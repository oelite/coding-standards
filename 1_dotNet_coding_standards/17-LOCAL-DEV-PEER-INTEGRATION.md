# 17. Local Dev Peer Integration

**Status**: Active (since 2026-11-02)
**Owner**: Daniel (backend implementation), Marcus (architecture), Ethan (registry + peers-health)
**Related**: `0_project_planning_standards/BUSINESS-RULEBOOK.md` § 8 (BR-DEV-001..006), `16-SHARED-LOCAL-INFRASTRUCTURE.md`, `CONFIGURATION-VALIDATION.md`, `SECURITY-PATTERNS.md`, Issue #97

## Overview

Local development environments integrate with **peer OElite platform services** (Origin Auth, Kortex, Nexus, OeSterling, Apex, Synapse, Obelisk, Hermes, Orion) through a **profile-based resolution model**. An app's **own data layer always stays on the local shared stack** (`localhost:*`, per `16-SHARED-LOCAL-INFRASTRUCTURE.md`); only **peer service endpoints** are profile-switched.

The three profiles are engineering names (the business rules are BR-DEV-001..006 in the rulebook):

| Profile | Meaning | Peer endpoints resolve to |
|---|---|---|
| `mock-peers` | Hermetic — CI, unit tests, offline dev | In-process mocks / fakes. Never touches network. |
| `local-peers` | Peers run locally (you are developing a peer itself, or a peer runs in the shared stack) | `localhost:*` |
| `uat-peers` | Explicit opt-in to shared UAT | `*.uat.phanes.ltd` (from the central registry) |

**There is no `prod` profile.** Production endpoints are not a field in the peer registry schema and not a value in the resolver's vocabulary — production deploys read prod endpoints from CI/CD variables, never from this configuration chain (see `CONFIGURATION-VALIDATION.md` § Fail-Closed Prod Guard).

The central registry is `infrastructure/oelite-stack/config/peer-registry.yml` — platform-owned, versioned, one review point (Marcus arch review required for registry MRs). Consumers target the `stable` channel only; registry entries pin `minVersion`, `contractUrl`, `contractVersion`, `mutability`, `critical`, `testTenantId`, `resetPolicy`.

## Profile Resolution Order (Final, Marcus's Spec)

Resolution is **most-specific wins**, evaluated top-down; the first hit wins:

1. **Per-peer env var**: `OELITE_PEERS__<PEERNAME>__PROFILE` (e.g. `OELITE_PEERS__ORIGINAUTH=local`, `OELITE_PEERS__NEXUS=uat`) — supports hybrid composition (app is a UAT consumer for one peer and a local provider for another).
2. **Per-app appsettings override**: `integrationProfile.peers.<peerName>.profile`
3. **Global env var**: `OELITE_PROFILE`
4. **App default**: `integrationProfile.defaultProfile`
5. **Platform default**: `local-peers`

Constraints enforced at resolution time:

- The only legal profile values are `mock-peers`, `local-peers`, `uat-peers` (and per-peer overrides from the same set). Any other value — including `prod`, `production`, or free-form strings — is **rejected at startup, fail-fast**.
- A peer is resolved even if no override matches: it falls through to the app default / platform default. An app cannot "opt out" a peer listed in the registry.
- Resolved endpoints must match the allow-list `*.uat.phanes.ltd` or `localhost`. Anything else fails startup (structural prod-prevention — see `CONFIGURATION-VALIDATION.md`).

## appsettings.init.json Structure

Every OElite .NET application's `configs/appsettings.init.json` carries the `oelite.integration` block. Canonical shape with per-peer overrides:

```jsonc
{
  "oelite": {
    "integration": {
      "defaultProfile": "local-peers",          // level 4 of the resolution order; must be in {mock-peers, local-peers, uat-peers}
      "peers": {
        "enabled": true,                         // master switch for peer integration in this app
        "requiredOnStartup": false,              // true = fail startup if any resolved peer fails peers-health
        "timeoutSeconds": 30,                    // per-peer health/connectivity timeout
        "originAuth": {                          // per-peer override — level 2 of the resolution order
          "profile": "uat-peers",                // opt-in to UAT for THIS peer only
          "iamClient": "dev-jdoe-local"          // per-developer UAT IAM client (BR-DEV-005; never the shared acceptance client)
        },
        "nexus": {
          "profile": "local-peers"
        }
      }
    }
  }
}
```

The full minimal spec (the committed template) lives at `1_dotNet_coding_standards/configs/appsettings.init.json`.

Keychain-backed secrets (peer API keys, IAM client secrets) are **never** placed in this file. They load at startup from the OS credential store; see § Credential Loading below and `SECURITY-PATTERNS.md`.

## Credential Loading Pattern

Peer credentials are **per-machine, per-developer** and loaded at startup — never committed (AC-003, BR-DEV-001):

| OS | Store | Reference name convention |
|---|---|---|
| macOS | Keychain Services (`security find-generic-password`) | `oelite/peer/<peerName>/<key>` |
| Windows | Windows Credential Manager (via `CredentialManagement` / P/Invoke) | `oelite/peer/<peerName>/<key>` |
| Linux | libsecret / Secret Service API (`secret-tool`) | `oelite/peer/<peerName>/<key>` |

Reference implementation pattern (`IPeerCredentialProvider`):

```csharp
public interface IPeerCredentialProvider
{
    /// <summary>Fails fast (PeerCredentialException) if the credential is missing — no silent nulls.</summary>
    string GetCredential(string peerName, string key);
}

// macOS implementation sketch: shell out to
//   security find-generic-password -s "oelite/peer/originAuth/apiKey" -w
// Do NOT put the secret in appsettings, environment files, or code.
```

Rules:

- Startup resolves the credential **only for peers whose profile is `uat-peers`**; `local-peers`/`mock-peers` peers must not prompt or load secrets.
- Missing credential for a UAT peer → **fail fast** with a message naming the peer and the Keychain item (no silent degradation — Emma's stakeholder decision supersedes any mock-fallback behavior).
- Rotation SLA: ≤ 90 days. `peers-health --auth` validates credentials, not just reachability (Ethan's utility).
- `dev-<username>-local` UAT IAM clients only; never the shared UAT acceptance client (BR-DEV-005).
- Short-lived dynamic credentials (token minting via Origin Auth) are **V2 — TBD, pending Emma + Ethan joint sign-off**. Do not implement in v1.

## Dynamic Peer Credentials (V2 — Cross-Reference)

When a peer's registry entry sets `credentials.mode: dynamic`, UAT peer credentials are **minted** (not loaded): the `DynamicPeerCredentialProvider` performs an Origin Auth **client-credentials** grant with the per-developer `dev-<username>-local` IAM client, requesting exactly the registry-declared `credentials.scopes`, with a **TTL ≤ 15 min** and proactive refresh at **80% of TTL**, cached under `oelite/peer/<peerName>/uat-token`.

This document remains the source of truth for the **static** path (registry resolution, profile rules, Keychain loading, `peers-health` pre-flight). The **normative spec for the dynamic path** — provider selection by registry `credentials.mode`, minting flow, caching/refresh semantics, fail-closed behavior per BR-DEV-006, clock-skew and retry policy, and unit-test guidance — lives in **`18-DYNAMIC-PEER-CREDENTIALS.md`**. Read both before implementing dynamic-mode peer integration.

## Restart Required (No Hot-Swap in v1)

Changing any value in the resolution chain (env vars, appsettings) requires an **application restart**. The profile snapshot is resolved once at startup and frozen into the DI container. There is no hot-reload of peer profiles in v1; on-profile-change detection is a V2 candidate. Document this in developer onboarding — a "changed env var but nothing happened" session is almost always a stale process.

## Fail-Fast Validation Summary

All validation happens at startup, before the host accepts traffic (full logic + unit tests in `CONFIGURATION-VALIDATION.md`):

1. Unknown profile value → fail fast, message names the offending key and value.
2. Resolved endpoint not matching `*.uat.phanes.ltd` or `localhost` → fail fast (prod rejection).
3. Missing credential for a `uat-peers` peer → fail fast with Keychain item name.
4. `requiredOnStartup: true` and a peer fails `peers-health` → fail fast naming the peer + the health-check command.

## Examples

### Example 1 — Pure local development (`local-peers`, the default)

```jsonc
{
  "oelite": {
    "integration": {
      "defaultProfile": "local-peers",
      "peers": { "enabled": true, "requiredOnStartup": false, "timeoutSeconds": 30 }
    }
  }
}
```

All peers resolve to `localhost:*` (shared stack). No credentials required. The app's own data layer also points at the local shared stack — nothing touches UAT.

### Example 2 — UAT opt-in with per-peer override (`uat-peers` hybrid)

Developer is integrating against real Origin Auth but everything else stays local:

```bash
export OELITE_PROFILE=local-peers            # global baseline
export OELITE_PEERS__ORIGINAUTH=uat-peers    # per-peer opt-in wins (resolution level 1)
```

```jsonc
{
  "oelite": {
    "integration": {
      "defaultProfile": "local-peers",
      "peers": {
        "enabled": true,
        "requiredOnStartup": true,           // auth integration task → fail if Origin Auth unreachable
        "timeoutSeconds": 30,
        "originAuth": {
          "profile": "uat-peers",
          "iamClient": "dev-jdoe-local"
        }
      }
    }
  }
}
```

Result: Origin Auth resolves to `https://origin-auth.uat.phanes.ltd` from the registry; all other peers stay `localhost`. Writes into UAT carry the `dev-jdoe-` identifier prefix (BR-DEV-005); mutation is tenant-scoped against the registry-declared `testTenantId`.

## Migration / Backward Compatibility

- Existing repos with hardcoded localhost peer URLs keep working: `mock-peers`/`local-peers` resolve to the same endpoints. Adoption is opt-in via the `integrationProfile` block.
- Adding a repo's peer to the registry = MR to `peer-registry.yml` + `peers-health` registration check. No code change in consuming apps.
- Deprecation: hardcoded peer URLs in appsettings produce a startup warning during a deprecation window, then become validation errors (same fail-fast path).

## CI / Testing Boundary (AC-004)

Unit tests and CI pipelines run hermetically under `mock-peers` only. CI must never reach UAT. Contract checks against peers run locally using the registry's `contractUrl`/`contractVersion` (contract testing against shared staging is an anti-pattern — surface integration failures in pipelines, not shared environments).

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-11-02 | Daniel | Initial creation — implements Marcus's final arbitration spec on #97 (Flags 1–3), amended by Emma's stakeholder decisions (fail-fast over degraded mode; per-developer IAM clients; V2 short-lived creds pending sign-off). Issue #97. |
| 2026-11-02 | Daniel | Added § Dynamic Peer Credentials (V2) cross-reference to `18-DYNAMIC-PEER-CREDENTIALS.md` per the approved joint sign-off on #99. Issue #99. |
