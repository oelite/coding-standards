# OElite Application Lifecycle Standards

## Overview

This document defines the standardized application lifecycle for all OElite applications using the phase-based lifecycle architecture (`OeWebApp`, `OeHybridApp`, `OeConsoleApp`). This architecture ensures consistent behavior, graceful shutdown, resource cleanup, and prevents orphaned processes.

## 🎯 Core Principles

### 1. **Graceful Shutdown by Design**
- All applications MUST implement proper cancellation token propagation
- Background services MUST respond to shutdown signals within 10 seconds
- Never use `.Wait()` in shutdown handlers - always use async patterns with timeouts

### 2. **Phase-Based Lifecycle Management**
- Use `OeWebApp`, `OeHybridApp`, or `OeConsoleApp` for centralized lifecycle
- All shutdown logic is automatic - no manual registration required
- Leverage `OeAppPipelineBuilder` for middleware ordering

### 3. **Resource Cleanup Guarantee**
- All background tasks MUST be cancellable via `CancellationToken`
- File handles, network connections, and external resources MUST be properly disposed
- Use `using` statements and `IDisposable` patterns consistently

## Current Architecture (December 2024)

### Phase-Based Lifecycle Components
- **OeWebApp.RunAsync**: Web applications with ASP.NET Core
- **OeHybridApp.RunAsync**: Background services + Web API (e.g., Kortex, Obelisk)
- **OeConsoleApp.RunAsync**: Console applications and background workers
- **OeAppPipelineBuilder**: Ordered middleware/lifecycle hook configuration
- **WebLifecycleOptions**: Unified configuration for all settings
- **Automatic Features**: Bootstrap discovery, graceful shutdown, cancellation coordination

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

**What's Automatic**:
- Graceful shutdown with 10-second timeout
- `OEliteApplicationLifetime` with SafeCancelToken patterns
- All `IOEliteShutdownAware` services discovered and managed
- Authentication/authorization when enabled
- Rate limiting for API applications
- Swagger/OpenAPI documentation
- Prevention of ObjectDisposedException during shutdown
- No manual cancellation token or cleanup code needed

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

## Background Service Patterns

### ✅ PREFERRED: OEliteBackgroundService

```csharp
using OElite.Common.Hosting.Lifecycle;

public class MyBackgroundService : OEliteBackgroundService
{
    public MyBackgroundService(ILogger<MyBackgroundService> logger) : base(logger) { }

    protected override async Task ExecuteServiceAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Your service logic here
                await DoWorkAsync(cancellationToken);

                // Respect cancellation in delays
                await Task.Delay(TimeSpan.FromMinutes(1), cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                // Expected during shutdown
                break;
            }
        }
    }

    protected override async Task OnShutdownAsync(CancellationToken cancellationToken)
    {
        // Custom cleanup logic
        Logger.LogInformation("Performing custom cleanup...");
        await CleanupResourcesAsync(cancellationToken);
    }
}
```

### 🔧 Manual Implementation with SafeCancelToken Patterns

```csharp
public class MyService : BackgroundService, IOEliteService, IOEliteShutdownAware
{
    private readonly ILogger<MyService> _logger;
    private readonly CancellationTokenSource _serviceCts = new();

    public async Task PrepareForShutdownAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Preparing for shutdown...");

        // Use SafeCancelToken pattern to prevent ObjectDisposedException
        SafeCancelToken(_serviceCts);

        // Perform cleanup with timeout
        try
        {
            await CleanupAsync().WaitAsync(TimeSpan.FromSeconds(5), cancellationToken);
        }
        catch (TimeoutException)
        {
            _logger.LogWarning("Cleanup timed out");
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var combined = CancellationTokenSource.CreateLinkedTokenSource(
            stoppingToken, _serviceCts.Token);

        // Use combined.Token for all operations
        await DoWorkAsync(combined.Token);
    }

    /// <summary>
    /// Safely cancels the cancellation token source without throwing ObjectDisposedException
    /// </summary>
    private void SafeCancelToken(CancellationTokenSource tokenSource)
    {
        try
        {
            if (!tokenSource.IsCancellationRequested)
            {
                tokenSource.Cancel();
                _logger.LogDebug("✅ Cancellation token cancelled safely");
            }
        }
        catch (ObjectDisposedException)
        {
            _logger.LogDebug("⚠️ Attempted to cancel already disposed cancellation token source - ignoring");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "⚠️ Error during safe token cancellation");
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            SafeDisposeCancellationSource(_serviceCts);
        }
        base.Dispose(disposing);
    }

    /// <summary>
    /// Safely disposes the cancellation token source without throwing ObjectDisposedException
    /// </summary>
    private void SafeDisposeCancellationSource(CancellationTokenSource tokenSource)
    {
        try
        {
            tokenSource?.Dispose();
            _logger.LogDebug("✅ Cancellation token source disposed safely");
        }
        catch (ObjectDisposedException)
        {
            _logger.LogDebug("⚠️ Attempted to dispose already disposed cancellation token source - ignoring");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "⚠️ Error during safe cancellation source disposal");
        }
    }
}
```

## Task Management Patterns

### ✅ CORRECT: Cancellable Background Tasks

```csharp
// In service initialization
_backgroundTask = Task.Run(async () =>
{
    try
    {
        await LongRunningOperationAsync(_cancellationToken);
    }
    catch (OperationCanceledException) when (_cancellationToken.IsCancellationRequested)
    {
        // Expected during shutdown
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Background task failed");
    }
}, _cancellationToken);

// In shutdown handler
public async Task PrepareForShutdownAsync(CancellationToken cancellationToken)
{
    _cancellationTokenSource.Cancel();

    if (_backgroundTask != null)
    {
        try
        {
            await _backgroundTask.WaitAsync(TimeSpan.FromSeconds(5), cancellationToken);
        }
        catch (TimeoutException)
        {
            _logger.LogWarning("Background task did not complete within timeout");
        }
    }
}
```

### ❌ FORBIDDEN: Blocking Operations in Shutdown

```csharp
// NEVER DO THIS - causes deadlocks
lifetime.ApplicationStopping.Register(() =>
{
    CleanupBackgroundTasks().Wait(); // ❌ DEADLOCK RISK
});

// NEVER DO THIS - blocks shutdown
public async Task StopAsync(CancellationToken cancellationToken)
{
    await _longRunningTask; // ❌ NO TIMEOUT
}
```

## 🚨 Critical Anti-Patterns to Avoid

### 1. **Synchronous Operations in Shutdown Handlers**
```csharp
// ❌ WRONG
lifetime.ApplicationStopping.Register(() =>
{
    SomeAsyncOperation().Wait();
});

// ✅ CORRECT
lifetime.ApplicationStopping.Register(() =>
{
    _cancellationTokenSource.Cancel();
});
```

### 2. **Infinite Loops Without Cancellation**
```csharp
// ❌ WRONG
while (true)
{
    await DoWork();
    await Task.Delay(1000);
}

// ✅ CORRECT
while (!cancellationToken.IsCancellationRequested)
{
    await DoWork(cancellationToken);
    await Task.Delay(1000, cancellationToken);
}
```

### 3. **Missing Timeout on Cleanup Operations**
```csharp
// ❌ WRONG
await _backgroundTask; // Could hang forever

// ✅ CORRECT
await _backgroundTask.WaitAsync(TimeSpan.FromSeconds(5), cancellationToken);
```

### 4. **Unsafe CancellationTokenSource Operations**
```csharp
// ❌ WRONG - Can cause ObjectDisposedException race conditions
public void Stop()
{
    _cancellationSource.Cancel();
    _cancellationSource.Dispose();
}

// ✅ CORRECT - Use SafeCancelToken pattern
public void Stop()
{
    SafeCancelToken();
    SafeDisposeCancellationSource();
}

private void SafeCancelToken()
{
    try
    {
        if (!_cancellationSource.IsCancellationRequested)
        {
            _cancellationSource.Cancel();
        }
    }
    catch (ObjectDisposedException)
    {
        // Token source already disposed - safe to ignore
    }
}

private void SafeDisposeCancellationSource()
{
    try
    {
        _cancellationSource?.Dispose();
    }
    catch (ObjectDisposedException)
    {
        // Already disposed - safe to ignore
    }
}
```

## 📊 Shutdown Timeline with SafeCancelToken

| Phase | Duration | Action | Responsibility | SafeToken Features |
|-------|----------|--------|----------------|--------------------|
| **Signal** | 0s | `ApplicationStopping` fired | Framework | - |
| **Cancel** | 0s | SafeCancelToken() called | OEliteApplicationLifetime | Prevents ObjectDisposedException |
| **Prepare** | 0-2s | `IOEliteShutdownAware.PrepareForShutdownAsync()` | Application Services | Safe cancellation propagation |
| **Stop** | 2-8s | `IHostedService.StopAsync()` | Hosted Services | Graceful service shutdown |
| **Dispose** | 8-10s | SafeDisposeCancellationSource() | OEliteApplicationLifetime | Safe resource cleanup |
| **Force** | 10s+ | Timeout reached, force termination | Framework | Last resort cleanup |

**Key Features:**
- **Race condition prevention**: SafeCancelToken methods prevent ObjectDisposedException
- **Automatic cleanup**: No manual cancellation token management required
- **Timeout enforcement**: 10-second maximum shutdown time
- **Process cleanup**: No orphaned processes holding ports

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

## 🛠️ Migration Guide

### Step 1: **Identify Current Issues**
- Search for `.Wait()` calls in shutdown handlers
- Find background tasks without cancellation tokens
- Look for missing `IDisposable` implementations

### Step 2: **Update to Latest OeApp** (Automatic - No Code Changes)
- Lifecycle management with SafeCancelToken patterns is now built into all `OeApp` methods
- No manual registration required
- All existing applications get automatic graceful shutdown with race condition prevention
- ObjectDisposedException prevention during shutdown sequences

### Step 3: **Refactor Background Services**
- Inherit from `OEliteBackgroundService` (recommended)
- Or implement `IOEliteShutdownAware` manually
- Add proper cancellation token handling

### Step 4: **Remove Manual Shutdown Code**
- Remove `.Wait()` calls in shutdown handlers
- Remove manual `OEliteApplicationLifetime` registrations
- Remove custom cleanup code (now automatic)

### Step 5: **Test Shutdown Behavior**
```bash
# Start application
./your-app.sh start

# Test graceful shutdown (should complete within 10 seconds)
# Ctrl+C or:
kill -TERM <pid>

# Verify no orphaned processes
lsof -i :<port>  # Should return nothing
```

## 📈 Best Practices Summary

1. **Use phase-based lifecycle runners** - Get automatic lifecycle management with SafeCancelToken patterns
2. **Choose the right runner for your application type:**
   - `OeWebApp.RunAsync<T>()` for standard web applications
   - `OeConsoleApp.RunAsync<T>()` for standard console applications
   - `OeHybridApp.RunAsync<T>()` for hybrid apps (background + web)
3. **Inherit from OEliteBackgroundService** - Proper cancellation token handling built-in
4. **Implement IOEliteShutdownAware** for services with custom cleanup requirements
5. **Always use SafeCancelToken patterns** when manually managing CancellationTokenSource
6. **Always use cancellation tokens** for long-running operations
7. **Never use .Wait()** in any application code - use async patterns with timeouts
8. **Test shutdown behavior** regularly (should complete within 10 seconds)
9. **Monitor for orphaned processes** in production - SafeCancelToken patterns prevent this
10. **Avoid ObjectDisposedException** by using proper disposal patterns in custom services

## Code Standards

### Required Patterns

All applications MUST:
1. Use `OeWebApp.RunAsync()`, `OeHybridApp.RunAsync()`, or `OeConsoleApp.RunAsync()`
2. Use `options.ConfigurePipeline` with `OeAppPipelineBuilder` for middleware ordering
3. Configure `WebLifecycleOptions` properly (EnableSwagger, EnableAuthentication, etc.)
4. Use proper using statements (`OElite.Common.Hosting.AspNetCore`, `OElite.Common.Hosting.AspNetCore.Configuration`)

### Build Requirements

- Build successfully with latest `OElite.Common.Hosting` and `OElite.Common.Hosting.AspNetCore` packages
- Follow documented patterns for application type (Web, Hybrid, Console)
- Use `OeAppPipelineBuilder` for any middleware requiring specific ordering

## Reference Implementations

### Production Examples

- **OElite.Servers.Nexus** - Web API with permission enrichment
- **OElite.Servers.Kortex** - Hybrid app (proxy + management API)
- **OElite.Servers.Obelisk** - Hybrid app (mail server + management API)
- **OElite.Servers.Tesseract** - Storage server API
- **OElite.Servers.Hephaestus** - MCP server API
- **OElite.OeSterling.Api** - Blockchain web API
- **OElite.OeSterling.Node** - Hybrid app (blockchain sync + node API)
- **OElite.OeSterling.MiningClient** - CLI mining tool
- **Orion.Api** - Workflow orchestration API
- **Orion.Worker.Console** - Background job worker
- **Origin.Api** - Authentication API
- **OElite.Servers.Chromia** - Console app (PDF generation)
- **OElite.Migration.CollectionMerger** - CLI tool (execute-and-exit pattern)

## Related Standards

- **07-CONFIGURATION-MANAGEMENT.md** - Configuration lifecycle
- **03-DEPENDENCY-INJECTION.md** - Service registration patterns
- **10-OELITE-RESTME-HOSTING-GUIDE.md** - OElite.Restme integration patterns

## Additional Resources

- **LIFECYCLE-README.md** (helios/core) - Complete lifecycle architecture documentation
- **LIFECYCLE-REFACTORING-COMPLETE.md** (helios/core) - Migration guide and examples

---

**Last Updated**: December 8, 2024  
**Version**: 3.0 (Consolidated Lifecycle Standards)  
**Implementation Priority**: HIGH - This affects all applications and prevents production issues like port conflicts and resource leaks.
