#!/bin/zsh
emulate -L zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/oelite-gitlab-env.sh" 2>/dev/null || {
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
  python3 -c 'import sys,json; d=json.load(sys.stdin); v=d.get(sys.argv[1]); print(v if v is not None else sys.argv[2])' "$1" "$2"
}

json_encode_value() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read().rstrip('\n')))" <<< "$1"
}

url_encode_path() {
  echo "${1//\//%2F}"
}

get_pat() {
  local agent="$1"
  local var_name="OELITE_PAT_${agent:u}"
  local pat="${(P)var_name}"
  if [[ -z "$pat" ]]; then
    local alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
    pat="${(P)alias_name}"
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
    curl_args+=(--data "$data")
  fi

  _API_STATUS=$(curl "${curl_args[@]}")
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
  git rev-parse --show-toplevel 2>/dev/null || {
    echo "[ERROR] Not inside a git repository" >&2
    exit 1
  }
}

worktree_path() {
  local agent="$1"
  local root
  root=$(repo_root)
  echo "$root/.worktrees/$agent"
}

check_worktree_exists() {
  local agent="$1"
  local wt_path
  wt_path=$(worktree_path "$agent")
  if [[ ! -d "$wt_path" ]]; then
    echo "[ERROR] Worktree not found for agent: $agent (expected: $wt_path)" >&2
    return 1
  fi
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
    endpoint+="&labels=$label_filter"
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
  local status="$4"

  validate_agent "$agent" || return 1
  [[ -z "$status" ]] && { echo "[ERROR] Status required" >&2; return 1; }

  local valid_states="opened closed"
  [[ ! " $valid_states " =~ " $status " ]] && { echo "[ERROR] Invalid status '$status'. Use: opened or closed" >&2; return 1; }

  local encoded_path
  encoded_path=$(url_encode_path "$project_path")

  local data
  data=$(python3 -c "import json; print(json.dumps({'state_event': '$status'}))")

  local pat
  pat=$(get_pat "$agent")
  api_post "/projects/$encoded_path/issues/$iid" "$pat" "$data"

  if [[ "$_API_STATUS" -ge 200 && "$_API_STATUS" -lt 300 ]]; then
    echo "[OK] Issue #$iid status set to $status by $agent"
  else
    echo "[ERROR] Failed to set issue status (HTTP $_API_STATUS)" >&2
    api_error_hint "$_API_STATUS" "$project_path"
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_worktree_create() {
  local agent="$1"
  local branch="$2"
  local base_branch="${3:-develop}"
  local owner="$agent"  # Default: agent IS the owner (owner DNA)

  validate_agent "$agent" || return 1

  shift 3 2>/dev/null || shift $#

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --owner)
        if [[ -z "${2:-}" ]]; then
          echo "[ERROR] --owner requires a value" >&2
          return 1
        fi
        owner="$2"
        shift 2
        ;;
      *)
        echo "[ERROR] Unknown option: $1" >&2
        return 1
        ;;
    esac
  done

  # Validate owner if specified (can be different from agent when delegating)
  if [[ "$owner" != "$agent" ]]; then
    if [[ -z "${AGENT_IDS[$owner]:-}" ]]; then
      echo "[ERROR] Unknown owner: $owner" >&2
      echo "Valid owners: ${(j:, :)ALL_AGENTS}" >&2
      return 1
    fi
  fi

  local root
  root=$(repo_root)
  local wt_path="$root/.worktrees/$agent"

  if [[ -d "$wt_path" ]]; then
    echo "[ERROR] Worktree already exists for $agent at $wt_path" >&2
    return 1
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

  local owner_name
  owner_name=$(get_agent_name "$owner")
  local owner_email
  owner_email=$(get_agent_email "$owner")

  # Owner DNA: git identity = owner, not agent
  git -C "$wt_path" config --local user.name "$owner_name"
  git -C "$wt_path" config --local user.email "$owner_email"

  # Store ownership metadata for workflow tracking
  echo "$owner" > "$wt_path/.git-worktree-owner"

  # Log ownership attribution (for transparency)
  if [[ "$owner" != "$agent" ]]; then
    echo "[OK] Worktree created for executor $agent (owner: $owner)"
  else
    echo "[OK] Worktree created for $agent"
  fi
  echo "  Path:   $wt_path"
  echo "  Branch: $branch"
  echo "  Owner:  $owner_name <$owner_email> (owner DNA)"
  if [[ "$owner" != "$agent" ]]; then
    echo "  Executor: $agent (using owner's GitLab identity)"
  fi
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
  local agent="$1"
  shift

  local delete_branch=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --delete-branch) delete_branch=true; shift ;;
      *)               echo "[ERROR] Unknown option: $1" >&2; return 1 ;;
    esac
  done

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent")
  local branch
  branch=$(git -C "$wt_path" branch --show-current)

  echo "Removing worktree for $agent..."
  git worktree remove "$wt_path"

  if $delete_branch && [[ -n "$branch" ]]; then
    if git branch -D "$branch" 2>/dev/null; then
      echo "  Deleted branch: $branch"
    else
      echo "  [WARN] Could not delete branch: $branch" >&2
    fi
  fi

  echo "[OK] Worktree removed for $agent"
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

cmd_mr_check_eligible() {
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
from datetime import datetime, timezone

mrs = json.load(sys.stdin)
if not mrs:
    print("No open merge requests found.")
    sys.exit(0)

print("{:<6} | {:<40} | {:<16} | {:<12} | ELIGIBLE | REASONS".format("IID", "Title", "Author", "Status"))
print("-" * 130)

for mr in mrs:
    iid = str(mr.get("iid", ""))
    title = mr.get("title", "")[:40]
    author = mr.get("author", {}).get("username", "")[:16]
    merge_status = mr.get("merge_status", "")
    state = mr.get("state", "")
    created_at = mr.get("created_at", "")
    labels = mr.get("labels", [])

    reasons = []
    eligible = True

    if merge_status not in ("can_be_merged", "merge_status_can_be_merged"):
        eligible = False
        reasons.append("CI not green")

    if mr.get("has_conflicts", False):
        eligible = False
        reasons.append("Has conflicts")

    if title.startswith("WIP:"):
        eligible = False
        reasons.append("WIP flag")

    if "requires-manual-review" in labels:
        eligible = False
        reasons.append("Manual review flag")

    if created_at:
        try:
            created_dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            now_dt = datetime.now(timezone.utc)
            age_minutes = (now_dt - created_dt).total_seconds() / 60
            if age_minutes < 10:
                eligible = False
                reasons.append("Age <10m ({:.0f}m)".format(age_minutes))
        except (ValueError, TypeError):
            pass

    status_str = "ELIGIBLE" if eligible else "INELIGIBLE"
    reasons_str = ", ".join(reasons) if reasons else "-"
    color_marker = "OK" if eligible else "XX"

    print("{:<6} | {:<40} | {:<16} | {:<12} | {} {:<11} | {}".format(
        iid, title, author, merge_status or state, color_marker, status_str, reasons_str))

print()
print("Total: " + str(len(mrs)) + " open MR(s)")
'
}

cmd_mr_auto_approve() {
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

  echo "Checking eligible MRs..."
  echo ""
  
  local eligible_mrs
  eligible_mrs=$(printf '%s\n' "$_API_RESPONSE" | python3 -c '
import sys, json
from datetime import datetime, timezone

mrs = json.load(sys.stdin)
eligible = []

for mr in mrs:
    iid = mr.get("iid")
    title = mr.get("title", "")
    merge_status = mr.get("merge_status", "")
    labels = mr.get("labels", [])
    created_at = mr.get("created_at", "")
    has_conflicts = mr.get("has_conflicts", False)

    is_eligible = True

    if merge_status not in ("can_be_merged", "merge_status_can_be_merged"):
        is_eligible = False

    if has_conflicts:
        is_eligible = False

    if title.startswith("WIP:"):
        is_eligible = False

    if "requires-manual-review" in labels:
        is_eligible = False

    if created_at and is_eligible:
        try:
            created_dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
            now_dt = datetime.now(timezone.utc)
            age_minutes = (now_dt - created_dt).total_seconds() / 60
            if age_minutes < 10:
                is_eligible = False
        except (ValueError, TypeError):
            pass

    if is_eligible:
        eligible.append(iid)

for iid in eligible:
    print(iid)
')

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
      ((approved_count++))
    else
      echo "[WARN] MR !$mr_iid approval failed (HTTP $_API_STATUS) — may require manual approval" >&2
      ((failed_count++))
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

cmd_sync() {
  local agent="$1"

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent")

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
  local agent="$1"
  local new_owner="${2:-}"

  validate_agent "$agent" || return 1
  check_worktree_exists "$agent" || return 1

  local wt_path
  wt_path=$(worktree_path "$agent")
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
    echo "Worktree Owner DNA for $agent:"
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
    git -C "$wt_path" config --local user.name "$new_owner_name"
    git -C "$wt_path" config --local user.email "$new_owner_email"

    echo "[OK] Owner DNA updated for $agent:"
    echo "  Path:   $wt_path"
    echo "  New owner: $new_owner_name <$new_owner_email>"
  fi
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

  issue-assign <project-path> <iid> <agent>
    Assign an issue to an agent.
    Example: oelite-gitlab.sh issue-assign uranus/origin-auth 42 daniel

  issue-comment <project-path> <iid> <agent> <message>
    Post a comment on an issue as the specified agent.
    Example: oelite-gitlab.sh issue-comment uranus/origin-auth 42 grace "LGTM"

  issue-status <project-path> <iid> <agent> <status>
    Update issue status (opened or closed) as the specified agent.
    Example: oelite-gitlab.sh issue-status uranus/origin-auth 42 emma closed

  worktree-create <agent> <branch> [base-branch] [--owner <team-member>]
    Create a git worktree for an agent with per-worktree identity.
    Default base-branch is develop.
    --owner specifies the team member who owns the commit attribution (owner DNA).
    When omitted, the agent IS the owner.
    Example: oelite-gitlab.sh worktree-create daniel feature/US-001-auth
    Example: oelite-gitlab.sh worktree-create sophia feature/auth --owner daniel

  worktree-list
    List all active agent worktrees with branch, last commit, and sync status.

   worktree-remove <agent> [--delete-branch]
     Remove an agent's worktree. Use --delete-branch to also delete the branch.
     Note: MR source branch is auto-deleted by GitLab upon merge.
     Example: oelite-gitlab.sh worktree-remove daniel --delete-branch

  worktree-owner <agent> [new-owner]
    View or update worktree owner DNA (commit attribution).
    Without new-owner: displays current owner identity.
    With new-owner: updates git config and owner metadata to the new owner.
    Example: oelite-gitlab.sh worktree-owner daniel
    Example: oelite-gitlab.sh worktree-owner daniel emma

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

  mr-check-eligible <project-path>
    Check which open MRs meet auto-approval criteria (CI green, no conflicts, not WIP, not manual-review flagged, age ≥10min).
    Example: oelite-gitlab.sh mr-check-eligible oelite/helios/core

mr-auto-approve <project-path>
     Auto-approve all MRs that meet eligibility criteria. Uses caller's PAT for approval attribution.
     Note: Security-sensitive MRs must be reviewed manually by Maya; architecture-critical by Marcus.
     Example: oelite-gitlab.sh mr-auto-approve oelite/helios/core

sync <agent>
     Rebase the agent's feature branch on the latest origin/develop.
     Use this to resolve conflicts before creating/updating an MR.
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
  issue-assign)   cmd_issue_assign "$@" ;;
  issue-comment)  cmd_issue_comment "$@" ;;
  issue-status)   cmd_issue_status "$@" ;;
  worktree-create) cmd_worktree_create "$@" ;;
  worktree-list)  cmd_worktree_list "$@" ;;
  worktree-remove) cmd_worktree_remove "$@" ;;
  mr-create)      cmd_mr_create "$@" ;;
  mr-list)        cmd_mr_list "$@" ;;
  mr-comment)     cmd_mr_comment "$@" ;;
  mr-approve)     cmd_mr_approve "$@" ;;
  mr-check-eligible) cmd_mr_check_eligible "$@" ;;
  mr-auto-approve)  cmd_mr_auto_approve "$@" ;;
  sync)           cmd_sync "$@" ;;
  status)         cmd_status "$@" ;;
  worktree-owner) cmd_worktree_owner "$@" ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "[ERROR] Unknown command: $command" >&2
    echo "Run 'oelite-gitlab.sh help' for usage." >&2
    exit 1
    ;;
esac
