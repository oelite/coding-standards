# Git Workflow & Collaboration Standards

## Overview

This document defines the git workflow, worktree protocol, human+AI collaboration rules, and GitLab integration for the OElite platform. These standards apply to **ALL repositories** in the OElite monorepo without exception.

The OElite team consists of 12 members (10 AI agents + human developers) who work in parallel on the same codebase. Parallel development requires strict isolation, clear ownership boundaries, and consistent merge practices to prevent conflicts and maintain code quality.

### Key Principles

- **`develop` is the single source of truth.** The local `develop` branch is always a mirror of `origin/develop`. Agents pull before starting work and pull after MR merges. No local-only commits accumulate.
- **Worktree isolation.** AI agents work in isolated git worktrees, never in the main working directory.
- **MR-Centric Model.** All code enters `develop` through GitLab Merge Requests. Agents push their feature branch, create an MR, and the MR is reviewed and merged via GitLab. No local merges — GitLab is the integration point.
- **Review before merge.** Code review is a gate, not an afterthought. No code enters `develop` without required approvals. GitLab enforces this natively.
- **Auto-merge on approval.** When an MR is approved and the CI pipeline succeeds, GitLab auto-merges and auto-deletes the feature branch. This eliminates manual merge steps.
- **Parallel by design.** Directory-level ownership and worktree isolation let multiple agents work simultaneously without stepping on each other. GitLab handles concurrent MRs natively.

---

## 1.5 Mandatory Pre-Task Sync (Hard Gate)

**This is a non-negotiable gate. No work begins until this step is completed.**

Before ANY task begins — including research, exploration, planning, or code review — the main directory's `develop` branch MUST be pulled from remote:

```bash
# HARD GATE — execute before any task, including reading code or creating a worktree
../../coding-standards/scripts/oelite-gitlab.sh worktree-sync
```

### Why This Exists

When agents push feature branches and create MRs, they need to branch from the latest approved code. Without this hard gate:

- Agents branch from outdated code, increasing merge conflicts
- MRs target an outdated `develop`, requiring rebases later
- The workflow becomes less efficient due to unnecessary conflict resolution

### Enforcement

| Scenario | Action |
|----------|--------|
| Starting a new task session | `../../coding-standards/scripts/oelite-gitlab.sh worktree-sync` — safe sync, does NOT checkout develop |
| Switching between tasks | Re-sync before creating a new worktree |
| Emma doing planning | Sync `develop` before creating tasks or assigning issues |
| Human developer working | Already on `develop` — pull before any commit: `git checkout develop && git pull origin develop` |

**Failure to sync before starting work means the agent branches from stale `develop`, increasing merge conflicts and rebases required.**

---

## 1.6 Post-Merge Sync (After MR Merged)

After an MR is merged into `develop` (via GitLab), the local `develop` must be synced before starting new work:

```bash
# After your MR is merged (or any MR is merged)
../../coding-standards/scripts/oelite-gitlab.sh worktree-sync
```

### Sync Responsibilities

| Role | Responsibility |
|------|---------------|
| **Any agent** | MUST sync `develop` after their MR is merged and before starting a new task |
| **Emma** (Product Coordinator) | MUST sync `develop` before starting any planning session or creating tasks |
| **Human developers** | MUST sync `develop` before any commit or push (`git checkout develop && git pull origin develop`) |

### Stale `develop` Detection

Use `scripts/oelite-gitlab.sh status` to check worktree status:

```
AGENT     OWNER      BRANCH                           AHEAD    BEHIND   LAST COMMIT  STATUS
daniel    daniel     feature/US-001-auth-token-refresh   3        2        2026-06-20   active
```

The `BEHIND` column shows how many commits the worktree's branch is behind `origin/develop`. If `BEHIND > 0`, the agent should rebase:

```bash
scripts/oelite-gitlab.sh sync <agent>
```

---

## 1.7 Issue-First (Hard Gate — No Work Without an Issue)

**This is a non-negotiable gate. No work begins until a GitLab issue ticket exists with full task elaboration.**

Before ANY work — including exploration, planning, code review, or worktree creation — a GitLab issue MUST exist in the target project and meet the **Definition of Ready** (see `TASK-TEMPLATES.md` §1 for the full checklist). In summary, the issue must have:

- Title with issue reference (US-XXX, BUG-XXX, TASK-XXX)
- Acceptance criteria in GIVEN/WHEN/THEN format
- Owner assigned
- Priority labeled
- Dependencies identified (not blocking)

Issue creation MUST follow the templates in `ISSUE-MR-TEMPLATES.md` (Feature, Bug, or Task template as appropriate).

### Why This Exists

Without issue-first enforcement:
- Work happens without traceability — no way to track what was done or why
- MRs are submitted with no linked issue, making review and closure haphazard
- Issues are left open after MRs merge because nobody owns the closure step
- Sprint planning has no visibility into in-flight work

### Enforcement

| Scenario | Action |
|----------|--------|
| Agent asked to start a task with no issue | STOP. Ask Emma to create the issue via `issue-create` using `ISSUE-MR-TEMPLATES.md` |
| Issue exists but doesn't meet Definition of Ready | STOP. Ask Emma to elaborate before proceeding |
| MR submitted with no `Closes #<issue>` reference | Reviewer MUST reject and request issue linkage |
| Issue created but not yet assigned | Do not start work — wait for Emma to assign via `issue-assign` |

```bash
# Verify the issue exists before starting work
scripts/oelite-gitlab.sh issues <project>
```

**Only after the issue is verified (exists, meets Definition of Ready) may the agent proceed to sync, worktree creation, and implementation.**

---

## 2. Team Identity Registry

Every team member has a unique GitLab identity. AI agents commit under the team member's GitLab identity configured in their worktree — **never under the AI executor's own name**. All GitLab operations (comments, MRs, approvals) use the configured team member's personal access token (PAT).

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

## 3. Git Flow: Branch Strategy

### 2.1 Permanent Branches

| Branch | Purpose | Who Commits |
|--------|---------|-------------|
| `develop` | Integration branch. All MRs target this. | Only via merged MRs. Never direct commits. |
| `main` | Production-ready releases. | Only via release MRs from `develop`. |

### 2.1.1 Protected Branches (Server-Side Enforcement)

**GitLab protected branches MUST be configured for `develop` and `main`** as a second layer of defense beyond the pre-commit hook:

- `develop`: Protected against direct pushes. Only MR merges allowed. Allows force push? **No**.
- `main`: Protected against direct pushes. Only MR merges from `develop` allowed. Allows force push? **No**.

This prevents accidental direct commits even if an agent bypasses the pre-commit hook. Configure in GitLab: **Settings > Repository > Protected Branches**.

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

### 2.4 Branch Lifecycle (MR-Centric Model)

```
1. Create feature branch from latest origin/develop
2. Work in worktree (agent) or local checkout (human)
3. Commit with conventional messages
4. Push feature branch to origin
5. Create MR targeting develop
6. Reviewer reviews, approves or requests changes
7. If changes requested: agent fixes, pushes, reviewer re-reviews
8. On approval + CI green: MR auto-merges, feature branch auto-deleted
9. Agent syncs local develop: scripts/oelite-gitlab.sh worktree-sync
```

---

## 4. Worktree Protocol

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

### 3.2 One Worktree Per Agent+Issue

Each agent gets **ONE worktree per issue** per repo. The worktree path includes the issue number to enable parallel work on non-blocking tickets:

```
<repo>/.worktrees/<agent>-<issue>/
```

**Examples:**

```
helios/core/.worktrees/daniel-42/       # Daniel working on issue #42
helios/core/.worktrees/daniel-57/       # Daniel working on issue #57 (parallel)
jupiter/ec-nx-01/.worktrees/sophia-15/  # Sophia working on issue #15
```

If an agent needs to work on a second task in the same repo, they create a **second worktree** with a different issue number. This enables parallel same-agent work without conflicts.

**Legacy mode** (`--no-issue`): For work that genuinely does not require an issue ticket (spikes, experiments), use `--no-issue` to fall back to the agent-name-only path (`.worktrees/<agent>/`). Only one legacy worktree per agent per repo is allowed.

### 3.3 Per-Worktree Git Config

When a worktree is created, git config is set for that worktree only:

```bash
git config user.name "daniel.phanes"
git config user.email "daniel@phanes.ltd"
```

This ensures commits are attributed to the correct agent regardless of the host machine's global git config.

### 3.4 Worktree Lifecycle (MR-Centric Model)

```
1. SYNC      scripts/oelite-gitlab.sh worktree-sync (safe — does NOT checkout develop)
2. CREATE    scripts/oelite-gitlab.sh worktree-create <agent> <branch> --issue <iid>
             → Creates .worktrees/<agent>-<iid>/ with auto-generated .oe-scope
             → Pre-commit hook installed automatically (worktree + branch guard)
2.5 SCOPE    scripts/oelite-gitlab.sh oe-scope <agent>-<iid> --task-type <type> --desc "<desc>"
3. WORK      cd .worktrees/<agent>-<iid>/ && make changes && commit
             → After compaction: cat .oe-scope to restore context
4. PUSH      git push origin <branch>
5. MR        scripts/oelite-gitlab.sh mr-create <project> <agent> <branch> develop "<title>"
6. REVIEW    Reviewer reviews → approves or requests changes
7. FIX       If changes requested: fix in worktree → push → re-review
8. MERGE     Auto-merge on approval + CI green (GitLab)
9. SYNC      scripts/oelite-gitlab.sh worktree-sync (prepare for next task)
10. CLEANUP  scripts/oelite-gitlab.sh worktree-remove <agent>-<iid>
             → .oe-scope deleted with worktree
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

## 5. Parallel Development Rules

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

AI agents **NEVER** work directly on `develop` in the main directory. All agent work happens in worktrees on feature branches. Code enters `develop` through GitLab MRs:

```bash
# WRONG - agent working directly on develop in main dir
cd /path/to/repo
git checkout develop
# make changes...

# CORRECT - agent works in worktree, pushes, creates MR
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth-token-refresh --issue 42
cd .worktrees/daniel-42/
# make changes, commit...
git push origin feature/US-001-auth-token-refresh
# Then create MR via GitLab (auto-merges on approval + CI green)
```

The **MR-Centric** model ensures all code is reviewed before merging:
1. Agent branches from latest `origin/develop`
2. Agent works in worktree, commits, pushes feature branch
3. Agent creates MR targeting `develop`
4. Reviewer reviews → approves or requests changes
5. On approval + CI green: GitLab auto-merges and auto-deletes feature branch

### 4.4 Keeping Feature Branch Up-to-Date

To minimize merge conflicts, agents should keep their feature branch up-to-date with `origin/develop`:

```bash
# In worktree: fetch latest develop
git fetch origin develop

# Rebase feature branch onto latest develop (resolve conflicts if any)
git checkout <branch>
git rebase origin/develop
# Resolve conflicts in worktree if needed:
#   git add <resolved-files> && git rebase --continue
```

### 4.5 Conflict Resolution During Rebase

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

## 6. Human + AI Collaboration

### 6.1 Human Developers

Human developers work however they prefer. Direct commits on `develop`, feature branches, anything goes. The only requirement: **all code enters `develop` through MRs**, same as agents.

### 6.2 AI Agents

AI agents follow strict worktree protocol. They never touch the main working directory's branch. Every change goes through:

1. Sync local `develop` with remote
2. Worktree creation
3. Feature branch work
4. Push feature branch to remote
5. Create MR targeting `develop`
6. Review and approval (reviewer comments, agent fixes if needed)
7. GitLab auto-merges on approval + CI green (feature branch auto-deleted)
8. Sync local `develop` for next task
9. Worktree cleanup

### 6.3 Same Rules for Everyone

All code enters `develop` through MRs. Human or AI, the review process is identical:

- MR must pass CI pipeline
- Required reviewers must approve
- No self-merging without review (unless explicitly authorized by Emma)
- GitLab auto-merges on approval + CI green (feature branch auto-deleted)

### 6.4 Visibility

Humans see agent commits under agent names in git log and GitLab. For example:

```
commit abc1234
Author: daniel.phanes <daniel@phanes.ltd>
Date:   Fri Jun 14 10:30:00 2026 +0000

    Add token refresh endpoint for API clients
```

GitLab shows the commit under `daniel.phanes`'s profile. MRs created by agents appear as created by the agent's GitLab account. When the MR is approved and CI passes, GitLab auto-merges the change and auto-deletes the source branch.

### 6.5 Human on `develop` + Agent Worktrees: The MR-Centric Sync Protocol

The human developer works directly on `develop` in the main working directory. AI agents work in `.worktrees/<agent>/` on feature branches. All code enters `develop` through GitLab MRs — whether from humans or agents.

#### Why This Works

Git worktrees have **independent working directories and indexes**. When the human commits and pushes to `develop`:
- The main working directory updates normally.
- Agent worktrees are **untouched**. Their files, staging area, and branch pointer remain exactly as they were.
- No agent process is interrupted. No files change under any agent.
- Multiple agents can be working simultaneously — none are affected.

The coordination happens via **GitLab MRs**. Agents push their feature branch, create an MR, and the MR is reviewed and merged via GitLab. The local `develop` is synced via `git pull origin develop` after MR merges.

#### The Two Sync Points

Agents sync at exactly **two moments** during every task:

| Sync Point | When | Why |
|------------|------|-----|
| **Before starting work** | After worktree creation, before first edit | Ensures the agent builds on the latest `develop`, not stale code |
| **After MR merged** | After GitLab auto-merges the MR | Ensures local `develop` is up-to-date for next task |

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

**Agent** (MR-Centric workflow):

```bash
# 1. Source environment
source scripts/oelite-gitlab-env.sh

# 2. Sync main develop with remote (start of task) — safe, does NOT checkout develop
scripts/oelite-gitlab.sh worktree-sync

# 3. Create worktree (replace 42 with actual issue number)
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth-token-refresh --issue 42

# 4. Work in the worktree
cd .worktrees/daniel-42/
# ... edit files, commit ...
# Pre-commit hook automatically enforces worktree isolation and branch protection

# 5. Push feature branch to remote
git push origin feature/US-001-auth-token-refresh

# 6. Create MR targeting develop
scripts/oelite-gitlab.sh mr-create <project> daniel feature/US-001-auth-token-refresh develop "Add token refresh endpoint"

# 7. Wait for reviewer feedback
# If changes requested: fix in worktree → push → re-review

# 8. After MR approved + CI green: GitLab auto-merges
# Clean up worktree
scripts/oelite-gitlab.sh worktree-remove daniel-42

# 9. Sync local develop for next task
scripts/oelite-gitlab.sh worktree-sync
```

#### What If the Human Has Uncommitted Changes?

The human's uncommitted changes in the main working directory do **not** block agents. Agents work in separate directories with separate indexes. The sync command only fetches from the **remote** `origin/develop`, not the local working directory. So:
- Human has uncommitted files in the main checkout → agents are unaffected.
- Human has committed locally but not pushed → agents won't see those changes until the human pushes.
- Human has pushed to `origin/develop` → agents see those changes on their next sync.

**Guideline for humans**: Commit and push to `develop` regularly so agents always have recent code to build on. Stale `develop` branches mean agents work on outdated code and face larger rebases later.

#### What If Multiple Agents Are Working?

Each agent works independently in their worktree and creates their own MR. GitLab handles concurrent MRs natively. When an MR is merged, the agent syncs their local `develop` before starting the next task:
- Agent A finishes → creates MR → reviewer approves → GitLab merges → Agent A syncs
- Agent B finishes → creates MR → reviewer approves → GitLab merges → Agent B syncs
No coordination is needed between agents for the merge step.

#### Conflict Resolution During Rebase

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
git push origin <branch> --force-with-lease
```

If conflicts are complex, the agent should check what changed on `develop` before resolving:

```bash
git log --oneline origin/develop...HEAD
```

---

## 7. GitLab Integration

All project management happens in GitLab at https://code.phanes.ltd. The CLI tool `scripts/oelite-gitlab.sh` wraps the GitLab API using each agent's PAT.

### 7.1 Issues

- Issues are tracked in GitLab per project.
- Emma assigns issues to agents via `scripts/oelite-gitlab.sh issue-assign`.
- Agents comment on issues using their own PAT. Comments appear under the agent's GitLab identity.
- Issue state transitions are managed per the **Issue Lifecycle Protocol** (see §8 below).

### 7.2 Merge Requests

- MRs are created via `scripts/oelite-gitlab.sh mr-create` with the implementing agent's PAT.
- The MR description should reference the issue it addresses.
- Reviewers are assigned based on the workflow chain defined in `AGENTS.md`.

### 7.3 Approvals

- Reviewers approve via `scripts/oelite-gitlab.sh mr-approve` using their own PAT.
- Approval appears under the reviewer's GitLab identity.
- Required approvals depend on the change type (see workflow chains in `AGENTS.md`).

### 7.4 Comments

- Issue comments: `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>`
- MR comments: `scripts/oelite-gitlab.sh mr-comment <project> <iid> <agent> <message>`
- All comments are attributed to the specified agent's GitLab account.

---

## 8. Issue Lifecycle Protocol (SCRUM/Dev Workflow)

This section defines the mandatory issue status workflow that every agent MUST follow. It ensures full traceability from issue creation through business validation.

### 8.1 Issue Statuses

OElite uses GitLab labels to track issue status. The following labels are **mandatory** on every project's GitLab instance:

| Label | Color | Meaning | Who Sets It |
|-------|-------|---------|-------------|
| `To Do` | #666666 | Issue created, not yet started | Emma (on creation) |
| `In Progress` | #0075CA | Agent actively working | Assignee (on worktree creation) |
| `PR Review` | #FCA326 | MR created, awaiting review | Assignee (on MR creation) |
| `Ready to Merge` | #009966 | MR approved + CI green | Reviewer (on approval) |
| `Done` | #3CB371 | MR merged + business validation passed | Emma (on merge + Isabella validation) |
| `Blocked` | #FF0000 | External dependency blocking progress | Assignee (when blocked) |

### 8.2 Status Transition Rules

Every status change MUST be accompanied by:
1. **Label update** in GitLab (add new status label, remove old one)
2. **Issue comment** explaining the transition (who, what, why)
3. **CLI command**: `scripts/oelite-gitlab.sh issue-status <project> <iid> <agent> <opened|closed>` (for open/close only)

| Trigger | From | To | Who | Required Action |
|---------|------|----|-----|-----------------|
| Emma assigns issue to agent | `To Do` | `In Progress` | Emma + Assignee | `issue-assign` + comment "Assigned to @agent. Starting work." |
| Agent creates worktree and begins implementation | `To Do` or unlabeled | `In Progress` | Assignee | Comment: "Implementation started. Branch: `feature/US-XXX-description`" |
| Agent creates MR | `In Progress` | `PR Review` | Assignee | Comment: "MR !N created. Link: [MR URL]. Ready for review by @reviewer." |
| Reviewer approves MR + CI green | `PR Review` | `Ready to Merge` | Reviewer | Comment: "Approved. CI green. Awaiting merge." |
| **MR merged into develop (verified)** | `Ready to Merge` | `Done` | Reviewer or Emma | Comment: "Merged into develop. Business validation: @isabella." + `mr-status` verification |
| **Issue closed in GitLab** | `Done` (label) | **Closed** (state) | Emma | Comment: "Issue complete. Closing." + `issue-status closed` — MUST happen in same session as merge verification |
| Blocker encountered | `In Progress` | `Blocked` | Assignee | Comment: "Blocked by: [reason]. Needs: [dependency]." |
| Blocker resolved | `Blocked` | `In Progress` | Assignee | Comment: "Blocker resolved. Resuming work." |

### 8.2.1 Merge Verification (Mandatory Step)

**Before transitioning an issue to `Done`, the reviewer (or Emma) MUST verify that the MR has actually merged.** Auto-merge is assumed but NOT guaranteed — protected branch rules, pipeline failures, or GitLab configuration issues can prevent merging silently.

```bash
# Check the MR's actual merge status
scripts/oelite-gitlab.sh mr-status <project> <mr-iid>
```

Output shows one of: `open`, `merged`, `closed`, `cannot_merge`.

| MR Status | Action |
|-----------|--------|
| `merged` | Proceed to label issue `Done` and close (see §8.2.2) |
| `open` | Do NOT label `Done` — investigate why auto-merge hasn't occurred; may need manual merge or pipeline fix |
| `cannot_merge` | Rebase the branch: `scripts/oelite-gitlab.sh sync <agent>`, push, then re-check |
| `closed` (unmerged) | MR was closed without merging — create a new MR or investigate |

**The reviewer who approves the MR is responsible for verifying the merge.** If the reviewer cannot verify (session ended), Emma MUST verify before closing the issue.

### 8.2.2 Issue Closure Enforcement (Mandatory Final Step)

**Labeling an issue `Done` is NOT sufficient — the issue MUST be closed in GitLab.**

Emma MUST close the issue in the **same session** as verifying the MR merge:

```bash
# 1. Verify MR is merged
scripts/oelite-gitlab.sh mr-status <project> <mr-iid>
# Must show: merged

# 2. Label the issue Done (via GitLab UI/API)

# 3. Close the issue
scripts/oelite-gitlab.sh issue-status <project> <iid> emma closed
```

**Why this matters**: Issues labeled `Done` but left `opened` in GitLab accumulate indefinitely. The `Done` label indicates completion; the `closed` state removes the issue from active boards and queries. Both are required.

### 8.2.3 Post-Merge Issue Audit

Isabella (or designated reviewer) MUST run a periodic audit to catch issues left open after their linked MRs were merged:

```bash
# List issues still open whose linked MRs are merged
scripts/oelite-gitlab.sh issue-audit <project>
```

This flags:
- Issues with `Done` label but still in `opened` state → close them
- Issues where the linked MR (via `Closes #<iid>`) is `merged` but the issue is still `opened` → close them

**Audit cadence**: At minimum, run after every sprint review. Ideally, run at the end of each work session before closing out the day.

| Audit Finding | Action |
|---------------|--------|
| Issue `Done` but `opened` | Close via `issue-status closed` |
| Issue linked to merged MR but still `opened` | Close via `issue-status closed` |
| Issue `opened` with no MR and no activity for >7 days | Escalate to Emma — reassign or close as won't-do |

### 8.3 Agent Responsibilities by Role

#### Emma (Product & Delivery Coordinator)
- Creates issues with `To Do` label, clear acceptance criteria, and story points using `ISSUE-MR-TEMPLATES.md`
- Assigns issues to the correct owner based on domain expertise
- Updates status to `In Progress` when assigning
- **Verifies MR merge** via `mr-status` before labeling `Done` (if reviewer hasn't already)
- Updates status to `Done` after MR merge verified + Isabella's business validation
- **Closes the issue via `issue-status closed`** in the same session as verifying merge — labeling `Done` is not sufficient
- Runs or delegates `issue-audit` periodically to catch orphaned open issues

#### Assignee (Implementing Agent: Daniel/Sophia/Jonathan/Ethan/etc.)
- Sets `In Progress` label when starting work (after worktree creation)
- Sets `PR Review` label when MR is created
- Sets `Blocked` label when encountering blockers, with detailed comment
- Never closes the issue — only Emma closes after business validation

#### Reviewer (Grace/Felix/Maya/Marcus/Victor)
- Reviews MR within the workflow chain
- Sets `Ready to Merge` label after approval + CI green
- **Verifies MR merge** via `mr-status` after approval — confirms GitLab actually merged the MR
- If merge verified: transitions issue to `Done` (if Emma delegates) or notifies Emma to close
- If changes requested: comment with specific fixes, assignee returns to `In Progress`

#### Isabella (Business Analyst)
- Validates deliverable against business requirements after MR merge
- Confirms `Done` status with Emma or requests changes (return to `In Progress`)
- **Runs `issue-audit <project>` periodically** to catch issues left open after their linked MRs were merged
- Escalates orphaned open issues to Emma for closure

### 8.4 SCRUM Integration

#### Sprint Planning (Emma-led)
- Issues are assigned to sprints via GitLab Milestones
- Each issue MUST have: acceptance criteria, story points, priority label
- Definition of Ready: issue has clear scope, acceptance criteria, and no blockers

#### Daily Progress
- Agents comment on their `In Progress` issues with daily updates
- Blockers are escalated to Emma within the same day
- Emma reviews `Blocked` issues and reassigns or clarifies

#### Sprint Review
- Emma reviews all `Done` issues against sprint goals
- Isabella confirms business validation for each completed issue
- Undefined issues return to `To Do` for next sprint

#### Definition of Done (Issue Level)
An issue is only `Done` when ALL are true:
- [ ] MR merged into `develop` (**verified via `mr-status` CLI**)
- [ ] CI pipeline green (build + unit tests)
- [ ] Integration tests pass (local Docker infrastructure)
- [ ] E2E tests pass (if user-facing)
- [ ] Code review approved by required reviewer
- [ ] Business validation passed (Isabella confirms)
- [ ] Documentation updated (per Part IV Self-Maintenance Protocol)
- [ ] No `Blocked` label remaining
- [ ] **Issue closed in GitLab** via `issue-status closed` (not just labeled `Done`)
- [ ] **Post-merge audit passed**: `issue-audit` confirms no orphaned open issues for this MR

### 8.5 Issue Comment Templates

Every status transition MUST include a structured comment:

**Starting Work:**
```
Starting work on this issue.

- Worktree: `.worktrees/<agent>/`
- Branch: `feature/US-XXX-description`
- Estimated approach: [brief technical plan]
- Dependencies: [any blockers or dependencies]
```

**Ready for Review:**
```
MR created and ready for review.

- MR: !<mr-iid> ([URL])
- Changes: [summary of what changed]
- Verification: [build/test/health commands run]
- Reviewer: @<reviewer> (per workflow chain)
```

**Blocked:**
```
Blocked by: [specific dependency or issue]

- What's needed: [exact requirement]
- Impact: [how this blocks progress]
- ETA: [expected resolution date if known]
```

### 8.6 CLI Commands for Issue Management

| Command | Description | When to Use |
|---------|-------------|-------------|
| `issue-create <project> <agent> <title> [description]` | Create a new issue | Emma or any agent: task intake, bugs, feature requests |
| `issue-assign <project> <iid> <agent>` | Assign issue to agent | Emma: during sprint planning or task assignment |
| `issue-comment <project> <iid> <agent> <message>` | Post comment on issue | Any agent: status updates, progress reports, blockers |
| `issue-status <project> <iid> <agent> <opened\|closed>` | Open or close issue | Emma: close after Done; reopen if regression found |

**Note:** Label changes (In Progress, PR Review, Ready to Merge, Blocked) are managed via GitLab UI or API. The CLI `issue-status` command handles the binary open/close state.

---

## 9. CLI Tool Reference

The CLI tool `scripts/oelite-gitlab.sh` is the single interface for all GitLab operations. It reads PATs from macOS Keychain at runtime via `scripts/oelite-gitlab-env.sh`.

### 9.1 Setup

```bash
scripts/oelite-gitlab.sh setup
```

Verifies all PATs are present in Keychain and accessible. Run this at the start of every session to confirm identity.

### 9.2 Issue Management

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh issues <project>` | Fetch open issues for a project |
| `scripts/oelite-gitlab.sh issue-create <project> <agent> <title> [description]` | Create a new issue as an agent |
| `scripts/oelite-gitlab.sh issue-assign <project> <iid> <agent>` | Assign issue to an agent |
| `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>` | Comment on an issue as an agent |
| `scripts/oelite-gitlab.sh issue-status <project> <iid> <agent> <opened\|closed>` | Open or close an issue as an agent |

**Parameters:**

- `<project>`: GitLab project path (e.g., `oelite/helios/core`)
- `<agent>`: Agent name from the Team Identity Registry (e.g., `daniel`, `sophia`)
- `<title>`: Issue title (quote if it contains spaces)
- `<description>`: Optional issue description (markdown supported; quote multi-word text)
- `<iid>`: Issue internal ID (the number shown in GitLab UI)
- `<message>`: Comment text (quote if it contains spaces)

**Examples:**

```bash
scripts/oelite-gitlab.sh issues oelite/helios/core
scripts/oelite-gitlab.sh issue-create oelite/helios/core emma "feat: add tenant export" "Closes #7"
scripts/oelite-gitlab.sh issue-assign oelite/helios/core 42 daniel
scripts/oelite-gitlab.sh issue-comment oelite/helios/core 42 daniel "Implementation started. Working on token refresh logic."
```

### 9.3 Worktree Management

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh worktree-create <agent> <branch> [base] [--issue <iid>] [--no-issue]` | Create worktree (issue-keyed or legacy) |
| `scripts/oelite-gitlab.sh worktree-list` | List all active worktrees in the current repo |
| `scripts/oelite-gitlab.sh worktree-remove <worktree-id>` | Remove a worktree (worktree-id = agent or agent-issue) |
| `scripts/oelite-gitlab.sh oe-scope <worktree-id> [--task-type T] [--issue I] [--desc D]` | Read or update per-worktree `.oe-scope` context anchor |

**Parameters:**

- `<agent>`: Agent name (e.g., `daniel`, `sophia`)
- `<branch>`: Feature branch name (e.g., `feature/US-001-auth-token-refresh`)
- `[base]`: Base branch to create from (default: `develop`)
- `--issue <iid>`: GitLab issue number. Required by default. Creates `.worktrees/<agent>-<iid>/`
- `--no-issue`: Bypass issue requirement. Falls back to legacy `.worktrees/<agent>/`
- `<worktree-id>`: Either `<agent>` (legacy) or `<agent>-<issue>` (issue-keyed)

**Examples:**

```bash
# Issue-keyed (parallel-safe):
scripts/oelite-gitlab.sh worktree-create daniel feature/US-042-auth --issue 42
scripts/oelite-gitlab.sh worktree-create sophia feature/US-015-checkout develop --issue 15
scripts/oelite-gitlab.sh worktree-remove daniel-42

# Legacy mode (no issue ticket):
scripts/oelite-gitlab.sh worktree-create marcus feature/spike --no-issue

# Scope management:
scripts/oelite-gitlab.sh oe-scope daniel-42
scripts/oelite-gitlab.sh oe-scope daniel-42 --task-type backend-impl --desc "JWT refresh"
scripts/oelite-gitlab.sh sync daniel-42
scripts/oelite-gitlab.sh worktree-list
```

### 9.4 Sync & Merge Operations

| Command | Description |
|---------|-------------|
| `scripts/oelite-gitlab.sh worktree-list` | List all active worktrees in the current repo |
| `scripts/oelite-gitlab.sh worktree-remove <agent>` | Remove an agent's worktree after MR merged |
| `scripts/oelite-gitlab.sh sync <agent>` | Rebase agent's feature branch on latest origin/develop |
| `scripts/oelite-gitlab.sh status` | Show overall worktree status |

**Examples:**

```bash
scripts/oelite-gitlab.sh worktree-sync                # Sync develop (safe — no checkout)
scripts/oelite-gitlab.sh sync daniel                   # Rebase agent branch
scripts/oelite-gitlab.sh status                        # Check status
scripts/oelite-gitlab.sh worktree-remove daniel-42     # Cleanup after MR merged
```

### 9.5 GitLab Operations (Agent + Human)

GitLab operations are available to both agents and humans. **Agents perform their own MR workflow** — push branches, create MRs, respond to review comments:

| Command | Description | Who Uses |
|---------|-------------|----------|
| `scripts/oelite-gitlab.sh issues <project>` | Fetch open issues | Emma (planning) |
| `scripts/oelite-gitlab.sh issue-create <project> <agent> <title> [description]` | Create a new issue | Emma or any agent |
| `scripts/oelite-gitlab.sh issue-assign <project> <iid> <agent>` | Assign issue to agent | Emma |
| `scripts/oelite-gitlab.sh issue-comment <project> <iid> <agent> <message>` | Comment on an issue as agent | Any agent |
| `scripts/oelite-gitlab.sh issue-status <project> <iid> <agent> <opened|closed>` | Open or close an issue | Emma |
| `scripts/oelite-gitlab.sh mr-create <project> <agent> <source> <target> <title> [desc]` | Create MR | Implementing agent |
| `scripts/oelite-gitlab.sh mr-list <project>` | List open MRs | Anyone |
| `scripts/oelite-gitlab.sh mr-comment <project> <iid> <agent> <message>` | Comment on an MR | Reviewer |
| `scripts/oelite-gitlab.sh mr-approve <project> <iid> <agent>` | Approve an MR | Assigned reviewer |
| `scripts/oelite-gitlab.sh mr-status <project> <iid>` | Check MR merge status (open/merged/closed/cannot_merge) | Reviewer or Emma — merge verification |
| `scripts/oelite-gitlab.sh issue-audit <project>` | List issues still open whose linked MRs are merged | Isabella or Emma — post-merge audit |
| `scripts/oelite-gitlab.sh mr-check-eligible <project>` | List MRs meeting auto-approval criteria | Emma or reviewer |
| `scripts/oelite-gitlab.sh mr-auto-approve <project>` | Auto-approve all eligible MRs | Emma or reviewer |

---

## 10. MR Auto-Approval (Enhanced Workflow)

MRs created by agents that have completed their full review chain can be auto-approved to eliminate the manual bottleneck where reviewers must manually check GitLab for ready MRs. This is a **supplement** to manual review — it accelerates MRs that are already eligible, not a replacement for review.

### 10.1 Eligibility Criteria

An MR is eligible for auto-approval when **ALL** of the following conditions are met:

| # | Criterion | Check Method |
|---|-----------|-------------|
| 1 | **CI Pipeline Passed** | All pipeline stages are green (`merge_status == "can_be_merged"`) |
| 2 | **No Requested Changes** | No reviewer has requested changes on the MR |
| 3 | **Implementer Verification Complete** | The implementing agent's verification is complete (build + tests pass) |
| 4 | **No Scope Conflicts** | No other open MR overlaps with the same directory scope (Emma's directory ownership) |
| 5 | **Review Window Passed** | MR has been open for at least **10 minutes** (allows for human observation) |

### 10.2 Auto-Approval Workflow

```bash
# 1. Check which MRs are eligible for auto-approval
scripts/oelite-gitlab.sh mr-check-eligible oelite/helios/core

# 2. Review the eligible MRs (shown with eligibility details)
# If satisfied, approve all eligible:
scripts/oelite-gitlab.sh mr-auto-approve oelite/helios/core
```

### 10.3 Auto-Approval Rules

- **Auto-approval appears under the agent who runs the command** (not the implementing agent)
- **Only one agent runs auto-approve per project at a time** — Emma coordinates who runs it (typically the reviewer whose turn it is: Grace for backend, Felix for frontend, Marcus for architecture)
- **Auto-approved MRs are automatically merged by GitLab** and the source branch is auto-deleted (no manual steps needed)
- **If any criterion fails**, the MR is listed as ineligible with the reason, and the reviewer must manually review it

### 10.4 When Auto-Approval Does NOT Apply

| Scenario | Action |
|----------|--------|
| MR touches security-sensitive code (auth, crypto, keys) | MUST be manually reviewed by Maya |
| MR changes architecture-critical files (Program.cs, BaseEntity, shared interfaces) | MUST be manually reviewed by Marcus |
| MR is marked with label `requires-manual-review` | MUST be manually reviewed by the assigned reviewer |
| MR has conflicts unresolved | NOT eligible — resolve conflicts first |
| MR is a WIP (title starts with `WIP:`) | NOT eligible — wait for final version |

### 10.5 Integration with Review Chain

Auto-approval supplements the existing review chain defined in `AGENTS.md`:

```
Agent completes work → Push branch → MR created → CI passes → Reviewer approves
                                                                    ↓
                                                          Auto-merge + branch delete (GitLab)
                                                                    ↓
                                                          Agent syncs local develop
                                               ↓ (if not eligible)
                                       Manual review by assigned reviewer
                                                ↓ (if changes requested)
                                        Agent fixes → pushes → re-review
```

This reduces the manual overhead on reviewers (Grace, Felix, Emma) while maintaining the quality gates of the review chain. Reviewers focus their manual attention on MRs that need human judgment (security, architecture, complex logic), while standard MRs flow through auto-approval and auto-merge.

---

## 11. Agent Session Protocol (MR-Centric Model)

Every agent session follows this sequence. No exceptions.

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

### Step 3: Sync Main `develop` with Remote (Start of Task)

```bash
scripts/oelite-gitlab.sh worktree-sync
```

**This is the first critical sync point.** Updates local `develop` from `origin/develop` WITHOUT checking it out — avoids the footgun of switching to develop and then forgetting to switch back. Pre-commit hook will block commits on develop anyway.

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

All file edits, builds, and tests happen inside the worktree directory. The worktree is a full checkout of the repo on the feature branch. Other agents and human developers may push to `origin/develop` during this time — the worktree is unaffected.

### Step 7: Push Feature Branch

```bash
git push origin <branch>
```

Push commits to the remote feature branch to back up work and enable MR creation.

### Step 8: Create Merge Request

```bash
scripts/oelite-gitlab.sh mr-create <project> <agent> <branch> develop "<title>" "[description]"
```

Create an MR targeting `develop`. Include a descriptive title and optional description.

### Step 9: Respond to Review

Wait for reviewer feedback. If changes are requested:
1. Make fixes in worktree
2. Commit and push: `git push origin <branch>`
3. Repeat review loop

### Step 10: After MR Approved & Merged

When the MR is approved and CI passes:
- GitLab auto-merges the MR into `develop`
- GitLab auto-deletes the source feature branch
- Agent receives notification

```bash
# Clean up worktree (branch already deleted remotely)
scripts/oelite-gitlab.sh worktree-remove <agent>

# Sync local develop for next task (safe — no checkout)
scripts/oelite-gitlab.sh worktree-sync
```

---

## 12. Security Rules

### 12.1 PAT Storage

- PATs are stored in **macOS Keychain** only. Never in files. Never committed.
- Each PAT is stored as a generic password with **service name `oelite-gitlab-<agent>`** and **account `oelite`**.
- The bootstrap script reads from Keychain at runtime.

**CRITICAL: Correct Keychain Service Name Format**

The service name MUST follow this exact pattern:
```
oelite-gitlab-<agent-name>
```

**Correct examples:**
```bash
# ✅ CORRECT - Service name format: oelite-gitlab-<agent>
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
security add-generic-password -s "oelite-gitlab-emma" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
security add-generic-password -s "oelite-gitlab-sophia" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

**WRONG examples (will cause 401 errors):**
```bash
# ❌ WRONG - Using "GitLab-PAT" as service name (does NOT match script expectation)
security add-generic-password -s "GitLab-PAT" -a "daniel.phanes" -w "glpat-xxxxxxxxxxxx" -U

# ❌ WRONG - Using email as account instead of "oelite"
security add-generic-password -s "oelite-gitlab-daniel" -a "daniel.phanes" -w "glpat-xxxxxxxxxxxx" -U

# ❌ WRONG - Using personal name as service
security add-generic-password -s "MyGitLab" -a "daniel" -w "glpat-xxxxxxxxxxxx" -U
```

**Retrieving a PAT (for verification only):**
```bash
# ✅ CORRECT - Matches the service name format used when adding
security find-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w
```

**Adding a PAT to Keychain:**

```bash
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

### 12.2 Environment Files

- `.env` files are in `.gitignore`. Never commit them.
- The `scripts/oelite-gitlab-env.sh` script does not create `.env` files. It exports variables into the current shell session only.

### 12.3 PAT Hygiene

- Each agent uses **their own PAT**. No sharing PATs between agents.
- Rotate PATs periodically (recommended: every 90 days).
- If a PAT is compromised, revoke it immediately in GitLab (User Settings > Access Tokens) and remove it from Keychain:

```bash
security delete-generic-password -s "oelite-gitlab-<agent>" -a "oelite"
```

### 12.4 No Secrets in Commits

- Never commit PATs, API keys, passwords, or connection strings.
- Use environment variables or Keychain references.
- If a secret is accidentally committed, revoke it immediately and force-push to remove it from history.

### 12.5 Troubleshooting 401 Authentication Errors

If you see `401 Unauthorized` errors from GitLab API calls:

**Step 1: Verify PAT exists in Keychain**
```bash
# Check if PAT is stored (replace 'daniel' with your agent name)
security find-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w

# If this returns nothing, the PAT is missing from Keychain
```

**Step 2: Verify PAT is valid**
```bash
# Test the PAT against GitLab API
source scripts/oelite-gitlab-env.sh
curl -s --header "PRIVATE-TOKEN: $OELITE_PAT_DANIEL" "https://code.phanes.ltd/api/v4/user"

# If this returns user info, PAT is valid. If 401, the PAT is expired/revoked.
```

**Step 3: Re-add PAT to Keychain (if missing or invalid)**
```bash
# Remove old PAT (if exists)
security delete-generic-password -s "oelite-gitlab-daniel" -a "oelite"

# Add new PAT (replace with actual token)
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

**Common causes of 401 errors:**
- ❌ PAT stored with wrong service name (e.g., `GitLab-PAT` instead of `oelite-gitlab-daniel`)
- ❌ PAT stored with wrong account (e.g., `daniel.phanes` instead of `oelite`)
- ❌ PAT expired or revoked in GitLab
- ❌ PAT doesn't have required scopes (api, read_user, read_api)

**Step 4: Run setup to verify all PATs**
```bash
scripts/oelite-gitlab.sh setup
```

This will show which agents have valid PATs and which are failing.

---

### 12.6 Troubleshooting 404 Project Not Found

If you see `404 Project Not Found` from GitLab API calls:

**Important:** GitLab returns `404` (not `401` or `403`) when a project is private and the PAT's user cannot access it. This is intentional — it prevents leaking which projects exist. Therefore, **404 usually means an access or token problem**, not a wrong URL.

**Step 1: Verify the PAT is valid**
```bash
source scripts/oelite-gitlab-env.sh
# This now validates each PAT against /api/v4/user. Look for [FAIL] lines.
```

If a PAT is invalid/expired:
```bash
# Remove old PAT
security delete-generic-password -s "oelite-gitlab-daniel" -a "oelite"

# Add new PAT
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

**Step 2: Verify the project namespace**
The full project path must match GitLab's `path_with_namespace`:
```text
https://code.phanes.ltd/oelite/<family>/<repo>
                      ^^^^^^ full top-level group
```

Examples:
- ✅ `oelite/uranus/origin-auth`
- ✅ `oelite/helios/core`
- ❌ `uranus/origin-auth` (missing top group)
- ❌ `oelite%2Furanus%2Forigin-auth` (already URL-encoded — only encode slashes when building API URLs)

**Step 3: Verify project membership**
The agent user must be a member of the project or inherit access via the `oelite/<family>` group. Check in GitLab:
- Project Settings > Members
- Group `oelite/<family>` > Members

**Step 4: Run setup to verify all PATs and project access**
```bash
scripts/oelite-gitlab.sh setup
scripts/oelite-gitlab.sh issues oelite/uranus/origin-auth
```

**Common causes of 404 errors:**
- ❌ PAT in Keychain is stale, expired, or revoked (most common)
- ❌ Agent user is not a member of the project/group
- ❌ Project path is missing the `oelite/` top-level group
- ❌ Project was moved/renamed in GitLab

---

### 12.7 Using the GitLab CLI Tool

**ALWAYS use the provided scripts** instead of manual curl commands:

```bash
# ✅ CORRECT - Use the official tool (project path = oelite/<family>/<repo>)
scripts/oelite-gitlab.sh mr-list oelite/uranus/origin-auth
scripts/oelite-gitlab.sh issues oelite/helios/core --assignee daniel
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth --issue 42

# ❌ WRONG - Manual curl commands with incorrect PAT retrieval
PAT=$(security find-generic-password -s GitLab-PAT -a daniel.phanes -w)  # Wrong service name!
curl --header "PRIVATE-TOKEN: $PAT" ...  # Will fail with 401/404
```

The scripts handle authentication and URL encoding correctly. If you need to query GitLab API directly, always source the env file first and use the **full namespace**:

```bash
# ✅ CORRECT - Source env file to load PATs
source scripts/oelite-gitlab-env.sh

# Use project ID (numeric) or URL-encoded path
curl --header "PRIVATE-TOKEN: $OELITE_PAT_DANIEL" \
  "https://code.phanes.ltd/api/v4/projects/oelite%2Furanus%2Forigin-auth/issues?per_page=1"
```

---

## 13. Conflict Resolution

### 13.1 Prevention

Directory-level ownership prevents most conflicts. Emma assigns non-overlapping directory scopes per task. Agents stay within their scope.

### 13.2 Shared File Serialization

Shared files (Program.cs, docker-compose, shared interfaces, AGENTS.md, etc.) are gated. Only one agent modifies a shared file at a time. Emma coordinates the order.

### 13.3 Conflict Resolution During Rebase

If conflicts arise when rebasing on `origin/develop`:

1. The agent resolves the conflicts in their worktree.
2. The agent runs tests after resolving conflicts.
3. The agent continues the rebase and force-pushes.

```bash
# Resolve conflicts in the worktree
# Edit conflicted files, then:
git add <resolved-files>
git rebase --continue
git push origin <branch> --force-with-lease
```

### 13.4 Two Agents Need the Same File

If two agents need to modify the same file:

1. Emma decides who goes first based on task priority and dependency order.
2. The first agent completes their MR and it merges.
3. The second agent rebases on the updated `origin/develop` and incorporates the first agent's changes.

### 13.5 Escalation

If agents can't resolve a conflict independently, Emma mediates. For architectural conflicts, Marcus adjudicates.

---

## 14. Pre-MR Checklist

Before creating an MR, the agent **MUST** verify every item below. No MR should be created with unchecked items.

### Pre-MR Verification

- [ ] Local develop synced: `scripts/oelite-gitlab.sh worktree-sync`
- [ ] Feature branch rebased on latest `origin/develop` (resolve conflicts if any)
- [ ] Build passes in worktree (`dotnet build` / `npm run build` / `ng build`)
- [ ] Tests pass (unit tests at minimum; integration tests if applicable)
- [ ] No placeholder/mock/TODO data in changed files
- [ ] Code follows OElite coding standards (`coding-standards/`)
- [ ] Directory scope respected (no changes outside assigned scope)
- [ ] Commit messages follow convention (see Section 13)
- [ ] No secrets, PATs, or credentials in committed files
- [ ] No `as any`, `@ts-ignore`, or type-error suppression (frontend)
- [ ] No raw `MongoDB.Driver`, `BsonDocument`, or manual DI (backend)
- [ ] Health endpoint verified if service is runnable

### Post-MR Actions

- [ ] MR created targeting `develop` with descriptive title
- [ ] MR description references the linked issue (`Closes #<issue-iid>`)
- [ ] Reviewer assigned based on change type (Grace for backend, Felix for frontend, Maya for security, Marcus for architecture)
- [ ] Reviewer notified via GitLab
- [ ] After approval + CI green: MR auto-merges (or manual merge if auto-merge disabled)
- [ ] **Merge verified**: `mr-status <project> <mr-iid>` confirms `merged` state
- [ ] **Issue labeled `Done`** (after Isabella business validation)
- [ ] **Issue closed in GitLab**: `issue-status <project> <iid> emma closed` — in same session as merge verification
- [ ] Worktree removed after MR merged: `scripts/oelite-gitlab.sh worktree-remove <agent>`
- [ ] Local develop synced: `scripts/oelite-gitlab.sh worktree-sync`
- [ ] **Post-merge audit**: `issue-audit <project>` run to confirm no orphaned open issues

---

## 15. Commit Message Convention

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

## 16. Edge Cases & FAQ

### Q: What if my worktree gets into a broken state?

Remove it and recreate:

```bash
scripts/oelite-gitlab.sh worktree-remove <agent>
scripts/oelite-gitlab.sh worktree-create <agent> <branch>
```

Your commits are still on the remote branch (if you pushed). If you didn't push, the work is lost. **Push frequently.**

### Q: What if two agents accidentally modify the same file?

The second agent's MR will show conflicts during rebase. Resolve them, push, and proceed. Going forward, Emma should assign non-overlapping scopes.

### Q: Can a human developer work on the same branch as an agent?

No. If a human needs to work on the same feature, they should coordinate with the agent through GitLab comments. The human can create a review branch or work in a separate worktree.

### Q: What if `develop` has moved significantly since I created my branch?

Run `scripts/oelite-gitlab.sh sync <agent>` to rebase. If there are many conflicts, consider whether the feature should be split into smaller MRs.

### Q: Can I have multiple worktrees in different repos?

Yes. An agent can have one worktree per repo. For example, Daniel can have a worktree in `helios/core/` and another in `uranus/origin-auth/` simultaneously.

### Q: What happens if an MR is rejected (changes requested)?

The implementing agent addresses the feedback in the worktree, pushes new commits, and the reviewer re-evaluates. After 2 failed review attempts, the issue escalates to Marcus (architecture) or Emma (requirements).

### Q: How do I handle a worktree after my MR is merged?

```bash
# Remove worktree (branch already auto-deleted by GitLab)
scripts/oelite-gitlab.sh worktree-remove <agent>

# Sync local develop for next task (safe — no checkout)
scripts/oelite-gitlab.sh worktree-sync
```

### Q: What if my MR has conflicts with `develop`?

GitLab will show "Cannot be merged" status. Rebase your branch:

```bash
scripts/oelite-gitlab.sh sync <agent>
# Resolve conflicts if any, then:
git push origin <branch> --force-with-lease
```

GitLab will re-evaluate mergeability automatically.

---

## 17. Standards Maintenance

### Update Process

1. Changes to this standard go through the same MR process as code changes.
2. Emma approves workflow changes. Marcus approves architectural impacts.
3. Update this file and sync to `uranus/arc-agents/standards/` if it exists there.

### Version History

| Date | Update |
|------|--------|
| Jun 2026 | Initial standard. Worktree protocol, branch strategy, GitLab integration, CLI tool reference. |
| Jun 20 2026 | **Major Update**: Replaced MR-centric remote workflow with **Late Sync & Local Merge Model**. Agents now merge directly into local `develop` instead of pushing/remotely creating MRs. Human developers act as "Publishers" for remote `develop`. Updated Sections 2.4, 3.4, 4.3, 4.4, 4.5, 5.5, 7.4, 8, 11 to reflect agentic AI local-first workflow. |
| Jun 21 2026 | **Workflow Enhancement**: Added mandatory pre-task sync (hard gate) at §1.5, periodic sync responsibilities at §1.6, and stale `develop` detection via `status`. Added MR auto-approval eligibility criteria at §10 and CLI commands (`mr-check-eligible`, `mr-auto-approve`) at §9.5. Agents MUST sync `git pull origin develop` before every task. Reviewers can auto-approve eligible MRs via CLI. |
| Jun 22 2026 | **Major Update**: Reverted to **MR-Centric Model**. Local Merge Model proved inconsistent for agentic teams — agents frequently skipped steps or performed them out of order, leading to stale local `develop` branches and unreviewed code accumulation. New workflow: agents push feature branches → create MRs → reviewers approve → GitLab auto-merges + auto-deletes branch. All code enters `develop` through reviewed MRs. Review is a gate, not an afterthought. |
| Jun 29 2026 | **SCRUM/Dev Workflow Enhancement**: Added explicit GitLab issue lifecycle protocol at §8. Defined mandatory status labels (`To Do`, `In Progress`, `PR Review`, `Ready to Merge`, `Done`, `Blocked`), status transition rules, role responsibilities, SCRUM integration, issue comment templates, and definition-of-done checklist. Added `issue-status` CLI command. Emma owns issue assignment and closure; assignees update labels during workflow; reviewers set `Ready to Merge`; Isabella validates before `Done`. |
| Jul 21 2026 | **Issue-First & Closure Enforcement**: Added §1.7 Issue-First hard gate — no work begins without a GitLab issue with full elaboration. Added §8.2.1 Merge Verification (mandatory `mr-status` check before labeling `Done`). Added §8.2.2 Issue Closure Enforcement (`issue-status closed` in same session as merge verification). Added §8.2.3 Post-Merge Issue Audit (`issue-audit` CLI). Updated §8.3 role responsibilities (Emma verifies merge + closes; Reviewer verifies merge; Isabella runs audit). Updated §8.4 Definition of Done with closure + audit checkboxes. Updated §14 Post-MR checklist with merge verification + closure steps. Added `mr-status` and `issue-audit` CLI commands. |

---

## Related Documentation

- [AGENTS.md](../../AGENTS.md) - Team roles, workflow chains, and collaboration protocol
- [coding-standards/README.md](../README.md) - Master index of all coding standards
- [rulespec_checklist.md](../rulespec_checklist.md) - AI agent project bootstrapping guide
