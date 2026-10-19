#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/oelite-gitlab-env.sh" || {
  echo "[ERROR] Failed to source oelite-gitlab-env.sh" >&2
  exit 1
}

ALL_AGENTS=(emma marcus daniel sophia jonathan olivia ethan maya victor grace felix isabella)

typeset -A AGENT_IDS AGENT_USERNAMES AGENT_EMAILS AGENT_DISPLAY_NAMES
AGENT_IDS=(emma 7 marcus 8 daniel 6 sophia 9 jonathan 10 olivia 11 ethan 12 maya 13 victor 14 grace 15 felix 16 isabella 17)
AGENT_USERNAMES=(emma emma.phanes marcus marcus.phanes daniel daniel.phanes sophia sophia.phanes jonathan jonathan.phanes olivia olivia.phanes ethan ethan.phanes maya maya.phanes victor victor.phanes grace grace.phanes felix felix.phanes isabella isabella.phanes)
AGENT_EMAILS=(emma emma@phanes.ltd marcus marcus@phanes.ltd daniel daniel@phanes.ltd sophia sophia@phanes.ltd jonathan jonathan@phanes.ltd olivia olivia@phanes.ltd ethan ethan@phanes.ltd maya maya@phanes.ltd victor victor@phanes.ltd grace grace@phanes.ltd felix felix@phanes.ltd isabella isabella@phanes.ltd)
AGENT_DISPLAY_NAMES=(emma Emma marcus Marcus daniel Daniel sophia Sophia jonathan Jonathan olivia Olivia ethan Ethan maya Maya victor Victor grace Grace felix Felix isabella Isabella)

_API_RESPONSE=""
_API_STATUS=""

json_get() {
  python3 -c '
import sys, json
raw = sys.stdin.read()
out = []
in_str = False
esc = False
for c in raw:
    if esc:
        out.append(c)
        esc = False
    elif c == "\\\\":
        out.append(c)
        esc = True
    elif c == "\"":
        in_str = not in_str
        out.append(c)
    elif c in ("\n","\r") and in_str:
        out.append("\\\\n")
    else:
        out.append(c)
d = json.loads("".join(out))
v = d.get(sys.argv[1])
print(v if v is not None else sys.argv[2])
' "$1" "$2"
}

json_encode_value() {
  printf '%s' "$1" | python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
}

url_encode_path() {
  echo "${1//\//%2F}"
}

# URL-encodes a query-string value (not a path). Preserves alphanumerics and / .
# Uses Python urllib.parse.quote to handle spaces, &, #, +, quotes, etc.
url_encode_query() {
  python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# FIX #48: escapes a value for safe use in the *replacement* half of a sed
# s|pat|repl| expression: backslash first, then `&` (whole-match), then the
# `|` delimiter itself. Quotes, backticks and `$` in the value are safe
# because the shell expands the variable exactly once and sed does not
# re-evaluate the replacement text.
scope_kv_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf '%s' "$s"
}

get_pat() {
  local agent="$1"
  local var_name="OELITE_PAT_${agent:u}"
  local pat="${${(P)var_name}:-}"
  if [[ -z "$pat" ]]; then
    local alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
    pat="${${(P)alias_name}:-}"
  fi
  echo "$pat"
}

get_agent_id() {
  echo "${AGENT_IDS[$1]:-}"
}

get_agent_name() {
  echo "${AGENT_DISPLAY_NAMES[$1]:-$1}"
}

get_agent_email() {
  echo "${AGENT_EMAILS[$1]:-}"
}

validate_agent() {
  local agent="$1"
  if [[ -z "${AGENT_IDS[$agent]:-}" ]]; then
    echo "[ERROR] Unknown agent: $agent" >&2
    echo "Valid agents: ${(j:, :)ALL_AGENTS}" >&2
    return 1
  fi
}

api_call() {
  local method="$1"
  local endpoint="$2"
  local pat="$3"
  local data="${4:-}"

  if [[ -z "$pat" ]]; then
    _API_STATUS="401"
    _API_RESPONSE='{"error":"PAT is empty — the token was not found in Keychain or was invalidated during validation. Run `oelite-gitlab.sh setup` to verify PAT status."}'
    return 1
  fi

  local tmpfile
  tmpfile=$(mktemp)

  local -a curl_args
  curl_args=(
    -s -w "%{http_code}"
    -o "$tmpfile"
    --header "PRIVATE-TOKEN: $pat"
    --header "Content-Type: application/json"
    --request "$method"
    "$OELITE_GITLAB_API$endpoint"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(--data-binary @- --header "Content-Length: ${#data}")
  fi

  _API_STATUS=$(printf '%s' "$data" | curl "${curl_args[@]}")
  _API_RESPONSE=$(<"$tmpfile")
  rm -f "$tmpfile"
}

api_get() {
  api_call "GET" "$1" "$2"
}

api_post() {
  api_call "POST" "$1" "$2" "$3"
}

api_put() {
  api_call "PUT" "$1" "$2" "$3"
}

api_patch() {
  api_call "PATCH" "$1" "$2" "$3"
}

resolve_project_id() {
  local project_path="$1"
  local encoded_path pat
  encoded_path=$(url_encode_path "$project_path")
  pat=$(get_pat "${2:-emma}")
  api_get "/projects/$encoded_path" "$pat"
  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to resolve project $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi
  python3 -c 'import json,sys; value=json.load(sys.stdin).get("id"); print(value if value is not None else "")' <<< "$_API_RESPONSE"
}

api_error_hint() {
  local http_status="$1"
  local project_path="${2:-}"

  case "$http_status" in
    401)
      echo "[HINT] 401 means the PAT is missing, invalid, or expired. Run 'oelite-gitlab.sh setup' to verify." >&2
      ;;
    404)
      echo "[HINT] 404 usually means the resource is private/inaccessible with this PAT, or the path is wrong." >&2
      [[ -n "$project_path" ]] && echo "       Project path used: $project_path" >&2
      echo "       Verify: (1) PAT validity with 'oelite-gitlab.sh setup', (2) project membership, (3) full namespace is 'oelite/<family>/<repo>'." >&2
      ;;
    403)
      echo "[HINT] 403 means the PAT is valid but the user lacks permission for this action." >&2
      ;;
  esac
}

repo_root() {
  local root
  root=$(main_repo_root 2>/dev/null)
  if [[ -z "$root" || "$root" == "$(pwd)" && ! -d "$root/.git" && ! -f "$root/.git" ]]; then
    echo "[ERROR] Not inside a git repository" >&2
    return 1
  fi
  echo "$root"
}

worktree_path() {
  local agent="$1"
  local issue="${2:-}"
  local root
  root=$(repo_root)
  if [[ -n "$issue" ]]; then
    echo "$root/.worktrees/${agent}-${issue}"
  else
    echo "$root/.worktrees/$agent"
  fi
}

check_worktree_exists() {
  local agent="$1"
  local issue="${2:-}"
  local wt_path
  wt_path=$(worktree_path "$agent" "$issue")
  if [[ ! -d "$wt_path" ]]; then
    echo "[ERROR] Worktree not found for ${agent}${issue:+ (issue #$issue)} (expected: $wt_path)" >&2
    return 1
  fi
}

parse_worktree_id() {
  local wt_id="$1"
  local agent=""
  local issue=""
  if [[ "$wt_id" =~ ^([a-z]+)-([0-9]+)$ ]]; then
    agent="${match[1]}"
    issue="${match[2]}"
  else
    agent="$wt_id"
  fi
  echo "$agent $issue"
}

# Scans for orphan worktree directories on disk (not tracked by git).
# An orphan is a .worktrees/<agent>* directory that exists on disk but is NOT
# in git's worktree list — e.g. from a failed worktree-create, manual deletion,
# or interrupted operation. Prints orphan paths (one per line) to stdout.
# Exits 0 if no orphans found, 1 if orphans found.
detect_orphan_worktrees() {
  local agent="$1"
  local root
  root=$(main_repo_root 2>/dev/null || true)
  if [[ -z "$root" ]]; then
    return 0
  fi

  local wt_base="$root/.worktrees"
  if [[ ! -d "$wt_base" ]]; then
    return 0
  fi

  # Use Python for reliable symlink resolution, path comparisons, and subprocess
  # interaction — avoids zsh local-scoping quirks and multi-line string edge cases.
  python3 -c "
import os, sys, subprocess, json

agent = sys.argv[1]
root = os.path.realpath(sys.argv[2])
wt_base = os.path.join(root, '.worktrees')

# Gather git-tracked worktrees inside .worktrees/ (use realpath for consistency)
tracked = set()
try:
    result = subprocess.run(
        ['git', '-C', root, 'worktree', 'list', '--porcelain'],
        capture_output=True, text=True, check=True
    )
    for line in result.stdout.splitlines():
        if line.startswith('worktree '):
            p = os.path.realpath(line[len('worktree '):].strip())
            if p.startswith(wt_base + os.sep):
                tracked.add(p)
except Exception:
    pass

# Scan disk for agent-prefixed dirs not in tracked set
orphans = []
if os.path.isdir(wt_base):
    for entry in os.scandir(wt_base):
        if not entry.is_dir():
            continue
        if not entry.name.startswith(agent):
            continue
        p = os.path.realpath(entry.path)
        if p not in tracked:
            orphans.append(p)

for o in orphans:
    print(o)

sys.exit(1 if orphans else 0)
" "$agent" "$root" 2>/dev/null
}

print_separator() {
  printf '%0.s─' {1..$1}
  printf '\n'
}

cmd_setup() {
  local all_ok=true

  printf "%-12s │ %-20s │ %-4s │ %-24s │ %s\n" "AGENT" "USERNAME" "ID" "EMAIL" "STATUS"
  print_separator 80

  for agent in $ALL_AGENTS; do
    pat=$(get_pat "$agent")
    if [[ -z "$pat" ]]; then
      printf "%-12s │ %-20s │ %-4s │ %-24s │ %s\n" "$agent" "—" "—" "—" "FAIL (no PAT)"
      all_ok=false
      continue
    fi

    api_get "/user" "$pat"

    if [[ "$_API_STATUS" == "200" ]]; then
      username=$(echo "$_API_RESPONSE" | json_get "username" "")
      id=$(echo "$_API_RESPONSE" | json_get "id" "")
      email=$(echo "$_API_RESPONSE" | json_get "email" "")
      printf "%-12s │ %-20s │ %-4s │ %-24s │ %s\n" "$agent" "$username" "$id" "$email" "OK"
    else
      printf "%-12s │ %-20s │ %-4s │ %-24s │ %s\n" "$agent" "—" "—" "—" "FAIL (HTTP $_API_STATUS)"
      all_ok=false
    fi
  done

  if $all_ok; then
    echo ""
    echo "[OK] All 12 agent PATs verified."
    return 0
  else
    echo ""
    echo "[FAIL] One or more PATs failed verification."
    return 1
  fi
}

cmd_issues() {
  local project_path="$1"
  shift

  local label_filter=""
  local assignee_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label)    label_filter="$2"; shift 2 ;;
      --assignee) assignee_filter="$2"; shift 2 ;;
      *)          echo "[ERROR] Unknown option: $1" >&2; return 1 ;;
    esac
  done

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local endpoint="/projects/$encoded_path/issues?scope=all&state=opened&per_page=100"

  if [[ -n "$label_filter" ]]; then
    local encoded_label
    encoded_label=$(url_encode_query "$label_filter")
    endpoint+="&labels=$encoded_label"
  fi

  if [[ -n "$assignee_filter" ]]; then
    validate_agent "$assignee_filter" || return 1
    local assignee_id
    assignee_id=$(get_agent_id "$assignee_filter")
    endpoint+="&assignee_id=$assignee_id"
  fi

  local pat
  pat=$(get_pat "emma")
  api_get "$endpoint" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch issues (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import sys, json
issues = json.load(sys.stdin)
if not issues:
    print("No open issues found.")
    sys.exit(0)
print("{:<6} | {:<50} | {:<20} | {:<18} | {:<10}".format("IID", "Title", "Labels", "Assignee", "Created"))
print("-" * 115)
for i in issues:
    iid = str(i.get("iid", ""))
    title = i.get("title", "")[:50]
    labels = ",".join(i.get("labels", []))[:20]
    assignee = i.get("assignee", {})
    assignee_name = assignee.get("username", "") if assignee else ""
    created = i.get("created_at", "")[:10]
    print("{:<6} | {:<50} | {:<20} | {:<18} | {:<10}".format(iid, title, labels, assignee_name, created))
print()
print("Total: " + str(len(issues)) + " open issue(s)")
'
}

cmd_issue_show() {
  local project_path="$1"
  local iid="$2"

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/issues/$iid" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch issue #$iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import sys, json
i = json.load(sys.stdin)
print("IID:           #" + str(i.get("iid", "")))
print("Title:         " + i.get("title", ""))
print("State:         " + i.get("state", ""))
print("Author:        " + (i.get("author", {}).get("username", "") if i.get("author") else ""))
print("Assignee:      " + (i.get("assignee", {}).get("username", "") if i.get("assignee") else "(unassigned)"))
print("Labels:        " + ",".join(i.get("labels", [])))
print("Created:       " + i.get("created_at", ""))
print("Updated:       " + i.get("updated_at", ""))
print("Web URL:       " + i.get("web_url", ""))
print("---")
print(i.get("description", "(no description)"))
'
}

cmd_print_notes() {
  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import sys, json
notes = json.load(sys.stdin)
if not notes:
    print("(no notes)")
    sys.exit(0)
for n in notes:
    if n.get("system"):
        continue
    author = (n.get("author") or {}).get("username", "(unknown)")
    print("=== Note id=%s | %s | %s ===" % (n.get("id", ""), author, n.get("created_at", "")))
    print(n.get("body", ""))
    print()
'
}

cmd_mr_notes() {
  local project_path="${1:-}"
  local mr_iid="${2:-}"
  local agent="${3:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$mr_iid" ]] && { echo "[ERROR] MR IID required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")
  api_get "/projects/$encoded_path/merge_requests/$mr_iid/notes?per_page=100&sort=asc&order_by=created_at" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch notes for MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  cmd_print_notes
}

cmd_issue_notes() {
  local project_path="${1:-}"
  local iid="${2:-}"
  local agent="${3:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$iid" ]] && { echo "[ERROR] Issue IID required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")
  api_get "/projects/$encoded_path/issues/$iid/notes?per_page=100&sort=asc&order_by=created_at" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch notes for issue #$iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  cmd_print_notes
}

cmd_issue_create() {
  local project_path="$1"
  local agent="$2"
  local title="$3"
  local description="${4:-}"

  validate_agent "$agent" || return 1
  [[ -z "$title" ]] && { echo "[ERROR] Title required" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(printf '%s\n%s' "$title" "$description" | python3 -c "
import json, sys
lines = sys.stdin.read().split('\n', 1)
title = lines[0]
desc = lines[1] if len(lines) > 1 else ''
payload = {'title': title}
if desc:
    payload['description'] = desc
print(json.dumps(payload))
")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/issues" "$pat" "$data"

  if [[ "$_API_STATUS" == "201" ]]; then
    local iid issue_url issue_title
    iid=$(echo "$_API_RESPONSE" | json_get "iid" "")
    issue_url=$(echo "$_API_RESPONSE" | json_get "web_url" "")
    issue_title=$(echo "$_API_RESPONSE" | json_get "title" "")
    echo "[OK] Issue created by $agent"
    echo "  IID:    #$iid"
    echo "  URL:    $issue_url"
    echo "  Title:  $issue_title"
  else
    echo "[ERROR] Failed to create issue (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_issue_assign() {
  local project_path="$1"
  local iid="$2"
  local agent="$3"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")
  local user_id
  user_id=$(get_agent_id "$agent")

  local data
  data=$(python3 -c "import json; print(json.dumps({'assignee_ids': [$user_id]}))")

  local pat
  pat=$(get_pat "$agent")
  api_put "/projects/$encoded_path/issues/$iid" "$pat" "$data"

  if [[ "$_API_STATUS" == "200" ]]; then
    local title
    title=$(echo "$_API_RESPONSE" | json_get "title" "")
    echo "[OK] Issue #$iid assigned to $agent (${AGENT_USERNAMES[$agent]})"
    echo "  Title: $title"
  else
    echo "[ERROR] Failed to assign issue #$iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_issue_comment() {
  local project_path="$1"
  local iid="$2"
  local agent="$3"
  local message="$4"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(python3 -c "import json; print(json.dumps({'body': $(json_encode_value "$message")}))")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/issues/$iid/notes" "$pat" "$data"

  if [[ "$_API_STATUS" == "201" ]]; then
    local note_id
    note_id=$(echo "$_API_RESPONSE" | json_get "id" "")
    echo "[OK] Comment posted on issue #$iid by $agent (note_id: $note_id)"
  else
    echo "[ERROR] Failed to post comment (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_issue_status() {
  local project_path="$1"
  local iid="$2"
  local agent="$3"
  local new_status="$4"

  validate_agent "$agent" || return 1
  [[ -z "$new_status" ]] && { echo "[ERROR] Status required" >&2; return 1; }

  local valid_states="opened closed"
  case " $valid_states " in
    *" $new_status "*) ;;
    *) { echo "[ERROR] Invalid status '$new_status'. Use: opened or closed" >&2; return 1; } ;;
  esac

  local state_event
  case "$new_status" in
    opened) state_event="reopen" ;;
    closed) state_event="close" ;;
  esac

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(python3 -c "import json; print(json.dumps({'state_event': '$state_event'}))")

  local pat
  pat=$(get_pat "$agent")
  api_put "/projects/$encoded_path/issues/$iid" "$pat" "$data"

  if [[ "$_API_STATUS" -ge 200 && "$_API_STATUS" -lt 300 ]]; then
    echo "[OK] Issue #$iid status set to $new_status by $agent"
  else
    echo "[ERROR] Failed to set issue status (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_issue_label() {
  local project_path="$1"
  local iid="$2"
  local agent="$3"
  shift 3

  validate_agent "$agent" || return 1

  if [[ $# -eq 0 ]]; then
    echo "[ERROR] At least one label required" >&2
    return 1
  fi

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")

  local data
  data=$(python3 -c "
import json, sys
labels = sys.argv[1:]
print(json.dumps({'labels': labels}))
" "$@")

  api_put "/projects/$encoded_path/issues/$iid" "$pat" "$data"

  if [[ "$_API_STATUS" -ge 200 && "$_API_STATUS" -lt 300 ]]; then
    echo "[OK] Issue #$iid labels updated by $agent: $*"
  else
    echo "[ERROR] Failed to update issue labels (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_worktree_create() {
  local agent="$1"
  local branch="$2"
  local base_branch="develop"
  local owner="$agent"
  local issue=""
  local no_issue=false
  local force_preflight=false

  if [[ -z "$agent" || -z "$branch" ]]; then
    echo "[ERROR] worktree-create requires: <agent> <branch> [--base <branch>] [--issue <iid>] [--no-issue] [--owner <agent>] [--force]" >&2
    return 1
  fi

  validate_agent "$agent" || return 1

  # Backward-compat: if $3 is set and does NOT start with '--', treat it as
  # the legacy positional base_branch. This preserves the documented call form
  # `worktree-create <agent> <branch> <base> --issue <iid>` while also allowing
  # the new form `worktree-create <agent> <branch> --issue <iid>` (no base).
  if [[ -n "${3:-}" && "$3" != --* ]]; then
    base_branch="$3"
    shift 3
  else
    shift 2
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        if [[ -z "${2:-}" ]]; then
          echo "[ERROR] --base requires a value (branch name)" >&2
          return 1
        fi
        base_branch="$2"
        shift 2
        ;;
      --owner)
        if [[ -z "${2:-}" ]]; then
          echo "[ERROR] --owner requires a value" >&2
          return 1
        fi
        owner="$2"
        shift 2
        ;;
      --issue)
        if [[ -z "${2:-}" ]]; then
          echo "[ERROR] --issue requires a value (issue IID number)" >&2
          return 1
        fi
        issue="$2"
        shift 2
        ;;
      --no-issue)
        no_issue=true
        shift
        ;;
      --force)
        force_preflight=true
        shift
        ;;
      *)
        echo "[ERROR] Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$issue" && "$no_issue" == false ]]; then
    echo "[WARN] No --issue specified. Per OElite Issue-First workflow," >&2
    echo "       every work MUST have a GitLab issue ticket before starting." >&2
    echo "       Create one via 'issue-create' using ISSUE-MR-TEMPLATES.md." >&2
    echo "" >&2
    echo "       If this work genuinely does not require an issue ticket," >&2
    echo "       re-run with --no-issue to bypass this warning:" >&2
    echo "" >&2
    echo "         oelite-gitlab.sh worktree-create $agent $branch --no-issue" >&2
    echo "" >&2
    echo "[ERROR] Refusing to create worktree without --issue or --no-issue." >&2
    return 1
  fi

   # Pre-flight: HARD GATE on stale worktrees for the same agent (GIT-WORKFLOW-STANDARDS.md §1.8).
  # Blocks worktree creation when the agent has a worktree whose linked MR is
  # already merged/closed, or whose dir is gone (prunable orphan) — the exact
  # condition `worktree-cleanup --all` removes. An *open* MR (or a branch with
  # no matching MR yet) is advisory, so legitimate parallel work is unaffected.
  # Bypass: OELITE_HUMAN=1 (human maintenance) or --force (spike/parallel escape hatch).
  local preflight_gitlab_project=""
  preflight_gitlab_project=$(get_gitlab_project_path "$(main_repo_root 2>/dev/null || repo_root)" 2>/dev/null || true)
  if ! $force_preflight && [[ -z "${OELITE_HUMAN:-}" ]]; then
    local preflight_root preflight_root_resolved preflight_wt_path preflight_wt_branch preflight_stale=false preflight_blocked=false
    preflight_root=$(main_repo_root 2>/dev/null || true)
    if [[ -n "$preflight_root" && -d "$preflight_root" ]]; then
      # Resolve symlinks (e.g. macOS /tmp → /private/tmp) so the path comparison
      # below matches whatever 'git worktree list --porcelain' returns.
      preflight_root_resolved=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]))" "$preflight_root" 2>/dev/null || echo "$preflight_root")
      local preflight_line preflight_wt_state
      # Classify a matching worktree: "orphan" | "merged" | "closed" | "open" | "not_found"
      _preflight_classify() {
        if $preflight_stale; then
          echo "orphan"
        else
          get_mr_state_for_branch "$preflight_gitlab_project" "$preflight_wt_branch"
        fi
      }
      _preflight_report() {
        # $1 = wt_state
        local wt_state="$1"
        case "$wt_state" in
          orphan|merged|closed)
            preflight_blocked=true
            echo "" >&2
            echo "[BLOCKED] Stale worktree for agent '$agent' must be cleaned up first:" >&2
            echo "       $preflight_wt_path (branch: $preflight_wt_branch, MR=$wt_state)" >&2
            echo "       Per GIT-WORKFLOW-STANDARDS.md §1.8 (hard gate)." >&2
            echo "" >&2
            echo "       Run:  oelite-gitlab.sh worktree-cleanup $agent --delete-branch" >&2
            echo "       Or:   oelite-gitlab.sh worktree-cleanup --all" >&2
            echo "" >&2
            echo "       To proceed anyway (spike/parallel work), re-run with --force," >&2
            echo "       or set OELITE_HUMAN=1 for a human-maintenance session." >&2
            ;;
          *)
            echo "" >&2
            echo "[WARN] Active worktree exists for agent '$agent':" >&2
            echo "       $preflight_wt_path (branch: $preflight_wt_branch, MR=$wt_state)" >&2
            echo "       Per GIT-WORKFLOW-STANDARDS.md §1.8, clean up after each task." >&2
            echo "" >&2
            echo "       Run:  oelite-gitlab.sh worktree-cleanup $agent --delete-branch" >&2
            ;;
        esac
      }
      while IFS= read -r preflight_line; do
        case "$preflight_line" in
          "")  # Record delimiter — evaluate the worktree we just finished parsing
            if [[ -n "$preflight_wt_path" && "$preflight_wt_path" == "$preflight_root_resolved/.worktrees/$agent"* ]]; then
              _preflight_report "$(_preflight_classify)"
            fi
            preflight_wt_path=""; preflight_wt_branch=""; preflight_stale=false
            ;;
          worktree\ *) preflight_wt_path="${preflight_line#worktree }" ;;
          branch\ *)   preflight_wt_branch="${preflight_line#branch refs/heads/}" ;;
          prunable\ *) preflight_stale=true ;;
        esac
      done < <(git -C "$preflight_root" worktree list --porcelain 2>/dev/null)

      # Handle the last record (no trailing blank line)
      if [[ -n "$preflight_wt_path" && "$preflight_wt_path" == "$preflight_root_resolved/.worktrees/$agent"* ]]; then
        _preflight_report "$(_preflight_classify)"
      fi
    fi

    if $preflight_blocked; then
      echo "[ERROR] Refusing to create worktree — stale worktree(s) for agent '$agent'. Run worktree-cleanup first." >&2
      return 1
    fi
  fi

  if [[ "$owner" != "$agent" ]]; then
    if [[ -z "${AGENT_IDS[$owner]:-}" ]]; then
      echo "[ERROR] Unknown owner: $owner" >&2
      echo "Valid owners: ${(j:, :)ALL_AGENTS}" >&2
      return 1
    fi
  fi

  local root
  root=$(repo_root)
  local wt_suffix="$agent"
  if [[ -n "$issue" ]]; then
    wt_suffix="${agent}-${issue}"
  fi
  local wt_path="$root/.worktrees/$wt_suffix"

  if [[ -d "$wt_path" ]]; then
    echo "[ERROR] Worktree already exists for $wt_suffix at $wt_path" >&2
    return 1
  fi

  # ── Orphan worktree collision check ──
  # Detect orphaned worktree directories (e.g. from failed/interrupted operations)
  # before attempting git worktree add. An orphan is a .worktrees/<agent>* dir on disk
  # that is not tracked by git — git would refuse with "fatal: '<path>' already exists".
  # Suggest cleanup so the user is not stuck.
  local orphans=""
  detect_orphan_worktrees "$agent" > /tmp/oelite-orphans-$$.txt 2>/dev/null || true
  orphans=$(</tmp/oelite-orphans-$$.txt)
  rm -f /tmp/oelite-orphans-$$.txt
  if [[ -n "$orphans" ]]; then
    echo "[ERROR] Orphaned worktree directory detected for agent '$agent':" >&2
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "       $line" >&2
    done <<< "$orphans"
    echo "" >&2
    echo "[ERROR] git worktree add would fail because the directory already exists." >&2
    echo "       This is typically caused by a failed or interrupted worktree-create." >&2
    echo "" >&2
    echo "       To clean up and proceed, run:" >&2
    echo "         oelite-gitlab.sh worktree-cleanup $agent --delete-branch" >&2
    echo "" >&2
    echo "       Or remove manually:" >&2
    while IFS= read -r line; do
      [[ -n "$line" ]] && echo "         rm -rf \"$line\"" >&2
    done <<< "$orphans"
    echo "" >&2
    echo "[ERROR] Refusing to create worktree on top of orphan directory." >&2
    return 1
  fi

  # ── Check if local develop is stale (sync warning) ──
  if git show-ref --verify --quiet "refs/remotes/origin/develop" 2>/dev/null; then
    local behind_count
    behind_count=$(git rev-list --left-right --count "develop...origin/develop" 2>/dev/null | awk '{print $2}' || echo "0")
    if [[ "$behind_count" -gt 0 ]]; then
      echo "[WARN] Local develop is $behind_count commits behind origin/develop" >&2
      echo "       Recommend: oelite-gitlab.sh worktree-sync" >&2
      echo "       Or (refreshes origin/develop only, never the checked-out branch): git fetch origin --prune develop" >&2
    fi
  fi

  echo "Fetching latest from origin..."
  git fetch origin --quiet

  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    if ! git show-ref --verify --quiet "refs/remotes/origin/$base_branch"; then
      echo "[ERROR] Base branch origin/$base_branch not found" >&2
      return 1
    fi
    echo "Creating branch $branch from origin/$base_branch..."
    git branch "$branch" "origin/$base_branch"
  fi

  echo "Creating worktree at $wt_path..."
  git worktree add "$wt_path" "$branch"

  git config extensions.worktreeConfig true

  local owner_name
  owner_name=$(get_agent_name "$owner")
  local owner_email
  owner_email=$(get_agent_email "$owner")

  git -C "$wt_path" config --worktree user.name "$owner_name"
  git -C "$wt_path" config --worktree user.email "$owner_email"

  echo "$owner" > "$wt_path/.git-worktree-owner"

  local repo_rel_path
  repo_rel_path=$(basename "$root")
  local gitlab_project="oelite/$(git -C "$root" remote get-url origin 2>/dev/null | sed 's|.*oelite/||; s|\.git$||' || echo "unknown/$repo_rel_path")"

  cat > "$wt_path/.oe-scope" <<OE_SCOPE
# OElite Worktree Scope — auto-generated by worktree-create
# This file is NOT committed (gitignored). It is a per-worktree context anchor.
# After context compaction, read this file to restore your working scope.
AGENT=$agent
WORKTREE=$wt_path
WORKTREE_REL=.worktrees/$wt_suffix
BRANCH=$branch
REPO=$repo_rel_path
REPO_ROOT=$root
GITLAB_PROJECT=$gitlab_project
TASK_TYPE=
ISSUE=$issue
TASK_DESCRIPTION=
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OE_SCOPE

  if ! grep -qx '.oe-scope' "$wt_path/.gitignore" 2>/dev/null; then
    echo '.oe-scope' >> "$wt_path/.gitignore"
  fi

  # ── Install pre-commit hook (worktree enforcement) ──
  # In a worktree, $wt_path/.git is a file (gitdir pointer), not a directory.
  # The real gitdir comes from `git rev-parse --git-dir`, which is the only
  # path where `hooks/` is actually a directory.
  local hook_src="$SCRIPT_DIR/hooks/pre-commit"
  local hook_gitdir hook_dst
  hook_gitdir=$(git -C "$wt_path" rev-parse --git-dir 2>/dev/null || true)
  if [[ -z "$hook_gitdir" ]]; then
    hook_dst="$wt_path/.git/hooks/pre-commit"
  else
    # Resolve relative paths (e.g. ".git") against the worktree root.
    case "$hook_gitdir" in
      /*) hook_dst="$hook_gitdir/hooks/pre-commit" ;;
      *)  hook_dst="$wt_path/$hook_gitdir/hooks/pre-commit" ;;
    esac
  fi
  if [[ -f "$hook_src" ]]; then
    mkdir -p "$(dirname "$hook_dst")"
    cp "$hook_src" "$hook_dst"
    chmod +x "$hook_dst"
    echo "  Hook:   pre-commit hook installed at $hook_dst"
  else
    echo "  [WARN] Pre-commit hook source not found at: $hook_src" >&2
  fi

  if [[ "$owner" != "$agent" ]]; then
    echo "[OK] Worktree created for executor $agent (owner: $owner)"
  else
    echo "[OK] Worktree created for $wt_suffix"
  fi
  echo "  Path:   $wt_path"
  echo "  Branch: $branch"
  echo "  Owner:  $owner_name <$owner_email> (owner DNA)"
  echo "  Scope:  $wt_path/.oe-scope (compaction-resilient context anchor)"
  if [[ -n "$issue" ]]; then
    echo "  Issue:  #$issue"
  fi
  if [[ "$owner" != "$agent" ]]; then
    echo "  Executor: $agent (using owner's GitLab identity)"
  fi
  echo ""
  echo "  To update scope after task assignment:"
  if [[ -n "$issue" ]]; then
    echo "    ../../coding-standards/scripts/oelite-gitlab.sh oe-scope $agent $issue --task-type backend-impl --desc 'Implement JWT refresh'"
  else
    echo "    ../../coding-standards/scripts/oelite-gitlab.sh oe-scope $agent --task-type backend-impl --desc 'Implement JWT refresh'"
  fi
  echo ""
  echo "  ⚠️  IMPORTANT: After sync, do NOT work in the main directory."
  echo "     Always cd into the worktree: cd .worktrees/$wt_suffix/"
  echo "     The pre-commit hook will block commits outside the worktree."
}

cmd_worktree_sync() {
  # ── Safe sync: updates local develop without checking it out ──
  # Replaces the dangerous pattern: git checkout develop && git pull origin develop
  # This avoids the footgun of switching to develop and then forgetting to switch back.
  local root
  root=$(repo_root)

  echo "Syncing local develop from origin/develop (without switching branch)..."
  echo ""

  # Check if we're in a worktree — if so, warn
  if [[ "$root" == *"/.worktrees/"* ]]; then
    echo "[WARN] You are inside a worktree. The sync command updates the main"
    echo "       directory's develop branch. Run this from the main repo root."
    echo "       Current worktree: $root"
    echo "       To sync this worktree's feature branch, use: oelite-gitlab.sh sync <agent>"
    echo ""
    echo "       Continuing anyway..."
    echo ""
  fi

  # Explicit destination works even with a restricted remote fetch configuration.
  git fetch --no-tags origin '+refs/heads/develop:refs/remotes/origin/develop' --quiet 2>&1 || {
    echo "[ERROR] Failed to fetch origin/develop. Check network, origin access, or missing remote develop branch." >&2
    return 1
  }
  echo "[OK] origin/develop refreshed"

  local records line checkout_path="" pinned=false
  records=$(git worktree list --porcelain) || return 1
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) checkout_path="${line#worktree }" ;;
      'branch refs/heads/develop')
        echo "[INFO] Local develop unchanged: checked out at $checkout_path"
        pinned=true
        ;;
    esac
  done <<< "$records"
  $pinned && return 0

  local old target
  target=$(git rev-parse refs/remotes/origin/develop) || return 1
  old=$(git rev-parse --verify refs/heads/develop 2>/dev/null) || old=""
  if [[ -n "$old" ]] && ! git merge-base --is-ancestor "$old" "$target"; then
    echo "[WARN] Local develop is ahead or divergent; preserved. origin/develop is current."
    return 0
  fi
  # Compare-and-swap prevents overwriting a concurrently advanced branch.
  git update-ref refs/heads/develop "$target" "$old" || return 1
  echo "[OK] Local develop synced to origin/develop (fast-forward only)"
  echo "  Current HEAD: $(git log -1 --oneline develop)"
}

cmd_worktree_list() {
  local root
  root=$(repo_root)

  printf "%-12s │ %-35s │ %-12s │ %s\n" "AGENT" "BRANCH" "LAST COMMIT" "PATH"
  print_separator 100

  local found=false

  git worktree list --porcelain | while read -r line; do
    case "$line" in
      worktree\ *)
        wt_path="${line#worktree }"
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      HEAD\ *)
        ;;
      "")
        if [[ "$wt_path" == "$root/.worktrees/"* ]]; then
          agent_name="${wt_path#$root/.worktrees/}"
          found=true

          last_commit_date=$(git -C "$wt_path" log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1)
          if [[ -z "$last_commit_date" ]]; then
            last_commit_date="—"
          fi

          behind_count=""
          if git -C "$wt_path" show-ref --verify --quiet "refs/remotes/origin/develop" 2>/dev/null; then
            behind_count=$(git -C "$wt_path" rev-list --left-right --count "origin/develop...HEAD" 2>/dev/null | awk '{print $2}')
            if [[ "$behind_count" -gt 0 ]] 2>/dev/null; then
              behind_count=" (↓$behind_count)"
            else
              behind_count=""
            fi
          fi

          printf "%-12s │ %-35s │ %-12s │ %s%s\n" "$agent_name" "$branch" "$last_commit_date" "$wt_path" "$behind_count"
        fi
        wt_path=""
        branch=""
        ;;
    esac
  done

  if ! git worktree list --porcelain | grep -q "$root/.worktrees/"; then
    echo "No active agent worktrees found."
  fi
}

cmd_worktree_remove() {
  local wt_id="$1"
  shift

  local delete_branch=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --delete-branch) delete_branch=true; shift ;;
      *)               echo "[ERROR] Unknown option: $1" >&2; return 1 ;;
    esac
  done

  local parsed
  parsed=$(parse_worktree_id "$wt_id")
  local agent="${parsed% *}"
  local issue="${parsed#* }"

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" "$issue" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent" "$issue")
  local branch
  branch=$(git -C "$wt_path" branch --show-current)

  echo "Removing worktree for $wt_id..."
  git worktree remove "$wt_path"

  if $delete_branch && [[ -n "$branch" ]]; then
    if git branch -D "$branch" 2>/dev/null; then
      echo "  Deleted branch: $branch"
    else
      echo "  [WARN] Could not delete branch: $branch" >&2
    fi
  fi

  echo "[OK] Worktree removed for $wt_id"
}

get_gitlab_project_path() {
  local root="${1:-$(repo_root)}"
  local url_path
  url_path=$(git -C "$root" remote get-url origin 2>/dev/null | sed 's|.*oelite/||; s|\.git$||' || true)
  if [[ -n "$url_path" ]]; then
    echo "oelite/$url_path"
  else
    echo "oelite/$(basename "$root")"
  fi
}

main_repo_root() {
  local gitrepo
  gitrepo=$(git rev-parse --git-common-dir 2>/dev/null)
  if [[ -z "$gitrepo" ]]; then
    echo "[ERROR] Not inside a git repository" >&2
    return 1
  fi
  if [[ "$gitrepo" != /* ]]; then
    gitrepo="$(pwd)/$gitrepo"
  fi
  dirname "$gitrepo"
}

get_mr_state_for_branch() {
  local project_path="$1"
  local source_branch="$2"
  local _api_response _api_count

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat emma)

  for state in opened merged closed; do
    api_get "/projects/$encoded_path/merge_requests?state=${state}&source_branch=${source_branch}&per_page=10" "$pat" 2>/dev/null
    _api_response="$_API_RESPONSE"
    if [[ "$_API_STATUS" == "200" ]]; then
      _api_count=$(printf '%s' "$_api_response" | python3 -c '
import sys, json
try:
  d = json.loads(sys.stdin.read() or "[]")
  print(len(d) if isinstance(d, list) else 0)
except Exception:
  print(0)
' 2>/dev/null) || _api_count=0
      : "${_api_count:=0}"
      if [[ "$_api_count" -gt 0 ]]; then
        echo "$state"
        return 0
      fi
    fi
  done

  echo "not_found"
  return 0
}

cleanup_local_worktree_for_branch() {
  local root="$1" branch="$2"
  [[ -z "$branch" ]] && return 0

  local wt_path
  # FIX #49 (audit): avoid `| head -1` under pipefail; awk prints only the
  # first match itself so no downstream reader can be SIGPIPE'd.
  wt_path=$(git -C "$root" worktree list --porcelain 2>/dev/null | awk -v b="$branch" '
    BEGIN { printed = 0 }
    /^worktree / { w=$2; br="" }
    /^branch /   { split($0, a, "refs/heads/"); br = (a[2] != "" ? a[2] : "") }
    /^$/         { if (br == b && !printed) { print w; printed = 1 } }
    END          { if (br == b && !printed) print w }
  ')

  [[ -z "$wt_path" ]] && return 0

  git -C "$root" worktree prune 2>/dev/null || true

  local active_wt
  active_wt=$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)

  if [[ "$wt_path" == "$active_wt" ]]; then
    echo "  Skipping worktree remove — currently active: ${wt_path#$root/}"
  elif [[ -d "$wt_path" ]]; then
    git -C "$root" worktree remove "$wt_path" --force 2>&1 | sed 's/^/    /' || true
    echo "  Removed worktree: ${wt_path#$root/}"
  else
    echo "  Worktree dir already gone: ${wt_path#$root/}"
  fi

  if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
    if git -C "$root" branch -D "$branch" 2>/dev/null; then
      echo "  Deleted local branch: $branch"
    fi
  fi
}

cmd_worktree_cleanup() {
  local target_agent=""
  local delete_branch=false
  local sweep_all=false
  local check_stale=false
  local do_cleanup=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --delete-branch) delete_branch=true; shift ;;
      --all)           sweep_all=true;   shift ;;
      --check-stale)   check_stale=true; shift ;;
      --cleanup)       do_cleanup=true;   shift ;;
      --agent)         target_agent="$2"; shift 2 ;;
      -*)
        echo "[ERROR] Unknown option: $1" >&2
        echo "Usage: worktree-cleanup <agent> [--delete-branch]" >&2
        echo "       worktree-cleanup --all" >&2
        echo "       worktree-cleanup --check-stale [--agent A]" >&2
        return 1 ;;
      *)
        [[ -z "$target_agent" ]] && target_agent="$1"
        shift ;;
    esac
  done

  local root current_wt_path
  root=$(main_repo_root)
  current_wt_path=$(git rev-parse --show-toplevel 2>/dev/null || true)
  local gitlab_project
  gitlab_project=$(get_gitlab_project_path "$root")

  if $check_stale; then
    local found_stale=false
    echo "=== Worktree Stale Check ==="
    echo "Project: $gitlab_project"
    echo ""

    while read -r line; do
      case "$line" in
        worktree\ *) wt_path="${line#worktree }" ;;
        branch\ *)   branch="${line#branch refs/heads/}" ;;
        prunable\ *) prunable_reason="${line#prunable }" ;;
        "")
          if [[ -n "$wt_path" && "$wt_path" == "$root/.worktrees/"* ]]; then
            local agent_name="${wt_path#$root/.worktrees/}"
            local is_stale=false
            local reason=""

            if [[ -n "${prunable_reason:-}" ]]; then
              is_stale=true
              reason="${prunable_reason} (orphan)"
            fi

            if $is_stale; then
              found_stale=true
              if [[ -z "$target_agent" || "$agent_name" == "$target_agent" ]]; then
                echo "[STALE] $agent_name | reason: $reason"
              fi
            fi
          fi
          wt_path=""; branch=""; prunable_reason="" ;;
      esac
    done < <(git -C "$root" worktree list --porcelain 2>/dev/null)

    if ! $found_stale; then
      echo "No stale worktrees found."
    fi
    if $do_cleanup; then
      echo ""
      echo "=== Pruning stale worktrees ==="
      git -C "$root" worktree prune 2>&1
      echo "[OK] Prune complete."
    else
      echo ""
      echo "To auto-prune, run:"
      echo "  worktree-cleanup --check-stale --cleanup"
    fi
    return 0
  fi

  if $sweep_all; then
    echo "=== Sweeping all worktrees ==="
    echo "Project: $gitlab_project"
    echo ""
    echo "[prune] Running git worktree prune..."
    git -C "$root" worktree prune 2>&1

    local removed_count=0
    local skipped_count=0
    while read -r line; do
      case "$line" in
        worktree\ *) wt_path="${line#worktree }" ;;
        branch\ *)   branch="${line#branch refs/heads/}" ;;
        prunable\ *) prunable_reason="${line#prunable }" ;;
        "")
          if [[ -n "$wt_path" && "$wt_path" == "$root/.worktrees/"* ]]; then
            local agent_name="${wt_path#$root/.worktrees/}"

            if [[ "$wt_path" == "$current_wt_path" ]]; then
              echo "  [SKIP] $agent_name ($branch) — currently in use"
              skipped_count=$((skipped_count + 1))
              wt_path=""; branch=""; prunable_reason=""
              continue
            fi

            if [[ -n "${prunable_reason:-}" ]]; then
              echo "==> $agent_name (orphan: $prunable_reason) — pruning..."
              if [[ -d "$wt_path" ]]; then
                git -C "$root" worktree remove "$wt_path" --force 2>&1 || echo "  [WARN] Could not remove: $wt_path"
              fi
              if [[ -n "$branch" ]] && (git -C "$root" branch --list "$branch" | grep -q . || true); then
                git -C "$root" branch -D "$branch" 2>/dev/null && echo "  Deleted branch: $branch"
              fi
              removed_count=$((removed_count + 1))
            else
              local mr_state
              mr_state=$(get_mr_state_for_branch "$gitlab_project" "$branch")
              if [[ "$mr_state" == "merged" || "$mr_state" == "closed" || "$mr_state" == "not_found" ]]; then
                echo "==> $agent_name ($branch) MR=$mr_state — removing..."
                if [[ -d "$wt_path" ]]; then
                  git -C "$root" worktree remove "$wt_path" --force 2>&1 || echo "  [WARN] Could not remove: $wt_path"
                fi
                if (git -C "$root" branch --list "$branch" | grep -q . || true); then
                  git -C "$root" branch -D "$branch" 2>/dev/null && echo "  Deleted branch: $branch"
                fi
                removed_count=$((removed_count + 1))
              else
                echo "  [SKIP] $agent_name ($branch) MR=$mr_state — still open"
                skipped_count=$((skipped_count + 1))
              fi
            fi
          fi
          wt_path=""; branch=""; prunable_reason="" ;;
      esac
    done < <(git -C "$root" worktree list --porcelain 2>/dev/null)

    echo ""
    echo "=== Sweep Summary ==="
    echo "  Removed: $removed_count"
    echo "  Skipped: $skipped_count"
    echo "  Remaining worktrees:"
    git -C "$root" worktree list --porcelain | grep "$root/.worktrees/" || echo "    (none)"
    return 0
  fi

  if [[ -z "$target_agent" ]]; then
    echo "[ERROR] Missing agent name. Usage: worktree-cleanup <agent> [--delete-branch]" >&2
    return 1
  fi

  validate_agent "$target_agent" || return 1

  # FIX #49: iterate ALL matching worktrees (no `| head -1` under pipefail —
  # head closed the pipe early and SIGPIPE'd the writer as exit 141 when the
  # agent had >1 matching worktree). Each match gets an MR-state guard so an
  # open-MR worktree is never removed silently.
  local wt_matches=()
  while IFS= read -r line; do
    case "$line" in
      worktree\ *) wt_p="${line#worktree }" ;;
      branch\ *)   br="${line#branch refs/heads/}" ;;
      "")
        if [[ "$wt_p" == "$root/.worktrees/$target_agent" || \
              "$wt_p" == "$root/.worktrees/$target_agent-"* ]]; then
          wt_matches+=("$wt_p|$br")
        fi
        wt_p=""; br="" ;;
    esac
  done < <(git -C "$root" worktree list --porcelain 2>/dev/null)

  if [[ ${#wt_matches[@]} -eq 0 ]]; then
    echo "[INFO] No worktree found for agent: $target_agent"
    return 0
  fi

  local cleaned_count=0
  for wt_match in "${wt_matches[@]}"; do
    local wt_path="${wt_match%%|*}"
    local branch="${wt_match#*|}"

    if [[ "$wt_path" == "$current_wt_path" ]]; then
      echo "[SKIP] $wt_path — currently-active worktree (run from main repo or another worktree)"
      continue
    fi

    # MR-state guard (per GIT-WORKFLOW-STANDARDS.md §1.8): never silently remove
    # a worktree whose linked MR is still open.
    local mr_state=""
    if [[ -n "$branch" ]]; then
      mr_state=$(get_mr_state_for_branch "$gitlab_project" "$branch")
    fi
    if [[ -n "$branch" && "$mr_state" != "merged" && "$mr_state" != "closed" && "$mr_state" != "not_found" ]]; then
      echo "[SKIP] $target_agent ($branch) MR=$mr_state — still open; not removing"
      continue
    fi

    echo "=== Cleaning up worktree: $wt_path ==="
    echo "  Branch: ${branch:-<none>}"
    echo "  MR state: ${mr_state:-orphan (no branch)}"
    echo "[prune] Running git worktree prune..."
    git -C "$root" worktree prune 2>&1

    if [[ ! -d "$wt_path" ]]; then
      echo "  Worktree directory already gone (prunable orphan)"
      if [[ -n "$branch" ]] && (git -C "$root" branch --list "$branch" | grep -q . || true); then
        echo "  Deleting local branch: $branch"
        git -C "$root" branch -D "$branch" 2>/dev/null && echo "  [OK] Branch deleted"
      fi
      cleaned_count=$((cleaned_count + 1))
      continue
    fi

    echo "[remove] git worktree remove $wt_path"
    if git -C "$root" worktree remove "$wt_path" 2>&1; then
      echo "  [OK] Worktree removed"
    else
      echo "  [WARN] Standard remove failed, trying --force..."
      git -C "$root" worktree remove "$wt_path" --force 2>&1 || echo "  [WARN] Could not remove worktree"
    fi

    if $delete_branch && [[ -n "$branch" ]]; then
      echo "[branch] Deleting local branch: $branch"
      if git -C "$root" branch -D "$branch" 2>/dev/null; then
        echo "  [OK] Branch deleted"
      else
        echo "  [WARN] Could not delete branch (may not exist)" >&2
      fi
    fi

    cleaned_count=$((cleaned_count + 1))
  done

  echo ""
  echo "[OK] Worktree cleanup complete for $target_agent ($cleaned_count worktree(s) cleaned)"
}

cmd_worktree_check_stale() {
  cmd_worktree_cleanup --check-stale "$@"
}

cmd_mr_create() {
  local project_path="$1"
  local agent="$2"
  local source_branch="$3"
  local target_branch="$4"
  local title="$5"
  local description="${6:-}"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(python3 -c "
import json, sys
mr = {
    'source_branch': $(json_encode_value "$source_branch"),
    'target_branch': $(json_encode_value "$target_branch"),
    'title': $(json_encode_value "$title"),
    'remove_source_branch': True,
    'squash_on_merge': True
}
desc = $(json_encode_value "$description")
if desc:
    mr['description'] = desc
print(json.dumps(mr))
")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/merge_requests" "$pat" "$data"

  if [[ "$_API_STATUS" == "201" ]]; then
    local mr_iid mr_url
    mr_iid=$(echo "$_API_RESPONSE" | json_get "iid" "")
    mr_url=$(echo "$_API_RESPONSE" | json_get "web_url" "")
    echo "[OK] Merge request created"
    echo "  IID:    !$mr_iid"
    echo "  URL:    $mr_url"
    echo "  Title:  $title"
    echo "  $source_branch → $target_branch"
  else
    echo "[ERROR] Failed to create MR (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_mr_list() {
  local project_path="$1"

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/merge_requests?state=opened&per_page=100" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch MRs (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import sys, json
mrs = json.load(sys.stdin)
if not mrs:
    print("No open merge requests found.")
    sys.exit(0)
print("{:<6} | {:<45} | {:<18} | {:<35} | {:<12} | Reviewers".format("IID", "Title", "Author", "Source -> Target", "Status"))
print("-" * 140)
for mr in mrs:
    iid = str(mr.get("iid", ""))
    title = mr.get("title", "")[:45]
    author = mr.get("author", {}).get("username", "")[:18]
    source = mr.get("source_branch", "")
    target = mr.get("target_branch", "")
    branch_info = source + " -> " + target
    status = mr.get("merge_status", "") or mr.get("state", "")
    reviewers = mr.get("reviewers", [])
    reviewer_names = ",".join([r.get("username", "") for r in reviewers])[:30] if reviewers else ""
    print("{:<6} | {:<45} | {:<18} | {:<35} | {:<12} | {}".format(iid, title, author, branch_info, status, reviewer_names))
print()
print("Total: " + str(len(mrs)) + " open MR(s)")
'
}

cmd_mr_comment() {
  local project_path="$1"
  local mr_iid="$2"
  local agent="$3"
  local message="$4"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(python3 -c "import json; print(json.dumps({'body': $(json_encode_value "$message")}))")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/merge_requests/$mr_iid/notes" "$pat" "$data"

  if [[ "$_API_STATUS" == "201" ]]; then
    local note_id
    note_id=$(echo "$_API_RESPONSE" | json_get "id" "")
    echo "[OK] Comment posted on MR !$mr_iid by $agent (note_id: $note_id)"
  else
    echo "[ERROR] Failed to post comment (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_mr_approve() {
  local project_path="$1"
  local mr_iid="$2"
  local agent="$3"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/merge_requests/$mr_iid/approve" "$pat" ""

  if [[ "$_API_STATUS" == "200" || "$_API_STATUS" == "201" ]]; then
    echo "[OK] MR !$mr_iid approved by $agent (${AGENT_USERNAMES[$agent]})"
  else
    echo "[ERROR] Failed to approve MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_mr_unapprove() {
  local project_path="$1"
  local mr_iid="$2"
  local agent="$3"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/merge_requests/$mr_iid/unapprove" "$pat" ""

  if [[ "$_API_STATUS" == "200" || "$_API_STATUS" == "201" || "$_API_STATUS" == "204" ]]; then
    echo "[OK] MR !$mr_iid unapproved by $agent (${AGENT_USERNAMES[$agent]})"
  else
    echo "[ERROR] Failed to unapprove MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_mr_update() {
  local project_path="$1"
  local mr_iid="$2"
  local agent="$3"
  local title="$4"
  local description="${5:-}"

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  # Use stdin to pass title/description into Python — avoids shell-variable interpolation
  # in Python source, which would break on single-quotes in titles (e.g. "don't break").
  data=$(printf '%s\n%s' "$title" "$description" | python3 -c "
import json, sys
lines = sys.stdin.read().split('\n', 1)
t = lines[0]
desc = lines[1] if len(lines) > 1 else ''
payload = {}
if t:
    payload['title'] = t
if desc:
    payload['description'] = desc
print(json.dumps(payload))
")

  local pat
  pat=$(get_pat "$agent")
  api_put "/projects/$encoded_path/merge_requests/$mr_iid" "$pat" "$data"

  if [[ "$_API_STATUS" == "200" ]]; then
    echo "[OK] MR !$mr_iid updated by $agent"
  else
    echo "[ERROR] Failed to update MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

# Resolve open-MR pipeline evidence: the list endpoint on this instance does NOT
# serialize head_pipeline, so eligibility verdicts come from per-MR GETs. Prints
# newline-delimited single-MR JSON (JSONL) to stdout; returns 1 on any fetch failure.
fetch_mr_details() {
  local project_path="$1"
  local encoded_path pat iids iid

  encoded_path=$(url_encode_path "$project_path")
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/merge_requests?state=opened&per_page=100" "$pat"
  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch MR list (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi
  iids=$(printf '%s' "$_API_RESPONSE" | python3 -c 'import json,sys; [print(m.get("iid", "")) for m in json.load(sys.stdin)]') || return 1

  for iid in ${(f)iids}; do
    [[ -z "$iid" ]] && continue
    api_get "/projects/$encoded_path/merge_requests/$iid" "$pat"
    if [[ "$_API_STATUS" != "200" ]]; then
      echo "[ERROR] Failed to fetch MR !$iid details (HTTP $_API_STATUS) — pipeline evidence unresolvable, failing closed." >&2
      return 1
    fi
    printf '%s\n' "$_API_RESPONSE"
  done
}

cmd_mr_check_eligible() {
  local project_path="${1:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }

  if [[ "${2:-}" == "--raw" ]]; then
    local encoded_path
    encoded_path=$(url_encode_path "$project_path")
    api_get "/projects/$encoded_path/merge_requests?state=opened&per_page=100" "$(get_pat "emma")"
    if [[ "$_API_STATUS" != "200" ]]; then
      echo "[ERROR] Failed to fetch MRs (HTTP $_API_STATUS)" >&2
      api_error_hint "$_API_STATUS" "$project_path"
      echo "$_API_RESPONSE" >&2
      return 1
    fi
    printf '%s\n' "$_API_RESPONSE" | python3 -m json.tool
    return 0
  fi

  local details_file
  details_file=$(mktemp)
  if ! fetch_mr_details "$project_path" > "$details_file"; then
    rm -f "$details_file"
    return 1
  fi

  local rc=0
  python3 "$SCRIPT_DIR/mr_readiness.py" eligible "$details_file" || rc=$?
  rm -f "$details_file"
  return "$rc"
}

cmd_mr_auto_approve() {
  local project_path="${1:-}"
  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  echo "Checking eligible MRs (per-MR pipeline evidence)..."
  echo ""

  local eligible_mrs details_file rc=0
  details_file=$(mktemp)
  if ! fetch_mr_details "$project_path" > "$details_file"; then
    rm -f "$details_file"
    return 1
  fi
  eligible_mrs=$(python3 "$SCRIPT_DIR/mr_readiness.py" ids "$details_file") || rc=$?
  rm -f "$details_file"
  [[ "$rc" != 0 ]] && return "$rc"

  if [[ -z "$eligible_mrs" ]]; then
    echo "[INFO] No eligible MRs found for auto-approval."
    echo "Tip: Run 'mr-check-eligible' to see why MRs are ineligible."
    return 0
  fi

  echo "Found $(echo "$eligible_mrs" | wc -l | tr -d ' ') eligible MR(s)."
  echo ""
  
  local approved_count=0
  local failed_count=0
  
  while IFS= read -r mr_iid; do
    [[ -z "$mr_iid" ]] && continue
    
    # Use emma's PAT for auto-approval (reviewer identity)
    local emma_pat
    emma_pat=$(get_pat "emma")
    
    api_post "/projects/$encoded_path/merge_requests/$mr_iid/approve" "$emma_pat" ""
    
    if [[ "$_API_STATUS" == "200" || "$_API_STATUS" == "201" ]]; then
      echo "[OK] MR !$mr_iid approved (auto-approved)"
      approved_count=$((approved_count + 1))
    else
      echo "[WARN] MR !$mr_iid approval failed (HTTP $_API_STATUS) — may require manual approval" >&2
      failed_count=$((failed_count + 1))
    fi
  done <<< "$eligible_mrs"
  
  echo ""
  echo "=== Auto-Approval Summary ==="
  echo "  Approved: $approved_count"
  echo "  Failed:   $failed_count"
  
  if [[ $failed_count -gt 0 ]]; then
    return 1
  fi
}

cmd_mr_status() {
  local project_path="${1:-}"
  local mr_iid="${2:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$mr_iid" ]] && { echo "[ERROR] MR IID required" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/merge_requests/$mr_iid" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  local mr_file approvals_file rc=0
  mr_file=$(mktemp)
  approvals_file=$(mktemp)
  printf '%s' "$_API_RESPONSE" > "$mr_file"
  if api_get "/projects/$encoded_path/merge_requests/$mr_iid/approvals" "$pat" && [[ "$_API_STATUS" == "200" ]]; then
    printf '%s' "$_API_RESPONSE" > "$approvals_file"
  else
    echo "[WARN] Approval evidence unavailable (HTTP $_API_STATUS)" >&2
    printf 'null' > "$approvals_file"
  fi
  python3 "$SCRIPT_DIR/mr_readiness.py" status "$mr_file" "$approvals_file" || rc=$?
  rm -f "$mr_file" "$approvals_file"
  return "$rc"
}

cmd_mr_show() {
  local project_path="${1:-}"
  local mr_iid="${2:-}"
  local mode="${3:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$mr_iid" ]] && { echo "[ERROR] MR IID required" >&2; return 1; }
  [[ -n "$mode" && "$mode" != "--raw" ]] && { echo "[ERROR] Unknown option: $mode (only --raw is supported)" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/merge_requests/$mr_iid" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch MR !$mr_iid (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  if [[ "$mode" == "--raw" ]]; then
    printf '%s\n' "$_API_RESPONSE" | python3 -m json.tool
    return 0
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c "
import json, sys

mr = json.load(sys.stdin)
def user(obj):
    return (obj or {}).get('username', '')

print('=== MR Show ===')
print(f\"  IID:                !{mr.get('iid', '')}\")
print(f\"  Title:              {mr.get('title', '')}\")
print(f\"  Author:             {user(mr.get('author'))}\")
print(f\"  State:              {mr.get('state', '')}\")
print(f\"  Draft:              {str(mr.get('draft', mr.get('work_in_progress', ''))).lower()}\")
print(f\"  Source -> Target:   {mr.get('source_branch', '')} -> {mr.get('target_branch', '')}\")
print(f\"  Source SHA:         {mr.get('sha', '')}\")
print(f\"  Merge Status:       {mr.get('merge_status', '')}\")
print(f\"  Detailed Status:    {mr.get('detailed_merge_status', 'n/a')}\")
print(f\"  Has Conflicts:      {str(mr.get('has_conflicts', '')).lower()}\")
print(f\"  Blocking Disc. Res: {str(mr.get('blocking_discussions_resolved', '')).lower()}\")
hp = mr.get('head_pipeline')
if isinstance(hp, dict):
    print(f\"  Head Pipeline:      id={hp.get('id', '')} status={hp.get('status', '')} sha={hp.get('sha', '')}\")
    print(f\"  Pipeline URL:       {hp.get('web_url', '')}\")
else:
    print('  Head Pipeline:      none')
print(f\"  Auto-merge:         {str(mr.get('merge_when_pipeline_succeeds', '')).lower()}\")
print(f\"  Created At:         {mr.get('created_at', '')}\")
print(f\"  Updated At:         {mr.get('updated_at', '')}\")
if mr.get('merged_at'):
    print(f\"  Merged At:          {mr.get('merged_at', '')}\")
    print(f\"  Merged By:          {user(mr.get('merged_by'))}\")
if mr.get('closed_at'):
    print(f\"  Closed At:          {mr.get('closed_at', '')}\")
labels = mr.get('labels', [])
print(f\"  Labels:             {', '.join(labels) if labels else '-'}\")
print(f\"  URL:                {mr.get('web_url', '')}\")
desc = mr.get('description') or ''
print()
print('=== Description ===')
print(desc if desc.strip() else '(empty)')
"
}

cmd_pipeline_jobs() {
  local project_path="${1:-}"
  local pipeline_id="${2:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$pipeline_id" || ! "$pipeline_id" == <-> ]] && { echo "[ERROR] Numeric pipeline ID required" >&2; return 1; }

  local encoded_path pat
  encoded_path=$(url_encode_path "$project_path")
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/pipelines/$pipeline_id/jobs?per_page=100" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch jobs for pipeline $pipeline_id (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys

jobs = json.load(sys.stdin)
if not isinstance(jobs, list):
    raise SystemExit("unexpected jobs response")
if not jobs:
    print("No jobs found for pipeline.")
    raise SystemExit(0)

print("ID     | STAGE        | STATUS     | NAME                           | FAILURE REASON")
print("-" * 115)
for job in jobs:
    print("{:<6} | {:<12} | {:<10} | {:<30} | {}".format(
        job.get("id", ""), job.get("stage", ""), job.get("status", ""),
        job.get("name", ""), job.get("failure_reason") or "-"))
print("\nJob trace may contain sensitive build output; fetch it only when needed.")
'
}

cmd_pipeline_job_trace() {
  local project_path="${1:-}"
  local job_id="${2:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$job_id" || ! "$job_id" == <-> ]] && { echo "[ERROR] Numeric job ID required" >&2; return 1; }

  local encoded_path pat
  encoded_path=$(url_encode_path "$project_path")
  pat=$(get_pat "emma")
  api_get "/projects/$encoded_path/jobs/$job_id/trace" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch trace for job $job_id (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE"
}

cmd_pipeline_job_retry() {
  local project_path="${1:-}"
  local job_id="${2:-}"
  local agent="${3:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$job_id" || ! "$job_id" == <-> ]] && { echo "[ERROR] Numeric job ID required" >&2; return 1; }

  validate_agent "$agent" || return 1

  local encoded_path pat
  encoded_path=$(url_encode_path "$project_path")
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/jobs/$job_id/retry" "$pat" ""

  if [[ "$_API_STATUS" != "201" && "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to retry job $job_id (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys
job = json.load(sys.stdin)
print("[OK] Job retried")
print("  ID:       {}".format(job.get("id", "")))
print("  Name:     {}".format(job.get("name", "")))
print("  Status:   {}".format(job.get("status", "")))
print("  Pipeline: {}".format((job.get("pipeline") or {}).get("id", "")))
print("  Web URL:  {}".format(job.get("web_url", "")))
'
}

cmd_mr_merge() {
  local project_path="${1:-}"
  local mr_iid="${2:-}"
  local agent="${3:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$mr_iid" ]] && { echo "[ERROR] MR IID required" >&2; return 1; }

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")

  # Accept the MR via POST /merge_requests/:iid/merge
  local data
  data=$(python3 -c "import json; print(json.dumps({'should_remove_source_branch': True, 'squash': False}))")

  api_put "/projects/$encoded_path/merge_requests/$mr_iid/merge" "$pat" "$data"

  if [[ "$_API_STATUS" == "200" ]] || [[ "$_API_STATUS" == "201" ]]; then
    local state merged_at source_branch
    state=$(echo "$_API_RESPONSE" | json_get "state" "")
    merged_at=$(echo "$_API_RESPONSE" | json_get "merged_at" "")
    source_branch=$(echo "$_API_RESPONSE" | json_get "source_branch" "")
    echo "[OK] MR !$mr_iid merged by $agent"
    echo "  State:      $state"
    echo "  Merged At:  $merged_at"
    echo "  Source:     $source_branch"

    local root
    root=$(repo_root 2>/dev/null || true)
    if [[ -z "${OELITE_HUMAN:-}" ]] && [[ -n "$source_branch" ]] && [[ -n "$root" ]]; then
      if [[ "$state" == "merged" ]]; then
        echo ""
        echo "Cleaning up merged branch's local worktree (GIT-WORKFLOW-STANDARDS.md §1.8)..."
        cleanup_local_worktree_for_branch "$root" "$source_branch"
      else
        echo ""
        echo "[INFO] Merge is pending (state=$state). Run after it completes:"
        echo "       oelite-gitlab.sh worktree-cleanup <agent> --delete-branch"
      fi
    fi
  else
    echo "[ERROR] Failed to merge MR !$mr_iid (HTTP $_API_STATUS)" >&2
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_mr_close() {
  local project_path="${1:-}"
  local mr_iid="${2:-}"
  local agent="${3:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$mr_iid" ]] && { echo "[ERROR] MR IID required" >&2; return 1; }

  validate_agent "$agent" || return 1

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "$agent")

  # Close the MR via PUT /merge_requests/:iid with state_event=close
  local data
  data=$(python3 -c "import json; print(json.dumps({'state_event': 'close'}))")

  api_put "/projects/$encoded_path/merge_requests/$mr_iid" "$pat" "$data"

  if [[ "$_API_STATUS" == "200" ]] || [[ "$_API_STATUS" == "201" ]]; then
    local state
    state=$(echo "$_API_RESPONSE" | json_get "state" "")
    echo "[OK] MR !$mr_iid closed by $agent"
    echo "  State: $state"
  else
    echo "[ERROR] Failed to close MR !$mr_iid (HTTP $_API_STATUS)" >&2
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_issue_audit() {
  local project_path="${1:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local pat
  pat=$(get_pat "emma")

  # Fetch all open issues
  api_get "/projects/$encoded_path/issues?state=opened&per_page=100" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch issues (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  local open_issues_response="$_API_RESPONSE"

  # Fetch all merged MRs
  api_get "/projects/$encoded_path/merge_requests?state=merged&per_page=100" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to fetch merged MRs (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  local merged_mrs_response="$_API_RESPONSE"

  local tmp_issues tmp_mrs
  tmp_issues=$(mktemp)
  tmp_mrs=$(mktemp)
  printf '%s' "$open_issues_response" > "$tmp_issues"
  printf '%s' "$merged_mrs_response" > "$tmp_mrs"

  python3 -c "
import json, re, sys

with open('$tmp_issues') as f:
    open_issues = json.load(f)
with open('$tmp_mrs') as f:
    merged_mrs = json.load(f)

# Build a set of issue IIDs that were closed by merged MRs
# GitLab MRs store closing issue references in 'description' (Closes #NNN) and
# the API also provides 'closed_by' (issues) but we work from MR side here.
closed_by_mr = set()
mr_titles = {}

for mr in merged_mrs:
    desc = mr.get('description', '') or ''
    iid = mr.get('iid', '')
    title = mr.get('title', '')
    # Find 'Closes #NNN' patterns
    matches = re.findall(r'[Cc]loses\s+#?(\d+)', desc)
    for m in matches:
        closed_by_mr.add(int(m))
        mr_titles[int(m)] = f'!{iid} {title}'

# Also check MR title for 'Closes #NNN'
    matches2 = re.findall(r'[Cc]loses\s+#?(\d+)', title)
    for m in matches2:
        closed_by_mr.add(int(m))
        mr_titles[int(m)] = f'!{iid} {title}'

# Find open issues that should have been closed
orphans = []
done_label_issues = []

for issue in open_issues:
    iid = issue.get('iid', 0)
    title = issue.get('title', '')
    labels = issue.get('labels', [])
    state = issue.get('state', '')

    if iid in closed_by_mr:
        orphans.append((iid, title, labels, mr_titles.get(iid, '')))
    elif 'Done' in labels:
        done_label_issues.append((iid, title, labels))

print('=== Post-Merge Issue Audit ===')
print(f'Project: $project_path')
print(f'Open issues: {len(open_issues)}')
print(f'Merged MRs: {len(merged_mrs)}')
print()

if orphans:
    print(f'[ACTION] {len(orphans)} issue(s) still OPEN but linked MR was MERGED — close them:')
    print(f'{\"IID\":<6} | {\"Title\":<45} | {\"Labels\":<25} | Closed By MR')
    print('-' * 110)
    for iid, title, labels, mr_info in orphans:
        label_str = ','.join(labels)[:25]
        print(f'{iid:<6} | {title[:45]:<45} | {label_str:<25} | {mr_info}')
    print()
else:
    print('[OK] No orphaned open issues found (all linked MRs have their issues closed).')
    print()

if done_label_issues:
    print(f'[ACTION] {len(done_label_issues)} issue(s) with Done label but still OPEN — close them:')
    print(f'{\"IID\":<6} | {\"Title\":<45} | {\"Labels\":<25}')
    print('-' * 85)
    for iid, title, labels in done_label_issues:
        label_str = ','.join(labels)[:25]
        print(f'{iid:<6} | {title[:45]:<45} | {label_str:<25}')
    print()

total_action = len(orphans) + len(done_label_issues)
if total_action > 0:
    print(f'[SUMMARY] {total_action} issue(s) need closure. Run:')
    for iid, _, _, _ in orphans:
        print(f'  oelite-gitlab.sh issue-status $project_path {iid} emma closed')
    for iid, _, _ in done_label_issues:
        print(f'  oelite-gitlab.sh issue-status $project_path {iid} emma closed')
else:
    print('[SUMMARY] All clear — no action needed.')
"

  rm -f "$tmp_issues" "$tmp_mrs"
}

cmd_sync() {
  local wt_id="$1"

  local parsed
  parsed=$(parse_worktree_id "$wt_id")
  local agent="${parsed% *}"
  local issue="${parsed#* }"

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" "$issue" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent" "$issue")

  echo "Fetching latest develop..."
  git -C "$wt_path" fetch origin develop --quiet

  echo "Rebasing on origin/develop..."
  if git -C "$wt_path" rebase origin/develop 2>&1; then
    echo "[OK] Rebased on latest develop"
    local branch
    branch=$(git -C "$wt_path" branch --show-current)
    local ahead
    ahead=$(git -C "$wt_path" rev-list --left-right --count "origin/develop...HEAD" | awk '{print $1}')
    echo "  Branch: $branch ($ahead commit(s) ahead of develop)"
  else
    echo "[ERROR] Rebase failed — conflicts detected" >&2
    echo "Conflicting files:" >&2
    git -C "$wt_path" diff --name-only --diff-filter=U 2>/dev/null >&2
    echo "" >&2
    echo "Resolve conflicts and run: git -C $wt_path rebase --continue" >&2
    return 1
  fi
}

cmd_status() {
  local root
  root=$(repo_root)

  echo "=== OElite GitLab Status ==="
  echo "Repo: $root"
  echo ""

  printf "%-12s │ %-12s │ %-30s │ %-8s │ %-8s │ %-12s │ %s\n" "AGENT" "OWNER" "BRANCH" "AHEAD" "BEHIND" "LAST COMMIT" "STATUS"
  print_separator 110

  local now
  now=$(date +%s)
  local found=false

  git worktree list --porcelain | while read -r line; do
    case "$line" in
      worktree\ *)
        wt_path="${line#worktree }"
        ;;
      branch\ *)
        branch="${line#branch refs/heads/}"
        ;;
      HEAD\ *)
        ;;
      "")
        if [[ "$wt_path" == "$root/.worktrees/"* ]]; then
          agent_name="${wt_path#$root/.worktrees/}"
          found=true

          # Read owner DNA metadata
          local owner="$agent_name"
          if [[ -f "$wt_path/.git-worktree-owner" ]]; then
            owner=$(<"$wt_path/.git-worktree-owner")
          fi

          ahead="" behind="" last_date="" last_ts="" status_label=""

          if git -C "$wt_path" show-ref --verify --quiet "refs/remotes/origin/develop" 2>/dev/null; then
            read -r ahead behind <<< "$(git -C "$wt_path" rev-list --left-right --count 'origin/develop...HEAD' 2>/dev/null)"
          else
            ahead="?"
            behind="?"
          fi

          last_date=$(git -C "$wt_path" log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1)
          last_ts=$(git -C "$wt_path" log -1 --format="%ct" 2>/dev/null)

          if [[ -z "$last_date" ]]; then
            last_date="—"
          fi

          status_label=""
          if [[ -n "$last_ts" ]] 2>/dev/null; then
            age=$(( now - last_ts ))
            if [[ $age -gt 86400 ]]; then
              status_label="STALE (>${age/86400}d)"
            else
              status_label="active"
            fi
          else
            status_label="—"
          fi

          printf "%-12s │ %-12s │ %-30s │ %-8s │ %-8s │ %-12s │ %s\n" \
            "$agent_name" "$owner" "$branch" "$ahead" "$behind" "$last_date" "$status_label"
        fi
        wt_path=""
        branch=""
        ;;
    esac
  done

  if ! git worktree list --porcelain | grep -q "$root/.worktrees/"; then
    echo "No active agent worktrees found."
  fi
}

cmd_worktree_owner() {
  local wt_id="$1"
  local new_owner="${2:-}"

  local parsed
  parsed=$(parse_worktree_id "$wt_id")
  local agent="${parsed% *}"
  local issue="${parsed#* }"

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" "$issue" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent" "$issue")
  local owner_file="$wt_path/.git-worktree-owner"
  local current_owner
  if [[ -f "$owner_file" ]]; then
    current_owner=$(<"$owner_file")
  else
    current_owner="$agent"
  fi

  if [[ -z "$new_owner" ]]; then
    # Display current owner
    local owner_name
    owner_name=$(get_agent_name "$current_owner")
    local owner_email
    owner_email=$(get_agent_email "$current_owner")
    echo "Worktree Owner DNA for $wt_id:"
    echo "  Path:   $wt_path"
    echo "  Owner:  $owner_name <$owner_email>"
    echo "  Config: user.name=$owner_name, user.email=$owner_email"
  else
    # Set new owner
    validate_agent "$new_owner" || return 1
    local new_owner_name
    new_owner_name=$(get_agent_name "$new_owner")
    local new_owner_email
    new_owner_email=$(get_agent_email "$new_owner")

    echo "$new_owner" > "$owner_file"
    git -C "$wt_path" config --worktree user.name "$new_owner_name"
    git -C "$wt_path" config --worktree user.email "$new_owner_email"

    echo "[OK] Owner DNA updated for $wt_id:"
    echo "  Path:   $wt_path"
    echo "  New owner: $new_owner_name <$new_owner_email>"
  fi
}

cmd_pipeline_list() {
  local project_path="${1:-}"
  local agent="${2:-emma}"
  local ref="${3:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local encoded_path endpoint pat
  encoded_path=$(url_encode_path "$project_path")
  endpoint="/projects/$encoded_path/pipelines?per_page=50"
  if [[ -n "$ref" ]]; then
    endpoint+=$(printf '&ref=%s' "$(url_encode_query "$ref")")
  fi

  pat=$(get_pat "$agent")
  api_get "$endpoint" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to list pipelines for $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys

pipelines = json.load(sys.stdin)
if not isinstance(pipelines, list):
    raise SystemExit("unexpected pipelines response")
if not pipelines:
    print("No pipelines found.")
    raise SystemExit(0)

print("ID     | STATUS     | SHA                                      | SOURCE")
print("-" * 100)
for p in pipelines:
    print("{:<6} | {:<10} | {:<40} | {}".format(
        p.get("id", ""), p.get("status", ""), p.get("sha", ""), p.get("source", "")))
'
}

cmd_job_token_allowlist_add() {
  local project_path="${1:-}"
  local agent="${2:-}"
  local target_project="${3:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$target_project" ]] && { echo "[ERROR] Target project path required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local project_id target_id
  project_id=$(resolve_project_id "$project_path" "$agent") || return 1
  [[ -n "$project_id" ]] || { echo "[ERROR] Could not resolve project ID for $project_path" >&2; return 1; }

  target_id=$(resolve_project_id "$target_project" "$agent") || return 1
  [[ -n "$target_id" ]] || { echo "[ERROR] Could not resolve project ID for $target_project" >&2; return 1; }

  local body
  body=$(printf '{"target_project_id":%s}' "$target_id")

  # GitLab's supported add operation is POST /job_token_scope/allowlist.
  # Some installations reject numeric IDs while accepting URL-encoded paths;
  # retry the same supported operation with the source path only on 404/410.
  api_post "/projects/$project_id/job_token_scope/allowlist" "$pat" "$body"
  if [[ "$_API_STATUS" == "404" || "$_API_STATUS" == "410" ]]; then
    local encoded_source
    encoded_source=$(url_encode_path "$project_path")
    api_post "/projects/$encoded_source/job_token_scope/allowlist" "$pat" "$body"
  fi

  if [[ "$_API_STATUS" != "201" && "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to allow $target_project in $project_path inbound CI_JOB_TOKEN allowlist (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  local confirmed_target
  confirmed_target=$(printf '%s\n' "$_API_RESPONSE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("target_project_id", ""))')
  if [[ "$confirmed_target" != "$target_id" ]]; then
    echo "[ERROR] Allowlist response did not confirm target project $target_project" >&2
    return 1
  fi

  echo "[OK] Added $target_project to $project_path inbound CI_JOB_TOKEN allowlist"
}

# Build the JSON body used to create a protected branch with least-privilege
# settings: no direct pushes (No access), Maintainer (40) merge/unprotect,
# force push disabled, and code-owner approval per requested state.
protected_branch_create_body() {
  local branch="$1"
  local code_owner_value="$2"

  python3 -c '
import json, sys
branch, code_owner = sys.argv[1], sys.argv[2] == "true"
body = {
    "name": branch,
    "allow_force_push": False,
    "code_owner_approval_required": code_owner,
    "allowed_to_push": [{"access_level": 0}],
    "allowed_to_merge": [{"access_level": 40}],
    "allowed_to_unprotect": [{"access_level": 40}],
}
print(json.dumps(body))
' "$branch" "$code_owner_value"
}

# Read the authoritative code_owner_approval_required value for one protected
# branch via GET /projects/:id/protected_branches/:name. Prints true/false on
# 200, prints nothing otherwise. Read-only.
protected_branch_read_code_owner() {
  local project_path="$1"
  local branch_enc="$2"
  local pat="$3"

  api_get "/projects/$(url_encode_path "$project_path")/protected_branches/$branch_enc" "$pat"
  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Authoritative read of protected branch failed (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi
  printf '%s\n' "$_API_RESPONSE" | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("code_owner_approval_required")).lower())'
}

cmd_protected_branch_code_owner() {
  local project_path="${1:-}"
  local agent="${2:-}"
  local branch="${3:-}"
  local state="${4:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$branch" ]] && { echo "[ERROR] Branch name required" >&2; return 1; }
  local value
  case "$state" in
    on)  value=true ;;
    off) value=false ;;
    *)   echo "[ERROR] State must be 'on' or 'off'" >&2; return 1 ;;
  esac
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")
  local branch_enc
  branch_enc=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$branch")

  # Read the complete protected-branch list first so a missing exact branch is
  # distinguishable from an inaccessible project. This also ensures existing
  # entries are identified before PATCH, preserving their access settings.
  api_get "/projects/$encoded_path/protected_branches" "$pat"
  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to list protected branches on $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  local existing
  existing=$(printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys
raw = json.load(sys.stdin)
branches = raw if isinstance(raw, list) else []
name = sys.argv[1]
match = next((branch for branch in branches if branch.get("name") == name), None)
print(json.dumps(match) if match is not None else "")
' "$branch")

  if [[ -n "$existing" ]]; then
    local existing_code_owner
    existing_code_owner=$(printf '%s\n' "$existing" | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("code_owner_approval_required")).lower())')
    if [[ "$existing_code_owner" == "$value" ]]; then
      echo "[OK] code_owner_approval_required=$state already set on $project_path protected branch $branch (no change)"
      return 0
    fi
    # GitLab documents the boolean toggles for this endpoint as query
    # parameters; JSON-body PATCHes of code_owner_approval_required have been
    # observed to return 200 without applying the change, so send the value in
    # the documented query form. Access levels are not sent, preserving them.
    api_patch "/projects/$encoded_path/protected_branches/$branch_enc?code_owner_approval_required=$value" "$pat" ""
    if [[ "$_API_STATUS" != "200" ]]; then
      echo "[ERROR] Failed to set code_owner_approval_required=$state on $project_path branch $branch (HTTP $_API_STATUS)" >&2
      api_error_hint "$_API_STATUS" "$project_path"
      return 1
    fi
  else
    # The exact branch is not protected. Create it with least-privilege
    # defaults instead of failing; confirm below from the response.
    local body
    body=$(protected_branch_create_body "$branch" "$value")
    api_post "/projects/$encoded_path/protected_branches" "$pat" "$body"
    if [[ "$_API_STATUS" != "201" && "$_API_STATUS" != "200" ]]; then
      echo "[ERROR] Failed to create protected branch $branch on $project_path with code_owner_approval_required=$state (HTTP $_API_STATUS)" >&2
      api_error_hint "$_API_STATUS" "$project_path"
      return 1
    fi
  fi

  # The PATCH/POST response can omit or contradict the applied state (observed:
  # HTTP 200 with code_owner_approval_required=false after a true request), so
  # confirm with an authoritative GET read-back before reporting success.
  local confirmed
  confirmed=$(protected_branch_read_code_owner "$project_path" "$branch_enc" "$pat") || return 1
  if [[ "$confirmed" != "$value" ]]; then
    echo "[ERROR] Protected branch read-back did not confirm code_owner_approval_required=$state" >&2
    return 1
  fi

  echo "[OK] code_owner_approval_required=$state set on $project_path protected branch $branch"
}

cmd_protected_branches() {
  local project_path="${1:-}"
  local agent="${2:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")
  api_get "/projects/$encoded_path/protected_branches" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to list protected branches on $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys
branches = json.load(sys.stdin)
if not isinstance(branches, list):
    raise SystemExit("[ERROR] Unexpected protected branches response")
if not branches:
    print("No protected branches found.")
    raise SystemExit(0)
print("NAME                 | CODE OWNER | FORCE PUSH | PUSH ACCESS | MERGE ACCESS | UNPROTECT ACCESS")
print("-" * 105)
for pb in branches:
    def levels(key):
        return ",".join(str(item.get("access_level_description") or item.get("access_level") or item) for item in (pb.get(key) or [])) or "(none)"
    print("{:<20} | {:<10} | {:<10} | {:<11} | {:<12} | {}".format(
        pb.get("name", ""), str(pb.get("code_owner_approval_required")).lower(),
        str(pb.get("allow_force_push")).lower(), levels("push_access_levels"),
        levels("merge_access_levels"), levels("unprotect_access_levels")))
'
}

cmd_protected_branch_show() {
  local project_path="${1:-}"
  local agent="${2:-}"
  local branch="${3:-}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  [[ -z "$branch" ]] && { echo "[ERROR] Branch name required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")
  local branch_enc
  branch_enc=$(python3 -c 'import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$branch")

  # Read-only diagnosis: reports the exact HTTP status of the single-branch
  # protected-branch endpoint without mutating anything.
  api_get "/projects/$encoded_path/protected_branches/$branch_enc" "$pat"

  if [[ "$_API_STATUS" == "200" ]]; then
    printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys
pb = json.load(sys.stdin)
print("[OK] Protected branch found on " + sys.argv[1] + ":")
print("  name:                         " + str(pb.get("name")))
print("  code_owner_approval_required: " + str(pb.get("code_owner_approval_required")).lower())
print("  allow_force_push:             " + str(pb.get("allow_force_push")).lower())
for label, key in (("push", "push_access_levels"), ("merge", "merge_access_levels"), ("unprotect", "unprotect_access_levels")):
    levels = pb.get(key) or []
    rendered = ", ".join(
        str(level.get("access_level_description") or level.get("access_level") or level)
        for level in levels
    )
    print("  " + label + "_access_levels:         " + (rendered or "(none)"))
' "$project_path"
    return 0
  fi

  if [[ "$_API_STATUS" == "404" ]]; then
    echo "[OK] No protected branch '$branch' found on $project_path (HTTP 404) - branch is not protected or is not visible to this PAT" >&2
    return 2
  fi

  echo "[ERROR] Failed to read protected branch $branch on $project_path (HTTP $_API_STATUS)" >&2
  api_error_hint "$_API_STATUS" "$project_path"
  return 1
}

cmd_pipeline_must_succeed() {
  local project_path="${1:-}"
  local agent="${2:-}"
  local state="${3:-}"

  local value
  case "$state" in
    on)  value=true ;;
    off) value=false ;;
    *)   echo "[ERROR] State must be 'on' or 'off'" >&2; return 1 ;;
  esac
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  api_put "/projects/$encoded_path" "$pat" "{\"only_allow_merge_if_pipeline_succeeds\":$value}"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to set only_allow_merge_if_pipeline_succeeds=$state on $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  local confirmed
  confirmed=$(printf '%s\n' "$_API_RESPONSE" | python3 -c 'import json,sys; print(str(json.load(sys.stdin).get("only_allow_merge_if_pipeline_succeeds")).lower())')
  if [[ "$confirmed" != "$value" ]]; then
    echo "[ERROR] Project response did not confirm only_allow_merge_if_pipeline_succeeds=$state" >&2
    return 1
  fi

  echo "[OK] only_allow_merge_if_pipeline_succeeds=$state set on $project_path"
}

cmd_project_permissions() {
  local project_path="${1:-}"
  local agent="${2:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  api_get "/projects/$encoded_path" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to inspect project $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys

project = json.load(sys.stdin)
permissions = project.get("permissions") or {}
levels = []
for key in ("project_access", "group_access"):
    entry = permissions.get(key)
    if isinstance(entry, dict) and isinstance(entry.get("access_level"), int):
        levels.append(entry["access_level"])
access = max(levels) if levels else None
print("Project:              {}".format(project.get("path_with_namespace", "")))
print("Caller access level:  {}".format(access if access is not None else "none"))
print("Visibility:           {}".format(project.get("visibility", "")))
'
}

cmd_project_approvals() {
  local project_path="${1:-}"
  local agent="${2:-emma}"

  [[ -z "$project_path" ]] && { echo "[ERROR] Project path required" >&2; return 1; }
  validate_agent "$agent" || return 1

  local pat
  pat=$(get_pat "$agent")

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  api_get "/projects/$encoded_path/approvals" "$pat"

  if [[ "$_API_STATUS" != "200" ]]; then
    echo "[ERROR] Failed to read approval settings for $project_path (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  printf '%s\n' "$_API_RESPONSE" | python3 -c '
import json, sys

settings = json.load(sys.stdin)
print("Project:                    {}".format(sys.argv[1]))
print("Approvals required:         {}".format(settings.get("approvals_required", 0)))
print("Approvals reset on push:    {}".format(settings.get("reset_approvals_on_push", "")))
print("Disable overwriting:        {}".format(settings.get("disable_overriding_approvers_per_merge_request", "")))
approvers = settings.get("approvers") or []
approver_groups = settings.get("approver_groups") or []
if approvers:
    print("Specific approvers:")
    for a in approvers:
        print("  - {}".format(a.get("user", {}).get("username", a.get("id", "?"))))
else:
    print("Specific approvers:         none (any eligible member may approve)")
if approver_groups:
    print("Approver groups:")
    for g in approver_groups:
        print("  - {}".format(g.get("group", {}).get("full_path", g.get("id", "?"))))
' "$project_path"
}

cmd_oe_scope() {
  local wt_id="$1"
  shift

  local parsed
  parsed=$(parse_worktree_id "$wt_id")
  local agent="${parsed% *}"
  local issue_from_id="${parsed#* }"

  validate_agent "$agent" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent" "$issue_from_id")
  local scope_file="$wt_path/.oe-scope"

  if [[ ! -f "$scope_file" ]]; then
    echo "[ERROR] .oe-scope not found at $scope_file" >&2
    echo "        Worktree may not exist or was created before this feature." >&2
    echo "        Run worktree-remove then worktree-create to regenerate." >&2
    return 1
  fi

  local task_type="" issue="" desc=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-type) task_type="$2"; shift 2 ;;
      --issue)     issue="$2"; shift 2 ;;
      --desc)      desc="$2"; shift 2 ;;
      *)           echo "[ERROR] Unknown option: $1" >&2; return 1 ;;
    esac
  done

  if [[ -n "$task_type" || -n "$issue" || -n "$desc" ]]; then
    # FIX #48: quote-safe KEY=VALUE line updates (see scope_kv_escape above).
    if [[ -n "$task_type" ]]; then
      sed -i '' "s|^TASK_TYPE=.*|TASK_TYPE=$(scope_kv_escape "$task_type")|" "$scope_file"
    fi
    if [[ -n "$issue" ]]; then
      sed -i '' "s|^ISSUE=.*|ISSUE=$(scope_kv_escape "$issue")|" "$scope_file"
    fi
    if [[ -n "$desc" ]]; then
      sed -i '' "s|^TASK_DESCRIPTION=.*|TASK_DESCRIPTION=$(scope_kv_escape "$desc")|" "$scope_file"
    fi
    echo "[OK] Scope updated for $wt_id:"
  else
    echo "=== Scope for $wt_id ==="
  fi

  cat "$scope_file"
}

cmd_help() {
  cat <<'EOF'
oelite-gitlab.sh — GitLab-integrated parallel agentic development tool

USAGE:
  oelite-gitlab.sh <command> [arguments]

COMMANDS:

  setup
    Verify all 12 agent PATs against GitLab.
    Prints a table: agent | username | id | email | status

  issues <project-path> [--label <label>] [--assignee <agent>]
    List open issues for a project.
    Example: oelite-gitlab.sh issues uranus/origin-auth --label backend

  issue-show <project-path> <iid>
    Show issue details with description.
    Example: oelite-gitlab.sh issue-show uranus/origin-auth 42

  issue-create <project-path> <agent> <title> [description]
    Create a new issue as the specified agent.
    Example: oelite-gitlab.sh issue-create oelite/uranus/origin-auth emma "feat: add tenant export" "Closes #7"

  issue-assign <project-path> <iid> <agent>
    Assign an issue to an agent.
    Example: oelite-gitlab.sh issue-assign uranus/origin-auth 42 daniel

  issue-comment <project-path> <iid> <agent> <message>
    Post a comment on an issue as the specified agent.
    Example: oelite-gitlab.sh issue-comment uranus/origin-auth 42 grace "LGTM"

  issue-status <project-path> <iid> <agent> <status>
    Update issue status (opened or closed) as the specified agent.
    Example: oelite-gitlab.sh issue-status uranus/origin-auth 42 emma closed

  worktree-create <agent> <branch> [--base <branch>] [--issue <iid>] [--no-issue] [--owner <team-member>] [--force]
    Create a git worktree for an agent with per-worktree identity.
    Default base branch is 'develop'. For backward compatibility, you may also
    pass base as a 3rd positional argument (e.g. <agent> <branch> <base> --issue N).
    --base <branch>: Branch to base the new worktree on (default: develop).
                     Use this for feature/release/maintenance branch cutoffs.
    --issue <iid>: GitLab issue number. Creates .worktrees/<agent>-<issue>.
                   Required by default (Issue-First workflow). Enables parallel
                   same-agent worktrees for different issues.
    --no-issue: Bypass the --issue requirement. Falls back to legacy
                .worktrees/<agent>/ naming. Use only for work that genuinely
                does not require an issue ticket.
    --owner: Team member who owns commit attribution (owner DNA).
             When omitted, the agent IS the owner.
    --force: Skip the pre-flight check that warns about stale worktrees
             for the same agent (per §1.8). Use only for spike work.
    Example: oelite-gitlab.sh worktree-create daniel feature/US-042-auth --issue 42
    Example: oelite-gitlab.sh worktree-create daniel feature/x --base develop --issue 42
    Example: oelite-gitlab.sh worktree-create sophia feature/auth --issue 15 --owner daniel
    Example: oelite-gitlab.sh worktree-create marcus feature/spike --no-issue

 worktree-sync
  Safe sync: refreshes origin/develop without checking out or switching branches.
  If develop is checked out anywhere, it remains pinned and the command exits 0.
  Otherwise local develop is updated with a fast-forward-only compare-and-swap.
  Divergent local develop is preserved. Run this BEFORE worktree-create.
  Example: oelite-gitlab.sh worktree-sync

 worktree-list
    List all active agent worktrees with branch, last commit, and sync status.

   worktree-remove <worktree-id> [--delete-branch]
     Remove a worktree. <worktree-id> is either <agent> or <agent>-<issue>.
     Use --delete-branch to also delete the branch.
     Note: MR source branch is auto-deleted by GitLab upon merge.
     Example: oelite-gitlab.sh worktree-remove daniel-42 --delete-branch
     Example: oelite-gitlab.sh worktree-remove daniel --delete-branch

   worktree-cleanup <agent> [--delete-branch]
     HARD GATE per GIT-WORKFLOW-STANDARDS.md section 1.8. Removes a worktree
     and (optionally) its local feature branch after the linked MR
     is merged or closed. Prunes orphan gitdir references first.
     Example: oelite-gitlab.sh worktree-cleanup daniel --delete-branch

   worktree-cleanup --all
     Sweep ALL worktrees in the current repo. For each worktree,
     queries GitLab for the linked MR state and removes if merged,
     closed, or not_found. Prunes orphan gitdir references. For
     Emma/Isabella periodic sweeps.
     Example: oelite-gitlab.sh worktree-cleanup --all

   worktree-check-stale [--agent <agent>] [--cleanup]
     Dry-run report of stale worktrees (orphans with missing
     directories). With --cleanup, auto-prunes them.
     Example: oelite-gitlab.sh worktree-check-stale
     Example: oelite-gitlab.sh worktree-check-stale --cleanup

   worktree-owner <worktree-id> [new-owner]
     View or update worktree owner DNA (commit attribution).
     <worktree-id> is either <agent> or <agent>-<issue>.
     Without new-owner: displays current owner identity.
     With new-owner: updates git config and owner metadata to the new owner.
     Example: oelite-gitlab.sh worktree-owner daniel-42
     Example: oelite-gitlab.sh worktree-owner daniel-42 emma

   oe-scope <worktree-id> [--task-type <type>] [--issue <iid>] [--desc <text>]
     Read or update the per-worktree .oe-scope file (compaction-resilient context anchor).
     <worktree-id> is either <agent> or <agent>-<issue>.
     Without options: prints the current scope file contents.
     With options: updates the specified fields in-place.
     Example: oelite-gitlab.sh oe-scope daniel-42
     Example: oelite-gitlab.sh oe-scope daniel-42 --task-type backend-impl --desc "Implement JWT refresh"

   mr-create <project-path> <agent> <source> <target> <title> [description]
     Create a merge request using the agent's PAT.
     Push your feature branch first, then run this to create MR.
     Example: oelite-gitlab.sh mr-create uranus/origin-auth daniel feature/auth develop "feat: JWT refresh" "Closes #42"

  mr-list <project-path>
    List open merge requests for a project.
    Example: oelite-gitlab.sh mr-list uranus/origin-auth

  mr-comment <project-path> <mr-iid> <agent> <message>
    Post a comment on a merge request as the specified agent.
    Example: oelite-gitlab.sh mr-comment uranus/origin-auth 15 grace "Use auto-discovery"

  mr-approve <project-path> <mr-iid> <agent>
    Approve a merge request as the specified agent.
    Example: oelite-gitlab.sh mr-approve uranus/origin-auth 15 grace

  mr-unapprove <project-path> <mr-iid> <agent>
    Revoke the specified agent's own approval on a merge request.
    Use to remove a stray/approved-by-mistake approval (only the approving
    identity can revoke its own approval).
    Example: oelite-gitlab.sh mr-unapprove uranus/origin-auth 15 grace

  mr-update <project-path> <mr-iid> <agent> <title> [description]
    Update MR title and description. Pass empty quotes for title to keep current title.
    Example: oelite-gitlab.sh mr-update uranus/origin-auth 420 isabella "fix: new title" "New description"

  mr-status <project-path> <mr-iid>
     Report independent merge readiness, pipeline evidence, and approval state.
     Used for merge verification before labeling an issue Done.
     Example: oelite-gitlab.sh mr-status uranus/origin-auth 15

   mr-show <project-path> <mr-iid> [--raw]
     Show an MR description and authoritative status fields through the wrapper.
     Use --raw to inspect the complete read-only API response.
      Example: oelite-gitlab.sh mr-show uranus/origin-auth 15 --raw

  mr-notes <project-path> <mr-iid> [agent]
    List non-system comments on a merge request (read-only, shows up to 100 notes);
    defaults to emma's PAT when [agent] is omitted.
    Example: oelite-gitlab.sh mr-notes oelite/helios/kortex 128 grace

  issue-notes <project-path> <iid> [agent]
    List non-system comments on an issue (read-only, shows up to 100 notes);
    defaults to emma's PAT.
    Example: oelite-gitlab.sh issue-notes oelite/helios/kortex 207 olivia

   pipeline-list <project-path> <agent> [<ref>]
      List pipeline id, status, SHA, and source, optionally filtered by ref.

  job-token-allowlist-add <project-path> <agent> <target-project>
      Add a target project to the source project's inbound CI_JOB_TOKEN allowlist.

  protected-branches <project-path> <agent>
      List protected branches (read-only diagnosis).

  protected-branch-show <project-path> <agent> <branch>
      Read one protected branch configuration (read-only diagnosis).

  protected-branch-code-owner <project-path> <agent> <branch> <on|off>
      Enable or disable protected-branch Code Owner approval, creating a
      missing protected branch with least-privilege defaults.

  pipeline-must-succeed <project-path> <agent> <on|off>
      Enable or disable the project successful-pipeline merge requirement.

  project-permissions <project-path> <agent>
      Print the calling PAT's project access level.

  project-approvals <project-path> [agent]
      Print the project's GitLab approval settings (approvals_required, specific
      approvers/approver-groups, reset rules). Use to verify whether the project
      enforces named approvers. Defaults to the emma PAT.
      Example: oelite-gitlab.sh project-approvals oelite/helios/kortex emma

  pipeline-jobs <project-path> <pipeline-id>
      List pipeline job status and failure reasons WITHOUT printing job traces.
      Use this to diagnose a failed pipeline reported by mr-status / mr-show.
      Example: oelite-gitlab.sh pipeline-jobs venus/mellow 9342

   pipeline-job-trace <project-path> <job-id>
      Print one job's trace for diagnosis. Treat the output as sensitive build data.
      Example: oelite-gitlab.sh pipeline-job-trace venus/mellow 12345

   pipeline-job-retry <project-path> <job-id> [<agent>]
      Retry a single failed job on its existing pipeline (same SHA), attributed to
      <agent> (default emma). Use for known-flaky failures so the reviewed head SHA
      is preserved instead of pushing a new commit.
      Example: oelite-gitlab.sh pipeline-job-retry oelite/helios/kortex 84300 ethan



  mr-close <project-path> <mr-iid> <agent>
    Close a merge request without merging (e.g. superseded, obsolete).
    Example: oelite-gitlab.sh mr-close uranus/origin-auth 15 emma

  issue-audit <project-path>
    List issues still open whose linked MRs were merged.
    Used for post-merge audit to catch orphaned open issues.
    Example: oelite-gitlab.sh issue-audit oelite/uranus/origin-auth

  mr-check-eligible <project-path>
    Check which open MRs meet auto-approval criteria. Fetches the open-MR list,
    then per-MR details for real head_pipeline evidence (the list endpoint does not
    serialize pipelines). Eligible = mergeable content, pipeline success on head SHA,
    not draft/WIP, not manual-review flagged, age >=10min. Unknown evidence fails closed.
    Pass --raw to dump the read-only list endpoint response.
    Example: oelite-gitlab.sh mr-check-eligible oelite/helios/core

mr-auto-approve <project-path>
     Auto-approve all MRs that meet eligibility criteria. Uses caller's PAT for approval attribution.
     Note: Security-sensitive MRs must be reviewed manually by Maya; architecture-critical by Marcus.
     Example: oelite-gitlab.sh mr-auto-approve oelite/helios/core

sync <worktree-id>
     Rebase the worktree's feature branch on the latest origin/develop.
     <worktree-id> is either <agent> or <agent>-<issue>.
     Use this to resolve conflicts before creating/updating an MR.
     Example: oelite-gitlab.sh sync daniel-42
     Example: oelite-gitlab.sh sync daniel

  status
    Show overall status: all worktrees, ahead/behind develop, stale detection.

  help
    Show this help message.

AGENTS:
  emma, marcus, daniel, sophia, jonathan, olivia,
  ethan, maya, victor, grace, felix, isabella

ENVIRONMENT:
  PATs are loaded from macOS Keychain via oelite-gitlab-env.sh.
  GitLab API: $OELITE_GITLAB_API (https://code.phanes.ltd/api/v4)
EOF
}

if [[ $# -lt 1 ]]; then
  cmd_help
  exit 0
fi

command="$1"
shift

case "$command" in
  setup)          cmd_setup "$@" ;;
  issues)         cmd_issues "$@" ;;
  issue-show)     cmd_issue_show "$@" ;;
  issue-notes)    cmd_issue_notes "$@" ;;
  issue-create)   cmd_issue_create "$@" ;;
  issue-assign)   cmd_issue_assign "$@" ;;
  issue-comment)  cmd_issue_comment "$@" ;;
  issue-status)   cmd_issue_status "$@" ;;
  issue-label)    cmd_issue_label "$@" ;;
 worktree-create) cmd_worktree_create "$@" ;;
 worktree-sync) cmd_worktree_sync "$@" ;;
 worktree-list) cmd_worktree_list "$@" ;;
  worktree-remove) cmd_worktree_remove "$@" ;;
  worktree-cleanup) cmd_worktree_cleanup "$@" ;;
  worktree-check-stale) cmd_worktree_check_stale "$@" ;;
  mr-create)      cmd_mr_create "$@" ;;
  mr-list)        cmd_mr_list "$@" ;;
  mr-comment)     cmd_mr_comment "$@" ;;
  mr-approve)     cmd_mr_approve "$@" ;;
  mr-unapprove)   cmd_mr_unapprove "$@" ;;
  mr-update)      cmd_mr_update "$@" ;;
  mr-status)      cmd_mr_status "$@" ;;
  mr-show)        cmd_mr_show "$@" ;;
  mr-notes)       cmd_mr_notes "$@" ;;
  pipeline-list)  cmd_pipeline_list "$@" ;;
  job-token-allowlist-add) cmd_job_token_allowlist_add "$@" ;;
  protected-branches) cmd_protected_branches "$@" ;;
  protected-branch-show) cmd_protected_branch_show "$@" ;;
  protected-branch-code-owner) cmd_protected_branch_code_owner "$@" ;;
  pipeline-must-succeed) cmd_pipeline_must_succeed "$@" ;;
  project-permissions) cmd_project_permissions "$@" ;;
  project-approvals)   cmd_project_approvals "$@" ;;
  pipeline-jobs)  cmd_pipeline_jobs "$@" ;;
  pipeline-job-trace) cmd_pipeline_job_trace "$@" ;;
  pipeline-job-retry) cmd_pipeline_job_retry "$@" ;;
  mr-merge)       cmd_mr_merge "$@" ;;
  mr-close)       cmd_mr_close "$@" ;;
  mr-check-eligible) cmd_mr_check_eligible "$@" ;;
  mr-auto-approve)  cmd_mr_auto_approve "$@" ;;
  issue-audit)    cmd_issue_audit "$@" ;;
  sync)           cmd_sync "$@" ;;
  status)         cmd_status "$@" ;;
  worktree-owner) cmd_worktree_owner "$@" ;;
  oe-scope)       cmd_oe_scope "$@" ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "[ERROR] Unknown command: $command" >&2
    echo "Run 'oelite-gitlab.sh help' for usage." >&2
    exit 1
    ;;
esac
