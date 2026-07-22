# OElite Platform — Agent Navigator

> **Loaded every request. Read completely.**
> **Source of Truth**: `coding-standards/` — all standards, templates, workflows live there.
> **Per-Repo Context**: `<repo>/AGENTS.md` + `<repo>/.ai/standards/`

---

## 🚨 UNIVERSAL BOOTSTRAP (Every Agent, Every Time)

**Before ANY tool call, complete these 4 steps IN ORDER:**

### STEP 0: SELECT TARGET REPOSITORY (Hard Gate)
**You MUST be inside a sub-repository (e.g., `helios/core/`, `uranus/origin-auth/`, `jupiter/ec-nx-01/`) before running bootstrap.**
The root `oelite/` folder is NOT a git repository — it is a monorepo container.

```bash
# Navigate to your assigned repo FIRST (check ACTIVE REPOS table below)
cd <target-repo-path>   # e.g., cd helios/core

# Verify you're in a git repo
git rev-parse --show-toplevel
# Must output your repo path, NOT "fatal: not a git repository"
```

### STEP 0.5: VERIFY ISSUE TICKET EXISTS (Hard Gate — Issue-First)
**No work begins until a GitLab issue ticket exists with full task elaboration.**

```bash
# Verify the issue exists in GitLab before proceeding
# Replace <project> with GitLab path (e.g., oelite/uranus/origin-auth)
# Replace <iid> with the issue number
../../coding-standards/scripts/oelite-gitlab.sh issues <project>
```

**The issue MUST meet Definition of Ready** (see `TASK-TEMPLATES.md` §1):
- Title with issue reference (US-XXX, BUG-XXX, TASK-XXX)
- Acceptance criteria in GIVEN/WHEN/THEN format
- Owner assigned
- Priority labeled
- Dependencies identified (not blocking)

**If no issue exists → STOP. Create one via `issue-create` using `ISSUE-MR-TEMPLATES.md` before any further work.**
**If the issue exists but lacks acceptance criteria or owner → STOP. Ask Emma to elaborate before proceeding.**

### STEP 1: DECLARE IDENTITY
```markdown
MY_ROLE = "<emma|marcus|daniel|sophia|jonathan|olivia|ethan|maya|victor|grace|felix|isabella>"
MY_TASK_TYPE = "<planning|backend-impl|backend-review|frontend-impl|frontend-review|testing|infrastructure|security|documentation|architecture>"
MY_SESSION_TYPE = "<primary|subagent|continued>"
```

### STEP 2: SYNC & WORKTREE (Hard Gate)
```bash
# From INSIDE the target repo (after Step 0 cd):
source ../../coding-standards/scripts/oelite-gitlab-env.sh
git checkout develop && git pull origin develop
../../coding-standards/scripts/oelite-gitlab.sh worktree-create "$MY_ROLE" "feature/<branch>"
# Verify owner DNA (see coding-standards/5_git_workflow_standards/WORKTREE-OWNER-DNA.md)
git -C ".worktrees/$MY_ROLE" config user.email  # Must be "$MY_ROLE@phanes.ltd"
```

### STEP 2.25: VERIFY & UPDATE SCOPE ANCHOR (Hard Gate — Compaction Resilience)
**The `.oe-scope` file is your disk-based context anchor. It survives context compaction.**

`worktree-create` auto-generates `.oe-scope` in your worktree. After issue assignment, update it with task details:

```bash
# Update scope with task details (do this AFTER Step 0.5 issue verification)
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE" \
  --task-type "$MY_TASK_TYPE" \
  --issue "<iid>" \
  --desc "<brief task description>"
```

**After context compaction (or at any point you're unsure where you are):**
```bash
# Read the scope file to restore your working context
cat .oe-scope
# OR:
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE"
```

**Pre-tool directory guard (run before ANY file edit if unsure of location):**
```bash
# If this outputs anything, you are in the WRONG directory — STOP
test -f .oe-scope || { echo "SCOPE LOST: No .oe-scope found. You are not in a worktree. cd to the correct worktree first."; }
```

**If `.oe-scope` is missing or you're not in a worktree:**
1. `cd` back to your target repo root
2. `cd .worktrees/<your-role>/`
3. Verify `.oe-scope` exists
4. If worktree doesn't exist, re-run Step 2 (worktree-create)

### STEP 2.25: VERIFY & UPDATE SCOPE ANCHOR (Hard Gate — Compaction Resilience)
**The `.oe-scope` file is your disk-based context anchor. It survives context compaction.**

`worktree-create` auto-generates `.oe-scope` in your worktree. After issue assignment, update it with task details:

```bash
# Update scope with task details (do this AFTER Step 0.5 issue verification)
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE" \
  --task-type "$MY_TASK_TYPE" \
  --issue "<iid>" \
  --desc "<brief task description>"
```

**After context compaction (or at any point you're unsure where you are):**
```bash
# Read the scope file to restore your working context
cat .oe-scope
# OR:
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE"
```

**Pre-tool directory guard (run before ANY file edit if unsure of location):**
```bash
# If this outputs anything, you are in the WRONG directory — STOP
test -f .oe-scope || { echo "SCOPE LOST: No .oe-scope found. You are not in a worktree. cd to the correct worktree first."; }
```

**If `.oe-scope` is missing or you're not in a worktree:**
1. `cd` back to your target repo root
2. `cd .worktrees/<your-role>/`
3. Verify `.oe-scope` exists
4. If worktree doesn't exist, re-run Step 2 (worktree-create)

### STEP 3: LOAD REQUIRED CONTEXT (Read via `read` tool)
Read in this exact order:

1. `coding-standards/agents/core/principles.md` — universal foundation
2. `coding-standards/agents/workflow/workflow.md` — detailed handoff chains, GitLab workflow, owner DNA
3. `coding-standards/agents/roles/{MY_ROLE}.md` — your role delta
4. `coding-standards/agents/packs/{MY_TASK_TYPE}.md` — task-specific standards
5. `<target-repo>/AGENTS.md` — repo orientation
6. `<target-repo>/.ai/standards/*.md` — repo-specific overrides (if they exist)

### STEP 4: VERIFY & OUTPUT BOOTSTRAP COMPLETE
**After reading all required files, output EXACTLY:**

```
=== BOOTSTRAP COMPLETE ===
ROLE: <role>
SESSION: <primary|subagent|continued>
TASK: <task-type>
ISSUE: #<iid> — <issue title> (verified exists, has AC + owner)
LOADED:
  - coding-standards/agents/core/principles.md
  - coding-standards/agents/workflow/workflow.md
  - coding-standards/agents/roles/<role>.md
  - coding-standards/agents/packs/<task-type>.md
  - <target-repo>/AGENTS.md
  - <target-repo>/.ai/standards/*.md (if applicable)
WORKTREE: .worktrees/<role>/feature/<branch> (verified via git config user.email)
SCOPE: .oe-scope verified and updated (task-type, issue, description)
SYNC: develop pulled from origin
IDENTITY: <role>@phanes.ltd (confirmed per WORKTREE-OWNER-DNA.md)
READY: true
===
```

**Only after this output may you execute ANY other tool.**

---

## 📁 CODING STANDARDS (Read via tools when needed)

| Domain | Path | Key Files |
|--------|------|-----------|
| .NET / Backend | `coding-standards/1_dotNet_coding_standards/` | 01-15 |
| Frontend (Next.js) | `coding-standards/4_react_nextjs_coding_standards/` | 12-NEXTJS-CODING-STANDARDS.md |
| Frontend (Angular) | `coding-standards/3_angular_coding_standards/` | 11-ANGULAR-CODING-STANDARDS.md |
| General Web | `coding-standards/2_general_web_coding_standards/` | README.md |
| Git Workflow | `coding-standards/5_git_workflow_standards/` | GIT-WORKFLOW-STANDARDS.md, TASK-TEMPLATES.md, ISSUE-MR-TEMPLATES.md, PROHIBITED-PATTERNS.md, WORKTREE-OWNER-DNA.md |
| Documentation | `coding-standards/6_documentation_standards/` | DOC-STANDARDS.md |
| Planning | `coding-standards/0_project_planning_standards/` | 6 templates |

---

## 🎭 ROLE FILES

`coding-standards/agents/roles/{role}.md` — one per role:

| Role | File | Primary Domain |
|------|------|----------------|
| Emma | `roles/emma.md` | Product & Delivery Coordination |
| Marcus | `roles/marcus.md` | Principal Architecture |
| Daniel | `roles/daniel.md` | Backend Implementation |
| Sophia | `roles/sophia.md` | Frontend Implementation |
| Jonathan | `roles/jonathan.md` | UX Design |
| Olivia | `roles/olivia.md` | QA & Test Automation |
| Ethan | `roles/ethan.md` | DevOps & Reliability |
| Maya | `roles/maya.md` | Security |
| Victor | `roles/victor.md` | Data & Performance |
| Grace | `roles/grace.md` | Backend Code Review |
| Felix | `roles/felix.md` | Frontend Code Review |
| Isabella | `roles/isabella.md` | Business Analysis & Documentation |

---

## 📦 TASK PACKS

`coding-standards/agents/packs/{task-type}.md`:

| Task Type | Pack File |
|-----------|-----------|
| Planning | `packs/planning.md` |
| Backend Implementation | `packs/backend-impl.md` |
| Backend Review | `packs/backend-review.md` |
| Frontend Implementation | `packs/frontend-impl.md` |
| Frontend Review | `packs/frontend-review.md` |
| Testing | `packs/testing.md` |
| Infrastructure | `packs/infrastructure.md` |
| Security | `packs/security.md` |
| Documentation | `packs/documentation.md` |
| Architecture | `packs/architecture.md` |

---

## 🤖 SUBAGENT DELEGATION RULE

When spawning a subagent via `task()`, include in the prompt:

```markdown
# SUBAGENT BOOTSTRAP REQUIREMENTS
YOUR_ROLE: <role-name>
YOUR_TASK_TYPE: <task-type>
YOUR_SESSION_TYPE: subagent

# SCOPE CONTEXT (MANDATORY — prevents worktree drift after compaction)
WORKING_DIR: <full path to worktree, e.g., /oelite/helios/core/.worktrees/daniel>
GIT_ROOT: <verified via git rev-parse --show-toplevel>
ISSUE: #<iid> — <issue title>
TASK: <brief description>
FORBIDDEN: Creating files outside the git repo root above.

You MUST complete the Universal Agent Bootstrap (Steps 1-4) before ANY work.
Your first output MUST be the bootstrap verification block (including SCOPE verified).
```

---

## 🔄 CONTINUED SESSION RULE

When continuing a session via `session_id` in `task()`:

```markdown
# CONTINUED SESSION BOOTSTRAP
YOUR_ROLE: <same-as-original>
YOUR_TASK_TYPE: <same-as-original>
YOUR_SESSION_TYPE: continued

Re-run Steps 1-4 (abbreviated: confirm role/task, re-read role file if context lost, verify worktree).
MANDATORY: Read .oe-scope in your worktree to restore full task context after compaction.
```

---

## 🛡️ HARD GATES (Non-Negotiable)

- ✅ **Issue-First**: No work begins (no worktree, no code, no exploration) until a GitLab issue ticket exists with full task elaboration (goals, acceptance criteria, scope, dependencies, assigned owner) per `ISSUE-MR-TEMPLATES.md`. Bootstrap refuses to proceed without an issue IID.
- ✅ Worktree identity via `scripts/oelite-gitlab.sh worktree-create`
- ✅ `develop` sync before worktree creation
- ✅ Zero mock data
- ✅ Zero mock persistence — real Docker infra for tests
- ✅ No `as any`, `@ts-ignore`, `@ts-expect-error`
- ✅ Build + test + health check before "done"
- ✅ **Merge verification**: After reviewer approves, the reviewer (or Emma) MUST verify the MR status is `merged` in GitLab (via `mr-status` CLI) before transitioning the linked issue to `Done`
- ✅ **Issue closure enforcement**: Every merged MR's linked issue MUST be closed in GitLab via `issue-status closed` — not just labeled `Done`. Closure happens in the same session as merge verification.
- ✅ **Post-merge issue audit**: Isabella (or designated reviewer) MUST run `issue-audit <project>` periodically to catch any issues left open after their linked MRs were merged.
- ✅ Autonomous handoff to next role per workflow chain
- ✅ Bootstrap verification block as first output

---

## 🏷️ ACTIVE REPOS ONLY (Reference)

| Family | Repos |
|--------|-------|
| **Helios** | `core/`, `kortex/`, `oesterling/`, `compass/`, `k8s/` |
| **Jupiter** | `ec-std-01`, `ec-nx-01`, `occ`, `bizsmart`, `apex/`, `apps-ec-store`, `apps-biz-suite` |
| **Mercury** | `runners/Backplane`, `DataSync`, `LoadBalanceHealthCheckker`, `SubscriptionBilling` |
| **Uranus** | `origin-auth/`, `restme/`, `restme-dapper/`, `orion/`, `stella/`, `hermes/`, `lattice/`, `quantrix/`, `slate/`, `arc-cli/`, `arc-agents/` |
| **Venus** | `obelisk/`, `sip/`, `stela/` |

**Deprecated (do not touch)**: `pluto/`, `*-legacy`, `helios/sites`, `helios/app-config-server`, `jupiter/oes`, `jupiter/gemni-dev`, `jupiter/ec-std-03`, `mercury/runners/Legacy`, `mercury/workflows`, `uranus/restme-wildduck`, `venus/wildduck-*`, `venus/mail-quarantine`, `venus/runners`, `helios/kortex/web/kortex-dashboard-archived`

### GitLab Project Path Convention

The table above lists **local sub-repository folders** inside the monorepo container. In GitLab, every project lives under the top-level group `oelite/`:

| Local Folder | GitLab Project Path |
|--------------|---------------------|
| `helios/core/` | `oelite/helios/core` |
| `uranus/origin-auth/` | `oelite/uranus/origin-auth` |
| `jupiter/ec-nx-01/` | `oelite/jupiter/ec-nx-01` |
| `mercury/runners/Backplane/` | `oelite/mercury/runners/Backplane` |

Always pass the full GitLab project path (`oelite/<family>/<repo>`) to `scripts/oelite-gitlab.sh`.

### CLI Tool Reference

| Command | Purpose |
|---------|---------|
| `setup` | Verify all 12 agent PATs against GitLab |
| `issues <project>` | List open issues (GitLab path: `oelite/<family>/<repo>`) |
| `issue-create <project> <agent> <title> [desc]` | Create a new issue as agent |
| `issue-assign <project> <iid> <agent>` | Assign issue to agent |
| `issue-comment <project> <iid> <agent> <msg>` | Comment on issue as agent |
| `issue-status <project> <iid> <agent> <opened|closed>` | Open or close issue as agent |
| `worktree-create <agent> <branch> [base]` | Create worktree with agent identity |
| `worktree-list` | List active worktrees |
| `worktree-remove <agent>` | Remove worktree after MR merged |
| `mr-create <project> <agent> <src> <tgt> <title> [desc]` | Create MR as agent |
| `mr-list <project>` | List open MRs |
| `mr-comment <project> <iid> <agent> <msg>` | Comment on MR as agent |
| `mr-approve <project> <iid> <agent>` | Approve MR as agent |
| `mr-status <project> <iid>` | Check MR merge status (open/merged/closed/cannot_merge) — used for merge verification |
| `issue-audit <project>` | List issues still open whose linked MRs are merged — used for post-merge audit |
| `oe-scope <agent> [--task-type] [--issue] [--desc]` | Read/update per-worktree .oe-scope file (compaction-resilient context anchor) |
| `sync <agent>` | Rebase worktree on latest `origin/develop` |
| `status` | Show worktree status (ahead/behind `origin/develop`) |

---

## ⚠️ AGENT INVOCATION CONVENTION

When a request **names a role** (Emma, Marcus, Daniel, ...) **and** context matches their responsibility:
- **Auto-spawn that role as subagent** with `YOUR_ROLE` + `YOUR_TASK_TYPE` in prompt
- Human = business owner/approver, not workflow dispatcher
- Escalate to human only for: business decisions, material risk, budget/priority, 2×+ ambiguity

---

## 📚 STANDARDS AUTHORITY

1. `coding-standards/` — global source of truth
2. `<repo>/.ai/standards/*` — repo overrides (extend, never contradict)
3. `uranus/arc-agents/standards/` — mirror only (may drift)

---

*End of navigator. Full details in modular files loaded per bootstrap.*
