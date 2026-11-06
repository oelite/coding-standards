import assert from "node:assert/strict";
import test from "node:test";
import {
  createTask,
  markClassifiedFailure,
  markInterrupted,
  markRunning,
  markSucceeded,
  markWorktreeReady,
  reconcileCheckpoint,
  recordDispatch,
} from "./supervisor.js";

function task() {
  return createTask({ taskKey: "stable-task-1", role: "daniel", taskType: "backend-impl", issueIid: 125, worktreePath: "/repo/.worktrees/daniel-125" });
}

test("worktree setup is not dispatch and state transitions preserve child identity", () => {
  const prepared = markWorktreeReady(task());
  assert.equal(prepared.status, "worktree_ready");
  assert.equal(prepared.attempt, 0);
  const dispatch = recordDispatch(prepared, { kind: "dispatched", childSessionId: "child-42" });
  assert.equal(dispatch.status, "ACTIVE");
  assert.equal(dispatch.task.status, "dispatched");
  assert.equal(dispatch.task.attempt, 1);
  assert.equal(dispatch.task.childSessionId, "child-42");
  const running = markRunning(dispatch.task);
  assert.equal(markSucceeded(running).status, "succeeded");
});

test("unsupported native dispatch awaits continuation without consuming attempt", () => {
  const result = recordDispatch(markWorktreeReady(task()), { kind: "unsupported", reason: "No pinned OpenCode session API" });
  assert.equal(result.status, "AWAITING_CONTINUATION");
  assert.equal(result.task.status, "awaiting_continuation");
  assert.equal(result.task.attempt, 0);
});

test("checkpoint conflict blocks dispatch and requires reconciliation", () => {
  const original = task();
  const mismatch = { ...original, taskKey: "different" };
  const result = reconcileCheckpoint(original, mismatch);
  assert.equal(result.status, "BLOCKED");
  assert.match(result.reason, /conflicts/);
});

test("one classified failure permits exactly one retry, second failure escalates", () => {
  const first = recordDispatch(markWorktreeReady(task()), { kind: "dispatched", childSessionId: "child-1" });
  const failedOnce = markClassifiedFailure(markRunning(first.task), "build failed");
  assert.equal(failedOnce.status, "ACTIVE");
  const retry = recordDispatch(failedOnce.task, { kind: "dispatched", childSessionId: "child-2" });
  assert.equal(retry.task.attempt, 2);
  const failedTwice = markClassifiedFailure(markRunning(retry.task), "tests failed again");
  assert.equal(failedTwice.status, "ESCALATED");
  assert.equal(failedTwice.task.status, "escalated");
  const noThirdAttempt = recordDispatch(failedTwice.task, { kind: "dispatched", childSessionId: "child-3" });
  assert.equal(noThirdAttempt.status, "BLOCKED");
});

test("interruption preserves child identity and does not consume an attempt", () => {
  const dispatched = recordDispatch(markWorktreeReady(task()), { kind: "dispatched", childSessionId: "child-resume" });
  const resumed = markInterrupted(dispatched.task, true);
  assert.equal(resumed.status, "AWAITING_CONTINUATION");
  assert.equal(resumed.task.childSessionId, "child-resume");
  assert.equal(resumed.task.attempt, 1);
  assert.match(resumed.task.nextAction, /reconcile/);
});

test("empty child identity is never recorded as a successful dispatch", () => {
  const result = recordDispatch(markWorktreeReady(task()), { kind: "dispatched", childSessionId: " " });
  assert.equal(result.status, "BLOCKED");
  assert.equal(result.task.attempt, 0);
});
