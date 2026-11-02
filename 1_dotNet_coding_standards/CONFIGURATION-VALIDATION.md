# Configuration Validation — Peer Integration Profiles

**Status**: Active (since 2026-11-02)
**Owner**: Daniel (backend implementation), Marcus (architecture review)
**Related**: `17-LOCAL-DEV-PEER-INTEGRATION.md`, `07-CONFIGURATION-MANAGEMENT.md`, `SECURITY-PATTERNS.md`, `16-SHARED-LOCAL-INFRASTRUCTURE.md`, Issue #97

This document is the canonical **fail-fast validation spec** for the peer-integration profile resolution chain. All OElite .NET apps consuming the `oelite.integration` block implement the behavior defined here; the unit tests in § 7 are the reference acceptance suite.

## 1. Principle: Fail Fast, Never Degrade

Configuration errors are **startup-fatal**. Per Emma's stakeholder decision on #97 (superseding the earlier degraded-mode proposal), there is **no mock fallback, no silent localhost default, no warning-and-continue** for a misconfigured profile. A wrong config that reaches runtime is an incident vector (BR-DEV-001 makes prod isolation incident-level with no exceptions); the only correct behavior is to stop before accepting traffic.

Production would never degrade this way — local dev must not either.

## 2. Configuration Provider Ordering

Resolution order (most-specific wins; defined in Marcus's final spec on #97):

| Level | Source | Example |
|---|---|---|
| 1 | Per-peer env var | `OELITE_PEERS__ORIGINAUTH__PROFILE=uat-peers` (shorthand `OELITE_PEERS__ORIGINAUTH=local` is also honored) |
| 2 | Per-app appsettings override | `integrationProfile.peers.<peerName>.profile` |
| 3 | Global env var | `OELITE_PROFILE` |
| 4 | App default | `integrationProfile.defaultProfile` |
| 5 | Platform default | `local-peers` |

Implementation notes:

- Levels 1 and 3 come through `IConfiguration` with the standard .NET provider order: **environment variables override appsettings.json**. Wire env vars with prefix filtering (`AddEnvironmentVariables("OELITE_")`) so only `OELITE_*` variables participate.
- The resolved snapshot is computed **once at startup** and frozen into the DI container (no hot-swap in v1 — restart required after any change).
- Per-peer env vars use `__` (double underscore) as the section delimiter, per .NET configuration conventions.

## 3. Unknown Profile Rejection

The resolver's vocabulary is **exactly** `{ mock-peers, local-peers, uat-peers }`. Per-peer overrides draw from the same set.

- Any other value — `prod`, `production`, `staging`, `uat`, `local`, typos, casing variants (`UAT-Peers`), or free-form strings — is rejected **at startup** with a message naming the offending configuration key and value.
- Comparisons are ordinal, case-sensitive; there is no normalization step that could silently rescue a typo.
- There is **no `prod` value in the vocabulary at all** (structural prod-prevention — the strongest guard is that the data cannot be expressed).

**Error message format** (stable, greppable):

```
CONFIGURATION ERROR: Unknown peer integration profile '<value>' at '<configKey>'.
Allowed values: mock-peers | local-peers | uat-peers. Check OELITE_PEERS__* / OELITE_PROFILE / appsettings.init.json.
```

## 4. Prod URL Rejection (Fail-Closed, No Exceptions)

Three layers, per Marcus's arbitration — **no CI exception path exists** (Isabella's BR-DEV-001):

### 4.1 Startup resolver validation

After resolution, every resolved peer endpoint must match the allow-list. Anything not matching fails startup:

| Allowed pattern | Matches |
|---|---|
| `localhost` / `127.0.0.1` / `::1` (any port) | Local shared stack |
| `*.uat.phanes.ltd` | UAT peers |

```csharp
private static readonly Regex UatHostPattern =
    new(@"^https?://[a-z0-9-]+\.uat\.phanes\.ltd(:\d+)?$", RegexOptions.IgnoreCase | RegexOptions.Compiled);

private static readonly Regex LocalHostPattern =
    new(@"^https?://(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$", RegexOptions.IgnoreCase | RegexOptions.Compiled);

private static bool IsAllowedEndpoint(string url) =>
    UatHostPattern.IsMatch(url) || LocalHostPattern.IsMatch(url);
```

Regex notes:

- Anchored (`^…$`) — a prod URL embedded in a query string or path cannot slip through a substring match.
- `IgnoreCase` is acceptable here because the *allow-list* side is case-tolerant; the danger (prod hosts) matches nothing on this list by construction.
- Rejection error format:

```
CONFIGURATION ERROR: Resolved endpoint 'https://origin-auth.phanes.ltd' for peer 'originAuth' is not an allowed peer endpoint.
Allowed: *.uat.phanes.ltd or localhost. Prod endpoints never resolve through the integration-profile chain (BR-DEV-001).
```

### 4.2 CI lint

A CI job statically scans **all committed** `appsettings*.json` and env templates for prod host patterns (`phanes.ltd` outside the `.uat.` subdomain, literal prod IPs). The job has **no exception mechanism** — no `# allow` comments, no job-level bypass variables. If it fires, the fix is to correct the file, never to silence the lint.

### 4.3 Registry structural rule

The peer registry schema simply has **no prod-endpoint field**. Production deploys read prod endpoints from CI/CD variables (`$OElite_K8S`, `$PHANES_K8S`), never from the registry. Strongest guard = the data doesn't exist.

## 5. Missing Credential Rejection

- A peer resolved to `uat-peers` **must** have its credential resolvable from the OS credential store (`oelite/peer/<peerName>/<key>` — see `SECURITY-PATTERNS.md`). Missing → fail fast naming the peer and the Keychain item.
- `local-peers` / `mock-peers` peers must **not** trigger credential lookups (no prompts in dev loops).
- Error format:

```
CONFIGURATION ERROR: Peer 'originAuth' is configured as 'uat-peers' but credential 'oelite/peer/originAuth/apiKey' is not present in the OS credential store.
Load it, or switch the peer profile. See 17-LOCAL-DEV-PEER-INTEGRATION.md § Credential Loading.
```

## 6. Startup Wiring Pattern

```csharp
// Program.cs — after config providers are registered, BEFORE builder.Build()
var peerConfig = PeerIntegrationConfig.LoadAndValidate(configuration);
// throws PeerConfigurationException with the messages above on any violation
builder.Services.AddSingleton(peerConfig);
```

`LoadAndValidate` performs, in order: vocabulary check (§ 3) → resolution (§ 2) → endpoint allow-list (§ 4) → credential presence (§ 5) → `peers-health` pre-flight when `requiredOnStartup: true` (failure names the peer + the health-check command). Validation failures throw `PeerConfigurationException` — an unhandled startup exception, not a logged warning.

## 7. Unit Test Examples

Reference tests (xUnit) — implement these in each consuming repo's test suite:

```csharp
public class PeerProfileValidationTests
{
    [Theory]
    [InlineData("prod")]
    [InlineData("production")]
    [InlineData("staging")]
    [InlineData("UAT-Peers")]          // casing variant — no normalization rescue
    [InlineData("local")]              // shorthand not in vocabulary
    [InlineData("")]                   // empty string
    [InlineData("local-peers ")]       // trailing whitespace
    public void Unknown_or_illegal_profile_fails_fast(string badProfile)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["oelite:integration:defaultProfile"] = badProfile
            })
            .Build();

        var act = () => PeerIntegrationConfig.LoadAndValidate(config);

        var ex = Assert.Throws<PeerConfigurationException>(act);
        Assert.Contains(badProfile, ex.Message);
        Assert.Contains("mock-peers | local-peers | uat-peers", ex.Message);
    }

    [Theory]
    [InlineData("https://origin-auth.phanes.ltd")]        // prod hostname
    [InlineData("https://origin-auth.uat.phanes.ltd.evil.example")] // suffix trick
    [InlineData("http://10.0.4.12:8080")]                 // bare IP
    public void Prod_or_non_allowlisted_endpoint_fails_fast(string endpoint)
    {
        var config = BuildConfig(peerName: "originAuth", profile: "uat-peers", endpoint: endpoint);

        var ex = Assert.Throws<PeerConfigurationException>(
            () => PeerIntegrationConfig.LoadAndValidate(config));

        Assert.Contains("not an allowed peer endpoint", ex.Message);
        Assert.Contains("originAuth", ex.Message);
    }

    [Theory]
    [InlineData("https://origin-auth.uat.phanes.ltd")]
    [InlineData("https://origin-auth.uat.phanes.ltd:8443")]
    [InlineData("http://localhost:5001")]
    [InlineData("http://127.0.0.1:27017")]
    public void Allowed_endpoints_pass(string endpoint)
    {
        var config = BuildConfig(peerName: "originAuth", profile: "uat-peers", endpoint: endpoint);

        var resolved = PeerIntegrationConfig.LoadAndValidate(config);

        Assert.Equal(endpoint, resolved.Peers["originAuth"].Endpoint);
    }

    [Fact]
    public void Uat_peer_without_credential_fails_fast()
    {
        var config = BuildConfig(peerName: "originAuth", profile: "uat-peers",
                                 endpoint: "https://origin-auth.uat.phanes.ltd");
        var credentials = new FakePeerCredentialProvider(); // empty store

        var ex = Assert.Throws<PeerConfigurationException>(
            () => PeerIntegrationConfig.LoadAndValidate(config, credentials));

        Assert.Contains("oelite/peer/originAuth/apiKey", ex.Message);
    }

    [Fact]
    public void Per_peer_env_var_overrides_global_profile()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["OELITE_PROFILE"] = "local-peers",
                ["OELITE_PEERS__NEXUS__PROFILE"] = "uat-peers"
            })
            .Build();

        var resolved = PeerIntegrationConfig.LoadAndValidate(config, credentialProvider: new FakePeerCredentialProvider());

        Assert.Equal("uat-peers", resolved.Peers["nexus"].Profile);  // level 1 wins over level 3
        Assert.Equal("local-peers", resolved.DefaultProfile);
    }
}
```

CI runs these under `mock-peers` hermetically (AC-004) — tests never reach UAT.

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-11-02 | Daniel | Initial creation — fail-fast validation spec implementing Marcus's arbitration on #97 (Flag 3: fail-closed prod guard, no CI exception; Flag 1: resolution order), amended by Emma's stakeholder decision #1 (no degraded mode). Issue #97. |
