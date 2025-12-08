# Project Architecture & Layered Design Standards

## Overview

The OElite platform follows a comprehensive **N-tier architecture** pattern with strict separation of concerns, domain-driven design principles, and enterprise-grade scalability patterns. This document establishes the foundational architectural standards that all OElite applications must follow.

## Functional Requirements-Driven Development Flow

### **MANDATORY: Requirements-First Development Process**

Before writing any code, **ALL** OElite developers must follow this functional requirements-driven flow:

#### **3.1 UI Operations Analysis**
- Start with functional requirements document
- Identify **what UI level operations** users actually need to perform
- Map user journeys and interaction patterns
- Define success criteria for each operation

#### **3.2 API Endpoints Design**
- Based on UI operations, determine **what API endpoints** are required
- Design RESTful contracts that support the identified UI operations
- Ensure endpoints are stateless and follow HTTP conventions
- Define request/response models for each endpoint

#### **3.3 Data Entity Design**
- Based on API contracts, identify **what data entities** need persistence
- Create entity classes inheriting from `BaseEntity`
- Design proper database schema with appropriate attributes:
  - `[DbCollection("collectionName")]` - Collection/table name
  - `[DbField("fieldName")]` - Field mapping
  - `[DbIndex]` - Database indexes for performance
  - `[DbShardKey]` - Sharding keys for scalability
  - `[DenormalizedField]` - Denormalized field references
  - `[DenormalizedCollection]` - Denormalized collection references
- Analyze normalization vs denormalization needs
- Create required DTOs/Models and ModelTransformers

#### **3.4 Functional Methods Implementation**
- Based on API endpoints, implement **functional methods with correct logic**
- Create data repositories for persistence needs
- Implement business logic in service layer
- Ensure methods directly support the defined API contracts

#### **3.5 Data Repository Standards**
- **MANDATORY**: Create generic CRUD operations only
- **AVOID**: Business logic in repositories (data-level logic acceptable but avoid complex business rules)
- **STANDARD**: Use the following naming convention:

```csharp
// ✅ REQUIRED CRUD Naming Convention
public interface IEntityRepository : IDataRepository<OrionDbCentre>
{
    // Core CRUD Operations
    Task<Entity?> GetEntityAsync(EntityQuery query);
    Task<EntityCollection> GetEntitiesAsync(EntityQuery query);
    Task<Entity> UpdateEntityAsync(Entity entity);
    Task<bool> DeleteEntityAsync(EntityQuery query);
}
```

#### **3.6 Repository CRUD Implementation**
**MANDATORY**: All repositories must implement at least these 4 core CRUD methods:

```csharp
// ✅ Example: ApiClientRepository CRUD Implementation
public class ApiClientRepository : OrionDbRepository, IApiClientRepository
{
    // Get single entity
    public async Task<OrionApiClient?> GetApiClientAsync(ApiClientQuery query)
    {
        // Implementation using query filters
    }

    // Get multiple entities with pagination/filtering
    public async Task<OrionApiClientCollection> GetApiClientsAsync(ApiClientQuery query)
    {
        // Implementation with proper FetchAsync usage
    }

    // Update entity
    public async Task<OrionApiClient> UpdateApiClientAsync(OrionApiClient apiClient)
    {
        // Implementation
    }

    // Delete entities
    public async Task<bool> DeleteApiClientAsync(ApiClientQuery query)
    {
        // Implementation
    }
}
```

### **Repository Design Rules**

#### **✅ ALLOWED in Repositories:**
- Basic data filtering and querying
- Pagination and sorting
- Simple aggregations (counts, sums)
- Data validation (null checks, basic constraints)
- Database-specific optimizations

#### **❌ FORBIDDEN in Repositories:**
- Complex business logic
- Cross-entity business rules
- External API calls
- Email sending or notifications
- File system operations
- Complex calculations or algorithms

#### **Collection Type Standards**
**MANDATORY**: Use proper entity collection types instead of generic collections:

```csharp
// ✅ CORRECT
public async Task<OrionApiClientCollection> GetApiClientsAsync(ApiClientQuery query)
{
    return await query.FetchAsync<OrionApiClient, OrionApiClientCollection>();
}

// ❌ WRONG
public async Task<List<OrionApiClient>> GetApiClientsAsync(ApiClientQuery query)
{
    return await query.ToListAsync();
}
```

## N-Tier Architecture Pattern

### Core Architectural Layers

#### 1. **Domain Layer** (Pure Business Logic)
**Purpose**: Contains pure business entities, domain logic, and business rules
**Location**: `OElite.Common` namespace - Domain entities and DTOs
**Characteristics**:
- No dependencies on external frameworks
- Contains business rules and domain logic
- Implements domain events and aggregates
- Validates business invariants

```csharp
// ✅ Good - Pure domain entity
[DbCollection("products")]
public class Product : BaseEntity
{
    [DbField("name")]
    public string Name { get; set; }

    [DbField("price")]
    public decimal Price { get; set; }

    // Business logic method
    public bool IsAvailableForPurchase()
    {
        return IsActive && Stock > 0 && Price > 0;
    }
}
```

#### 2. **Data Access Layer** (Repository Pattern)
**Purpose**: Handles all database operations and data persistence
**Location**: `OElite.Data.Repositories` namespace
**Characteristics**:
- **MANDATORY**: Implements standardized CRUD operations only
- **MANDATORY**: Inherits from `OrionDbRepository` base class
- **MANDATORY**: Uses `DbCentre` for database context operations
- **MANDATORY**: Returns proper entity collection types
- **FORBIDDEN**: Business logic (keep repositories data-focused only)

```csharp
// ✅ REQUIRED - Repository CRUD Implementation
public class ApiClientRepository : OrionDbRepository, IApiClientRepository
{
    // Core CRUD Operations - MANDATORY
    public async Task<OrionApiClient?> GetApiClientAsync(ApiClientQuery query)
    {
        // Single entity retrieval with filtering
        var mongoQuery = DbCentre.ApiClients;
        // Apply query filters...
        return await mongoQuery.FetchAsync();
    }

    public async Task<OrionApiClientCollection> GetApiClientsAsync(ApiClientQuery query)
    {
        // Multiple entities with pagination/filtering
        var mongoQuery = DbCentre.ApiClients;
        // Apply query filters...
        return await mongoQuery.FetchAsync<OrionApiClient, OrionApiClientCollection>();
    }

    public async Task<OrionApiClient> UpdateApiClientAsync(OrionApiClient apiClient)
    {
        // Entity update
        apiClient.UpdatedOnUtc = DateTime.UtcNow;
        await DbCentre.ApiClients.ReplaceAsync(apiClient);
        return apiClient;
    }

    public async Task<bool> DeleteApiClientAsync(ApiClientQuery query)
    {
        // Entity deletion with filtering
        var mongoQuery = DbCentre.ApiClients;
        // Apply query filters...
        var result = await mongoQuery.DeleteAsync();
        return result.DeletedCount > 0;
    }
}
```

#### 3. **Service Layer** (Business Logic Orchestration)
**Purpose**: Orchestrates business operations and coordinates between repositories
**Location**: `OElite.Services` namespace
**Characteristics**:
- Implements `IOEliteService` interface
- Handles complex business workflows
- Manages transactions and data consistency
- Implements cascade updates and denormalized field refreshing

```csharp
// ✅ Good - Service layer implementation
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;

    public ProductService(IProductRepository productRepository, ICategoryRepository categoryRepository)
    {
        _productRepository = productRepository;
        _categoryRepository = categoryRepository;
    }

    public async Task<Product> CreateProductAsync(CreateProductRequest request)
    {
        // Business logic orchestration
        var category = await _categoryRepository.GetByIdAsync(request.CategoryId);
        if (category == null) throw new BusinessException("Category not found");

        var product = new Product
        {
            Name = request.Name,
            Price = request.Price,
            CategoryId = request.CategoryId
        };

        return await _productRepository.CreateAsync(product);
    }
}
```

#### 4. **API Layer** (Controllers and Endpoints)
**Purpose**: Handles HTTP requests and response formatting
**Location**: `OElite.Servers.Nexus` controllers
**Characteristics**:
- Thin controllers with minimal logic
- Uses `OEliteApiOutputFormatter` for consistent responses
- Implements proper HTTP status codes
- Handles authentication and authorization

```csharp
// ✅ Good - Thin controller
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ProductService _productService;

    public ProductsController(ProductService productService)
    {
        _productService = productService;
    }

    [HttpPost]
    [TransformedResponse(typeof(Product), 201)]
    public async Task<Product> CreateProduct(CreateProductRequest request)
    {
        var product = await _productService.CreateProductAsync(request);
        // OEliteApiOutputFormatter handles CreatedAtAction routing and response wrapping
        return product;
    }
}
```

## Project Structure Organization

### Core Libraries Structure (Domain-Based Organization)

The OElite platform uses a **domain-based folder structure** where each business domain contains all related components for easier management and maintainability:

```
OElite.Common/
├── Customers/                 # Customer domain
│   ├── Models/                # Customer models
│   │   ├── {{model}}.cs       # Customer models
│   │   ├── Requests/          # Customer API request models
│   │   ├── Responses/         # Customer API response models
│   ├── ModelTransformers/     # Customer mmodel transformers
│   ├── Reports/               # Customer reporting DTOs
│   └── {{entity}}.cs          # Customer entities (BaseEntity classes) 
├── Products/                  # Product domain
│   ├── Models/                # Customer models
│   │   ├── {{model}}.cs       # Customer models
│   │   ├── Requests/          # Customer API request models
│   │   ├── Responses/         # Customer API response models
│   ├── ModelTransformers/     # Customer mmodel transformers
│   ├── Reports/               # Customer reporting DTOs
│   └── {{entity}}.cs          # Customer entities (BaseEntity classes) 
├── Orders/                    # Order domain
│   ├── Models/                # Customer models
│   │   ├── {{model}}.cs       # Customer models
│   │   ├── Requests/          # Customer API request models
│   │   ├── Responses/         # Customer API response models
│   ├── ModelTransformers/     # Customer mmodel transformers
│   ├── Reports/               # Customer reporting DTOs
│   └── {{entity}}.cs          # Customer entities (BaseEntity classes) 
├── Payments/                  # Payment domain
│   ├── Models/                # Customer models
│   │   ├── {{model}}.cs       # Customer models
│   │   ├── Requests/          # Customer API request models
│   │   ├── Responses/         # Customer API response models
│   ├── ModelTransformers/     # Customer mmodel transformers
│   ├── Reports/               # Customer reporting DTOs
│   └── {{entity}}.cs          # Customer entities (BaseEntity classes) 
├── Domain/                    # Core domain entities and shared components
│   ├── Models/                # Customer models
│   │   ├── {{model}}.cs       # Customer models
│   │   ├── Requests/          # Customer API request models
│   │   ├── Responses/         # Customer API response models
│   ├── ModelTransformers/     # Customer mmodel transformers
│   ├── Reports/               # Customer reporting DTOs
│   └── {{entity}}.cs          # Customer entities (BaseEntity classes) 
└── Infrastructure/            # Cross-cutting concerns (path resolution, etc.)

OElite.Data.Repositories/
├── Customers/                 # Customer data access
│   ├── DbCentre.cs            # Partial class for DbCentre context with domain based db collections
│   ├── CustomerRepository.cs
│   └── CustomerAddressRepository.cs
├── Products/                  # Product data access
│   ├── DbCentre.cs            # Partial class for DbCentre context with domain based db collections
│   ├── ProductCategoryRepository.cs
│   └── ProductRepository.cs
├── Orders/                    # Order data access
│   ├── DbCentre.cs            # Partial class for DbCentre context with domain based db collections
│   ├── OrderItemRepository.cs
│   └── OrderRepository.cs
├── Payments/                  # Payment data access
│   ├── DbCentre.cs            # Partial class for DbCentre context with domain based db collections
│   └── PaymentRepository.cs
├── Base/                      # Base repository classes (DataRepository<T>)
├── Context/                   # DbCentre context classes
└── Shared/                    # Shared query implementations

OElite.Services/
├── Customers/                 # Customer business logic
│   ├── CustomerService.cs
│   ├── CustomerProfileService.cs
│   └── CustomerNotificationService.cs
├── Products/                  # Product business logic
│   ├── ProductService.cs
│   ├── ProductCatalogService.cs
│   └── ProductInventoryService.cs
├── Orders/                    # Order business logic
│   ├── OrderService.cs
│   ├── OrderProcessingService.cs
│   └── OrderFulfillmentService.cs
├── Payments/                  # Payment business logic
│   ├── PaymentService.cs
│   └── PaymentProcessingService.cs
├── Base/                      # Base service classes
├── Integration/               # External service integrations
└── Background/                # Background processing services
```

### Application Server Structure

```
OElite.Servers.{ServerName}/
├── Controllers/               # API controllers (thin layer)
├── Middleware/               # Custom middleware
├── configs/                  # Configuration files (NEW STANDARD)
│   ├── appsettings.init.json # Base configuration
│   └── .dev/                 # Environment-specific overrides
│       ├── Development/
│       ├── Production/
│       └── Staging/
├── Program.cs                # Application entry point
├── k8s                      # k8s manifest/deployment files
└── Dockerfile               # Container configuration
```

## Separation of Concerns Principles

### 1. **Single Responsibility Principle**
Each class should have only one reason to change.

```csharp
// ❌ Bad - Multiple responsibilities
public class ProductService
{
    public Product CreateProduct(string name) { }
    public void SendEmailNotification(Product product) { }  // Email responsibility
    public void LogActivity(string message) { }             // Logging responsibility
}

// ✅ Good - Single responsibility
public class ProductService: IOEliteService
{
    private readonly IEmailService _emailService;
    private readonly ILogger<ProductService> _logger;

    public Product CreateProduct(string name)
    {
        var product = new Product { Name = name };
        _emailService.SendProductCreatedNotification(product);
        _logger.LogInformation("Product created: {ProductId}", product.Id);
        return product;
    }
}
```

### 2. **Dependency Inversion Principle**
High-level modules should not depend on low-level modules. Both should depend on abstractions.

```csharp
// ✅ Good - Depends on abstraction
public class OrderService : IOEliteService
{
    private readonly IOrderRepository _orderRepository;    // Abstraction
    private readonly IPaymentService _paymentService;      // Abstraction

    public OrderService(IOrderRepository orderRepository, IPaymentService paymentService)
    {
        _orderRepository = orderRepository;
        _paymentService = paymentService;
    }
}
```

### 3. **Interface Segregation**
Clients should not be forced to depend on interfaces they don't use.

```csharp
// ❌ Bad - Fat interface
public interface IProductService
{
    Task<Product> GetProductAsync(string id);
    Task<Product> CreateProductAsync(CreateProductRequest request);
    Task<byte[]> ExportProductsToExcelAsync();           // Different concern
    Task<ProductAnalytics> GetProductAnalyticsAsync();   // Different concern
}

// ✅ Good - Segregated interfaces
public interface IProductService
{
    Task<Product> GetProductAsync(string id);
    Task<Product> CreateProductAsync(CreateProductRequest request);
}

public interface IProductExportService
{
    Task<byte[]> ExportProductsToExcelAsync();
}

public interface IProductAnalyticsService
{
    Task<ProductAnalytics> GetProductAnalyticsAsync();
}
```

## Domain-Driven Design Principles

### 1. **Ubiquitous Language**
Use the same language across code, documentation, and business conversations.

```csharp
// ✅ Good - Business language
public class ShoppingCart
{
    public void AddItem(Product product, int quantity) { }
    public void RemoveItem(string productId) { }
    public decimal CalculateTotal() { }
    public void ApplyCoupon(Coupon coupon) { }
}

// ❌ Bad - Technical language
public class CartData
{
    public void InsertRecord(ProductEntity entity, int count) { }
    public void DeleteRecord(string id) { }
}
```

### 2. **Bounded Contexts**
Each microservice or module should have clearly defined boundaries.

```
Contexts:
├── Catalog Context             # Product management
│   ├── Product
│   ├── Category
│   └── Brand
├── Order Context              # Order processing
│   ├── Order
│   ├── OrderItem
│   └── Payment
├── Customer Context           # Customer management
│   ├── Customer
│   ├── Address
│   └── CustomerProfile
└── Inventory Context          # Stock management
    ├── Stock
    ├── Warehouse
    └── StockMovement
```

### 3. **Aggregates and Aggregate Roots**
Group related entities under a single aggregate root for consistency.

```csharp
// ✅ Good - Order as aggregate root
public class Order : BaseEntity  // Aggregate Root
{
    private List<OrderItem> _items = new();
    public IReadOnlyList<OrderItem> Items => _items.AsReadOnly();

    // Business methods that maintain invariants
    public void AddItem(Product product, int quantity)
    {
        if (quantity <= 0) throw new BusinessException("Quantity must be positive");

        var existingItem = _items.FirstOrDefault(i => i.ProductId == product.Id);
        if (existingItem != null)
        {
            existingItem.UpdateQuantity(existingItem.Quantity + quantity);
        }
        else
        {
            _items.Add(new OrderItem(product.Id, quantity, product.Price));
        }

        RecalculateTotal();
    }

    private void RecalculateTotal()
    {
        Total = _items.Sum(i => i.Subtotal);
    }
}

public class OrderItem  // Part of Order aggregate
{
    public string ProductId { get; private set; }
    public int Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal Subtotal => Quantity * UnitPrice;

    internal void UpdateQuantity(int newQuantity)
    {
        if (newQuantity <= 0) throw new BusinessException("Quantity must be positive");
        Quantity = newQuantity;
    }
}
```

## Configuration Architecture (Configs-Only Pattern)

### Required Configuration Structure
All OElite applications MUST follow the configs-only pattern:

```
Application/
├── configs/
│   ├── appsettings.init.json          # Base configuration (required)
│   └── .dev/                          # Environment-specific overrides
│       ├── Development/
│       │   └── appsettings.init.json  # Development overrides
│       ├── Production/
│       │   └── appsettings.init.json  # Production overrides
│       └── Staging/
│           └── appsettings.init.json  # Staging overrides
└── Program.cs                         # Configuration loading
```

### Configuration Loading Pattern
```csharp
// ✅ Required pattern in Program.cs (Only needed if not using OElite application lifecycle hosting extensions)
var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("configs/appsettings.init.json", optional: false)  // Base (required)
    .AddJsonFile($"configs/.dev/{environment}/appsettings.init.json", optional: true)  // Override
    .AddEnvironmentVariables();  // Final override
```

### Strongly-Typed Configuration
```csharp
// ✅ Good - Inherits from BaseAppConfig for path resolution
public class KortexAppConfig : BaseAppConfig
{
    public KortexAppConfig(string jsonConfig, ILogger logger, IOElitePathResolver? pathResolver = null) : base(
        OeAppType.Kortex,
        jsonConfig, logger, "kortex", pathResolver)
    {
        PopulateKortexSettings();        
    }

    // Strongly-typed configuration properties
    public DnsConfiguration Dns { get; set; } = new();
    public ProxyConfiguration Proxy { get; set; } = new();
    public SecurityConfiguration Security { get; set; } = new();

    // Path resolution integration
    public string ResolvedGeoLocationDatabasePath => GetResolvedPath(OElitePathType.Data, "GeoLite2-City.mmdb");
    public string ResolvedCdnCachePath => GetResolvedPath(OElitePathType.Cache, "cdn");
}
```

## Microservices Architecture Patterns

### Service Communication
```csharp
// ✅ Good - Async communication via events
public class OrderService : IOEliteService
{
    private readonly IEventBus _eventBus;

    public async Task CompleteOrderAsync(string orderId)
    {
        var order = await _orderRepository.GetByIdAsync(orderId);
        order.MarkAsCompleted();
        await _orderRepository.UpdateAsync(order);

        // Publish event for other services
        await _eventBus.PublishAsync(new OrderCompletedEvent(orderId, order.CustomerId));
    }
}
```

### Service Discovery and Health Checks
```csharp
// ✅ Good - Health check implementation
public class DatabaseHealthCheck : IHealthCheck
{
    private readonly DbCentre _dbCentre;

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await _dbCentre.TestConnectionAsync();
            return HealthCheckResult.Healthy("Database connection is healthy");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Database connection failed", ex);
        }
    }
}
```

## Performance and Scalability Patterns

### 1. **Caching Strategy**
OElite applications now natively support `IMemoryCache` and `IDistributedCache` for caching operations. The `OElite.Restme.Hosting` package automatically injects the necessary implementations during the application's lifecycle, allowing for direct use of these standard .NET caching interfaces.

For memory caching, inject `IMemoryCache`. For distributed caching (e.g., Redis), inject `IDistributedCache`.

```csharp
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json; // Required for serializing/deserializing objects for IDistributedCache

// ✅ RECOMMENDED - Direct IMemoryCache/IDistributedCache usage
public class ProductService : IOEliteService
{
    private readonly IProductRepository _repository; // Assuming this is already present or needed
    private readonly IMemoryCache _memoryCache;
    private readonly IDistributedCache _distributedCache;
    private readonly IRestme _restme; // For non-caching Restme helper methods

    public ProductService(IProductRepository repository, IMemoryCache memoryCache, IDistributedCache distributedCache, IRestme restme)
    {
        _repository = repository;
        _memoryCache = memoryCache;
        _distributedCache = distributedCache;
        _restme = restme;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";

        // ✅ Use IMemoryCache for local caching
        if (_memoryCache.TryGetValue(cacheKey, out Product cachedProduct))
        {
            return cachedProduct;
        }

        // ✅ Use IDistributedCache for distributed caching (example)
        var distributedCachedProductBytes = await _distributedCache.GetAsync(cacheKey);
        if (distributedCachedProductBytes != null)
        {
            var distributedCachedProduct = JsonSerializer.Deserialize<Product>(distributedCachedProductBytes);
            _memoryCache.Set(cacheKey, distributedCachedProduct, TimeSpan.FromMinutes(5)); // Cache in memory after fetching from distributed
            return distributedCachedProduct;
        }

        // Database fallback
        var dbProduct = await _repository.GetByIdAsync(id);
        if (dbProduct != null)
        {
            // Cache in IMemoryCache
            _memoryCache.Set(cacheKey, dbProduct, TimeSpan.FromMinutes(10));

            // Cache in IDistributedCache
            var productBytes = JsonSerializer.SerializeToUtf8Bytes(dbProduct);
            await _distributedCache.SetAsync(cacheKey, productBytes, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
            });
        }

        return dbProduct;
    }

    public async Task<Product> CreateProductAsync(CreateProductRequest request)
    {
        var product = new Product
        {
            Name = request.Name,
            Price = request.Price,
            CategoryId = request.CategoryId
        };

        var createdProduct = await _repository.CreateAsync(product);

        // ✅ Cache the newly created product in IMemoryCache
        _memoryCache.Set($"product:{createdProduct.Id}", createdProduct, TimeSpan.FromMinutes(10));

        // ✅ Cache the newly created product in IDistributedCache
        var productBytes = JsonSerializer.SerializeToUtf8Bytes(createdProduct);
        await _distributedCache.SetAsync($"product:{createdProduct.Id}", productBytes, new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
        });

        // ✅ Use QueuemeAsync() for background processing (non-caching Restme helper)
        var productCreatedEvent = new ProductCreatedEvent
        {
            ProductId = createdProduct.Id,
            ProductName = createdProduct.Name,
            CreatedOnUtc = DateTime.UtcNow
        };
        await _restme.QueuemeAsync("product-created", productCreatedEvent);

        return createdProduct;
    }
}
```

### 2. **OElite.Restme Queue Processing Pattern**
Use standardized queue processing with `QueuemeAsync()` and `DomeAsync()`:

```csharp
// ✅ REQUIRED - OElite.Restme queue pattern
public class OrderProcessingService : IOEliteService
{
    private readonly IOrderRepository _orderRepository;
    private readonly IRestme _restme;

    public async Task ProcessOrderAsync(CreateOrderRequest request)
    {
        var order = new Order
        {
            CustomerId = request.CustomerId,
            Items = request.Items,
            Total = request.Total
        };

        var createdOrder = await _orderRepository.CreateAsync(order);

        // ✅ Queue order processing tasks
        var orderProcessingTask = new OrderProcessingTask
        {
            OrderId = createdOrder.Id,
            ProcessingType = "payment-processing"
        };
        await _restme.QueuemeAsync("order-processing", orderProcessingTask);

        // ✅ Queue inventory update
        var inventoryUpdateTask = new InventoryUpdateTask
        {
            OrderId = createdOrder.Id,
            Items = createdOrder.Items
        };
        await _restme.QueuemeAsync("inventory-update", inventoryUpdateTask);

        return createdOrder;
    }
}

// ✅ Queue processing worker using DomeAsync()
public class OrderProcessingWorker : BackgroundService
{
    private readonly IRestme _restme;
    private readonly IPaymentService _paymentService;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // ✅ Use DomeAsync() for queue processing
            await _restme.DomeAsync<OrderProcessingTask>("order-processing", async task =>
            {
                try
                {
                    await _paymentService.ProcessPaymentAsync(task.OrderId);

                    // Mark task as completed
                    return ProcessingResult.Success();
                }
                catch (Exception ex)
                {
                    // Return failure with retry logic
                    return ProcessingResult.Retry(ex.Message, retryAfter: TimeSpan.FromMinutes(5));
                }
            });

            await Task.Delay(TimeSpan.FromSeconds(10), stoppingToken);
        }
    }
}
```

### 3. **OElite.Restme Performance Patterns**
Use appropriate caching strategies based on data characteristics and understand which Rest provider you're using:

```csharp
// ✅ Cache-aware service implementation
public class ProductService : IOEliteService
{
    private readonly IProductRepository _repository;
    private readonly IRestme _restme; // Be aware of which provider is configured

    public ProductService(IProductRepository repository, IRestme restme)
    {
        _repository = repository;
        _restme = restme;
    }

    public async Task<List<Product>> GetFeaturedProductsAsync()
    {
        var cacheKey = "featured-products";

        // ✅ Check cache first with FindmeAsync()
        var cachedProducts = await _restme.FindmeAsync<List<Product>>(cacheKey);
        if (cachedProducts != null)
            return cachedProducts;

        // Database query
        var products = await _repository.GetFeaturedProductsAsync();

        // ✅ Cache with appropriate expiration based on data volatility
        // Featured products change infrequently - longer cache time
        await _restme.CachemeAsync(cacheKey, products, TimeSpan.FromHours(6));

        return products;
    }

    public async Task<Product> GetProductWithRealtimeInventoryAsync(string productId)
    {
        var productCacheKey = $"product:{productId}";
        var inventoryCacheKey = $"inventory:{productId}";

        // ✅ Cache product data (changes infrequently)
        var product = await _restme.FindmeAsync<Product>(productCacheKey);
        if (product == null)
        {
            product = await _repository.GetByIdAsync(productId);
            if (product != null)
            {
                // Cache product for longer duration
                await _restme.CachemeAsync(productCacheKey, product, TimeSpan.FromHours(2));
            }
        }

        // ✅ Cache inventory data (changes frequently) - shorter duration
        var inventory = await _restme.FindmeAsync<ProductInventory>(inventoryCacheKey);
        if (inventory == null)
        {
            inventory = await _repository.GetProductInventoryAsync(productId);
            if (inventory != null)
            {
                // Cache inventory for shorter duration due to frequent updates
                await _restme.CachemeAsync(inventoryCacheKey, inventory, TimeSpan.FromMinutes(5));
            }
        }

        if (product != null && inventory != null)
        {
            product.AvailableQuantity = inventory.AvailableQuantity;
            product.ReservedQuantity = inventory.ReservedQuantity;
        }

        return product;
    }

    // ✅ Cache invalidation when data changes
    public async Task<Product> UpdateProductAsync(string productId, UpdateProductRequest request)
    {
        var product = await _repository.UpdateAsync(productId, request);

        // ✅ Invalidate specific cache entries (if supported by your Rest provider)
        var productCacheKey = $"product:{productId}";
        // Note: Check your specific Rest provider documentation for cache invalidation methods

        // ✅ Queue cache warming for frequently accessed data
        var cacheWarmingTask = new CacheWarmingTask
        {
            ProductId = productId,
            WarmingType = "product-details"
        };
        await _restme.QueuemeAsync("cache-warming", cacheWarmingTask);

        return product;
    }
}
```

### 4. **Performance Best Practices**
Understand your Rest provider configuration and optimize accordingly:

```csharp
// ✅ Performance-aware service implementation
public class OptimizedProductService : IOEliteService
{
    private readonly IProductRepository _repository;
    private readonly IRestme _restme;

    public OptimizedProductService(IProductRepository repository, IRestme restme)
    {
        _repository = repository;
        _restme = restme;
    }

    public async Task<List<Product>> GetProductsWithOptimizedCachingAsync(GetProductsRequest request)
    {
        // ✅ Create cache key that includes filter parameters
        var cacheKey = $"products:category:{request.CategoryId}:page:{request.Page}:size:{request.PageSize}";

        // ✅ Try cache first
        var cachedResult = await _restme.FindmeAsync<PaginatedResponse<Product>>(cacheKey);
        if (cachedResult != null)
            return cachedResult.Items;

        // Database query if not cached
        var products = await _repository.GetProductsAsync(request);
        var paginatedResult = new PaginatedResponse<Product>(products, request.Page, request.PageSize);

        // ✅ Cache with appropriate expiration based on data volatility
        var cacheExpiration = request.CategoryId != null
            ? TimeSpan.FromHours(2)     // Category-specific queries cache longer
            : TimeSpan.FromMinutes(30); // General queries cache shorter

        await _restme.CachemeAsync(cacheKey, paginatedResult, cacheExpiration);

        return products;
    }

    // ✅ Batch operations for better performance
    public async Task<List<Product>> GetProductsBatchAsync(List<string> productIds)
    {
        var products = new List<Product>();
        var uncachedIds = new List<string>();

        // ✅ Check cache for each product first
        foreach (var productId in productIds)
        {
            var cacheKey = $"product:{productId}";
            var cachedProduct = await _restme.FindmeAsync<Product>(cacheKey);
            if (cachedProduct != null)
            {
                products.Add(cachedProduct);
            }
            else
            {
                uncachedIds.Add(productId);
            }
        }

        // ✅ Batch fetch uncached products from database
        if (uncachedIds.Any())
        {
            var uncachedProducts = await _repository.GetProductsByIdsAsync(uncachedIds);
            products.AddRange(uncachedProducts);

            // ✅ Cache the fetched products
            foreach (var product in uncachedProducts)
            {
                var cacheKey = $"product:{product.Id}";
                await _restme.CachemeAsync(cacheKey, product, TimeSpan.FromHours(1));
            }
        }

        return products;
    }
}
```

### 2. **Async/Await Patterns**
```csharp
// ✅ Good - Proper async usage
public async Task<List<OrderDto>> GetCustomerOrdersAsync(string customerId)
{
    var orders = await _orderRepository.GetOrdersByCustomerAsync(customerId);
    var customerTask = _customerRepository.GetByIdAsync(customerId);
    var productTasks = orders.Select(o => _productRepository.GetByIdAsync(o.ProductId));

    await Task.WhenAll(customerTask);
    await Task.WhenAll(productTasks);

    return orders.Select(MapToDto).ToList();
}
```

## Error Handling Architecture

### Exception Hierarchy
```csharp
// ✅ Good - Custom exception hierarchy
public abstract class OEliteException : Exception
{
    public abstract int StatusCode { get; }
    protected OEliteException(string message) : base(message) { }
    protected OEliteException(string message, Exception innerException) : base(message, innerException) { }
}

public class ProductOutOfStockException : OEliteException
{
    public override int StatusCode => 400;
    public ProductOutOfStockException(string productId, int requestedQuantity, int availableQuantity)
        : base($"Product {productId} is out of stock. Requested: {requestedQuantity}, Available: {availableQuantity}") { }
}

public class InvalidPaymentMethodException : OEliteException
{
    public override int StatusCode => 400;
    public InvalidPaymentMethodException(string paymentMethod)
        : base($"Payment method '{paymentMethod}' is not supported") { }
}

public class CustomerNotAuthorizedException : OEliteException
{
    public override int StatusCode => 403;
    public CustomerNotAuthorizedException(string customerId, string operation)
        : base($"Customer {customerId} is not authorized to perform operation: {operation}") { }
}

public class NotFoundException : OEliteException
{
    public override int StatusCode => 404;
    public NotFoundException(string message) : base(message) { }
}
```

### Global Exception Middleware
```csharp
public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception occurred");
            await HandleExceptionAsync(context, ex);
        }
    }

    private static async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var response = exception switch
        {
            ProductOutOfStockException ex => new { message = ex.Message, statusCode = ex.StatusCode, type = "PRODUCT_OUT_OF_STOCK" },
            InvalidPaymentMethodException ex => new { message = ex.Message, statusCode = ex.StatusCode, type = "INVALID_PAYMENT_METHOD" },
            CustomerNotAuthorizedException ex => new { message = ex.Message, statusCode = ex.StatusCode, type = "CUSTOMER_NOT_AUTHORIZED" },
            NotFoundException ex => new { message = ex.Message, statusCode = ex.StatusCode, type = "NOT_FOUND" },
            OEliteException oex => new { message = oex.Message, statusCode = oex.StatusCode, type = "BUSINESS_LOGIC_ERROR" },
            _ => new { message = "An internal server error occurred", statusCode = 500, type = "INTERNAL_SERVER_ERROR" }
        };

        context.Response.StatusCode = response.statusCode;
        await context.Response.WriteAsync(JsonSerializer.Serialize(response));
    }
}
```

## Testing Architecture

### Unit Test Structure
```csharp
// ✅ Good - AAA pattern with proper mocking
[Test]
public async Task CreateProduct_ValidRequest_ReturnsProduct()
{
    // Arrange
    var categoryId = ObjectId.GenerateNewId().ToString();
    var mockCategoryRepo = new Mock<ICategoryRepository>();
    mockCategoryRepo.Setup(r => r.GetByIdAsync(categoryId))
               .ReturnsAsync(new Category { Id = categoryId, Name = "Electronics" });

    var mockProductRepo = new Mock<IProductRepository>();
    mockProductRepo.Setup(r => r.CreateAsync(It.IsAny<Product>()))
               .ReturnsAsync((Product p) => { p.Id = ObjectId.GenerateNewId().ToString(); return p; });

    var service = new ProductService(mockProductRepo.Object, mockCategoryRepo.Object);
    var request = new CreateProductRequest { Name = "Test Product", CategoryId = categoryId, Price = 99.99m };

    // Act
    var result = await service.CreateProductAsync(request);

    // Assert
    Assert.That(result, Is.Not.Null);
    Assert.That(result.Name, Is.EqualTo("Test Product"));
    Assert.That(result.CategoryId, Is.EqualTo(categoryId));
    mockProductRepo.Verify(r => r.CreateAsync(It.IsAny<Product>()), Times.Once);
}
```

## Compliance Checklist

### Functional Requirements Flow (MANDATORY)
- [ ] **3.1 UI Operations**: Code starts with functional requirements identifying actual user operations needed
- [ ] **3.2 API Endpoints**: API contracts are designed based on UI operation requirements
- [ ] **3.3 Data Entities**: Entity classes inherit from BaseEntity with proper database attributes ([DbCollection], [DbIndex], [DbShardKey], [DenormalizedField], [DenormalizedCollection])
- [ ] **3.4 Functional Methods**: Methods implement logic that directly supports defined API contracts
- [ ] **3.5 Data Repositories**: Repositories contain only data access logic, no business rules
- [ ] **3.6 CRUD Standards**: All repositories implement the 4 core CRUD methods with proper naming convention

### Repository Standards (MANDATORY)
- [ ] **CRUD Implementation**: All repositories implement GetEntityAsync, GetEntitiesAsync, UpdateEntityAsync, DeleteEntityAsync
- [ ] **Collection Types**: Methods return EntityCollection types (e.g., OrionApiClientCollection) instead of List<T>
- [ ] **FetchAsync Usage**: All collection-returning methods use .FetchAsync<EntityType, EntityCollectionType>()
- [ ] **No Business Logic**: Repositories contain only data access operations
- [ ] **Query Objects**: Methods accept strongly-typed query objects for filtering

### Architecture Requirements
- [ ] Follows N-tier architecture with clear layer separation
- [ ] Implements proper dependency injection patterns
- [ ] Uses configs-only configuration loading
- [ ] Implements domain-driven design principles
- [ ] Has proper exception handling hierarchy
- [ ] Includes comprehensive unit tests
- [ ] Follows single responsibility principle
- [ ] Uses appropriate design patterns (Repository, Service, etc.)
- [ ] Implements proper async/await patterns
- [ ] Has health check endpoints for monitoring
- [ ] **Uses domain-based folder organization**

### Code Quality Gates
- [ ] No business logic in controllers
- [ ] No direct database access from controllers
- [ ] All services implement IOEliteService interface
- [ ] All repositories inherit from OrionDbRepository
- [ ] Configuration classes inherit from BaseAppConfig
- [ ] Proper error handling with custom exceptions
- [ ] Comprehensive logging throughout application
- [ ] Thread-safe implementations where applicable

### OElite.Restme and Caching Requirements (MANDATORY)
- [ ] **IMemoryCache and IDistributedCache are the primary interfaces for caching, automatically injected via OElite.Restme.Hosting.**
- [ ] **IRestme is used for non-caching operations like _restme.QueuemeAsync() and _restme.DomeAsync() methods.**
- [ ] **Caching operations directly use IMemoryCache and IDistributedCache.**
- [ ] **IRestme is properly injected and configured with appropriate providers for non-caching functionalities.**
- [ ] **Cache keys follow consistent naming patterns**
- [ ] **Queue processing includes proper error handling and retry logic**
- [ ] **Background services implement _restme.DomeAsync() for queue processing**
- [ ] **Cache expiration times are appropriate for data volatility**
- [ ] **Developers understand which Rest provider is being used for performance optimization**
- [ ] **Services inject IRestme (not non-existent RestmeProvider)**

This architectural foundation ensures consistency, maintainability, and enterprise-grade quality across all OElite applications while following industry best practices and domain-driven design principles.