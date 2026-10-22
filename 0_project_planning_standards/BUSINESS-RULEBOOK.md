# OElite Platform Business Rulebook — Source of Authority Index

> **Repository**: coding-standards
> **Last Updated**: 2026-10-22
> **Maintained by**: Isabella (Business Analyst)
> **Status**: Active — index of authoritative business docs
> **Version**: 1.0.0

---

## Overview

This is the **platform-wide business rulebook hub** for OElite. It does not duplicate factual content from project repos; it points to each repo's authoritative business documents so PR authors and dev teams have a single place to resolve "which business document governs this repo?"

Rules of authority:

1. **Factual documents** (BRD, SRD/SRS, user stories, journeys, process flows, business rules `BR-XX-NNN`) are the authority for what features ARE and how they MUST behave. They change only via the amendment process in `6_documentation_standards/REQUIREMENTS-AUTHORITY.md`.
2. **Implementation state** (shipped? evidence? MR numbers?) must NOT live in factual docs. Where a repo document currently mixes them (e.g. `uranus/arc-cli/docs/business/RULEBOOK.md` ships-status columns), the factual content (features, rules, ACs) is authoritative and the status columns must migrate to GitLab (issue #68 audit finding).
3. If a repo has **no** `docs/business/` material, the platform templates in this folder (`0.1`–`0.5`) are the requirement for Isabella/Emma to author before development.

---

## 1. Business Features — By Repo

| Repo | Document | Status |
|------|----------|--------|
| helios/core | `docs/business/BRD.md`, `SRS.md` + 15 user stories | Authoritative, journeys missing |
| helios/kortex | `docs/business/BRD.md`, `SRS.md`, `rules/`, `process-flows/`, 51 user stories, requirements-coverage-matrix | Authoritative; `KORTEX_REMAINING_22_PERCENT_ACTION_PLAN.md`, `AUDIT-REPORT-77.md`, `AMENDMENTS-PENDING.md` in same folder mix delivery tracking with facts — TODO(owner): relocate |
| jupiter/apex | `docs/business/BRD.md` (1564 lines), `SRS.md` (122 lines — thinner than BRD), 286 user stories, `rules/`, `user-journeys/`, traceability-matrix, BRD-AMENDMENTS | Authoritative; SRS undersized vs story count — TODO(owner): reconcile SRS |
| jupiter/occ | `docs/business/BRD.md`, `SRS.md`, 28 user stories (US-001…US-050) | Authoritative |
| mercury/synapse | `docs/business/BRD.md`, `SRS.md`, 1 user story (single-file catalog) | Incomplete — stories not decomposed |
| uranus/arc-cli | `docs/business/RULEBOOK.md` (single combined rulebook + feature matrix), `USER-JOURNEYS.md` | Authoritative content; status/shipped columns violate requirement no. 2 above |
| uranus/hermes | `docs/business/BRD.md`, `SRS.md` (3166 lines), 166 user stories (multi-series IDs: US-0xx, US-3xx, US-5xx, US-44xx, US-A11Y/DR/PERF/TKN/ML/UX/NOTIF/SUB) | Authoritative; ID series inconsistent — TODO(owner): renumber scheme documented in BRD § ID scheme |
| uranus/origin-auth | `docs/business/BRD.md`, `SRS.md`, `rules/BR-01…BR-25` (incl. BR-23-AMENDMENTS), `rulebook/traceability-matrix.md`, `USER-STORY-CATALOG.md`, 60 stories | **Most mature rulebook in the platform — use this as the reference pattern** |
| uranus/orion | `docs/business/BRD.md`, `SRS.md`, 32 user stories | Authoritative |
| uranus/restpdf | `docs/business/BRD.md`, `SRS.md`, 21 user stories (US-001…US-021, API-first product) | Authoritative |
| venus/mellow | `docs/business/BRD.md`, `SRS.md`, 1 user story (US-001-initialization) + `docs/validation/` (BRD validation report, rulebook mapping, SRS gap analysis) | Incomplete — TODO(owner): decompose stories |
| venus/obelisk | `docs/business/BRD.md`, `SRS.md`, 43 stories, 4 rulebook-related docs, `BRD-AMENDMENTS.md`, `BRD-GAP-ANALYSIS-v2.md` | Authoritative; progress content must move to GitLab |
| venus/obelisk-runtime | `docs/business/BRD.md`, `SRS.md`, 43 stories, process flows | Authoritative |

FF (API/reference): `uranus/restpdf` user stories reference API behavior directly.

## 2. Business Logic & Rules

Per-repo rule files follow (or should follow) `6_documentation_standards/REQUIREMENTS-AUTHORITY.md`: location `docs/business/rules/BR-XX-<topic>.md` with stable IDs.

| Repo | Rules directory | Notes |
|------|-----------------|-------|
| uranus/origin-auth | `docs/business/rules/BR-01…BR-25` | Canonical example: identity, tenancy, authn/OIDC/SAML/SCIM, MFA, sessions, audit, crypto, billing, branding, GDPR, mobile |
| helios/kortex | `docs/business/rules/` | Directory exists; Browse TODO(owner) to verify BR-XX coverage vs SRS |
| jupiter/apex | `docs/business/rules/` | Directory exists; TODO(owner): BR numbering audit |
| venus/obelisk | `docs/business/RULEBOOK-*.md` (pattern-extraction, enhancement-plan) | TODO(owner): migrate into `rules/BR-XX` structure |
| All others | — | TODO(owner): create `rules/` per DOC-STANDARDS |

## 3. Workflows

| Repo | Source |
|------|--------|
| helios/kortex | `docs/business/process-flows/` |
| venus/obelisk, obelisk-runtime | `docs/business/` process flows (2 each, confirmed via journey listing) |
| All others | TODO(owner): document end-to-end workflows in `docs/business/process-flows/` |

## 4. UI User Journeys

| Repo | Source | Notes |
|------|--------|-------|
| jupiter/apex | `docs/business/user-journeys/` | Full set |
| uranus/arc-cli | `docs/business/USER-JOURNEYS.md` | Single file |
| uranus/origin-auth | journeys referenced in `rulebook/traceability-matrix.md` | TODO(owner): verify per-journey files |
| venus/obelisk(±runtime) | 2 journeys each | TODO(owner): verify completeness |
| helios/core, jupiter/occ, uranus/orion, restpdf, hermes, synapse, mellow | — | MISSING — blocks journey-based e2e testing (Principles § Quality Gate 11) |

## 5. Operation Expectations (SLOs, permissions, audit)

Platform-wide baselines come from `agents/core/principles.md` (security: origin-auth RS256 JWT, Argon2id, AES-256 field encryption; e2e quality gates; integration testing on shared stack).
Per-repo operational SLO tables: **TODO(owner)** — none of the audited repos currently carries a dedicated SLO section in `docs/business/`. Audit logging requirements exist in cadence within origin-auth BR-12 and each repo's SRS where written.

## 6. Traceability Matrix — Platform

Traceability is per-repo (the matrix maps stories ↔ ACs ↔ journeys ↔ tests within a repo). Existing matrices:

| Repo | Traceability location | Confidence |
|------|----------------------|------------|
| uranus/origin-auth | `docs/business/rulebook/traceability-matrix.md` | High |
| jupiter/apex | `docs/business/traceability-matrix.md` | Present — TODO(owner): refresh |
| venus/obelisk-runtime | story/e2e-linked (verified via docs structure) | Medium |
| All others | — | TODO(owner): build matrix from BRD + USER-STORIES.md |

---

## Audit Findings (issue #68, 2026-10-22)

### Spot-check accuracy results

| Check | Document claim | Verified finding | Evidence |
|-------|---------------|------------------|----------|
| arc-cli BF-004 | `arc run` dispatched "case \"run\" (line 274)" in `v2/cli/src/index.ts` | ✅ Feature exists and is real, ❌ line ref is stale | actual location is line 320 |
| arc-cli BF-001/002 | Anthropic + OpenAI provider adapters | ✅ Accurate | `uranus/arc-cli/v2/core/src/providers/{anthropic,openai}-provider-adapter.ts` exist |
| jupiter/occ US-001 | Product catalog management feature | ✅ Accurate | UI routes exist at `src/app/[lang]/dashboards/products/` (list, create, [id]) |
| origin-auth ruleset | 25 business rule files incl. amendments | ✅ Accurate | `docs/business/rules/` BR-01…BR-25 present |
| kortex folder hygiene | Factual folder contains delivery-plan docs | ❌ Violation of REQUIREMENTS-AUTHORITY | `KORTEX_REMAINING_22_PERCENT_ACTION_PLAN.md`, `AUDIT-REPORT-77.md` beside BRD/SRS |

### Audit pattern-to-fix list

1. **Line-number / SHA evidence rot**: docs pinning exact lines scroll; reference symbols or files instead.
2. **Implementation-status in factual docs**: kortex, obelisk, arc-cli rulebook status columns — migrate to GitLab.
3. **Missing user journeys**: helios/core, jupiter/occ, uranus/orion, restpdf, hermes, synapse, mellow.
4. **Undecomposed single-file story catalogs**: synapse, mellow.
5. **No per-repo SLO sections**: all repos — TODO(owner).

---

## Gaps Blocking "Complete All Business Requirements" (Prioritized)

| # | Gap | Blocks |
|---|-----|--------|
| 1 | No BRD/SRS/docs at all in: helios/nexus, helios/compass, helios/oesterling, jupiter/ec-nx-01, jupiter/ec-std-01, jupiter/bizsmart, jupiter/apps-ec-store, jupiter/apps-biz-suite, mercury/runners/*, venus/sip, venus/stela | Entire feature scope of those repos is un-governable — highest priority for Isabella/Emma authoring sprints |
| 2 | Two repos with incomplete story decomposition (synapse, mellow) | worktree-level e2e test matrices |
| 3 | User journeys missing in above 7+ repos | journey-based e2e testing, user-guide accuracy gates |
| 4 | No per-repo SLO / operation expectations | "complete" cannot be defined for feaures relying on availability/perf rules |
| 5 | Mixed factual+delivery content in 3 doc sets (kortex, obelisk, arc-cli rulebook status) | trustworthy audit / REQUIREMENTS-AUTHORITY compliance |
