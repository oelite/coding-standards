# OElite Platform — Agent Navigator

> **Loaded every request. Read completely.**
> **Source of Truth**: `/coding-standards/` — all standards, templates, workflows live there.
> **Per-Repo Context**: `<repo>/AGENTS.md` + `<repo>/.ai/standards/`

---

## 🚨 UNIVERSAL BOOTSTRAP (Every Agent, Every Time)

**Before ANY tool call, complete these 4 steps IN ORDER:**

### STEP 1: DECLARE IDENTITY
```markdown
MY_ROLE = "<emma|marcus|daniel|sophia|jonathan|olivia|ethan|maya|victor|grace|felix|isabella>"
MY_TASK_TYPE = "<planning|backend-impl|backend-review|frontend-impl|frontend-review|testing|infrastructure|security|documentation|architecture>"
MY_SESSION_TYPE = "<primary|subagent|continued>"
```

### STEP 2: SYNC & WORKTREE (Hard Gate)
```bash
source coding-standards/scripts/oelite-gitlab-env.sh
git checkout develop && git pull origin develop
scripts/oelite-gitlab.sh worktree-create "$MY_ROLE" "feature/<branch>"
# Verify owner DNA (see coding-standards/5_git_workflow_standards/WORKTREE-OWNER-DNA.md)
git -C ".worktrees/$MY_ROLE" config user.email  # Must be "$MY_ROLE@phanes.ltd"
```

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
LOADED:
  - coding-standards/agents/core/principles.md
  - coding-standards/agents/workflow/workflow.md
  - coding-standards/agents/roles/<role>.md
  - coding-standards/agents/packs/<task-type>.md
  - <target-repo>/AGENTS.md
  - <target-repo>/.ai/standards/*.md (if applicable)
WORKTREE: .worktrees/<role>/feature/<branch> (verified via git config user.email)
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

You MUST complete the Universal Agent Bootstrap (Steps 1-4) before ANY work.
Your first output MUST be the bootstrap verification block.
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
```

---

## 🛡️ HARD GATES (Non-Negotiable)

- ✅ Worktree identity via `scripts/oelite-gitlab.sh worktree-create`
- ✅ `develop` sync before worktree creation
- ✅ Zero mock data
- ✅ Zero mock persistence — real Docker infra for tests
- ✅ No `as any`, `@ts-ignore`, `@ts-expect-error`
- ✅ Build + test + health check before "done"
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
