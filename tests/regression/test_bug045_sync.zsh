#!/bin/zsh
# BUG-045: real disposable Git repositories; no API or persistence doubles.
emulate -L zsh
set -euo pipefail
export GIT_MASTER=1 OELITE_VALIDATE_PATS=false
export GIT_AUTHOR_NAME=Regression GIT_AUTHOR_EMAIL=regression@example.invalid
export GIT_COMMITTER_NAME=Regression GIT_COMMITTER_EMAIL=regression@example.invalid
script="${0:A:h:h:h}/scripts/oelite-gitlab.sh"
sandbox=$(mktemp -d "${0:A:h}/.bug045-sync.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
integer passed=0 failed=0
check() {
  if eval "$2"; then
    print "PASS: $1"
    passed=$((passed + 1))
  else
    print "FAIL: $1"
    failed=$((failed + 1))
  fi
}
git init --bare --initial-branch=develop "$sandbox/origin" >/dev/null
git clone "$sandbox/origin" "$sandbox/checkout" 2>/dev/null
repo="$sandbox/checkout"
print initial > "$repo/tracked"
git -C "$repo" add tracked
git -C "$repo" commit -m initial >/dev/null
git -C "$repo" push origin develop 2>/dev/null
initial=$(git -C "$repo" rev-parse HEAD)
# Advance the real bare origin using Git plumbing, without a second checkout.
tree=$(git -C "$repo" rev-parse HEAD^{tree})
remote=$(print remote | git -C "$sandbox/origin" commit-tree "$tree" -p "$initial")
git -C "$sandbox/origin" update-ref refs/heads/develop "$remote"
run_sync() {
  local location="$1"
  output=$( (builtin cd "$location"; "$script" worktree-sync) 2>&1) && result=0 || result=$?
  print -r -- "$output"
}
print dirty >> "$repo/tracked"
print untracked > "$repo/untracked"
run_sync "$repo"
check 'AC-001 checked-out develop succeeds' '[[ $result == 0 ]]'
check 'AC-001 origin/develop refreshed' '[[ $(git -C "$repo" rev-parse origin/develop) == "$remote" ]]'
check 'AC-001 local checkout preserved' '[[ $(git -C "$repo" rev-parse HEAD) == "$initial" && "$output" == *"checked out"* ]]'
check 'AC-003 tracked and untracked changes preserved' '[[ $(<"$repo/tracked") == $'"'"'initial\ndirty'"'"' && $(<"$repo/untracked") == untracked ]]'
git -C "$repo" switch -c feature/test >/dev/null
run_sync "$repo"
check 'AC-002 unchecked-out develop fast-forwarded' '[[ $result == 0 && $(git -C "$repo" rev-parse develop) == "$remote" ]]'
check 'AC-003 feature branch and dirty changes preserved' '[[ $(git -C "$repo" branch --show-current) == feature/test && $(<"$repo/tracked") == $'"'"'initial\ndirty'"'"' ]]'
git -C "$repo" worktree add "$sandbox/linked checkout" develop >/dev/null
next=$(print next | git -C "$sandbox/origin" commit-tree "$tree" -p "$remote")
git -C "$sandbox/origin" update-ref refs/heads/develop "$next"
run_sync "$sandbox/linked checkout"
check 'linked checkout pins develop, including space in path' '[[ $result == 0 && $(git -C "$repo" rev-parse develop) == "$remote" && $(git -C "$repo" rev-parse origin/develop) == "$next" ]]'
git -C "$repo" worktree remove "$sandbox/linked checkout"
local_commit=$(print local | git -C "$repo" commit-tree "$tree" -p "$initial")
git -C "$repo" update-ref refs/heads/develop "$local_commit"
run_sync "$repo"
check 'divergent develop preserved with explicit warning' '[[ $result == 0 && $(git -C "$repo" rev-parse develop) == "$local_commit" && "$output" == *"diverg"* ]]'
git -C "$repo" update-ref -d refs/heads/develop
run_sync "$repo"
check 'missing local develop safely created' '[[ $result == 0 && $(git -C "$repo" rev-parse develop) == "$next" ]]'
git -C "$repo" update-ref -d refs/remotes/origin/develop
run_sync "$repo"
check 'missing tracking ref restored' '[[ $result == 0 && $(git -C "$repo" rev-parse origin/develop) == "$next" ]]'
git -C "$repo" remote set-url origin "$sandbox/absent"
run_sync "$repo"
check 'AC-004 real origin failure returns nonzero and diagnostic' '[[ $result != 0 && "$output" == *"origin"* && "$output" == *"ERROR"* ]]'
print "RESULT: $passed passed, $failed failed"
(( failed == 0 ))
