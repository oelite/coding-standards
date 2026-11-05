#!/usr/bin/env bash
# UAT Redis ACL — Phase 0 (ACL file + legacy default) + Phase 1 (Orion user)
#
# Operator-only. Credentials never printed, never passed as long-lived argv
# literals, never written to GitLab. Temp material is shredded on exit.
#
# Prerequisites:
#   - Run from a machine with UAT kubeconfig via oelite-stack.sh
#   - Authorized operator for gitignored clusters/UAT edits
#   - coding-standards issue #108 / Orion #150 umbrella
#
# Usage:
#   ./scripts/uat-redis-acl-phase0-1-orion.sh
#   ./scripts/uat-redis-acl-phase0-1-orion.sh --dry-run
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Prefer an explicit override, then a stack dir that actually has UAT kubeconfig.
# Worktrees do not carry gitignored clusters/UAT — use the main coding-standards checkout.
resolve_stack_dir() {
  local candidate
  for candidate in \
      "${OELITE_STACK_DIR:-}" \
      "$LOCAL_STACK_DIR" \
      "$LOCAL_STACK_DIR/../../../../infrastructure/oelite-stack" \
      "$LOCAL_STACK_DIR/../../../infrastructure/oelite-stack"; do
    [[ -n "$candidate" ]] || continue
    candidate="$(cd "$candidate" 2>/dev/null && pwd)" || continue
    if [[ -x "$candidate/oelite-stack.sh" && -d "$candidate/clusters/UAT/kubeconfig" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}
STACK_DIR="$(resolve_stack_dir)" || {
  echo "[FATAL] No oelite-stack with clusters/UAT/kubeconfig found. Set OELITE_STACK_DIR." >&2
  exit 1
}
STACK_SH="$STACK_DIR/oelite-stack.sh"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

log_pre() { printf '[uat-redis-acl] %s\n' "$*"; }
log_pre "using stack dir: $STACK_DIR"

k() { "$STACK_SH" cluster UAT kubectl "$@"; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/uat-redis-acl.XXXXXX")"
chmod 700 "$WORKDIR"
cleanup() {
  if [[ -d "$WORKDIR" ]]; then
    find "$WORKDIR" -type f -exec sh -c 'rm -P "$1" 2>/dev/null || rm -f "$1"' _ {} \;
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

log() { printf '[uat-redis-acl] %s\n' "$*"; }
die() { printf '[uat-redis-acl] FATAL: %s\n' "$*" >&2; exit 1; }

REDIS_NS=default
REDIS_DEPLOY=redis-prod
ORION_NS=oelite-uat
ORION_DEPLOY=orion-api
ORION_SECRET=orion-redis
ACL_SECRET=redis-prod-acl
HOST="redis-prod.default.svc.cluster.local"
PORT=6379

log "workdir prepared (credentials stay here until shred)"
log "checking redis-prod readiness"
READY_LINE="$(k get deploy -n "$REDIS_NS" "$REDIS_DEPLOY" -o jsonpath='{.status.readyReplicas}/{.status.replicas}')"
log "redis-prod readyReplicas: $READY_LINE"
echo "$READY_LINE" | grep -E '^[1-9][0-9]*/[1-9]' >/dev/null \
  || die "redis-prod is not ready"

# Extract live --requirepass value into a file without printing it.
k get deploy -n "$REDIS_NS" "$REDIS_DEPLOY" -o json >"$WORKDIR/redis-deploy.json"
python3 - "$WORKDIR/redis-deploy.json" "$WORKDIR/legacy.pwd" <<'PY'
import json, sys
deploy = json.load(open(sys.argv[1]))
cmd = deploy["spec"]["template"]["spec"]["containers"][0].get("command") or []
pwd = None
for i, part in enumerate(cmd):
    if part == "--requirepass" and i + 1 < len(cmd):
        pwd = cmd[i + 1]
        break
    if isinstance(part, str) and part.startswith("--requirepass="):
        pwd = part.split("=", 1)[1]
        break
open(sys.argv[2], "w").write(pwd or "")
PY
chmod 600 "$WORKDIR/legacy.pwd"

if [[ ! -s "$WORKDIR/legacy.pwd" ]]; then
  die "could not locate live Redis auth material on redis-prod (no --requirepass). Aborting rather than guessing."
fi

# Authenticate inside the pod via stdin — avoid -a argv.
# Build default ACL with live plaintext (>password), not ACL LIST #hash.
# Redis 8.8 UAT rejected #hash re-auth after aclfile load (WRONGPASS); >password works.
log "capturing default ACL flags from live Redis (password taken from live requirepass)"
{
  cat "$WORKDIR/legacy.pwd"
  printf '\n'
} | k exec -i -n "$REDIS_NS" "deploy/$REDIS_DEPLOY" -- sh -c '
set -e
AUTH=$(head -n 1)
export REDISCLI_AUTH="$AUTH"
redis-cli --no-auth-warning ACL LIST
' >"$WORKDIR/acl-list.raw"

python3 - "$WORKDIR/acl-list.raw" "$WORKDIR/legacy.pwd" "$WORKDIR/default.acl-line" <<'PY'
import sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
legacy = open(sys.argv[2], encoding="utf-8", errors="replace").read()
if not legacy:
    sys.stderr.write("legacy password file empty\n")
    sys.exit(2)
default_line = None
for line in raw.splitlines():
    if line.startswith("user default "):
        default_line = line.strip()
        break
if not default_line:
    sys.stderr.write("unable to find 'user default' in ACL LIST\n")
    sys.stderr.write("raw_len=%d\n" % len(raw))
    sys.exit(2)
# Rebuild: keep non-password tokens; replace #hash / >secret with live >password.
tokens = default_line.split()
out = []
for t in tokens:
    if t.startswith("#") or t.startswith(">"):
        continue
    out.append(t)
# Insert password after on/off (+ optional sanitize flag already in out)
# Format: user <name> on|off [flags...] >password ~* &* +@...
out.insert(3 if len(out) >= 3 else len(out), ">" + legacy)
open(sys.argv[3], "w").write(" ".join(out) + "\n")
PY
chmod 600 "$WORKDIR/default.acl-line"
log "default user ACL line rebuilt with live password token (not echoed)"

# Generate Orion password without '=' padding (avoids StackExchange false option keys)
ORION_PASS="$(openssl rand -base64 36 | tr -d '/+=' | head -c 32)"
printf '%s' "$ORION_PASS" >"$WORKDIR/orion.pwd"
chmod 600 "$WORKDIR/orion.pwd"
unset ORION_PASS

ORION_PASS="$(cat "$WORKDIR/orion.pwd")"
{
  cat "$WORKDIR/default.acl-line"
  printf 'user orion on >%s ~* &* +@read +@write +@connection +@pubsub +@transaction +@scripting +ping +info -@dangerous\n' "$ORION_PASS"
} >"$WORKDIR/users.acl"
chmod 600 "$WORKDIR/users.acl"
unset ORION_PASS

printf '%s:%s,user=orion,password=%s,defaultDatabase=0,abortConnect=false' \
  "$HOST" "$PORT" "$(cat "$WORKDIR/orion.pwd")" >"$WORKDIR/orion.conn"
chmod 600 "$WORKDIR/orion.conn"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY RUN: would apply ACL secret $ACL_SECRET, patch redis-prod, create $ORION_SECRET, rewire $ORION_DEPLOY"
  log "ACL file lines: $(wc -l <"$WORKDIR/users.acl" | tr -d ' ')"
  log "connection string length: $(wc -c <"$WORKDIR/orion.conn" | tr -d ' ')"
  exit 0
fi

log "applying ACL secret $ACL_SECRET (namespace $REDIS_NS)"
k create secret generic "$ACL_SECRET" \
  -n "$REDIS_NS" \
  --from-file=users.acl="$WORKDIR/users.acl" \
  --dry-run=client -o yaml | k apply -f -

log "building redis-prod patch (KEEP requirepass for Phase 0; add aclfile mount)"
# Phase 0 dual-mode: retain --requirepass so legacy clients keep working even if
# aclfile default-user tokens misbehave; project users come from aclfile.
# Phase 3 removes requirepass when legacy is revoked.
python3 - "$WORKDIR/redis-deploy.json" "$WORKDIR/redis-patch.json" <<'PY'
import json, sys
src = json.load(open(sys.argv[1]))
container = src["spec"]["template"]["spec"]["containers"][0]
cmd = list(container.get("command") or [])
if "--aclfile" in cmd:
    idx = cmd.index("--aclfile")
    if idx + 1 < len(cmd):
        cmd[idx + 1] = "/etc/redis/users.acl"
    else:
        cmd.append("/etc/redis/users.acl")
else:
    cmd.extend(["--aclfile", "/etc/redis/users.acl"])

vol_mounts = [m for m in (container.get("volumeMounts") or []) if m.get("name") != "redis-acl"]
vol_mounts.append({"name": "redis-acl", "mountPath": "/etc/redis", "readOnly": True})

vols = [v for v in (src["spec"]["template"]["spec"].get("volumes") or []) if v.get("name") != "redis-acl"]
vols.append({"name": "redis-acl", "secret": {"secretName": "redis-prod-acl"}})

patch = {
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": container["name"],
          "command": cmd,
          "volumeMounts": vol_mounts,
        }],
        "volumes": vols,
      }
    }
  }
}
json.dump(patch, open(sys.argv[2], "w"))
PY

k patch deploy "$REDIS_DEPLOY" -n "$REDIS_NS" --type=strategic --patch-file="$WORKDIR/redis-patch.json"

# Secret updates do not restart the pod; force a rollout so aclfile is re-read.
log "restarting redis-prod to load updated ACL secret"
k rollout restart deploy/"$REDIS_DEPLOY" -n "$REDIS_NS"

log "waiting for redis-prod rollout"
k rollout status deploy/"$REDIS_DEPLOY" -n "$REDIS_NS" --timeout=180s

rollback_redis() {
  log "rolling back redis-prod to previous revision"
  k rollout undo deploy/"$REDIS_DEPLOY" -n "$REDIS_NS" || true
  k rollout status deploy/"$REDIS_DEPLOY" -n "$REDIS_NS" --timeout=180s || true
}

wait_redis_pong() {
  local i out
  for i in $(seq 1 24); do
    out="$(
      {
        cat "$WORKDIR/legacy.pwd"
        printf '\n'
      } | k exec -i -n "$REDIS_NS" "deploy/$REDIS_DEPLOY" -- sh -c '
AUTH=$(head -n 1)
export REDISCLI_AUTH="$AUTH"
redis-cli --no-auth-warning PING
' 2>/dev/null | tail -n 1 | tr -d "\r"
    )"
    if [[ "$out" == "PONG" ]]; then
      return 0
    fi
    log "waiting for redis ready (got: ${out:-empty})"
    sleep 5
  done
  return 1
}

log "waiting for redis PING after AOF load"
if ! wait_redis_pong; then
  rollback_redis
  die "redis did not return PONG after aclfile rollout; redis rolled back"
fi

log "verifying legacy default auth + orion ACL user"
if ! {
  cat "$WORKDIR/legacy.pwd"
  printf '\n'
} | k exec -i -n "$REDIS_NS" "deploy/$REDIS_DEPLOY" -- sh -c '
set -e
AUTH=$(head -n 1)
export REDISCLI_AUTH="$AUTH"
PONG=$(redis-cli --no-auth-warning PING)
test "$PONG" = "PONG"
redis-cli --no-auth-warning ACL LIST > /tmp/acl.list
grep -q "^user default " /tmp/acl.list
grep -q "^user orion " /tmp/acl.list
rm -f /tmp/acl.list
'; then
  rollback_redis
  die "legacy auth or ACL users failed after aclfile rollout; redis rolled back"
fi
log "legacy + orion ACL users present; PING ok"

log "verifying Orion ACL user auth"
{
  cat "$WORKDIR/orion.pwd"
  printf '\n'
} | k exec -i -n "$REDIS_NS" "deploy/$REDIS_DEPLOY" -- sh -c '
set -e
PASS=$(head -n 1)
export REDISCLI_AUTH="$PASS"
PONG=$(redis-cli --no-auth-warning --user orion PING)
test "$PONG" = "PONG"
'
log "orion ACL user PING ok"

log "creating/updating Secret $ORION_SECRET in $ORION_NS"
k create secret generic "$ORION_SECRET" \
  -n "$ORION_NS" \
  --from-file=connection-string="$WORKDIR/orion.conn" \
  --dry-run=client -o yaml | k apply -f -

log "rewiring $ORION_DEPLOY oelite__data__redis -> $ORION_SECRET/connection-string"
ENV_INDEX="$(k get deploy "$ORION_DEPLOY" -n "$ORION_NS" -o json | python3 -c '
import json,sys
d=json.load(sys.stdin)
envs=d["spec"]["template"]["spec"]["containers"][0].get("env") or []
for i,e in enumerate(envs):
  if e.get("name")=="oelite__data__redis":
    print(i); sys.exit(0)
print(-1)
')"
[[ "$ENV_INDEX" != "-1" ]] || die "oelite__data__redis env not found on orion-api"

k patch deploy "$ORION_DEPLOY" -n "$ORION_NS" --type=json -p="[
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/$ENV_INDEX/valueFrom/secretKeyRef/name\",\"value\":\"$ORION_SECRET\"},
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/$ENV_INDEX/valueFrom/secretKeyRef/key\",\"value\":\"connection-string\"}
]"

log "waiting for orion-api rollout"
if ! k rollout status deploy/"$ORION_DEPLOY" -n "$ORION_NS" --timeout=240s; then
  log "rollout not ready — dumping sanitized recent logs"
  k logs -n "$ORION_NS" "deploy/$ORION_DEPLOY" --tail=40 2>&1 \
    | sed -E 's/(password|pwd|Password|token|secret|Bearer )[=:][^[:space:],}"]*/\1=<REDACTED>/gi' \
    | sed -E 's/[A-Za-z0-9+\/=]{32,}/<REDACTED_BLOB>/g' || true
  die "orion-api rollout failed"
fi

READY="$(k get deploy "$ORION_DEPLOY" -n "$ORION_NS" -o jsonpath='{.status.readyReplicas}')"
log "orion-api readyReplicas=$READY"
[[ "${READY:-0}" -ge 1 ]] || die "orion-api not ready"

log "Phase 0+1 complete (sanitized). Verify https://api.uat.orion.oelite.cloud/health externally."
