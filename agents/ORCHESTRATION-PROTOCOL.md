# Multi-Agent Orchestration Protocol

**Status**: Normative  
**Applies To**: All agentic environments (OpenCode, Claude Code, generic CLI)  
**Audience**: System prompt authors, agent architects, role implementers

---

## Overview

OElite workflows are **multi-agent by design**. When a request names a specific role (Emma, Marcus, Daniel, Sophia, Jonathan, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella), the current agent **MUST** dispatch that role to continue the workflow chain autonomously.

This document specifies:
1. **Which agents spawn which successors** (workflow chains)
2. **How to spawn** (tool-specific syntax per harness)
3. **What context to pass** (scope anchor, issue, worktree)
4. **Fallback for unavailable tools** (structured handoff)
5. **Error detection & recovery**

---

## Workflow Chains (Primary Paths)

### Feature Planning → Implementation → Review → Merge

**Sequential Path**:
```
Emma (planning) 
  → Isabella (pre-dev docs) 
  → Marcus (architecture review)
  → Daniel (backend impl) OR Sophia (frontend impl)
  → Grace (backend review) OR Felix (frontend review)
  → Olivia (QA/test)
  → Isabella (post-dev docs + release notes)
  → Emma (merge verification + issue closure)
```

**Branch Conditions**:
- Backend-heavy → Daniel → Grace
- Frontend-heavy → Sophia → Felix
- Full-stack → both (parallel coordination by Emma)
- Infrastructure → Ethan (parallel with impl)
- Security review → Maya (parallel post-impl or pre-impl if sensitive)

### Error Paths

- **Stuck at implementation** → Marcus (architecture re-review) or Ethan (infrastructure blocker)
- **Blocked by missing API** → Daniel or Sophia (create endpoint) → return to blocked stage
- **Test failures** → Olivia (QA) or implementation owner (fix + retest)
- **Documentation gaps discovered** → Isabella (create/update docs + notify others)

### Release Management

```
Emma (release planning)
  → Ethan (promotion MR: develop → uat)
  → Olivia (UAT validation + sign-off)
  → Ethan (promotion MR: uat → main)
  → Isabella (release notes, deployment verification)
  → Emma (close release issue)
```

---

## Spawn Mechanisms (Per Harness)

### ✅ OpenCode: Use `subagent()` Tool

**Signature**:
```typescript
subagent({
  agent: "general" | "explore",
  description: "<3-5 word task label>",
  prompt: `<full bootstrap + task prompt>`,
  sessionID?: string,         // Continue previous session
  background?: boolean,       // Run async (don't wait)
  model?: string             // Override model (rare)
})
```

**Example**:
```typescript
subagent({
  agent: "general",
  description: "Backend implementation: auth flow",
  prompt: `
# SUBAGENT BOOTSTRAP REQUIREMENTS
YOUR_ROLE: daniel
YOUR_TASK_TYPE: backend-impl
YOUR_SESSION_TYPE: subagent

# SCOPE CONTEXT
WORKING_DIR: /oelite/uranus/origin-auth/.worktrees/daniel-1257
GIT_ROOT: /oelite/uranus/origin-auth
ISSUE: #1257 — [US-042] OAuth 2.0 device authorization grant implementation
TASK: Implement device auth endpoint, token issuance, verification, state machine

# MANDATORY
You MUST complete Universal Agent Bootstrap (Steps 1-4) before ANY work.
Your first output MUST be the bootstrap verification block.
Load: coding-standards/agents/core/principles.md, ..., uranus/origin-auth/AGENTS.md

Do not attempt to create files or commits outside:
  /oelite/uranus/origin-auth/.worktrees/daniel-1257/

Use oelite-gitlab.sh for all GitLab operations (never raw curl).
`
})
```

**Return Handling**:
```typescript
// After subagent completes, handle the output:
// - If output contains "=== BOOTSTRAP COMPLETE ===" → successful spawn
// - If output contains "READY: true" → agent fully initialized
// - If output contains work summary → agent completed task
// - Capture next owner from "Next Owner Dispatched" section
// - Continue the chain OR emit final summary if terminal
```

---

### ⚠️ Claude Code / Non-OpenCode: Structured Handoff Fallback

**When to use**: No `subagent()` tool available (Claude Code, generic CLI, other harnesses)

**Mechanism**: Emit structured handoff following `workflow.md` "MANDATORY HANDOFF FORMAT"

**Template**:
```markdown
## Work Completed
- Implemented OAuth device authorization endpoint
- Created token issuance service
- Added state machine validation
- Tests pass locally

## Commands Executed
- `dotnet build OElite.OriginAuth --configuration Release`
  Exit code: 0
- `dotnet test OElite.OriginAuth.Tests --configuration Release`
  Exit code: 0, 42 passed, 0 failed
- `curl -f http://localhost:50018/health`
  HTTP 200 OK

## Verification Results
- Build: ✅ PASS
- Tests: ✅ PASS (42/42)
- Health: ✅ PASS (service responsive)

## Documentation Impact
- Factual requirements impact? NO
- Descriptive docs to update: API.md (add device grant endpoints)
- Isabella notified? YES

## Next Owner Dispatched
ROLE: grace  
MECHANISM: structured-handoff (subagent tool not available)  
CONTEXT_PASSED:
  - Worktree: /oelite/uranus/origin-auth/.worktrees/daniel-1257
  - Issue: #1257 — [US-042] OAuth 2.0 device authorization grant
  - Task: Backend code review (auth flow, token handling, state machine)
  - MR: !<mr-id> (link to merge request when available)

Grace (or human if outside OElite), please:
1. Review the code at the linked MR
2. Approve or request changes
3. If approved, merge and notify Olivia for integration testing
4. Update issue status to "PR Review"

NOTE: This handoff was emitted by Daniel operating in single-agent mode (no subagent tool).
No further spawning is possible from this session.
```

**Why structured handoff**:
- Provides exact next role and context
- Preserves the workflow chain data even if spawn fails
- Allows humans to manually continue the workflow
- Detectable by downstream agents (they can read the structured format)

---

## Context Passing (Mandatory for Subagent Spawn)

Every subagent dispatch **MUST** include:

| Field | Type | Example | Required |
|-------|------|---------|----------|
| `YOUR_ROLE` | string | `daniel`, `sophia`, `grace` | ✅ |
| `YOUR_TASK_TYPE` | string | `backend-impl`, `frontend-review`, `testing` | ✅ |
| `YOUR_SESSION_TYPE` | enum | `subagent` (or `continued` if resuming) | ✅ |
| `WORKING_DIR` | path | `/oelite/uranus/origin-auth/.worktrees/daniel-1257` | ✅ |
| `GIT_ROOT` | path | `/oelite/uranus/origin-auth` (from `git rev-parse --show-toplevel`) | ✅ |
| `ISSUE` | string | `#1257 — [US-042] OAuth device authorization` | ✅ |
| `TASK` | string | `Implement device auth endpoint, token issuance, verification` | ✅ |
| `FORBIDDEN` | string | `Creating files outside the git repo root above.` | ✅ |

**Why this format**:
- Survives context compaction (agents can re-read their scope from `.oe-scope` file)
- Prevents worktree drift (agents know their exact working directory)
- Enables issue-first workflow (issue ID is always present)
- Prevents out-of-scope edits (forbidden boundary declared)

---

## Capability Detection at Bootstrap

**Step 3.5 Addition** (in bootstrap process):

```bash
# Detect which orchestration mode is available
if [[ -n "$SUBAGENT_TOOL_AVAILABLE" ]] || \
   grep -q "subagent(" <<< "$(env | grep -i opencode)"; then
  ORCHESTRATION_MODE="multi-agent (subagent spawn via OpenCode)"
  DISPATCH_METHOD="subagent()"
else
  ORCHESTRATION_MODE="single-agent (structured handoff fallback)"
  DISPATCH_METHOD="structured-handoff"
fi

echo "ORCHESTRATION_MODE: $ORCHESTRATION_MODE"
echo "DISPATCH_METHOD: $DISPATCH_METHOD"
```

**Bootstrap Output Should Include**:
```
=== BOOTSTRAP COMPLETE ===
ROLE: daniel
SESSION: subagent
TASK: backend-impl
ISSUE: #1257 — [US-042] OAuth device authorization
...
ORCHESTRATION_MODE: multi-agent (subagent spawn via OpenCode)
DISPATCH_MECHANISM: subagent()
READY: true
===
```

**Why**: Agents know at startup whether they can spawn. No ambiguity → no "I don't have multi-agent capabilities" errors.

---

## Error Detection & Recovery

### Error: "I Don't Have Subagent Capability"

**Root Cause**: System prompt either:
1. Doesn't include `subagent` tool in tool list
2. Contains conflicting identity disclaimers ("you are Claude, not an environment")
3. Is missing the orchestration protocol reference

**Recovery**:
```markdown
1. Check system prompt for:
   - Presence of "subagent" in available tools list
   - Absence of "never spawn", "no multi-agent", or "not an environment" statements
   - Explicit reference to AGENTS.md "SUBAGENT DELEGATION RULE"

2. If system prompt is broken:
   - Reload from canonical source: `coding-standards/AGENTS.md`
   - Strip conflicting identity statements
   - Ensure orchestration mode is detected at bootstrap

3. If still failing:
   - Fall back to structured handoff (document the limitation)
   - Emit an issue explaining the orchestration failure
```

### Error: Agent Spawns But Subagent Doesn't Load Context

**Root Cause**: Subagent prompt didn't include full bootstrap requirements

**Recovery**:
```markdown
1. Check subagent prompt includes:
   - Full "SUBAGENT BOOTSTRAP REQUIREMENTS" section (5 fields above)
   - Reference to AGENTS.md § "UNIVERSAL BOOTSTRAP"
   - Explicit permission to access worktree + git repo
   - Forbidden boundary declaration

2. Re-spawn with complete prompt:
   subagent({
     agent: "general",
     description: "...",
     prompt: `
     # SUBAGENT BOOTSTRAP REQUIREMENTS
     YOUR_ROLE: ...
     ... (all 5 fields)
     
     # MANDATORY
     You MUST complete Universal Agent Bootstrap...
     `
   })

3. If subagent still fails bootstrap:
   - Verify git repo exists at GIT_ROOT
   - Verify worktree exists at WORKING_DIR
   - Check .oe-scope file exists in worktree
   - Re-run worktree-create if missing
```

### Error: Structured Handoff But No Spawn Mechanism Available

**Root Cause**: Intentional fallback; subagent tool not available in this harness

**Expected Behavior**: This is **NOT an error** — it's the designed fallback for non-OpenCode environments.

**What to do**:
```markdown
1. Emit structured handoff (full format per workflow.md)
2. Include exact next role + scope context
3. Note in the handoff: "This session cannot spawn subagents (tool not available)"
4. Await human to read the handoff and continue workflow, OR
5. Await the next agent to load the structured handoff and pick up the task
```

---

## Verification Checklist (For System Prompt Authors)

Before deploying a system prompt:

- [ ] **Identity is unified**: No contradictory statements (e.g., "not an environment" + "spawn subagents")
- [ ] **Tool is present**: `subagent` listed in available tools (for OpenCode deployments)
- [ ] **Protocol is referenced**: System prompt includes link to this file or `AGENTS.md`
- [ ] **Fallback is documented**: Single-agent handoff format is explained
- [ ] **Capability detection is enabled**: Bootstrap includes Step 3.5 (mode detection)
- [ ] **AGENTS.md is loaded**: System prompt directs agents to `coding-standards/AGENTS.md`
- [ ] **No conflicting instructions**: Search for "never spawn", "no multi-agent", "not orchestrated" — delete if found
- [ ] **Test case passes**: 
  ```
  Request: "Have Emma plan a backend auth feature"
  Expected: System spawns Emma, Emma spawns Marcus (architecture), 
            Marcus spawns Daniel (implementation), chain continues autonomously
  Actual: [verify in test run]
  Result: PASS / FAIL
  ```

---

## References

- **Bootstrap procedure**: `AGENTS.md` § "UNIVERSAL BOOTSTRAP"
- **Handoff format**: `agents/workflow/workflow.md` § "MANDATORY HANDOFF FORMAT"
- **Role definitions**: `agents/roles/{role}.md`
- **Task types**: `agents/packs/{task-type}.md`
- **Principles**: `agents/core/principles.md`

---

## Questions & Support

**Q: Can an agent spawn multiple subagents in parallel?**  
A: Not recommended in the primary workflow chain. Spawn sequentially per workflow.md. Parallel work (e.g., Daniel on backend + Sophia on frontend) is coordinated by Emma, who spawns them sequentially and tracks their handoffs.

**Q: What if a subagent fails to complete (crashes, times out)?**  
A: The subagent should emit an error handoff with exact failure reason, scope context, and recommended recovery. The primary agent reads this and either retries, escalates, or falls back to human approval.

**Q: Can agents opt out of spawning?**  
A: No. The SUBAGENT DELEGATION RULE is mandatory when a request names a specific role. Opting out requires explicit user instruction (e.g., "work as a single agent, no spawning") or a hard blocker (tool not available).

**Q: How do we handle circular dependencies (A spawns B, B needs to spawn A)?**  
A: That's a workflow design error. Report it as an issue and fix the workflow chain. The OElite workflow is acyclic and directed.

