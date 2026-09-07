#!/bin/bash
# OElite Shared Local Infrastructure — secret bootstrap
#
# Generates a per-machine `.env.local` with random credentials for every service.
# Runs ONCE per machine (or whenever secrets are rotated).
#
# - `.env.example`  → committed, contains schema + key names
# - `.env.local`    → gitignored, contains real credentials for THIS machine
# - `.mongo.key`    → generated alongside by oelite-stack.sh (cluster auth)
#
# Usage:
#   ./scripts/generate-secrets.sh          # create .env.local if missing
#   ./scripts/generate-secrets.sh --rotate # regenerate ALL secrets
#   ./scripts/generate-secrets.sh --print  # just print the current values
#
# Idempotent: running without --rotate preserves existing values.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$STACK_DIR/.env.local"
ENV_EXAMPLE="$STACK_DIR/.env.example"
cd "$STACK_DIR"

ROTATE=0
PRINT=0
for arg in "$@"; do
  case "$arg" in
    --rotate) ROTATE=1 ;;
    --print)  PRINT=1 ;;
    -h|--help)
      sed -n '3,/^$/{s/^# \?//; p}' "$0" | head -20
      exit 0
      ;;
  esac
done

# ─── helpers ────────────────────────────────────────────────────────────────
gen_secret() {
  # URL-safe 32-char random; tr strips '/' and '+' to keep URL parsers happy
  openssl rand -base64 36 | tr -d '/+=' | head -c 32
}

ensure_example() {
  if [ ! -f "$ENV_EXAMPLE" ]; then
    cat > "$ENV_EXAMPLE" <<'EOF'
# OElite Shared Stack — env schema
#
# Copy this file to `.env.local` (gitignored) and let
# `./scripts/generate-secrets.sh` fill in random values on first run.
#
# All variables are read by docker-compose.shared.yml via `env_file: .env.local`
# and by the init scripts.

# ─── MongoDB (root) ──────────────────────────────────────────────────────
# Created by init-per-project-dbs.sh on first `oelite-stack.sh init`.
# Has root + clusterAdmin + userAdmin roles on admin DB.
MONGO_ROOT_USER=admin
MONGO_ROOT_PASSWORD=

# ─── ClickHouse ──────────────────────────────────────────────────────────
# Created by init-clickhouse-users.sh on first init.
# Has access_management=1 (admin).
CLICKHOUSE_ADMIN_USER=oelite
CLICKHOUSE_ADMIN_PASSWORD=

# ─── Redis ───────────────────────────────────────────────────────────────
# Wired via --requirepass on the redis-server CLI.
REDIS_PASSWORD=

# ─── RabbitMQ ────────────────────────────────────────────────────────────
# RABBITMQ_DEFAULT_USER/PASS create the initial superuser.
# init-rabbitmq.sh then provisions per-project vhost + user accounts.
RABBITMQ_DEFAULT_USER=oelite
RABBITMQ_DEFAULT_PASS=

# ─── MinIO ───────────────────────────────────────────────────────────────
# MINIO_ROOT_USER/PASSWORD create the initial superuser.
# init-minio.sh then creates per-project buckets + service-account keys.
MINIO_ROOT_USER=oelite
MINIO_ROOT_PASSWORD=
EOF
    chmod 644 "$ENV_EXAMPLE"
    echo "[generate-secrets] wrote $ENV_EXAMPLE (committed example, no secrets)"
  fi
}

read_value() {
  # read a KEY=value line from .env.local; empty if missing
  local key="$1"
  if [ -f "$ENV_FILE" ]; then
    grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-
  fi
}

write_value() {
  # upsert KEY=value in .env.local, preserving comments and other keys
  local key="$1" value="$2" file="$3"
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    # portable in-place edit (BSD/GNU)
    local tmp="${file}.tmp"
    sed "s|^${key}=.*|${key}=${value}|" "$file" > "$tmp" && mv "$tmp" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

rotate_if_requested() {
  local key="$1"
  local current
  current="$(read_value "$key")"
  if [ "$ROTATE" -eq 1 ] || [ -z "$current" ]; then
    gen_secret
  else
    echo "$current"
  fi
}

# ─── print-only mode ───────────────────────────────────────────────────────
if [ "$PRINT" -eq 1 ]; then
  if [ ! -f "$ENV_FILE" ]; then
    echo "(no .env.local yet — run ./scripts/generate-secrets.sh)"
    exit 0
  fi
  echo "Current .env.local (sensitive values — do not share):"
  cat "$ENV_FILE"
  exit 0
fi

# ─── main ──────────────────────────────────────────────────────────────────
ensure_example

if [ ! -f "$ENV_FILE" ] || [ "$ROTATE" -eq 1 ]; then
  if [ "$ROTATE" -eq 1 ] && [ -f "$ENV_FILE" ]; then
    echo "[generate-secrets] ROTATE requested — regenerating all secrets"
  else
    echo "[generate-secrets] first run — creating $ENV_FILE"
  fi
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  REGEN=1
else
  echo "[generate-secrets] existing $ENV_FILE found — preserving values (use --rotate to regenerate)"
  REGEN=0
fi

# Required secret keys
SECRETS=(
  MONGO_ROOT_PASSWORD
  CLICKHOUSE_ADMIN_PASSWORD
  REDIS_PASSWORD
  RABBITMQ_DEFAULT_PASS
  MINIO_ROOT_PASSWORD
)

for key in "${SECRETS[@]}"; do
  new="$(rotate_if_requested "$key")"
  write_value "$key" "$new" "$ENV_FILE"
done

chmod 600 "$ENV_FILE"

echo ""
echo "[generate-secrets] $ENV_FILE ready"
echo "  permissions: $(stat -f '%Lp' "$ENV_FILE" 2>/dev/null || stat -c '%a' "$ENV_FILE")"
echo "  secrets:     ${#SECRETS[@]} keys"
echo ""
echo "Next step:  ./oelite-stack.sh up && ./oelite-stack.sh init"
echo ""
