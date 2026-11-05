# 19. Unified M2M Integration, Provisioning, Identity & Security Standard

**Document ID**: OELITE-ENG-M2M-001
**Status**: Active (since 2026-11-05)
**Version**: 1.0
**Owner**: Marcus (architecture), Maya (security), Daniel (backend implementation)
**Source issue**: coding-standards #112
**Related**: `SECURITY-PATTERNS.md`, `06-API-RESPONSE-PATTERNS.md`, `04-DATABASE-ENTITIES.md`, `14-TESTING-STANDARDS.md`, `agents/skills/cross-service-integration-pattern/SKILL.md` (XIP-1), `agents/skills/security-design/SKILL.md`
**Applies to**: All OElite platforms exposing services to machine consumers — Origin Auth, Apex Billing, Orion, Kortex, and all future products.

---

## 1. Purpose and Scope

This standard establishes the mandatory engineering requirements for Machine-to-Machine (M2M) functionality across the OElite ecosystem. Every OElite platform must be independently discoverable, authenticated, subscribed, provisioned, configured and managed programmatically — by developers, backend services, CI/CD pipelines, and AI agents — without requiring a customer to manually navigate the platform's administration portal.

M2M is a fundamental product capability, equivalent to the human-facing UI.

### 1.1 The ten Golden Rules (acceptance criteria for all OElite projects)

| # | Rule |
|---|------|
| 1 | **No portal dependency** — every automatable onboarding/subscription/provisioning operation is accessible programmatically |
| 2 | **No anonymous machine trust** — every machine identity has an owner, authentication mechanism and permission boundary |
| 3 | **No implicit agent authority** — an AI agent operates only within explicitly delegated authority and cannot expand its own permissions |
| 4 | **No central application dependency** — every product owns and operates its own M2M implementation; no separate shared provisioning app is required |
| 5 | **No inconsistent API conventions** — all products follow the common API, identity, subscription, provisioning, error and event standards in this document |
| 6 | **No trust based on upstream infrastructure alone** — every product enforces its own authentication, authorisation, tenant isolation, entitlement and compliance |
| 7 | **No uncontrolled provisioning** — registration, subscription and provisioning are protected by identity, risk, rate and quota controls |
| 8 | **No automatic financial or regulatory privilege** — subscription activation never automatically grants capabilities requiring separate legal/financial/compliance approval |
| 9 | **No untraceable machine operations** — all consequential machine operations are attributable to an identifiable actor and organisation |
| 10 | **No undocumented machine interfaces** — all M2M APIs have accurate machine-readable specs, structured errors and automated conformance tests |

### 1.2 Independent product ownership

Each product owns all 15 M2M responsibilities within its existing application architecture (no new deployable application):

1. M2M API endpoints; 2. Machine identity registration; 3. Authentication; 4. Authorisation; 5. Delegated access for human-authorised agents; 6. Registration/onboarding; 7. Subscription catalogue & pricing; 8. Subscription management; 9. Product resource provisioning; 10. Entitlement enforcement; 11. Product-specific compliance workflows; 12. Abuse prevention; 13. Credential lifecycle; 14. Audit logging; 15. Events & webhooks.

Products MAY reuse approved libraries, schemas, SDKs and conformance tests; they MUST NOT depend on a separate OElite provisioning application or runtime control plane for their basic M2M responsibilities. Integration with another OElite product (e.g. Apex Billing processing payments) is an explicit business integration, never an architectural prerequisite.

### 1.3 Relationship to XIP-1 (Cross-Service Integration Pattern)

This standard and XIP-1 are complementary, not competing:

| Concern | Governed by |
|---|---|
| Product-level machine onboarding, subscriptions, entitlements, provisioning lifecycle, delegation | **This standard (doc 19)** |
| Pair-level provisioning between two OElite services (Provisioning Tokens, cross-reference ID store, webhook sync, reconciliation, drift handling) | **XIP-1** (`agents/skills/cross-service-integration-pattern/SKILL.md`) |

An XIP-1 Provisioning Token is an **approved bootstrap mechanism** for Scenario A registration (§4.2) — e.g. Apex Billing bootstraps its tenant in Origin Auth via the XIP-1 provision ring. XIP-1 semantics (idempotent replay, show-once secrets, never-delete reconciliation) apply unchanged inside any M2M implementation that uses it.

---

## 2. Identity and Actor Model

All M2M implementations MUST distinguish the customer, the machine, and the authority under which the machine operates.

| Actor | Description | Key rules |
|---|---|---|
| **Organisation** | Customer/ownership boundary (`org_…`) | Unique per product; owns subscriptions and resources |
| **Human principal** | Identifiable individual (`usr_…`) | Authentication ≠ business authority |
| **Machine principal** | Software identity (`mc_…`): service, CI/CD, scheduled job, AI agent | Distinct identity, owning org, status, auth method, scopes, credential metadata, last-used, rotation policy, revocation |
| **AI agent** | Machine actor, even in natural-language contexts (`agt_…` or a machine principal subtype) | System MUST identify both the principal whose authority is exercised AND the machine actor |

### 2.1 Identifier conventions

Opaque, non-sequential, prefixed identifiers MUST be used for all externally exposed M2M resources:

```
org_  organisation          dlg_  delegation grant
usr_  human principal       sub_  subscription
mc_   machine principal     prov_ provisioning request
agt_  agent principal       crd_  credential metadata
evt_  audit/webhook event   qte_  quote
```

Identifiers are opaque strings generated from non-guessable sources (e.g. ULID/GUID); they MUST NOT expose enumeration or internal DB structure. Internally, entities continue to inherit `BaseEntity` (DbObjectId `Id`) and carry the external identifier in a dedicated indexed field (see §8).

### 2.2 Delegation grant

A delegation grant (`dlg_…`) represents permission provided by an authorised principal to a machine identity. Required properties: grant ID, organisation, subject, actor, permitted products, actions (scopes), optional resource restrictions, environment restrictions, spending limit, expiration, approval rules, status (`active | suspended | revoked | expired`).

Hard rules:
- An agent cannot grant itself permissions, change its spending limit, extend its own expiry, remove mandatory human approvals, transfer its delegation, or use one organisation's grant against another.
- Delegation is revocable independently of the machine client's registration.
- Every consequential M2M action is attributable to (human principal where applicable, machine actor, delegation grant, organisation, product, operation, result) — never a bare `system`/`api`/`agent` attribution.

---

## 3. Registration and Onboarding

### 3.1 Registration scenarios

| Scenario | Flow |
|---|---|
| **A — Existing organisation** | Authenticate org principal → register/authorise machine client → assign scopes → apply org policies → issue credentials. XIP-1 Provisioning Tokens and bootstrap grants are approved trust mechanisms here. |
| **B — New organisation** | Programmatic initial registration → provisional org identity → verify contact/representative → terms → plan selection → approvals → resource creation → credentials. A hosted verification session MAY be used where human input is necessary. |
| **C — Existing workload identity** | Federated OIDC / cloud / CI workload identity. Trust policies MUST explicitly declare trusted issuers, audiences and subject claims; never accept arbitrary issuer URLs or client-supplied claims as proof of ownership. |
| **D — AI agent onboarding** | Agent operates via an existing machine identity + explicit delegation grant. Without one, the customer/administrator must establish identity+delegation through an approved bootstrap (e.g. Authorization Code + PKCE or Device Authorization Grant). |

### 3.2 Bootstrap security (hard gate)

A registration endpoint MUST require a bootstrap trust mechanism: authenticated administrator session, single-use invitation/registration token, existing organisation-issued credential, trusted federated workload identity, device authorisation flow, signed time-limited registration grant, or enterprise provisioning integration (XIP-1).

**A publicly accessible endpoint allowing unrestricted confidential-client registration MUST NOT be implemented.**

### 3.3 Registration state model

`pending` · `verification_required` · `active` · `suspended` · `revoked` · `expired` · `rejected`

Identities in any state other than `active` receive no operational access.

---

## 4. API Design and Endpoint Conventions

### 4.1 API-first, versioned, OElite-conformant

- All M2M capabilities are exposed through documented HTTP APIs under the platform's standard versioned routes (`api/v{version:apiVersion}/...` with `[ApiVersion]`, per doc 06 and `architecture-design` §5.6).
- M2M controllers are thin: parse → authorise → call the product's **existing application service** → return DTO. M2M controllers MUST NOT duplicate domain/business logic; the admin portal and the M2M API invoke the same services (§8.1).
- Do not implement M2M by simulating browser interactions or relying on private frontend endpoints.
- All actions annotated `[TransformedResponse]`; responses wrapped by `OEliteApiOutputFormatter` — never hand-built envelopes.

### 4.2 Common resource structure

Products SHOULD expose equivalent operations for: Catalogue, Plans, Quotes, Registrations, Organisations, Delegations, Provisioning, Subscriptions, Entitlements, Credentials, Compliance, Events, Audit. These are common concepts — not mandatory controller names.

Illustrative surface (adapt routes to the product's domain):

```
GET    /api/v1/m2m/catalog            GET  /api/v1/m2m/plans
POST   /api/v1/m2m/registrations      GET  /api/v1/m2m/registrations/{id}
POST   /api/v1/m2m/delegations        GET/DELETE /api/v1/m2m/delegations/{id}
POST   /api/v1/m2m/quotes             GET  /api/v1/m2m/quotes/{id}
POST   /api/v1/m2m/provisioning       GET  /api/v1/m2m/provisioning/{id}
GET    /api/v1/m2m/subscriptions      POST /api/v1/m2m/subscriptions/{id}/change-plan | /cancel
GET    /api/v1/m2m/entitlements
POST   /api/v1/m2m/credentials        POST /api/v1/m2m/credentials/{id}/rotate | /revoke
GET    /api/v1/m2m/events
```

### 4.3 HTTP semantics and errors

Standard status codes per `architecture-design` §5.2 (200/201/202/204/400/401/403/404/409/422/429/500/503). Never HTTP 200 with an error hidden in the body.

**Error format — OElite envelope is canonical.** The platform's `OEliteApiOutputFormatter` error structure with a stable machine-readable `code` is the mandatory format for OElite platforms:

```json
{
  "success": false,
  "error": {
    "code": "SPENDING_LIMIT_EXCEEDED",
    "message": "The requested subscription exceeds the delegated spending limit.",
    "details": [],
    "correlationId": "0HMD..."
  }
}
```

Stable M2M error-code registry (machine consumers switch on `code`, never on messages):

```
AUTHENTICATION_REQUIRED   INVALID_MACHINE_CREDENTIAL   CLIENT_SUSPENDED
TOKEN_EXPIRED             INVALID_AUDIENCE             INSUFFICIENT_SCOPE
DELEGATION_EXPIRED        DELEGATION_REVOKED           TENANT_ACCESS_DENIED
SUBSCRIPTION_NOT_ACTIVE   PLAN_NOT_AVAILABLE           ENTITLEMENT_EXCEEDED
SPENDING_LIMIT_EXCEEDED   QUOTE_EXPIRED                PROVISIONING_CONFLICT
PROVISIONING_IN_PROGRESS  PROVISIONING_FAILED          VERIFICATION_REQUIRED
COMPLIANCE_REVIEW_REQUIRED COMPLIANCE_REJECTED         PAYOUT_NOT_ELIGIBLE
RATE_LIMIT_EXCEEDED       RESOURCE_LIMIT_EXCEEDED      IDEMPOTENCY_KEY_CONFLICT
```

RFC 9457 Problem Details MAY be used only for externally published partner APIs where the OElite envelope is contractually unsuitable — requires an ADR and MUST NOT replace the envelope on internal OElite surfaces.

When human intervention is required, the error MUST identify the action explicitly (`verify_identity`, `approve_delegation`, `approve_subscription`, `accept_terms`, `complete_kyb`, …) with a secure action URL and expiry. Never expose internal risk thresholds or investigation details.

### 4.4 Request correlation and idempotency

Every request carries/generates Request ID, Correlation ID, Trace ID (distributed tracing), and an `Idempotency-Key` for consequential mutating operations. Keys are scoped to the authenticated client; same key + equivalent payload replays the original result; same key + different payload → `409 IDEMPOTENCY_KEY_CONFLICT` + audit alarm (Stripe-style semantics, aligned with XIP-1 §2). Records have a defined retention period.

---

## 5. Authentication and OAuth Security

### 5.1 Framework

OAuth 2.0 with **RFC 9700** (Security BCP) as the baseline. Origin Auth (`uranus/origin-auth`) is the ecosystem's IAM/token authority (JWT RS256 issuance/validation/revocation per `principles.md` §Security); each product still validates tokens and enforces its own authorisation on every request.

Supported methods (choose per deployment/risk model): **Private Key JWT** (RFC 7523), **mTLS** (RFC 8705), **DPoP** (RFC 9449), **federated workload identity**, **Client Credentials** for autonomous M2M. Client Credentials alone MUST NOT be used to imply a human's delegated authority — use Token Exchange (RFC 8693) so the final token accurately represents organisation/principal, machine actor, target product, permitted actions and delegation.

Prohibited: ROPC grant, Implicit grant, permanent shared secrets in code, hardcoded production credentials, credentials in repositories, unrestricted API keys, credentials in URLs, agents collecting user passwords for onward submission, cross-product token acceptance without an explicit trust relationship.

### 5.2 Tokens, audiences, scopes

- Access tokens: short-lived (~5–15 min; Origin Auth dynamic peer credential contract is ≤ 900 s — see doc 18), audience-restricted to the issuing product's API, scope-restricted, validated for issuer/signature/expiry/nbf/binding/revocation.
- A token for one product is never accepted by another; cross-product access is explicitly authorised.
- Scopes are specific (`organisation.read`, `subscription.create`, `provisioning.create`, `credential.rotate`, `workspace.execute`, `merchant.apply`, `payout.request`, …). Broad scopes (`admin`, `full_access`) are prohibited.

### 5.3 Credential lifecycle

Every product MUST implement: creation, rotation, revocation, expiration, suspension, last-used tracking, auth-failure tracking, secure public-key registration, emergency invalidation. Secrets are returned **once** via the creation/rotation response (XIP-1 show-once semantics) and never retrievable via read endpoints.

---

## 6. Authorisation and Tenant Isolation

- Authentication ≠ authorisation. Every operation independently evaluates identity, organisation ownership, client identity, delegation, scopes, roles, resource permissions, entitlements, compliance state and environment restrictions.
- **Tenant isolation is enforced at the data layer**: every repository query filters by tenant (`Region` / `IOwnedEntity` per `architecture-design` §10.2); a caller knowing a valid resource ID gains nothing. Resource/organisation IDs submitted by clients are always validated against the authenticated identity's ownership relationships. Cross-tenant leaks are P-zero incidents.
- Privileged operations (admin identities, IdP changes, elevated grants, payout destinations, compliance records, org-wide revocations, security policy, delegation authority) require additional verification/approval and SHOULD support separation of duties — an agent must not both initiate and independently approve a sensitive action.

---

## 7. Discovery, Plans and Commercial Authority

- Products SHOULD expose a machine-readable capability catalogue (product ID, API base URLs, version, auth methods, environments, plans, capabilities, provisioning/approval requirements, docs links). Public discovery exposes only public information.
- Plans are structured, machine-readable, versioned (`planId`, `planVersion`, `billingInterval`, price in **integer minor currency units** — never floating point — `capabilities`, `quotas`).
- The product is the authoritative source of pricing; consumers cannot submit arbitrary amounts. Subscription requests reference an immutable quote (product, plan+version, pricing version, currency, interval, taxes, discounts, trial, terms version, expiry).
- Machines need explicit delegated authority to commit an organisation to a subscription: spending limits, permitted products/tiers/intervals, trial eligibility, approval requirements and contractual acceptance are enforced server-side. An agent may request a tier upgrade but never auto-executes a commitment beyond its delegation.

---

## 8. OElite Implementation Mapping (normative for .NET platforms)

M2M capabilities are implemented **inside the product's existing OElite architecture** — no new deployable application, no new hosting model.

### 8.1 Layering (per `architecture-design` §2)

```
Api layer          M2M controllers (thin): parse → authz context → service → DTO
                   [ApiVersion] + [TransformedResponse]; OEliteApiOutputFormatter wrapping
Services layer     M2M application services (IOEliteService/IScopedService markers, auto-DI):
                   RegistrationService, DelegationService, ProvisioningService,
                   EntitlementService, CredentialService — orchestrating the product's
                   EXISTING domain services; business decisions live here
Data layer         DataRepository<TDbCentre>: data access only (4 CRUD methods)
Entities           BaseEntity subclasses with [DbCollection("snake_case")] +
                   external identifier fields (org_ / mc_ / dlg_ / …) per §2.1
```

Admin portal and M2M API MUST invoke the same application services — no parallel business-rule implementations.

### 8.2 Common logical entities (per product; snake_case collections, doc 09 naming)

| Entity | Collection (example) | Notes |
|---|---|---|
| M2mOrganisation | `m2m_organisations` | `BaseEntity` + `ExternalId` (`org_…`) + `Region` |
| MachinePrincipal | `m2m_machine_principals` | owning org ref, auth method, scopes, status, last-used, rotation policy |
| DelegationGrant | `m2m_delegation_grants` | subject/actor refs, products, scopes, spending limit, expiry, status |
| ProductPlan / Quote | product domain | immutable versioned pricing (minor units) |
| ProvisioningRequest | `m2m_provisioning_requests` | state machine (§9), idempotency key, statusUrl |
| Subscription / Entitlement | product domain | capabilities + quotas; server-side enforcement |
| CredentialMetadata | `m2m_credential_metadata` | status/rotation/last-used only — **secret material is never stored retrievable**; use the platform SecretsService / one-time delivery |
| M2mAuditEvent | `m2m_audit_events` | append-only collection (§10) |
| WebhookSubscription | `m2m_webhook_subscriptions` | signed endpoint config |

Use `[DenormalizedField]` for display-only copies (e.g. org name on a subscription); never denormalise compliance evidence or credentials. TTL-index time-bounded data (idempotency records, quote expiry).

### 8.3 Configuration, hosting and data access

- `BaseAppConfig` + configs-only pattern; M2M settings (token lifetimes, rate limits, bootstrap policies) are environment config, never code.
- Startup via `OeApp.RunWebAppAsync<TAppConfig>`; services auto-discovered — no manual DI.
- All data/queue/cache access via `IRestme`; background provisioning work via durable jobs (mercury Backplane / Restme queues) — never fire-and-forget for compensating workflows.
- Edge protection may integrate Kortex (gateway, WAF, rate limiting) but never replaces product-level authz (Golden Rule 6).

### 8.4 Internal consistency (§18 of source standard, OElite terms)

Revocations, suspensions and entitlement changes propagate to all validating components: token validation, entitlement caches (`IRestmeCache` with TTL + invalidation on write), credential revocation, subscription suspension. A revoked financial or privileged capability MUST NOT remain usable via stale cached authorisation data.

---

## 9. Provisioning Lifecycle

### 9.1 Workflow

`DISCOVERY → MACHINE AUTHENTICATION → ORGANISATION VALIDATION → AUTHORITY/DELEGATION VALIDATION → PRODUCT & PLAN SELECTION → QUOTE → SPENDING/TERMS APPROVAL → COMPLIANCE & RISK CHECKS → PROVISIONING REQUEST → RESOURCE CREATION → ENTITLEMENT CONFIGURATION → CREDENTIAL DELIVERY → ACTIVE`

Products may omit irrelevant stages but MUST NOT bypass a mandatory security, commercial or compliance condition. Submission (HTTP 202 with `prov_…` requestId + `statusUrl`) ≠ completion.

### 9.2 State model

`pending → validating → action_required → approved → provisioning → active` (terminal: `failed | rejected | cancelled | expired`). Maintain **separate** lifecycle dimensions for machine client, delegation, provisioning request, subscription, product resource, compliance case, capability and financial eligibility — never one status field.

### 9.3 Failure and compensation

Provisioning spans multiple services/providers; handle partial failure with durable orchestration (mercury Backplane), bounded retries and compensating operations (XIP-1 §4 never-delete semantics: re-sync attaches missing links or fails cleanly for admin review — never deletes the partner resource on missing correlation). A reconciliation job identifies and corrects inconsistent states; drift is recorded, never silent.

### 9.4 Entitlements and quotas

Subscription → concrete capabilities + quotas, enforced **server-side on every request** (not frontend visibility, client flags, CLI rules, agent instructions or cached data). High-concurrency products use atomic/concurrency-safe quota reservation. Downgrades: calculate impact, identify over-limit resources, notify, apply grace/restricted policy, prevent new over-limit usage, preserve data.

---

## 10. Audit, Webhooks, Observability

### 10.1 Audit events

Every significant M2M operation emits an auditable event: `m2m.client.registered|suspended|revoked`, `m2m.delegation.created|revoked`, `m2m.provisioning.requested|approved|failed|completed`, `m2m.subscription.*`, `m2m.credential.created|rotated|revoked`, `m2m.compliance.*`, `m2m.security.risk_detected|access_denied`.

Minimum attributes: event ID, timestamp, product, organisation, resource, human principal (where relevant), machine actor, delegation ID, action, result, reason code, correlation ID, request ID, policy version. Stored append-only (tamper-evident); privileged users and machines cannot silently alter or erase material events. **Never log** tokens, refresh tokens, private keys, API secrets, passwords, full bank credentials or unredacted verification evidence (structured logs + redaction).

### 10.2 Webhooks

Signed (HMAC-SHA256 or asymmetric), timestamped, unique `evt_…` ID, replay detection, secret rotation, minimal payload. Common envelope: `eventId`, `eventType`, `eventVersion`, `productId`, `organisationId`, `resourceId`, `occurredAt`, `correlationId`, `data`. At-least-once delivery — consumers are idempotent. SSRF protection: validate destination schemes/addresses; block loopback/private/link-local unless explicitly authorised; revalidate on resolution and delivery (DNS rebinding).

### 10.3 Monitoring

Expose metrics for: registration rate, auth success/failure, authorisation denials, provisioning success/failure/latency, pending requests, credential revocations, subscription changes, entitlement rejections, rate-limit triggers, risk-based blocks, webhook delivery failures.

---

## 11. Compliance and Abuse Prevention

### 11.1 Compliance

Compliance is product-specific and jurisdiction-dependent — there is no universal KYB. Each product declares which capabilities require verification/approval/licence/contract. States: `not_required · not_started · pending · information_required · verification_in_progress · manual_review · approved · restricted · rejected · expired`. Compliance decisions restrict the relevant **capabilities**, not necessarily the whole product (e.g. Apex Billing: active software subscription ≠ merchant approval ≠ payment-processing eligibility ≠ payout eligibility — four separate decisions). Machines may submit evidence; they never fabricate results, bypass providers, or approve regulated activities. Evidence is encrypted, access-restricted, malware-scanned, retention-managed; agents receive status/references, not raw evidence.

### 11.2 Security threat model & layered controls

Every M2M product assesses at minimum: unauthorised registration, account farms, credential theft, token replay, org impersonation, cross-tenant access, privilege escalation, delegation abuse, subscription manipulation, free-tier abuse, API scraping, provisioning floods, financial fraud, webhook spoofing, DoS, sensitive-data disclosure, abuse of trusted integrations.

Controls at three layers — API (authn/authz/validation/size/rate limits), application (business rules, registration risk assessment, quotas, abuse detection), infrastructure (Kortex WAF/DDoS/bot detection) — with neither layer assuming the other is complete. Registration endpoints get dedicated protection (velocity, reputation, org verification, creation patterns — not IP alone, since legitimate agents/CI share cloud IPs). Adaptive verification: low risk → routine automation; medium → extra verification/tighter provisional quotas; high → suspend/restrict/review, without leaking detection logic in public errors. Separate rate limits per operation class (discovery, quotes, registration, org/client creation, rotation, provisioning, evidence submission, subscription changes, financial ops); HTTP 429 + `Retry-After`.

### 11.3 Agent-protocol safety

MCP servers or other agent adapters are optional interfaces that MUST enforce the same authentication, authorisation, delegation, subscription and compliance rules and produce auditable actions — never a privileged bypass. System prompts / agent instructions / natural-language policies are never the primary enforcement mechanism; the API independently validates every action.

---

## 12. AI Agent Compatibility

- Every product publishes a version-controlled OpenAPI document (3.x), updated alongside implementation, consistent with deployed behaviour; plus JSON schemas, catalogue, plan definitions, auth instructions, structured errors, lifecycle docs, examples and webhook documentation.
- Canonical agent journey: discover → plans → authenticate → validate delegation → identify org → select subscription → quote → approval → provision → monitor async status → complete verification actions → confirm resource status → obtain scoped credentials → configure → verify. An agent MUST NOT report completion merely because the API accepted the request — it verifies resulting resource status.
- CLI/SDK support SHOULD exist with consistent terminology across the ecosystem; CLIs support interactive and unattended use.

---

## 13. Product-Specific Guidance

| Product | M2M emphasis |
|---|---|
| **Origin Auth** | Machine client registration, OAuth client auth, service accounts, public-key registration, token issuance/validation, scopes/roles, delegation, org access policies, IAM tenant & application provisioning, credential rotation/revocation, security audit. Must support bootstrapping a brand-new tenant (onboarding cannot require already having a tenant on the very platform being provisioned). Reference implementation status: XIP-1 Provisioning API v1 (origin-auth #1693). |
| **Apex Billing** | Billing-account provisioning, plan/quote, payment setup, merchant application, KYB, beneficial-ownership/identity verification, sanctions screening where required, settlement-account registration & bank ownership verification, payout eligibility, financial audit. Software subscription, merchant approval, payment-processing eligibility and payout eligibility remain **separate** decisions. |
| **Orion** | Workspace/project/environment provisioning, workflow namespaces, worker identities with their own scoped identities (workers never auto-inherit org/project permissions), execution permissions, monitoring/logging/metrics/tracing config, quotas, credential rotation, environment isolation. |
| **Kortex** | Proxy/edge config, traffic policy, WAF, rate limiting, bot mitigation, DDoS, infrastructure provisioning — same authn/delegation/audit/API-security principles; not responsible for other products' commercial subscription or domain compliance. |

---

## 14. Testing and Conformance (extends doc 14)

Every M2M product MUST have automated tests (unit under hermetic rules; integration against the shared oelite-stack, `[Trait("Category","Integration")]`) covering:

| Suite | Minimum verification |
|---|---|
| Authentication | invalid/expired/wrong-audience tokens, revoked clients, bad signatures, untrusted issuers, scope enforcement |
| Delegation | agent cannot exceed/expiry/revoke/self-grant/cross-org; actor attribution; spending limits |
| Tenant isolation | org A cannot reach org B; resource ID alone grants nothing; nested + list/search leakage checks |
| Provisioning | idempotent replay no-duplication, invalid transitions rejected, partial-failure recovery, expired quotes, async resumability, final state accuracy |
| Compliance (where relevant) | restricted capabilities gated, evidence access-controlled, approvals attributable |
| Abuse | registration limits, quota bypass under concurrency, suspension blocks provisioning, correct 429 behaviour |
| API conformance | response envelopes, error-code registry, versioning, idempotency, event envelope, webhook signatures, OpenAPI validity |

---

## 15. Release Acceptance (Definition of Done for M2M)

A product is M2M-compliant only when **all** of the following hold:

- **Functional**: programmatic discovery, plan retrieval, secure machine registration, org authorisation, delegated agent operation, subscription selection with commercial authority enforcement, portal-free provisioning with trackable status, programmatic subscription management, server-side entitlement enforcement, credential rotation/revocation.
- **Security**: approved auth standards, audience + scope enforcement, delegation limits, cross-tenant prevention, approval gates on privileged operations, no secret exposure, registration-abuse and rate controls, audit events.
- **Operational**: recoverable async operations, idempotency, tested failure/retry, authenticated webhooks, monitoring, OpenAPI matching implementation, conformance tests passing.
- **Compliance**: product-specific requirements documented, gated capabilities explicit, auditable decisions, protected evidence, regulatory review where applicable.

## 16. Implementation Priority

1. **Foundational**: API conventions, machine identity, secure registration, OAuth, scopes, tenant isolation, credential lifecycle, audit.
2. **Commercial & provisioning**: discovery, catalogue, quotes, delegated spending limits, subscriptions, provisioning APIs, idempotency, async lifecycle, entitlement enforcement.
3. **Advanced security**: workload federation, token exchange, mTLS/DPoP, adaptive registration controls, abuse detection, automated revocation, security monitoring.
4. **Compliance**: product verification workflows, financial/regulatory gates, evidence handling.
5. **Agent-native DX**: OpenAPI contract, SDKs/CLI, agent examples, optional MCP, conformance testing.

New products plan all applicable priorities at architecture design even when implementation is phased.

---

## 17. References

- RFC 9700 (OAuth Security BCP), RFC 6749, RFC 8693 (Token Exchange), RFC 7523 (Private Key JWT), RFC 8705 (mTLS), RFC 9449 (DPoP), RFC 8628 (Device Grant), RFC 8414 (AS Metadata)
- OpenAPI Specification · RFC 9110 (HTTP Semantics) · OWASP API Security Top 10
- OElite internal: `SECURITY-PATTERNS.md`, `06-API-RESPONSE-PATTERNS.md`, `04-DATABASE-ENTITIES.md`, `14-TESTING-STANDARDS.md`, `18-DYNAMIC-PEER-CREDENTIALS.md`, `agents/skills/cross-service-integration-pattern/SKILL.md`, `agents/skills/security-design/SKILL.md`, `agents/core/principles.md`
- Regulatory: UK GDPR, Money Laundering Regulations 2017, FCA Handbook. **Technical conformance to this standard does not establish legal or regulatory compliance.**

---

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-11-05 | Marcus | Initial standard from coding-standards issue #112: refined the draft golden standard — resolved RFC 9457 vs OElite response-envelope conflict (§4.3), defined boundary with XIP-1 (§1.3), added normative OElite implementation mapping (§8), identifier conventions (§2.1), OElite testing/acceptance alignment (§14–15). |
