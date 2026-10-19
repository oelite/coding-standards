# Business Change Impact-Analysis Skill

**Skill ID:** business-change-impact
**Status:** active (registered in agents/skills/SKILLS.md)
**Default loaders:** Emma, Isabella
**On-demand loaders:** Marcus, Jonathan, Daniel, Sophia, Olivia, Grace, Felix (when their work reveals a factual-requirements impact)
**Owner:** Emma (gate orchestration) + Isabella (documentation execution)
**Issue:** #54

---

## 1. Mission and When to Load

This skill defines the **mandatory, always-on Emma→Isabella impact-analysis gate** for any request that changes business logic, workflows, user-facing behavior, APIs, configuration, or architecture. The purpose: we do not *only* implement what the user asks — we first **analyse the product change**, identify the *additional / underlying business logic and functional implications*, and **enhance & detail the request** for best-quality delivery. Documentation (BRD, SRS, user stories, business rulebooks, workflows, UI, technical docs, user guides) is kept accurate and current, not just before development and not just at final validation.

**Load this skill when the request contains any of these trigger phrases:**

- business change, feature request, new feature, change feature
- new requirement, update requirement, alter requirement, modify BRD, modify SRS
- change business logic, change workflow, change user story, change journey
- business rule, rulebook, BR-XX, new rule, amend rule
- UI change, user-facing change, user journey, user flow
- API change, new endpoint, change interface, config change
- "do I need to update the docs", "documentation impact", "what else changes if we do this"
- impact analysis, product change, requirements impact, scope impact

**When NOT to load this skill:**

- A pure cosmetic fix (rename, color, copy) with no behavior, API, config, or business-logic change → load `formatting` / `frontend-design`; Isabella still gets a brief notification but no full gate.
- A known bug with a known fix and no requirement change → apply debugging; Isabella is notified only if the fix reveals a discrepancy with approved requirements (see `requirements-authority`).
- Work that only touches delivery state (issue labels, MR state, cleanup) → no documentation gate.

If after loading this skill Emma judges a decision is a **business decision** (new objective, scope change, new business rule, priority change), stop and escalate to the human/stakeholder. Do not invent business facts.

---

## 2. The Two-Phase Gate

The gate has **two mandatory phases**. Neither may be skipped. Both are recorded in the structured handoff format (`agents/workflow/workflow.md` §Mandatory Handoff Format → Documentation Impact section).

### Phase 1 — Pre-development impact analysis (Emma leads, Isabella confirms)

This runs **before any implementation worktree is created** and **before Daniel/Sophia/Ethan/Jonathan begin work**.

#### Phase 1a — Product analysis & market research (Emma, as product manager)

1. **Emma receives the request** and analyses the *product change*, not just the implementation ask.
   - What user-facing behavior changes?
   - Which business rules / workflows / user journeys are affected or newly introduced?
   - Which API / data / config / architecture surfaces are touched?
   - Are there **additional / underlying functional changes** the request implies but does not state (edge cases, error flows, permission boundaries, state transitions, derived values, integrations, backward compatibility)?
   - Emma *enhances & details* the request: fills in the implied logic, clarifies ambiguity, and resolves scope before implementation.
2. **Emma conducts/reviews market research** as product manager to ensure the change is fully supported by surrounding features/logics:
   - Gather market context: user interviews, stakeholder input, competitive analysis, industry standards where applicable.
   - Identify all **related/surrounding features** that the change touches or depends on — upstream, downstream, and adjacent features.
   - Verify each surrounding feature/logic still aligns with, and fully supports, the proposed change. Surface any conflicts or missing prerequisite features as risks or dependencies.
   - Document the market/feature analysis (decision rationale, affected features, dependencies) as part of the issue record so the team can see *why* the change is scoped this way.
   - Do **not** silently add scope: if market research reveals a need for new surrounding features beyond the request, surface them as separate child issues for business approval.

#### Phase 1b — Team allocation analysis (Emma, as delivery coordinator)

3. **Emma analyses required team members** to allocate the best-fit roles *before* implementation begins:
   - Map the change to the roles needed (Daniel backend / Sophia frontend / Jonathan UX / Marcus architecture / Maya security / Victor performance / Ethan infrastructure / Olivia QA / Grace/Felix review).
   - Assign each deliverable to the role with the matching expertise; do not default to "any available person" for role-specific work (e.g., do not assign auth/security work to a general backend slot without Maya review).
   - Sequence assignments by dependency: architecture → UX design → implementation → QA → deployment; document the dependency chain and any cross-role handoffs.
   - Record role assignments in the issue/task plan with explicit success criteria per role (per `packs/planning.md` Required Outputs).

#### Phase 1c — Isabella confirmation (documentation)

4. **Emma advises Isabella** on documentation impact, naming each affected document class:
   - Factual (BRD, SRS, user stories, business rulebook, process flows, user journeys)
   - Descriptive (API docs, technical docs, configuration, deployment, user guides, README, CHANGELOG)
   - For factual documents: is this an *approved new/corrected/changed fact* (amend via `REQUIREMENTS-AUTHORITY.md`), or just implementation status (do NOT rewrite factual docs — see skill `requirements-authority`)?
5. **Isabella confirms and authors/updates the required documentation BEFORE development starts:**
   - Factual docs: only for approved requirement changes, via the amendment process; record decision provenance.
   - Descriptive docs: update to the planned (not yet implemented) behavior, flagged as "planned" where the code is not yet merged.
   - User stories / acceptance criteria: refine so Olivia's tests and Isabella's validation have a precise target.
   - Playwright screenshot requirements in the story are specified *now* (which screens/states to capture), so Isabella captures them after development.
6. **Isabella triggers Emma to proceed.** Only after Isabella's confirmation does Emma hand the request to Marcus (architecture) → Daniel/Sophia/… (implementation). Emma *monitors and orchestrates* team progress toward the documented goal, tracking that the work stays aligned with the enhanced request.
7. **Emma records the gate in the handoff** (Documentation Impact: YES/NO; factual impact YES/NO; Isabella notified = YES).

**Gate rule:** No worktree creation, no code, no design spec for an affected surface until Phase 1 (a–c) is recorded. Emma may assign the issue to an implementer only after Isabella's confirmation.

### Phase 2 — Post-development documentation revisit (Isabella leads, Emma retrospective)

This runs **after team development is complete** (implementation + reviews + tests green), **before Emma closes the issue**.

1. **Isabella revisits the documentation against the *implemented* reality**, not just the plan:
   - Factual docs still accurate? If implementation deviated from an approved requirement, this is a *discrepancy* — record it in GitLab with requirement/rule IDs and route to `requirements-authority` (fix code or propose amendment). Never silently rewrite.
   - Descriptive docs updated to reflect the merged behavior (API docs, config, deployment, README, CHANGELOG).
   - User guides updated with **actual Playwright screenshots** captured from the real UI (not mockups, not the pre-development "planned" placeholders).
   - Release notes / business-impact summary published.
2. **Isabella confirms documentation accuracy & quality** and hands back to Emma.
3. **Emma conducts a retrospective goal review** to confirm the deliverable actually meets the original request:
   - Compare the shipped deliverable against the original stakeholder request and goals documented in the issue.
   - Verify all original acceptance criteria (US-XXX/AC-YYY) are satisfied — not only the enhanced/implied ones Emma added in Phase 1.
   - Confirm no surrounding feature/logic was broken by the change (regression check against Phase 1a market research).
   - If goals are not met or gaps are found, hand back to the implementing role with specific gaps before closure.
4. **Emma closes the issue** only after Phase 2 passes, her retrospective goal review passes, the MR merge is verified via `mr-status`, and `issue-status closed` is run in the same session.

**Gate rule:** Emma MUST NOT label an issue `Done` or close it while Isabella's Phase 2 documentation revisit or Emma's retrospective goal review is outstanding or failing.

---

## 3. Documentation Impact Decision Matrix

Emma uses this to advise Isabella. Mark each row that applies; Isabella executes the marked classes.

| Change type | Factual docs (BRD/SRS/stories/rules/flows) | Descriptive docs | User guide / screenshots | Release notes |
|---|:---:|:---:|:---:|:---:|
| New / changed business requirement (approved) | ✅ amend | ✅ | ✅ | ✅ |
| New / changed business rule / workflow | ✅ amend rulebook + derived | ✅ | ✅ | ✅ |
| Purely descriptive change (new API, config, deployment) | ⬜ (no fact change) | ✅ | ✅ if user-facing | ✅ |
| UI / UX behavior change | ✅ amend user story/journey | ✅ | ✅ (re-capture) | ✅ |
| Edge case / error flow discovered | ✅ if it changes an approved fact | ✅ | ✅ | ⬜ unless user-facing |
| Cosmetic / copy only | ⬜ | ⬜ | ⬜ | ⬜ |

⬜ = not required. ✅ = required.

**If a factual document is marked "amend"**, load the `requirements-authority` skill and follow its amendment process — do not inline-rewrite.

---

## 4. Handoff Recording (Structured)

Every Phase 1 and Phase 2 handoff appends to the `Documentation Impact` section of the Mandatory Handoff Format:

```
### Documentation Impact
- **Requires documentation update?** YES / NO
- **Emma impact analysis performed:** YES (product change, implied logic, affected doc classes) / N/A
- **Factual requirements impact?** YES / NO — did behavior change vs an approved BRD/SRS/rule/user story/journey? If YES, list the requirement/rule IDs and the approved decision reference; do NOT edit those docs yourself (Isabella runs the amendment process per REQUIREMENTS-AUTHORITY.md).
- **Descriptive docs to update:** API docs / technical / config / deployment / README / CHANGELOG (list)
- **User guide / Playwright screenshots:** YES / NO (list screens)
- **Isabella notified + confirmed?** YES / NO
- **Market research + team allocation analysis:** YES / N/A — surrounding features/dependencies identified with rationale; best-fit roles assigned with dependency-sequenced plan
- **Emma retrospective goal review:** YES / N/A — original stakeholder request/goals confirmed achieved, all original AC satisfied, surrounding features/regressions checked
- **Phase 1 (pre-dev) gate recorded:** YES / N/A
- **Phase 2 (post-dev) revisit recorded:** YES / N/A / pending
```

Reviewers reject a handoff missing any of these fields.

---

## 5. Role Responsibilities

### Emma (gate orchestrator)
- Runs Phase 1 impact analysis on every business-change / feature request.
- **Product analysis & market research (as product manager):** analyses surrounding features/logics, gathers market context (user interviews, stakeholder input, competitive analysis, industry standards), verifies the change is fully supported by related features, documents decision rationale and dependencies; surfaces new feature needs as child issues for business approval rather than silently adding scope.
- **Team allocation analysis:** maps the change to required roles, assigns each deliverable to the best-fit role by expertise, sequences work by dependency, and records role assignments with explicit success criteria per role.
- Enhances & details the request: identifies implied business logic, edge cases, error flows, permission boundaries, state transitions, integrations, backward-compatibility concerns.
- Advises Isabella with the documentation impact decision (section 3 matrix).
- Monitors and orchestrates team progress toward the documented goal; keeps the enhanced request as the single alignment target.
- **Post-development retrospective goal review:** compares the shipped deliverable against the original stakeholder request/goals, verifies all original acceptance criteria are satisfied, confirms no surrounding feature/logic was broken by the change; hands back to implementing role with specific gaps if goals are not met.
- Does NOT close an issue while Phase 1 or Phase 2 is outstanding.
- Escalates to the human/stakeholder for any business decision (new objective, scope, new rule, priority).

### Isabella (documentation executor)
- Confirms Emma's impact analysis; authors/updates the required documentation *before development* (factual via `requirements-authority`; descriptive to the planned behavior).
- Refines user stories / AC / screenshot requirements so QA and validation have a precise target.
- Runs Phase 2 revisit *after development*: confirms accuracy/quality against the implemented reality; captures real Playwright screenshots; updates descriptive docs + release notes.
- Routes any implementation-vs-requirement discrepancy to `requirements-authority` (record in GitLab, fix code or propose amendment) — never silently rewrites factual docs.
- May reject features shipped without updated documentation, or with factual docs containing implementation status.

### Marcus / Jonathan / Daniel / Sophia / Olivia / Grace / Felix
- When their work reveals a new factual impact not in the request, stop and hand back to Emma (who re-runs Phase 1) rather than silently widening scope or rewriting requirements.

---

## 6. Verification

- **Phase 1 evidence:** Emma's impact analysis + market research + team allocation + Isabella's confirmation are all present in the issue record (GitLab) before any implementer worktree exists.
- **Phase 2 evidence:** Isabella's revisit + Playwright screenshots + descriptive doc updates are present before Emma labels `Done`.
- **Retrospective evidence:** Emma's original-goal review (original request/goals confirmed achieved, all original AC satisfied, surrounding-feature/regression check) is present in the issue record before closure.
- **Gate enforcement:** Reviewers reject a handoff missing the Documentation Impact fields. Emma's closure checklist includes "Phase 1 recorded" and "Phase 2 recorded/passing".
- **No factual drift:** Factual docs changed only via the `requirements-authority` amendment process; `python3 scripts/check-requirements-authority.py --staged` passes when factual docs are touched.
- **Enhancement quality:** The issue's AC list is more detailed than the user's raw request where implied logic / edge cases were identified (Emma's enhancement is visible in the task's GIVEN/WHEN/THEN).

## 7. Related Skills & Standards

- `requirements-authority` — factual-document governance (when to amend vs. record a discrepancy).
- `architecture-design` — when the change is architecturally significant (Marcus).
- `ux-design` / `frontend-design` — for UI surfaces Isabella screenshots and Emma details.
- `6_documentation_standards/DOC-STANDARDS.md` §9 Documentation Triggers.
- `6_documentation_standards/REQUIREMENTS-AUTHORITY.md` — factual amendment process.
- `agents/workflow/workflow.md` — Mandatory Handoff Format + workflow trigger chains (updated to reference this gate).
