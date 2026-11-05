# Cross-Service Integration Pattern (XIP-1)

## Purpose

A standardized design pattern for provisioning and identity integration between any two OElite services (e.g., Origin Auth ↔ Apex Billing, Origin Auth ↔ Hermes, Kortex ↔ Apex). Every OElite integration pair forms a **bidirectional service-provision ring**: each side issues scoped Provisioning Tokens for the other's Provisioning API, stores the partner's correlated resource ID, and relies on webhook-driven sync plus safe reconciliation to stay consistent. XIP-1 exists so future service pairs do not reinvent ID mapping, cross-service auth, idempotency, or reconciliation.

Canonical reference implementation and full design authority: origin-auth issue **#1693**, notes 58785/58786 (owner-ratified 2026-11-02); Origin Auth's Provisioning API v1 is the first provider implementation.

## When to Load

- **Default loaders:** Marcus, Daniel, Ethan (whenever a service pair integrates provisioning or cross-service identity)
- **On-demand triggers:** "cross-service integration", "XIP-1", "provisioning between services", "billing-link", "service-provision ring", "cross-reference ID", "reconciliation job", "drift detection", "Provisioning Token", "another service needs a tenant/account in my service", "we need to integrate with Origin Auth / Apex Billing / another OElite platform"
- **On-demand loaders:** Emma (orchestration/impact analysis), Isabella (documentation of a new integration pair), Maya (security review of token scopes), Grace (review of a provider implementation)

## Standards & Rules

### 1. The Provision Ring

- Service A and Service B each expose a **Provisioning API** — a minimal, scoped endpoint family that creates the pair's resource (tenant, account, merchant) and records the partner's correlated ID.
- Each side **issues Provisioning Tokens** (scoped, short-lived, JWT) for the *other* side's Provisioning API. Both directions are explicit; no side assumes the other's token.
- The provisioned principal is a **Machine Identity** (tenant + client-credentials client + scoped API keys in Origin Auth terms). The enrollment credential is the **Provisioning Token** — never call the access tokens it mints "provisioning tokens" in docs or billing meters.

### 2. Required Endpoint Contract

Each provider implements, at minimum:

```http
POST /v1.0/provision/bootstrap
// Auth: Provisioning Token (Bearer) issued by the partner service
// Body: { "external_id": "<partner-unique-id>", "metadata": { "partner_name": "Service B" }, "clientInstanceId": "..." }
// 201 (created) / 200 (replay): { "local_id": "...", "external_id": "...",
//   "credentials": { "api_key": "<shown once>" }, "credentialsAlreadyIssued": false }

POST /v1.0/provision/billing-link        // link an external billing/account ID to a local resource
POST /v1.0/provision/credentials/rotate  // re-issue credentials (secrets are never re-shown on replay)
```

- **Idempotency is mandatory**: keyed by `(external_id, clientInstanceId)` or the pair's agreed equivalent. Replay returns the existing resource with `credentialsAlreadyIssued: true`; same key + **different** payload → `409` with wire-level error code `IDEMPOTENCY_KEY_CONFLICT` (canonical, per doc 19 §4.3) + audit alarm (Stripe-style semantics; never overwrite). Implementations MAY use an exception type such as `IdempotencyKeyConflictException` internally; the registry code is what appears on the wire.
- Secrets are **returned once** and never logged or re-issued by replay; rotation goes through the rotate endpoint.

### 3. Cross-Reference ID Store

- Bidirectional stable external IDs, write-once at provisioning, updatable only with bilateral consent:
  - Side A stores partner ID on its resource (e.g., `TenantMetadata.ApexMerchantId`).
  - Side B stores the mirror (`Merchants.OriginAuthTenantId`).
- Optionally a **correlation/lookup table** (GUID per pair) on either side for fast reverse lookup without join storms.
- **Source-of-truth matrix is mandatory** before implementation: for each data domain (identity, subscription, payment method, plans), record who owns it and who may mutate it.

### 4. Sync, Reconciliation & Drift

- **Webhook-first**: both sides emit idempotent provisioning events (`X provisioned` / `X updated`) carrying `event_id` for replay safety.
- **Polling fallback** for missed webhooks (rate-limited).
- **Background reconciliation job** (e.g., hourly): verify correlated pairs on both sides; record drift to an audit log (`cross_service_drift`); alert on critical drift (e.g., `archived` vs `active`).
- **Failure/rollback semantics**: a failed provisioning step after the partner already created its resource uses a compensating transaction (soft-delete/archive + `...ProvisioningFailed` audit event). Re-sync **never deletes** the partner resource — it attaches the missing link or fails cleanly for admin review. No silent bypass; no data deleted based on a missing correlation alone.

### 5. Security Controls (Maya review mandatory)

- Tokens: scoped per purpose (e.g., `tenant:create`, `billing:create`, `provision:bootstrap`), short-lived (≤1h), `jti` tracked with auto-revoke on reuse anomaly, per-environment issuance via CI variables/secrets manager, optional IP allowlist (recommended prod, mandatory for platform-operator-issued tokens).
- Least privilege: provisioning tokens never carry platform-admin scope.
- Audit every provisioning, sync, reconciliation, and drift event (BR-12 family) — never include secrets.
- mTLS optional hardening for service-to-service calls.
- Anti-abuse: per-token rate limits, budget caps (max resources per token per window), tenant allowlists in token claims — see origin-auth note 58785 §3 for the canonical 8-control list.

### 6. Adoption Checklist (complete before implementation)

- [ ] Choose which side issues the Provisioning Token (based on existing credential store)
- [ ] Define the minimal provisioning endpoint surface (create + correlation only; resist scope creep)
- [ ] Agree on cross-reference ID storage (one-way vs two-way) and the source-of-truth matrix
- [ ] Design the webhook schema (idempotent, `event_id`-keyed) + polling fallback
- [ ] Build the reconciliation background job and drift detection (never-delete semantics)
- [ ] Pass Maya's security review of token scopes, rotation, and anti-abuse controls
- [ ] Publish the pair's documentation; register repo-specific overrides in `<repo>/.ai/standards/integration-patterns/` if the pair deviates
- [ ] Cite rulebook IDs (e.g., BR-24-003 and the provisioning rule family) where rulebook-affecting

### Anti-patterns (reject in review)

- Ad-hoc one-off integrations without a source-of-truth matrix or reconciliation
- Secrets re-displayable or stored in plaintext (must be shown-once + encrypted at rest)
- Deleting partner data on sync failure or missing correlation
- Unauthenticated or open dynamic registration (gating via Provisioning Token / initial access token is mandatory)
- Per-transaction billing of provisioning control-plane operations (control plane is free; meter the data plane, e.g., "Active Machine")

## Verification

- Both sides of the pair implement the endpoint contract including idempotent replay and 409-conflict semantics (integration test evidence).
- Correlated IDs resolve in both directions; reconciliation job runs and produces drift records (not silent gaps).
- Token lifecycle verified: scope enforcement, TTL, jti reuse auto-revoke, rotation runbook exists.
- Audit events present for provisioning, replay, failure, and drift (BR-12 family), secrets never in logs.
- Maya's security sign-off recorded on the pair's issue/MR.
- New pairs document adoption via this checklist and link the origin-auth reference implementation (#1693).
