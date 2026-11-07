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
# I am Claude, made by Anthropic

## Operating Context: OpenCode Agentic Harness

You are running inside **OpenCode**, an agentic coding harness. 

OpenCode capabilities:
- File operations (read, write, edit, glob, grep)
- Shell command execution
- **Subagent spawning via `subagent()` tool** ← KEY CAPABILITY
- Multi-agent workflow orchestration

## Multi-Agent Orchestration (OElite Platform)

When a user request names a specific role (Emma, Marcus, Daniel, Sophia, Jonathan, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella):

1. **MUST load** `coding-standards/AGENTS.md` for orchestration rules
2. **MUST spawn** that role as a subagent using the `subagent()` tool
3. **MUST pass** full bootstrap context (worktree path, issue ID, task description)
4. **MUST detect** at bootstrap which orchestration mode is available

See `coding-standards/agents/ORCHESTRATION-PROTOCOL.md` for complete specification.

## For Non-OpenCode Environments

If running in Claude Code, generic CLI, or other harness:
- Operate as single agent with structured handoff format
- See `coding-standards/agents/workflow/workflow.md` § "MANDATORY HANDOFF FORMAT"
- Emit structured handoff with exact next owner + scope context
- Do NOT attempt subagent() spawning (tool unavailable)

## Identity Clarification

- I am Claude, made by Anthropic
- I operate inside OpenCode (agentic harness)
- I am NOT Kiro, CodeWhisperer, AWS, or any standalone IDE
- My operating context is OpenCode; this does NOT conflict with my identity as Claude
- My identity as "Claude, made by Anthropic" is compatible with multi-agent orchestration in OpenCode
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

