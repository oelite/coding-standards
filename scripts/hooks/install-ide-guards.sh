#!/usr/bin/env bash
# =============================================================================
# install-ide-guards.sh — Roll out per-repo .claude/settings.json to every
# OElite sub-repository, ensuring the PreToolUse guard fires regardless of
# which sub-repo Claude Code is launched from.
#
# Idempotent. Safe to re-run. Skips repos that already have a settings.json
# unless --force is passed.
#
# Usage:
#   ./install-ide-guards.sh                  # dry-run; show what would change
#   ./install-ide-guards.sh --apply          # write settings.json files
#   ./install-ide-guards.sh --apply --force  # overwrite existing settings.json
#   ./install-ide-guards.sh --repo helios/core  # only one repo
#
# Honours OELITE_HUMAN=1 (required when invoked from a context where the
# unified guard is already active, since per-repo files live under root).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve the OElite monorepo root. Works from both the main checkout
# (<root>/coding-standards/scripts/hooks/) and from a worktree
# (<root>/coding-standards/.worktrees/<agent>/scripts/hooks/).
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
while [[ "$(basename "$ROOT")" == ".worktrees" ]]; do
  ROOT="$(cd "$ROOT/.." && pwd)"
done
if [[ ! -d "$ROOT/coding-standards" && -d "$(cd "$ROOT/../coding-standards" 2>/dev/null && pwd)" ]]; then
  ROOT="$(cd "$ROOT/.." && pwd)"
fi
CODING_STANDARDS="$ROOT/coding-standards"
GUARD_PATH="coding-standards/scripts/hooks/oelite-guard.sh"

APPLY=0
FORCE=0
TARGET_REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --force) FORCE=1; shift ;;
    --repo)  TARGET_REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Active repos list — keep in sync with coding-standards/AGENTS.md.
ACTIVE_REPOS=(
  helios/core helios/kortex helios/oesterling helios/compass helios/k8s
  jupiter/ec-std-01 jupiter/ec-nx-01 jupiter/occ jupiter/bizsmart jupiter/apex
  jupiter/apps-ec-store jupiter/apps-biz-suite
  uranus/origin-auth uranus/restme uranus/restme-dapper uranus/orion
  uranus/stella uranus/hermes uranus/lattice uranus/quantrix uranus/slate
  uranus/arc-cli uranus/arc-agents
  venus/obelisk venus/sip venus/stela
  mercury/runners/Backplane mercury/DataSync
  mercury/LoadBalanceHealthCheckker mercury/SubscriptionBilling
)

filter_repos() {
  if [[ -n "$TARGET_REPO" ]]; then
    printf '%s\n' "${ACTIVE_REPOS[@]}" | grep -Fx "$TARGET_REPO" || {
      echo "Repo '$TARGET_REPO' is not in the active list." >&2
      exit 2
    }
  else
    printf '%s\n' "${ACTIVE_REPOS[@]}"
  fi
}

# Compute relative path from a repo root to coding-standards.
relpath_to_standards() {
  local repo="$1"
  python3 - "$ROOT" "$repo" <<'PY'
import os, sys
root, repo = sys.argv[1], sys.argv[2]
repo_abs = os.path.realpath(os.path.join(root, repo))
cs_abs = os.path.realpath(os.path.join(root, "coding-standards"))
rel = os.path.relpath(cs_abs, repo_abs)
print(rel)
PY
}

render_settings() {
  cat <<'GUARDEOF'
{
    "permissions": {
        "allow": [
            "Bash(dotnet *)",
            "Bash(npm *)",
            "Bash(npx *)",
            "Bash(cd *)",
            "Bash(source *)",
            "Bash(ls *)",
            "Bash(cat *)",
            "Bash(echo *)",
            "Bash(pwd)",
            "Bash(which *)",
            "Bash(mkdir *)",
            "Bash(cp *)",
            "Bash(mv *)",
            "Bash(grep *)",
            "Bash(curl *)",
            "Bash(python3 *)",
            "Bash(node *)",
            "Bash(test *)",
            "Bash(git -C *)",
            "Bash(git status*)",
            "Bash(git log*)",
            "Bash(git diff*)",
            "Bash(git branch*)",
            "Bash(git fetch*)",
            "Bash(security find-generic-password *)",
            "Bash(xxd *)"
        ]
    },
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash -c 'D=\"$CLAUDE_PROJECT_DIR\"; while [ \"$D\" != \"/\" ]; do [ -f \"$D/coding-standards/scripts/hooks/oelite-guard.sh\" ] && exec bash \"$D/coding-standards/scripts/hooks/oelite-guard.sh\"; D=\"$(dirname \"$D\")\"; done; exit 0'"
                    }
                ]
            }
        ],
        "PostCompact": [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash -c 'D=\"$CLAUDE_PROJECT_DIR\"; while [ \"$D\" != \"/\" ]; do [ -f \"$D/AGENTS.md\" ] && { cat \"$D/AGENTS.md\"; exit 0; }; D=\"$(dirname \"$D\")\"; done'"
                    }
                ]
            }
        ]
    }
}
GUARDEOF
}

INSTALLED=0
SKIPPED=0
MISSING=0
declare -a MISSING_REPOS=()

while read -r repo; do
  [[ -z "$repo" ]] && continue
  repo_dir="$ROOT/$repo"
  if [[ ! -d "$repo_dir" ]]; then
    MISSING=$((MISSING+1))
    MISSING_REPOS+=("$repo")
    continue
  fi
  if [[ ! -e "$repo_dir/.git" ]]; then
    MISSING=$((MISSING+1))
    MISSING_REPOS+=("$repo (no .git)")
    continue
  fi
  target="$repo_dir/.claude/settings.json"
  if [[ -f "$target" && $FORCE -eq 0 && $APPLY -eq 0 ]]; then
    : # dry-run: would skip
  fi
  if [[ -f "$target" && $FORCE -eq 0 ]]; then
    echo "SKIP  $repo (.claude/settings.json exists; pass --force to overwrite)"
    SKIPPED=$((SKIPPED+1))
    continue
  fi
  rel="$(relpath_to_standards "$repo")"
  if [[ "$APPLY" -eq 1 ]]; then
    mkdir -p "$repo_dir/.claude"
    render_settings "$rel" > "$target"
    echo "WROTE $repo/.claude/settings.json (rel=$rel)"
  else
    echo "DRY  $repo/.claude/settings.json (rel=$rel)"
  fi
  INSTALLED=$((INSTALLED+1))
done < <(filter_repos)

echo
echo "Summary: installed=$INSTALLED skipped=$SKIPPED missing=$MISSING"
if [[ ${#MISSING_REPOS[@]} -gt 0 ]]; then
  echo "Missing or non-git repos:"
  printf '  - %s\n' "${MISSING_REPOS[@]}"
fi
if [[ "$APPLY" -eq 0 ]]; then
  echo
  echo "This was a dry-run. Re-run with --apply to write files."
fi
