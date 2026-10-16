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
print "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
print "ALL TESTS PASSED"
