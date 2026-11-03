// =============================================================================
// peers-health — OElite UAT peer availability & version checker (TASK-97, #97)
// =============================================================================
// Implements Marcus's final spec (issue #97, note 58413 §"peers-health"):
//   Options : --profile, --strict, --json, --auth, --peer (repeatable), --verbose
//   Exit 0  : all checked peers healthy
//   Exit 1  : at least one critical peer failed (or --strict and any failure)
//   Exit 2  : configuration error (registry missing/invalid, unknown profile)
//
// Emma's stakeholder decision 1 (#97 note 58415): local dev FAILS FAST when a
// required peer is down — this tool is the pre-flight prevention mechanism.
// There is no degraded/mock fallback mode here.
// =============================================================================

using System.Diagnostics;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace OElite.Tools.PeersHealth;

internal static class Program
{
    private const int ExitOk = 0;
    private const int ExitCriticalFailure = 1;
    private const int ExitConfigError = 2;

    private static int Main(string[] args)
    {
        var options = Options.Parse(args);
        if (options is null)
        {
            Options.PrintUsage();
            return ExitConfigError;
        }

        try
        {
            return RunAsync(options).GetAwaiter().GetResult();
        }
        catch (PeersHealthException ex)
        {
            Console.Error.WriteLine($"CONFIG ERROR: {ex.Message}");
            return ExitConfigError;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"UNEXPECTED ERROR: {ex.Message}");
            if (options.Verbose)
            {
                Console.Error.WriteLine(ex.ToString());
            }

            return ExitConfigError;
        }
    }

    private static async Task<int> RunAsync(Options options)
    {
        var registry = RegistryLoader.Load(options.RegistryPath);
        var validator = new RegistryValidator();
        var validationErrors = validator.Validate(registry);
        if (validationErrors.Count > 0)
        {
            foreach (var error in validationErrors)
            {
                Console.Error.WriteLine($"CONFIG ERROR: {error}");
            }

            return ExitConfigError;
        }

        if (!registry.Profiles.ContainsKey(options.Profile))
        {
            Console.Error.WriteLine(
                $"CONFIG ERROR: unknown profile '{options.Profile}'. " +
                $"Allowed: {string.Join(", ", registry.Profiles.Keys)} (prod is not a resolvable profile).");
            return ExitConfigError;
        }

        var selected = registry.Peers
            .Where(p => options.PeerFilter.Count == 0 || options.PeerFilter.Contains(p.Name))
            .ToList();

        foreach (var requested in options.PeerFilter)
        {
            if (registry.Peers.All(p => p.Name != requested))
            {
                Console.Error.WriteLine($"CONFIG ERROR: unknown peer '{requested}' in registry.");
                return ExitConfigError;
            }
        }

        var authErrors = options.Auth ? CredentialChecker.ValidateCredentials(selected) : new List<string>();

        // V2 (TASK-99): dynamic-mode peers validate the full mint path
        // (client-credentials exchange against the token endpoint) instead of
        // a Keychain lookup; static peers keep the Keychain validation.
        var dynamicAuthResults = options.Auth
            ? await DynamicAuthValidator.ValidateDynamicPeersAsync(selected, options.Verbose).ConfigureAwait(false)
            : new Dictionary<string, DynamicAuthResult>();

        if (authErrors.Count > 0)
        {
            foreach (var error in authErrors)
            {
                Console.Error.WriteLine($"AUTH ERROR: {error}");
            }

            return ExitConfigError;
        }

        // Check if any dynamic peer failed minting and is critical
        var dynamicFailures = dynamicAuthResults.Values.Where(r => !r.Valid).ToList();
        if (dynamicFailures.Count > 0)
        {
            foreach (var failure in dynamicFailures)
            {
                Console.Error.WriteLine($"AUTH ERROR (dynamic mint failed): {failure.Peer}: {failure.Error}");
            }

            // In strict mode or if any critical peer failed dynamic auth, abort or flag as error
            var criticalFailed = dynamicFailures.Any(f => selected.Any(p => p.Name == f.Peer && p.Critical));
            if (criticalFailed || options.Strict)
            {
                return ExitConfigError;
            }
        }

        using var http = HttpClientFactory.Create(options.Auth, options.Verbose);
        var results = await PeerChecker.CheckAllAsync(http, registry, selected, options).ConfigureAwait(false);

        var report = ReportBuilder.Build(registry, options.Profile, results, options, dynamicAuthResults);
        if (options.Json)
        {
            Console.WriteLine(JsonSerializer.Serialize(report, PeersJsonContext.Default.HealthReport));
        }
        else
        {
            ReportPrinter.Print(report, options.Verbose);
        }

        var strictFailed = options.Strict && report.Summary.FailedPeers > 0;
        return report.Summary.FailedCriticalPeers > 0 || strictFailed ? ExitCriticalFailure : ExitOk;
    }
}

// -----------------------------------------------------------------------------
// CLI options — exact surface from Marcus's spec Section 4
// -----------------------------------------------------------------------------

internal sealed class Options
{
    public string Profile { get; private set; } = "uat-peers";
    public bool Strict { get; private set; }
    public bool Json { get; private set; }
    public bool Auth { get; private set; }
    public bool Verbose { get; private set; }
    public List<string> PeerFilter { get; } = new();
    public string RegistryPath { get; private set; } = DefaultRegistryPath();
    public int TimeoutSeconds { get; private set; } = 10;

    public static string DefaultRegistryPath()
    {
        // Walk up from CWD looking for infrastructure/oelite-stack/config/peer-registry.yml
        var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
        while (dir is not null)
        {
            var candidate = Path.Combine(
                dir.FullName, "infrastructure", "oelite-stack", "config", "peer-registry.yml");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        return Path.Combine("infrastructure", "oelite-stack", "config", "peer-registry.yml");
    }

    public static Options? Parse(string[] args)
    {
        var options = new Options();
        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--profile":
                    if (!TryNext(args, ref i, out var profile))
                    {
                        return null;
                    }

                    options.Profile = profile;
                    break;
                case "--strict":
                    options.Strict = true;
                    break;
                case "--json":
                    options.Json = true;
                    break;
                case "--auth":
                    options.Auth = true;
                    break;
                case "--verbose":
                    options.Verbose = true;
                    break;
                case "--peer":
                    if (!TryNext(args, ref i, out var peer))
                    {
                        return null;
                    }

                    options.PeerFilter.Add(peer);
                    break;
                case "--registry":
                    if (!TryNext(args, ref i, out var registryPath))
                    {
                        return null;
                    }

                    options.RegistryPath = registryPath;
                    break;
                case "--timeout":
                    if (!TryNext(args, ref i, out var timeoutRaw)
                        || !int.TryParse(timeoutRaw, out var timeout)
                        || timeout <= 0)
                    {
                        return null;
                    }

                    options.TimeoutSeconds = timeout;
                    break;
                case "-h" or "--help":
                    return null;
                default:
                    Console.Error.WriteLine($"Unknown option: {args[i]}");
                    return null;
            }
        }

        return options;
    }

    private static bool TryNext(string[] args, ref int i, out string value)
    {
        if (i + 1 < args.Length)
        {
            value = args[++i];
            return true;
        }

        value = string.Empty;
        return false;
    }

    public static void PrintUsage()
    {
        Console.WriteLine("""
            peers-health — OElite peer availability & version checker (TASK-97)

            Usage:
              peers-health [options]

            Options:
              --profile <name>   Profile to resolve endpoints against: mock-peers | local-peers | uat-peers (default: uat-peers)
              --strict           Fail (exit 1) when ANY checked peer is down, not only critical ones
              --json             Emit machine-readable JSON report instead of terminal format
              --auth             Also validate per-peer credentials: static peers via Keychain lookup, dynamic peers (credentials.mode: dynamic, V2 TASK-99) via a full client-credentials mint against the UAT token endpoint, reporting TTL remaining
              --peer <name>      Check only the named peer (repeatable)
              --registry <path>  Override path to peer-registry.yml
              --timeout <sec>    Per-request timeout in seconds (default: 10)
              --verbose          Include latency/version detail and per-request diagnostics
              -h, --help         Show this help

            Exit codes:
              0  all checked peers healthy
              1  at least one critical peer failed (or --strict and any failure)
              2  configuration error (registry missing/invalid, unknown profile/peer)
            """);
    }
}

// -----------------------------------------------------------------------------
// Registry model (matches peer-registry.yml schema v1)
// -----------------------------------------------------------------------------

public sealed class PeerRegistry
{
    [JsonPropertyName("schemaVersion")]
    public int SchemaVersion { get; set; }

    [JsonPropertyName("registryVersion")]
    public int RegistryVersion { get; set; }

    [JsonPropertyName("profiles")]
    public Dictionary<string, ProfileDefinition> Profiles { get; set; } = new();

    [JsonPropertyName("peers")]
    public List<PeerDefinition> Peers { get; set; } = new();
}

public sealed class ProfileDefinition
{
    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("endpointPattern")]
    public string EndpointPattern { get; set; } = string.Empty;

    [JsonPropertyName("allowedInCi")]
    public bool AllowedInCi { get; set; }
}

public sealed class PeerDefinition
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = string.Empty;

    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;

    [JsonPropertyName("description")]
    public string Description { get; set; } = string.Empty;

    [JsonPropertyName("repository")]
    public string Repository { get; set; } = string.Empty;

    [JsonPropertyName("endpoints")]
    public PeerEndpoints Endpoints { get; set; } = new();

    [JsonPropertyName("contractUrl")]
    public string ContractUrl { get; set; } = string.Empty;

    [JsonPropertyName("contractVersion")]
    public string ContractVersion { get; set; } = string.Empty;

    [JsonPropertyName("minVersion")]
    public string MinVersion { get; set; } = string.Empty;

    [JsonPropertyName("channel")]
    public string Channel { get; set; } = string.Empty;

    [JsonPropertyName("critical")]
    public bool Critical { get; set; }

    [JsonPropertyName("mutability")]
    public string Mutability { get; set; } = string.Empty;

    [JsonPropertyName("testTenantId")]
    public string TestTenantId { get; set; } = string.Empty;

    [JsonPropertyName("resetPolicy")]
    public string ResetPolicy { get; set; } = string.Empty;

    [JsonPropertyName("credentials")]
    public PeerCredentials Credentials { get; set; } = new();

    [JsonPropertyName("healthEndpoint")]
    public string HealthEndpoint { get; set; } = string.Empty;

    [JsonPropertyName("versionEndpoint")]
    public string VersionEndpoint { get; set; } = string.Empty;
}

public sealed class PeerEndpoints
{
    [JsonPropertyName("uat")]
    public string Uat { get; set; } = string.Empty;

    [JsonPropertyName("local")]
    public string Local { get; set; } = string.Empty;
}

public sealed class PeerCredentials
{
    [JsonPropertyName("mode")]
    public string Mode { get; set; } = "static";

    [JsonPropertyName("source")]
    public string Source { get; set; } = string.Empty;

    [JsonPropertyName("keychainService")]
    public string KeychainService { get; set; } = string.Empty;

    [JsonPropertyName("scopes")]
    public List<string> Scopes { get; set; } = new();
}

internal static class RegistryLoader
{
    public static PeerRegistry Load(string path)
    {
        if (!File.Exists(path))
        {
            throw new PeersHealthException(
                $"Peer registry not found at '{path}'. Expected infrastructure/oelite-stack/config/peer-registry.yml " +
                "(run from repo root, or pass --registry <path>).");
        }

        try
        {
            var yaml = File.ReadAllText(path);
            var deserializer = new DeserializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .IgnoreUnmatchedProperties()
                .Build();
            var registry = deserializer.Deserialize<PeerRegistry>(yaml)
                ?? throw new PeersHealthException($"Peer registry at '{path}' is empty.");
            return registry;
        }
        catch (YamlDotNet.Core.YamlException ex)
        {
            throw new PeersHealthException($"Peer registry at '{path}' is not valid YAML: {ex.Message}");
        }
    }
}

// -----------------------------------------------------------------------------
// Registry validation — structural prod-prevention (fail-closed)
// -----------------------------------------------------------------------------

internal sealed class RegistryValidator
{
    public List<string> Validate(PeerRegistry registry)
    {
        var errors = new List<string>();
        if (registry.SchemaVersion != 1)
        {
            errors.Add($"Unsupported schemaVersion {registry.SchemaVersion} (expected 1).");
        }

        if (registry.Peers.Count == 0)
        {
            errors.Add("Registry declares no peers.");
        }

        foreach (var profile in registry.Profiles)
        {
            if (profile.Key.Contains("prod", StringComparison.OrdinalIgnoreCase))
            {
                errors.Add($"Profile '{profile.Key}' contains 'prod' — prod is not a resolvable profile (Marcus Flag 3).");
            }
        }

        var seen = new HashSet<string>();
        foreach (var peer in registry.Peers)
        {
            if (!seen.Add(peer.Name))
            {
                errors.Add($"Duplicate peer name '{peer.Name}'.");
                continue;
            }

            if (string.IsNullOrWhiteSpace(peer.Endpoints.Uat)
                || !Uri.TryCreate(peer.Endpoints.Uat, UriKind.Absolute, out var uatUri)
                || !uatUri.Host.EndsWith(".uat.phanes.ltd", StringComparison.Ordinal))
            {
                errors.Add(
                    $"Peer '{peer.Name}': uat endpoint must be an https://*.uat.phanes.ltd URL " +
                    $"(fail-closed prod guard; got '{peer.Endpoints.Uat}').");
            }

            if (string.IsNullOrWhiteSpace(peer.Endpoints.Local)
                || !Uri.TryCreate(peer.Endpoints.Local, UriKind.Absolute, out var localUri)
                || localUri.Host != "localhost")
            {
                errors.Add($"Peer '{peer.Name}': local endpoint must be an http://localhost:<port> URL.");
            }

            if (!Version.TryParse(peer.MinVersion, out _))
            {
                errors.Add($"Peer '{peer.Name}': minVersion '{peer.MinVersion}' is not a valid version.");
            }

            if (peer.Channel != "stable")
            {
                errors.Add($"Peer '{peer.Name}': channel '{peer.Channel}' invalid — consumers target stable only (v1).");
            }

            if (peer.Mutability is not ("read-only" or "tenant-scoped" or "mutable"))
            {
                errors.Add($"Peer '{peer.Name}': mutability '{peer.Mutability}' invalid.");
            }

            if (peer.Credentials.Source != "keychain")
            {
                errors.Add(
                    $"Peer '{peer.Name}': credentials.source '{peer.Credentials.Source}' invalid — " +
                    "credentials live in per-machine Keychain, never committed (AC-003).");
            }

            if (peer.Credentials.Scopes.Count == 0)
            {
                errors.Add($"Peer '{peer.Name}': credentials.scopes must declare at least one least-privilege scope.");
            }
        }

        return errors;
    }
}

// -----------------------------------------------------------------------------
// Credentials check (--auth)
// -----------------------------------------------------------------------------

internal static class CredentialChecker
{
    public static List<string> ValidateCredentials(List<PeerDefinition> peers)
    {
        var errors = new List<string>();
        foreach (var peer in peers)
        {
            if (peer.Credentials.Source != "keychain")
            {
                continue;
            }

            // V2 (TASK-99): dynamic-mode peers validate the full mint path
            // (client-credentials exchange) instead of a Keychain lookup.
            if (peer.Credentials.Mode == "dynamic")
            {
                continue; // validated asynchronously by DynamicAuthValidator (RunAsync)
            }

            var (exitCode, _) = Run("security", $"find-generic-password -s \"{peer.Credentials.KeychainService}\" -a oelite");
            if (exitCode != 0)
            {
                errors.Add(
                    $"Peer '{peer.Name}': credential not found in Keychain (service " +
                    $"'{peer.Credentials.KeychainService}'). Provision it with: " +
                    $"security add-generic-password -s \"{peer.Credentials.KeychainService}\" -a oelite -w <secret> -U");
            }
        }

        return errors;
    }

    private static (int ExitCode, string Output) Run(string fileName, string arguments)
    {
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            };
            using var process = Process.Start(psi);
            if (process is null)
            {
                return (-1, "process failed to start");
            }

            var output = process.StandardOutput.ReadToEnd();
            process.WaitForExit(5000);
            return (process.ExitCode, output);
        }
        catch (Exception ex)
        {
            return (-1, ex.Message);
        }
    }
}

// -----------------------------------------------------------------------------
// Dynamic credential validation (--auth, V2 TASK-99)
// -----------------------------------------------------------------------------

public sealed class DynamicAuthResult
{
    [JsonPropertyName("peer")]
    public string Peer { get; set; } = string.Empty;

    [JsonPropertyName("mode")]
    public string Mode { get; set; } = "static";

    [JsonPropertyName("valid")]
    public bool Valid { get; set; }

    [JsonPropertyName("tokenTtlSecondsRemaining")]
    public int? TokenTtlSecondsRemaining { get; set; }

    [JsonPropertyName("tokenEndpoint")]
    public string? TokenEndpoint { get; set; }

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}

internal static class DynamicAuthValidator
{
    // V2 (TASK-99): environment-provided client credentials for the UAT IAM
    // bootstrap client (dev-<username>-local on dev machines; pipeline-scoped
    // per-project client in CI). Never read from disk, never cached.
    private const string ClientIdEnvVar = "OELITE_UAT_IAM_CLIENT_ID";
    private const string ClientSecretEnvVar = "OELITE_UAT_IAM_CLIENT_SECRET";
    private const string TokenEndpointEnvVar = "OELITE_UAT_TOKEN_ENDPOINT";
    private const string DefaultTokenEndpoint = "https://origin-auth.uat.phanes.ltd/connect/token";

    public static async Task<Dictionary<string, DynamicAuthResult>> ValidateDynamicPeersAsync(
        List<PeerDefinition> peers, bool verbose)
    {
        var results = new Dictionary<string, DynamicAuthResult>();
        var dynamicPeers = peers.Where(p => p.Credentials.Mode == "dynamic").ToList();
        if (dynamicPeers.Count == 0)
        {
            return results;
        }

        var clientId = Environment.GetEnvironmentVariable(ClientIdEnvVar);
        var clientSecret = Environment.GetEnvironmentVariable(ClientSecretEnvVar);
        var tokenEndpoint = Environment.GetEnvironmentVariable(TokenEndpointEnvVar) ?? DefaultTokenEndpoint;

        foreach (var peer in dynamicPeers)
        {
            var result = new DynamicAuthResult
            {
                Peer = peer.Name,
                Mode = "dynamic",
                TokenEndpoint = tokenEndpoint,
            };

            if (string.IsNullOrEmpty(clientId) || string.IsNullOrEmpty(clientSecret))
            {
                result.Error =
                    $"dynamic-mode peer requires {ClientIdEnvVar} and {ClientSecretEnvVar} in the environment " +
                    "(dev: dev-<username>-local IAM client via Keychain bootstrap; CI: pipeline-scoped per-project " +
                    "client from protected variables — never committed, never cached).";
                results[peer.Name] = result;
                continue;
            }

            try
            {
                using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
                using var form = new FormUrlEncodedContent(new Dictionary<string, string>
                {
                    ["grant_type"] = "client_credentials",
                    ["client_id"] = clientId,
                    ["client_secret"] = clientSecret,
                    ["scope"] = string.Join(" ", peer.Credentials.Scopes),
                });

                using var response = await http.PostAsync(tokenEndpoint, form).ConfigureAwait(false);
                var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!response.IsSuccessStatusCode)
                {
                    result.Error = $"token endpoint returned HTTP {(int)response.StatusCode}: {Truncate(body)}";
                    results[peer.Name] = result;
                    continue;
                }

                using var doc = JsonDocument.Parse(body);
                var expiresIn = doc.RootElement.TryGetProperty("expires_in", out var expEl)
                    && expEl.TryGetInt32(out var exp)
                    ? exp
                    : (int?)null;
                var issuedToken = doc.RootElement.TryGetProperty("access_token", out var tokenEl)
                    && tokenEl.ValueKind == JsonValueKind.String;

                if (!issuedToken || expiresIn is null || expiresIn <= 0)
                {
                    result.Error = "token response missing access_token or expires_in.";
                    results[peer.Name] = result;
                    continue;
                }

                if (expiresIn > 900)
                {
                    result.Error = $"TTL {expiresIn}s exceeds the 15-minute V2 ceiling (BR-DEV-004).";
                    results[peer.Name] = result;
                    continue;
                }

                result.Valid = true;
                result.TokenTtlSecondsRemaining = expiresIn;
                if (verbose)
                {
                    Console.Error.WriteLine($"[auth] {peer.Name}: minted token, TTL {expiresIn}s (scopes: {string.Join(" ", peer.Credentials.Scopes)})");
                }
            }
            catch (Exception ex)
            {
                result.Error = $"mint failed: {ex.Message}";
            }

            results[peer.Name] = result;
        }

        return results;
    }

    private static string Truncate(string value)
    {
        var trimmed = value.Trim();
        return trimmed.Length <= 128 ? trimmed : trimmed[..128] + "…";
    }
}

// -----------------------------------------------------------------------------
// Peer health checking
// -----------------------------------------------------------------------------

public sealed class PeerCheckResult
{
    [JsonPropertyName("peer")]
    public string Peer { get; set; } = string.Empty;

    [JsonPropertyName("displayName")]
    public string DisplayName { get; set; } = string.Empty;

    [JsonPropertyName("endpoint")]
    public string Endpoint { get; set; } = string.Empty;

    [JsonPropertyName("critical")]
    public bool Critical { get; set; }

    [JsonPropertyName("status")]
    public string Status { get; set; } = "unknown";

    [JsonPropertyName("latencyMs")]
    public long? LatencyMs { get; set; }

    [JsonPropertyName("version")]
    public string? Version { get; set; }

    [JsonPropertyName("minVersion")]
    public string? MinVersion { get; set; }

    [JsonPropertyName("versionDrift")]
    public bool? VersionDrift { get; set; }

    [JsonPropertyName("error")]
    public string? Error { get; set; }
}

internal static class PeerChecker
{
    public static async Task<List<PeerCheckResult>> CheckAllAsync(
        HttpClient http,
        PeerRegistry registry,
        List<PeerDefinition> peers,
        Options options)
    {
        var results = new List<PeerCheckResult>();
        foreach (var peer in peers)
        {
            results.Add(await CheckOneAsync(http, registry, peer, options).ConfigureAwait(false));
        }

        return results;
    }

    private static async Task<PeerCheckResult> CheckOneAsync(
        HttpClient http,
        PeerRegistry registry,
        PeerDefinition peer,
        Options options)
    {
        var result = new PeerCheckResult
        {
            Peer = peer.Name,
            DisplayName = peer.DisplayName,
            Critical = peer.Critical,
            MinVersion = peer.MinVersion,
        };

        string baseUrl;
        if (options.Profile == "uat-peers")
        {
            baseUrl = peer.Endpoints.Uat;
        }
        else if (options.Profile == "local-peers")
        {
            baseUrl = peer.Endpoints.Local;
        }
        else
        {
            // mock-peers: nothing to probe over HTTP — hermetic by definition.
            result.Status = "mocked";
            result.Endpoint = registry.Profiles["mock-peers"].EndpointPattern;
            return result;
        }

        result.Endpoint = baseUrl.TrimEnd('/') + peer.HealthEndpoint;

        var sw = Stopwatch.StartNew();
        try
        {
            using var response = await http.GetAsync(result.Endpoint).ConfigureAwait(false);
            sw.Stop();
            result.LatencyMs = sw.ElapsedMilliseconds;

            if (!response.IsSuccessStatusCode)
            {
                result.Status = "down";
                result.Error = $"health endpoint returned HTTP {(int)response.StatusCode}";
                return result;
            }

            result.Status = "healthy";

            if (!options.Verbose)
            {
                return result;
            }

            var version = await TryGetVersionAsync(http, baseUrl.TrimEnd('/') + peer.VersionEndpoint).ConfigureAwait(false);
            result.Version = version;
            if (version is not null
                && Version.TryParse(version, out var actual)
                && Version.TryParse(peer.MinVersion, out var min))
            {
                result.VersionDrift = actual < min;
            }
        }
        catch (Exception ex)
        {
            sw.Stop();
            result.LatencyMs = sw.ElapsedMilliseconds;
            result.Status = "down";
            result.Error = ex.Message;
        }

        return result;
    }

    private static async Task<string?> TryGetVersionAsync(HttpClient http, string url)
    {
        try
        {
            using var response = await http.GetAsync(url).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                return null;
            }

            var body = await response.Content.ReadAsStringAsync().ConfigureAwait(false);
            try
            {
                using var doc = JsonDocument.Parse(body);
                if (doc.RootElement.TryGetProperty("version", out var versionElement)
                    && versionElement.ValueKind == JsonValueKind.String)
                {
                    return versionElement.GetString();
                }

                return doc.RootElement.ValueKind == JsonValueKind.String ? doc.RootElement.GetString() : null;
            }
            catch (JsonException)
            {
                return body.Trim().Length <= 64 ? body.Trim() : null;
            }
        }
        catch (Exception)
        {
            return null;
        }
    }
}

internal static class HttpClientFactory
{
    public static HttpClient Create(bool auth, bool verbose)
    {
        var handler = new SocketsHttpHandler
        {
            AutomaticDecompression = System.Net.DecompressionMethods.All,
        };
        var client = new HttpClient(handler)
        {
            Timeout = TimeSpan.FromSeconds(10),
        };
        client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        client.DefaultRequestHeaders.UserAgent.ParseAdd("oelite-peers-health/1.0");
        if (verbose)
        {
            client.DefaultRequestVersion = new Version(2, 0);
        }

        return client;
    }
}

// -----------------------------------------------------------------------------
// Report building / output
// -----------------------------------------------------------------------------

public sealed class HealthReport
{
    [JsonPropertyName("profile")]
    public string Profile { get; set; } = string.Empty;

    [JsonPropertyName("generatedAtUtc")]
    public DateTimeOffset GeneratedAtUtc { get; set; }

    [JsonPropertyName("registryVersion")]
    public int RegistryVersion { get; set; }

    [JsonPropertyName("summary")]
    public ReportSummary Summary { get; set; } = new();

    [JsonPropertyName("peers")]
    public List<PeerCheckResult> Peers { get; set; } = new();

    [JsonPropertyName("auth")]
    public List<DynamicAuthResult> AuthResults { get; set; } = new();
}

public sealed class ReportSummary
{
    [JsonPropertyName("total")]
    public int Total { get; set; }

    [JsonPropertyName("healthy")]
    public int Healthy { get; set; }

    [JsonPropertyName("failed")]
    public int FailedPeers { get; set; }

    [JsonPropertyName("failedCritical")]
    public int FailedCriticalPeers { get; set; }

    [JsonPropertyName("versionDrift")]
    public int VersionDrift { get; set; }

    [JsonPropertyName("authFailures")]
    public int AuthFailures { get; set; }
}

internal static class ReportBuilder
{
    public static HealthReport Build(PeerRegistry registry, string profile, List<PeerCheckResult> results, Options options, Dictionary<string, DynamicAuthResult>? dynamicAuthResults = null)
    {
        var authResultsList = dynamicAuthResults?.Values.ToList() ?? new List<DynamicAuthResult>();
        return new HealthReport
        {
            Profile = profile,
            GeneratedAtUtc = DateTimeOffset.UtcNow,
            RegistryVersion = registry.RegistryVersion,
            Summary = new ReportSummary
            {
                Total = results.Count,
                Healthy = results.Count(r => r.Status is "healthy" or "mocked"),
                FailedPeers = results.Count(r => r.Status == "down"),
                FailedCriticalPeers = results.Count(r => r.Status == "down" && r.Critical),
                VersionDrift = results.Count(r => r.VersionDrift == true),
                AuthFailures = authResultsList.Count(r => !r.Valid),
            },
            Peers = results,
            AuthResults = authResultsList,
        };
    }
}

internal static class ReportPrinter
{
    public static void Print(HealthReport report, bool verbose)
    {
        Console.WriteLine($"peers-health — profile: {report.Profile}  (registry v{report.RegistryVersion})");
        Console.WriteLine($"checked at {report.GeneratedAtUtc:u}");
        Console.WriteLine();
        foreach (var peer in report.Peers)
        {
            var marker = peer.Status switch
            {
                "healthy" => "OK  ",
                "mocked" => "MOCK",
                _ => "FAIL",
            };
            var latency = peer.LatencyMs is { } ms ? $" {ms}ms" : string.Empty;
            var criticalTag = peer.Critical ? " [critical]" : string.Empty;
            Console.WriteLine($"  {marker}  {peer.Peer}{criticalTag}{latency}");
            if (peer.Error is not null)
            {
                Console.WriteLine($"         {peer.Error}");
                Console.WriteLine("         run: peers-health --peer " + peer.Peer + " --verbose  for details");
            }

            if (verbose)
            {
                Console.WriteLine($"         endpoint: {peer.Endpoint}");
                if (peer.Version is not null)
                {
                    Console.WriteLine($"         version: {peer.Version} (min {peer.MinVersion})");
                }

                if (peer.VersionDrift == true)
                {
                    Console.WriteLine($"         WARNING: version below minVersion {peer.MinVersion} — peer needs UAT deploy");
                }
            }
        }

        Console.WriteLine();
        if (report.AuthResults.Count > 0)
        {
            Console.WriteLine("auth:");
            foreach (var auth in report.AuthResults)
            {
                if (auth.Valid)
                {
                    var ttl = auth.TokenTtlSecondsRemaining is { } s ? $"{s}s remaining" : "TTL unknown";
                    Console.WriteLine($"  OK    {auth.Peer} [dynamic] {ttl}");
                }
                else
                {
                    Console.WriteLine($"  FAIL  {auth.Peer} [dynamic] {auth.Error}");
                }
            }

            Console.WriteLine();
        }

        Console.WriteLine(
            $"summary: {report.Summary.Healthy}/{report.Summary.Total} healthy" +
            (report.Summary.FailedCriticalPeers > 0
                ? $", {report.Summary.FailedCriticalPeers} CRITICAL peer(s) DOWN"
                : string.Empty) +
            (report.Summary.VersionDrift > 0
                ? $", {report.Summary.VersionDrift} below minVersion"
                : string.Empty) +
            (report.Summary.AuthFailures > 0
                ? $", {report.Summary.AuthFailures} auth failure(s)"
                : string.Empty));
        if (report.Summary.FailedPeers > 0)
        {
            Console.WriteLine();
            Console.WriteLine("A required peer is down — local dev will FAIL FAST (BR-DEV-006, no fallback).");
            Console.WriteLine("Escalation: see infrastructure/oelite-stack/UAT-AVAILABILITY-RUNBOOK.md");
        }
    }
}

// -----------------------------------------------------------------------------
// Exceptions + JSON source-gen context
// -----------------------------------------------------------------------------

public sealed class PeersHealthException : Exception
{
    public PeersHealthException(string message)
        : base(message)
    {
    }
}

[JsonSerializable(typeof(HealthReport))]
[JsonSerializable(typeof(PeerCheckResult))]
[JsonSerializable(typeof(ReportSummary))]
[JsonSerializable(typeof(DynamicAuthResult))]
internal sealed partial class PeersJsonContext : JsonSerializerContext
{
}
