#!/usr/bin/env bash
# =============================================================================
# OElite Guard  —  Unified machine-enforced guard (Claude Code + OpenCode)
# =============================================================================
# Called by:
#   - Claude Code: PreToolUse hook (writes JSON to stdin, expects exit 2 on block)
#   - OpenCode:    opencode-plugin-oelite/index.ts (tool.execute.before)
#
# Hard-gates (all non-negotiable for AI agents; OELITE_HUMAN=1 bypasses all):
#   A. ROOT-WRITE       — Write/Edit/Bash target not inside a scoped git sub-repo
#                         AND not inside the auto-allowed .claude/.opencode tree.
#   B. WORKTREE-PRESENT — Within a scoped git repo, target must be under a
#                         .worktrees/ path. Agents never edit the main checkout.
#   C. PROTECTED-BRANCH — If the enclosing worktree is on develop/main/master,
#                         edits are blocked. Agents only edit feature branches.
#   D. ISSUE-IID        — (Advisory at edit-time; enforced at worktree-create
#                         via scripts/oelite-gitlab.sh.) When a worktree has a
#                         .oe-scope, edits to files outside the worktree's
#                         declared scope are blocked.
#   E. NO-STANDALONE-INFRA — Shared local infrastructure is a machine-wide
#                         SINGLETON at coding-standards/infrastructure/oelite-stack/.
#                         Agents MUST NOT create a second instance of any of the
#                         7 shared services (MongoDB, Redis, ClickHouse, Kafka,
#                         RabbitMQ, MinIO, OpenSearch) — not via docker-compose
#                         file, not via `docker run`, not via Testcontainers.
#                         If a shared service is down, the fix is to RESTART the
#                         shared stack (`./oelite-stack.sh up`), never to create
#                         a replacement container. See standard 16.
#
# Payload shape (stdin, normalised by this script):
#   Claude Code: { "tool_name": "Write|Edit|MultiEdit|Bash", "tool_input": {...} }
#   OpenCode:    { "tool":      "edit|write|bash",            "args":         {...} }
#
# Exit codes:
#   0 = allow
#   2 = block (stderr carries the diagnostic)
# =============================================================================
set -euo pipefail

# ── Resolve OElite root (the monorepo container) ─────────────────────────────
# Priority: CLAUDE_PROJECT_DIR > OPENCODE_PROJECT_DIR > derive from script path.
# This script lives at <root>/coding-standards/scripts/hooks/oelite-guard.sh,
# so 3 dirs up from here is the root.
ROOT="${CLAUDE_PROJECT_DIR:-${OPENCODE_PROJECT_DIR:-}}"
if [[ -z "$ROOT" || ! -d "$ROOT" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi
ROOT="$(cd "$ROOT" && pwd)"
CLAUDE_DIR="$ROOT/.claude"
OPENCODE_DIR="$ROOT/.opencode"

# ── Human bypass ────────────────────────────────────────────────────────────
if [[ "${OELITE_HUMAN:-0}" == "1" ]]; then exit 0; fi

# ── Staleness check: .oe-scope at the monorepo root is a contaminant ──
if [[ -f "$ROOT/.oe-scope" ]]; then
  echo "[oelite-guard] WARNING: Stale .oe-scope found at $ROOT/.oe-scope" >&2
  echo "          This file is a PER-WORKTREE anchor and should NOT exist" >&2
  echo "          at the monorepo root. It was likely created by an agent" >&2
  echo "          running from the wrong CWD. Delete it." >&2
fi

# ── Read payload, normalise fields ───────────────────────────────────────────
PAYLOAD="$(cat)"

# jq is a Claude Code dependency, but OpenCode may not have it. Both must
# satisfy the guard contract, so we require jq. (Told users to install it
# already for the CLI scripts.)
if ! command -v jq >/dev/null 2>&1; then
  echo "[oelite-guard] jq not found in PATH; guard is inert. Install jq." >&2
  exit 0
fi

TOOL_NAME="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // .tool // empty')"
FILE_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .args.filePath // empty')"
CMD="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // .args.command // empty')"
FILE_BODY="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.content // .tool_input.new_string // .args.content // .args.newString // empty')"

# ── Helpers ─────────────────────────────────────────────────────────────────
canon() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1" 2>/dev/null || echo "$1"
}

# True if path lives inside (or, for non-existent paths, would live inside) a
# directory that contains a .git entry ("scoped git sub-repo").
in_scoped_repo() {
  local p="$1" d="$1"
  while [[ ! -e "$d" && "$d" != "/" && "$d" != "$ROOT" ]]; do d="$(dirname "$d")"; done
  [[ "$d" == "/" || "$d" == "$ROOT" ]] && return 1
  while [[ "$d" != "$ROOT" && "$d" != "/" ]]; do
    [[ -e "$d/.git" ]] && return 0
    d="$(dirname "$d")"
  done
  return 1
}

# True if path lives inside a .worktrees/ directory of a scoped repo.
in_worktree() {
  local p="$1" d="$1"
  while [[ ! -e "$d" && "$d" != "/" && "$d" != "$ROOT" ]]; do d="$(dirname "$d")"; done
  while [[ "$d" != "$ROOT" && "$d" != "/" ]]; do
    [[ "$(basename "$d")" == ".worktrees" ]] && return 0
    d="$(dirname "$d")"
  done
  return 1
}

# True if path is inside the auto-allowed IDE config trees.
in_ide_config() {
  [[ "$1" == "$CLAUDE_DIR"   || "$1" == "$CLAUDE_DIR/"*   || \
     "$1" == "$OPENCODE_DIR" || "$1" == "$OPENCODE_DIR/"* ]]
}

# ── Gate E helpers: shared local infrastructure is a machine-wide singleton ──
# The singleton lives in coding-standards/infrastructure/oelite-stack/ (main
# checkout or a .worktrees/<agent>-<iid>/ copy). in_shared_stack() accepts both.

in_shared_stack() {
  local d
  d="$(dirname "$(canon "$1")")"
  [[ "$d" == *"/infrastructure/oelite-stack" && "$d" == *"coding-standards"* ]]
}

is_compose_filename() {
  local n
  n="$(basename "$1")"
  [[ "$n" == *compose*.yml || "$n" == *compose*.yaml ]]
}

# True if compose content declares a shared-stack service on an `image:` line.
# Anchored to `image:` so a mention in a comment or a service NAME does not match.
compose_declares_shared_infra() {
  grep -Eqi '^[[:space:]]*image:[[:space:]]*["'"'"']?[^[:space:]"'"'"']*(mongo|redis|rabbitmq|minio|clickhouse|opensearch|cp-kafka)' <<<"$1"
}

# True if a docker CLI invocation names a shared-stack service image.
docker_cmd_targets_shared_infra() {
  grep -Eqi '(^|[[:space:]"])(mongo|redis|rabbitmq|minio|clickhouse|opensearch|cp-kafka)(:[0-9]|$|@)' <<<"$1" ||
    grep -Eqi '(confluentinc/cp-kafka|apache/kafka|opensearchproject/opensearch|minio/minio|clickhouse/clickhouse-server)' <<<"$1"
}

# Extracts the value of the first -f/--file argument from a compose command.
compose_file_from_cmd() {
  local -a toks
  read -r -a toks <<<"$1"
  local i
  for (( i=0; i<${#toks[@]}-1; i++ )); do
    if [[ "${toks[i]}" == "-f" || "${toks[i]}" == "--file" ]]; then
      printf '%s\n' "${toks[i+1]}"
      return 0
    fi
  done
  return 1
}

# Enclosing git worktree toplevel (only meaningful if in_worktree).
# IMPORTANT: A worktree has its OWN toplevel. `git rev-parse --show-toplevel`
# from inside a worktree returns the worktree's path, not the parent repo's.
# We must land inside the .worktrees/<name>/ directory, then cd into the
# worktree (which is `../` from .worktrees/<name>/'s parent perspective).
# Easiest correct way: find the worktree dir, then ask git from there.
worktree_toplevel() {
  local p="$1"
  in_worktree "$p" || return 1
  local d="$p"
  while [[ ! -e "$d" && "$d" != "/" ]]; do d="$(dirname "$d")"; done
  while [[ "$(basename "$d")" != ".worktrees" && "$d" != "/" ]]; do
    d="$(dirname "$d")"
  done
  local pp="$p"
  while [[ ! -e "$pp" && "$pp" != "/" ]]; do pp="$(dirname "$pp")"; done
  local best_top=""
  local best_depth=0
  for wt in "$d"/*/; do
    [[ -d "$wt" ]] || continue
    local wt_canon="$wt"
    if command -v python3 >/dev/null 2>&1; then
      wt_canon="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt" 2>/dev/null || echo "$wt")"
    fi
    local top
    top="$(cd "$wt" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -z "$top" ]] && continue
    [[ "$top" != "$wt" && "$top" != "$wt_canon" ]] && continue
    case "$pp" in
      "$top"/*|"$top")
        local depth="${#top}"
        if (( depth > best_depth )); then
          best_top="$top"
          best_depth="$depth"
        fi
        ;;
    esac
  done
  [[ -n "$best_top" ]] && { printf '%s\n' "$best_top"; return 0; }
  return 1
}

# ── Block messaging ─────────────────────────────────────────────────────────
block() {
  local target="$1" reason="$2" via="$3"
  local body
  case "$reason" in
    root-write)
      body="The oelite root is a monorepo CONTAINER, not a git repo.
AI agents must work ONLY inside their scoped git sub-repo
(e.g. helios/core/, uranus/origin-auth/) — never directly under root.

Auto-allowed: .claude/ and .opencode/ (IDE config), coding-standards/scripts/hooks/."
      ;;
    no-worktree)
      body="This target is inside a scoped git repo, but you are NOT in a worktree.
The main checkout is reserved for the human developer on develop.
AI agents MUST work in .worktrees/<agent>-<iid>/.

Fix:
  cd <target-repo>/
  ../../coding-standards/scripts/oelite-gitlab.sh worktree-create <role> feature/<branch> --issue <iid>
  cd .worktrees/<role>-<iid>/
  # Now retry your edit here."
      ;;
    protected-branch)
      body="You are on a protected branch ($CURR_BRANCH).
AI agents must NEVER edit develop/main/master directly.
All code enters develop through reviewed Merge Requests."
      ;;
    out-of-scope)
      body="This target is outside the worktree's declared scope.
The worktree's .oe-scope file declares: $SCOPE_DESC
Editing files outside that scope is forbidden to prevent cross-issue contamination."
      ;;
    standalone-infra)
      body="This compose file declares a SHARED local-infrastructure service.
The 7 shared services (MongoDB, Redis, ClickHouse, Kafka, RabbitMQ, MinIO,
OpenSearch) live ONCE per machine in the singleton stack:

  coding-standards/infrastructure/oelite-stack/

Agents MUST NOT create a second instance. That drains dev-machine resources
and breaks the singleton model.

Fix (integration tests / local dev need infra?):
  cd coding-standards/infrastructure/oelite-stack
  ./oelite-stack.sh health   # verify shared stack
  ./oelite-stack.sh up       # start/restart the shared stack (idempotent)
  ./oelite-stack.sh init     # one-time sharding + per-project namespaces

Per-project isolation is via namespaces (db/bucket/vhost/topic-prefix/redis-db),
defined in your appsettings.init.json — NOT separate containers.

Need a service the shared stack lacks? Open a GitLab issue for Ethan instead
of starting a local container. See standard 16-SHARED-LOCAL-INFRASTRUCTURE.md."
      ;;
    standalone-infra-cmd)
      body="This command would start a SECOND instance of a SHARED service.
The 7 shared services run ONCE per machine in the singleton stack.

Agents MUST NOT run 'docker run' for these services, and MUST NOT bring up a
per-repo compose file that defines them.

Fix (need the shared services up?):
  cd coding-standards/infrastructure/oelite-stack
  ./oelite-stack.sh health   # see what is down
  ./oelite-stack.sh up       # start/restart the shared stack (idempotent)

If the shared stack is down, RESTART IT — do not create a replacement.
See standard 16-SHARED-LOCAL-INFRASTRUCTURE.md."
      ;;
    *)
      body="(unknown reason)"
      ;;
  esac

  cat >&2 <<EOF
────────────────────────────────────────────────────────────────────
⛔ OELITE GUARD: blocked ($reason)
Target : $target
Via    : $via ($TOOL_NAME)
Root   : $ROOT

$body

See coding-standards/AGENTS.md § HARD GATES.
HUMAN BYPASS: OELITE_HUMAN=1 (use only for intentional human maintenance).
────────────────────────────────────────────────────────────────────
EOF
  exit 2
}

# ── Tool dispatcher ─────────────────────────────────────────────────────────
# Normalise file-editing tool names
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|edit|write|patch)
    [[ -z "$FILE_PATH" ]] && exit 0
    FILE="$(canon "$FILE_PATH")"

    # Auto-allow IDE config dirs (write to .claude/.opencode is fine)
    in_ide_config "$FILE" && exit 0

    # A. ROOT-WRITE — if the file is under ROOT but not in a scoped repo, block
    if [[ "$FILE" == "$ROOT"/* ]]; then
      if ! in_scoped_repo "$FILE"; then
        # Special carve-out: coding-standards itself is a scoped repo via its
        # .git; the guard above would catch it. But coding-standards/scripts/
        # maintenance is sometimes done by tooling. Stay strict; rely on
        # OELITE_HUMAN=1 for human maintenance.
        block "$FILE_PATH" "root-write" "$TOOL_NAME"
      fi
    else
      # Not under ROOT at all (e.g. /tmp/foo) — allow
      exit 0
    fi

    # B. WORKTREE-PRESENT — inside a scoped repo, must be in a worktree
    if ! in_worktree "$FILE"; then
      block "$FILE_PATH" "no-worktree" "$TOOL_NAME"
    fi

    # C. PROTECTED-BRANCH — worktree on a protected branch is forbidden
    WT_TOP="$(worktree_toplevel "$FILE")"
    if [[ -n "$WT_TOP" ]]; then
      CURR_BRANCH="$(cd "$WT_TOP" && git branch --show-current 2>/dev/null || echo "")"
      case "$CURR_BRANCH" in
        develop|main|master) block "$FILE_PATH" "protected-branch" "$TOOL_NAME" ;;
      esac
    fi

    # D. ISSUE-IID / SCOPE — if .oe-scope exists, the worktree declared an
    #    issue+desc. Files written must be inside the worktree's declared
    #    scope path. We use the worktree toplevel as the legitimate scope.
    #    (No cross-file reflow; this is a light check.)
    SCOPE_FILE="$WT_TOP/.oe-scope"
    if [[ -f "$SCOPE_FILE" && -n "$WT_TOP" ]]; then
      SCOPE_DESC="$(grep -E '^#|desc:' "$SCOPE_FILE" 2>/dev/null | head -1 || true)"
      # The file is already inside WT_TOP (by construction of in_worktree),
      # so the scope check is satisfied by construction. We only use this
      # to surface scope context in blocked messages.
    fi

    # E. NO-STANDALONE-INFRA — block per-repo compose files that declare a
    #    shared-stack service. The singleton lives in oelite-stack/.
    if is_compose_filename "$FILE" && ! in_shared_stack "$FILE"; then
      payload_text=""
      [[ -f "$FILE" ]] && payload_text="$(cat "$FILE" 2>/dev/null || true)"
      payload_text+=$'\n'"$FILE_BODY"
      if compose_declares_shared_infra "$payload_text"; then
        block "$FILE_PATH" "standalone-infra" "$TOOL_NAME"
      fi
    fi

    exit 0
    ;;
esac

# ── Bash checks ─────────────────────────────────────────────────────────────
if [[ "$TOOL_NAME" != "Bash" && "$TOOL_NAME" != "bash" ]]; then
  exit 0
fi
[[ -z "$CMD" ]] && exit 0

# --- Per-target check, reusable for both redirect-scan and mutator-scan paths.
# Returns 0 (allow) or non-zero + sets block vars (via globals).
CURR_BRANCH=""
SCOPE_DESC=""
check_target_path() {
  local raw="$1" via="$2"
  [[ -z "$raw" ]] && return 0
  local abs
  abs="$(canon "$raw")"

  # Outside ROOT — allow (e.g. /tmp, /usr/local)
  [[ "$abs" != "$ROOT"/* ]] && return 0

  # Inside .claude/.opencode — allow
  in_ide_config "$abs" && return 0

  # A. ROOT-WRITE — under ROOT but not in a scoped repo
  if ! in_scoped_repo "$abs"; then
    block "$raw" "root-write" "$via"
  fi

  # B. WORKTREE-PRESENT
  if ! in_worktree "$abs"; then
    block "$raw" "no-worktree" "$via"
  fi

  # C. PROTECTED-BRANCH
  local wt_top
  wt_top="$(worktree_toplevel "$abs")"
  if [[ -n "$wt_top" ]]; then
    CURR_BRANCH="$(cd "$wt_top" && git branch --show-current 2>/dev/null || echo "")"
    case "$CURR_BRANCH" in
      develop|main|master) block "$raw" "protected-branch" "$via" ;;
    esac
  fi
}

# --- Redirect scan (carry over from prevent-root-writes.sh, generalised).
extract_paths_from_redirects() {
  local s="$1" tok target stripped
  local want_target=0
  for tok in $s; do
    stripped="$tok"
    stripped="${stripped#\"}"; stripped="${stripped%\"}"
    stripped="${stripped#\'}"; stripped="${stripped%\'}"

    if [[ "$stripped" == of=* ]]; then
      target="${stripped#of=}"
      [[ -n "$target" ]] && echo "$target"
      continue
    fi

    if (( want_target )); then
      target="$stripped"
      want_target=0
      [[ -n "$target" ]] && echo "$target"
      continue
    fi

    if [[ "$stripped" == ">"  || "$stripped" == ">>" || \
          "$stripped" =~ ^[0-9]+\>$ || "$stripped" =~ ^[0-9]+\>\>$ || \
          "$stripped" == "&>" || "$stripped" == "&>>" ]]; then
      want_target=1
      continue
    fi

    if [[ "$stripped" =~ ^(\&|[0-9]+)?\>{1,2}([^>&].*)$ ]]; then
      target="${BASH_REMATCH[2]}"
      [[ -n "$target" ]] && echo "$target"
      continue
    fi
  done
}

# --- Mutator segment scan (also carry over; sed/awk -i added).
check_segment() {
  local segment="$1"
  local first second arg abs verb
  segment="${segment#"${segment%%[![:space:]]*}"}"
  segment="${segment%"${segment##*[![:space:]]}"}"
  [[ -z "$segment" ]] && return 0

  read -r first second _ <<<"$segment"
  verb="$first"
  case "$first" in
    sudo|command|nice|time|env|nohup) read -r verb second _ <<<"$second" 2>/dev/null || true ;;
  esac

  # Common mutators: explicit file arg(s).
  case "$verb" in
    mkdir|touch|rm|rmdir|cp|mv|install|rsync|tee|dd|truncate|ln)
      for arg in $segment; do
        case "$arg" in
          -*) continue ;;
          "$verb") continue ;;
          /*) ;;     # absolute path — keep
          *) continue ;;
        esac
        check_target_path "$arg" "Bash($verb)"
      done
      ;;
    # sed -i / --in-place: take the next non-flag, non-=expression arg as target.
    sed)
      local next_is_target=0
      for arg in $segment; do
        case "$arg" in
          sed) continue ;;
          -i*|-[!-]i|--in-place*) next_is_target=1; continue ;;
          -e|--expression|-f|--file|--regexp-extended) next_is_target=0; continue ;;
          -*) continue ;;
          /*)
            if (( next_is_target )); then
              check_target_path "$arg" "Bash(sed -i)"
              next_is_target=0
            fi
            ;;
        esac
      done
      ;;
    # awk -i inplace: same treatment.
    awk|gawk)
      local next_is_target=0
      for arg in $segment; do
        case "$arg" in
          awk|gawk) continue ;;
          -i*|--include*|-f|--file) next_is_target=1; continue ;;
          -*) continue ;;
          /*)
            if (( next_is_target )); then
              check_target_path "$arg" "Bash(awk -i)"
              next_is_target=0
            fi
            ;;
        esac
      done
      ;;
  esac
}

# Run redirect scan first.
while read -r p; do
  [[ -z "$p" ]] && continue
  check_target_path "$p" "Bash(redirect)"
done < <(extract_paths_from_redirects "$CMD")

# Run mutator scan across pipeline segments.
IFS='|' read -ra segs <<< "$CMD"
for segment in "${segs[@]}"; do
  check_segment "$segment"
done

# ── Gate E (Bash): block docker commands that would create a second instance ──
# The shared stack is managed only through oelite-stack.sh / the shared compose
# file. `docker run <shared-image>` and per-repo compose files are prohibited.
is_docker_cmd() {
  [[ "$CMD" =~ (^|[[:space:]/])docker(-compose)?[[:space:]] ]]
}
if is_docker_cmd; then
  compose_arg="$(compose_file_from_cmd "$CMD" || true)"
  if [[ -n "$compose_arg" ]] && in_shared_stack "$compose_arg"; then
    exit 0
  fi
  # `docker run` is never the sanctioned way to manage the singleton.
  if [[ "$CMD" =~ (^|[[:space:]/])docker(-compose)?[[:space:]]+(-[^[:space:]]+[[:space:]]+)*run([[:space:]]|$) ]] \
     && docker_cmd_targets_shared_infra "$CMD"; then
    block "$CMD" "standalone-infra-cmd" "Bash(docker run)"
  fi
  # docker compose up/down/start against a per-repo file that defines a shared service.
  if [[ -n "$compose_arg" && "$compose_arg" != /* ]]; then
    compose_arg="$PWD/$compose_arg"
  fi
  if [[ -n "$compose_arg" && -f "$compose_arg" ]] && compose_declares_shared_infra "$(cat "$compose_arg" 2>/dev/null)"; then
    block "$compose_arg" "standalone-infra-cmd" "Bash(docker compose)"
  fi
  # No explicit -f: a bare `docker compose up` inside a repo whose default
  # compose file defines a shared service is the most common violation.
  if [[ -z "$compose_arg" && -f "./docker-compose.yml" ]] \
     && compose_declares_shared_infra "$(cat ./docker-compose.yml 2>/dev/null)"; then
    block "./docker-compose.yml" "standalone-infra-cmd" "Bash(docker compose)"
  fi
fi

exit 0
