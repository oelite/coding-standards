#!/usr/bin/env bash
# =============================================================================
# peers-health.sh — thin wrapper invoking the .NET peers-health tool (TASK-97)
# =============================================================================
# Usage: ./peers-health.sh [peers-health options]
#   e.g. ./peers-health.sh --profile uat-peers --strict
#
# Exit codes pass through from the .NET tool:
#   0 healthy | 1 critical failure (or --strict any failure) | 2 config error
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_PROJECT="$SCRIPT_DIR/../../../scripts/tools/peers-health/peers-health.csproj"

if ! command -v dotnet >/dev/null 2>&1; then
  echo "ERROR: dotnet SDK not found on PATH. Install .NET 8 SDK to run peers-health." >&2
  exit 2
fi

# Prefer a previously published binary if present (fast path); fall back to
# dotnet run (restores/builds on demand).
PUBLISHED="$SCRIPT_DIR/../../../scripts/tools/peers-health/bin/published/peers-health"
if [ -x "$PUBLISHED" ]; then
  exec "$PUBLISHED" "$@"
fi

exec dotnet run --project "$TOOL_PROJECT" --configuration Release -- "$@"
