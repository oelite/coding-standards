# Security Patterns

**Status**: Active (since 2026-11-02)
**Owner**: Maya (security review), Daniel (backend implementation patterns)
**Related**: `17-LOCAL-DEV-PEER-INTEGRATION.md`, `CONFIGURATION-VALIDATION.md`, `16-SHARED-LOCAL-INFRASTRUCTURE.md`, Issue #97

## Overview

This document codifies the mandatory credential-handling patterns for OElite applications, with emphasis on local-development peer integration (UAT peers). These patterns implement AC-003 of the peer-integration standard and the permission boundaries agreed on #97.

## 1. Keychain / OS Credential Store Loading (Mandatory)

Peer and platform credentials are **per-machine, per-developer** and loaded at startup from the OS-native credential store — never from committed files, never from appsettings, never from shell history or environment files checked into git.

| OS | Store | Tooling |
|---|---|---|
| macOS | Keychain Services | `security find-generic-password -s "<name>" -w` |
| Windows | Windows Credential Manager | `CredentialManagement` NuGet / P/Invoke (`CredRead`) |
| Linux | Secret Service API (libsecret / gnome-keyring) | `secret-tool lookup <attributes>` |

**Naming convention (required):** `oelite/peer/<peerName>/<key>` — e.g. `oelite/peer/originAuth/apiKey`, `oelite/peer/originAuth/iamClientSecret`.

**Loading pattern (`IPeerCredentialProvider`):**

```csharp
public interface IPeerCredentialProvider
{
    /// <summary>Fails fast (PeerCredentialException) if the credential is missing — no silent nulls, no empty-string defaults.</summary>
    string GetCredential(string peerName, string key);
}
```

- Credentials resolve **only** for peers whose profile is `uat-peers`. `local-peers`/`mock-peers` peers never trigger credential lookups.
- Missing credential → **startup failure** naming the peer and the credential-store item (fail-fast — no degraded mode per the #97 stakeholder decision).
- Developers hold **read-only or tenant-scoped-write UAT credentials only**. Admin/service-root UAT credentials never exist on developer machines.
- UAT IAM access uses a **dedicated per-developer client** named `dev-<username>-local`, registered in the UAT realm with only registry-declared scopes. Never use the shared UAT acceptance client (BR-DEV-005).

## 2. Rotation SLA

- All static peer credentials (API keys, IAM client secrets) **rotate every ≤ 90 days**.
- `peers-health --auth` validates credential *validity*, not just endpoint reachability — an expired/revoked credential is a health failure (Ethan's utility; registry-declared).
- On rotation: update the OS credential store entry first, restart the app (profiles and credentials are startup-frozen; no hot-swap in v1).

## 3. Never Commit Credentials

- `appsettings.init.json` and env templates carry **structure and non-secret values only**. Any field that would hold a secret is loaded from the credential store instead.
- `.gitignore` (and CI lint) must cover secret-bearing file patterns: `*.secrets.json`, `.env*`, `clusters/` (kubeconfigs — see `16-SHARED-LOCAL-INFRASTRUCTURE.md`), `*.pfx`, `*.pem`.
- The CI lint for prod host patterns (see `CONFIGURATION-VALIDATION.md` § 4.2) additionally greps committed configs for secret-shaped values (`password=`, `secret=`, `apiKey=` with literal values) — findings block the pipeline with no exception path.
- If a credential ever lands in a commit: treat as **incident-level** — rotate the credential immediately, then purge history. Rotation first, history rewrite second.

## 4. Short-Lived Dynamic Credentials (V2 — Normative)

**Status: approved — joint Emma + Ethan design sign-off on #99 (note 58524).**

When a peer's `peer-registry.yml` entry sets `credentials.mode: dynamic`, UAT peer credentials are obtained by **minting short-lived tokens via the Origin Auth client-credentials flow**, using the existing per-developer IAM client `dev-<username>-local` (BR-DEV-005) — no new client type. Scopes are limited to the registry-declared `credentials.scopes`; the registry MR is the only path to widen token reach.

- **TTL**: ≤ 15 minutes, minted lazily at startup for peers resolved under the `uat-peers` profile, refreshed on demand at **80% of TTL (~12 min)**.
- **Caching**: tokens are cached in the OS credential store under `oelite/peer/<peerName>/uat-token` with TTL metadata; no cross-run or cross-job caching.
- **Fail-closed (BR-DEV-006)**: mint/refresh failure **fails fast at startup**, naming the peer, token endpoint, and `peers-health`. No stale-token fallback, no degraded mode; `critical: true` peers hard-fail as today. In dynamic mode no long-lived per-peer app secret exists on the machine.
- **Rotation**: the 90-day rotation SLA applies to the **bootstrap IAM client only**; dynamic-mode peers drop per-peer app-credential rotation. Infra credentials are out of scope (stay on their own SLAs, cf. #37).
- **CI boundary**: hermetic CI (`mock-peers`) never mints. Integration jobs hitting UAT peers use pipeline-scoped per-project IAM clients, minted per run, never cached.
- **Staged rollout**: `credentials.mode: static` is the platform default; dynamic mode is enabled per-peer via the registry. Static Keychain entries (v1) remain valid. `peers-health --auth` validates the mint path and reports TTL remaining.

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-11-02 | Daniel | Initial creation — OS credential-store loading pattern, rotation SLA, no-commit rules, V2 short-lived-credential placeholder. Issue #97. |
| 2026-11-02 | Isabella | § 4 placeholder replaced with normative V2 dynamic-credential pattern (minting, TTL, caching, fail-closed, staged rollout) per joint Emma+Ethan sign-off on #99. |
