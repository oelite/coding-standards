# 07 - APPLICATION LIFECYCLE MANAGEMENT

## Overview

This document establishes the **OElite Application Lifecycle Management Standards** to ensure consistent, reliable, and graceful shutdown behavior across all OElite applications. These standards prevent orphaned processes, port binding issues, and resource leaks.

## 🎯 Core Principles

### 1. **Graceful Shutdown by Design**
- All applications MUST implement proper cancellation token propagation
- Background services MUST respond to shutdown signals within 10 seconds
- Never use `.Wait()` in shutdown handlers - always use async patterns with timeouts

### 2. **Centralized Lifecycle Management**
- Use `OEliteApplicationLifetime` for coordinated shutdown across all services
- Implement `IOEliteShutdownAware` for services requiring custom cleanup
- Leverage the enhanced `OeAppEnhanced` runners for new applications

### 3. **Resource Cleanup Guarantee**
- All background tasks MUST be cancellable via `CancellationToken`
- File handles, network connections, and external resources MUST be properly disposed
- Use `using` statements and `IDisposable` patterns consistently

## 📋 Implementation Standards

### 1. Application Startup Pattern

#### ✅ **STANDARD: Enhanced OeApp Runners with SafeCancelToken Patterns**

All OeApp runners now include automatic lifecycle management with enhanced safety patterns. No manual registration required:

**For Web Applications:**
```csharp
// Program.cs - Standard web application pattern
public static async Task Main(string[] args)
{
    await OeApp.RunWebAppAsync<AppConfig>(args, "AppName");
}
```

**For Console Applications:**
```csharp
// Program.cs - Standard console application pattern
public static async Task Main(string[] args)
{
    await OeApp.RunConsoleAppAsync<AppConfig>(args, "AppName");
}
```

**For Hybrid Applications (Console + Web):**
```csharp
// Program.cs - Enhanced hybrid pattern with full web features
public static async Task Main(string[] args)
{
    await OeApp.RunHybridAppAsync<KortexAppConfig>(
        args,
        "OElite.Servers.Kortex",
        enableWebHosting: true,  // Enables full web app configuration
        configureServices: builder =>
        {
            // Add application-specific services
            KortexAppExtensions.AddKortexServices<KortexAppConfig>(builder);
        },
        configureApp: async app =>
        {
            // Configure middleware pipeline - CORS automatically configured
            await ConfigureKortexMiddleware(app);
        });
}
```

**What's Automatic:**
- `OEliteApplicationLifetime` with SafeCancelToken patterns
- Graceful shutdown handling with race condition prevention
- All `IOEliteShutdownAware` services are discovered and managed
- Automatic CORS configuration for API applications (OeAppType.Kortex, OeAppType.Platform, OeAppType.GeneralWebApi)
- Automatic authentication/authorization when required
- Automatic rate limiting for API applications
- Automatic Swagger/OpenAPI documentation
- No manual cancellation token or cleanup code needed
- Prevention of ObjectDisposedException during shutdown

**Enhanced RunHybridAppAsync Features:**
- **enableWebHosting=true**: Provides full web app configuration including CORS, authentication, Swagger
- **enableWebHosting=false**: Console-only mode for background services
- **Automatic OeAppType detection**: Based on the configuration type parameter
- **Middleware auto-configuration**: Proper ordering of CORS, authentication, rate limiting
- **No manual service registration**: All required services auto-registered based on app type

### 2. CORS and Middleware Auto-Configuration

#### ✅ **AUTOMATIC: OeAppType-Based Configuration**

The enhanced lifecycle automatically configures CORS, authentication, and other middleware based on your application type:

```csharp
// For API applications (Kortex, Platform, GeneralWebApi)
// CORS is automatically configured with permissive policy:
// - AllowAnyOrigin()
// - AllowAnyMethod()
// - AllowAnyHeader()

// Middleware order is automatically optimized:
// 1. Global Exception Handler
// 2. CORS (before routing for preflight)
// 3. Routing
// 4. Rate Limiting (after routing)
// 5. Authentication
// 6. Authorization
// 7. Controllers
```

**Custom CORS Configuration:**
```csharp
await OeApp.RunHybridAppAsync<AppConfig>(
    args, "AppName",
    enableWebHosting: true,
    corsOptions: options =>
    {
        // Override default CORS policy
        options.AddPolicy("CustomPolicy", policy =>
        {
            policy.WithOrigins("https://myapp.com")
                  .AllowCredentials();
        });
    });
```

**Authentication Customization:**
```csharp
await OeApp.RunHybridAppAsync<AppConfig>(
    args, "AppName",
    enableWebHosting: true,
    enableAuthentication: false,  // Disable automatic auth
    authzOptions: options =>
    {
        // Custom authorization policies
        options.AddPolicy("CustomAuth", policy =>
        {
            policy.RequireClaim("custom_claim");
        });
    });
```

### 3. Background Service Pattern

#### ✅ **PREFERRED: OEliteBackgroundService**

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

#### 🔧 **Manual Implementation with SafeCancelToken Patterns**

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

### 4. Task Management Patterns

#### ✅ **CORRECT: Cancellable Background Tasks**

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

#### ❌ **FORBIDDEN: Blocking Operations in Shutdown**

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

## 📊 Enhanced Shutdown Timeline with SafeCancelToken

The enhanced shutdown process now includes SafeCancelToken patterns to prevent race conditions:

| Phase | Duration | Action | Responsibility | SafeToken Features |
|-------|----------|--------|----------------|--------------------|
| **Signal** | 0s | `ApplicationStopping` fired | Framework | - |
| **Cancel** | 0s | SafeCancelToken() called | OEliteApplicationLifetime | Prevents ObjectDisposedException |
| **Prepare** | 0-2s | `IOEliteShutdownAware.PrepareForShutdownAsync()` | Application Services | Safe cancellation propagation |
| **Stop** | 2-8s | `IHostedService.StopAsync()` | Hosted Services | Graceful service shutdown |
| **Dispose** | 8-10s | SafeDisposeCancellationSource() | OEliteApplicationLifetime | Safe resource cleanup |
| **Force** | 10s+ | Timeout reached, force termination | Framework | Last resort cleanup |

**Key Improvements:**
- **Race condition prevention**: SafeCancelToken methods prevent ObjectDisposedException
- **Automatic cleanup**: No manual cancellation token management required
- **Timeout enforcement**: 10-second maximum shutdown time
- **Process cleanup**: No orphaned processes holding ports

## 🛠️ Migration Guide

### Step 1: **Identify Current Issues**
- Search for `.Wait()` calls in shutdown handlers
- Find background tasks without cancellation tokens
- Look for missing `IDisposable` implementations

### Step 2: **Update to Latest OeApp with Enhanced Safety** (Automatic - No Code Changes)
- Lifecycle management with SafeCancelToken patterns is now built into all `OeApp` methods
- No manual registration required
- All existing applications get automatic graceful shutdown with race condition prevention
- Enhanced RunHybridAppAsync provides full web app features when enableWebHosting=true
- Automatic CORS configuration for API applications
- ObjectDisposedException prevention during shutdown sequences

### Step 3: **Refactor Background Services**
- Inherit from `OEliteBackgroundService` (recommended)
- Or implement `IOEliteShutdownAware` manually
- Add proper cancellation token handling

### Step 4: **Remove Manual Shutdown Code and Middleware Configuration**
- Remove `.Wait()` calls in shutdown handlers
- Remove manual `OEliteApplicationLifetime` registrations
- Remove custom cleanup code (now automatic)
- Remove manual CORS configuration (now automatic for API apps)
- Remove manual authentication setup (now automatic)
- Remove redundant service registrations (AddRateLimiting, etc.)
- Remove conflicting middleware (UseSecurityHeaders if overriding CORS)

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

1. **Use enhanced OeApp runners** - Get automatic lifecycle management with SafeCancelToken patterns for free
2. **Choose the right runner for your application type:**
   - `RunWebAppAsync<T>()` for standard web applications
   - `RunConsoleAppAsync<T>()` for standard console applications
   - `RunHybridAppAsync<T>(enableWebHosting: true)` for hybrid apps needing full web features
3. **Inherit from OEliteBackgroundService** - Proper cancellation token handling built-in
4. **Implement IOEliteShutdownAware** for services with custom cleanup requirements
5. **Always use SafeCancelToken patterns** when manually managing CancellationTokenSource
6. **Always use cancellation tokens** for long-running operations
7. **Never use .Wait()** in any application code - use async patterns with timeouts
8. **Test shutdown behavior** regularly (should complete within 10 seconds)
9. **Monitor for orphaned processes** in production - SafeCancelToken patterns prevent this
10. **Avoid ObjectDisposedException** by using proper disposal patterns in custom services

## 🔗 Related Standards

- [06-CONFIGURATION-MANAGEMENT.md](06-CONFIGURATION-MANAGEMENT.md) - Configuration lifecycle
- [02-DEPENDENCY-INJECTION.md](02-DEPENDENCY-INJECTION.md) - Service registration patterns
- [01-LOGGING.md](01-LOGGING.md) - Logging during shutdown

---

**Implementation Priority: HIGH** - This affects all applications and prevents production issues like port conflicts and resource leaks.