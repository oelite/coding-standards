#!/bin/bash
# Verify the shared ClickHouse account configured in .env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$STACK_DIR/.env"

load_env_value() {
  local key="$1"
  if [ -n "${!key:-}" ]; then
    return
  fi
  if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r env_key env_value; do
      if [ "$env_key" = "$key" ]; then
        printf -v "$key" '%s' "$env_value"
        export "$key"
        return
      fi
    done < "$ENV_FILE"
  fi
}

load_env_value CLICKHOUSE_ADMIN_USER
load_env_value CLICKHOUSE_ADMIN_PASSWORD
CLICKHOUSE_ADMIN_USER="${CLICKHOUSE_ADMIN_USER:-oelite}"

if [ -z "${CLICKHOUSE_ADMIN_PASSWORD:-}" ]; then
  echo "ERROR: CLICKHOUSE_ADMIN_PASSWORD is required; run ./scripts/generate-secrets.sh first." >&2
  exit 1
fi

if ! docker exec oelite-clickhouse clickhouse-client \
  --user "$CLICKHOUSE_ADMIN_USER" \
  --password "$CLICKHOUSE_ADMIN_PASSWORD" \
  --query 'SELECT 1' >/dev/null 2>&1; then
  echo "ERROR: ClickHouse credentials failed authentication for $CLICKHOUSE_ADMIN_USER." >&2
  echo "Repair the shared stack credentials before continuing; no data-destructive action was attempted." >&2
  exit 1
fi

echo "ClickHouse credentials verified for $CLICKHOUSE_ADMIN_USER."
