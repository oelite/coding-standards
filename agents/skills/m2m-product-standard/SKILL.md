# M2M Product Standard (OELITE-ENG-M2M-001)

## Purpose

Unified, mandatory standard for Machine-to-Machine capabilities across all OElite platforms — machine identity & registration, OAuth-based authentication, delegation (incl. AI agents), programmatic onboarding, subscription/catalogue/quote, provisioning lifecycle, entitlement enforcement, credential lifecycle, audit and webhooks. Ensures Origin Auth, Apex Billing, Orion, Kortex and future products implement M2M consistently and that products can be onboarded/provisioned programmatically with no portal dependency.

Canonical document: `coding-standards/1_dotNet_coding_standards/19-M2M-INTEGRATION-STANDARD.md`

## When to Load

- **Default loaders:** Marcus, Daniel (any M2M design or implementation), Maya (security review)
- **On-demand loaders:** Ethan (infrastructure/provisioning), Grace (review), Olivia (M2M test planning), Emma (orchestration), Isabella (documentation)
- **Trigger phrases:** "M2M", "machine-to-machine", "machine identity", "machine client", "service account registration", "delegation grant", "agent delegation", "provisioning API", "entitlement enforcement", "machine onboarding", "register a client programmatically", "spending limit", "capability catalogue", "M2M compliance"

Boundary with `cross-service-integration-pattern` (XIP-1): this skill governs **product-level** M2M (identity, onboarding, commercial, provisioning lifecycle); XIP-1 governs **pair-level** provisioning between two OElite services. Load both when a service pair integrates (the pair's Provisioning Token is an approved M2M Scenario-A bootstrap mechanism).

## Standards & Rules

Full normative text is in doc 19. Non-negotiables to apply during design/implementation/review:

1. **Ten Golden Rules** (doc 19 §1.1): no portal dependency, no anonymous machine trust, no implicit agent authority, no central application dependency, consistent conventions, product-owned enforcement, controlled provisioning, no automatic financial/regulatory privilege, attributable operations, documented interfaces.
2. **Actor model**: Organisation (`org_`) / human principal (`usr_`) / machine principal (`mc_`) / AI agent — delegation grant (`dlg_`) with spending limits, expiry, revocation; agents can never self-expand authority.
3. **Bootstrap security**: registration endpoints require a trust mechanism (admin session, invitation token, federated workload identity, device grant, XIP-1 provisioning token). No public unrestricted confidential-client registration — reject in review.
4. **API**: thin M2M controllers over existing application services (portal and M2M API share the same services); versioned routes; `OEliteApiOutputFormatter` envelope with the stable M2M error-code registry (doc 19 §4.3); RFC 9457 only for external partner APIs via ADR. Idempotency keys on consequential mutations (replay = original result; same key + different payload = `409 IDEMPOTENCY_KEY_CONFLICT`).
5. **Auth**: OAuth 2.0 / RFC 9700; short-lived audience-restricted scope-restricted tokens (≤ 900 s per doc 18 contract); Token Exchange (RFC 8693) for delegated agents; ROPC/Implicit prohibited; secrets shown once, never retrievable.
6. **Tenant isolation**: data-layer enforcement (`Region`/`IOwnedEntity` on every repository query); knowing a resource ID grants nothing.
7. **Commercial**: prices in integer minor units (never float); immutable quotes; server-side entitlement/quota enforcement on every request regardless of calling interface.
8. **Provisioning**: async state machine (`pending → validating → action_required → approved → provisioning → active`, terminals `failed/rejected/cancelled/expired`); durable jobs; compensating operations with never-delete reconciliation; separate lifecycle dimensions per concern.
9. **Audit & webhooks**: `m2m.*` event family with full attribution; append-only; never log secrets; signed at-least-once webhooks with SSRF protection.
10. **Compliance**: product-specific (no universal KYB); capability-level restriction; Apex Billing's subscription/merchant/payment-processing/payout remain four separate decisions.

### OElite implementation mapping (doc 19 §8 — the platform-specific layer)

- M2M services: `IOEliteService`/`IScopedService` auto-discovered (RegistrationService, DelegationService, ProvisioningService, EntitlementService, CredentialService); controllers thin with `[ApiVersion]` + `[TransformedResponse]`.
- Entities: `BaseEntity` + `[DbCollection("m2m_*")]` + external prefixed-ID fields; `[DenormalizedField]` for display data only, never evidence/credentials; TTL indexes for idempotency records and quotes.
- Config: `BaseAppConfig` configs-only; startup `OeApp.RunWebAppAsync<TAppConfig>`; data/queues via `IRestme`; background provisioning via durable jobs (mercury Backplane).
- Edge (Kortex WAF/rate limiting) is optional hardening — never a substitute for product-level authz.

## Verification

- [ ] Every automatable onboarding/subscription/provisioning operation has a programmatic path (no portal-only steps) — Golden Rule 1
- [ ] Machine registration is bootstrap-protected; no open dynamic registration
- [ ] Tokens audience/scope restricted; delegation cannot be exceeded or self-expanded (tests exist)
- [ ] Tenant isolation enforced at the data layer for every M2M collection
- [ ] Idempotency replay + 409-conflict semantics implemented and tested on all consequential mutations
- [ ] Entitlements/quotas enforced server-side (proof: request exceeding quota rejected at API with stable error code)
- [ ] `m2m.*` audit events emitted with actor/delegation attribution; no secrets in logs
- [ ] Provisioning async lifecycle with statusUrl, recoverable partial failure, reconciliation (never-delete)
- [ ] OpenAPI document version-controlled and matches implementation; conformance tests pass
- [ ] Marcus (architecture) + Maya (security) sign-off recorded on the product's M2M issue/MR
