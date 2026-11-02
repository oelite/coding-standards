# BR-DEV-001 — Local Peer Integration (UAT Peer-Integration Profile)

> **Maintained by**: Isabella (Business Analyst)
> **Status**: Active
> **Version**: 1.0.0
> **Change request**: TASK-97 / issue #97 — UAT peer-integration profile for local dev environments
> **Rulebook anchor**: `BUSINESS-RULEBOOK.md` § 8 (Platform-Wide Developer Experience)
> **Change History**:
> - 1.0.0 — Approved on merge of the TASK-97 MR; status set to Active (per retrospective audit corrections).

---

## 1. Scope

This rule file defines the business rules for **how local development environments integrate with peer OElite platform services** (Origin Auth, Kortex, Nexus, OeSterling, Apex, Synapse, Obelisk, Hermes, Orion) via UAT endpoints, while keeping each application's **own data layer** on the **local shared stack**.

It exists so that:

- local development is **predictable** (endpoints come from one versioned registry, not tribal knowledge),
- local development is **safe** (production is unreachable by construction; UAT writes are bounded),
- local development is **isolated** (an app's own data never leaves the developer's machine).

**Actors**: developers (local environment owners), Ethan (peer registry + UAT peer availability), Daniel (app configuration pattern), Marcus (architecture arbitration), Maya (permission-boundary review), Isabella (business validation), Emma (orchestration).

**Engineering counterparts** (these carry the mechanisms; this file states the business rules):

- `1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md` — local shared data stack (BR-DEV-001 target).
- Central peer endpoint registry: `infrastructure/oelite-stack/config/peer-registry.yml` (Ethan's deliverable under #97).
- `peers-health` utility (reachability + version + `--auth` + `--strict`).
- .NET `appsettings.init.json` integration-profile pattern (Daniel's deliverable under #97).
- Engineering standard document: `1_dotNet_coding_standards/17-LOCAL-DEV-PEER-INTEGRATION.md` (profile/registry mechanics).

**Terminology alignment** (per Marcus's arbitration on #97): profile names (`mock-peers` / `local-peers` / `uat-peers`) are engineering vocabulary; BR-DEV-001..006 are the business rules. Each BR-DEV rule cites the profile or mechanism that enforces it. Neither side renames the other.

---

## 2. Business Rules

### BR-DEV-001: Local Data Isolation

An application's **own data layer** (databases, caches, object storage, queues used to persist the app's domain data) MUST connect ONLY to the **local shared stack** (`localhost:*`, per `16-SHARED-LOCAL-INFRASTRUCTURE.md`). It MUST NOT connect to UAT or Production data stores under any integration profile.

- **Applies when**: any local dev run, under any profile (`mock-peers`, `local-peers`, `uat-peers`).
- **Outcome**: developer work never reads or mutates shared acceptance/production data through the app's own persistence.
- **Exceptions**: none. Violations are treated as **incidents** (report to Emma + Ethan), not style issues. The prod-prevention guard (BR-DEV-003 layer 1) enforces this structurally — a resolved endpoint outside the `*.uat.phanes.ltd` / `localhost` allow-list fails startup.

### BR-DEV-002: UAT Peer Opt-In

Local development reaches **UAT peer services** ONLY through the explicit `uat-peers` integration profile. The platform default profile is **`local-peers`** (fail-safe): touching shared UAT must be a deliberate, named act, never a default.

- **Applies when**: a developer configures peer endpoints for a local run.
- **Outcome**: `mock-peers` (hermetic tests / CI), `local-peers` (default local dev), `uat-peers` (named opt-in integration runs) are the only profiles; the resolver's vocabulary contains no `prod` value.
- **Exceptions**: none. A missing explicit opt-in resolves to `local-peers`, silently and by design.

### BR-DEV-003: Central Peer Registry and Resolution Order

Peer endpoints MUST resolve from the **central versioned registry** (`peer-registry.yml`, reviewed via MR; one review point, one drift source). Profile resolution follows this fixed precedence:

1. Per-peer environment variable: `OELITE_PEERS__<PEERNAME>__PROFILE` (e.g. `OELITE_PEERS__NEXUS__PROFILE=local-peers` while `OELITE_PEERS__ORIGINAUTH__PROFILE=uat-peers`). Shorthand values (`local` / `uat` / `mock`) and the bare key form `OELITE_PEERS__<PEERNAME>` are NOT part of the vocabulary and fail fast at startup (no silent alias mapping).
2. Per-app appsettings: `integrationProfile.peers.<peerName>.profile`
3. Global environment variable: `OELITE_PROFILE`
4. App default: `integrationProfile.defaultProfile`
5. Platform default: `local-peers`

The resolver MUST reject (fail fast at startup) any profile value outside the allowed set, and any resolved endpoint that does not match the allow-list patterns (`*.uat.phanes.ltd`, `localhost`). Production endpoints are **not fields in the registry schema** — production deploys read endpoints from CI variables, so there is nothing to guard against by construction.

- **Applies when**: an app resolves peer endpoints at startup; when CI lints committed configuration templates.
- **Outcome**: prod isolation is fail-closed with **no CI exception path** (Marcus's Flag 3 arbitration; the earlier "CI exception" idea is withdrawn).
- **Exceptions**: none.

### BR-DEV-004: Credential Isolation

UAT peer credentials MUST live in **per-machine Keychain storage** or gitignored secret files — never committed to any repository. Developers hold **read-only or tenant-scoped** UAT credentials only; admin/service-root UAT credentials MUST NOT exist on developer machines.

- **Applies when**: any local dev session uses the `uat-peers` profile.
- **Outcome**: a compromised developer machine cannot escalate to UAT administration; no credential ever reaches git history.
- **Exceptions**: none. (`peers-health --auth` validates credentials, not just reachability.)
- **Forward path (V2 — approved, joint Emma + Ethan sign-off on #99, note 58524)**: short-lived dynamic UAT peer credentials are the approved V2 mechanism. **When `credentials.mode: dynamic` is set in `peer-registry.yml`** for a peer, UAT peer credentials for that peer are obtained via **Origin Auth client-credentials token minting** (per-developer IAM client `dev-<username>-local`, scopes limited to registry-declared `credentials.scopes`), with **TTL ≤ 15 min**, **refresh at 80% of TTL**, and tokens **cached in the OS credential store under `oelite/peer/<peerName>/uat-token`**. In dynamic mode no long-lived per-peer app secret exists on the machine; the static Keychain path remains the default (`credentials.mode: static`) and the 90-day rotation SLA applies to the **bootstrap IAM client only**. Mint/refresh failure fails fast per BR-DEV-006. See `1_dotNet_coding_standards/SECURITY-PATTERNS.md` § 4 (normative pattern) and BUSINESS-RULEBOOK § 8.2 (operational expectations).

### BR-DEV-005: UAT Data Respect (Test-Write Patterns)

Local development treats UAT peer data as **shared acceptance data**. Reads are permitted. Writes are permitted ONLY through the two codified test patterns (stakeholder decision 3 on #97):

1. **Origin Auth (IAM)**: a dedicated UAT IAM client per developer machine, named `dev-<username>-local`, registered in the UAT realm with only registry-declared scopes. The shared UAT acceptance client MUST NOT be used by local dev.
2. **Peer data records**: any record local dev writes into a UAT peer (order refs, mail recipients, test wallets, entity names, …) MUST carry a `dev-<username>-` identifier prefix so peer owners can identify and purge dev-created data.

Any other mutation of UAT peer data from local development is **prohibited**.

- **Applies when**: a `uat-peers` session writes anywhere.
- **Outcome**: peer owners can always distinguish and clean developer-created data; the acceptance tenant is never polluted by untraceable writes.
- **Exceptions**: none. Registry entries declare `testTenantId` and `resetPolicy`; the naming convention is enforced socially + documented in v1 (no technical enforcement).

### BR-DEV-006: Fail Fast on Peer Unavailability

When a required UAT peer is unavailable under the `uat-peers` profile, local development **FAILS FAST** with a clear error naming the peer and the `peers-health` command to diagnose. There is **no mock fallback and no silent degradation** (stakeholder decision 1 on #97, superseding the earlier degraded-mode recommendation).

- **Applies when**: `peers-health` reports a peer down/mismatched, or a startup connection to a `uat-peers` endpoint fails.
- **Rationale**: production would never degrade this way; mock fallback on writes creates data divergence and false confidence.
- **Mechanics**: `peers-health` pre-flight is the prevention mechanism; `--strict` / `OELITE_STRICT_PEERS=1` fails fast on any peer problem; a registry entry declaring `critical: true` (e.g. Origin Auth when the task is auth integration) fails startup even without `--strict`.
- **Outcome**: developers notice peer problems before work begins, and data consistency is never sacrificed for convenience.
- **Exceptions**: none.

---

## 3. Business Features (BF-DEV)

| ID | Feature | Business outcome |
|----|---------|------------------|
| BF-DEV-001 | Integration profiles (`mock-peers`, `local-peers`, `uat-peers`) with per-peer overrides | Developers choose isolation level per service, not just per environment |
| BF-DEV-002 | Central versioned peer endpoint registry covering all 9 peer services (Origin Auth, Kortex, Nexus, OeSterling, Apex, Synapse, Obelisk, Hermes, Orion) | One review point and one drift source for peer endpoints; registry entries declare `minVersion`, `channel` (stable), `mutability`, `contractUrl`, `contractVersion`, `critical`, `testTenantId`, `resetPolicy` |
| BF-DEV-003 | `peers-health` pre-flight utility (reachability + version report + `--auth` credential validation + `--strict` fail-fast) | Peer problems surface before the app starts, not mid-task |
| BF-DEV-004 | `appsettings.init.json` integration-profile pattern with startup fail-fast validation (scaffolded into every new .NET app) | Misconfiguration fails at startup with an explicit message naming the profile + registry key — never silent localhost defaults for peers |
| BF-DEV-005 | Structural production prevention (startup resolver allow-list + CI lint with no exception path + registry schema without prod fields) | Production is unreachable from local dev **by construction**, not vigilance |

---

## 4. Workflows (WF-DEV)

### WF-DEV-001: Onboard a repo to peer integration

| # | Step | Owner | Outcome |
|---|------|-------|---------|
| 1 | Add the `integrationProfile` block to the app's `appsettings.init.json` (`defaultProfile: local-peers`) | Developer (per Daniel's pattern) | App declares its peer needs explicitly |
| 2 | Configure per-peer profiles if the repo consumes peers differentially | Developer | Resolution order per BR-DEV-003 |
| 3 | Run `peers-health` | Developer | All declared peers reachable (or a deliberate mock/local posture confirmed) |
| 4 | If the repo IS itself a peer service: MR to add it to `peer-registry.yml` | Developer → Ethan review | Registry entry with schema fields; versioned and reviewed |

### WF-DEV-002: Run a UAT peer-integration session

| # | Step | Owner | Outcome |
|---|------|-------|---------|
| 1 | `peers-health` pre-flight (use `--strict` for critical sessions) | Developer | Peer availability + versions + credentials confirmed BEFORE work starts (BR-DEV-006) |
| 2 | Start the app with `uat-peers` explicitly set | Developer | Deliberate opt-in (BR-DEV-002) |
| 3 | Work within BR-DEV-005 write patterns | Developer | All UAT writes traceable via `dev-<username>-` prefixes / dedicated IAM client |
| 4 | Shut down; record anything peer owners should know | Developer | Dev-created UAT data is identifiable for purge |

### WF-DEV-003: Respond to a UAT peer outage

| # | Step | Owner | Outcome |
|---|------|-------|---------|
| 1 | App fails fast naming the peer (BR-DEV-006) | Application | No partial/corrupt local work against a half-available peer set |
| 2 | Developer runs `peers-health` and checks the UAT availability channel | Developer | Confirms outage vs local misconfiguration |
| 3 | Escalate to Ethan (recovery SLO: 4 business hours / 1 business day — see § 6) | Developer → Ethan | Ethan owns UAT availability; Orion monitoring alerts |
| 4 | Resume after `peers-health` passes | Developer | Work resumes on a verified-healthy peer set |

---

## 5. UI User Journeys

**N/A** — Developer Experience is a developer-facing capability with no end-user UI. The "interface" is the integration-profile configuration, the `peers-health` CLI, and the peer registry MR process. Consumer-facing features that consume peers have their own journeys in their own repos' `docs/business/` folders.

---

## 6. Operational Expectations

| Expectation | Value | Owner |
|-------------|-------|-------|
| UAT peer uptime | 99% (best-effort, shared); local dev is not a consumer-of-last-resort — a down peer fails fast (BR-DEV-006) | Ethan (monitored via Orion) |
| Endpoint stability window | UAT peer endpoints stable ≥ 5 consecutive business days per deploy cycle (aligns with the UAT soak gate, BR-REL-003); endpoint changes only via reviewed registry MR — no silent churn | Ethan + peer-owning teams |
| Registry/credential rotation cadence | Registry endpoint/version changes sprint-aligned; credential rotation per the secrets-handling rules in `agents/core/principles.md` (§ Security & Best Practices), validated by `peers-health --auth` | Ethan + Maya (review) |
| Peer recovery | Failed UAT peer deployment recovered within **4 business hours** (business hours) or **1 business day** (otherwise) | Ethan (runbook) |
| Escalation path | `peers-health` failure → UAT availability channel → Ethan → Emma (if delivery-blocking) | Per WF-DEV-003 |

---

## 7. Cross-References

- `BUSINESS-RULEBOOK.md` § 8 — rulebook anchor for this rule file (business summary, § 8.1 table, § 8.2 operational expectations).
- `1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md` — the local shared data stack that BR-DEV-001 requires for an app's own data layer; per-service isolation model.
- `6_documentation_standards/REQUIREMENTS-AUTHORITY.md` — amendment process governing this factual rule file.
- `agents/core/principles.md` (§ Security & Best Practices) — secrets-handling baseline referenced by BR-DEV-004 / § 6.
- `1_dotNet_coding_standards/17-LOCAL-DEV-PEER-INTEGRATION.md` — engineering standard (profile resolution mechanics, registry schema, `peers-health` usage) authored under #97.
- `5_git_workflow_standards/GIT-WORKFLOW-STANDARDS.md` — referenced for the UAT soak gate alignment in § 6 (via BR-REL-003).
