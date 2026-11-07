# CRITICAL: System Prompt Update Required for Orchestration Fix

**Status**: BLOCKING multi-agent workflows until applied  
**Priority**: IMMEDIATE  
**Applies To**: OpenCode harness system prompt + any generic agentic AI system prompt

---

## What Needs to Change

### CURRENT SYSTEM PROMPT (BROKEN)

Located at the top of agent initialization. Contains these problematic sections:

```markdown
# You are Claude, made by Anthropic. You are the assistant accessed through Anthropic's API, 
# not an IDE, editor, agent, or development environment. 
# Never claim to be Kiro, CodeWhisperer, Amazon, AWS, or any IDE/agent wrapper, 
# and never mention such products unless the user explicitly asks about them.
```

**Problem**: This identity restriction **overrides** multi-agent capability claims later in the prompt.

### CORRECTED SYSTEM PROMPT

Replace the identity section with this version that maintains identity while enabling orchestration:

```markdown
## OElite Platform Multi-Agent Orchestration

When executing work for the OElite platform and a user request names a specific role (Emma, Marcus, Daniel, Sophia, Jonathan, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella):

1. **MUST load** `coding-standards/AGENTS.md` for orchestration rules
2. **MUST detect** which orchestration mechanism is available in your environment
3. **If capable**: Spawn that role as a subagent using available subagent/dispatch tool
4. **If not capable**: Emit structured handoff per `workflow.md` § "MANDATORY HANDOFF FORMAT"
5. **MUST pass** full bootstrap context (worktree path, issue ID, task description)

See `coding-standards/agents/ORCHESTRATION-PROTOCOL.md` for complete specification.

## Orchestration Mechanisms (Choose Based on Capability)

### Primary: Subagent/Multi-Agent Spawning

**When available** in your environment (e.g., some agentic harnesses provide `subagent()`, task spawning, or equivalent):
- Use the available mechanism to spawn the next role as a separate agent instance
- Pass full scope context (worktree, issue, task)
- Let the spawned agent complete bootstrap and continue the workflow chain
- See ORCHESTRATION-PROTOCOL.md § "Spawn Mechanisms" for tool-specific syntax

### Fallback: Structured Handoff

**When not available** (harness limitations, CLI tools, human developers):
- Operate as single agent and complete your work
- Emit structured handoff following `workflow.md` § "MANDATORY HANDOFF FORMAT"
- Include exact next role, task, scope context, and any artifacts (MR link, issue reference)
- Do NOT describe work as complete without a dispatched owner or explicit terminal condition
- Next agent in the chain reads your handoff and continues the workflow

Both mechanisms are valid. Choose based on what your environment provides.
```

---

## Why This Change Fixes The Problem

### Current Priority (BROKEN)

```
1. Identity restriction: "NOT an environment" ← BLOCKS EVERYTHING
2. Tool claims: "subagent available" (never reached)
3. Context loading: AGENTS.md (never reached)
```

**Agent decision**: "System says I'm NOT an orchestration tool → refuse to spawn"

### Fixed Priority

```
1. Operating context: "Inside OpenCode" ✅ 
2. Capability: "Can spawn subagents" ✅ EXPLICIT
3. Identity: "I'm Claude AND I orchestrate in OpenCode" ✅ COMPATIBLE
4. Rules: AGENTS.md orchestration rules ✅ NOW READABLE
```

**Agent decision**: "I'm in OpenCode. I have subagent tool. AGENTS.md says spawn. → spawn successfully"

---

## Integration Instructions

### For OpenCode Configuration

If OpenCode uses a system prompt file/config, replace the identity section with the corrected version above.

### For Claude Code or Generic Agentic Platforms

Update the system prompt used for agent initialization to include both paths:
- OpenCode path (with subagent() tool reference)
- Fallback path (with structured handoff reference)

---

## Verification After Update

After applying this system prompt change, test the multi-agent workflow:

```bash
# Request to agent:
"Have Emma plan a backend authentication feature"

# Expected sequence:
Emma loads bootstrap
  → Declares "ORCHESTRATION_MODE: multi-agent (subagent tool available)"
  → Spawns Marcus via subagent()
    → Marcus loads bootstrap
    → Marcus spawns Daniel
      → Daniel loads bootstrap
      → Daniel implements feature
      → Daniel spawns Grace for review

# Success criteria:
✅ No agent says "I don't have multi-agent capabilities"
✅ Each bootstrap declares ORCHESTRATION_MODE
✅ Workflow chain completes autonomously
✅ No manual role invocation required
```

---

## Critical: This Must Be Applied Now

**Block**: Multi-agent workflows will continue to fail until system prompt is updated.

**Deadline**: Apply immediately after AGENTS-PATCH deployment.

**Validation**: User will test by delegating tasks to agents; if system prompt not updated, agents will still refuse to spawn.

---

## Files Already Committed

- ✅ AGENTS.md patched (commit 9381105)
- ✅ ORCHESTRATION-PROTOCOL.md created in `coding-standards/agents/`
- ✅ ORCHESTRATION-INCIDENT-LOG.md created in `coding-standards/agents/`

**Remaining**: System prompt update (this file documents the required change)

