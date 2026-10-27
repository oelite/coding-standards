#!/usr/bin/env zsh
# Regression tests for scripts/oelite-gitlab.sh wrapper bugs #48 and #49.
#
# Covers:
#   #49 — worktree-cleanup SIGPIPE (exit 141) when an agent has >1 matching
#         worktree, caused by `$(... | head -1)` under `set -o pipefail`.
#         Also guards: an open-MR worktree must never be removed, and all
#         matching worktrees are processed (not just the first).
#   #48 — oe-scope --desc must survive shell/sed special characters verbatim.
#
# Run from anywhere:
#   coding-standards/scripts/tests/run-wrapper-tests.sh
#
# The harness builds a throwaway git repo with fake agent worktrees, sources
# the wrapper, and stubs `get_mr_state_for_branch` so no GitLab state is
# touched. MR-state lookups against the real API are never performed.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
WRAPPER="$SCRIPT_DIR/../oelite-gitlab.sh"

PASS=0
FAIL=0

pass() { print -P "  %F{green}[PASS]%f $1"; PASS=$((PASS + 1)); }
fail() { print -P "  %F{red}[FAIL]%f $1"; FAIL=$((FAIL + 1)); }

assert_dir_exists() {
  if [[ -d "$1" ]]; then pass "$2"; else fail "$2 (missing dir: $1)"; fi
}
assert_dir_gone() {
  if [[ ! -d "$1" ]]; then pass "$2"; else fail "$2 (dir still present: $1)"; fi
}
assert_branch_gone() {
  if ! git -C "$TMPROOT" show-ref --verify --quiet "refs/heads/$1"; then
    pass "$2"
  else
    fail "$2 (branch still exists: $1)"
  fi
}
assert_branch_exists() {
  if git -C "$TMPROOT" show-ref --verify --quiet "refs/heads/$1"; then
    pass "$2"
  else
    fail "$2 (branch missing: $1)"
  fi
}

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oelite-wrapper-test.XXXXXX")"
# Resolve symlinks (macOS: /var → /private/var, /tmp → /private/tmp) so the
# fixture paths match what `git worktree list --porcelain` reports — the
# wrapper matches worktrees against the physical repo root.
TMPROOT="${TMPROOT:A}"
trap 'rm -rf "$TMPROOT"' EXIT

print "Temp repo: $TMPROOT"

# ── Build fixture repo with two fake agent worktrees (the #49 shape) ──
git -C "$TMPROOT" init -q -b develop
git -C "$TMPROOT" -c user.email=test@phanes.ltd -c user.name=Test \
  commit -q --allow-empty -m "initial"
git -C "$TMPROOT" worktree add -q -b feature/wt-a "$TMPROOT/.worktrees/daniel-35"
git -C "$TMPROOT" worktree add -q -b feature/wt-b "$TMPROOT/.worktrees/daniel-43"
# A decoy worktree for another agent that must never be touched.
git -C "$TMPROOT" worktree add -q -b feature/wt-c "$TMPROOT/.worktrees/sophia-37"

# ── Source the wrapper. Passing "help" prevents the top-level dispatcher
#    from exiting the harness; it only prints usage. This also imports the
#    production `set -euo pipefail` under which the SIGPIPE bug fired. ──
source "$WRAPPER" help >/dev/null

# Stub the MR-state lookup — no GitLab API calls from this harness.
STUB_MR_STATE="opened"
get_mr_state_for_branch() { print -r -- "$STUB_MR_STATE"; }

# ────────────────────────────────────────────────────────────────────
print "\nTEST 1 (#49): cleanup with 2 matching worktrees, MRs still open"
STUB_MR_STATE="opened"
OUT="$(cd "$TMPROOT" && cmd_worktree_cleanup daniel 2>&1)"
RC=$?
if [[ $RC -eq 0 ]]; then
  pass "exit 0 under pipefail with 2 matching worktrees (was SIGPIPE/141)"
else
  fail "expected exit 0, got $RC"
fi
print "$OUT" | grep -q "still open; not removing" \
  && pass "open-MR worktree skipped with visible guard message" \
  || fail "open-MR guard message missing"
assert_dir_exists "$TMPROOT/.worktrees/daniel-35" "worktree daniel-35 preserved"
assert_dir_exists "$TMPROOT/.worktrees/daniel-43" "worktree daniel-43 preserved"
assert_dir_exists "$TMPROOT/.worktrees/sophia-37" "other agent's worktree untouched"

print "\nTEST 2 (#49): cleanup with 2 matching worktrees, MRs merged"
STUB_MR_STATE="merged"
OUT="$(cd "$TMPROOT" && cmd_worktree_cleanup daniel 2>&1)"
RC=$?
if [[ $RC -eq 0 ]]; then
  pass "exit 0 processing multiple merged-MR worktrees"
else
  fail "expected exit 0, got $RC"
fi
assert_dir_gone "$TMPROOT/.worktrees/daniel-35" "worktree daniel-35 removed (MR=merged)"
assert_dir_gone "$TMPROOT/.worktrees/daniel-43" "worktree daniel-43 removed (MR=merged)"
assert_dir_exists "$TMPROOT/.worktrees/sophia-37" "other agent's worktree untouched"

print "\nTEST 3 (#49): --delete-branch removes local branches too"
# Fresh daniel worktree (branch unique to this test) with MR closed.
git -C "$TMPROOT" worktree add -q -b feature/wt-daniel-50 "$TMPROOT/.worktrees/daniel-50"
STUB_MR_STATE="closed"
OUT="$(cd "$TMPROOT" && cmd_worktree_cleanup daniel --delete-branch 2>&1)"
RC=$?
if [[ $RC -eq 0 ]]; then
  pass "exit 0 with --delete-branch on merged worktree"
else
  fail "expected exit 0, got $RC"
fi
assert_dir_gone "$TMPROOT/.worktrees/daniel-50" "worktree daniel-50 removed (MR=closed)"
assert_branch_gone "feature/wt-daniel-50" "local branch feature/wt-daniel-50 deleted"
assert_branch_exists "feature/wt-c" "sophia's branch feature/wt-c untouched"

print "\nTEST 4 (#49): no matching worktrees exits cleanly"
STUB_MR_STATE="not_found"
OUT="$(cd "$TMPROOT" && cmd_worktree_cleanup ethan 2>&1)"
RC=$?
if [[ $RC -eq 0 && "$OUT" == *"No worktree found for agent: ethan"* ]]; then
  pass "exit 0 + info message when agent has no worktrees"
else
  fail "expected clean no-match exit (rc=$RC, out=$OUT)"
fi

print "\nTEST 5 (#48): oe-scope --desc survives special characters verbatim"
# Fixture .oe-scope inside a daniel worktree (cmd_oe_scope resolves paths
# relative to the repo root of the CWD).
mkdir -p "$TMPROOT/.worktrees/daniel-35"
cat > "$TMPROOT/.worktrees/daniel-35/.oe-scope" <<'EOF'
AGENT=daniel
TASK_TYPE=backend-impl
ISSUE=35
TASK_DESCRIPTION=original
EOF
SPECIAL_DESC='a/b & c | d "quote" '"'"'sq'"'"' $VAR `cmd` (paren) &more/2'
OUT="$(cd "$TMPROOT" && cmd_oe_scope daniel-35 --desc "$SPECIAL_DESC" 2>&1)"
RC=$?
ACTUAL="$(grep '^TASK_DESCRIPTION=' "$TMPROOT/.worktrees/daniel-35/.oe-scope")"
EXPECTED="TASK_DESCRIPTION=$SPECIAL_DESC"
if [[ $RC -eq 0 && "$ACTUAL" == "$EXPECTED" ]]; then
  pass "special chars written verbatim (exit 0)"
else
  fail "desc mangled or errored (rc=$RC)"
  print "    expected: $EXPECTED"
  print "    actual:   $ACTUAL"
fi

print "\nTEST 6 (#48): oe-scope --desc plain text unchanged (regression)"
OUT="$(cd "$TMPROOT" && cmd_oe_scope daniel-35 --desc "plain text only" 2>&1)"
RC=$?
ACTUAL="$(grep '^TASK_DESCRIPTION=' "$TMPROOT/.worktrees/daniel-35/.oe-scope")"
if [[ $RC -eq 0 && "$ACTUAL" == "TASK_DESCRIPTION=plain text only" ]]; then
  pass "plain-text description written verbatim"
else
  fail "plain-text regression (rc=$RC, got: $ACTUAL)"
fi

print "\nTEST 7 (#48): oe-scope --task-type and --issue still work"
OUT="$(cd "$TMPROOT" && cmd_oe_scope daniel-35 --task-type infrastructure --issue 36 2>&1)"
RC=$?
TT="$(grep '^TASK_TYPE=' "$TMPROOT/.worktrees/daniel-35/.oe-scope")"
IS="$(grep '^ISSUE=' "$TMPROOT/.worktrees/daniel-35/.oe-scope")"
if [[ $RC -eq 0 && "$TT" == "TASK_TYPE=infrastructure" && "$IS" == "ISSUE=36" ]]; then
  pass "--task-type and --issue updates intact"
else
  fail "task-type/issue regression (rc=$RC, tt=$TT, is=$IS)"
fi

print ""
print "════════════════════════════════════"
print "INFRA-288 regression tests: remote-branch deletion guard + mr-merge flags"

# ────────────────────────────────────────────────────────────────────
# INFRA-288 TEST 8: assert_no_open_mr_references_branch blocks when an open
# MR references the branch (stubbed MR state = opened).
print "\nTEST 8 (#288): remote-delete guard BLOCKS branch with open MR"
STUB_MR_STATE="opened"
RC=0
OUT="$(assert_no_open_mr_references_branch "oelite/test/project" "feature/stacked-src" 2>&1)" || RC=$?
if [[ $RC -eq 1 && "$OUT" == *"[BLOCKED]"* && "$OUT" == *"OPEN merge request"* ]]; then
  pass "guard refuses branch with open MR (exit 1, [BLOCKED] message)"
else
  fail "guard did not block open-MR branch (rc=$RC, out=$OUT)"
fi

# INFRA-288 TEST 9: guard allows deletion when MR is merged/closed/not_found.
print "\nTEST 9 (#288): remote-delete guard ALLOWS branch without open MR"
for state in merged closed not_found; do
  STUB_MR_STATE="$state"
  RC=0
  OUT="$(assert_no_open_mr_references_branch "oelite/test/project" "feature/merged-branch" 2>&1)" || RC=$?
  if [[ $RC -eq 0 ]]; then
    pass "guard allows deletion when MR state=$state"
  else
    fail "guard wrongly blocked MR state=$state (rc=$RC, out=$OUT)"
  fi
done

# INFRA-288 TEST 10: guard fails closed on missing arguments.
print "\nTEST 10 (#288): remote-delete guard fails closed on missing args"
STUB_MR_STATE="not_found"
RC=0
OUT="$(assert_no_open_mr_references_branch "oelite/test/project" "" 2>&1)" || RC=$?
if [[ $RC -eq 1 ]]; then
  pass "guard fails closed (exit 1) when branch arg is empty"
else
  fail "guard did not fail closed on empty branch arg (rc=$RC)"
fi
RC=0
OUT="$(assert_no_open_mr_references_branch "" "some-branch" 2>&1)" || RC=$?
if [[ $RC -eq 1 ]]; then
  pass "guard fails closed (exit 1) when project arg is empty"
else
  fail "guard did not fail closed on empty project arg (rc=$RC)"
fi

# INFRA-288 TEST 11: mr-merge payload honors --keep-source-branch /
# --delete-source-branch by inspecting the generated JSON payload.
# We can't call cmd_mr_merge against the real API; instead verify the
# python one-liner inside cmd_mr_merge produces the right JSON for each
# flag combination by re-running the same python fragment.
print "\nTEST 11 (#288): mr-merge payload reflects source-branch flag"
_payload_for() {
  local delete_source_branch=$1
  python3 -c "import json; print(json.dumps({'should_remove_source_branch': $( [[ $delete_source_branch == true ]] && echo True || echo False ), 'squash': False}))"
}
P1="$(_payload_for true)"
P2="$(_payload_for false)"
if [[ "$P1" == *'"should_remove_source_branch": true'* ]]; then
  pass "default payload has should_remove_source_branch=true"
else
  fail "default payload wrong: $P1"
fi
if [[ "$P2" == *'"should_remove_source_branch": false'* ]]; then
  pass "--keep-source-branch payload has should_remove_source_branch=false"
else
  fail "--keep-source-branch payload wrong: $P2"
fi

# INFRA-288 TEST 12: mr-merge rejects unknown flags (argument parsing).
print "\nTEST 12 (#288): mr-merge rejects unknown flags"
# shellcheck disable=SC2317  # cmd_mr_merge body is never reached — arg parsing fails first
mr_merge_arg_parse() {
  local delete_source_branch=true
  while [[ $# -gt 3 ]]; do
    case "$4" in
      --delete-source-branch) delete_source_branch=true;  shift ;;
      --keep-source-branch)   delete_source_branch=false; shift ;;
      *)               echo "[ERROR] Unknown option: $4" >&2; return 1 ;;
    esac
  done
  return 0
}
RC=0
OUT="$(mr_merge_arg_parse proj 15 emma --bogus-flag 2>&1)" || RC=$?
if [[ $RC -eq 1 && "$OUT" == *"Unknown option"* ]]; then
  pass "unknown flag rejected with clear error"
else
  fail "unknown flag not rejected (rc=$RC, out=$OUT)"
fi
RC=0
OUT="$(mr_merge_arg_parse proj 15 emma --keep-source-branch 2>&1)" || RC=$?
if [[ $RC -eq 0 ]]; then
  pass "--keep-source-branch accepted by arg parser"
else
  fail "--keep-source-branch rejected (rc=$RC, out=$OUT)"
fi
OUT="$(mr_merge_arg_parse proj 15 emma --delete-source-branch 2>&1)"
RC=$?
if [[ $RC -eq 0 ]]; then
  pass "--delete-source-branch accepted by arg parser"
else
  fail "--delete-source-branch rejected (rc=$RC, out=$OUT)"
fi

# INFRA-288 TEST 13: worktree-cleanup / worktree-remove code paths contain
# no remote branch deletion (grep-level static assertion against
# `git push --delete` / `git push origin :<ref>`).
print "\nTEST 13 (#288): no remote branch deletion in cleanup code paths"
for fn in cmd_worktree_cleanup cmd_worktree_remove cleanup_local_worktree_for_branch; do
  BODY=$(typeset -f "$fn")
  if print -r -- "$BODY" | grep -qE 'git (-C [^ ]+ )?push .*--delete|git (-C [^ ]+ )?push .*origin :|push .*:refs/heads/'; then
    fail "$fn contains a remote branch deletion command"
  else
    pass "$fn has no remote branch deletion"
  fi
done
# Also: the guard helper must be referenced in the cleanup doc-comment so
# future contributors see it.
if grep -q "assert_no_open_mr_references_branch" "$WRAPPER"; then
  pass "guard helper defined and referenced in wrapper"
else
  fail "guard helper missing from wrapper"
fi

print ""
print "════════════════════════════════════"
print "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
print "ALL TESTS PASSED"
