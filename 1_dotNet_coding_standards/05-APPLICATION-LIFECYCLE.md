# OElite Application Lifecycle Standards

## Overview

This document defines the **mandatory** standardized application lifecycle for all OElite applications. All new applications MUST use the phase-based lifecycle architecture (`OeWebApp`, `OeHybridApp`, `OeConsoleApp`). Legacy patterns are deprecated and must not be used.

## Major Updates (December 2024)

### Phase-Based Lifecycle Architecture
- **OeWebApp**: Web applications with ASP.NET Core
- **OeHybridApp**: Background services + Web API (e.g., Kortex, Obelisk)
- **OeConsoleApp**: Console applications and background workers
- **OeAppPipelineBuilder**: Ordered middleware/lifecycle hook configuration
- **WebLifecycleOptions**: Unified configuration for web applications
- **Complete Lifecycle Management**: Automatic bootstrap, graceful shutdown, cancellation coordination

### Breaking Changes
- **DEPRECATED**: `OeApp.RunWebAppAsync()`, `OeApp.RunConsoleAppAsync()`, `OeApp.RunHybridAppAsync()`
- **REQUIRED**: `OeWebApp.RunAsync()`, `OeHybridApp.RunAsync()`, `OeConsoleApp.RunAsync()`
- **REMOVED**: `UnifiedPipelineBuilder` → **USE**: `OeAppPipelineBuilder`
- **REMOVED**: `configurePipeline` parameter → **USE**: `options.ConfigurePipeline`

## Hosting Package Architecture

### OElite.Common.Hosting (Base Package)
**Purpose**: Core lifecycle components for all application types
- **Components**: `OeApp`, `OeConsoleApp`, lifecycle phases, lifecycle options
- **Dependencies**: Microsoft.Extensions.* (Configuration, Hosting, Logging, DI)
- **Use Cases**: Console applications, background workers, CLI tools

### OElite.Common.Hosting.AspNetCore (Web Package)
**Purpose**: ASP.NET Core specific hosting for web applications
- **Components**: `OeWebApp`, `OeHybridApp`, `OeAppPipelineBuilder`, middleware orchestration
- **Dependencies**: ASP.NET Core, Swagger, API Versioning, FluentValidation
- **Use Cases**: Web APIs, hybrid applications (background + web)

## Application Types and Selection

### When to Use OeWebApp
**Use Case**: Pure web applications with controllers and APIs

**Characteristics**:
- HTTP endpoints (REST APIs, GraphQL, etc.)
- Swagger/OpenAPI documentation
- JWT authentication and authorization
- API versioning
- No long-running background services

**Examples**: Nexus (platform API), Tesseract (storage API), Hephaestus (MCP server), OeSterling.Api (blockchain API), Orion.Api (workflow API), Origin.Api (auth API)

### When to Use OeHybridApp
**Use Case**: Applications requiring BOTH background services AND web APIs

**Characteristics**:
- Background services that run continuously (e.g., `IHostedService`)
- Management/monitoring API endpoints
- Coordinated shutdown of services and web host
- Shared service container

**Examples**: Kortex (proxy + management API), Obelisk (mail protocols + management API), OeSterling.Node (blockchain sync + node API)

### When to Use OeConsoleApp
**Use Case**: Console applications without web hosting

**Characteristics**:
- Background workers
- CLI tools with command-line arguments
- Batch processors
- Data migration tools

**Examples**: Chromia (PDF generation), Orion.Worker.Console (job processor), OElite.Migration.CollectionMerger (data migration), OeSterling.MiningClient (mining CLI)

## Standard Application Patterns

### Pattern 1: Web Application (OeWebApp)

**REQUIRED Pattern**:
```csharp
using OElite.Common.Hosting.AspNetCore;
using OElite.Common.Hosting.AspNetCore.Configuration;

await OeWebApp.RunAsync<MyAppConfig>(
    args,
    "My Application Name",
    configureServices: builder =>
    {
        // Register application-specific services
        builder.Services.AddValidatorsFromAssemblyContaining<Program>();
        
        // Add Swagger customization
        builder.Services.AddSwaggerGen(options =>
        {
            options.DocumentFilter<CustomTagsDocumentFilter>();
        });
        
        // Configure Kestrel
        builder.WebHost.UseKestrel(options =>
        {
            options.Listen(System.Net.IPAddress.Any, 5000);
        });
    },
    configureOptions: options =>
    {
        // Enable standard web features
        options.EnableSwagger = true;
        options.EnableAuthentication = true;
        options.EnableAuthorization = true;
        options.EnableApiVersioning = true;
        
        // ✅ CRITICAL: Configure middleware pipeline with proper ordering
        options.ConfigurePipeline = pipeline =>
        {
            // Before authentication: CORS, rate limiting
            pipeline.AddBeforeAuthentication(app =>
            {
                app.UseCors("MyPolicy");
                app.UseIpRateLimiting();
            });
            
            // After authentication: Permission enrichment, custom auth
            pipeline.AddAfterAuthentication(app =>
            {
                app.UsePermissionEnrichment();
                app.UseTenantIdentification();
            });
            
            // After authorization: SignalR hubs, health endpoints
            pipeline.AddAfterAuthorization(app =>
            {
                app.MapHub<NotificationHub>("/hubs/notifications");
                app.MapGet("/health", () => new { status = "healthy" });
            });
        };
        
        // Configure dependency injection auto-discovery
        options.DependencyInjectionOptions = di =>
        {
            di.IncludeAssemblyPrefixes.Add("MyApp");
            di.ExcludeAssemblyPrefixes.Add("Test");
        };
    });
```

### Pattern 2: Hybrid Application (OeHybridApp)

**REQUIRED Pattern**:
```csharp
using OElite.Common.Hosting.AspNetCore;
using OElite.Common.Hosting.AspNetCore.Configuration;

await OeHybridApp.RunAsync<MyAppConfig>(
    args,
    "My Hybrid Application",
    configureServices: builder =>
    {
        // Register background services (core functionality)
        builder.Services.AddHostedService<MyBackgroundService>();
        builder.Services.AddHostedService<AnotherHostedService>();
        
        // Register management API services
        builder.Services.AddHealthChecks();
    },
    configureOptions: options =>
    {
        // Enable web features for management API
        options.EnableSwagger = true;  // Or false for minimal APIs
        options.EnableAuthentication = true;
        options.EnableAuthorization = true;
        
        // Configure pipeline for management endpoints
        options.ConfigurePipeline = pipeline =>
        {
            // Management API endpoints
            pipeline.AddAfterAuthorization(app =>
            {
                app.MapHealthChecks("/health");
                app.MapMetrics();  // Prometheus metrics
            });
        };
    });
```

### Pattern 3: Console Application (OeConsoleApp)

**REQUIRED Pattern**:
```csharp
using OElite.Common.Hosting;
using OElite.Common.Hosting.Configuration;

await OeConsoleApp.RunAsync<MyAppConfig>(
    args,
    "My Console Application",
    configureServices: builder =>
    {
        // Register background services
        builder.Services.AddHostedService<WorkerService>();
        
        // Register application services
        builder.Services.AddSingleton<IMyService, MyService>();
    },
    configureOptions: options =>
    {
        // Console-specific configuration
        options.EnableConsoleLogging = true;
        options.MinimumLogLevel = LogLevel.Information;
    });
```

### Pattern 4: CLI Tools (Execute-and-Exit)

**REQUIRED Pattern** (for tools like CollectionMerger, MiningClient):
```csharp
using Microsoft.Extensions.Hosting;
using OElite.Common.Hosting.Extensions;

var builder = Host.CreateApplicationBuilder(args);

// Configure OElite application lifecycle
builder.ConfigureOeApp<MyAppConfig>();

// Register services
builder.Services.AddSingleton<IMigrationService, MigrationService>();

var host = builder.Build();

// Initialize OElite application
await host.InitOeApp<MyAppConfig>();

// Execute custom logic and exit
await ExecuteMyToolAndExitAsync(host, args);
```

## Pipeline Builder Standards (OeAppPipelineBuilder)

### Middleware Ordering Requirements

**CRITICAL**: Always use `options.ConfigurePipeline` for middleware that needs specific ordering relative to authentication/authorization.

### Available Injection Points

```csharp
options.ConfigurePipeline = pipeline =>
{
    // Stage 1: Before Authentication (600)
    pipeline.AddBeforeAuthentication(app =>
    {
        app.UseCors();                    // CORS must be before auth
        app.UseRateLimiting();            // Rate limiting early
        app.UseGlobalExceptionHandler();  // Exception handling
    });
    
    // Stage 2: After Authentication, Before Authorization (800)
    pipeline.AddAfterAuthentication(app =>
    {
        app.UsePermissionEnrichment();    // Add permissions after JWT validated
        app.UseTenantIdentification();    // Extract tenant from JWT claims
        app.UseCustomAuthentication();    // Custom auth logic
    });
    
    // Stage 3: After Authorization (1000)
    pipeline.AddAfterAuthorization(app =>
    {
        app.MapHub<MyHub>("/hubs/my");           // SignalR hubs
        app.MapHealthChecks("/health");          // Health checks
        app.MapMetrics();                        // Metrics endpoints
        app.MapGet("/custom", () => "OK");       // Custom endpoints
    });
};
```

### MiddlewarePipelineStage Reference

```csharp
public enum MiddlewarePipelineStage
{
    ExceptionHandling = 100,      // Global exception handling (auto-configured)
    Cors = 200,                   // CORS configuration (auto-configured if enabled)
    Routing = 300,                // Route matching (auto-configured)
    RateLimiting = 400,           // Rate limiting middleware
    Swagger = 500,                // Swagger middleware (auto-configured if enabled)
    BeforeAuthentication = 600,   // ⬅️ Your custom middleware here
    Authentication = 700,         // JWT authentication (auto-configured)
    AfterAuthentication = 800,    // ⬅️ Your custom middleware here
    Authorization = 900,          // Authorization (auto-configured)
    AfterAuthorization = 1000,    // ⬅️ Your custom endpoints/middleware here
    EndpointMapping = 1100        // MapControllers (auto-configured)
}
```

### Priority System

Use priority for fine-grained ordering within a stage:

```csharp
pipeline.AddAfterAuthentication(app =>
{
    app.UsePermissionEnrichment();
}, priority: 10);  // Runs first

pipeline.AddAfterAuthentication(app =>
{
    app.UseTenantIdentification();
}, priority: 20);  // Runs second
```

## WebLifecycleOptions Configuration

### Required Options for Web Applications

```csharp
options.EnableSwagger = true;           // Enable Swagger/OpenAPI (default: true)
options.EnableAuthentication = true;    // Enable JWT authentication (default: true)
options.EnableAuthorization = true;     // Enable authorization (default: true)
options.EnableApiVersioning = true;     // Enable API versioning (default: true)
options.EnableCors = false;             // Enable CORS (configure separately)
```

### Dependency Injection Auto-Discovery

```csharp
options.DependencyInjectionOptions = di =>
{
    // Include assemblies
    di.IncludeAssemblyPrefixes.Add("MyApp");
    di.IncludeAssemblyPrefixes.Add("MyApp.Services");
    
    // Exclude assemblies
    di.ExcludeAssemblyPrefixes.Add("Test");
    di.ExcludeAssemblyPrefixes.Add("Benchmark");
    
    // Exclude namespaces
    di.ExcludeNamespacePrefixes.Add("MyApp.Legacy");
    di.ExcludeNamespacePrefixes.Add("MyApp.Tests");
    
    // Custom type filters
    di.ServiceTypeFilter = type => !type.Name.Contains("Legacy");
    di.RepositoryTypeFilter = type => type.IsPublic;
};
```

### Auto-Discovery Process

**Automatically Registered Types**:
1. `IOEliteService` implementations → Singleton
2. `IDataRepository<>` implementations → Scoped (discovered via `DataRepository<>` base class)
3. `IHostedService` and `BackgroundService` → Singleton
4. `IOEliteOptions` implementations → Singleton configuration objects

**Assembly Discovery**:
- Automatically scans assemblies matching "OElite", "Origin", "Orion", plus application root namespace
- Uses hybrid assembly scanning (entry assembly + AppDomain assemblies) for reliability
- Works in all hosting scenarios: `dotnet watch`, unit tests, Docker, IIS, Azure

## Bootstrap Initialization

### Bootstrap Providers (Auto-Discovered)

```csharp
public class MyBootstrapProvider : IBootstrapProvider
{
    public int Priority => 100;  // Lower numbers run first
    
    public async Task BootstrapAsync(IServiceProvider services)
    {
        // Initialize default data, seed database, etc.
        var repository = services.GetRequiredService<IMyRepository>();
        await repository.EnsureDefaultDataAsync();
    }
}
```

**Requirements**:
- Implement `IBootstrapProvider`
- Assembly must match auto-discovery prefixes ("OElite", "Origin", "Orion", application root)
- Automatically discovered and executed during `InitOeApp<T>()`

### Bootstrap Execution

Bootstrap providers are automatically executed when:
- `OeWebApp.RunAsync()` is called
- `OeHybridApp.RunAsync()` is called
- `OeConsoleApp.RunAsync()` is called
- `host.InitOeApp<T>()` is called (manual pattern)

## Graceful Shutdown

All lifecycle types (`OeWebApp`, `OeHybridApp`, `OeConsoleApp`) provide graceful shutdown with:

- **10-second timeout**: Background services have 10 seconds to clean up
- **Application-wide cancellation**: `CancellationToken` propagated to all hosted services
- **Coordinated shutdown**: Web host and background services shut down together

### Using Cancellation Tokens

```csharp
public class MyBackgroundService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await DoWorkAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
        
        // Cleanup on shutdown
        await CleanupAsync();
    }
}
```

## Configuration Management

### Application Configuration (IAppConfig)

All applications must have a configuration class implementing `IAppConfig`:

```csharp
public class MyAppConfig : IAppConfig
{
    public string ApplicationName { get; set; } = "MyApplication";
    public DbObjectId ApplicationId { get; set; }
    public DbObjectId TenantId { get; set; }
    
    // Application-specific configuration
    public MyCustomSettings CustomSettings { get; set; }
}
```

### Configuration Loading Hierarchy

1. `configs/appsettings.init.json` - Base configuration (required)
2. `configs/.dev/{Environment}/appsettings.init.json` - Environment overrides (optional)
3. Environment variables - Runtime overrides

### Kortex Configuration Service Integration

For applications that fetch configuration from Kortex:

```csharp
configureServices: builder =>
{
    // Only for non-Kortex applications
    builder.Services.AddKortexConfigurationService(builder.Configuration);
}
```

**Note**: Kortex itself does NOT use this pattern (it IS the configuration provider).

## API Versioning Standards

### Controller Versioning

```csharp
[ApiController]
[ApiVersion("1.0")]
[Route("v{version:apiVersion}/[controller]")]
public class ProductsController : ControllerBase
{
    [HttpGet]
    [MapToApiVersion("1.0")]
    public async Task<IActionResult> GetProducts() { }
}
```

### Version Format

- **Controllers**: Use `[ApiVersion("1.0")]` (major.minor)
- **Routes**: Use `v{version:apiVersion}` parameter
- **URLs**: Generated as `/v1/products` (major version only)
- **Group Format**: `'v'VVV` produces "v1", "v2", "v3"

**Configuration**:
```csharp
public class ApiVersioningConfiguration
{
    public int DefaultMajorVersion { get; set; } = 1;
    public int DefaultMinorVersion { get; set; } = 0;
    public string GroupNameFormat { get; set; } = "'v'VVV";  // v1, v2, v3
}
```

## Migration Checklist

### Migrating from Legacy Lifecycle

- [ ] Remove `using OElite.Common.Hosting.AspNetCore.Extensions;`
- [ ] Add `using OElite.Common.Hosting.AspNetCore;`
- [ ] Add `using OElite.Common.Hosting.AspNetCore.Configuration;`
- [ ] Replace `OeApp.RunWebAppAsync<T>()` with `OeWebApp.RunAsync<T>()`
- [ ] Replace `OeApp.RunHybridAppAsync<T>()` with `OeHybridApp.RunAsync<T>()`
- [ ] Replace `OeApp.RunConsoleAppAsync<T>()` with `OeConsoleApp.RunAsync<T>()`
- [ ] Move `configurePipeline` parameter to `options.ConfigurePipeline`
- [ ] Update middleware registration to use `OeAppPipelineBuilder`
- [ ] Verify build and test application

### Example Migration

**BEFORE (Legacy - DO NOT USE)**:
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

await OeApp.RunWebAppAsync<MyAppConfig>(
    args,
    "My App",
    configureServices: builder => { },
    configureApp: async app =>
    {
        app.UsePermissionEnrichment();
        app.MapHub<MyHub>("/hubs/my");
    });
```

**AFTER (Correct - REQUIRED)**:
```csharp
using OElite.Common.Hosting.AspNetCore;
using OElite.Common.Hosting.AspNetCore.Configuration;

await OeWebApp.RunAsync<MyAppConfig>(
    args,
    "My App",
    configureServices: builder => { },
    configureOptions: options =>
    {
        options.EnableSwagger = true;
        options.EnableAuthentication = true;
        options.EnableAuthorization = true;
        
        options.ConfigurePipeline = pipeline =>
        {
            pipeline.AddAfterAuthentication(app =>
            {
                app.UsePermissionEnrichment();
            });
            
            pipeline.AddAfterAuthorization(app =>
            {
                app.MapHub<MyHub>("/hubs/my");
            });
        };
    });
```

## Common Patterns

### Pattern: Permission Enrichment After Authentication

```csharp
options.ConfigurePipeline = pipeline =>
{
    pipeline.AddAfterAuthentication(app =>
    {
        app.UsePermissionEnrichment();  // Must run after JWT validated
    });
};
```

### Pattern: Tenant Identification from JWT

```csharp
options.ConfigurePipeline = pipeline =>
{
    pipeline.AddAfterAuthentication(app =>
    {
        app.UseTenantIdentification();  // Extract tenant from JWT claims
    });
};
```

### Pattern: SignalR Hubs and Health Endpoints

```csharp
options.ConfigurePipeline = pipeline =>
{
    pipeline.AddAfterAuthorization(app =>
    {
        app.MapHub<NotificationHub>("/hubs/notifications");
        app.MapHub<ChatHub>("/hubs/chat");
        app.MapHealthChecks("/health");
        app.MapMetrics();
    });
};
```

### Pattern: CORS Before Authentication

```csharp
options.ConfigurePipeline = pipeline =>
{
    pipeline.AddBeforeAuthentication(app =>
    {
        app.UseCors("AllowDashboard");
    });
};
```

### Pattern: Rate Limiting Early

```csharp
options.ConfigurePipeline = pipeline =>
{
    pipeline.AddBeforeAuthentication(app =>
    {
        app.UseIpRateLimiting();
        app.UseGlobalExceptionHandler();
    });
};
```

## Enforcement

### Code Review Requirements

All new applications and PRs MUST:
1. Use `OeWebApp.RunAsync()`, `OeHybridApp.RunAsync()`, or `OeConsoleApp.RunAsync()`
2. Use `options.ConfigurePipeline` with `OeAppPipelineBuilder` for middleware ordering
3. NOT use deprecated `OeApp.RunXxxAsync()` methods
4. NOT use `configurePipeline` parameter (removed)
5. NOT reference `UnifiedPipelineBuilder` (renamed to `OeAppPipelineBuilder`)

### Build Requirements

All applications MUST:
- Build without errors using latest `OElite.Common.Hosting` and `OElite.Common.Hosting.AspNetCore` packages
- Include proper using statements
- Follow the patterns documented in this standard

## Reference Implementations

### Production Examples

- **OElite.Servers.Nexus** - Web API with permission enrichment
- **OElite.Servers.Kortex** - Hybrid app (proxy + management API)
- **OElite.Servers.Obelisk** - Hybrid app (mail server + management API)
- **OElite.OeSterling.Api** - Blockchain web API
- **OElite.OeSterling.Node** - Hybrid app (blockchain sync + node API)
- **Orion.Api** - Workflow orchestration API
- **Orion.Worker.Console** - Background job worker
- **Origin.Api** - Authentication API
- **OElite.Servers.Chromia** - Console app (PDF generation)
- **OElite.Migration.CollectionMerger** - CLI tool (execute-and-exit pattern)

## Additional Resources

- **LIFECYCLE-README.md** (helios/core) - Complete lifecycle architecture documentation
- **LIFECYCLE-REFACTORING-COMPLETE.md** (helios/core) - Migration guide and examples
- **03-DEPENDENCY-INJECTION.md** - Auto-discovery configuration details
- **10-OELITE-RESTME-HOSTING-GUIDE.md** - OElite.Restme integration patterns

---

**Last Updated**: December 8, 2024
**Version**: 2.0 (Phase-Based Lifecycle Architecture)
**Status**: **MANDATORY** for all new and migrated applications
