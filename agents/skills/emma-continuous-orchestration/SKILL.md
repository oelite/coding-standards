# Emma Continuous Orchestration Skill

**Skill ID:** emma-continuous-orchestration
**Status:** active (registered in agents/skills/SKILLS.md)
**Default loaders:** Emma
**On-demand loaders:** Marcus, Jonathan, Daniel, Sophia, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella (when the continuous loop hands off to them or reports mission state)
**Owner:** Emma (continuous orchestration loop)
**Issue:** #56

---

## 1. Mission and When to Load

This skill defines Emma as the orchestrator for a durable, multi-stage workflow. It is a **protocol, not a background service**: loading the skill does not create a watcher, scheduler, or session that survives the host ending the current run. Emma must use the IDE's available subagent/session tools to dispatch and collect work. If no such mechanism is available, Emma records a GitLab checkpoint, identifies the exact next owner/action, and reports the workflow as BLOCKED or awaiting continuation; she must not claim to be continuously monitoring.

Unlike the `business-change-impact` skill (which defines the Phase 1 + Phase 2 gate for a single request), this skill describes the durable mission loop:

- **Watch** for new business-change / feature requests across repos
- **Run Phase 1 gate** (product analysis + market research + team allocation + Isabella confirmation) before any implementation worktree exists
- **Delegate** each deliverable to the best-fit role through an available native subagent/session mechanism, dependency-sequenced with per-role success criteria; create the role worktree as a separate preparation step
- **Monitor** worktree status, MR state, test/CI results; hand back with specific gaps if goals are not met (max 2 attempts, then escalate to human)
- **Run Phase 2** (Isabella post-development documentation revisit + Emma retrospective goal review) after team development completes
- **Close** only after MR merge verified via `mr-status` and `issue-status closed` run in the same session
- **Escalate** business decisions (new objective, scope, new rule, priority) to the human/stakeholder — Emma does not invent business facts

The loop returns to intake for another issue only while the orchestration session is active or after an explicit continuation. No polling or monitoring occurs between host sessions unless a runtime supervisor is active.

**Load this skill when the request contains any of these trigger phrases:**

- emma continuous, emma orchestration, run emma as subagent
- continuous orchestration, durable mission, mission loop
- keep monitoring, keep progressing, full completion of original goals
- delegate to roles, assign best-fit roles, sequence dependencies
- monitor worktree, monitor MR, track progress to done
- retrospective goal review, original request achieved
- mission state, mission ledger, orchestration state

**When NOT to load this skill:**

- A one-off implementation task where the user has already scoped all details and only needs coding → load the role-specific pack (backend-impl, frontend-impl, etc.) instead
- A pure documentation-only task → load `documentation` pack / `requirements-authority`
- Work that only touches delivery state (issue labels, MR state, cleanup) → no orchestration needed

If after loading this skill Emma judges a decision is a **business decision** (new objective, scope change, new business rule, priority change), stop and escalate to the human/stakeholder. Do not invent business facts.

---

## 2. The Continuous Orchestration Loop

The loop has **five repeating stages**. Neither stage may be skipped for a business-change/feature request. All stage evidence is recorded in GitLab (issue comments + labels), never in local `.ai/` task files per `PROHIBITED-PATTERNS.md` §7.

### Stage A — Watch & Intake (Emma)

1. **Emma watches** GitLab for new/open business-change / feature requests (issues with US-/TASK- prefixes, or issues where Emma is the logical owner per role responsibility).
2. For each candidate, Emma verifies the issue meets Definition of Ready (AC + owner + priority). If not, Emma updates the issue to meet DoR before proceeding rather than blocking silently.
3. Emma loads the `business-change-impact` skill to run Phase 1 on the request.

### Stage B — Phase 1 Gate: Pre-development (Emma leads, Isabella confirms)

4. **Emma analyses the product change** — not just the implementation ask — enhancing & detailing by identifying implied business logic, edge cases, error flows, permission boundaries, state transitions, backward-compatibility concerns.
5. **Emma conducts market research as product manager** (user interviews, stakeholder input, competitive analysis, industry standards) to ensure surrounding features/logics fully support the change. New feature needs surface as child issues for business approval, not silently added scope.
6. **Emma analyses required team members** to allocate best-fit roles before implementation begins: map change to roles (Daniel backend / Sophia frontend / Jonathan UX / Marcus architecture / Maya security / Victor performance / Ethan infrastructure / Olivia QA / Grace/Felix review), assign by expertise, sequence by dependency (architecture → UX → implementation → QA → deployment), record role assignments with explicit success criteria per role.
7. **Emma advises Isabella** on documentation impact (factual vs descriptive vs user-guide classes per the `business-change-impact` decision matrix).
8. **Isabella confirms** and authors/updates required documentation BEFORE development starts. Only after Isabella's confirmation does Emma proceed to Stage C.
9. **Emma records Phase 1 gate** in the issue record (GitLab comment + `gate:phase1-recorded` label).

**Gate rule:** No implementation worktree creation, no code, no design spec until Phase 1 (4–9) is recorded.

### Stage C — Delegate & Sequence (Emma)

10. **Emma dispatches implementation work** to each assigned role through the available native subagent/session mechanism, dependency-sequenced. Each role receives the role/task type, issue, worktree and `.oe-scope` context. If the host cannot dispatch a role, Emma records the role and exact next action in the GitLab checkpoint and marks the workflow BLOCKED; creating a worktree alone is not delegation.
11. **Emma triggers the next responsible owner** per the handoff chain (`agents/workflow/workflow.md`): Isabella pre-dev docs → Marcus arch review → Daniel/Sophia impl → Olivia QA → Ethan deploy → Isabella post-dev revisit → Emma closure. Each transition requires dispatch evidence or an explicit blocker and next action.
12. **Emma monitors** each delegated task while the parent session is active: worktree status, MR state, MR approvals, CI pipeline, test results via `mr-status`, `mr-list`, `pipeline-jobs`. Do not imply monitoring continues after the host session ends unless a runtime supervisor is actually active.

### Stage D — Progress Monitoring & Escalation (Emma)

13. **Emma checks progress** on each in-flight worktree. If a subagent finishes, Emma collects its structured handoff (per `workflow.md` Mandatory Handoff Format).
14. **If goals are not met or gaps found**, Emma hands back to the implementing role with specific gaps. Max **2 attempts** per task; on the third failure, Emma pauses the mission and escalates to the human (no silent retry loops).
15. **If a business decision is needed** at any point (new objective, scope change, new business rule, priority change), Emma stops and escalates to the human/stakeholder. Emma does not invent business facts.
16. **Mission state** is tracked in GitLab via issue labels and comments (mission-issue ledger), never local `.ai/` task files.

### Stage E — Phase 2: Post-development & Closure (Isabella leads, Emma closes)

17. After team development completes (implementation + reviews + tests green), **Isabella runs Phase 2 revisit**: documentation accuracy against implemented reality, real Playwright screenshots, descriptive docs + release notes.
18. **Emma conducts retrospective goal review**: compares shipped deliverable against original stakeholder request/goals; verifies all original acceptance criteria (US-XXX/AC-YYY) satisfied — not only the enhanced/implied ones from Phase 1; confirms no surrounding feature/logic was broken (regression check against Phase 1a market research).
19. If goals are not met, hand back to implementing role with specific gaps before closure.
20. **Emma closes** only after Phase 2 passes, retrospective goal review passes, MR merge verified via `mr-status`, and `issue-status closed` run **in the same session**.

**Gate rule:** Emma MUST NOT label an issue `Done` or close it while Phase 2 documentation revisit or retrospective goal review is outstanding or failing.

---

## 3. Handoff Recording and Recovery Checkpoint

Every stage appends to the `Documentation Impact` section of the Mandatory Handoff Format (`agents/workflow/workflow.md`) and records a durable checkpoint in the GitLab issue before yielding or ending the session:

- Original stakeholder request and original acceptance criteria (verbatim or stable issue/comment reference)
- Current stage and responsible role
- Completed work with verification evidence
- Remaining criteria and dependent roles
- Attempts used per delegated task (0/2, 1/2, 2/2)
- Blockers and exact decisions required, with decision owner
- Next action, responsible role, and trigger
- Dispatch status and child session/worktree reference where available

`.oe-scope` is only a worktree locator; it is not the mission ledger. On continuation or context compaction, re-read the GitLab checkpoint and compare it with the original issue before acting. If the checkpoint is missing or conflicts with the issue, stop and reconcile before changing scope.

A non-terminal handoff MUST state `ACTIVE`, `BLOCKED`, or `AWAITING CONTINUATION`. `COMPLETE` is allowed only after all original acceptance criteria and workflow gates pass. A recommendation without a dispatch attempt or an explicit blocker is not a completed handoff.

```
### Documentation Impact
- **Stage A (intake):** issue meets Definition of Ready? YES / NO
- **Stage B (Phase 1 gate recorded):** YES / N/A — product analysis + market research + team allocation + Isabella confirmation present in GitLab before any implementer worktree
- **Stage C (delegate):** roles assigned — Daniel/Sophia/Jonathan/Marcus/Maya/Victor/Ethan/Olivia/Grace/Felix (list) with dependency sequence + per-role success criteria; dispatch status and child session/worktree reference, or exact blocker
- **Stage D (monitor):** worktree status · MR state · CI/test results · attempts used (0/2, 1/2, 2/2) · gaps found / handed back (list)
- **Stage E (Phase 2 + retrospective):** Isabella revisit passed YES / N/A; Emma retrospective goal review passed YES / N/A — original request/goals achieved, all original AC satisfied, no surrounding-feature regression
- **Closure:** MR merge verified via mr-status YES / N/A; issue-status closed run in same session YES / NO
- **Continuation:** ACTIVE / BLOCKED / AWAITING CONTINUATION / COMPLETE; exact next action + responsible role when not COMPLETE
- **Original goal preservation:** original request/AC reference; completed and remaining criteria
```

Reviewers reject a handoff missing any of these fields.

---

## 4. Role Responsibilities

### Emma (continuous orchestrator)
- Runs the continuous loop: watch → Phase 1 → delegate → monitor → Phase 2 → close → repeat
- **Phase 1 execution:** product analysis, market research as product manager, team allocation analysis (best-fit roles, dependency sequence, per-role success criteria)
- **Delegation:** dispatches implementation work through the available native subagent/session mechanism, assigns next responsible owner per handoff chain, and prepares each role worktree with owner DNA and `.oe-scope` context anchor. Worktree creation alone is not delegation.
- **Monitoring:** tracks worktree/MR/CI progress; max 2 attempts per task, then escalates to human
- **Retrospective goal review:** confirms original request/goals achieved, all original AC satisfied, no surrounding-feature regression
- **Closure:** verifies MR merge via `mr-status`; runs `issue-status closed` in same session as merge verification
- **Escalation:** business decisions (new scope, new rule, new priority) go to human/stakeholder; Emma does not invent facts
- Does NOT close an issue while Phase 1 or Phase 2 is outstanding

### Isabella (documentation executor, per `business-change-impact` skill)
- Confirms Phase 1 documentation impact; authors/updates required docs before development
- Runs Phase 2 post-development documentation revisit (accuracy vs implemented reality, Playwright screenshots, release notes)

### Daniel / Sophia / Jonathan / Marcus / Olivia / Ethan / Maya / Victor / Grace / Felix
- Implement delegated deliverables per assigned role with explicit success criteria
- Flag implementation-vs-requirement discrepancies to Emma (who re-runs Phase 1 if documentation scope changes)

---

## 5. Verification

- **Phase 1 evidence:** product analysis + market research + team allocation + Isabella confirmation present in issue record (GitLab) before any implementer worktree exists
- **Delegation evidence:** dispatch attempted or blocker recorded for each implementer role; role worktree created via `worktree-create <role> --issue <iid>` with owner DNA and `.oe-scope` context anchor. Worktree creation alone is not dispatch evidence.
- **Monitoring evidence:** worktree/MR/CI status checked; gaps recorded as GitLab comments; max-2-attempt limit enforced
- **Phase 2 evidence:** Isabella revisit + Playwright screenshots + descriptive doc updates present before Emma labels `Done`
- **Retrospective evidence:** original request/goals confirmed achieved, all original AC satisfied, surrounding-feature regression check present in issue record before closure
- **Closure evidence:** `mr-status` confirms merged; `issue-status closed` run in same session as merge verification
- **No local task state:** mission state lives in GitLab (issue labels/comments), never in `.ai/issues/`, `.ai/tasks/`, `.ai/plans/` per `PROHIBITED-PATTERNS.md` §7

---

## 6. Related Skills & Standards

- `business-change-impact` (#54) — the Phase 1 + Phase 2 gate this skill operationalizes continuously
- `requirements-authority` (#40) — factual-document governance when requirements may need amending
- `architecture-design` (#19) — architecturally significant changes (Marcus)
- `ux-design` / `frontend-design` — UI surfaces
- `agents/workflow/workflow.md` — Mandatory Handoff Format, Closure rule, handoff chain
- `agents/packs/planning.md` — Required Outputs, role assignment per task
- `agents/roles/emma.md` — Emma responsibilities (gate orchestration, monitoring, retrospective goal review)
- `agents/core/principles.md` — Issue-First, Autonomous Handoff, Merge Verification, Issue Closure Enforcement
- `PROHIBITED-PATTERNS.md` §7 — no local issue/task files; mission state via GitLab only