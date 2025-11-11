# OElite Application Lifecycle Standards

## Overview

This document defines the standardized application lifecycle for all OElite applications. The lifecycle ensures consistent initialization patterns, configuration management, and bootstrap processes across the entire platform.

## Hosting Package Architecture

The OElite hosting system is split into two complementary packages:

### OElite.Common.Hosting (Generic)
**Purpose**: Provides generic hosting bootstrapper for **any .NET application type**
- **Use Cases**: Console applications, mobile apps, desktop apps, background services
- **Dependencies**: Only core Microsoft.Extensions.* packages (Configuration, Hosting, Logging, DI)
- **Components**: Generic bootstrap orchestrator, configuration services, path resolution, model transformation

### OElite.Common.Hosting.AspNetCore (Web-Specific)
**Purpose**: Provides ASP.NET Core specific hosting components for **web applications**
- **Use Cases**: Web APIs, web applications, microservices
- **Dependencies**: ASP.NET Core, Swagger, MVC formatters, FluentValidation
- **Components**: Web middleware, Swagger integration, API formatters, web-specific extensions

## Application Lifecycle Phases

The OElite application lifecycle consists of four distinct phases that must be executed in order:

### Phase 1: Configuration Loading
**Purpose**: Load application configuration from standardized sources
**Implementation**: Handled by ASP.NET Core configuration system

```csharp
// Standard configuration loading pattern for all OElite applications
var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("configs/appsettings.init.json", optional: false)
    .AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true)
    .AddEnvironmentVariables();
```

**Configuration Hierarchy** (later sources override earlier ones):
1. `configs/appsettings.init.json` - Base configuration (required)
2. `configs/.dev/{Environment}/appsettings.init.json` - Environment-specific overrides (optional)
3. Environment variables - Runtime overrides

### Phase 2: Kortex Configuration Service Integration
**Purpose**: Connect to centralized configuration management (for non-Kortex applications)
**Implementation**: Application-specific (Kortex is the configuration provider)

```csharp
// Only for applications that are NOT Kortex itself
services.AddKortexConfigurationService(configuration);
```

**Note**: Kortex server does NOT fetch configuration from itself.

### Phase 3: OElite Services and Repositories Registration
**Purpose**: Register all OElite services, repositories, and hosted services
**Implementation**: Automatic discovery via reflection

```csharp
builder.Services.AddOEliteApplicationLifecycle();
// OR with explicit assemblies:
builder.Services.AddOEliteApplicationLifecycle(Assembly.GetExecutingAssembly(), additionalAssemblies);
```

**Auto-Discovery Process**:
- Scans assemblies for `IOEliteService` implementations
- Scans assemblies for `IOEliteDataRepository` implementations
- Scans assemblies for `IBootstrapProvider` implementations
- Registers all discovered services in dependency injection container

### Phase 4: Bootstrap Initialization
**Purpose**: Initialize application with default data and configurations
**Implementation**: Orchestrated bootstrap provider system

```csharp
// Execute all registered bootstrap providers
await app.InitializeOEliteApp();
```

## Standardized Program.cs Patterns

### Console Application Pattern

```csharp
using OElite.Common.Hosting.Bootstrap;
using MyApp.Services;

var host = Host.CreateDefaultBuilder(args)
    .ConfigureOeApp<MyAppConfig>()
    .Build();

// Phase 4: Bootstrap Initialization
await host.InitOeApp();

await host.RunAsync();
```

### Web Application Pattern

```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;
using OElite.Common.Hosting.AspNetCore.Middleware;
// Additional application-specific imports...

var builder = WebApplication.CreateBuilder(args);

// Phase 1-3: Complete OElite web application lifecycle
builder.ConfigureOeWebApp<PlatformAppConfig>()
    .Services.AddOEliteApi(builder.Configuration); // Application-specific API setup

// Additional application-specific service registration...
builder.Services.AddSignalR();
builder.WebHost.UseKestrel(options => { /* ... */ });

var app = builder.Build();

// Web-specific middleware configuration...
app.UseSwagger();
app.UseSwaggerUI();
app.UseGlobalExceptionHandler(); // From AspNetCore package
app.UseRequestLogging(); // From AspNetCore package
app.UseOEliteApi();
// Additional middleware...

// Phase 4: Bootstrap Initialization
await app.InitOeWebApp();

app.Run();
```

### Mobile/Desktop Application Pattern

```csharp
using OElite.Common.Hosting.Bootstrap;
using MyMobileApp.Services;

var host = Host.CreateDefaultBuilder(args)
    .ConfigureOeApp<MyMobileAppConfig>(
        environmentVariableName: "DOTNET_ENVIRONMENT" // Generic environment variable
    )
    .Build();

// Phase 4: Bootstrap Initialization
await host.InitOeApp();

// Start your mobile/desktop application
await StartApplicationAsync(host);
```

## Bootstrap Provider System

### Creating Bootstrap Providers

Bootstrap providers handle initialization of specific types of data or configuration. Each provider implements `IBootstrapProvider`:

```csharp
public class AppClientBootstrapProvider : BootstrapProviderBase
{
    public override string ConfigurationFileName => "app-clients-init.json";
    public override int Priority => 10; // Lower numbers execute first

    public override async Task<bool> ShouldInitializeAsync()
    {
        // Check if initialization is needed (e.g., database is empty)
        var existingData = await _repository.GetExistingDataAsync();
        return !existingData.Any();
    }

    public override async Task InitializeAsync()
    {
        // Load configuration and initialize data
        var config = await LoadConfigurationAsync<AppClientsInitConfiguration>();
        foreach (var item in config.Items)
        {
            await _repository.CreateAsync(item);
        }
    }
}
```

### Bootstrap Provider Best Practices

1. **Single Responsibility**: Each provider should handle one type of initialization
2. **Idempotent**: Providers should be safe to run multiple times
3. **Priority-Based**: Use priority to control execution order
4. **Environment-Aware**: Support environment-specific overrides
5. **Error Handling**: Don't fail application startup if bootstrap fails

### Configuration File Standards

Bootstrap providers load configuration from JSON files in the `configs/` directory:

**File Structure**:
```
configs/
├── appsettings.init.json              # Base configuration
├── app-clients-init.json              # App client bootstrap data
├── permissions-init.json              # Permission bootstrap data
└── .dev/
    ├── Development/
    │   ├── appsettings.init.json       # Development overrides
    │   └── app-clients-init.json       # Development bootstrap overrides
    └── Production/
        ├── appsettings.init.json       # Production overrides
        └── app-clients-init.json       # Production bootstrap overrides
```

**Configuration Merging**:
- Base configuration is loaded first
- Environment-specific overrides are merged (if they exist)
- Override behavior can be customized in each provider

## Extension Methods

The lifecycle is implemented through extension methods that provide a fluent API:

### Generic Hosting Extensions (OElite.Common.Hosting)

```csharp
// For console, mobile, and desktop applications
var host = Host.CreateDefaultBuilder(args)
    .ConfigureOeApp<MyAppConfig>()
    .Build();

// Execute lifecycle initialization (generic)
await host.InitOeApp();
```

### Web Hosting Extensions (OElite.Common.Hosting.AspNetCore)

```csharp
// For web applications
var builder = WebApplication.CreateBuilder(args);
builder.ConfigureOeWebApp<MyAppConfig>();

var app = builder.Build();

// Execute lifecycle initialization (web-specific)
await app.InitOeWebApp();

// Web-specific middleware
app.UseGlobalExceptionHandler();
app.UseRequestLogging();
```

### Service Registration Extensions

```csharp
// Individual components (both packages)
services.AddOEliteBootstrap(assemblies);
services.AddBootstrapProvider<MyBootstrapProvider>();
services.AddOEliteDataRepositories(assemblies);
services.AddOEliteServices(assemblies);

// Web-specific service registration (AspNetCore package only)
services.AddModelTransformationWithAutoDiscovery();
```

### Package Import Guidelines

**For Generic Applications** (Console, Mobile, Desktop):
```csharp
using OElite.Common.Hosting.Bootstrap;
using OElite.Common.Hosting.Configuration;
// No AspNetCore-specific imports
```

**For Web Applications**:
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;
using OElite.Common.Hosting.AspNetCore.Middleware;
using OElite.Common.Hosting.AspNetCore.Swagger;
// Can also use generic hosting components
```

## Directory Structure Standards

All OElite applications should follow this directory structure:

```
OElite.Servers.ApplicationName/
├── configs/
│   ├── appsettings.init.json           # Required base configuration
│   ├── {feature}-init.json             # Bootstrap configuration files
│   └── .dev/
│       ├── Development/
│       │   ├── appsettings.init.json   # Development overrides
│       │   └── {feature}-init.json     # Development bootstrap overrides
│       └── Production/
│           ├── appsettings.init.json   # Production overrides
│           └── {feature}-init.json     # Production bootstrap overrides
├── Services/
│   └── Bootstrap/
│       └── {Feature}BootstrapProvider.cs
├── Controllers/
├── Middleware/
├── Program.cs                          # Follows standardized pattern
└── OElite.Servers.ApplicationName.csproj
```

## Migration Guide

### From Old Bootstrap Pattern

**Before** (Legacy Pattern):
```csharp
// Old manual bootstrap registration
services.AddSingleton<BootstrapInitializationService>();

// Old manual bootstrap execution
var bootstrapService = scope.ServiceProvider.GetService<BootstrapInitializationService>();
await bootstrapService.InitializeAsync();
```

**After** (New Standardized Pattern):
```csharp
// Automatic bootstrap discovery and registration
builder.ConfigureOEliteLifecycle();

// Standardized bootstrap execution
await app.InitializeOEliteApp();
```

### Converting Existing Bootstrap Services

1. **Split monolithic bootstrap service** into focused providers
2. **Inherit from `BootstrapProviderBase`** instead of implementing custom logic
3. **Remove manual service registration** - auto-discovery handles it
4. **Update Program.cs** to use standardized lifecycle pattern

## Environment-Specific Behavior

The lifecycle system provides built-in support for environment-specific configuration:

### Development Environment
- Loads overrides from `configs/.dev/Development/`
- Supports rapid iteration and testing
- May include additional debug providers

### Production Environment
- Loads overrides from `configs/.dev/Production/`
- Optimized for performance and security
- May exclude debug-only providers

### Custom Environments
- Only Development and Production overrides are loaded
- Other environments use base configuration only

## Error Handling and Logging

The lifecycle system includes comprehensive error handling:

### Bootstrap Orchestrator
- Continues execution if individual providers fail
- Logs detailed information about each phase
- Provides diagnostic information about registered providers

### Provider-Level Error Handling
- Providers should handle their own errors gracefully
- Failed providers don't prevent application startup
- All errors are logged with appropriate context

### Logging Standards
```csharp
// Success messages
Logger.LogInformation("✅ Successfully initialized {ProviderName}", providerName);

// Warning messages
Logger.LogWarning("⚠️  Configuration file not found: {File}", configFile);

// Error messages
Logger.LogError(ex, "❌ Error during bootstrap initialization for {ProviderName}", providerName);

// Debug information
Logger.LogDebug("📂 Loading configuration from {File}", configFile);
```

## Testing the Lifecycle

### Unit Testing Bootstrap Providers
```csharp
[Test]
public async Task ShouldInitializeAsync_EmptyDatabase_ReturnsTrue()
{
    // Arrange
    var provider = new AppClientBootstrapProvider(logger, hostEnvironment, repository, service);

    // Act
    var result = await provider.ShouldInitializeAsync();

    // Assert
    Assert.True(result);
}
```

### Integration Testing
```csharp
[Test]
public async Task ApplicationLifecycle_CompletesSuccessfully()
{
    // Test complete lifecycle execution
    await app.InitializeOEliteApp();

    // Verify providers executed correctly
    var providers = app.Services.GetBootstrapProviders();
    Assert.True(providers.Any());
}
```

## Performance Considerations

### Auto-Discovery Optimization
- Assembly scanning occurs once at startup
- Results are cached in dependency injection container
- Minimal runtime overhead after initialization

### Bootstrap Execution
- Providers execute sequentially by priority
- Each provider's `ShouldInitializeAsync()` is called first
- Only necessary providers execute their `InitializeAsync()` method

### Configuration Loading
- JSON files are loaded once per provider
- Environment overrides are merged efficiently
- Configuration objects are disposed after use

## Security Considerations

### Configuration File Security
- Never store secrets in configuration files
- Use environment variables for sensitive data
- Support for `${ENV_VAR}` substitution in JSON files

### Bootstrap Data Security
- Hash sensitive data (passwords, secrets) before storage
- Validate all input data before processing
- Log security-relevant events appropriately

## Troubleshooting

### Common Issues

**Bootstrap providers not executing**:
- Verify provider implements `IBootstrapProvider`
- Check provider is in scanned assemblies
- Ensure `ShouldInitializeAsync()` returns true

**Configuration not loading**:
- Verify `configs/appsettings.init.json` exists
- Check file path resolution
- Validate JSON syntax

**Environment overrides not applied**:
- Confirm environment name matches directory name
- Verify override file exists in correct location
- Check merge logic in provider

### Diagnostic Information
```csharp
// Get provider information
var providers = app.Services.GetBootstrapProviders();
foreach (var provider in providers)
{
    Console.WriteLine($"Provider: {provider.Name} (Priority: {provider.Priority})");
    Console.WriteLine($"Config File: {provider.ConfigurationFileName}");
}

// Check for pending initialization
bool hasPending = await app.Services.HasPendingBootstrapAsync();
Console.WriteLine($"Has pending initialization: {hasPending}");
```

## Future Enhancements

### Planned Features
- Health check integration for bootstrap status
- Metrics collection for bootstrap performance
- Support for async configuration loading from external sources
- Integration with OElite monitoring and alerting

### Backward Compatibility
- Legacy bootstrap services will continue to work
- Migration path provided for gradual adoption
- Deprecation warnings for old patterns

---

## Benefits of Package Separation

### Generic Hosting (OElite.Common.Hosting)
✅ **Zero ASP.NET Core dependencies** - Perfect for console and mobile applications
✅ **Lightweight bootstrapper** - Only essential Microsoft.Extensions.* packages
✅ **Universal compatibility** - Works with any .NET application type
✅ **Clean separation** - No web-specific concerns mixed in

### Web Hosting (OElite.Common.Hosting.AspNetCore)
✅ **Web-optimized** - Full ASP.NET Core, Swagger, and MVC integration
✅ **Rich middleware** - Global exception handling, request logging, API formatters
✅ **Developer experience** - Comprehensive Swagger documentation and validation
✅ **Production ready** - All web-specific optimizations included

### Achieved Goals
- **Your desired API is fully implemented**:
  - Console: `Host.CreateDefaultBuilder(args).ConfigureOeApp<T>().Build()`
  - Web: `WebApplication.CreateBuilder(args).ConfigureOeWebApp<T>().Build()`
- **Complete separation of concerns** between generic and web hosting
- **Backward compatibility** maintained for existing applications
- **Future-proof architecture** supports mobile and desktop application development

## Implementation Checklist

When implementing the OElite Application Lifecycle in a new application:

### For Any Application Type
- [ ] Choose appropriate hosting package (Generic vs AspNetCore)
- [ ] Update Program.cs to use standardized pattern for your application type
- [ ] Create bootstrap providers for each initialization concern
- [ ] Move configuration files to standard locations
- [ ] Remove old manual bootstrap code
- [ ] Add proper error handling and logging
- [ ] Test lifecycle execution in all environments
- [ ] Document application-specific bootstrap requirements

### For Console/Mobile/Desktop Applications
- [ ] Use `OElite.Common.Hosting` package only
- [ ] Follow console application pattern
- [ ] Use `DOTNET_ENVIRONMENT` variable
- [ ] Avoid ASP.NET Core specific imports

### For Web Applications
- [ ] Use both `OElite.Common.Hosting` and `OElite.Common.Hosting.AspNetCore` packages
- [ ] Follow web application pattern
- [ ] Use `ASPNETCORE_ENVIRONMENT` variable
- [ ] Configure web-specific middleware and Swagger