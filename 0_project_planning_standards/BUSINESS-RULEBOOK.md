# OElite Platform Business Rulebook — Source of Authority Index

> **Repository**: coding-standards
> **Last Updated**: 2026-11-02
> **Maintained by**: Isabella (Business Analyst)
> **Status**: Active — index of authoritative business docs; § 5 numeric SLOs ratified (2026-11-02); § 7.1 Release Management is Draft pending approval; § 8 Platform-Wide Developer Experience is Draft pending approval
> **Version**: 1.3.0

---

## Overview

This is the **platform-wide business rulebook hub** for OElite. It does not duplicate factual content from project repos; it points to each repo's authoritative business documents so PR authors and dev teams have a single place to resolve "which business document governs this repo?"

Rules of authority:

1. **Factual documents** (BRD, SRD/SRS, user stories, journeys, process flows, business rules `BR-XX-NNN`) are the authority for what features ARE and how they MUST behave. They change only via the amendment process in `6_documentation_standards/REQUIREMENTS-AUTHORITY.md`.
2. **Implementation state** (shipped? evidence? MR numbers?) must NOT live in factual docs. Where a repo document currently mixes them (e.g. `uranus/arc-cli/docs/business/RULEBOOK.md` ships-status columns), the factual content (features, rules, ACs) is authoritative and the status columns must migrate to GitLab (issue #68 audit finding).
3. If a repo has **no** `docs/business/` material, the platform templates in this folder (`0.1`–`0.5`) are the requirement for Isabella/Emma to author before development.
4. **Platform-wide capabilities** (not owned by any single product repo) are documented directly in this file — see § 7 (Platform-Wide Release Management, § 7.1 / BR-REL) and § 8 (Platform-Wide Developer Experience, § 8.1 / BR-DEV).

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
| uranus/hermes | `docs/business/rules/` (BR-01…BR-32, indexed by `rules/README.md`), `traceability-matrix.md`, 166 user stories (multi-series IDs: US-0xx, US-3xx, US-5xx, US-44xx, US-A11Y/DR/PERF/TKN/ML/UX/NOTIF/SUB) | Rulebook `docs/business/rules/` is the **normative authority** (BRD Deprecated; SRS elaborates the rulebook; BR-23 checklist is a validation aid); ID series inconsistent — known duplicate-ID debt documented in `docs/business/user-stories/README.md` |
| uranus/origin-auth | `docs/business/BRD.md`, `SRS.md`, `rules/BR-01…BR-25` (incl. BR-23-AMENDMENTS), `rulebook/traceability-matrix.md`, `USER-STORY-CATALOG.md`, 60 stories | **Most mature rulebook in the platform — use this as the reference pattern** |
| uranus/orion | `docs/business/BRD.md`, `SRS.md`, 32 user stories | Authoritative |
| **uranus/evitale** | `docs/business/BRD.md`, `SRS.md`, `rules/BR-EVT-*.md` (43 rules incl. BR-EVT-050/115/116/206/204), `process-flows/WF-01..08`, `user-stories/US-101..153.md` (15 stories), `AMENDMENTS-2026-10.md` (post-dev, v2.0.0) | Authoritative for business logic; post-dev documentation revisit complete (evitale#16); **Phase 3.1 media pipeline audit complete** (evitale#35 — BR-EVT-050/204 authored, DEC-19 noop posture clarified, api-design.md/media pipeline documented); architecture/API-contract detail in repo `docs/architecture/` |
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
**Numeric platform SLOs** — ratified (MR !113 / DOS §7 pending-ratification note resolved). These SLOs are platform commitments owned by Ethan (DevOps & Reliability) and measured via GitLab Environments/Deploy Boards, `kubectl rollout status`, and Orion alerts, with evidence recorded on release issues per DOS §4.

| # | SLO | Ratified target | Measurement method | Owner | Review cadence |
|---|-----|-----------------|--------------------|-------|----------------|
| 1 | Deploy success rate (deploy_uat / deploy_prod) | ≥ 99% of jobs reach rollout-status success | GitLab Deploy Board rollout state + `kubectl rollout status` exit code, per deploy job | Ethan | Sprint review |
| 2 | Production rollback time | ≤ 30 minutes from authorization | Time from human authorization on release issue to `kubectl rollout undo` completion, recorded on REL issue | Ethan | Per incident + sprint review |
| 3 | UAT rollback time | ≤ 15 minutes from authorization | Time from human authorization on release issue to `kubectl rollout undo` completion | Ethan | Per incident + sprint review |
| 4 | Post-deploy health checks | Run within 5 minutes of rollout completion | Health-check result timestamp vs rollout-completion timestamp on release issue comment (DOS §4) | Ethan / deploying agent | Every deploy + sprint review |
| 5 | Existing peer SLAs (ratified) | 4h ack / 1 business-day recovery (UAT peer availability) | Orion availability monitoring + incident ack/recovery timestamps (UAT-AVAILABILITY-RUNBOOK §3) | Ethan | Daily during release week |

**Deltas from DOS §7 proposal**: none — all values ratified as proposed in DEPLOYMENT-OBSERVABILITY-STANDARD.md §7. DOS §7 SLOs cover rollout-failure detection/acknowledgment targets (≤10 min detection, ≤1 h prod / ≤4 h UAT acknowledgment, same-session health evidence, ≥1 business-day UAT soak) which remain **targets** in DOS; the ratified platform SLOs above narrow them to measurable commitments.

**Change History (this section):**
- 2026-11-02: SLOs ratified in § 5 (Isabella). Resolves DOS §7 "PROPOSED, PENDING RATIFICATION" note (MR !113); closes watch item 1 of issue #67 baseline. Values ratified as-proposed with zero deltas.

UAT peer availability for local development: see § 8.2 Operational Expectations (`rules/BR-DEV-001-local-peer-integration.md`).

## 6. Traceability Matrix — Platform

Traceability is per-repo (the matrix maps stories ↔ ACs ↔ journeys ↔ tests within a repo). Existing matrices:

| Repo | Traceability location | Confidence |
|------|----------------------|------------|
| uranus/origin-auth | `docs/business/rulebook/traceability-matrix.md` | High |
| jupiter/apex | `docs/business/traceability-matrix.md` | Present — TODO(owner): refresh |
| venus/obelisk-runtime | story/e2e-linked (verified via docs structure) | Medium |
| All others | — | TODO(owner): build matrix from BRD + USER-STORIES.md |

## 7. Platform-Wide Release Management

The rulebook's primary role is an index of per-repo business documents. Some capabilities, however, are **platform-wide by nature** — they are not features of any single product repo but govern how the platform itself operates and delivers. These are documented here directly as normative business rules, with stable `BR-REL-NNN` IDs. The engineering counterpart (branch mechanics, CI job syntax, CLI commands) lives in `5_git_workflow_standards/GIT-WORKFLOW-STANDARDS.md` (§2.1.2 Promotion Gates, §2.1.3 Rollback Standard, §8.7 Release Issue Lifecycle); where this section and that document could appear to differ, both agree by construction — this section states the business rule, that document its engineering enforcement.

> **Numbering note (issue #98)**: this section was introduced by MR !109 as a second `## 6.` heading, duplicating § 6 Traceability Matrix. It is renumbered to § 7 (and its subsection § 7.1) so section numbers are unique and sequential. § 8 (Platform-Wide Developer Experience) is appended after it.

## 7.1 Release Management (BR-REL)

> **Maintained by**: Isabella (Business Analyst)
> **Status**: Draft — pending approval per REQUIREMENTS-AUTHORITY.md amendment process
> **Version**: 1.0.0
> **Approved decision**: pending — TASK-94 / issue #94 change request

### Scope

Release Management is the platform-wide business capability covering **how software moves from development to production**. It defines who may promote code, under what business conditions a release may proceed, who validates it, and what happens when a release must be withdrawn.

**Actors**: Ethan (infrastructure / promotion execution), Emma (orchestration and closure), Olivia (UAT quality validation), Isabella (UAT business validation), Marcus (standards/architecture review), the human business owner (Production authorization).

**Engineering source**: `GIT-WORKFLOW-STANDARDS.md` §2.1.2 (promotion chain and gates), §2.1.3 (rollback standard), §8.7 (release issue lifecycle).

### BR-REL-001: Environment Promotion Chain

Software MUST move through environments in the fixed order **development → UAT → Production**, via promotion MRs (`feature/* → develop → uat → main`). No code MAY reach Production that has not been deployed to and validated in UAT first.

- **Applies when**: any deployable change is promoted toward a customer-visible environment.
- **Outcome**: production receives only UAT-validated code.
- **Exceptions**: none. The chain has no bypass path.

### BR-REL-002: Source-Branch Restrictions

Promotion MRs MUST respect fixed source-branch rules: an MR targeting `uat` MUST originate from `develop`; an MR targeting `main` MUST originate from `uat`. Any other source branch is a workflow violation and MUST be rejected.

- **Applies when**: a promotion MR is created or reviewed.
- **Outcome**: branch topology is uniform and machine-checkable.

### BR-REL-003: UAT Soak Gate

An MR promoting code to Production (`uat → main`) MUST NOT merge until: (a) the UAT deployment pipeline is green, (b) the UAT health check passed, and (c) both **Olivia (quality validation)** and **Isabella (business validation)** sign-offs are recorded on the release issue.

- **Applies when**: a `uat → main` release MR is prepared for merge.
- **Outcome**: two independent UAT validations (quality + business) gate every production release.
- **Exceptions**: see BR-REL-006 (soak compression requires recorded human business-owner authorization).

### BR-REL-004: Artifact Continuity

Docker images are built exactly once, tagged with the commit SHA at merge to `develop`, and that same SHA-tagged image is deployed to every subsequent environment. Production MUST NOT deploy an image that was never deployed to UAT; Production deploy MUST fail closed when this check fails.

- **Applies when**: images are built, promoted, or deployed to any environment.
- **Outcome**: the artifact validated in UAT is bit-identical to the artifact deployed in Production.

### BR-REL-005: Release Issue Lifecycle (REL-XXX)

Every release MUST be tracked by a release issue (REL-XXX) created at promotion time. Olivia's and Isabella's UAT sign-offs are recorded as comments on this issue (canonical location). The release issue moves: **In Progress** (upon `develop → uat` promotion, Ethan) → **Ready to Merge** (UAT soak gate satisfied, Olivia + Isabella sign-offs recorded) → **Done + Closed** (Production deploy verified and post-deploy health check passed, Emma).

- **Applies when**: a release is orchestrated.
- **Outcome**: a single, auditable record of who validated what, and when.

### BR-REL-006: UAT Soak Compression Exception

The UAT soak gate (BR-REL-003) MAY be compressed ONLY with **explicit human business-owner authorization, recorded on the release issue**. A soak gate MUST never be skipped silently. An unauthorized skip is a workflow violation and the release MUST be rolled back to the last known-good state pending review.

- **Applies when**: the business owner elects to release before the full UAT soak period.
- **Outcome**: exceptional, audited, business-authorized acceleration — never a silent engineering shortcut.

### BR-REL-007: Rollback Authority and Procedure

Every deployable service MUST support rollback to the last known-good release. **Ethan executes rollbacks**; **the human business owner (or Emma's delegate) authorizes Production rollbacks**. UAT rollbacks are at Ethan's discretion. Rollback uses immutable SHA-tagged images via `kubectl rollout undo`, and forward-only DB migrations require a recorded compensating migration before a release MR merges — an app MUST NOT be rolled back past an unreversed breaking migration.

- **Applies when**: a release causes a Production or UAT incident.
- **Outcome**: fast, authorized, structurally safe withdrawal of a bad release.

### Ownership summary

| Step | Owner |
|------|-------|
| Promotion MR creation and deploy execution (develop→uat, uat→main) | Ethan |
| Release orchestration, promotion MR verification, release issue closure | Emma |
| UAT quality-validation sign-off on the release issue | Olivia |
| UAT business-validation sign-off on the release issue | Isabella |
| Standards/architecture review of promotion-gate changes | Marcus |

### Workflow: WF-REL-01 Release & Promotion

Step-by-step business flow from a merged feature to a verified production deploy:

| # | Step | Owner | Gate / Outcome |
|---|------|-------|----------------|
| 1 | Feature MR merged to `develop` after review + CI green (standard §8 lifecycle) | Implementing agent → reviewer | `develop` pipeline green; image tagged with merge commit SHA |
| 2 | Release issue (REL-XXX) created at promotion time | Ethan or Emma | REL issue exists with release notes |
| 3 | Promotion MR `develop → uat` created, referencing the REL issue | Ethan | MR targets `uat` from `develop` only (BR-REL-002) |
| 4 | UAT deployment pipeline runs and succeeds on the `uat` branch | CI (Ethan verifies) | Same SHA-tagged image deployed to `oelite-uat` (BR-REL-004) |
| 5 | UAT health check passes | Ethan | Health endpoint / `./oelite-stack.sh cluster UAT health` |
| 6 | Olivia records UAT quality-validation sign-off **on the REL issue** | Olivia | Comment evidence on REL issue |
| 7 | Isabella records UAT business-validation sign-off **on the REL issue** | Isabella | Comment evidence on REL issue |
| 8 | REL issue transitions to `Ready to Merge` once soak gate satisfied (BR-REL-003) | Ethan or Emma (reviewer) | Both sign-offs verified on the REL issue |
| 9 | Release MR `uat → main` created and merged | Ethan | MR targets `main` from `uat` only (BR-REL-002); Production deploy is manual (`when: manual`) |
| 10 | Production deploy verified (`mr-status` confirms merge) and post-deploy health check passed | Ethan | Deploy of a SHA never deployed to UAT fails closed (BR-REL-004) |
| 11 | REL issue → `Done` + Closed in the same session as verification | Emma | Per §8.7 / §8.2.2 closure rule |
| 12 | (Exceptional path) Soak compression authorized in advance by the human business owner, recorded on the REL issue | Human business owner → Emma | BR-REL-006 |
| 13 | (Incident path) Rollback executed on Production authorization; incident and follow-up recorded on the REL issue | Ethan, authorized by human business owner / Emma's delegate | BR-REL-007 |

**Marcus's role**: standards/architecture review of the promotion-gate mechanism itself (branch rules, CI gate syntax, artifact-continuity checks). He is not a per-release approver.

### UI User Journeys

**N/A** — Release Management is an operator-facing capability, not a consumer feature. There is no end-user UI journey; the "interface" is the promotion MR chain and the release issue record. Per-repo product features that ship through this process have their own journeys in their own `docs/business/` folders.

### Operational Expectations

Per-repo operational SLO tables remain a known gap (platform SLOs ratified in § 5; per-repo tables TODO). Release-specific expectations:

- **Release cadence**: releases are sprint-aligned (sprint-N releases per §2.1.2 traceability rule); ad-hoc releases are permitted for hotfixes following the same chain.
- **Rollback time**: rollback MUST be executable via `kubectl rollout undo` within minutes of a confirmed Production incident; ratified SLOs are Production ≤30 min / UAT ≤15 min from authorization (BUSINESS-RULEBOOK § 5, MR !113 ratification).
- **Deploy reliability**: a production deploy of a SHA not previously deployed to UAT MUST fail closed, by construction (BR-REL-004), not by vigilance.

---

## 8. Platform-Wide Developer Experience

**Maintained by**: Isabella (Business Analyst)
**Status**: Draft — pending approval per `6_documentation_standards/REQUIREMENTS-AUTHORITY.md` amendment process
**Version**: 1.0.0
**Change request**: TASK-97 / issue #97 (UAT peer-integration profile for local dev environments)

### Scope

Platform-Wide Developer Experience is the platform capability covering **how developers run OElite applications locally while integrating with peer platform services**. It defines which peers a local environment may reach, under which integration profile, with which credentials and mutation boundaries — so local development is predictable, safe, and isolated from Production by construction.

**Actors**: developers (local environment owners), Ethan (peer registry + UAT peer availability), Daniel (app configuration pattern implementation), Isabella (business documentation and validation), Marcus (architecture review), Maya (security/permission boundary review), Emma (orchestration and approval).

**Engineering source**: `1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md` (local shared data stack), the peer endpoint registry (`infrastructure/oelite-stack/config/peer-registry.yml` — Ethan's implementation), the `peers-health` utility, and the .NET `appsettings.init.json` integration-profile pattern.

### 8.1 Business Rules (BR-DEV)

Full normative text: `0_project_planning_standards/rules/BR-DEV-001-local-peer-integration.md`.

| ID | Rule (summary) |
|----|----------------|
| BR-DEV-001 | **Local Data Isolation** — an app's own data layer connects ONLY to the local shared stack (`localhost:*`); never to UAT/Prod data stores. Prod isolation is incident-level with no exceptions. |
| BR-DEV-002 | **UAT Peer Opt-In** — local dev reaches UAT peers ONLY via the explicit `uat-peers` profile; the platform default is `local-peers` (fail-safe). |
| BR-DEV-003 | **Central Peer Registry** — peer endpoints resolve from the central versioned registry (`peer-registry.yml`); profile resolution order is per-peer env var → appsettings per-peer → global `OELITE_PROFILE` → app default → platform default. Production endpoints are not resolvable through this chain (structural prod-prevention; fail-closed domain-pattern guard, no CI exception). |
| BR-DEV-004 | **Credential Isolation** — UAT peer credentials live in per-machine Keychain or gitignored secret files; never committed. Developers hold read-only or tenant-scoped UAT credentials only — no admin/service-root credentials on dev machines. |
| BR-DEV-005 | **UAT Data Respect** — local dev treats UAT peer data as shared acceptance data: reads permitted; writes only via the reserved test patterns (Origin Auth: dedicated `dev-<username>-local` IAM client; peer records: `dev-<username>-` identifier prefix). Any other mutation is prohibited. |
| BR-DEV-006 | **Fail Fast on Peer Unavailability** — when a required UAT peer is unavailable under the `uat-peers` profile, local dev FAILS FAST with a clear error naming the peer and the `peers-health` command. No mock/local fallback, no silent degradation. `peers-health` pre-flight is the prevention mechanism. |

### 8.2 Operational Expectations

- **UAT peer uptime**: UAT peers target 99% availability (best-effort, shared); availability is Ethan-owned, monitored via Orion. Local dev is NOT an availability SLO consumer of last resort — a down peer fails fast (BR-DEV-006) rather than degrading.
- **Stability window**: UAT peer endpoints MUST be stable for at least 5 consecutive business days per deploy cycle (aligns with the UAT soak gate, BR-REL-003) — no silent endpoint churn; changes go through the versioned registry via reviewed MR.
- **Rotation cadence**: registry endpoint/version changes are sprint-aligned; credential rotation follows the secrets-handling rules in `agents/core/principles.md` (§ Security & Best Practices — no committed secrets, Keychain/K8s-secrets storage) with `peers-health --auth` validation.
- **Recovery**: a failed UAT peer deployment is recovered within 4 hours during business hours, 1 business day otherwise (Ethan-owned runbook); local developers are notified via the standard UAT availability channel.

#### V2 Short-Lived Dynamic Credentials — Operational Expectations

*Added per TASK-99 (issue #99, joint Emma + Ethan design sign-off, note 58524). Applies when a peer's registry entry sets `credentials.mode: dynamic`; the static Keychain path remains the platform default.*

- **Rotation shift**: in dynamic mode, peers carry **no long-lived per-peer app secrets** — the 90-day app-credential rotation no longer applies to them. The rotation obligation moves to the **bootstrap IAM client** (`dev-<username>-local`, one per developer machine), which keeps the existing 90-day Keychain-held rotation cadence. Infra credentials (shared-stack data stores) are explicitly out of scope and stay on their own SLAs (cf. #37).
- **UAT realm monitoring (Ethan-owned)**: token-issuance rate and UAT realm audit-log volume are monitored as an operational expectation. Expected load is ~1 token request per developer per peer per ~12 min of active UAT work; a sustained anomaly (issuance spikes, unexpected client attribution) is treated as a security signal and escalated to Maya. Audit logs gain per-developer attribution via `dev-<username>-local`.
- **CI pipeline-scoped clients**: hermetic CI (`mock-peers`) **never mints tokens**. Integration-category jobs touching UAT peers use a **pipeline-scoped per-project IAM client** (never a developer client), same registry-declared scopes, same ≤ 15 min TTL, **minted per job run and never cached across jobs**. `uat-peers` keeps `allowedInCi: false` for developer configuration; CI UAT access is a separate explicit per-pipeline opt-in.
- **Staged rollout**: migration is per-peer via the registry `credentials.mode` field (`static` | `dynamic`), **default `static`** — no forced migration. `peers-health --auth` validates the mint path (and reports TTL remaining) for dynamic peers, keeping `peers-health` the single diagnostic surface. Mint/refresh failure fails fast per BR-DEV-006.

### 8.3 Business Features (BF-DEV)

| ID | Feature | Outcome |
|----|---------|---------|
| BF-DEV-001 | Integration profiles (`mock-peers`, `local-peers`, `uat-peers`) with per-peer overrides | Developers choose isolation level per service, not just per environment |
| BF-DEV-002 | Central versioned peer endpoint registry (all 9 peer services: Origin Auth, Kortex, Nexus, OeSterling, Apex, Synapse, Obelisk, Hermes, Orion) | One review point and one drift source for peer endpoints |
| BF-DEV-003 | `peers-health` pre-flight check (reachability, version, `--auth` credential validation, `--strict` mode) | Peer problems surface before the app starts, not mid-task |
| BF-DEV-004 | `appsettings.init.json` integration-profile pattern with startup fail-fast validation | Misconfiguration fails at startup with an explicit message, never silent localhost defaults |
| BF-DEV-005 | Structural production prevention (fail-closed domain-pattern guard + CI lint + registry schema without prod fields) | Production is unreachable from local dev by construction |

### 8.4 Workflows (WF-DEV)

| ID | Workflow | Steps (summary) |
|----|----------|-----------------|
| WF-DEV-001 | **Onboard a repo to peer integration** | Add `integrationProfile` block to `appsettings.init.json` (default `local-peers`) → configure per-peer profile if needed → run `peers-health` → record registry MR if the repo is itself a peer. |
| WF-DEV-002 | **Run a UAT peer-integration session** | `peers-health` pre-flight → start app with `uat-peers` (opt-in) → work within BR-DEV-005 write patterns → shut down; any dev-created UAT data is identifiable for purge. |
| WF-DEV-003 | **Respond to UAT peer outage** | App fails fast (BR-DEV-006) → developer checks `peers-health` and the UAT availability channel → escalation to Ethan (recovery SLO above) → resume after health check passes. |

### 8.5 UI User Journeys

**N/A** — Developer Experience is a developer-facing capability with no end-user UI. The "interface" is the integration-profile configuration, the `peers-health` CLI, and the peer registry MR process.

### Cross-references

- `1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md` — the local shared data stack that BR-DEV-001 requires for an app's own data layer.
- `6_documentation_standards/REQUIREMENTS-AUTHORITY.md` — amendment process governing this section and the BR-DEV rule file.
- `agents/core/principles.md` (§ Security & Best Practices) — secrets-handling baseline referenced by BR-DEV-004 / § 8.2.

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
| 4 | No per-repo SLO / operation expectations | "complete" cannot be defined for features relying on availability/perf rules |
| 5 | Mixed factual+delivery content in 3 doc sets (kortex, obelisk, arc-cli rulebook status) | trustworthy audit / REQUIREMENTS-AUTHORITY compliance |
