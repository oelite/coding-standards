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

## 📋 MANDATORY HANDOFF FORMAT (HARD GATE — Reviewers Reject Incomplete Handoffs)

Every completed task MUST include the sections below. **Reviewers MUST reject any handoff missing any of these fields.** "Should pass" or "Works locally" without evidence is NOT acceptable — the reviewer must be able to confirm from the output alone.

### Work Completed
- summary of what changed and where (files/projects)

### Commands Executed (MUST paste actual command output)
- build command + output (e.g. `dotnet build` / `npx next build` — show the actual exit code and any errors)
- test command + output (e.g. `dotnet test` / `npx playwright test` — show pass/fail count, NOT just "all pass")
- health/startup command + output (e.g. `curl -f http://localhost:<port>/health` — show HTTP status code)

### Verification Results
- build status · test status · runtime/health status · (security scan if applicable)
- **Evidence above is mandatory. "Should pass" or "Works locally" is NOT acceptable.**

### Documentation Impact
- **Does this change require documentation updates?** YES / NO
- **Business-change impact-analysis gate (`business-change-impact` skill)**:
  - **Phase 1 (pre-dev) Emma analysis performed:** YES / N/A — product change analysed, implied business logic & edge cases identified, documentation impact advised to Isabella
  - **Phase 1 (pre-dev) market research + team allocation:** YES / N/A — surrounding features/dependencies identified with rationale; best-fit roles assigned with dependency-sequenced plan
  - **Phase 1 (pre-dev) Isabella confirmation:** YES / N/A — required docs updated BEFORE development (factual via REQUIREMENTS-AUTHORITY.md; descriptive to planned behavior); user stories / AC / screenshot requirements refined
  - **Factual requirements impact?** YES / NO — did behavior change vs an approved BRD/SRS/rule/user story/journey? If YES, do NOT edit those documents yourself: state the discrepancy with requirement/rule IDs so Isabella can run the amendment process (`6_documentation_standards/REQUIREMENTS-AUTHORITY.md`).
  - **Descriptive docs to update:** API docs / technical / configuration / deployment / README / CHANGELOG (list)
  - **User guide / Playwright screenshots:** YES / NO (list screens)
  - **Isabella notified + confirmed?** YES / NO
  - **Emma retrospective goal review:** YES / N/A — original stakeholder request/goals confirmed achieved, all original AC satisfied, surrounding features/regressions checked
  - **Phase 2 (post-dev) revisit recorded:** YES / N/A / pending — documentation revisited against implemented reality, real Playwright screenshots captured, release notes published, accuracy confirmed BEFORE Emma closes issue

### Cleanup Evidence
- **Worktree cleanup performed**: YES / NO (mandatory if MR was merged/closed)
- If YES, show the actual `worktree-cleanup` command output: branch deleted, worktree removed/pruned
- If NO, state why (e.g., worktree not yet merged, `--force` was used, or cleanup deferred with approval)
- **Reviewers MUST reject** any handoff that claims worktree cleanup without evidence or shows a stale worktree whose linked MR is already merged/closed.

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
| **MR merge verified** (`mr-status` confirms `merged`) | `Ready to Merge` → `Done` | Reviewer or Emma |
| **Issue closed in GitLab** (`issue-status closed`) | `Done` (label) → **Closed** (state) | Emma — same session as merge verification |
| Isabella's business validation fails | `Done` → `In Progress` | Emma |
| External blocker encountered | `In Progress` → `Blocked` | Assignee |
| External blocker resolved | `Blocked` → `In Progress` | Assignee |

**Closure rule:** Only Emma may close an issue, and only after:
1. MR merge is **verified** via `mr-status` (not assumed)
2. **Isabella's pre-development documentation gate** passed (documentation updated BEFORE development)
3. **Emma's retrospective goal review** passed (original stakeholder request/goals confirmed achieved, all original AC satisfied, surrounding features/regressions checked)
4. **Isabella's post-development documentation revisit** passed (documentation accuracy confirmed against implemented reality, Playwright screenshots captured, release notes published)
5. Issue is labeled `Done`
6. Issue is **closed** via `issue-status closed` in the same session as merge verification

**Post-merge audit:** Isabella (or designated reviewer) MUST run `issue-audit <project>` periodically to catch any issues left open after their linked MRs were merged. Orphaned open issues are escalated to Emma for immediate closure.

### Requirements Change Triggers
- **Stakeholder or Emma specifies new business requirements** → triggers Isabella immediately via the `business-change-impact` skill gate (Emma first analyses product change + implied logic; Isabella confirms & updates factual docs per `REQUIREMENTS-AUTHORITY.md` + descriptive docs BEFORE development; once complete, she triggers Emma to proceed).
- **Stakeholder or Emma updates existing business requirements** → triggers Isabella immediately via the same gate: Emma analyses impact → Isabella amends canonical factual documents through the authority standard, reconciles derived documents, notifies affected roles BEFORE they continue work.
- **Implementation reveals a discrepancy or gap vs approved requirements** → the implementer records it in GitLab with the requirement/rule IDs; requirements are NOT silently rewritten to match code. Isabella routes it as an implementation fix or a factual amendment. Emma re-runs the impact-analysis gate if the new fact changes documentation scope.

### Backend Workflow Triggers
1. **Emma clarifies + plans → business-change impact-analysis gate** (load `business-change-impact` skill; Emma analyses product change + implied logic; Isabella confirms & updates required docs BEFORE development)
2. **Isabella triggers Emma to proceed** → Marcus reviews design/architecture.
3. Daniel implements → builds clean, service starts, health 200, tests pass.
4. Maya reviews if auth/security/CRUD-sensitive; Victor reviews if queries/denormalization/caching changed. **(Parallel)**
5. Grace reviews code quality & pattern compliance.
6. Olivia validates via API/integration tests AND E2E browser tests. **Olivia MUST enforce all 12 E2E Quality Gates.** If tests fail, hand back to Daniel with exact repro steps.
7. Ethan validates Docker/K8s deployment & health.
8. **Isabella post-development documentation revisit** — updates docs to merged behavior, captures real Playwright screenshots, publishes release notes; confirms accuracy/quality before Emma closes issue.

### Frontend Workflow Triggers
1. **Emma + Marcus brief Jonathan on business context → business-change impact-analysis gate** (load `business-change-impact` skill; Emma analyses product change + implied logic; Isabella confirms & updates required docs BEFORE development)
2. **Isabella triggers Emma to proceed** → Jonathan produces design spec.
3. Emma approves (product); Marcus reviews (architecture/API contracts).
4. Sophia implements in correct stack with real APIs (no mock data).
5. Jonathan reviews UX/design fidelity; Felix reviews frontend code quality. **(Parallel)**
6. Build succeeds (`npx next build` / `ng build` + lint clean).
7. Olivia validates E2E browser tests. **Olivia MUST enforce all 12 E2E Quality Gates.** If tests fail, hand back to Sophia with exact repro steps.
8. Ethan validates deployment.
9. **Isabella post-development documentation revisit** — captures real Playwright screenshots, updates docs to merged behavior, publishes release notes; confirms accuracy/quality before Emma closes issue.

### Infrastructure Workflow Triggers
1. **Emma analyses product change + impact-analysis gate** → **Isabella updates infrastructure documentation** (if reqs changed) BEFORE implementation → Implement → Marcus reviews.
2. Olivia validates containers/health; Maya reviews secrets/config. **(Parallel)**
3. Ethan validates deployment.
4. **Isabella post-development documentation revisit** — confirms infrastructure meets operational requirements, updates docs, captures screenshots where user-facing; confirms accuracy before Emma closes issue.

### Identity / Auth Change Triggers (origin-auth / Kortex)
1. **Emma analyses product change + impact-analysis gate** → **Isabella updates security documentation and API docs** (if reqs changed) BEFORE development → Marcus reviews architecture & tenancy impact.
2. Daniel implements against established TokenService/crypto patterns.
3. **Maya MUST review** (mandatory trigger) — JWT/keys/Argon2id/encryption/authorization/secrets.
4. Olivia validates token issuance/validation/revocation and tenant-scoping via unit/integration tests AND E2E for UI components.
5. Grace reviews quality; Ethan validates deployment & scan.
6. **Isabella post-development documentation revisit** — confirms auth flows meet security and business requirements, updates docs to merged behavior, confirms accuracy before Emma closes issue.

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

**No project is complete until Isabella's two-phase gate passes.**

### Phase 1 — Pre-development documentation (before development begins)

After Emma clarifies requirements and performs the business-change impact-analysis:

1. **Isabella reviews the request** and confirms Emma's impact analysis.
2. **Isabella updates documentation** BEFORE development begins:
   - Factual documents (BRD, SRS, user stories, rulebook, process flows): amend ONLY via `REQUIREMENTS-AUTHORITY.md` for approved factual changes
   - Descriptive documentation (API docs, README, changelog, architecture decisions, configuration, deployment docs): update to planned behavior
   - User guides with **Playwright screenshot requirements** specified (which screens/states to capture after development)
3. **Validation criteria** (pre-dev):
   - Are business requirements clearly documented and approved?
   - Are acceptance criteria precise enough for QA and validation?
   - Is the documentation scope clear (factual vs descriptive)?
4. If pre-dev validation fails → hand back to Emma for clarification or business decision.
5. If pre-dev passes → **Isabella triggers Emma to proceed** to implementation.

### Phase 2 — Post-development documentation revisit (after development completes)

After all technical reviews, tests, and deployment succeed:

1. **Isabella reviews the deliverable** against the implemented reality (not just the plan).
2. **Isabella updates documentation**:
   - Technical documentation (API docs, README, changelog, architecture decisions): update to merged behavior
   - User guides with **Playwright screenshots** capturing actual UI/UX (not mockups, not placeholders)
   - Release notes with business impact summary
3. **Validation criteria** (post-dev):
   - Does the implementation match the business requirements Emma documented?
   - Are all user journeys working as expected?
   - Are edge cases and error flows handled per business context?
   - Does the UX reflect actual business workflows (not just CRUD)?
   - Is all documentation current, accurate, and complete?
   - Do user guides include actual screenshots (not mockups)?
   - If implementation deviates from an approved requirement, has the discrepancy been recorded in GitLab with requirement/rule IDs and routed via `REQUIREMENTS-AUTHORITY.md`?
4. If validation fails → hand back to implementing role with specific gaps.
5. If documentation incomplete → Isabella creates/updates documentation before declaring complete.
6. If validation passes → **Emma performs a retrospective goal review** before handing the issue back to herself for closure:
   - Compare the shipped deliverable against the original stakeholder request/goals documented in the issue.
   - Verify all original acceptance criteria (US-XXX/AC-YYY) are satisfied — not only the enhanced/implied ones added in Phase 1.
   - Confirm no surrounding feature/logic was broken by the change (regression check against Phase 1a market research).
   - If goals are not met or gaps are found → hand back to the implementing role with specific gaps; only re-run this step once fixed.
   - If goals are met → close the issue only after MR merge verified via `mr-status` and `issue-status closed` run in the same session.

**Definition of Project Complete**:
- ✅ All workflow steps passed
- ✅ **Phase 1 pre-dev documentation gate** passed (market research + team allocation + Isabella confirmation)
- ✅ **Phase 2 post-dev documentation revisit** passed
- ✅ **Emma retrospective goal review** passed (original request/goals achieved; all original AC satisfied)
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
| `issue-create <project> <agent> <title> [desc]` | Create a new issue |
| `issue-assign <project> <iid> <agent>` | Assign issue |
| `issue-comment <project> <iid> <agent> <msg>` | Comment on issue |
| `issue-status <project> <iid> <agent> <opened\|closed>` | Open or close issue |
| `worktree-create <agent> <branch> [base]` | Create worktree with agent identity |
| `worktree-sync` | Safe sync — refreshes origin/develop; fast-forwards local develop only when unchecked-out and non-divergent (never checks out develop) |
| `worktree-list` | List active worktrees |
| `worktree-cleanup <agent> [--delete-branch]` | **HARD GATE** — verify linked MR, prune orphans, remove merged/closed worktree, optionally delete local branch |
| `worktree-cleanup --all` | Sweep all worktrees in the current repo; remove those whose linked MR is merged/closed (Emma periodic sweep) |
| `worktree-check-stale [--agent A] [--cleanup]` | Report worktrees whose linked MR is merged/closed or prunable orphan; `--cleanup` to prune |
| `mr-create <project> <agent> <src> <tgt> <title> [desc]` | Create MR |
| `mr-list <project>` | List open MRs |
| `mr-comment <project> <iid> <agent> <msg>` | Comment on MR |
| `mr-approve <project> <iid> <agent>` | Approve MR |
| `mr-status <project> <iid>` | Report state, merge readiness, CI evidence, and approvals independently |
| `mr-show <project> <iid> [--raw]` | Read MR description and authoritative status fields |
| `pipeline-jobs <project> <pipeline-id>` | List pipeline jobs and failure reasons |
| `pipeline-job-trace <project> <job-id>` | Read job trace; fetch only when needed because output may be sensitive |
| `pipeline-job-retry <project> <job-id> [<agent>]` | Retry a single failed job (same SHA); attributed to the named agent, default `emma` — flaky-CI remediation only, never for real code failures |
| `mr-check-eligible <project>` | Check per-MR pipeline evidence; unknown evidence fails closed |
| `mr-auto-approve <project>` | Auto-approve eligible MRs under Emma's identity via the `emma` PAT |
| `sync <agent>` | Rebase worktree on latest `origin/develop` |
| `status` | Show worktree status |

### Agent Session Protocol (MR-Centric Model)

```bash
# ── Phase 1: Initialization ──
scripts/oelite-gitlab.sh worktree-sync    # Safe sync — does NOT checkout develop
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
scripts/oelite-gitlab.sh worktree-cleanup <agent> --delete-branch
scripts/oelite-gitlab.sh worktree-sync
```

**Mandatory rules for agents:**
1. **Sync First** before creating worktree (use `worktree-sync` — safe, no checkout)
2. **Push Feature Branch** before creating MR
3. **Create MR** targeting `develop`
4. **No Local Merges** — all code enters `develop` through reviewed MRs
5. **Sync After Merge** before next task
6. **Worktree Cleanup (same session)** — after `mr-status` confirms `merged` (or `closed`), run `worktree-cleanup <agent> --delete-branch` in the same session. The `worktree-create` preflight now hard-blocks on stale merged/closed worktrees, so skipping cleanup will block the next task.

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
- Never start a new task while leaving a worktree whose linked MR is merged or closed
