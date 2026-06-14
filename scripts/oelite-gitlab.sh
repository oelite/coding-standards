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
  local var_name="OELITE_PAT_${1:u}"
  echo "${(P)var_name}"
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
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  echo "$_API_RESPONSE" | python3 -c "
import sys, json
issues = json.load(sys.stdin)
if not issues:
    print('No open issues found.')
    sys.exit(0)
print(f'{\"IID\":<6} │ {\"Title\":<50} │ {\"Labels\":<20} │ {\"Assignee\":<18} │ {\"Created\":<10}')
print('─' * 115)
for i in issues:
    iid = str(i.get('iid', ''))
    title = i.get('title', '')[:50]
    labels = ','.join(i.get('labels', []))[:20]
    assignee = i.get('assignee', {})
    assignee_name = assignee.get('username', '') if assignee else ''
    created = i.get('created_at', '')[:10]
    print(f'{iid:<6} │ {title:<50} │ {labels:<20} │ {assignee_name:<18} │ {created:<10}')
print()
print(f'Total: {len(issues)} open issue(s)')
"
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
    echo "$_API_RESPONSE" >&2
    return 1
  fi
}

cmd_worktree_create() {
  local agent="$1"
  local branch="$2"
  local base_branch="${3:-develop}"

  validate_agent "$agent" || return 1

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

  local agent_name
  agent_name=$(get_agent_name "$agent")
  local agent_email
  agent_email=$(get_agent_email "$agent")

  git -C "$wt_path" config --local user.name "$agent_name"
  git -C "$wt_path" config --local user.email "$agent_email"

  echo "[OK] Worktree created for $agent"
  echo "  Path:   $wt_path"
  echo "  Branch: $branch"
  echo "  Config: user.name=$agent_name, user.email=$agent_email"
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
    echo "$_API_RESPONSE" >&2
    return 1
  fi

  echo "$_API_RESPONSE" | python3 -c "
import sys, json
mrs = json.load(sys.stdin)
if not mrs:
    print('No open merge requests found.')
    sys.exit(0)
print(f'{\"IID\":<6} │ {\"Title\":<45} │ {\"Author\":<18} │ {\"Source → Target\":<35} │ {\"Status\":<12} │ Reviewers')
print('─' * 140)
for mr in mrs:
    iid = str(mr.get('iid', ''))
    title = mr.get('title', '')[:45]
    author = mr.get('author', {}).get('username', '')[:18]
    source = mr.get('source_branch', '')
    target = mr.get('target_branch', '')
    branch_info = f'{source} → {target}'
    status = mr.get('merge_status', '') or mr.get('state', '')
    reviewers = mr.get('reviewers', [])
    reviewer_names = ','.join([r.get('username', '') for r in reviewers])[:30] if reviewers else ''
    print(f'{iid:<6} │ {title:<45} │ {author:<18} │ {branch_info:<35} │ {status:<12} │ {reviewer_names}')
print()
print(f'Total: {len(mrs)} open MR(s)')
"
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
    echo "$_API_RESPONSE" >&2
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

  printf "%-12s │ %-30s │ %-8s │ %-8s │ %-12s │ %s\n" "AGENT" "BRANCH" "AHEAD" "BEHIND" "LAST COMMIT" "STATUS"
  print_separator 100

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

          printf "%-12s │ %-30s │ %-8s │ %-8s │ %-12s │ %s\n" \
            "$agent_name" "$branch" "$ahead" "$behind" "$last_date" "$status_label"
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

  worktree-create <agent> <branch> [base-branch]
    Create a git worktree for an agent with per-worktree identity.
    Default base-branch is develop.
    Example: oelite-gitlab.sh worktree-create daniel feature/US-001-auth

  worktree-list
    List all active agent worktrees with branch, last commit, and sync status.

  worktree-remove <agent> [--delete-branch]
    Remove an agent's worktree. Use --delete-branch to also delete the branch.
    Example: oelite-gitlab.sh worktree-remove daniel --delete-branch

  mr-create <project-path> <agent> <source> <target> <title> [description]
    Create a merge request using the agent's PAT.
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

  sync <agent>
    Rebase the agent's worktree on the latest origin/develop.
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
  worktree-create) cmd_worktree_create "$@" ;;
  worktree-list)  cmd_worktree_list "$@" ;;
  worktree-remove) cmd_worktree_remove "$@" ;;
  mr-create)      cmd_mr_create "$@" ;;
  mr-list)        cmd_mr_list "$@" ;;
  mr-comment)     cmd_mr_comment "$@" ;;
  mr-approve)     cmd_mr_approve "$@" ;;
  sync)           cmd_sync "$@" ;;
  status)         cmd_status "$@" ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "[ERROR] Unknown command: $command" >&2
    echo "Run 'oelite-gitlab.sh help' for usage." >&2
    exit 1
    ;;
esac
