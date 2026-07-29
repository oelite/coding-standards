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
  # Walk to .worktrees
  while [[ "$(basename "$d")" != ".worktrees" && "$d" != "/" ]]; do
    d="$(dirname "$d")"
  done
  # d = <repo>/.worktrees. Iterate siblings to find the one containing our path.
  for wt in "$d"/*/; do
    [[ -d "$wt" ]] || continue
    # Normalise the worktree path (resolve symlinks for the comparison).
    local wt_canon="$wt"
    if command -v python3 >/dev/null 2>&1; then
      wt_canon="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt" 2>/dev/null || echo "$wt")"
    fi
    # Use git from inside this candidate worktree to get its own toplevel.
    local top
    top="$(cd "$wt" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -z "$top" ]] && continue
    # Match if the input file (or its nearest existing ancestor) is inside top.
    local pp="$p"
    while [[ ! -e "$pp" && "$pp" != "/" ]]; do pp="$(dirname "$pp")"; done
    case "$pp" in
      "$top"/*|"$top") printf '%s\n' "$top"; return 0 ;;
    esac
  done
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

exit 0
