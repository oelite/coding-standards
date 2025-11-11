# Dependency Injection & Service Patterns

## Overview

The OElite platform implements comprehensive dependency injection patterns using .NET's built-in DI container with standardized service interfaces, repository patterns, and lifecycle management. This document establishes the mandatory patterns for service registration, interface implementation, and dependency management across all OElite applications.

## Core Service Interface Standards

### 1. **IOEliteService Interface** (Mandatory)
All business services MUST implement the `IOEliteService` marker interface for consistent identification and registration.

```csharp
// ✅ Required interface implementation
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        IProductRepository productRepository,
        ICategoryRepository categoryRepository,
        ILogger<ProductService> logger)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;
        _logger = logger;
    }

    public async Task<Product> CreateProductAsync(CreateProductRequest request)
    {
        _logger.LogInformation("Creating product: {ProductName}", request.Name);

        var category = await _categoryRepository.GetByIdAsync(request.CategoryId);
        if (category == null)
            throw new NotFoundException($"Category {request.CategoryId} not found");

        var product = new Product
        {
            Name = request.Name,
            Price = request.Price,
            CategoryId = request.CategoryId
        };

        return await _productRepository.CreateAsync(product);
    }
}

// ❌ Wrong - Missing IOEliteService interface
public class ProductService
{
    // This will not be auto-registered
}
```

### 2. **Service Interface Patterns**
Define explicit interfaces for services that need to be abstracted or mocked for testing.

```csharp
// ✅ Good - Explicit service interface when needed
public interface IPaymentService : IOEliteService
{
    Task<PaymentResult> ProcessPaymentAsync(PaymentRequest request);
    Task<bool> RefundPaymentAsync(string paymentId, decimal amount);
}

public class PaymentService : IPaymentService
{
    private readonly IPaymentGateway _paymentGateway;
    private readonly IOrderRepository _orderRepository;

    public PaymentService(IPaymentGateway paymentGateway, IOrderRepository orderRepository)
    {
        _paymentGateway = paymentGateway;
        _orderRepository = orderRepository;
    }

    public async Task<PaymentResult> ProcessPaymentAsync(PaymentRequest request)
    {
        // Implementation
    }
}
```

## Repository Pattern Standards

### 1. **IDataRepository<T> Interface**
All repository interfaces MUST inherit from `IDataRepository<T>` for consistent data access patterns.

```csharp
// ✅ Required repository interface pattern
public interface IProductRepository : IDataRepository<Product>
{
    Task<List<Product>> GetProductsByCategoryAsync(string categoryId);
    Task<List<Product>> SearchProductsAsync(string searchTerm);
    Task<Product> GetProductWithInventoryAsync(string productId);
}

// ✅ Repository implementation
public class ProductRepository : DataRepository<Product>, IProductRepository
{
    public ProductRepository(DbCentre dbCentre) : base(dbCentre)
    {
    }

    public async Task<List<Product>> GetProductsByCategoryAsync(string categoryId)
    {
        return await GetAllAsync($"{{ 'categoryId': '{categoryId}' }}");
    }

    public async Task<List<Product>> SearchProductsAsync(string searchTerm)
    {
        var filter = new
        {
            name = new { @regex = searchTerm, options = "i" }
        };
        return await GetAllAsync(JsonSerializer.Serialize(filter));
    }

    public async Task<Product> GetProductWithInventoryAsync(string productId)
    {
        return await GetByIdAsync(productId, includeRelated: true);
    }
}
```

### 2. **DataRepository<T> Base Class Usage**
All concrete repositories MUST inherit from `DataRepository<T>` for consistent CRUD operations.

```csharp
// ✅ Good - Inherits from DataRepository<T>
public class OrderRepository : DataRepository<Order>, IOrderRepository
{
    public OrderRepository(DbCentre dbCentre) : base(dbCentre)
    {
    }

    // Leverage base class methods
    public async Task<Order> GetOrderAsync(string id)
    {
        return await GetByIdAsync(id); // From base class
    }

    // Custom query methods
    public async Task<List<Order>> GetOrdersByCustomerAsync(string customerId)
    {
        return await GetAllAsync($"{{ 'customerId': '{customerId}' }}");
    }

    // Complex aggregation queries
    public async Task<decimal> GetTotalSalesAsync(string customerId, DateTime fromDate)
    {
        var pipeline = new[]
        {
            new { @match = new { customerId, createdOnUtc = new { @gte = fromDate } } },
            new { @group = new { _id = (string)null, total = new { @sum = "$total" } } }
        };

        var result = await AggregateAsync<decimal>(pipeline);
        return result.FirstOrDefault();
    }
}

// ❌ Wrong - Not inheriting from DataRepository<T>
public class OrderRepository : IOrderRepository
{
    // Missing all base functionality, inconsistent patterns
}
```

## DbCentre Inheritance and Context Organization

### 1. **DbCentre Usage Pattern**
All repositories receive `DbCentre` as a constructor dependency for database context operations.

```csharp
// ✅ Required DbCentre usage pattern
public class CustomerRepository : DataRepository<Customer>, ICustomerRepository
{
    private readonly DbCentre _dbCentre;

    public CustomerRepository(DbCentre dbCentre) : base(dbCentre)
    {
        _dbCentre = dbCentre; // Store for custom operations
    }

    // Using DbCentre for custom database operations
    public async Task<bool> EmailExistsAsync(string email)
    {
        var count = await _dbCentre.CountAsync<Customer>($"{{ 'email': '{email}' }}");
        return count > 0;
    }

    // Complex operations using DbCentre directly
    public async Task<CustomerStatistics> GetCustomerStatisticsAsync(string customerId)
    {
        var customer = await GetByIdAsync(customerId);
        var orderCount = await _dbCentre.CountAsync<Order>($"{{ 'customerId': '{customerId}' }}");
        var totalSpent = await _dbCentre.AggregateAsync<decimal>("orders", new[]
        {
            new { @match = new { customerId } },
            new { @group = new { _id = (string)null, total = new { @sum = "$total" } } }
        });

        return new CustomerStatistics
        {
            Customer = customer,
            TotalOrders = (int)orderCount,
            TotalSpent = totalSpent.FirstOrDefault()
        };
    }
}
```

### 2. **DbCentre Context Partial Classes**
Use partial classes to organize DbCentre contexts by domain for maintainability.

```csharp
// ✅ Good - Partial class organization
// DbCentreContext.Products.cs
public partial class DbCentreContext
{
    // Product-related database operations
    public async Task<List<Product>> GetFeaturedProductsAsync()
    {
        return await GetAllAsync<Product>("{ 'isFeatured': true }");
    }

    public async Task<int> GetProductCountByCategoryAsync(string categoryId)
    {
        return await CountAsync<Product>($"{{ 'categoryId': '{categoryId}' }}");
    }
}

// DbCentreContext.Orders.cs
public partial class DbCentreContext
{
    // Order-related database operations
    public async Task<List<Order>> GetPendingOrdersAsync()
    {
        return await GetAllAsync<Order>("{ 'status': 1 }");
    }

    public async Task<decimal> GetDailySalesAsync(DateTime date)
    {
        var pipeline = new[]
        {
            new { @match = new {
                createdOnUtc = new {
                    @gte = date.Date,
                    @lt = date.Date.AddDays(1)
                }
            }},
            new { @group = new { _id = (string)null, total = new { @sum = "$total" } } }
        };

        var result = await AggregateAsync<decimal>("orders", pipeline);
        return result.FirstOrDefault();
    }
}
```

## Service Registration and Lifecycle Management

### 1. **Streamlined Application Startup** (MANDATORY)
Use OElite.Common.Hosting extensions for automatic service registration and configuration:

#### **Web Applications** (ASP.NET Core)
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        // ✅ REQUIRED - Use OElite.Common.Hosting.AspNetCore for web apps
        await OeApp.RunWebAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteApp",
            enableAuthentication: true,
            configureServices: builder =>
            {
                // Additional service configuration if needed
                builder.Services.AddCustomServices();
            },
            configureApp: async app =>
            {
                // Additional app configuration if needed
                app.UseCustomMiddleware();
            }
        );
    }
}
```

#### **Console Applications**
```csharp
using OElite.Common.Hosting.AspNetCore.Extensions;

public class Program
{
    public static async Task Main(string[] args)
    {
        // ✅ REQUIRED - Use OElite.Common.Hosting.AspNetCore for console apps
        await OeApp.RunHybridAppAsync<AppConfig>(
            args: args,
            applicationName: "MyOEliteConsoleApp",
            enableWebHosting: false, // Set to true for hybrid apps
            configureServices: builder =>
            {
                // Additional service configuration if needed
            }
        );
    }
}
```

#### **Manual Configuration** (Advanced Use Cases)
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
                options.IncludeAssemblies = new[] { "MyApp" };
                options.ExcludeNamespaces = new[] { "MyApp.Tests" };
            }
        );

        // Additional service configuration
        builder.Services.AddCustomServices();

        var app = builder.Build();

        // ✅ REQUIRED - Initialize OElite application
        await app.InitOeWebApp<AppConfig>();

        // Additional app configuration
        app.UseCustomMiddleware();

        await app.RunAsync();
    }
}
```

### 2. **What OElite.Common.Hosting Automatically Handles**

The hosting extensions automatically configure:

#### **Automatic Service Registration**
- ✅ **IOEliteService implementations** - All services implementing IOEliteService
- ✅ **Repository implementations** - All repositories inheriting from DataRepository<T>
- ✅ **Background services** - All services implementing IHostedService or inheriting from BackgroundService
- ✅ **Bootstrap providers** - All implementations of IBootstrapProvider
- ✅ **Interface registration** - All OElite interfaces implemented by services

#### **Automatic Configuration**
- ✅ **Configs-only pattern** - Loads configs/appsettings.init.json + environment overrides
- ✅ **Kortex configuration** - Runtime configuration fetching with fallback
- ✅ **OElite.Restme caching** - Redis when available, memory fallback
- ✅ **DbCentre registration** - App-specific database context
- ✅ **Path resolution** - OElitePathResolver integration
- ✅ **Logging** - Serilog configuration with file and console output

#### **Automatic Middleware Pipeline** (Web Apps)
- ✅ **Authentication/Authorization** - Based on OeAppType detection
- ✅ **CORS configuration** - Automatic CORS setup
- ✅ **API formatters** - OEliteApiInputFormatter and OEliteApiOutputFormatter
- ✅ **Swagger/OpenAPI** - Automatic API documentation
- ✅ **Response compression** - Gzip compression
- ✅ **Exception handling** - Standardized error handling

```csharp
// ✅ Manual registration for complex scenarios
builder.Services.AddScoped<IPaymentGateway>(serviceProvider =>
{
    var config = serviceProvider.GetRequiredService<AppConfig>();
    return config.PaymentProvider switch
    {
        "stripe" => new StripePaymentGateway(config.StripeApiKey),
        "paypal" => new PayPalPaymentGateway(config.PayPalClientId, config.PayPalSecret),
        _ => throw new InvalidOperationException($"Unknown payment provider: {config.PaymentProvider}")
    };
});

// ✅ Singleton registration for expensive resources
builder.Services.AddSingleton<AppConfig>();
builder.Services.AddSingleton<OElitePathResolver>();
builder.Services.AddSingleton<IHttpClientFactory>(serviceProvider =>
{
    var services = new ServiceCollection();
    services.AddHttpClient();
    return services.BuildServiceProvider().GetRequiredService<IHttpClientFactory>();
});
```

### 3. **OElite.Restme Integration** (MANDATORY)
All OElite services MUST use OElite.Restme for caching, queues, and storage operations. With OElite.Restme.Hosting, you can now use standard ASP.NET Core caching interfaces while leveraging OElite.Restme's advanced features underneath.

#### **Option A: Direct OElite.Restme Usage** (Advanced Features)
```csharp
// ✅ REQUIRED - Service using OElite.Restme directly
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly IRestme _restme; // OElite.Restme interface
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        IProductRepository productRepository,
        IRestme restme,
        ILogger<ProductService> logger)
    {
        _productRepository = productRepository;
        _restme = restme;
        _logger = logger;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";

        // ✅ Use FindmeAsync() for cache retrieval with grace period
        var cachedProduct = await _restme.FindmeAsync<Product>(cacheKey, 
            returnExpired: false, 
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));
        
        if (cachedProduct != null)
        {
            _logger.LogInformation("Product {ProductId} retrieved from cache", id);
            return cachedProduct;
        }

        // Database fallback
        var product = await _productRepository.GetByIdAsync(id);
        if (product != null)
        {
            // ✅ Use CachemeAsync() for caching data with grace period
            await _restme.CachemeAsync(cacheKey, product, 
                expiryInSeconds: 3600, // 1 hour
                graceInSeconds: 300);  // 5 minute grace period
            _logger.LogInformation("Product {ProductId} cached for 1 hour with 5min grace", id);
        }

        return product;
    }

    public async Task<Product> CreateProductAsync(CreateProductRequest request)
    {
        var product = new Product
        {
            Name = request.Name,
            Price = request.Price,
            CategoryId = request.CategoryId
        };

        var createdProduct = await _productRepository.CreateAsync(product);

        // ✅ Use QueuemeAsync() for background processing
        var productCreatedEvent = new ProductCreatedEvent
        {
            ProductId = createdProduct.Id,
            ProductName = createdProduct.Name,
            CreatedOnUtc = DateTime.UtcNow
        };
        await _restme.QueuemeAsync("product-created", productCreatedEvent);

        _logger.LogInformation("Product {ProductId} created and queued for processing", createdProduct.Id);
        return createdProduct;
    }
}
```

#### **Option B: Standard ASP.NET Core Caching** (Simplified Integration)
```csharp
// ✅ NEW - Service using standard IDistributedCache/IMemoryCache with OElite.Restme.Hosting
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly IDistributedCache _distributedCache; // OElite.Restme.Hosting adapter
    private readonly IMemoryCache _memoryCache;          // OElite.Restme.Hosting adapter
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        IProductRepository productRepository,
        IDistributedCache distributedCache,
        IMemoryCache memoryCache,
        ILogger<ProductService> logger)
    {
        _productRepository = productRepository;
        _distributedCache = distributedCache;
        _memoryCache = memoryCache;
        _logger = logger;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";

        // ✅ Use enhanced FindmeAsync() with grace period support
        var cachedProduct = await _distributedCache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));

        if (cachedProduct != null)
        {
            _logger.LogInformation("Product {ProductId} retrieved from distributed cache", id);
            return cachedProduct;
        }

        // Fallback to memory cache
        var memoryCachedProduct = await _memoryCache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));

        if (memoryCachedProduct != null)
        {
            _logger.LogInformation("Product {ProductId} retrieved from memory cache", id);
            return memoryCachedProduct;
        }

        // Database fallback
        var product = await _productRepository.GetByIdAsync(id);
        if (product != null)
        {
            // ✅ Cache in both distributed and memory cache
            await _distributedCache.CachemeAsync(cacheKey, product, 
                expiryInSeconds: 3600, graceInSeconds: 300);
            _memoryCache.CachemeAsync(cacheKey, product, 
                expiryInSeconds: 1800, graceInSeconds: 180);
            
            _logger.LogInformation("Product {ProductId} cached in both stores", id);
        }

        return product;
    }
}
```

#### **Service Registration for OElite.Restme.Hosting**
```csharp
// ✅ REQUIRED - Register OElite.Restme.Hosting adapters
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Option 1: Redis distributed cache with OElite.Restme
        builder.Services.AddRestmeRedisCache(options =>
        {
            options.ConnectionString = builder.Configuration["oelite:data:redis:platform"];
            options.InstanceName = "myapp:";
        });

        // Option 2: Memory cache with OElite.Restme (both IMemoryCache and IDistributedCache)
        builder.Services.AddRestmeMemoryCacheWithDistributed("myapp:");

        // Option 3: Memory cache only (IMemoryCache)
        // builder.Services.AddRestmeMemoryCache("myapp:");

        // Automatic registration of all IOEliteService implementations
        builder.Services.AddOEliteServices(typeof(Program).Assembly);

        var app = builder.Build();
        app.Run();
    }
}
```

### 4. **OElite.Restme Background Processing**
Use `DomeAsync()` for queue processing in background services:

```csharp
// ✅ Background service using OElite.Restme
public class ProductProcessingWorker : BackgroundService, IOEliteService
{
    private readonly IRestme _cacheRestme;
    private readonly IRestme _queueRestme;
    private readonly IProductService _productService;
    private readonly ILogger<ProductProcessingWorker> _logger;

    public ProductProcessingWorker(
        [FromKeyedServices("cache")] IRestme cacheRestme,
        [FromKeyedServices("queue")] IRestme queueRestme,
        IProductService productService,
        ILogger<ProductProcessingWorker> logger)
    {
        _cacheRestme = cacheRestme;
        _queueRestme = queueRestme;
        _productService = productService;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // ✅ Use DomeAsync() for queue processing
            await _queueRestme.DomeAsync<ProductCreatedEvent>("product-created", async productEvent =>
            {
                try
                {
                    _logger.LogInformation("Processing product created event for {ProductId}", productEvent.ProductId);

                    // Process the product event
                    await _productService.ProcessProductCreatedAsync(productEvent);

                    _logger.LogInformation("Successfully processed product {ProductId}", productEvent.ProductId);
                    return ProcessingResult.Success();
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to process product {ProductId}", productEvent.ProductId);
                    return ProcessingResult.Retry(ex.Message, retryAfter: TimeSpan.FromMinutes(5));
                }
            });

            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
        }
    }
}
```

### 5. **Service Lifetime Management**

#### **Scoped Lifetime** (Default for Business Services)
```csharp
// ✅ Scoped services (per HTTP request)
builder.Services.AddScoped<IOrderService, OrderService>();
builder.Services.AddScoped<IProductService, ProductService>();
builder.Services.AddScoped<ICustomerService, CustomerService>();

// Repositories are typically scoped
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
```

#### **Singleton Lifetime** (For Expensive Resources)
```csharp
// ✅ Singleton services (application lifetime)
builder.Services.AddSingleton<IMemoryCache, MemoryCache>();
builder.Services.AddSingleton<IConnectionMultiplexer>(serviceProvider =>
{
    var config = serviceProvider.GetRequiredService<AppConfig>();
    return ConnectionMultiplexer.Connect(config.RedisConnectionString);
});

// Configuration objects
builder.Services.AddSingleton<AppConfig>();
```

#### **Transient Lifetime** (For Lightweight Objects)
```csharp
// ✅ Transient services (new instance each time)
builder.Services.AddTransient<IEmailSender, EmailSender>();
builder.Services.AddTransient<IValidator<CreateProductRequest>, CreateProductRequestValidator>();
```

## Advanced Dependency Injection Patterns

### 1. **Factory Pattern Integration**
```csharp
// ✅ Factory pattern for creating related services
public interface INotificationServiceFactory
{
    INotificationService CreateNotificationService(NotificationType type);
}

public class NotificationServiceFactory : INotificationServiceFactory
{
    private readonly IServiceProvider _serviceProvider;

    public NotificationServiceFactory(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    public INotificationService CreateNotificationService(NotificationType type)
    {
        return type switch
        {
            NotificationType.Email => _serviceProvider.GetRequiredService<IEmailNotificationService>(),
            NotificationType.Sms => _serviceProvider.GetRequiredService<ISmsNotificationService>(),
            NotificationType.Push => _serviceProvider.GetRequiredService<IPushNotificationService>(),
            _ => throw new ArgumentException($"Unknown notification type: {type}")
        };
    }
}

// Registration
builder.Services.AddScoped<INotificationServiceFactory, NotificationServiceFactory>();
builder.Services.AddScoped<IEmailNotificationService, EmailNotificationService>();
builder.Services.AddScoped<ISmsNotificationService, SmsNotificationService>();
builder.Services.AddScoped<IPushNotificationService, PushNotificationService>();
```

### 2. **Decorator Pattern with DI**
```csharp
// ✅ Decorator pattern for cross-cutting concerns
public interface IOrderService : IOEliteService
{
    Task<Order> CreateOrderAsync(CreateOrderRequest request);
}

public class OrderService : IOrderService
{
    // Core implementation
}

public class CachedOrderService : IOrderService
{
    private readonly IOrderService _inner;
    private readonly IMemoryCache _cache;

    public CachedOrderService(IOrderService inner, IMemoryCache cache)
    {
        _inner = inner;
        _cache = cache;
    }

    public async Task<Order> CreateOrderAsync(CreateOrderRequest request)
    {
        // Add caching logic
        var cacheKey = $"order:{request.CustomerId}";
        if (_cache.TryGetValue(cacheKey, out Order cachedOrder))
            return cachedOrder;

        var order = await _inner.CreateOrderAsync(request);
        _cache.Set(cacheKey, order, TimeSpan.FromMinutes(5));
        return order;
    }
}

// Registration with decorator
builder.Services.AddScoped<OrderService>();
builder.Services.AddScoped<IOrderService>(serviceProvider =>
{
    var orderService = serviceProvider.GetRequiredService<OrderService>();
    var cache = serviceProvider.GetRequiredService<IMemoryCache>();
    return new CachedOrderService(orderService, cache);
});
```

### 3. **Conditional Service Registration**
```csharp
// ✅ Environment-based service registration
if (builder.Environment.IsDevelopment())
{
    builder.Services.AddScoped<IEmailSender, DevelopmentEmailSender>();
}
else
{
    builder.Services.AddScoped<IEmailSender, ProductionEmailSender>();
}

// ✅ Feature flag-based registration
var config = builder.Configuration.Get<AppConfig>();
if (config.Features.EnableAdvancedSearch)
{
    builder.Services.AddScoped<ISearchService, ElasticsearchService>();
}
else
{
    builder.Services.AddScoped<ISearchService, BasicSearchService>();
}
```

## Configuration Integration with DI

### 1. **Strongly-Typed Configuration Registration**
```csharp
// ✅ Configuration registration pattern
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Load configuration using configs-only pattern
        var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
        builder.Configuration
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("configs/appsettings.init.json", optional: false)
            .AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true)
            .AddEnvironmentVariables();

        // Register strongly-typed configuration
        var appConfig = new AppConfig();
        builder.Configuration.Bind(appConfig);
        builder.Services.AddSingleton(appConfig);

        // Register path resolver with configuration
        builder.Services.AddOElitePathResolver("kortex", appConfig.PathResolver);
    }
}
```

### 2. **Configuration-Dependent Service Registration**
```csharp
// ✅ Services that depend on configuration
builder.Services.AddScoped<IPaymentService>(serviceProvider =>
{
    var config = serviceProvider.GetRequiredService<AppConfig>();
    var logger = serviceProvider.GetRequiredService<ILogger<PaymentService>>();

    return new PaymentService(
        config.PaymentGatewayApiKey,
        config.PaymentGatewayUrl,
        logger
    );
});
```

## Testing and Mocking Patterns

### 1. **Service Unit Testing**
```csharp
// ✅ Unit test with proper mocking
[Test]
public async Task CreateProduct_ValidRequest_ReturnsCreatedProduct()
{
    // Arrange
    var mockProductRepo = new Mock<IProductRepository>();
    var mockCategoryRepo = new Mock<ICategoryRepository>();
    var mockLogger = new Mock<ILogger<ProductService>>();

    var category = new Category { Id = "cat123", Name = "Electronics" };
    mockCategoryRepo.Setup(r => r.GetByIdAsync("cat123")).ReturnsAsync(category);

    var service = new ProductService(mockProductRepo.Object, mockCategoryRepo.Object, mockLogger.Object);
    var request = new CreateProductRequest { Name = "Test Product", CategoryId = "cat123", Price = 99.99m };

    // Act
    var result = await service.CreateProductAsync(request);

    // Assert
    Assert.That(result, Is.Not.Null);
    Assert.That(result.Name, Is.EqualTo("Test Product"));
    mockProductRepo.Verify(r => r.CreateAsync(It.IsAny<Product>()), Times.Once);
}
```

### 2. **Integration Testing with DI**
```csharp
// ✅ Integration test with test container
public class ProductServiceIntegrationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public ProductServiceIntegrationTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Test]
    public async Task CreateProduct_EndToEnd_WorksCorrectly()
    {
        // Arrange
        using var scope = _factory.Services.CreateScope();
        var productService = scope.ServiceProvider.GetRequiredService<ProductService>();
        var categoryService = scope.ServiceProvider.GetRequiredService<CategoryService>();

        var category = await categoryService.CreateCategoryAsync(new CreateCategoryRequest { Name = "Test Category" });
        var request = new CreateProductRequest { Name = "Test Product", CategoryId = category.Id, Price = 99.99m };

        // Act
        var result = await productService.CreateProductAsync(request);

        // Assert
        Assert.That(result, Is.Not.Null);
        Assert.That(result.Name, Is.EqualTo("Test Product"));
        Assert.That(result.CategoryId, Is.EqualTo(category.Id));
    }
}
```

## Error Handling in DI Context

### 1. **Service-Level Exception Handling**
```csharp
// ✅ Consistent exception handling in services
public class OrderService : IOEliteService
{
    private readonly IOrderRepository _orderRepository;
    private readonly ILogger<OrderService> _logger;

    public async Task<Order> GetOrderAsync(string orderId)
    {
        try
        {
            _logger.LogInformation("Retrieving order {OrderId}", orderId);

            var order = await _orderRepository.GetByIdAsync(orderId);
            if (order == null)
            {
                _logger.LogWarning("Order {OrderId} not found", orderId);
                throw new NotFoundException($"Order {orderId} not found");
            }

            return order;
        }
        catch (Exception ex) when (!(ex is NotFoundException))
        {
            _logger.LogError(ex, "Error retrieving order {OrderId}", orderId);
            throw new ServiceException($"Failed to retrieve order {orderId}", ex);
        }
    }
}
```

### 2. **Repository-Level Exception Handling**
```csharp
// ✅ Repository exception handling
public class ProductRepository : DataRepository<Product>, IProductRepository
{
    private readonly ILogger<ProductRepository> _logger;

    public ProductRepository(DbCentre dbCentre, ILogger<ProductRepository> logger) : base(dbCentre)
    {
        _logger = logger;
    }

    public async Task<Product> CreateAsync(Product product)
    {
        try
        {
            _logger.LogInformation("Creating product {ProductName}", product.Name);
            return await base.CreateAsync(product);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create product {ProductName}", product.Name);
            throw new RepositoryException("Failed to create product", ex);
        }
    }
}
```

## Performance Considerations

### 1. **Lazy Loading with DI**
```csharp
// ✅ Lazy loading for expensive services
public class ReportService : IOEliteService
{
    private readonly Lazy<IExpensiveService> _expensiveService;

    public ReportService(Lazy<IExpensiveService> expensiveService)
    {
        _expensiveService = expensiveService;
    }

    public async Task<Report> GenerateReportAsync()
    {
        // Only creates the expensive service when actually needed
        var service = _expensiveService.Value;
        return await service.GenerateReportAsync();
    }
}

// Registration
builder.Services.AddScoped<IExpensiveService, ExpensiveService>();
builder.Services.AddScoped<Lazy<IExpensiveService>>(serviceProvider =>
    new Lazy<IExpensiveService>(() => serviceProvider.GetRequiredService<IExpensiveService>()));
```

### 2. **Connection Pooling and Resource Management**
```csharp
// ✅ Proper resource management with DI
public class DatabaseService : IOEliteService, IDisposable
{
    private readonly IDbConnection _connection;
    private bool _disposed = false;

    public DatabaseService(IDbConnection connection)
    {
        _connection = connection;
    }

    public async Task<List<T>> QueryAsync<T>(string sql)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(DatabaseService));
        return await _connection.QueryAsync<T>(sql);
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _connection?.Dispose();
            _disposed = true;
        }
    }
}
```

## Compliance Checklist

### Required Patterns
- [ ] All services implement `IOEliteService` interface
- [ ] All repositories inherit from `DataRepository<T>` and implement `IDataRepository<T>`
- [ ] All repositories receive `DbCentre` as constructor dependency
- [ ] **NEW**: Applications use OElite.Common.Hosting.AspNetCore extensions (OeApp.RunWebAppAsync, OeApp.RunHybridAppAsync)
- [ ] **NEW**: Configuration classes inherit from `BaseAppConfig` and implement `IAppConfig`
- [ ] **NEW**: Bootstrap providers implement `IBootstrapProvider` for initialization logic
- [ ] Proper service lifetime management (Scoped/Singleton/Transient)
- [ ] Exception handling follows OElite patterns
- [ ] Logging is injected and used appropriately
- [ ] Unit tests mock all dependencies properly
- [ ] **NEW**: Caching uses OElite.Restme.Hosting adapters (IDistributedCache/IMemoryCache) OR direct IRestme
- [ ] **NEW**: Service registration includes OElite.Restme.Hosting extensions (AddRestmeRedisCache, AddRestmeMemoryCache, etc.)

### Performance Requirements
- [ ] Expensive services use lazy loading where appropriate
- [ ] Singleton services are thread-safe
- [ ] Database connections are properly pooled
- [ ] **NEW**: Grace period caching is implemented for critical data (returnInGrace: true)
- [ ] **NEW**: Background refresh actions are configured for stale data (refreshAction)
- [ ] **NEW**: Multi-tier caching strategy (distributed + memory) where appropriate
- [ ] Async/await patterns are used consistently

### Quality Standards
- [ ] No service locator anti-pattern usage
- [ ] Dependencies are injected through constructors only
- [ ] Services have single responsibility
- [ ] Repository methods are specific and focused
- [ ] Configuration is strongly-typed and validated
- [ ] Error handling is comprehensive and consistent
- [ ] **NEW**: Caching implementations use OElite.Restme.Hosting adapters for consistency
- [ ] **NEW**: Grace period and background refresh patterns are properly implemented

This dependency injection framework ensures consistent, testable, and maintainable service architecture across the entire OElite platform.