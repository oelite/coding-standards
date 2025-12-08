# Configuration Management Standards

## Overview

The OElite platform implements a standardized **configs-only architecture** using `BaseAppConfig` inheritance, `OElitePathResolver` integration, and environment-specific configuration patterns. This document establishes the mandatory configuration management standards that replace traditional appsettings.json patterns and ensure consistent, environment-aware application configuration across all OElite applications.

## Configs-Only Architecture (NEW STANDARD)

### 1. **Directory Structure** (Mandatory)
All OElite applications MUST follow the configs-only directory structure:

```
Application/
├── configs/                           # Configuration root (NEW STANDARD)
│   ├── appsettings.init.json         # Base configuration (REQUIRED)
│   └── .dev/                         # Environment-specific overrides
│       ├── Development/
│       │   └── appsettings.init.json # Development overrides
│       ├── Production/
│       │   └── appsettings.init.json # Production overrides
│       └── Staging/
│           └── appsettings.init.json # Staging overrides
├── data/                             # Application data (GeoIP, databases)
├── logs/                             # Application logs
├── cache/                            # Temporary cache files
├── uploads/                          # User uploaded files
├── certificates/                     # SSL/TLS certificates
├── backup/                           # Backup files
└── Program.cs                        # Configuration loading
```

### 2. **Configuration Loading Pattern** (Mandatory)
All applications MUST use the configs-only configuration loading pattern in `Program.cs`:

```csharp
// ✅ REQUIRED configs-only configuration loading
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // ✅ NEW STANDARD - Configs-only approach
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
        builder.Configuration
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("configs/appsettings.init.json", optional: false)  // Base (REQUIRED)
            .AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true)  // Environment override
            .AddEnvironmentVariables();  // Final override

        // Register strongly-typed configuration
        var appConfig = new YourAppConfig();
        builder.Configuration.Bind(appConfig);
        builder.Services.AddSingleton(appConfig);

        // Register OElite path resolver
        builder.Services.AddOElitePathResolver("your-app-name");

        var app = builder.Build();

        // Ensure all directories exist
        app.Services.EnsureOEliteDirectories();

        // Log path diagnostics for troubleshooting
        app.Services.LogOElitePathDiagnostics();

        app.Run();
    }
}

// ❌ DEPRECATED - Do NOT use traditional pattern
builder.Configuration
    .AddJsonFile("appsettings.json", optional: true)  // DEPRECATED
    .AddJsonFile($"appsettings.{environment}.json", optional: true)  // DEPRECATED
    .AddEnvironmentVariables();
```

### 3. **Configuration Priority Order**
The configuration system follows a strict priority order:

1. **Base Configuration**: `configs/appsettings.init.json` (required, lowest priority)
2. **Environment Override**: `configs/.dev/{environment}/appsettings.init.json` (optional, medium priority)
3. **Environment Variables**: Highest priority (production secrets, runtime overrides)

```json
// ✅ configs/appsettings.init.json (Base Configuration)
{
  "oelite": {
    "application": {
      "name": "kortex",
      "version": "1.0.0",
      "environment": "Production"
    },
    "data": {
      "mongodb": {
        "kortex": "mongodb://localhost:27017/kortex"
      },
      "redis": {
        "kortex": "localhost:6379"
      }
    }
  },
  "logging": {
    "logLevel": {
      "default": "Information"
    }
  }
}

// ✅ configs/.dev/Development/appsettings.init.json (Environment Override)
{
  "oelite": {
    "data": {
      "mongodb": {
        "kortex": "mongodb://dev-user:dev-pass@localhost:27017/kortex-dev"
      }
    }
  },
  "logging": {
    "logLevel": {
      "default": "Debug",
      "microsoft": "Warning"
    }
  }
}
```

## BaseAppConfig and Inheritance

### 1. **BaseAppConfig Pattern** (Mandatory)
All application configuration classes MUST inherit from `BaseAppConfig` for standardized path resolution:

```csharp
// ✅ REQUIRED inheritance pattern
public class KortexAppConfig : BaseAppConfig
{
    public KortexAppConfig(OElitePathResolver? pathResolver = null) : base(pathResolver)
    {
    }

    // Strongly-typed configuration sections
    public DnsConfiguration Dns { get; set; } = new();
    public ProxyConfiguration Proxy { get; set; } = new();
    public SecurityConfiguration Security { get; set; } = new();
    public CertificatesConfiguration Certificates { get; set; } = new();
    public GeoLocationConfiguration GeoLocation { get; set; } = new();
    public MonitoringConfiguration Monitoring { get; set; } = new();
    public PerformanceConfiguration Performance { get; set; } = new();

    // Path resolution integration (using base class)
    public string ResolvedGeoLocationDatabasePath => GetResolvedPath(OElitePathType.Data, "GeoLite2-City.mmdb");
    public string ResolvedCdnCachePath => GetResolvedPath(OElitePathType.Cache, "cdn");
    public string ResolvedLogPath => GetResolvedPath(OElitePathType.Logs, "kortex.log");
    public string ResolvedCertificatePath => GetResolvedPath(OElitePathType.Certificates, "ssl");

    // Environment-aware configuration properties
    public bool IsDevelopment => Environment?.Equals("Development", StringComparison.OrdinalIgnoreCase) == true;
    public bool IsProduction => Environment?.Equals("Production", StringComparison.OrdinalIgnoreCase) == true;
    public bool IsStaging => Environment?.Equals("Staging", StringComparison.OrdinalIgnoreCase) == true;
}

// ❌ WRONG - Not inheriting from BaseAppConfig
public class KortexAppConfig
{
    // Missing path resolution capabilities, inconsistent patterns
    public string DatabasePath { get; set; } = "/var/lib/geoip/GeoLite2-City.mmdb";  // Hard-coded path
}
```

### 2. **Configuration Section Classes**
Create strongly-typed classes for each configuration section:

```csharp
// ✅ Well-structured configuration classes
public class DnsConfiguration
{
    [Required]
    public List<int> ListenPorts { get; set; } = new() { 53 };

    [Range(1, int.MaxValue)]
    public int DefaultTtl { get; set; } = 3600;

    public bool EnableDnsSec { get; set; } = false;

    [Range(1, int.MaxValue)]
    public int MaxConcurrentQueries { get; set; } = 10000;

    // Validation method
    public void Validate()
    {
        if (!ListenPorts.Any())
            throw new ConfigurationException("At least one listen port must be specified");

        if (ListenPorts.Any(p => p < 1 || p > 65535))
            throw new ConfigurationException("Listen ports must be between 1 and 65535");
    }
}

public class SecurityConfiguration
{
    public bool EnableDdosProtection { get; set; } = true;

    [Range(1, int.MaxValue)]
    public int DefaultRateLimit { get; set; } = 1000;

    [Range(1, int.MaxValue)]
    public int BlockDurationMinutes { get; set; } = 5;

    public bool EnableWaf { get; set; } = true;
    public bool EnableGeoBlocking { get; set; } = true;

    public RateLimitConfiguration RateLimit { get; set; } = new();
    public DdosProtectionConfiguration DdosProtection { get; set; } = new();
}

public class RateLimitConfiguration
{
    [Range(1, int.MaxValue)]
    public int RequestsPerMinute { get; set; } = 1000;

    [Range(1, int.MaxValue)]
    public int BurstAllowance { get; set; } = 2000;

    public bool AdaptiveRateLimiting { get; set; } = true;

    [Range(1, int.MaxValue)]
    public int DomainRequestsPerMinute { get; set; } = 5000;

    [Range(1, int.MaxValue)]
    public int DomainBurstCapacity { get; set; } = 10000;
}
```

## OElitePathResolver Integration

### 1. **Path Resolution in Configuration**
Use `BaseAppConfig.GetResolvedPath()` for all file and directory paths:

```csharp
// ✅ Correct path resolution usage
public class ApplicationConfig : BaseAppConfig
{
    public ApplicationConfig(OElitePathResolver? pathResolver = null) : base(pathResolver)
    {
    }

    // Database and data files
    public string DatabasePath => GetResolvedPath(OElitePathType.Data, "application.db");
    public string GeoIpDatabasePath => GetResolvedPath(OElitePathType.Data, "GeoLite2-City.mmdb");
    public string BackupPath => GetResolvedPath(OElitePathType.Backup, "daily");

    // Cache and temporary files
    public string CacheDirectory => GetResolvedPath(OElitePathType.Cache);
    public string TempDirectory => GetResolvedPath(OElitePathType.Temp);
    public string SessionCachePath => GetResolvedPath(OElitePathType.Cache, "sessions");

    // Logs and monitoring
    public string LogDirectory => GetResolvedPath(OElitePathType.Logs);
    public string ApplicationLogPath => GetResolvedPath(OElitePathType.Logs, "application.log");
    public string ErrorLogPath => GetResolvedPath(OElitePathType.Logs, "errors.log");

    // SSL and certificates
    public string CertificateDirectory => GetResolvedPath(OElitePathType.Certificates);
    public string SslCertificatePath => GetResolvedPath(OElitePathType.Certificates, "ssl.crt");
    public string SslKeyPath => GetResolvedPath(OElitePathType.Certificates, "ssl.key");

    // Uploads and user content
    public string UploadDirectory => GetResolvedPath(OElitePathType.Uploads);
    public string UserUploadPath => GetResolvedPath(OElitePathType.Uploads, "users");
    public string ProductImagePath => GetResolvedPath(OElitePathType.Uploads, "products");
}

// ❌ WRONG - Hard-coded paths in configuration
public class ApplicationConfig
{
    public string DatabasePath { get; set; } = "/var/oelite/app/data/database.db";        // Hard-coded (DEPRECATED)
    public string LogPath { get; set; } = "/var/oelite/app/logs/application.log";        // Hard-coded (DEPRECATED)
    public string CachePath { get; set; } = "/var/oelite/app/cache";                    // Hard-coded (DEPRECATED)
}
```

### 2. **Directory Initialization**
Ensure directories exist during application startup:

```csharp
// ✅ Proper directory initialization
public static class ConfigurationExtensions
{
    public static void EnsureApplicationDirectories(this IServiceProvider serviceProvider)
    {
        var config = serviceProvider.GetRequiredService<ApplicationConfig>();

        // Ensure critical directories exist
        config.EnsureDirectory(OElitePathType.Data);
        config.EnsureDirectory(OElitePathType.Logs);
        config.EnsureDirectory(OElitePathType.Cache);
        config.EnsureDirectory(OElitePathType.Uploads);
        config.EnsureDirectory(OElitePathType.Certificates);
        config.EnsureDirectory(OElitePathType.Backup);

        // Ensure specific subdirectories
        config.EnsureDirectory(OElitePathType.Cache, "sessions");
        config.EnsureDirectory(OElitePathType.Uploads, "users");
        config.EnsureDirectory(OElitePathType.Uploads, "products");
    }

    public static void ValidateConfiguration(this ApplicationConfig config)
    {
        // Validate path accessibility
        if (!config.DirectoryExists(OElitePathType.Data))
            throw new ConfigurationException("Data directory is not accessible");

        if (!config.DirectoryExists(OElitePathType.Logs))
            throw new ConfigurationException("Logs directory is not accessible");

        // Validate specific files
        if (!config.FileExists(OElitePathType.Data, "GeoLite2-City.mmdb"))
            throw new ConfigurationException("GeoIP database file not found");
    }
}
```

## Environment-Specific Configuration Patterns

### 1. **Development Environment Configuration**
Development configurations should prioritize debugging and local development:

```json
// ✅ configs/.dev/Development/appsettings.init.json
{
  "oelite": {
    "data": {
      "mongodb": {
        "kortex": "mongodb://dev-user:dev-pass@localhost:27017/kortex-dev?authSource=admin"
      },
      "redis": {
        "kortex": "localhost:6379,password=dev-password,abortConnect=False"
      }
    }
  },
  "kortex": {
    "security": {
      "enableDdosProtection": false,
      "defaultRateLimit": 10000,
      "rateLimit": {
        "requestsPerMinute": 10000,
        "adaptiveRateLimiting": false
      }
    },
    "monitoring": {
      "enableDetailedLogging": true,
      "enableMetrics": true
    },
    "performance": {
      "memoryWarningThresholdMB": 256,
      "memoryCriticalThresholdMB": 512,
      "enablePerformanceLogging": true,
      "logIntervalMinutes": 1
    },
    "certificates": {
      "letsEncryptServer": "https://acme-staging-v02.api.letsencrypt.org/directory",
      "email": "admin@localhost"
    }
  },
  "logging": {
    "logLevel": {
      "default": "Debug",
      "microsoft": "Warning",
      "oelite": "Debug"
    }
  }
}
```

### 2. **Production Environment Configuration**
Production configurations should prioritize security, performance, and monitoring:

```json
// ✅ configs/.dev/Production/appsettings.init.json
{
  "oelite": {
    "data": {
      "mongodb": {
        "kortex": "mongodb://REPLACE_MONGO_USER:REPLACE_MONGO_PASSWORD@REPLACE_MONGO_HOST:27017/kortex?authSource=admin"
      },
      "redis": {
        "kortex": "REPLACE_REDIS_HOST:6379,password=REPLACE_REDIS_PASSWORD,abortConnect=False"
      }
    }
  },
  "kortex": {
    "security": {
      "enableDdosProtection": true,
      "defaultRateLimit": 1000,
      "rateLimit": {
        "requestsPerMinute": 1000,
        "burstAllowance": 2000,
        "adaptiveRateLimiting": true
      },
      "ddosProtection": {
        "detectionThreshold": 2000,
        "blockDurationMinutes": 60,
        "emergencyMode": {
          "enabled": true,
          "triggerThreshold": 10000,
          "blockDurationHours": 24
        }
      }
    },
    "monitoring": {
      "enableDetailedLogging": false,
      "enableMetrics": true,
      "metricsRetentionDays": 30
    },
    "performance": {
      "memoryWarningThresholdMB": 1024,
      "memoryCriticalThresholdMB": 2048,
      "enablePerformanceLogging": true,
      "logIntervalMinutes": 10
    },
    "certificates": {
      "letsEncryptServer": "https://acme-v02.api.letsencrypt.org/directory",
      "email": "REPLACE_ADMIN_EMAIL"
    },
    "authentication": {
      "jwtSecret": "REPLACE_KORTEX_JWT_SECRET_MIN_32_CHARS_LONG",
      "accessTokenExpirationMinutes": 60,
      "refreshTokenExpirationDays": 30
    }
  },
  "logging": {
    "logLevel": {
      "default": "Information",
      "microsoftAspNetCore": "Warning",
      "oeliteServersKortex": "Information"
    }
  }
}
```

### 3. **Environment Variable Overrides**
Support runtime configuration through environment variables:

```bash
# ✅ Production environment variable examples
export ASPNETCORE_ENVIRONMENT=Production
export OELITE__DATA__MONGODB__KORTEX="mongodb://prod-user:prod-pass@mongo.prod.com:27017/kortex?authSource=admin"
export OELITE__DATA__REDIS__KORTEX="redis.prod.com:6379,password=prod-redis-pass,abortConnect=False"
export KORTEX__AUTHENTICATION__JWTSECRET="super-secure-production-jwt-secret-key-32-chars-minimum"
export KORTEX__CERTIFICATES__EMAIL="admin@production.com"
```

## Configuration Validation and Error Handling

### 1. **Configuration Validation**
Implement comprehensive validation for all configuration sections:

```csharp
// ✅ Configuration validation implementation
public class ConfigurationValidator
{
    public static void ValidateConfiguration(ApplicationConfig config)
    {
        var errors = new List<string>();

        // Validate DNS configuration
        if (config.Dns.ListenPorts?.Any() != true)
            errors.Add("DNS listen ports must be specified");

        if (config.Dns.ListenPorts?.Any(p => p < 1 || p > 65535) == true)
            errors.Add("DNS listen ports must be between 1 and 65535");

        // Validate security configuration
        if (config.Security.DefaultRateLimit <= 0)
            errors.Add("Default rate limit must be greater than 0");

        if (config.Security.BlockDurationMinutes <= 0)
            errors.Add("Block duration must be greater than 0");

        // Validate database connections
        if (string.IsNullOrWhiteSpace(config.ConnectionStrings?.Kortex))
            errors.Add("Kortex database connection string is required");

        // Validate authentication
        if (config.IsProduction && string.IsNullOrWhiteSpace(config.Authentication?.JwtSecret))
            errors.Add("JWT secret is required in production");

        if (config.Authentication?.JwtSecret?.Length < 32)
            errors.Add("JWT secret must be at least 32 characters long");

        // Validate certificates
        if (config.IsProduction && string.IsNullOrWhiteSpace(config.Certificates?.Email))
            errors.Add("Certificate email is required in production");

        // Validate path accessibility
        try
        {
            config.EnsureDirectory(OElitePathType.Data);
            config.EnsureDirectory(OElitePathType.Logs);
        }
        catch (Exception ex)
        {
            errors.Add($"Path validation failed: {ex.Message}");
        }

        if (errors.Any())
        {
            throw new ConfigurationException($"Configuration validation failed:\n{string.Join("\n", errors)}");
        }
    }
}

// ✅ Use validation during startup
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Load configuration
        var appConfig = new ApplicationConfig();
        builder.Configuration.Bind(appConfig);

        // Validate configuration
        try
        {
            ConfigurationValidator.ValidateConfiguration(appConfig);
        }
        catch (ConfigurationException ex)
        {
            Console.WriteLine($"Configuration Error: {ex.Message}");
            Environment.Exit(1);
        }

        builder.Services.AddSingleton(appConfig);

        var app = builder.Build();
        app.Run();
    }
}
```

### 2. **Kortex Proxy-Based Architecture - Configuration Service**
The OElite platform now uses a unified proxy-based architecture where Kortex services are identified by `ListenIp = "kortex"` in ProxyConfiguration. This eliminates separate domain services and leverages existing proxy infrastructure:

```csharp
// ✅ New Kortex proxy-based configuration pattern
public class KortexProxyConfiguration
{
    // Kortex services are identified by ListenIp = "kortex"
    public static bool IsKortexInternalService(ProxyConfiguration config)
    {
        return config.ListenIp?.Equals("kortex", StringComparison.OrdinalIgnoreCase) == true;
    }

    // Service types determined by domain patterns (no database lookups)
    public static KortexServiceType GetServiceType(string domain)
    {
        return domain.ToLowerInvariant() switch
        {
            var d when d.Contains("management") || d.Contains("api") => KortexServiceType.Management,
            var d when d.Contains("storage") || d.Contains("s3") => KortexServiceType.EdgeQ1Storage,
            var d when d.Contains("cdn") || d.Contains("static") => KortexServiceType.Cdn,
            _ => KortexServiceType.Management
        };
    }

    // Network architecture: HTTPS proxy → HTTP internal services
    public static int GetInternalPort(KortexServiceType serviceType)
    {
        return serviceType switch
        {
            KortexServiceType.Management => 8080,
            KortexServiceType.EdgeQ1Storage => 8082,
            KortexServiceType.Cdn => 8081,
            _ => 8080
        };
    }
}
```

### 3. **KortexConfigurationService - Runtime Configuration Fetching**
The OElite platform uses `KortexConfigurationService` to fetch configuration from Kortex server and merge it with local configuration at runtime:

```csharp
// ✅ KortexConfigurationService usage in Program.cs
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Standard configs-only configuration loading
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
        builder.Configuration
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("configs/appsettings.init.json", optional: false)
            .AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true)
            .AddEnvironmentVariables();

        // Register strongly-typed configuration
        var appConfig = new YourAppConfig();
        builder.Configuration.Bind(appConfig);
        builder.Services.AddSingleton(appConfig);

        // ✅ Add KortexConfigurationService for runtime configuration fetching
        builder.Services.AddKortexConfiguration(options =>
        {
            options.RefreshIntervalSeconds = 300; // 5 minutes
            options.MaxRetryAttempts = 3;
            options.RequestTimeoutSeconds = 30;
            options.EnableDevelopmentMode = true;
        });

        var app = builder.Build();

        // ✅ Access merged configuration from KortexConfigurationService
        var kortexConfigService = app.Services.GetKortexConfigurationService();
        var mergedConfig = kortexConfigService?.GetConfiguration() ?? builder.Configuration;

        app.Run();
    }
}

// ✅ Using KortexConfigurationService in services
public class YourService
{
    private readonly KortexConfigurationService _kortexConfigService;
    private readonly ILogger<YourService> _logger;

    public YourService(KortexConfigurationService kortexConfigService, ILogger<YourService> logger)
    {
        _kortexConfigService = kortexConfigService;
        _logger = logger;
    }

    public void DoSomethingWithConfiguration()
    {
        // Get the merged configuration (local + Kortex)
        var configuration = _kortexConfigService.GetConfiguration();

        // Check if Kortex configuration was successfully loaded
        if (_kortexConfigService.IsConfigurationLoaded)
        {
            _logger.LogInformation("Using merged configuration from Kortex");
            var value = configuration["oelite:feature:enabled"];
        }
        else
        {
            _logger.LogWarning("Using local configuration only (Kortex unavailable)");
        }

        // Get service status for health checks
        var status = _kortexConfigService.GetStatus();
        _logger.LogDebug("Configuration service status: IsHealthy={IsHealthy}, ConsecutiveFailures={ConsecutiveFailures}",
            status.IsHealthy, status.ConsecutiveFailures);
    }
}

// ✅ Configuration for KortexConfigurationService
// In configs/appsettings.init.json
{
  "kortex": {
    "bootstrap": {
      "enabled": "true",
      "endpoint": "kortex.example.com",
      "clientId": "your-application-id",
      "clientSecret": "your-client-secret"
    }
  },
  "oelite": {
    "application": {
      "neuronId": "your-app-neuron-id"
    },
    "platform": {
      "kortexServer": "kortex.example.com"
    }
  }
}
```

### 3. **KortexConfigurationService Features**
The service provides enterprise-grade configuration management:

```csharp
// ✅ Key features of KortexConfigurationService

// 1. Resilient Configuration Fetching
// - Automatic retry with exponential backoff
// - Graceful failure handling (continues with local config)
// - Configurable timeouts and retry attempts

// 2. Background Refresh
// - Periodic configuration refresh (default: 5 minutes)
// - Non-blocking operation (doesn't interrupt application)
// - Health monitoring and status reporting

// 3. Environment Awareness
// - Automatically detects environment (Development/Production)
// - Can be disabled in development when Kortex is unavailable
// - Supports localhost development scenarios

// 4. Configuration Merging
// - Merges Kortex configuration with local configuration
// - Local configuration serves as fallback
// - Maintains configuration hierarchy (Kortex overrides local)

// 5. Health Monitoring
public class ConfigurationHealthCheck : IHealthCheck
{
    private readonly KortexConfigurationService _kortexConfigService;

    public ConfigurationHealthCheck(KortexConfigurationService kortexConfigService)
    {
        _kortexConfigService = kortexConfigService;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var status = _kortexConfigService.GetStatus();

        if (status.IsHealthy)
        {
            return Task.FromResult(HealthCheckResult.Healthy(
                $"Configuration loaded successfully. Last fetch: {status.LastSuccessfulFetch}"));
        }

        return Task.FromResult(HealthCheckResult.Degraded(
            $"Configuration service degraded. Consecutive failures: {status.ConsecutiveFailures}"));
    }
}
```

## Kortex Configuration Integration Patterns

### 1. **Neuron-Based Configuration Fetching**
KortexConfigurationService uses neuron-based configuration fetching:

```csharp
// ✅ Neuron configuration pattern
public class NeuronConfigurationPattern
{
    // Configuration is fetched based on:
    // - NEURON_ID environment variable or oelite:application:neuronId
    // - ASPNETCORE_ENVIRONMENT for environment-specific configs
    // - Client credentials for authentication

    // Example configuration request:
    // {
    //   "neuronId": "kortex-api-prod",
    //   "environment": "Production",
    //   "clientId": "kortex-client",
    //   "clientSecret": "secure-secret",
    //   "requestedSections": ["oelite"]
    // }
}
```

### 2. **Configuration Override Hierarchy**
Understand the complete configuration hierarchy with Kortex integration:

```text
1. configs/appsettings.init.json (Base - Lowest Priority)
2. configs/.dev/{environment}/appsettings.init.json (Environment Override)
3. Kortex Server Configuration (Fetched at Runtime)
4. Environment Variables (Highest Priority)

Example:
- Local config has "oelite:feature:enabled": false
- Kortex config has "oelite:feature:enabled": true
- Final result: true (Kortex overrides local)

- Kortex config has "oelite:database:connection": "kortex-value"
- Environment variable OELITE__DATABASE__CONNECTION="env-value"
- Final result: "env-value" (Environment variables override everything)
```

### 3. **Development vs Production Behavior**
KortexConfigurationService adapts to different environments:

```csharp
// ✅ Environment-aware configuration behavior

// Development Environment:
// - Can be disabled if Kortex server is not available
// - Gracefully falls back to local configuration
// - Supports localhost Kortex instances
// - Controlled by EnableDevelopmentMode option

// Production Environment:
// - Always attempts to fetch from Kortex
// - Logs failures but continues with local config
// - Monitors consecutive failures for health checks
// - Critical for centralized configuration management

// Configuration example:
{
  "kortex": {
    "bootstrap": {
      "enabled": "true",  // Set to "false" to disable Kortex fetching
      "endpoint": "prod-kortex.company.com",
      "clientId": "api-client-prod",
      "clientSecret": "REPLACE_WITH_ACTUAL_SECRET"
    }
  }
}
```

## Secrets Management

### 1. **Production Secrets Handling**
Never commit secrets to configuration files; use environment variables or secret management:

```json
// ✅ Production configuration with placeholders
{
  "oelite": {
    "data": {
      "mongodb": {
        "kortex": "REPLACE_MONGO_CONNECTION_STRING"
      },
      "redis": {
        "kortex": "REPLACE_REDIS_CONNECTION_STRING"
      }
    },
    "storage": {
      "s3": {
        "kortex": "AccessKeyId=REPLACE_S3_ACCESS_KEY;SecretAccessKey=REPLACE_S3_SECRET_KEY;ServiceUrl=REPLACE_S3_ENDPOINT"
      }
    }
  },
  "kortex": {
    "authentication": {
      "jwtSecret": "REPLACE_KORTEX_JWT_SECRET_MIN_32_CHARS_LONG"
    },
    "certificates": {
      "email": "REPLACE_ADMIN_EMAIL"
    }
  }
}
```

### 2. **Secret Injection During Deployment**
Use deployment scripts to inject secrets:

```bash
# ✅ Production deployment script
#!/bin/bash

# Replace configuration placeholders with actual secrets
sed -i "s/REPLACE_MONGO_CONNECTION_STRING/${MONGO_CONNECTION_STRING}/g" configs/.dev/Production/appsettings.init.json
sed -i "s/REPLACE_REDIS_CONNECTION_STRING/${REDIS_CONNECTION_STRING}/g" configs/.dev/Production/appsettings.init.json
sed -i "s/REPLACE_KORTEX_JWT_SECRET_MIN_32_CHARS_LONG/${JWT_SECRET}/g" configs/.dev/Production/appsettings.init.json
sed -i "s/REPLACE_ADMIN_EMAIL/${ADMIN_EMAIL}/g" configs/.dev/Production/appsettings.init.json

# Set environment variables
export ASPNETCORE_ENVIRONMENT=Production
export ASPNETCORE_URLS="http://+:5000;https://+:5001"
```

## Migration from Legacy Configuration

### 1. **Migration Steps**
For applications transitioning from traditional appsettings.json:

```bash
# Step 1: Create configs directory structure
mkdir -p configs/.dev/{Development,Production,Staging}

# Step 2: Move and rename existing files
mv appsettings.json configs/appsettings.init.json
mv appsettings.Development.json configs/.dev/Development/appsettings.init.json
mv appsettings.Production.json configs/.dev/Production/appsettings.init.json

# Step 3: Update Program.cs to use configs-only pattern

# Step 4: Update configuration classes to inherit from BaseAppConfig

# Step 5: Remove obsolete root configuration files
rm appsettings*.json  # Keep templates if needed

# Step 6: Update Docker and deployment scripts
```

### 2. **Backward Compatibility**
Provide temporary backward compatibility during migration:

```csharp
// ✅ Migration compatibility helper
public static class ConfigurationMigrationHelper
{
    public static void AddLegacyConfigurationSupport(this ConfigurationBuilder builder, string environment)
    {
        // First try new configs-only pattern
        builder.AddJsonFile("configs/appsettings.init.json", optional: true);
        builder.AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true);

        // Fallback to legacy pattern for backward compatibility
        builder.AddJsonFile("appsettings.json", optional: true);
        builder.AddJsonFile($"appsettings.{environment}.json", optional: true);

        builder.AddEnvironmentVariables();
    }
}
```

## Compliance Checklist

### Configuration Structure Requirements
- [ ] Uses configs-only directory structure
- [ ] Base configuration in `configs/appsettings.init.json`
- [ ] Environment overrides in `configs/.dev/{environment}/appsettings.init.json`
- [ ] No root `appsettings*.json` files (except templates)
- [ ] Configuration classes inherit from `BaseAppConfig`
- [ ] Path resolution uses `OElitePathResolver` integration
- [ ] Directory initialization during startup

### Configuration Standards
- [ ] Strongly-typed configuration classes for all sections
- [ ] Comprehensive validation for all configuration values
- [ ] Environment-specific configurations are properly isolated
- [ ] Secrets are not committed to configuration files
- [ ] Production configurations use placeholder tokens
- [ ] Environment variables override file configurations

### Quality and Security
- [ ] Configuration validation runs at startup
- [ ] Invalid configurations prevent application startup
- [ ] Configuration changes are monitored and validated
- [ ] Secrets management follows security best practices
- [ ] Path resolution is environment-aware
- [ ] Error handling includes configuration diagnostics

### Migration and Compatibility
- [ ] Legacy configuration files have been removed
- [ ] Docker and deployment scripts updated for new structure
- [ ] Documentation updated to reflect new patterns
- [ ] Team training completed on new configuration standards
- [ ] Automated deployment scripts inject production secrets
- [ ] Configuration templates are maintained for new environments

This configuration management system ensures consistent, secure, and maintainable application configuration across all OElite applications while providing excellent developer experience and robust production deployment capabilities.