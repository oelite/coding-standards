# Workflow Details — Agent Collaboration, Handoffs, GitLab Integration

> **Loaded by ALL agents as part of bootstrap** (referenced from principles.md). Contains detailed workflow chains, handoff format, failure escalation, and GitLab integration specifics.
> **Task initialization** (bootstrap steps, sync, worktree creation) is defined in `AGENTS.md` navigator — not duplicated here.

---

## 🧬 WORKTREE-OWNER DNA — COMMIT ATTRIBUTION

**CRITICAL**: When agents work in worktrees, commits MUST use the **team member's GitLab identity**, not the AI executor's identity.

### Identity Mapping

| Team Member | GitLab Username | Email | Display Name |
|-------------|----------------|-------|--------------|
| Emma | emma.phanes | emma@phanes.ltd | Emma |
| Marcus | marcus.phanes | marcus@phanes.ltd | Marcus |
| Daniel | daniel.phanes | daniel@phanes.ltd | Daniel |
| Sophia | sophia.phanes | sophia@phanes.ltd | Sophia |
| Jonathan | jonathan.phanes | jonathan@phanes.ltd | Jonathan |
| Olivia | olivia.phanes | olivia@phanes.ltd | Olivia |
| Ethan | ethan.phanes | ethan@phanes.ltd | Ethan |
| Maya | maya.phanes | maya@phanes.ltd | Maya |
| Victor | victor.phanes | victor@phanes.ltd | Victor |
| Grace | grace.phanes | grace@phanes.ltd | Grace |
| Felix | felix.phanes | felix@phanes.ltd | Felix |
| Isabella | isabella.phanes | isabella@phanes.ltd | Isabella |

### Verification

```bash
# Check git config in worktree
git -C .worktrees/daniel config --local --list | grep user

# Check recent commit authorship
git -C .worktrees/daniel log --oneline -5 --format="%h | %an <%ae>"

# Expected: %an = team member name, %ae = team member email
```

If owner DNA is incorrect, re-create the worktree with the correct agent parameter.

For full details see `coding-standards/5_git_workflow_standards/WORKTREE-OWNER-DNA.md`.

---

## 🤝 COLLABORATION PRACTICES

The team should:
- Collaborate autonomously and delegate to the appropriate specialist.
- Continue workflows without unnecessary interruptions, assigning the next responsible owner.
- Provide structured handoffs and continue validation chains until the Definition of Done for the whole chain is met.
- Raise concerns early when a request contradicts standards, tenancy, or architecture — propose an alternative rather than silently complying.
- **Documentation is a team responsibility**: Every team member MUST assess documentation impact before completing work. If changes affect user-facing behavior, APIs, configuration, architecture, or business requirements, notify Isabella immediately with specific details.

---

## 📋 MANDATORY HANDOFF FORMAT

Every completed task MUST include:

### Work Completed
- summary of what changed and where (files/projects)

### Commands Executed
- exact commands with their output (build/test/E2E/health/docker/kubectl)

### Verification Results
- build status · test status · runtime/health status · (security scan if applicable)

### Documentation Impact
- **Does this change require documentation updates?** YES / NO
- If YES, specify:
  - What changed (new feature, API change, config change, UI change, etc.)
  - What documentation needs updating (BRD, SRS, API docs, user guides, README, etc.)
  - Specific details Isabella needs to update the documentation accurately
- **Isabella notified?** YES / NO

### Risks
- unresolved concerns · blocked items (e.g. missing endpoints, disabled CI)

### Issue Status Update
- **Current issue status**: [status label]
- **Status change performed**: [e.g., `In Progress` → `PR Review`]
- **Issue comment posted**: YES / NO (mandatory for every status transition)

### Recommended Next Owner
- the assigned follow-up role
- **explicit trigger**: what event/condition triggers the handoff

---

## 🔄 AUTONOMOUS HANDOFF TRIGGERS

### Issue Status Transition Triggers

| Trigger | Status Change | Who |
|---------|---------------|-----|
| Emma assigns issue to agent | `To Do` → `In Progress` | Emma |
| Agent creates worktree and starts implementation | `To Do`/`Blocked` → `In Progress` | Assignee |
| Agent creates MR targeting develop | `In Progress` → `PR Review` | Assignee |
| Reviewer approves MR and CI is green | `PR Review` → `Ready to Merge` | Reviewer |
| MR merged into develop | `Ready to Merge` → `Done` | Emma |
| Isabella's business validation fails | `Done` → `In Progress` | Emma |
| External blocker encountered | `In Progress` → `Blocked` | Assignee |
| External blocker resolved | `Blocked` → `In Progress` | Assignee |

**Closure rule:** Only Emma may close an issue, and only after MR merge + Isabella's business validation.

### Requirements Change Triggers
- **Stakeholder or Emma specifies new business requirements** → triggers Isabella immediately. Isabella updates BRD, SRS, technical documentation, configuration documentation, and user guides BEFORE development begins. Once complete, she triggers Emma to proceed.
- **Stakeholder or Emma updates existing business requirements** → triggers Isabella immediately. Isabella reviews impact on existing documentation, updates as needed, and notifies affected roles BEFORE they continue work.

### Backend Workflow Triggers
1. Emma clarifies + plans → **Isabella updates docs if reqs changed** → Marcus reviews design/architecture.
2. Daniel implements → builds clean, service starts, health 200, tests pass.
3. Maya reviews if auth/security/CRUD-sensitive; Victor reviews if queries/denormalization/caching changed. **(Parallel)**
4. Grace reviews code quality & pattern compliance.
5. Olivia validates via API/integration tests AND E2E browser tests. **Olivia MUST enforce all 8 E2E Quality Gates.** If tests fail, hand back to Daniel with exact repro steps.
6. Ethan validates Docker/K8s deployment & health.
7. **Isabella final business validation** — confirms deliverable matches requirements, updates docs, publishes release notes.

### Frontend Workflow Triggers
1. **Emma + Marcus brief Jonathan on business context** → **Isabella updates docs if reqs changed**.
2. Jonathan produces design spec.
3. Emma approves (product); Marcus reviews (architecture/API contracts).
4. Sophia implements in correct stack with real APIs (no mock data).
5. Jonathan reviews UX/design fidelity; Felix reviews frontend code quality. **(Parallel)**
6. Build succeeds (`npx next build` / `ng build` + lint clean).
7. Olivia validates E2E browser tests. **Olivia MUST enforce all 8 E2E Quality Gates.** If tests fail, hand back to Sophia with exact repro steps.
8. Ethan validates deployment.
9. **Isabella final business validation** — captures Playwright screenshots, updates docs, publishes release notes.

### Infrastructure Workflow Triggers
1. **Isabella updates infrastructure documentation if reqs changed** → Implement → Marcus reviews.
2. Olivia validates containers/health; Maya reviews secrets/config. **(Parallel)**
3. Ethan validates deployment.
4. **Isabella final business validation** — confirms infrastructure meets operational requirements, updates docs.

### Identity / Auth Change Triggers (origin-auth / Kortex)
1. **Isabella updates security documentation and API docs if reqs changed** → Marcus reviews architecture & tenancy impact.
2. Daniel implements against established TokenService/crypto patterns.
3. **Maya MUST review** (mandatory trigger) — JWT/keys/Argon2id/encryption/authorization/secrets.
4. Olivia validates token issuance/validation/revocation and tenant-scoping via unit/integration tests AND E2E for UI components.
5. Grace reviews quality; Ethan validates deployment & scan.
6. **Isabella final business validation** — confirms auth flows meet security and business requirements.

### Failure Escalation Protocol
1. **Failure report format** (mandatory):
   - Exact repro steps
   - Logs/screenshots/E2E output
   - Specific files/lines to fix
   - Severity: blocker / warning
2. **Retry loop**: Implementer has **2 attempts** to fix. After each attempt, re-trigger reviewer.
3. **Escalation paths**:
   - If still failing after 2 attempts → escalate to Marcus (architecture) or Emma (requirements)
   - Technical disagreement → Marcus adjudicates
   - Requirements ambiguity → Emma clarifies
   - Security concern → Maya final call
   - Performance regression → Victor final call

---

## ⚡ PARALLEL EXECUTION OPPORTUNITIES

- **Backend**: Maya (security) + Victor (performance) can review in parallel if both triggered
- **Frontend**: Jonathan (UX review) + Felix (code review) can review in parallel after Sophia completes
- **Infrastructure**: Olivia (container validation) + Maya (secrets review) can run in parallel

**Rule**: All parallel reviewers must pass before triggering the next sequential step. If any fails, hand back to implementer with all issues consolidated.

---

## 🏁 FINAL BUSINESS VALIDATION (Project Completion Gate)

**No project is complete until business validation passes.**

After all technical reviews, tests, and deployment succeed:

1. **Isabella reviews the deliverable** against original business requirements.
2. **Isabella updates documentation**:
   - Technical documentation (API docs, README, changelog, architecture decisions)
   - User guides with **Playwright screenshots** capturing actual UI/UX
   - Release notes with business impact summary
3. **Validation criteria**:
   - Does the implementation match the business requirements Emma documented?
   - Are all user journeys working as expected?
   - Are edge cases and error flows handled per business context?
   - Does the UX reflect actual business workflows (not just CRUD)?
   - Is all documentation current, accurate, and complete?
   - Do user guides include actual screenshots (not mockups)?
4. If validation fails → hand back to implementing role with specific gaps.
5. If documentation incomplete → Isabella creates/updates documentation before declaring complete.
6. If validation passes → **Project Complete**.

**Definition of Project Complete**:
- ✅ All workflow steps passed
- ✅ Business validation passed
- ✅ All documentation updated
- ✅ No unresolved risks or blocked items
- ✅ Handoff to operations complete

---

## 🦊 GITLAB-INTEGRATED DEVELOPMENT WORKFLOW

### PAT Storage Format
**The PAT MUST be stored in Keychain with the exact service name format:**

```bash
# ✅ CORRECT
security add-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w "glpat-xxxxxxxxxxxx" -U
```

**Service name pattern: `oelite-gitlab-<agent-name>`**
- Service: `oelite-gitlab-daniel`, `oelite-gitlab-emma`, etc.
- Account: `oelite` (always)

If 401 errors occur:
```bash
security find-generic-password -s "oelite-gitlab-daniel" -a "oelite" -w
scripts/oelite-gitlab.sh setup
```

### CLI Tool
**Always use the provided scripts** instead of manual curl.

```bash
scripts/oelite-gitlab.sh mr-list oelite/uranus/origin-auth
scripts/oelite-gitlab.sh issues oelite/helios/core --assignee daniel
scripts/oelite-gitlab.sh worktree-create daniel feature/US-001-auth
```

| Command | Purpose |
|---------|---------|
| `setup` | Verify all 12 agent PATs against GitLab |
| `issues <project>` | List open issues |
| `issue-assign <project> <iid> <agent>` | Assign issue |
| `issue-comment <project> <iid> <agent> <msg>` | Comment on issue |
| `worktree-create <agent> <branch> [base]` | Create worktree with agent identity |
| `worktree-list` | List active worktrees |
| `worktree-remove <agent>` | Remove worktree after MR merged |
| `mr-create <project> <agent> <src> <tgt> <title> [desc]` | Create MR |
| `mr-list <project>` | List open MRs |
| `mr-comment <project> <iid> <agent> <msg>` | Comment on MR |
| `mr-approve <project> <iid> <agent>` | Approve MR |
| `mr-check-eligible <project>` | List MRs meeting auto-approval criteria |
| `mr-auto-approve <project>` | Auto-approve eligible MRs |
| `sync <agent>` | Rebase worktree on latest `origin/develop` |
| `status` | Show worktree status |

### Agent Session Protocol (MR-Centric Model)

```bash
# ── Phase 1: Initialization ──
git checkout develop && git pull origin develop
scripts/oelite-gitlab.sh worktree-create <agent> <branch>
cd .worktrees/<agent>/

# ── Phase 2: Implementation ──
# ... implement, build, test ...
git push origin <branch>

# ── Phase 3: Create MR ──
scripts/oelite-gitlab.sh mr-create <project> <agent> <branch> develop "<title>"

# ── Phase 4: Review Loop ──
# Wait for feedback; fix → push → re-review

# ── Phase 5: After MR Approved + CI Green ──
scripts/oelite-gitlab.sh worktree-remove <agent>
git checkout develop && git pull origin develop
```

**Mandatory rules for agents:**
1. **Sync First** before creating worktree
2. **Push Feature Branch** before creating MR
3. **Create MR** targeting `develop`
4. **No Local Merges** — all code enters `develop` through reviewed MRs
5. **Sync After Merge** before next task

### GitLab Project Paths

| Local Path | GitLab Project Path |
|------------|-------------------|
| `helios/core/` | `oelite/helios/core` |
| `helios/kortex/` | `oelite/helios/kortex` |
| `uranus/origin-auth/` | `oelite/uranus/origin-auth` |
| `jupiter/occ/` | `oelite/jupiter-occ` |
| `venus/obelisk/` | `oelite/venus/obelisk` |

Use `scripts/oelite-gitlab.sh issues oelite/<path>` with the GitLab path, not the local path.

### Human + AI Collaboration

- **Human**: Works in main `develop`, pushes when satisfied.
- **Agent**: Works in worktree → pushes feature branch → creates MR → reviewer approves → GitLab auto-merges.
- **Safety**: Parallel work is safe via worktrees. All code enters `develop` through reviewed MRs.

---

## ⛔ NEVER DO

- Never commit outside a worktree
- Never commit under the AI executor's identity
- Never merge locally into `develop`
- Never skip bootstrap verification
- Never skip verification before declaring "done"
