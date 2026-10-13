# Requirements Authority

## Purpose
Protect approved business and product requirements from implementation-progress churn while allowing purposeful, approved factual amendments.

## When to Load
Load when creating, changing, reviewing, auditing, or reconciling BRDs, SRSs, business rulebooks, requirements in `.spec/`, user stories, user journeys, or process flows. For routine implementation work that does not touch these files, use only the short guardrail in `agents/core/principles.md`.

## Standards & Rules
The canonical policy is `6_documentation_standards/REQUIREMENTS-AUTHORITY.md`. Read only the relevant sections and cited requirement IDs; do not load every business document into context. Summary:

- Approved rules in a business rulebook are authoritative for business logic; BRD for objectives/scope; SRS for system requirements; approved stories/journeys for user workflows and acceptance criteria. These sources must agree.
- Code, tests, issues, MRs, or implementation progress never authorize changing requirements. Report implementation gaps in GitLab/delivery records. For a conflict or ambiguity, stop and seek a business decision.
- Amend facts only for a proposed and approved factual change; record rationale, decision provenance, affected IDs, review/approval, and reconcile derived documents. Isabella owns authoring/review; Emma and the accountable stakeholder approve.
- Keep implementation status, code paths, test results, assignments, schedules, and release evidence out of factual documents. A factual change log records requirement decisions, not delivery events.
- Load only the scoped rule IDs/files. Never ingest a complete rulebook by default.

## Verification
Run `python3 scripts/check-requirements-authority.py --staged` before committing changes to factual requirements. Review meaning and approval provenance manually; the validator is a narrow tripwire, not a semantic approval engine. See `6_documentation_standards/REQUIREMENTS-AUTHORITY.md` for full policy and examples.
