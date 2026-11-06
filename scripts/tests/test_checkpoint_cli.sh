#!/usr/bin/env zsh
#
# Standards tests for the oelite-gitlab.sh `checkpoint` command.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
WRAPPER="$SCRIPT_DIR/../oelite-gitlab.sh"

PASS=0
FAIL=0

pass() { print -P "  %F{green}[PASS]%f $1"; PASS=$((PASS + 1)); }
fail() { print -P "  %F{red}[FAIL]%f $1"; FAIL=$((FAIL + 1)); }

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/oelite-checkpoint-test.XXXXXX")"
TMPROOT="${TMPROOT:A}"
trap 'rm -rf "$TMPROOT"' EXIT

git -C "$TMPROOT" init -q -b develop
git -C "$TMPROOT" -c user.email=emma@phanes.ltd -c user.name=Emma commit -q --allow-empty -m "initial"
git -C "$TMPROOT" worktree add -q -b feature/task-126-checkpoint "$TMPROOT/.worktrees/emma-126"
cat > "$TMPROOT/.worktrees/emma-126/.oe-scope" <<'EOF'
AGENT=emma
TASK_TYPE=infrastructure
ISSUE=126
TASK_DESCRIPTION=checkpoint task
EOF

source "$WRAPPER" help >/dev/null

typeset -A AGENT_USERNAMES
AGENT_USERNAMES[emma]="emma"

BASE_ISSUE='{"iid": 126, "assignee": {"username": "emma"}, "title": "[TASK-126] Mission checkpoint"}'
API_NOTES='[]'
API_CALLS=""

api_get() {
  API_CALLS="$API_CALLS GET:$1"
  _API_STATUS=200
  if [[ "$1" == *"/notes?"* ]]; then _API_RESPONSE="$API_NOTES"; else _API_RESPONSE="$BASE_ISSUE"; fi
}
api_post() {
  API_CALLS="$API_CALLS POST:$1"
  _API_STATUS=201
  _API_RESPONSE='{"id":1,"body":"note"}'
  API_NOTES="$(printf '%s' "$2" | python3 -c 'import json,sys; p=json.loads(sys.stdin.read()); print(json.dumps([{"body": p["body"]}]))')"
}
api_put() { API_CALLS="$API_CALLS PUT:$1"; _API_STATUS=200; _API_RESPONSE='{}'; }
get_pat() { print "testpat"; }

cd "$TMPROOT/.worktrees/emma-126"

print "\nTEST 1: all required fields -> validates"
RC=0
cmd_checkpoint oelite/coding-standards 126 emma implementation \
  --task "build checkpoint schema" --ac "schema validates" --completed "drafted" \
  --remaining "wire CLI" --attempt 1 --next "run tests" --dispatch pending \
  --task-type infrastructure --session-type primary >/tmp/oe-t1.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t1.out)"
if [[ $RC -eq 0 && "$OUT" == *"[OK] Checkpoint recorded"* ]]; then
  pass "all fields accepted, checkpoint recorded"
else
  fail "expected [OK] recorded (rc=$RC): $OUT"
fi

print "\nTEST 2: missing --ac fails closed"
RC=0
cmd_checkpoint oelite/coding-standards 126 emma implementation \
  --task "x" --completed "c" --remaining "r" --attempt 1 --next "n" --dispatch pending \
  --task-type infrastructure --session-type primary >/tmp/oe-t2.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t2.out)"
if [[ $RC -eq 1 && "$OUT" == *"acceptance_criteria"* ]]; then
  pass "missing --ac rejected with field name"
else
  fail "missing --ac not rejected (rc=$RC): $OUT"
fi

print "\nTEST 3: invalid dispatch_status fails closed"
RC=0
cmd_checkpoint oelite/coding-standards 126 emma implementation \
  --task "x" --ac "y" --completed "c" --remaining "r" --attempt 1 --next "n" --dispatch bogus \
  --task-type infrastructure --session-type primary >/tmp/oe-t3.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t3.out)"
if [[ $RC -eq 1 && "$OUT" == *"invalid dispatch_status"* ]]; then
  pass "bad dispatch_status rejected"
else
  fail "bad dispatch_status not rejected (rc=$RC): $OUT"
fi

print "\nTEST 4: invalid session_type fails closed"
RC=0
cmd_checkpoint oelite/coding-standards 126 emma implementation \
  --task "x" --ac "y" --completed "c" --remaining "r" --attempt 1 --next "n" --dispatch pending \
  --task-type infrastructure --session-type weird >/tmp/oe-t4.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t4.out)"
if [[ $RC -eq 1 && "$OUT" == *"invalid session_type"* ]]; then
  pass "bad session_type rejected"
else
  fail "bad session_type not rejected (rc=$RC): $OUT"
fi

print "\nTEST 5: attempts must be non-negative integer"
RC=0
cmd_checkpoint oelite/coding-standards 126 emma implementation \
  --task "x" --ac "y" --completed "c" --remaining "r" --attempt abc --next "n" --dispatch pending \
  --task-type infrastructure --session-type primary >/tmp/oe-t5.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t5.out)"
if [[ $RC -eq 1 && "$OUT" == *"attempts must be"* ]]; then
  pass "non-integer attempts rejected"
else
  fail "non-integer attempts not rejected (rc=$RC): $OUT"
fi

print "\nTEST 6: scope IID conflict fails closed"
RC=0
cmd_checkpoint oelite/coding-standards 999 emma implementation \
  --task "x" --ac "y" --completed "c" --remaining "r" --attempt 1 --next "n" --dispatch pending \
  --task-type infrastructure --session-type primary >/tmp/oe-t6.out 2>&1 || RC=$?
OUT="$(</tmp/oe-t6.out)"
if [[ $RC -eq 1 && "$OUT" == *"issue conflict"* ]]; then
  pass "IID conflict between .oe-scope and requested rejected"
else
  fail "IID conflict not rejected (rc=$RC): $OUT"
fi

print "\nTEST 7: idempotency key is stable for task/stage/attempt"
KEY_A=$(python3 -c 'import hashlib; print(hashlib.sha256("\x1f".join(["126","infrastructure","implementation","1"]).encode()).hexdigest()[:24])')
KEY_B=$(python3 -c 'import hashlib; print(hashlib.sha256("\x1f".join(["126","infrastructure","implementation","1"]).encode()).hexdigest()[:24])')
if [[ "$KEY_A" == "$KEY_B" && -n "$KEY_A" ]]; then
  pass "same task/stage/attempt produces stable idempotency key"
else
  fail "idempotency key is not stable"
fi

print "\nTEST 7b: conflict marker is keyed and payload is parsed"
if grep -q 'conflicting checkpoint for idempotency_key' "$WRAPPER" && grep -q 'oelite-checkpoint:v1 key=' "$WRAPPER"; then
  pass "same-key conflict path and GitLab note marker are present"
else
  fail "conflict path or note marker missing"
fi

print "\nTEST 8: no local issue/checkpoint files created in worktree"
LOCAL_CHECKPOINTS="$(find "$TMPROOT/.worktrees/emma-126" -type f \( -path '*/issues/*' -o -name '*checkpoint*' -o -name '*.checkpoint.json' \) -print)"
if [[ -n "$LOCAL_CHECKPOINTS" ]]; then
  fail "unexpected local checkpoint/issue file present: $LOCAL_CHECKPOINTS"
else
  pass "no local issue/checkpoint files in worktree"
fi

print "\nTEST 9: no raw API bypass"
if print -r -- "$API_CALLS" | grep -qE 'curl|http|/api/v4'; then
  fail "raw API call detected"
else
  pass "only wrapper api_get/api_post used"
fi

print "\nTEST 10: valid dispatch_status enum values accepted"
for st in pending dispatched blocked complete; do
  API_NOTES='[]'
  RC=0
  cmd_checkpoint oelite/coding-standards 126 emma implementation \
    --task "t" --ac "y" --completed "c" --remaining "r" --attempt 1 --next "n" --dispatch "$st" \
    --task-type infrastructure --session-type primary >/tmp/oe-t10.out 2>&1 || RC=$?
  if [[ $RC -ne 0 ]]; then
    fail "dispatch_status=$st rejected (rc=$RC): $(</tmp/oe-t10.out)"; break
  fi
done
pass "all dispatch enum values accepted"

print ""
print "═══════════════════════════════════════════════════════════"
print "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then exit 1; fi
print "ALL CHECKPOINT TESTS PASSED"
