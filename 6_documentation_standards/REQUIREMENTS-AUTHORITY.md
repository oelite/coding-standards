# Requirements Authority and Business Rulebook

> **Maintained by**: Isabella (Business Analyst)
> **Status**: Active
> **Load when**: Authoring, amending, reviewing, or auditing factual requirements; resolving a conflict with implementation.

## Document classes

| Class | Location/examples | Purpose | Update trigger |
|-------|-------------------|---------|----------------|
| Factual authority | `docs/business/BRD.md`, `SRS.md`, `rules/BR-*.md`, `user-stories/`, `process-flows/`, user journeys; business requirements in `.spec/` | Approved desired business behavior, system requirements, journeys, and acceptance criteria | An approved new, corrected, or changed fact/requirement, not a code change or delivery milestone |
| Implementation description | `docs/technical/`, API and configuration docs, user guides, README | Describe the actual system and how to operate it | Verified behavior, interface, deployment, or UI changes |
| Delivery evidence | GitLab issues/MRs, release notes, `docs/requirements-status.json` where adopted, audits and execution plans outside `docs/business/rules/` | Implementation state, gaps, verification, ownership, schedule, and release history | Work advances |

An unapproved draft is a proposal, not authority. Do not infer a new requirement from code, test output, market research, or a backlog item. Observed behavior that differs from approved requirements is a gap: record it in GitLab, and fix the implementation or propose a factual amendment. Never silently rewrite the requirement to match the code.

## Authority by subject

- **Business rules and business logic**: the approved business rulebook is the ultimate normative authority across BRDs, SRSs, stories, process flows, journeys, and developer interpretation. Each rule has a stable `BR-XX-NNN` ID. Other documents may reference or derive testable detail from it; they MUST NOT override or contradict it. A business-logic conflict is resolved in favor of the approved rulebook unless and until the rulebook itself is formally amended.
- **Business objectives, product scope, and business constraints**: the approved BRD is canonical for these subjects, and is constrained by the rulebook wherever business logic is involved.
- **System functional/nonfunctional contracts**: the approved SRS elaborates the system behavior required by the BRD and rulebook. It is authoritative for system-level detail only when that detail does not redefine or conflict with a business rule.
- **User experience and workflows**: approved stories, process flows, and journeys specify roles, steps, exceptions, and acceptance criteria derived from the BRD, SRS, and rulebook. They MUST agree with the rulebook; for business logic the rulebook prevails.
- **Delivery state**: GitLab is canonical for issue/MR state; a status register, if used, is a derived or separately maintained implementation view and never overrides a factual requirement.

If two approved sources conflict, the approved rulebook wins on business logic, but the conflicting passages still require reconciliation through a factual amendment. Stop the affected implementation decision and record the precise IDs and passages; Isabella coordinates with Emma and the business owner, with technical or security reviewers as relevant. Neither recency, code behavior, nor an agent's preference changes a rule. Where no rulebook exists, do not invent a rulebook priority or silently promote code to authority: use the approved BRD/SRS/story and seek a business decision for ambiguities.

## Factual amendment process

1. Record a GitLab change request with the proposed fact, rationale, affected requirement/rule IDs, source of the decision, affected journeys and tests, and backward-compatibility impact. A developer may propose but must not unilaterally authorize a business change.
2. Emma and the accountable stakeholder/product owner approve the business decision; Isabella authors or reviews the amendment. Marcus/Maya/Jonathan review technical, security, or UX consequences as appropriate. Do not mark a document Active until approval is evidenced in the linked change request/MR.
3. Change the canonical source first. Update derived documents and references in the same coordinated change or create explicitly linked follow-up issues before implementation proceeds. Keep stable IDs: deprecate/supersede instead of silently recycling an ID.
4. Record the decision reference, affected IDs, factual summary, date, approver, and document version in Change History. This is **requirements provenance**, not an implementation diary. Mere status changes do not bump factual-document versions or Last Updated dates.
5. Review the diff against the decision; reviewers reject status injection or unsupported changes. After approval, implement and verify against the updated facts. If implementation uncovers a new need, return to step 1.

Routine editorial corrections that do not change meaning may be proposed with an explicit no-semantic-change statement and Isabella review; they still must not include delivery progress. An audit is evidence of a discrepancy, not authorization to change the normative statement.

## Business rulebook format

**Location**: `docs/business/rules/BR-XX-<topic>.md`; index `docs/business/rules/README.md`. Rule IDs `BR-XX-NNN` are unique and stable across the repository. Keep the index navigational; put audits, status matrices, and execution plans outside `rules/` (prefer GitLab for task tracking). Do not require entire rulebooks in agent context: load the index and only the rule files/IDs cited by the scoped task.

```markdown
# BR-XX: <Business domain>

> **Maintained by**: Isabella (Business Analyst)
> **Status**: Draft | Active | Deprecated
> **Version**: <semantic-version>
> **Approved decision**: <GitLab change request / stakeholder decision reference>

## Scope
<Business context, actors, boundaries, and terms; no delivery state.>

### BR-XX-001: <Stable rule name>
<Normative, testable business behavior using MUST/SHOULD/MUST NOT as appropriate.>

- **Applies when**: <trigger and preconditions>
- **Outcome**: <expected state or decision>
- **Exceptions**: <explicit exception behavior>
- **References**: <BRD/SRS/story/journey IDs, where applicable>

## Change History
| Date | Version | Decision | Factual change and affected IDs | Approved by |
|------|---------|----------|---------------------------------|-------------|
```

The rule describes **what must be true**, including permitted transitional behavior only if it is itself an approved business requirement. It does not describe whether the current implementation meets it. A rule may cite an API contract when that contract is normative, but not a source-code path or an MR as evidence of completion.

## Content boundary and review

Factual documents MAY contain approved objectives, constraints, workflows, UX journeys, conditions, exceptions, measurable acceptance criteria, and factual decision provenance. They MUST NOT contain implementation progress, "gaps vs current code" tables, issue/MR status, developer assignment, sprint/points, branch names, code paths as completion evidence, test pass counts, release logs, or completion/sign-off checkboxes. Issue/MR references in Change History are allowed only as immutable **decision provenance**; project status belongs in GitLab or a separate delivery record. `Draft | Active | Deprecated` is document approval status, never feature status.

Review changed factual documents against the approved decision and canonical source. The scoped validator in `scripts/check-requirements-authority.py` catches clearly structured delivery markers, not semantic drift; Isabella and Emma must review meaning. Deploy the check and reviewer ownership into each product repo's CI/MR policy before claiming enforcement there. Legacy contamination is remediated in separate, reviewed changes: move evidence to delivery records without altering approved rule semantics.
