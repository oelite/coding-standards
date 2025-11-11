# OElite.Common.Hosting Integration Guide

## Overview

OElite.Common.Hosting provides streamlined application startup and lifecycle management for OElite applications. It eliminates the need for manual service registration, configuration setup, and middleware pipeline configuration by providing automatic discovery and configuration based on application type detection.

## Key Benefits

- ✅ **One-line startup** - Complete application configuration with a single method call
- ✅ **Automatic service discovery** - All IOEliteService, repositories, and bootstrap providers auto-registered
- ✅ **Automatic configuration** - Configs-only pattern, Kortex configuration, OElite.Restme caching
- ✅ **Automatic middleware** - Authentication, CORS, API formatters, Swagger, exception handling
- ✅ **App type detection** - Automatic OeAppType detection from IAppConfig implementation
- ✅ **Consistent patterns** - Standardized startup across all OElite applications

## Installation

```bash
dotnet add package OElite.Common.Hosting
dotnet add package OElite.Common.Hosting.AspNetCore
```

## Application Startup Patterns

### 1. Web Applications (ASP.NET Core)

#### **Simple Web App**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        // ✅ REQUIRED - One-line web application startup
        await OeApp.RunWebAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteWebApp"
        );
    }
}
```

#### **Web App with Custom Configuration**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        await OeApp.RunWebAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteWebApp",
            enableAuthentication: true,
            configureServices: builder =>
            {
                // Additional service configuration
                builder.Services.AddCustomServices();
                builder.Services.Configure<CustomOptions>(builder.Configuration.GetSection("Custom"));
            },
            configureApp: async app =>
            {
                // Additional app configuration
                app.UseCustomMiddleware();
                app.MapCustomEndpoints();
            },
            corsOptions: cors =>
            {
                // Custom CORS configuration
                cors.AllowAnyOrigin();
                cors.AllowAnyMethod();
                cors.AllowAnyHeader();
            }
        );
    }
}
```

### 2. Console Applications

#### **Simple Console App**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        // ✅ REQUIRED - One-line console application startup
        await OeApp.RunHybridAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteConsoleApp",
            enableWebHosting: false
        );
    }
}
```

#### **Hybrid App (Console + Web)**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        await OeApp.RunHybridAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteHybridApp",
            enableWebHosting: true, // Enable web hosting
            enableAuthentication: true,
            configureServices: builder =>
            {
                // Additional services for both console and web
                builder.Services.AddBackgroundServices();
            },
            configureApp: async app =>
            {
                // Additional configuration for web components
                app.MapHealthChecks("/health");
            }
        );
    }
}
```

### 3. Manual Configuration (Advanced Use Cases)

#### **Custom Builder Configuration**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // ✅ REQUIRED - Configure OElite application lifecycle
        builder.ConfigureOeWebApp<AppConfig>(
            enableAuthentication: true,
            dependencyInjectionOptions: options =>
            {
                // Configure service discovery options
                options.IncludeAssemblies = new[] { "MyApp", "MyApp.Services" };
                options.ExcludeNamespaces = new[] { "MyApp.Tests", "MyApp.Mocks" };
                options.ServiceLifetime = ServiceLifetime.Scoped;
            },
            corsOptions: cors =>
            {
                cors.AllowSpecificOrigins("https://myapp.com");
            }
        );

        // Additional service configuration
        builder.Services.AddCustomServices();
        builder.Services.AddCustomAuthentication();

        var app = builder.Build();

        // ✅ REQUIRED - Initialize OElite application
        await app.InitOeWebApp<AppConfig>();

        // Additional app configuration
        app.UseCustomMiddleware();
        app.MapCustomEndpoints();

        await app.RunAsync();
    }
}
```

## What Gets Automatically Configured

### 1. Service Registration

The hosting extensions automatically discover and register:

#### **IOEliteService Implementations**
```csharp
// ✅ Automatically registered
public class ProductService : IOEliteService
{
    // Implementation
}

public class OrderService : IOEliteService
{
    // Implementation
}
```

#### **Repository Implementations**
```csharp
// ✅ Automatically registered
public class ProductRepository : DataRepository<Product>, IProductRepository
{
    // Implementation
}

public class OrderRepository : DataRepository<Order>, IOrderRepository
{
    // Implementation
}
```

#### **Background Services**
```csharp
// ✅ Automatically registered as IHostedService
public class DataSyncWorker : BackgroundService, IOEliteService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Background work
    }
}
```

#### **Bootstrap Providers**
```csharp
// ✅ Automatically registered and executed during startup
public class DatabaseBootstrapProvider : IBootstrapProvider
{
    public async Task InitializeAsync()
    {
        // Database initialization logic
    }
}
```

### 2. Configuration Management

#### **Configs-Only Pattern**
```json
// configs/appsettings.init.json (base configuration)
{
  "oelite": {
    "data": {
      "redis": {
        "platform": "localhost:6379"
      }
    }
  }
}

// configs/.dev/Development/appsettings.init.json (environment override)
{
  "oelite": {
    "data": {
      "redis": {
        "platform": "dev-redis:6379"
      }
    }
  }
}
```

#### **Kortex Configuration**
```csharp
// ✅ Automatically configured
public class AppConfig : BaseAppConfig, IAppConfig
{
    public string RedisConnectionString { get; set; }
    public string DatabaseConnectionString { get; set; }
    
    // Automatically updated by KortexConfigurationService
}
```

### 3. OElite.Restme Caching

#### **Automatic Cache Configuration**
```csharp
// ✅ Automatically configured based on configuration
// Redis when available:
services.AddRestmeRedisCache(redisConnectionString, "oelite:");

// Memory fallback:
services.AddRestmeMemoryCacheWithDistributed("oelite:");
```

### 4. Middleware Pipeline (Web Apps)

#### **Automatic Middleware Configuration**
```csharp
// ✅ Automatically configured based on OeAppType
app.UseAuthentication();
app.UseAuthorization();
app.UseCors();
app.UseResponseCompression();
app.UseSwagger();
app.UseSwaggerUI();
app.UseExceptionHandling();
app.MapControllers();
```

## Application Type Detection

### OeAppType Detection

The hosting extensions automatically detect application type from the IAppConfig implementation:

```csharp
public class PlatformAppConfig : BaseAppConfig, IAppConfig
{
    // Automatically detected as OeAppType.Platform
    // Enables authentication, authorization, and platform-specific middleware
}

public class KortexAppConfig : BaseAppConfig, IAppConfig
{
    // Automatically detected as OeAppType.Kortex
    // Enables Kortex-specific services and middleware
}

public class ConsoleAppConfig : BaseAppConfig, IAppConfig
{
    // Automatically detected as OeAppType.Console
    // Minimal web hosting, focuses on background services
}
```

### App-Specific Configuration

#### **Platform Applications**
- ✅ Authentication and authorization enabled
- ✅ OElite policy applied by default
- ✅ Full API documentation with Swagger
- ✅ CORS configured for web clients

#### **Kortex Applications**
- ✅ Custom authentication patterns
- ✅ Kortex-specific services
- ✅ Configuration management UI
- ✅ Neuron-based configuration

#### **Console Applications**
- ✅ Background service support
- ✅ Minimal web hosting (optional)
- ✅ File-based logging
- ✅ Configuration validation

## Bootstrap System

### Bootstrap Providers

Implement `IBootstrapProvider` for application initialization:

```csharp
public class DatabaseBootstrapProvider : IBootstrapProvider
{
    private readonly DbCentre _dbCentre;
    private readonly ILogger<DatabaseBootstrapProvider> _logger;

    public DatabaseBootstrapProvider(DbCentre dbCentre, ILogger<DatabaseBootstrapProvider> logger)
    {
        _dbCentre = dbCentre;
        _logger = logger;
    }

    public async Task InitializeAsync()
    {
        _logger.LogInformation("Initializing database...");
        
        // Create indexes
        await _dbCentre.CreateIndexAsync<Product>("name");
        await _dbCentre.CreateIndexAsync<Order>("customerId");
        
        // Seed initial data
        await SeedInitialDataAsync();
        
        _logger.LogInformation("Database initialization completed");
    }

    private async Task SeedInitialDataAsync()
    {
        // Seed data logic
    }
}
```

### Bootstrap Execution Order

1. **Configuration Loading** - Load configs and Kortex configuration
2. **Service Registration** - Register all discovered services
3. **Bootstrap Providers** - Execute all IBootstrapProvider implementations
4. **Application Startup** - Start the application

## Advanced Configuration

### Service Discovery Options

```csharp
builder.ConfigureOeWebApp<AppConfig>(
    dependencyInjectionOptions: options =>
    {
        // Include specific assemblies
        options.IncludeAssemblies = new[] { "MyApp", "MyApp.Services" };
        
        // Exclude specific namespaces
        options.ExcludeNamespaces = new[] { "MyApp.Tests", "MyApp.Mocks" };
        
        // Set default service lifetime
        options.ServiceLifetime = ServiceLifetime.Scoped;
        
        // Custom service filtering
        options.ServiceFilter = type => 
            !type.Name.Contains("Test") && 
            !type.Name.Contains("Mock");
    }
);
```

### Custom Authentication Configuration

```csharp
builder.ConfigureOeWebApp<AppConfig>(
    enableAuthentication: true,
    authzOptions: authz =>
    {
        // Custom authorization policies
        authz.AddPolicy("admin", policy => policy.RequireRole("Admin"));
        authz.AddPolicy("user", policy => policy.RequireRole("User", "Admin"));
    }
);
```

### Custom CORS Configuration

```csharp
builder.ConfigureOeWebApp<AppConfig>(
    corsOptions: cors =>
    {
        cors.AllowSpecificOrigins("https://myapp.com", "https://admin.myapp.com");
        cors.AllowSpecificMethods("GET", "POST", "PUT", "DELETE");
        cors.AllowSpecificHeaders("Authorization", "Content-Type");
        cors.AllowCredentials();
    }
);
```

## Migration from Manual Configuration

### Before (Manual Configuration)

```csharp
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Manual configuration loading
        builder.Configuration
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("configs/appsettings.init.json", optional: false)
            .AddJsonFile($"configs/.dev/{Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")}/appsettings.init.json", optional: true)
            .AddEnvironmentVariables();

        // Manual service registration
        builder.Services.AddOEliteServices(typeof(Program).Assembly);
        builder.Services.AddOEliteRepositories(typeof(Program).Assembly);
        builder.Services.AddDbCentre(builder.Configuration.GetConnectionString("DefaultConnection"));
        builder.Services.AddSingleton<AppConfig>();
        builder.Services.AddOElitePathResolver("myapp");
        builder.Services.AddRestmeRedisCache(options =>
        {
            options.ConnectionString = builder.Configuration["oelite:data:redis:platform"];
            options.InstanceName = "myapp:";
        });

        // Manual middleware configuration
        builder.Services.AddControllers();
        builder.Services.AddAuthentication();
        builder.Services.AddAuthorization();
        builder.Services.AddCors();
        builder.Services.AddSwaggerGen();

        var app = builder.Build();

        // Manual middleware pipeline
        app.UseAuthentication();
        app.UseAuthorization();
        app.UseCors();
        app.UseSwagger();
        app.UseSwaggerUI();
        app.MapControllers();

        app.Run();
    }
}
```

### After (OElite.Common.Hosting)

```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        // ✅ One-line configuration
        await OeApp.RunWebAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteApp"
        );
    }
}
```

## Best Practices

### 1. Application Configuration

```csharp
// ✅ Good - Inherit from BaseAppConfig and implement IAppConfig
public class AppConfig : BaseAppConfig, IAppConfig
{
    public string DatabaseConnectionString { get; set; }
    public string RedisConnectionString { get; set; }
    public bool EnableSwagger { get; set; } = true;
    
    public override void Validate()
    {
        if (string.IsNullOrEmpty(DatabaseConnectionString))
            throw new InvalidOperationException("Database connection string is required");
    }
}
```

### 2. Bootstrap Providers

```csharp
// ✅ Good - Implement IBootstrapProvider for initialization
public class DatabaseBootstrapProvider : IBootstrapProvider
{
    private readonly DbCentre _dbCentre;
    private readonly ILogger<DatabaseBootstrapProvider> _logger;

    public DatabaseBootstrapProvider(DbCentre dbCentre, ILogger<DatabaseBootstrapProvider> logger)
    {
        _dbCentre = dbCentre;
        _logger = logger;
    }

    public async Task InitializeAsync()
    {
        try
        {
            _logger.LogInformation("Starting database initialization...");
            
            // Initialize database
            await InitializeDatabaseAsync();
            
            _logger.LogInformation("Database initialization completed successfully");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database initialization failed");
            throw;
        }
    }

    private async Task InitializeDatabaseAsync()
    {
        // Database initialization logic
    }
}
```

### 3. Service Implementation

```csharp
// ✅ Good - Implement IOEliteService for automatic discovery
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly IDistributedCache _distributedCache;
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        IProductRepository productRepository,
        IDistributedCache distributedCache,
        ILogger<ProductService> logger)
    {
        _productRepository = productRepository;
        _distributedCache = distributedCache;
        _logger = logger;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        // Service implementation
    }
}
```

## Troubleshooting

### Common Issues

1. **Service Not Registered**: Ensure the service implements `IOEliteService` and is in an included assembly
2. **Configuration Not Loaded**: Verify `configs/appsettings.init.json` exists and is properly formatted
3. **Bootstrap Failure**: Check bootstrap provider implementations for exceptions
4. **Authentication Issues**: Verify OeAppType detection and authentication configuration

### Debugging

```csharp
// Enable detailed logging for service discovery
builder.ConfigureOeWebApp<AppConfig>(
    dependencyInjectionOptions: options =>
    {
        options.EnableDebugLogging = true; // Log service discovery details
    }
);
```

## Compliance Checklist

### Required Patterns
- [ ] Use OElite.Common.Hosting.AspNetCore extensions for application startup
- [ ] Configuration classes inherit from BaseAppConfig and implement IAppConfig
- [ ] Services implement IOEliteService for automatic discovery
- [ ] Repositories inherit from DataRepository<T> for automatic registration
- [ ] Bootstrap providers implement IBootstrapProvider for initialization
- [ ] Use OeApp.RunWebAppAsync<T>() or OeApp.RunHybridAppAsync<T>() for startup

### Performance Requirements
- [ ] Service discovery configured with appropriate assembly filtering
- [ ] Bootstrap providers optimized for fast initialization
- [ ] Configuration validation implemented in IAppConfig
- [ ] Proper error handling in bootstrap providers

### Quality Standards
- [ ] Application configuration properly validated
- [ ] Bootstrap providers handle exceptions gracefully
- [ ] Service implementations follow OElite patterns
- [ ] Logging implemented throughout the application lifecycle

This guide ensures optimal usage of OElite.Common.Hosting while maintaining high performance and reliability across the OElite platform.
