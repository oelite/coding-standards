# 18. Dynamic Peer Credentials (V2 — Token Minting)

**Status**: Active (since 2026-11-02)
**Owner**: Daniel (backend implementation), Ethan (registry + Origin Auth realm), Maya (security review)
**Related**: `17-LOCAL-DEV-PEER-INTEGRATION.md` (static path + profile resolution), `SECURITY-PATTERNS.md` § 4 (normative V2 statement), `CONFIGURATION-VALIDATION.md` (fail-fast pattern), `0_project_planning_standards/rules/BR-DEV-001-local-peer-integration.md` (BR-DEV-004/005/006), `infrastructure/oelite-stack/config/peer-registry.yml`, Issue #99 (joint Emma + Ethan sign-off, note 58524)

## Overview

V2 adds a **dynamic credential path** alongside the v1 static Keychain path. When a peer's registry entry sets `credentials.mode: dynamic`, UAT peer credentials are **minted lazily (at startup for required/critical peers)** as short-lived access tokens via the **Origin Auth client-credentials flow** — using the existing per-developer IAM client `dev-<username>-local` (BR-DEV-005). No new client type, no new secret class, no new registration model.

The provider abstraction (`IPeerCredentialProvider`, defined in doc 17) gains a second implementation:

| Implementation | Registry mode | Credential source | Rotation |
|---|---|---|---|
| `StaticKeychainPeerCredentialProvider` (v1) | `static` (default) | OS credential store entry `oelite/peer/<peerName>/<key>` | 90-day SLA |
| `DynamicPeerCredentialProvider` (V2) | `dynamic` | Minted access token, cached at `oelite/peer/<peerName>/uat-token` | Per-developer IAM client only (90-day SLA); no long-lived per-peer app secret exists |

**Staged rollout**: `static` is the platform default. A peer moves to dynamic mode only via a reviewed registry MR changing its `credentials.mode`. Existing v1 Keychain entries remain valid; nothing is forced to migrate.

## Provider Selection

Selection is **registry-driven, not app-configured** — apps never choose the mode locally (one drift source, per the BR-DEV-003 registry principle):

1. At startup, the resolver reads the peer's `credentials.mode` from `peer-registry.yml` (absent ⇒ `static`).
2. `static` → `StaticKeychainPeerCredentialProvider`; `dynamic` → `DynamicPeerCredentialProvider`.
3. Any other value ⇒ **fail fast at startup**, naming the registry key and value (same pattern as profile validation in doc 17).
4. Only peers resolved to `uat-peers` acquire credentials at all. `local-peers`/`mock-peers` peers never mint and never load secrets (unchanged from v1).

Both implementations satisfy the same `IPeerCredentialProvider` contract from doc 17: fail fast (`PeerCredentialException`) on acquisition failure — no silent nulls, no degraded mode. Registration in DI:

```csharp
services.AddSingleton<IPeerCredentialProvider>(sp =>
    PeerCredentialProviderFactory.Create(
        sp.GetRequiredService<IPeerRegistry>(),
        sp.GetRequiredService<ICredentialStore>(),
        sp.GetRequiredService<IHttpClientFactory>(),
        timeProvider: TimeProvider.System));
```

The factory is the **only** place that knows about modes; consumers depend solely on `IPeerCredentialProvider`.

## Minting Flow (Normative)

`DynamicPeerCredentialProvider.GetCredential(peerName, "uat-token")` performs, in order:

1. **Cache lookup** (see § Caching below) — return a valid, unexpired token if present.
2. **Mint** if no valid cached token:

```
POST {originAuth.uat endpoint from peer-registry.yml}/{realm}/protocol/openid-connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
client_id=dev-<username>-local
client_secret=<from OS credential store: oelite/iam/dev-<username>-local>
scope=<space-joined registry credentials.scopes for THIS peer>
```

3. **Validate the response** before accepting it:
   - HTTP 200 with `access_token`, `expires_in` (seconds), and `token_type` present — otherwise fail fast.
   - `expires_in` **≤ 900 seconds (15 min)** is the design contract. If the realm ever returns a longer TTL, the provider caps its own refresh timer at 80% of **900 s**, not 80% of the returned value, so a misconfigured realm can never silently extend token lifetimes beyond the approved bound (a deviation is logged loudly and reported by `peers-health --auth`).
   - The issuer (`iss` claim) must match the registry-declared Origin Auth UAT endpoint — mismatch ⇒ fail fast (token obtained from the wrong place is treated as an error, not a usable credential).

### Scope rule — never widened client-side

The `scope` parameter is **exactly** the peer's registry-declared `credentials.scopes`, space-joined in registry order. The provider MUST NOT add, drop, reorder, or "helpfully expand" scopes. If Origin Auth rejects the scope set (HTTP 400 `invalid_scope`), that is a **registry bug or realm misconfiguration** — fail fast pointing at the registry entry; do not retry with a reduced scope set. Widening local-dev token reach is possible **only** via a reviewed registry MR (Marcus arch review per the BR-DEV-003 review point).

### Bootstrap secret

The **canonical term** is the **per-developer IAM client** (`dev-<username>-local`). In earlier drafts and some docs the same client is called the **"bootstrap IAM client"** — the names are interchangeable; prefer "per-developer IAM client" in new writing.

The only long-lived secret on the machine is the `dev-<username>-local` IAM **client secret**, held in the OS credential store under `oelite/iam/dev-<username>-local` and rotated on the existing 90-day cadence — the same Keychain-held bootstrap pattern as agent PATs. It is never used as a peer credential itself; it only authenticates minting requests.

## Caching & Refresh

Cache location (same OS credential store used by the static path):

| OS | Store | Entry |
|---|---|---|
| macOS | Keychain Services | `oelite/peer/<peerName>/uat-token` (token) + `oelite/peer/<peerName>/uat-token-ttl` (metadata) |
| Windows | Windows Credential Manager | same names |
| Linux | libsecret / Secret Service API | same names |

**Metadata entry** (non-secret, but stored alongside for consistency) — JSON:

```json
{ "expiresAtUtc": "2026-11-02T09:41:07Z", "issuedAtUtc": "2026-11-02T09:27:07Z", "ttlSeconds": 840, "peer": "nexus", "mintedForScopes": ["nexus.api.read", "nexus.api.write"] }
```

Rules:

- **No cross-run reuse beyond TTL.** A cached token is read back only if `now + ClockSkew < expiresAtUtc`. Tokens past expiry are never returned and never sent — they are overwritten on next mint (BR-DEV-006: no stale-token fallback).
- **Proactive refresh at 80% of TTL.** With a 15-min TTL, refresh fires at ~12 min. A token in the 80–100% window is still *returned* to the caller while a background refresh is kicked off (single-flight: concurrent callers await one in-flight refresh, not N parallel mints).
- **No cross-job caching.** Tokens are per-machine, per-run. CI never reads a developer's cached token (see § CI boundary in `SECURITY-PATTERNS.md` § 4).
- `peers-health --auth` in dynamic mode validates the mint path end-to-end and reports **TTL remaining** (Ethan's deliverable, #99 split item 5) — the single diagnostic surface, unchanged.

## Fail-Closed Behavior (BR-DEV-006)

Mint or refresh failure ⇒ **fail fast** with a `PeerCredentialException` whose message names, in one line:

1. the **peer name**,
2. the **token endpoint** that was called (full URL),
3. the HTTP status / failure stage (request, response validation, cache write),
4. the diagnostic command: **`peers-health --auth`**.

Example:

```
PeerCredentialException: Failed to mint UAT credential for peer 'nexus'.
Token endpoint: https://origin-auth.uat.phanes.ltd/realms/oelite-uat/protocol/openid-connect/token
Stage: token request — HTTP 401 (invalid_client). The 'dev-<username>-local' client secret may be rotated or missing
from the OS credential store (oelite/iam/dev-<username>-local).
Diagnose: peers-health --auth
```

Hard rules:

- **No stale-token fallback** — an expired or unparseable cached token is never served, even if a mint attempt just failed. Fail > stale, always.
- **No degraded mode, no mock fallback** — Emma's stakeholder decision 1 on #97 applies unchanged to the dynamic path.
- **Startup vs. on-demand**: peers with `requiredOnStartup: true` (or registry `critical: true`) fail the process at startup on mint failure. Otherwise the exception surfaces at first credential acquisition — but it is still an **exception**, never a null or empty credential.
- Clock not trustworthy? See § Clock Skew — skew never masks an expired token as valid.

## Clock Skew Handling

- The provider treats the local clock as potentially skewed by up to **±60 seconds** against the token endpoint.
- **Conservative direction**: skew is applied so it can only *shorten* the usable window, never extend it. Usable expiry = `expiresAtUtc − max(60s, configured skew)`. A skewed-late clock therefore refreshes slightly early; a skewed-early clock cannot be tricked into serving an expired token.
- Cache TTL metadata uses absolute UTC timestamps (`expiresAtUtc`), not bare durations, so a process restart cannot re-arm a stale token's lifetime.
- The 80% proactive refresh (12 min into a 15-min TTL) sits far from the skew boundary by design — skew handling is a correctness backstop, not the primary refresh trigger.

## Retry Policy

Transient failures (network timeouts, HTTP 502/503/504, connection resets) may be retried:

- **Bounded**: at most **3 attempts total** (1 initial + 2 retries) per credential acquisition.
- **Backoff**: fixed 2 s between attempts — sufficient for a load balancer blip, deliberately not exponential (no long blocking in startup paths).
- **Which failures are retryable**: transport errors and HTTP 502/503/504 only. HTTP 400/401/403 (`invalid_client`, `invalid_scope`, `unauthorized_client`) are **never retried** — they are configuration or registry errors; retrying would only spam the UAT realm's audit log (and trip Ethan's anomaly monitoring per the § 8.2 addendum). Fail fast immediately.
- **No infinite loops**: after the bounded attempts are exhausted, the exception of § Fail-Closed is thrown. There is no background scheduler that keeps re-minting forever; the next acquisition attempt starts a fresh bounded cycle.
- Single-flight refresh: concurrent callers share one attempt cycle; they do not multiply load against the realm.

## Unit-Test Guidance

All tests run under `mock-peers` rules (doc 17 § CI boundary): hermetic, no real network, no real credential store, CI never mints against UAT.

- **Fake token endpoint**: bind an `HttpClient` to a stub `HttpMessageHandler` (or a locally hosted mock server started on an ephemeral `localhost` port). The endpoint is the system under test's configuration, not the real registry entry — tests must never construct requests toward `*.uat.phanes.ltd`.
- **Fake credential store**: in-memory `ICredentialStore` test double backing the cache; assert what gets written (`uat-token` + TTL metadata) and that expired entries are never returned.
- **Fake clock**: inject `Microsoft.Extensions.TimeProvider` (the provider must use `TimeProvider`, never `DateTime.UtcNow` directly) to test: mint-on-first-call, 80%-TTL refresh trigger, expiry rejection, skew shortening of the usable window.
- **Scenario matrix** (minimum):
  1. No cache → mints; correct `grant_type`, `client_id`, exact registry scope string; secret read from store.
  2. Valid cache → no HTTP call; second caller shares the single-flight refresh.
  3. Token in 80–100% window → returned to caller while refresh is in flight.
  4. Expired cache → token never returned even when the mint fails (fail-closed regression test — this is the BR-DEV-006 guard).
  5. Mint HTTP 401 → `PeerCredentialException` naming peer + endpoint + `peers-health --auth`; **no retry**.
  6. Mint HTTP 503 → retried exactly twice, then fail fast.
  7. Response with `expires_in` > 900 → provider still schedules refresh at ≤ 720 s (cap test).
  8. Scope mismatch / response `iss` mismatch → fail fast.
  9. Registry `credentials.mode` = unknown value → startup validation failure.
- **No mock persistence**: the fake store lives in-process for the test run only (per `16-SHARED-LOCAL-INFRASTRUCTURE.md` — the zero-mock-persistence rule concerns shared infrastructure, which these tests do not touch).

## Migration / Rollout

1. Registry MR flips one peer's `credentials.mode` to `dynamic` (Marcus arch review).
2. Each developer machine needs only the bootstrap entry `oelite/iam/dev-<username>-local` (client ID + secret), created once.
3. `peers-health --auth` confirms the mint path + reports TTL remaining before the first UAT session.
4. Static peers are unaffected; `StaticKeychainPeerCredentialProvider` behavior is byte-for-byte v1.

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-11-02 | Daniel | Initial creation — dynamic `IPeerCredentialProvider` spec: `DynamicPeerCredentialProvider`, registry `credentials.mode` selection, Origin Auth client-credentials minting (registry scopes, TTL ≤ 15 min, 80% refresh, `oelite/peer/<peerName>/uat-token` cache), fail-closed per BR-DEV-006, clock-skew + bounded retry policy, unit-test guidance. Issue #99 (TASK-99, joint sign-off note 58524). |
