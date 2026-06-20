# Git Workflow & Collaboration Standards

## Overview

This document defines the git workflow, worktree protocol, human+AI collaboration rules, and GitLab integration for the OElite platform. These standards apply to **ALL repositories** in the OElite monorepo without exception.

The OElite team consists of 12 members (10 AI agents + human developers) who work in parallel on the same codebase. Parallel development requires strict isolation, clear ownership boundaries, and consistent merge practices to prevent conflicts and maintain code quality.

### Key Principles

- **`develop` is the Local Integration Basin.** The main working directory checks out `develop`. Agents branch **from** and merge **back into** local `develop` for accumulation. Remote `develop` is only touched by human developers.
- **Worktree isolation.** AI agents work in isolated git worktrees, never in the main working directory.
- **Local Merge Model.** Agents complete tasks by merging their feature branch directly into local `develop`. This eliminates remote race conditions and network latency during agentic workflows.
- **Human Publisher.** Human developers review the state of local `develop`, approve work, and push to remote `origin/develop` when ready. This keeps CI/CD triggers under human control.
- **Parallel by design.** Directory-level ownership and worktree isolation let multiple agents work simultaneously without stepping on each other.

---

## 1. Team Identity Registry

Every team member has a unique GitLab identity. AI agents commit under their own name and email. All GitLab operations (comments, MRs, approvals) use the agent's personal access token (PAT).

| Agent | Role | GitLab Username | Email | GitLab User ID |
|-------|------|-----------------|-------|----------------|
| Emma | Product & Delivery Coordinator | emma.phanes | emma@phanes.ltd | 7 |
| Marcus | Principal Software Architect | marcus.phanes | marcus@phanes.ltd | 8 |
| Daniel | Senior Backend Engineer | daniel.phanes | daniel@phanes.ltd | 6 |
| Sophia | Senior Frontend Engineer | sophia.phanes | sophia@phanes.ltd | 9 |
| Jonathan | Lead UX Designer | jonathan.phanes | jonathan@phanes.ltd | 10 |
| Olivia | QA & Test Automation Lead | olivia.phanes | olivia@phanes.ltd | 11 |
| Ethan | DevOps & Reliability Engineer | ethan.phanes | ethan@phanes.ltd | 12 |
| Maya | Security Engineer | maya.phanes | maya@phanes.ltd | 13 |
| Victor | Data & Performance Engineer | victor.phanes | victor@phanes.ltd | 14 |
| Grace | Lead Backend Code Reviewer | grace.phanes | grace@phanes.ltd | 15 |
| Felix | Lead Frontend Code Reviewer | felix.phanes | felix@phanes.ltd | 16 |
| Isabella | Business Analyst & Documentation Lead | isabella.phanes | isabella@phanes.ltd | 17 |

### Identity Rules

- Each agent uses **their own PAT** for all GitLab API operations. No sharing.
- Git `user.name` and `user.email` in worktrees are set to the agent's identity from the table above.
- Human developers use their own GitLab identity. The same workflow rules apply.
- Commits from agents appear under the agent's GitLab username (e.g., `daniel.phanes`, `sophia.phanes`).

---

## 2. Git Flow: Branch Strategy

### 2.1 Permanent Branches

| Branch | Purpose | Who Commits |
|--------|---------|-------------|
| `develop` | Integration branch. All MRs target this. | Only via merged MRs. Never direct commits. |
| `main` | Production-ready releases. | Only via release MRs from `develop`. |

### 2.2 Feature Branches

Feature branches are where all development happens. Naming convention:

```
feature/<issue-ref>-<short-description>
```

**Examples:**

```
feature/US-001-auth-token-refresh
feature/OE-142-product-catalog-api
feature/BUG-089-fix-cascade-update-loop
feature/US-015-checkout-payment-flow
```

**Rules:**

- Lowercase letters, hyphens, no spaces.
- Always prefixed with `feature/`.
- Include the issue reference (US-XXX, OE-XXX, BUG-XXX) for traceability.
- Short description: 2-5 words, hyphen-separated.

### 2.3 Review Branches

Review branches are created for reviewers who need to run tests or inspect code in a worktree:

```
review/<agent-name>-<feature-branch-name>
```

**Example:**

```
review/grace-US-001-auth-token-refresh
review/felix-US-015-checkout-payment-flow
```

### 2.4 Branch Lifecycle (Local Merge Model)

```
1. Create feature branch from latest local develop
2. Work in worktree (agent) or local checkout (human)
3. Commit with conventional messages
4. Sync main develop with remote
5. Rebase agent's branch onto main develop
6. Merge agent's branch into main develop (Local Merge)
7. (Optional) Human reviews local develop and pushes to remote
```

---

## 3. Worktree Protocol

Git worktrees allow multiple agents to work on the same repo simultaneously, each in their own isolated directory with their own branch.

### 3.1 Worktree Location

All worktrees live inside the repo under `.worktrees/`:

```
<repo>/.worktrees/<agent-name>/
```

**Example:**

```
helios/core/.worktrees/daniel/
jupiter/ec-nx-01/.worktrees/sophia/
uranus/origin-auth/.worktrees/maya/
```

### 3.2 One Worktree Per Agent

Each agent gets **ONE worktree at a time** per repo. If an agent needs to work on a second task in the same repo, they must finish or remove their current worktree first.

### 3.3 Per-Worktree Git Config

When a worktree is created, git config is set for that worktree only:

```bash
git config user.name "daniel.phanes"
git config user.email "daniel@phanes.ltd"
```

This ensures commits are attributed to the correct agent regardless of the host machine's global git config.

### 3.4 Worktree Lifecycle (Local Merge Model)

```
1. CREATE    scripts/oelite-gitlab.sh worktree-create <agent> <branch>
2. WORK      cd .worktrees/<agent>/ && make changes && commit
3. SYNC      git checkout develop && git pull origin develop (Main dir)
            cd .worktrees/<agent>/ && git rebase develop (Agent dir)
4. MERGE     git checkout develop && git merge <agent>/<branch> (Main dir)
5. CLEANUP   scripts/oelite-gitlab.sh worktree-remove <agent>
```

### 3.5 Stale Worktree Policy

Worktrees with no commits in more than 24 hours are flagged for cleanup. Emma coordinates with the assigned agent to either:

- Resume work and make a commit, or
- Remove the worktree and reassign the task.

**Identifying stale worktrees:**

```bash
scripts/oelite-gitlab.sh worktree-list
```

Review the output for worktrees with no recent activity. If a worktree is stale, remove it:

```bash
scripts/oelite-gitlab.sh worktree-remove <agent>
```

---

## 4. Parallel Development Rules

### 4.1 Directory-Level Ownership

Emma assigns directory scopes per task to prevent conflicts. Each agent works only within their assigned scope.

**Example assignment:**

```
Daniel: helios/core/OElite.Common.Platform/Biz/Products/
        helios/core/OElite.Services/Products/
        helios/core/OElite.Data.Platform/Products/
Sophia: jupiter/ec-nx-01/src/app/products/
        jupiter/ec-nx-01/src/components/products/
```

### 4.2 Shared Files (Gated)

Some files are shared across the codebase and can only be modified by **one agent at a time**. Emma serializes access to these files.

**Gated files include:**

- `Program.cs` / `Startup.cs`
- `docker-compose*.yml`
- `Dockerfile`
- `.gitlab-ci.yml`
- `global.json`
- `NuGet.config`
- Shared interfaces (e.g., `IOEliteService.cs`, `BaseEntity.cs`)
- `AGENTS.md` / `CLAUDE.md` / `README.md`
- `.ai/standards/` files
- `.editorconfig`
- Solution files (`.sln`)

**Rule:** If you need to modify a gated file, check with Emma first. She will coordinate who goes first and ensure no conflicts.

### 4.3 Working with the Main `develop` Branch

AI agents **NEVER** work directly on `develop` in the main directory. All agent work happens in worktrees on feature branches. However, agents **DO** merge their completed work back into the main `develop` branch using the **Late Sync** model:

```bash
# WRONG - agent working directly on develop in main dir
cd /path/to/repo
git checkout develop
# make changes...

# CORRECT - agent works in worktree, then merges into main develop
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth-token-refresh
cd .worktrees/daniel/
# make changes...
git checkout ../develop
git merge daniel/feature/US-001-auth-token-refresh --no-edit
```

The **Late Sync** model ensures main `develop` is always up-to-date before merging:
1. Main directory pulls latest from remote
2. Agent worktree rebases on main `develop`
3. Main directory merges the now-clean feature branch
This prevents stale merges and remote race conditions.

### 4.4 Pre-Merge Sync (The Critical "Late Sync")

Before merging into `develop`, agents MUST ensure they are building on the latest state:

```bash
# Main Directory: Pull latest
git checkout develop && git pull origin develop

# Agent Worktree: Rebase onto updated develop
git checkout <branch>
git rebase ../develop    # Resolve conflicts here
```

### 4.5 Local Merge Verification

Run a dry-run merge to verify the feature branch can merge cleanly into local `develop`:

```bash
git checkout develop
git merge --no-commit --no-ff <agent>/<branch>
git merge-tree HEAD $(git merge-base HEAD <agent>/<branch>) <agent>/<branch>
# Verify clean output, then:
git merge --abort
git checkout <agent>/<branch>
```

If conflicts are detected, resolve them in the worktree before proceeding to Phase 4 (Local Merge).

---

## 5. Human + AI Collaboration

### 5.1 Human Developers

Human developers work however they prefer. Direct commits on `develop`, feature branches, anything goes. The only requirement: **all code enters `develop` through MRs**, same as agents.

### 5.2 AI Agents

AI agents follow strict worktree protocol. They never touch the main working directory's branch. Every change goes through:

1. Worktree creation
2. Feature branch work
3. Push and MR
4. Review and merge
5. Worktree cleanup

### 5.3 Same Rules for Everyone

All code enters `develop` through MRs. Human or AI, the review process is identical:

- MR must pass CI pipeline
- Required reviewers must approve
- No self-merging without review (unless explicitly authorized by Emma)

### 5.4 Visibility

Humans see agent commits under agent names in git log and GitLab. For example:

```
commit abc1234
Author: daniel.phanes <daniel@phanes.ltd>
Date:   Fri Jun 14 10:30:00 2026 +0000

    Add token refresh endpoint for API clients
```

GitLab shows the commit under `daniel.phanes`'s profile. MRs created by agents appear as created by the agent's GitLab account.

### 5.5 Human on `develop` + Agent Worktrees: The Local Merge Sync Protocol

The human developer works directly on `develop` in the main working directory. AI agents work in `.worktrees/<agent>/` on feature branches. These are **independent** until the agent completes their task.

#### Why This Works

Git worktrees have **independent working directories and indexes**. When the human commits and pushes to `develop`:
- The main working directory updates normally.
- Agent worktrees are **untouched**. Their files, staging area, and branch pointer remain exactly as they were.
- No agent process is interrupted. No files change under any agent.
- Multiple agents can be working simultaneously — none are affected.

The coordination happens via **explicit Late Sync** before the agent merges into main `develop`. This ensures the agent incorporates the human's latest remote pushes before modifying the local integration branch.

#### The Two Sync Points

Agents sync at exactly **two moments** during every task:

| Sync Point | When | Why |
|------------|------|-----|
| **Before starting work** | After worktree creation, before first edit | Ensures the agent builds on the latest `develop`, not stale code |
| **Before merging into local `develop`** | After all edits are done, before `git merge` in main dir | Ensures no conflicts with the human's latest remote pushes or other merged agents |

#### The Protocol

**Human developer** (normal workflow, no changes needed):

```bash
# Human works directly on develop — commits and pushes at will
cd /path/to/repo
git checkout develop
# ... edit files ...
git add . && git commit -m "Update shared interface"
git push origin develop
```

This is always safe. It never disrupts any agent worktree.

**Agent** (Late Sync & Local Merge workflow):

```bash
# 1. Source environment
source scripts/oelite-gitlab-env.sh

# 2. Sync main develop with remote (start of task)
git checkout develop && git pull origin develop

# 3. Create worktree
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth-token-refresh

# 4. Work in the worktree
cd .worktrees/daniel/
# ... edit files, commit ...

# 5. Late Sync: Update main develop with remote
git checkout ../develop
git pull origin develop

# 6. Rebase agent branch onto updated main develop
git checkout feature/US-001-auth-token-refresh
git rebase ../develop

# 7. Resolve conflicts in worktree if needed
# git add <resolved-files> && git rebase --continue

# 8. Merge into main develop
git checkout ../develop
git merge daniel/feature/US-001-auth-token-refresh --no-edit

# 9. Cleanup
scripts/oelite-gitlab.sh worktree-remove daniel
```

#### What If the Human Has Uncommitted Changes?

The human's uncommitted changes in the main working directory do **not** block agents. Agents work in separate directories with separate indexes. The sync command only fetches from the **remote** `origin/develop`, not the local working directory. So:
- Human has uncommitted files in the main checkout → agents are unaffected.
- Human has committed locally but not pushed → agents won't see those changes until the human pushes.
- Human has pushed to `origin/develop` → agents see those changes on their Late Sync.

**Guideline for humans**: Commit and push to `develop` regularly so agents always have recent code to build on. Stale `develop` branches mean agents work on outdated code and face larger rebases later.

#### What If Multiple Agents Are Working?

Each agent syncs and merges independently into local `develop`. Because agents merge sequentially (only one main `develop` directory), their work accumulates cleanly:
- Agent A finishes → merges into local `develop` → cleanup
- Agent B finishes → pulls latest remote → rebases → merges into local `develop` (now includes Agent A's work) → cleanup
No coordination is needed between agents for the merge step.

#### Conflict Resolution During Sync

If the human (or another merged agent) has changed the same files the agent is working on, the rebase will report conflicts:

```
CONFLICT (content): Merge conflict in OElite.Common.Platform/Biz/Products/Product.cs
```

The agent resolves conflicts in their worktree:

```bash
# Edit the conflicted file to resolve
# Then:
git add <resolved-files>
git rebase --continue
```

If conflicts are complex, the agent should check what changed on `develop` before resolving:

```bash
git log --oneline origin/develop...HEAD
```

---

## 6. GitLab Integration

All project management happens in GitLab at https://code.phanes.ltd. The CLI tool `scripts/oelite-gitlab.sh` wraps the GitLab API using each agent's PAT.

### 6.1 Issues

- Issues are tracked in GitLab per project.
- Emma assigns issues to agents via `scripts/oelite-gitlab.sh issue-assign`.
- Agents comment on issues using their own PAT. Comments appear under the agent's GitLab identity.
- Issue state transitions (open, in_progress, review, done) are managed by Emma.

### 6.2 Merge Requests

- MRs are created via `scripts/oelite-gitlab.sh mr-create` with the implementing agent's PAT.
- The MR description should reference the issue it addresses.
- Reviewers are assigned based on the workflow chain defined in `AGENTS.md`.

### 6.3 Approvals

- Reviewers approve via `scripts/oelite-gitlab.sh mr-approve` using their own PAT.
- Approval appears under the reviewer's GitLab identity.
- Required approvals depend on the change type (see workflow chains in `AGENTS.md`).

### 6.4 Comments

- Issue comments: `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>`
- MR comments: `scripts/oelite-gitlab.sh mr-comment <project> <iid> <agent> <message>`
- All comments are attributed to the specified agent's GitLab account.

---

## 7. CLI Tool Reference

The CLI tool `scripts/oelite-gitlab.sh` is the single interface for all GitLab operations. It reads PATs from macOS Keychain at runtime via `scripts/oelite-gitlab-env.sh`.

### 7.1 Setup

```bash
scripts/oelite-gitlab.sh setup
```

Verifies all PATs are present in Keychain and accessible. Run this at the start of every session to confirm identity.

### 7.2 Issue Management

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh issues <project>` | Fetch open issues for a project |
| `scripts/oelite-gitlab.sh issue-assign <project> <iid> <agent>` | Assign issue to an agent |
| `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>` | Comment on an issue as an agent |

**Parameters:**

- `<project>`: GitLab project path (e.g., `oelite/helios/core`)
- `<iid>`: Issue internal ID (the number shown in GitLab UI)
- `<agent>`: Agent name from the Team Identity Registry (e.g., `daniel`, `sophia`)
- `<message>`: Comment text (quote if it contains spaces)

**Examples:**

```bash
scripts/oelite-gitlab.sh issues oelite/helios/core
scripts/oelite-gitlab.sh issue-assign oelite/helios/core 42 daniel
scripts/oelite-gitlab.sh issue-comment oelite/helios/core 42 daniel "Implementation started. Working on token refresh logic."
```

### 7.3 Worktree Management

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh worktree-create <agent> <branch> [base]` | Create worktree for an agent |
| `scripts/oelite-gitlab.sh worktree-list` | List all active worktrees in the current repo |
| `scripts/oelite-gitlab.sh worktree-remove <agent>` | Remove an agent's worktree |

**Parameters:**

- `<agent>`: Agent name (e.g., `daniel`, `sophia`)
- `<branch>`: Feature branch name (e.g., `feature/US-001-auth-token-refresh`)
- `[base]`: Base branch to create from (default: `develop`)

**Examples:**

```bash
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth-token-refresh
scripts/oelite-gitlab.sh worktree-create sophia feature/US-015-checkout-payment-flow develop
scripts/oelite-gitlab.sh worktree-list
scripts/oelite-gitlab.sh worktree-remove daniel
```

### 7.4 Sync & Local Merge

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh worktree-list` | List all active worktrees in the current repo |
| `scripts/oelite-gitlab.sh worktree-remove <agent>` | Remove an agent's worktree after merge |
| `scripts/oelite-gitlab.sh status` | Show overall status (active worktrees, recent issues) |

**Examples:**

```bash
git checkout develop && git pull origin develop   # Sync main directory
git -C .worktrees/daniel rebase develop           # Sync agent worktree
git checkout develop && git merge daniel/feature/xxx --no-edit # Local merge
scripts/oelite-gitlab.sh worktree-remove daniel   # Cleanup
scripts/oelite-gitlab.sh status
```

### 7.5 GitLab Operations (Human Publisher)

GitLab operations (MR creation, approvals, comments) are reserved for **human developers** in this model:

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh issues <project>` | Fetch open issues |
| `scripts/oelite-gitlab.sh issue-assign <project> <iid> <agent>` | Assign issue to agent |
| `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>` | Comment on an issue as agent |
| `scripts/oelite-gitlab.sh mr-create <project> <agent> <source> <target> <title> [desc]` | Create MR (human only) |
| `scripts/oelite-gitlab.sh mr-list <project>` | List open MRs |
| `scripts/oelite-gitlab.sh mr-comment <project> <iid> <agent> <message>` | Comment on an MR |
| `scripts/oelite-gitlab.sh mr-approve <project> <iid> <agent>` | Approve an MR |

---

## 8. Session Bootstrap (Local Merge Model)

Every agent session starts with this sequence. No exceptions.

### Step 1: Source the Environment

```bash
source scripts/oelite-gitlab-env.sh
```

This loads all PATs from macOS Keychain into environment variables. You should see:

```
[OK] 12 GitLab PATs loaded from Keychain.
```

If any PATs are missing, you'll see warnings. Missing PATs mean that agent can't perform GitLab operations.

### Step 2: Verify Identity

```bash
scripts/oelite-gitlab.sh setup
```

Confirms all PATs are valid and can authenticate against GitLab.

### Step 3: Sync Main `develop` with Remote

```bash
git checkout develop && git pull origin develop
```

**This is the first critical sync point.** Ensures the main directory holds the latest remote state before creating a worktree.

### Step 4: Fetch Issues

```bash
scripts/oelite-gitlab.sh issues <project>
```

Review open issues. Emma assigns issues to agents before work begins.

### Step 5: Create Worktree

```bash
scripts/oelite-gitlab.sh worktree-create <agent> <branch>
```

This creates the worktree directory, checks out a new feature branch from the latest local `develop`, and sets the per-worktree git config (`user.name` and `user.email`).

### Step 6: Work in the Worktree

```bash
cd .worktrees/<agent>/
```

All file edits, builds, and tests happen inside the worktree directory. The worktree is a full checkout of the repo on the feature branch. The human developer may continue pushing to `develop` during this time — the worktree is unaffected.

### Step 7: Late Sync & Rebase

```bash
git checkout ../develop
git pull origin develop
git checkout <branch>
git rebase ../develop
```

**This is the second critical sync point.** Before merging into main `develop`, rebase the feature branch on the latest remote `develop` to pick up any commits the human (or other merged agents) pushed while working.

If sync detects conflicts, resolve them in the worktree before proceeding:

```bash
# Edit conflicted files to resolve
git add <resolved-files>
git rebase --continue
```

Run tests after resolving conflicts to confirm nothing is broken.

### Step 8: Local Merge

```bash
git checkout ../develop
git merge <agent>/<branch> --no-edit
```

The agent's work is now directly integrated into the local `develop` branch. Other agents can immediately build on these changes.

### Step 9: After Merge Complete

```bash
scripts/oelite-gitlab.sh worktree-remove <agent>
```

This cleans up the worktree directory and the local feature branch.

---

## 9. Security Rules

### 9.1 PAT Storage

- PATs are stored in **macOS Keychain** only. Never in files. Never committed.
- Each PAT is stored as a generic password with service name `oelite-gitlab-<agent>` and account `oelite`.
- The bootstrap script reads from Keychain at runtime.

**Adding a PAT to Keychain:**

```bash
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

### 9.2 Environment Files

- `.env` files are in `.gitignore`. Never commit them.
- The `scripts/oelite-gitlab-env.sh` script does not create `.env` files. It exports variables into the current shell session only.

### 9.3 PAT Hygiene

- Each agent uses **their own PAT**. No sharing PATs between agents.
- Rotate PATs periodically (recommended: every 90 days).
- If a PAT is compromised, revoke it immediately in GitLab (User Settings > Access Tokens) and remove it from Keychain:

```bash
security delete-generic-password -s "oelite-gitlab-<agent>" -a "oelite"
```

### 9.4 No Secrets in Commits

- Never commit PATs, API keys, passwords, or connection strings.
- Use environment variables or Keychain references.
- If a secret is accidentally committed, revoke it immediately and force-push to remove it from history.

---

## 10. Conflict Resolution

### 10.1 Prevention

Directory-level ownership prevents most conflicts. Emma assigns non-overlapping directory scopes per task. Agents stay within their scope.

### 10.2 Shared File Serialization

Shared files (Program.cs, docker-compose, shared interfaces, AGENTS.md, etc.) are gated. Only one agent modifies a shared file at a time. Emma coordinates the order.

### 10.3 Conflict Resolution During Rebase

If conflicts arise when rebasing on `develop`:

1. The agent resolves the conflicts in their worktree.
2. The agent runs tests after resolving conflicts.
3. The agent continues the rebase and pushes.

```bash
# Resolve conflicts in the worktree
# Edit conflicted files, then:
git add <resolved-files>
git rebase --continue
git push origin <branch> --force-with-lease
```

### 10.4 Two Agents Need the Same File

If two agents need to modify the same file:

1. Emma decides who goes first based on task priority and dependency order.
2. The first agent completes their MR and merges.
3. The second agent rebases on the updated `develop` and incorporates the first agent's changes.

### 10.5 Escalation

If agents can't resolve a conflict independently, Emma mediates. For architectural conflicts, Marcus adjudicates.

---

## 11. Pre-Merge Checklist

Before merging into local `develop`, the agent **MUST** verify every item below. No merge should be created with unchecked items.

### Pre-Merge Verification

- [ ] Main `develop` pulled from remote (`git checkout develop && git pull origin develop`)
- [ ] Feature branch rebased on latest local `develop` (`git rebase ../develop`)
- [ ] Build passes in worktree (`dotnet build` / `npm run build` / `ng build`)
- [ ] Tests pass (unit tests at minimum; integration tests if applicable)
- [ ] No placeholder/mock/TODO data in changed files
- [ ] Code follows OElite coding standards (`coding-standards/`)
- [ ] Directory scope respected (no changes outside assigned scope)
- [ ] Commit messages follow convention (see Section 12)
- [ ] No secrets, PATs, or credentials in committed files
- [ ] No `as any`, `@ts-ignore`, or type-error suppression (frontend)
- [ ] No raw `MongoDB.Driver`, `BsonDocument`, or manual DI (backend)
- [ ] Health endpoint verified if service is runnable

### Merge Metadata

- [ ] Merge is executed in main directory: `git checkout develop && git merge <branch> --no-edit`
- [ ] Worktree is removed after successful merge: `scripts/oelite-gitlab.sh worktree-remove <agent>`

---

## 12. Commit Message Convention

All commits follow a consistent format for traceability and changelog generation.

### Format

```
<title>

- <change 1>
- <change 2>
- <change 3>
```

**Rules:**

- **Title**: Imperative mood, 50 chars max, no period at end. Example: "Add token refresh endpoint for API clients"
- **Body**: Bullet list of changes, each starting with a hyphen.
- **No AI references**: Never mention "Claude", "Claude Code", "Anthropic", "AI", or emojis in commit messages.
- **No issue prefix in commit**: The MR title references the issue, not every commit.

### Examples

```
Add token refresh endpoint for API clients

- Implement TokenService.RefreshAsync with RS256 rotation
- Add Redis blacklist for revoked tokens
- Add integration tests for refresh flow
- Update API client repository with token query methods
```

```
Fix cascade update loop in product denormalization

- Bound cascade depth to 3 levels in CascadeUpdateService
- Add cycle detection before processing denormalized fields
- Update DataSyncJob to skip already-processed collections
```

```
Implement checkout payment flow UI

- Add payment method selection component
- Add order summary with real-time price calculation
- Integrate with payment API client
- Add loading, error, and empty states per No-Mock-Data policy
```

---

## 13. Edge Cases & FAQ

### Q: What if my worktree gets into a broken state?

Remove it and recreate:

```bash
scripts/oelite-gitlab.sh worktree-remove <agent>
scripts/oelite-gitlab.sh worktree-create <agent> <branch>
```

Your commits are still on the remote branch (if you pushed). If you didn't push, the work is lost. Push frequently.

### Q: What if two agents accidentally modify the same file?

The second agent to create an MR will see conflicts during rebase. Resolve them, push, and proceed. Going forward, Emma should assign non-overlapping scopes.

### Q: Can a human developer work on the same branch as an agent?

No. If a human needs to work on the same feature, they should coordinate with the agent through GitLab comments. The human can create a review branch or work in a separate worktree.

### Q: What if `develop` has moved significantly since I created my branch?

Run `scripts/oelite-gitlab.sh sync <agent>` to rebase. If there are many conflicts, consider whether the feature should be split into smaller MRs.

### Q: Can I have multiple worktrees in different repos?

Yes. An agent can have one worktree per repo. For example, Daniel can have a worktree in `helios/core/` and another in `uranus/origin-auth/` simultaneously.

### Q: What happens if an MR is rejected?

The implementing agent addresses the feedback, pushes new commits, and the reviewer re-evaluates. After 2 failed review attempts, the issue escalates to Marcus (architecture) or Emma (requirements).

### Q: How do I handle a worktree after my MR is merged?

Remove it:

```bash
scripts/oelite-gitlab.sh worktree-remove <agent>
```

Then switch to the repo root and pull the latest `develop`:

```bash
cd <repo-root>
git checkout develop
git pull origin develop
```

---

## 14. Standards Maintenance

### Update Process

1. Changes to this standard go through the same MR process as code changes.
2. Emma approves workflow changes. Marcus approves architectural impacts.
3. Update this file and sync to `uranus/arc-agents/standards/` if it exists there.

### Version History

| Date | Update |
|------|--------|
| Jun 2026 | Initial standard. Worktree protocol, branch strategy, GitLab integration, CLI tool reference. |
| Jun 20 2026 | **Major Update**: Replaced MR-centric remote workflow with **Late Sync & Local Merge Model**. Agents now merge directly into local `develop` instead of pushing/remotely creating MRs. Human developers act as "Publishers" for remote `develop`. Updated Sections 1, 2.4, 3.4, 4.3, 4.4, 4.5, 5.5, 7.4, 8, 11 to reflect agentic AI local-first workflow. |

---

## Related Documentation

- [AGENTS.md](../../AGENTS.md) - Team roles, workflow chains, and collaboration protocol
- [coding-standards/README.md](../README.md) - Master index of all coding standards
- [rulespec_checklist.md](../rulespec_checklist.md) - AI agent project bootstrapping guide
