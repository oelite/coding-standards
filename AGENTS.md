# OElite Platform — Agent Navigator

**Loaded every request. Read completely.**
**Source of Truth**: `coding-standards/` — all standards, templates, workflows live there.
**Per-Repo Context**: `<repo>/AGENTS.md` (+ `<repo>/.ai/standards/` only if repo deviates from OElite patterns — see note below)

---

## 🚨 UNIVERSAL BOOTSTRAP (Every Agent, Every Time)

**Before ANY tool call, complete these 4 steps IN ORDER:**

### STEP 0: SELECT TARGET REPOSITORY (Hard Gate)
**You MUST be inside a sub-repository (e.g., `helios/core/`, `uranus/origin-auth/`, `jupiter/ec-nx-01/`) before running bootstrap.**
The root `oelite/` folder is NOT a git repository — it is a monorepo container.

> **⛔ MACHINE-ENFORCED:** A PreToolUse hook (`coding-standards/scripts/hooks/oelite-guard.sh`)
> blocks ALL of the following — for both Claude Code and OpenCode (via `coding-standards/scripts/opencode-plugin-oelite/`):
>
> | Gate | Blocks |
> |---|---|
> | **A. Root-write** | Write/Edit/Bash targeting paths under the oelite root but NOT inside a scoped git sub-repo |
> | **B. Worktree-presence** | Edits inside a scoped git repo that are NOT under `.worktrees/<agent>-<iid>/` |
> | **C. Protected-branch** | Edits in worktrees whose branch is `develop`, `main`, or `master` |
> | **D. Issue-IID** | (Advisory) When `.oe-scope` exists, the worktree's declared issue must match the branch's issue ref |
>
> The `OELITE_HUMAN=1` environment variable bypasses the guard for intentional human maintenance.
> `.claude/` and `.opencode/` are auto-allowed (IDE config writes).
>
> The guard is wired into **every active sub-repo** via per-repo `.claude/settings.json` files
> (run `coding-standards/scripts/hooks/install-ide-guards.sh --apply` to roll out to new repos),
> so the same rules fire regardless of which directory you launch your IDE from.
> See § HARD GATES → "Unified IDE guard" for the full policy.
>
```bash
# Navigate to your assigned repo FIRST (check ACTIVE REPOS table below)
cd <target-repo-path>   # e.g., cd helios/core

# Verify you're in a git repo
git rev-parse --show-toplevel
# Must output your repo path, NOT "fatal: not a git repository"
```

### STEP 0.5: VERIFY OR CREATE ISSUE TICKET (Hard Gate — Issue-First)
**No work begins until a GitLab issue ticket exists for this task with full task elaboration.**

**The agent MUST create the issue, not the human.** The human gave you a goal;
you owe them a properly-scoped, Definition-of-Ready issue ticket before any
exploration or code edits. Do not block the session by asking the human to
go create one themselves.

```bash
# 1. Search GitLab for an existing issue that already covers this task.
#    If one exists and meets Definition of Ready, reuse it.
../../coding-standards/scripts/oelite-gitlab.sh issues <project>

# 2. If no issue exists, AUTHOR IT YOURSELF using the templates, then create
#    it on GitLab via the CLI. Pick the template that matches the work:
#    - Feature → ISSUE-MR-TEMPLATES.md § Feature Issue
#    - Bug     → ISSUE-MR-TEMPLATES.md § Bug Issue
#    - Task    → ISSUE-MR-TEMPLATES.md § Task Issue
#    - Audit/post-implementation review → Task Issue with US-XXX ref
../../coding-standards/scripts/oelite-gitlab.sh issue-create \
  <project> <your-role> "<title>" "<description>"
# example:
# oelite-gitlab.sh issue-create oelite/uranus/origin-auth isabella \
#   "[US-042] Post-impl audit: full UI/API journey validation" \
#   "$(cat <<'EOF'
#   ## Goal
#   Retrospectively audit the origin-auth implementation ...
#
#   ## Acceptance Criteria (GIVEN/WHEN/THEN)
#   - GIVEN the auth UI pages ... WHEN a user signs in ... THEN ...
#   ...
#   EOF
#   )"
```

**The issue MUST meet Definition of Ready** (see `TASK-TEMPLATES.md` §1):
- Title with issue reference (US-XXX, BUG-XXX, TASK-XXX)
- Acceptance criteria in GIVEN/WHEN/THEN format
- Owner assigned
- Priority labeled
- Dependencies identified (not blocking)
- **Authorization clause** for creating child issues and fixing discovered defects
  in-scope (write it in the description if the parent is an audit/repair umbrella)

**If you find an existing issue that does NOT meet Definition of Ready → you
update it, you do not block the session on a human.** Add the missing AC,
assign yourself as owner, set priority, and proceed.

**⚠️ DO NOT create local issue files.** Issue tickets belong on GitLab server, not in:
- `.gitlab/issue_templates/` — **ONE-TIME REPO SETUP ONLY** (per `ISSUE-MR-TEMPLATES.md` §1)
- `.ai/` — reserved for `standards/` overrides only
- Any other local directory

See `PROHIBITED-PATTERNS.md` §7 for the full prohibition.

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
# Safe sync — updates local develop WITHOUT checking it out (avoids footgun)
../../coding-standards/scripts/oelite-gitlab.sh worktree-sync
../../coding-standards/scripts/oelite-gitlab.sh worktree-create "$MY_ROLE" "feature/<branch>" --issue "<iid>"
# Verify owner DNA — USE `git -C` (NOT `cd .worktrees/... && git ...`)
# See "⚠️ Claude Code permission pattern" below for why.
git -C ".worktrees/$MY_ROLE-<iid>" config user.email  # Must be "$MY_ROLE@phanes.ltd"
```

**⚠️ Claude Code permission pattern (use `git -C`, never `cd <dir> && git ...`).**
Claude Code prompts for approval on every `cd <new-dir> && git ...` compound command because a new
directory can host its own `.git/hooks/`. The pattern `Bash(git *)` in the allow-list does **not**
match `cd <dir> && git ...`. Use `git -C <dir> ...` (or `git --git-dir=<dir>/.git ...`) instead —
it matches `Bash(git -C *)` and skips the prompt. Same rule applies to any other version-control
or build tool you want to invoke against a worktree. The apex per-repo `.claude/settings.local.json`
is pre-seeded with worktree-scoped allow rules; add equivalents for your own repos.

**⚠️ CRITICAL: Never pipe the `source` command.**
- ✅ `source scripts/oelite-gitlab-env.sh` — correct
- ✅ `source scripts/oelite-gitlab-env.sh 2>/dev/null` — quiet mode
- ❌ `source scripts/oelite-gitlab-env.sh 2>&1 | tail -1` — **breaks: PATs are lost in subshell**
>
Piping `source` creates a subshell. All exported PATs evaporate. The script will detect this and abort.

**⚠️ Never chain `source` with `curl` in a compound command.**
- ❌ `source ...; curl ... $OELITE_PAT_X ...` — **triggers `simple_expansion` approval prompts and exposes the PAT to Claude Code's shell evaluator**
- ✅ Run `source` standalone (or skip it entirely — the `oelite-gitlab.sh` wrapper loads PATs internally from Keychain as needed)
- ✅ Use `oelite-gitlab.sh <subcommand> ...` for ALL GitLab operations — it handles PAT retrieval and never expands secrets in your command

**Note**: `--issue <iid>` is REQUIRED by default (Issue-First workflow). For work that genuinely does not require an issue ticket, use `--no-issue` (falls back to legacy `.worktrees/<agent>/` naming).

### STEP 2.25: VERIFY & UPDATE SCOPE ANCHOR (Hard Gate — Compaction Resilience)
**The `.oe-scope` file is your disk-based context anchor. It survives context compaction.**

`worktree-create` auto-generates `.oe-scope` in your worktree. After issue assignment, update it with task details:

```bash
# Update scope with task details (do this AFTER Step 0.5 issue verification)
# Use <worktree-id> = <role>-<iid> for issue-keyed worktrees, or just <role> for legacy
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE-<iid>" \
  --task-type "$MY_TASK_TYPE" \
  --desc "<brief task description>"
```

**After context compaction (or at any point you're unsure where you are):**
```bash
# Read the scope file to restore your working context
# IMPORTANT: .oe-scope is a per-worktree file. It only exists inside
# .worktrees/<agent>-<iid>/.oe-scope. If you're at the monorepo root or
# a repo root, you will NOT find it there — that's normal.
# cd to your worktree first, then read it:
cat .worktrees/<role>-<iid>/.oe-scope
# OR (from the repo root):
../../coding-standards/scripts/oelite-gitlab.sh oe-scope "$MY_ROLE-<iid>"
```

**Pre-tool directory guard (run before ANY file edit if unsure of location):**
```bash
# If this outputs anything, you are in the WRONG directory — STOP
# Navigate to the correct worktree first:
cd .worktrees/<role>-<iid>/
# Then verify:
test -f .oe-scope || { echo "SCOPE LOST: No .oe-scope found. You are not in a worktree. cd to the correct worktree first."; }
```

**If `.oe-scope` is missing or you're not in a worktree:**
1. `cd` back to your target repo root
2. `cd .worktrees/<your-role>-<iid>/` (or `.worktrees/<your-role>/` for legacy)
3. Verify `.oe-scope` exists
4. If worktree doesn't exist, re-run Step 2 (worktree-create)

### STEP 3: LOAD REQUIRED CONTEXT (Read via `read` tool)
Read in this exact order:

1. `coding-standards/agents/core/principles.md` — universal foundation
2. `coding-standards/agents/workflow/workflow.md` — detailed handoff chains, GitLab workflow, owner DNA
3. `coding-standards/agents/roles/{MY_ROLE}.md` — your role delta
4. `coding-standards/agents/packs/{MY_TASK_TYPE}.md` — task-specific standards
5. `<target-repo>/AGENTS.md` — repo orientation
6. `<target-repo>/.ai/standards/*.md` — repo-specific deviations (ONLY if present; reserved for repos that deviate from OElite patterns — currently `uranus/lattice`, `uranus/origin-auth`, `venus/sip`, `mercury/synapse`)

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
  - <target-repo>/.ai/standards/*.md (deviation-only; see STANDARDS AUTHORITY)
WORKTREE: .worktrees/<role>-<iid>/feature/<branch> (verified via git config user.email)
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
| UX Design | `packs/ux-design.md` |
| Testing | `packs/testing.md` |
| Infrastructure | `packs/infrastructure.md` |
| Security | `packs/security.md` |
| Documentation | `packs/documentation.md` |
| Architecture | `packs/architecture.md` |

---

## 🤖 SUBAGENT DELEGATION RULE

When a request names a specific role and the context matches their responsibility, you MAY spawn that role as a subagent using the `Agent` tool. Include in the prompt:

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

**Note**: Subagent spawning is optional. The primary workflow is a single-agent session that outputs a structured handoff for the next role. Use subagents only when the user explicitly requests multi-agent orchestration or names a specific role.

---

## 🔄 CONTINUED SESSION RULE

When continuing a session (e.g., resuming from a handoff or re-invoking a role after context compaction):

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
✅ **Unified IDE guard**: AI agents may create or modify files/folders only inside their scoped git sub-repository AND only inside a worktree on a feature branch. The `oelite/` root is a non-git monorepo container; direct writes to it and non-repository family containers are blocked, plus edits in main checkouts (not under `.worktrees/`) and on protected branches (`develop`/`main`/`master`) are blocked. Enforced by `coding-standards/scripts/hooks/oelite-guard.sh` for both Claude Code (via per-repo `.claude/settings.json`) and OpenCode (via `coding-standards/scripts/opencode-plugin-oelite/`). Humans bypass with `OELITE_HUMAN=1`; `.claude/` and `.opencode/` are auto-allowed (IDE config). Run `coding-standards/scripts/hooks/install-ide-guards.sh --apply` to roll out to new repos.
- ✅ Worktree identity via `scripts/oelite-gitlab.sh worktree-create`
- ✅ `develop` sync before worktree creation (use `worktree-sync` — safe sync that does NOT checkout develop)
- ✅ **Pre-commit hook enforcement**: Hook blocks commits outside `.worktrees/` and on protected branches (`develop`, `main`, `master`). Humans bypass with `OELITE_HUMAN=1`. Installed automatically by `worktree-create`.
- ✅ **Protected branches**: `develop` and `main` are for MR merges only. AI agents must NEVER commit directly on them. GitLab protected branches should be configured server-side as a second layer of defense.
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

**⚠️ GitLab API security rule:** Never generate raw `curl` commands against `code.phanes.ltd`, and never expand `OELITE_PAT_*` in an agent-generated Bash command. This exposes a secret-bearing operation to Claude Code's shell evaluator and triggers `simple_expansion` approval prompts. Use the provided wrapper for every GitLab operation:

```bash
# Correct — PAT is loaded internally from Keychain
coding-standards/scripts/oelite-gitlab.sh issue-status oelite/jupiter/apex 323 emma closed

# Forbidden — raw API call and PAT expansion
source coding-standards/scripts/oelite-gitlab-env.sh; curl ... \"$OELITE_PAT_EMMA\" ...
```

The wrapper is the only supported interface for issues, worktrees, MRs, comments, approvals, and status transitions. If the wrapper lacks an operation, extend `oelite-gitlab.sh`; do not bypass it with raw API calls.

| Command | Purpose |
|---------|---------|
| `setup` | Verify all 12 agent PATs against GitLab |
| `issues <project>` | List open issues (GitLab path: `oelite/<family>/<repo>`) |
| `issue-show <project> <iid>` | Show issue details with description and assignee |
| `issue-create <project> <agent> <title> [desc]` | Create a new issue as agent |
| `issue-assign <project> <iid> <agent>` | Assign issue to agent |
| `issue-comment <project> <iid> <agent> <msg>` | Comment on issue as agent |
| `issue-status <project> <iid> <agent> <opened|closed>` | Open or close issue as agent |
| `worktree-sync` | Safe sync — updates local develop WITHOUT checking it out (avoids footgun) |
| `worktree-create <agent> <branch> [base] [--issue <iid>] [--no-issue]` | Create worktree (issue-keyed for parallel same-agent work, or legacy) |
| `worktree-list` | List active worktrees |
| `worktree-remove <worktree-id>` | Remove worktree (worktree-id = agent or agent-issue) |
| `worktree-owner <worktree-id> [new-owner]` | View or update worktree owner DNA (commit attribution) |
| `mr-create <project> <agent> <src> <tgt> <title> [desc]` | Create MR as agent |
| `mr-list <project>` | List open MRs |
| `mr-comment <project> <iid> <agent> <msg>` | Comment on MR as agent |
| `mr-approve <project> <iid> <agent>` | Approve MR as agent |
| `mr-update <project> <iid> <agent> <title> [desc]` | Update MR title and description (pass empty title to keep current) |
| `mr-status <project> <iid>` | Check MR merge status (open/merged/closed/cannot_merge) — used for merge verification |
| `mr-check-eligible <project>` | List open MRs that meet auto-approval criteria (CI green, no conflicts, age ≥10min) |
| `mr-auto-approve <project>` | Auto-approve all eligible MRs (uses caller's PAT for attribution) |
| `mr-merge <project> <iid> <agent>` | Merge MR as agent (via GitLab API) |
| `mr-close <project> <iid> <agent>` | Close MR without merging (e.g. superseded/obsolete) |
| `issue-audit <project>` | List issues still open whose linked MRs are merged — used for post-merge audit |
| `oe-scope <agent> [--task-type] [--issue] [--desc]` | Read/update per-worktree .oe-scope file (compaction-resilient context anchor) |
| `sync <worktree-id>` | Rebase worktree on latest `origin/develop` |
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
2. `<repo>/.ai/standards/*` — repo overrides (extend, never contradict). **Deviation-only convention**: only repos that deviate from OElite patterns maintain a `.ai/` directory. Non-deviating repos must NOT carry one — it duplicates the canon and causes drift.
3. `uranus/arc-agents/standards/` — mirror only (may drift)

**`.ai/` Directory Constraints**:
- **Allowed**: `<repo>/.ai/standards/*.md` — repo-specific coding standard overrides
- **FORBIDDEN**: `<repo>/.ai/issues/`, `<repo>/.ai/tasks/`, `<repo>/.ai/plans/`, or any local issue/task tracking files
- **FORBIDDEN**: Issue tickets, task descriptions, or work-item files in `.ai/` (see `PROHIBITED-PATTERNS.md` §7)
- All issue management MUST go through GitLab server via `issue-create` CLI

---

*End of navigator. Full details in modular files loaded per bootstrap.*
