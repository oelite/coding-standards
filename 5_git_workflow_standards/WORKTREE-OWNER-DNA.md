# Worktree-Owner DNA — Commit Attribution Protocol

> **Created**: 2026-06-20  
> **Last Updated**: 2026-06-20  
> **Maintained by**: Engineering Team  
> **Status**: Active  
> **Version**: 1.0.0

---

## Overview

This document defines the **worktree-owner DNA** protocol — the rules governing how commit authorship is attributed when AI agents implement work in isolated worktrees. The protocol ensures that every commit carries the correct team member's GitLab identity, preserving ownership attribution through the entire Git lifecycle (worktree → commits → local merge → remote push).

---

## Core Principle

> **Commits in a worktree are authored by the team member whose identity is configured in that worktree — NOT by the AI executor.**

When Daniel is assigned an issue, all commits in Daniel's worktree use `Daniel <daniel@phanes.ltd>` as the author, regardless of which AI agent (Sisyphus, Oracle, etc.) actually wrote the code.

---

## Identity Resolution

### Rule 1: Agent Parameter IS Owner DNA

When creating a worktree, the agent parameter passed to `worktree-create` determines the GitLab identity used for ALL commits:

```bash
# Commits will show: Marcus <marcus@phanes.ltd>
scripts/oelite-gitlab.sh worktree-create marcus feature/US-042-arch
```

### Rule 2: Explicit Owner Override

The `--owner` flag allows specifying a different identity than the executor:

```bash
# Executor: Sophia's worktree, but commits show as Emma's
scripts/oelite-gitlab.sh worktree-create sophia feature/review --owner emma
```

This is used when one team member delegates work to another.

### Rule 3: Identity Mapping

All identities are resolved from the single source of truth in `coding-standards/scripts/oelite-gitlab.sh` (lines 14–17): the `AGENT_USERNAMES`, `AGENT_EMAILS`, and `AGENT_DISPLAY_NAMES` arrays. This file is the authoritative registry — never modify identities in markdown.

---

## Workflow

### 1. Worktree Creation

```bash
# Standard case: agent = owner
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth

# Result in worktree:
#   git config user.name = "Daniel"
#   git config user.email = "daniel@phanes.ltd"
#   .git-worktree-owner = "daniel"
```

### 2. Implementation

All commits made in the worktree use the configured owner identity:

```
Author: Daniel <daniel@phanes.ltd>
Date:   2026-06-20 14:30:00 +0800

    feat: implement JWT refresh token rotation

    - Added refresh token service
    - Updated token endpoint
    - Closes #42
```

### 3. Local Merge

When the worktree is merged into local `develop`, the commits retain their original author attribution:

```bash
git checkout develop
git merge daniel/feature/US-001-auth --no-edit
# Commits show Author: Daniel <daniel@phanes.ltd>
```

### 4. Remote Push

When a human developer pushes to `origin/develop`, GitLab displays the original author attribution — Daniel gets credit in GitLab's commit history.

---

## Owner Management

### View Current Owner

```bash
scripts/oelite-gitlab.sh worktree-owner daniel
```

Output:
```
Worktree Owner DNA for daniel:
  Path:   /path/to/repo/.worktrees/daniel
  Owner:  Daniel <daniel@phanes.ltd>
  Config: user.name=Daniel, user.email=daniel@phanes.ltd
```

### Change Owner Mid-Session

```bash
# Reassign ownership to Emma
scripts/oelite-gitlab.sh worktree-owner daniel emma
```

This updates:
- `user.name` → "Emma"
- `user.email` → "emma@phanes.ltd"
- `.git-worktree-owner` → "emma"

All subsequent commits will be authored as Emma.

### Status Display with Owner

```bash
scripts/oelite-gitlab.sh status
```

Output includes an OWNER column:
```
AGENT       OWNER      BRANCH                               AHEAD    BEHIND   LAST COMMIT  STATUS
daniel      daniel     feature/US-001-auth                  3        0        2026-06-20   active
sophia      emma       feature/review                       1        0        2026-06-20   active
```

---

## Verification

### Check Git Config in Worktree

```bash
git -C .worktrees/daniel config --local --list | grep user
# user.name=Daniel
# user.email=daniel@phanes.ltd
```

### Check Commit Authorship

```bash
git -C .worktrees/daniel log --oneline -5 --format="%h | %an <%ae>"
# b4c52031 | Daniel <daniel@phanes.ltd>
# dcaefb74 | Daniel <daniel@phanes.ltd>
```

### Verify Owner Metadata File

```bash
cat .worktrees/daniel/.git-worktree-owner
# daniel
```

---

## Requirements

1. **Every worktree MUST be created with the correct team member name.** Never use an AI executor name (e.g., "sisyphus").
2. **All commits MUST be authored by the team member** whose worktree the work is in.
3. **The AI executor's identity MUST NOT appear** in author/committer fields.
4. **Commit messages MUST follow the required format**: Title + bulleted body, no AI/co-authorship references.

---

## Error Handling

### Unknown Agent

```bash
scripts/oelite-gitlab.sh worktree-create unknown feature/xxx
# [ERROR] Unknown agent: unknown
# Valid agents: emma,marcus,daniel,sophia,jonathan,olivia,ethan,maya,victor,grace,felix,isabella
```

### Unknown Owner

```bash
scripts/oelite-gitlab.sh worktree-create daniel feature/xxx --owner unknown
# [ERROR] Unknown owner: unknown
# Valid owners: emma,marcus,daniel,sophia,jonathan,olivia,ethan,maya,victor,grace,felix,isabella
```

### Worktree Already Exists

```bash
scripts/oelite-gitlab.sh worktree-create daniel feature/xxx
# [ERROR] Worktree already exists for daniel at /path/.worktrees/daniel
```

---

## Related Documents

- [AGENTS.md Part III §1.7](../../AGENTS.md) — Worktree-Owner DNA in the main guide
- [GIT-WORKFLOW-STANDARDS.md](./GIT-WORKFLOW-STANDARDS.md) — Full Git workflow protocol
- [oelite-gitlab.sh](../oelite-gitlab.sh) — CLI tool reference

---

## Change History

| Date | Author | Version | Changes |
|------|--------|---------|---------|
| 2026-06-20 | Engineering Team | 1.0.0 | Initial document |
