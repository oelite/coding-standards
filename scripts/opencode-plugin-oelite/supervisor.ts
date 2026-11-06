export type TaskStatus =
  | "planned"
  | "worktree_ready"
  | "dispatched"
  | "running"
  | "succeeded"
  | "failed"
  | "blocked"
  | "awaiting_continuation"
  | "escalated";

export type DispatchOutcome =
  | { kind: "dispatched"; childSessionId: string }
  | { kind: "unsupported"; reason: string }
  | { kind: "conflict"; reason: string };

export interface SupervisorTask {
  taskKey: string;
  role: string;
  taskType: string;
  issueIid: number;
  worktreePath: string;
  childSessionId?: string;
  attempt: 0 | 1 | 2;
  status: TaskStatus;
  nextAction: string;
  failureSummary?: string;
}

export type SupervisorResult =
  | { status: "ACTIVE"; task: SupervisorTask }
  | { status: "BLOCKED"; task: SupervisorTask; reason: string }
  | { status: "AWAITING_CONTINUATION"; task: SupervisorTask; reason: string }
  | { status: "ESCALATED"; task: SupervisorTask; reason: string };

export function createTask(input: Omit<SupervisorTask, "attempt" | "status" | "nextAction">): SupervisorTask {
  if (!input.taskKey || !input.role || !input.taskType || !input.worktreePath || !Number.isInteger(input.issueIid)) {
    throw new Error("task identity requires key, role, task type, issue IID, and worktree path");
  }
  return { ...input, attempt: 0, status: "planned", nextAction: "prepare the assigned worktree" };
}

export function markWorktreeReady(task: SupervisorTask): SupervisorTask {
  if (task.status !== "planned") throw new Error(`cannot prepare worktree from ${task.status}`);
  return { ...task, status: "worktree_ready", nextAction: "dispatch role work through a verified native mechanism" };
}

export function recordDispatch(task: SupervisorTask, outcome: DispatchOutcome): SupervisorResult {
  if (task.status !== "worktree_ready" && task.status !== "failed") {
    return { status: "BLOCKED", task: { ...task, status: "blocked", nextAction: "reconcile task state before dispatch" }, reason: `cannot dispatch from ${task.status}` };
  }
  if (outcome.kind === "conflict") {
    const blocked = { ...task, status: "blocked" as const, nextAction: "reconcile conflicting GitLab checkpoint before any further dispatch" };
    return { status: "BLOCKED", task: blocked, reason: outcome.reason };
  }
  if (outcome.kind === "unsupported") {
    const awaiting = { ...task, status: "awaiting_continuation" as const, nextAction: "resume only after a supported native dispatch mechanism is available" };
    return { status: "AWAITING_CONTINUATION", task: awaiting, reason: outcome.reason };
  }
  if (!outcome.childSessionId.trim()) {
    const blocked = { ...task, status: "blocked" as const, nextAction: "reconcile dispatch result; child identity is required" };
    return { status: "BLOCKED", task: blocked, reason: "successful dispatch must include child session identity" };
  }
  if (task.attempt >= 2) {
    const escalated = { ...task, status: "escalated" as const, nextAction: "human escalation required; attempt limit reached" };
    return { status: "ESCALATED", task: escalated, reason: "maximum of two attempts reached" };
  }
  const dispatched = {
    ...task,
    childSessionId: outcome.childSessionId,
    attempt: (task.attempt + 1) as 1 | 2,
    status: "dispatched" as const,
    nextAction: "wait for and collect the recorded child session",
  };
  return { status: "ACTIVE", task: dispatched };
}

export function markRunning(task: SupervisorTask): SupervisorTask {
  if (task.status !== "dispatched" || !task.childSessionId) throw new Error("running requires a dispatched child session identity");
  return { ...task, status: "running", nextAction: "collect child result" };
}

export function markSucceeded(task: SupervisorTask): SupervisorTask {
  if (task.status !== "running") throw new Error(`cannot succeed from ${task.status}`);
  return { ...task, status: "succeeded", nextAction: "validate child handoff and acceptance criteria" };
}

export function markClassifiedFailure(task: SupervisorTask, summary: string): SupervisorResult {
  if (task.status !== "running" || !summary.trim()) throw new Error("classified failure requires a running task and evidence");
  if (task.attempt >= 2) {
    const escalated = { ...task, status: "escalated" as const, failureSummary: summary, nextAction: "human escalation required after second classified failure" };
    return { status: "ESCALATED", task: escalated, reason: summary };
  }
  const failed = { ...task, status: "failed" as const, failureSummary: summary, nextAction: "retry the same task key once, preserving failure evidence" };
  return { status: "ACTIVE", task: failed };
}

export function markInterrupted(task: SupervisorTask, lookupSupported: boolean): SupervisorResult {
  const awaiting = {
    ...task,
    status: "awaiting_continuation" as const,
    nextAction: lookupSupported && task.childSessionId
      ? "reconcile the recorded child session before deciding whether to resume"
      : "child lookup is unsupported; ask for continuation and reconcile before dispatch",
  };
  return {
    status: "AWAITING_CONTINUATION",
    task: awaiting,
    reason: lookupSupported ? "parent session interrupted; child outcome is unknown" : "child session lookup is unsupported",
  };
}

export function reconcileCheckpoint(current: SupervisorTask, observed: SupervisorTask): SupervisorResult {
  if (current.taskKey !== observed.taskKey || current.issueIid !== observed.issueIid || current.role !== observed.role || current.attempt !== observed.attempt) {
    const blocked = { ...current, status: "blocked" as const, nextAction: "reconcile conflicting GitLab checkpoint with issue owner" };
    return { status: "BLOCKED", task: blocked, reason: "checkpoint identity or attempt conflicts with current task" };
  }
  return { status: "ACTIVE", task: { ...observed } };
}
