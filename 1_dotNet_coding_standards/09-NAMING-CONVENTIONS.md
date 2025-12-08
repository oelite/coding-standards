# Naming Conventions & File Organization

## Overview

The OElite platform enforces comprehensive naming conventions across all code elements, files, namespaces, and organizational structures. These standards ensure consistency, readability, and maintainability across the entire enterprise platform. This document establishes the mandatory naming and organizational patterns that all OElite applications must follow.

## File Naming Standards

### 1. **C# Source Files** (Mandatory)
All C# files MUST follow PascalCase naming conventions matching their primary class name:

```
✅ Correct File Names:
- ProductService.cs
- IProductRepository.cs
- CreateProductRequest.cs
- ProductResponse.cs
- OrderController.cs
- CustomerEntity.cs
- DatabaseMigration001_CreateProductsTable.cs
- GlobalExceptionMiddleware.cs

❌ Incorrect File Names:
- productService.cs                    (camelCase)
- product_service.cs                   (snake_case)
- product-service.cs                   (kebab-case)
- IProductRepository.CS                (wrong extension case)
- ProductService.Services.cs           (compound names)
```

### 2. **Configuration and JSON Files**
Configuration files follow specific naming patterns:

```
✅ Correct Configuration Names:
- appsettings.init.json                (NEW STANDARD - base config)
- appsettings.template.json            (Template files)
- DbSchema.json                        (Schema definitions)
- swagger.json                         (API documentation)
- package.json                         (NPM packages)
- docker-compose.yml                   (Docker configurations)
- Dockerfile                           (Docker container definitions)

❌ Incorrect Configuration Names:
- appsettings.json                     (DEPRECATED - use appsettings.init.json)
- appsettings.Development.json         (DEPRECATED - use configs/.dev pattern)
- app_settings.json                    (snake_case)
- AppSettings.json                     (PascalCase for config files)
```

### 3. **Test Files**
Test files MUST indicate their purpose and target:

```
✅ Correct Test File Names:
- ProductServiceTests.cs               (Unit tests)
- ProductRepositoryIntegrationTests.cs (Integration tests)
- ProductControllerTests.cs            (Controller tests)
- DatabaseConnectionTests.cs           (Infrastructure tests)
- ProductServiceBenchmarks.cs          (Performance tests)

❌ Incorrect Test File Names:
- ProductTests.cs                      (Too generic)
- TestProductService.cs                (Wrong prefix)
- product_service_tests.cs             (snake_case)
```

### 4. **Project and Assembly Names**
Follow the OElite namespace hierarchy:

```
✅ Correct Project Names:
- OElite.Common.csproj
- OElite.Data.Repositories.csproj
- OElite.Services.Kortex.csproj
- OElite.Servers.Nexus.csproj
- OElite.Migration.CollectionMerger.csproj

❌ Incorrect Project Names:
- oelite.common.csproj                 (lowercase)
- OElite_Common.csproj                 (underscore)
- OEliteCommon.csproj                  (missing dots)
- Common.csproj                        (missing OElite prefix)
```

## Namespace Organization

### 1. **Required Namespace Hierarchy**
All OElite projects MUST follow the standardized namespace structure:

```csharp
// ✅ Correct namespace hierarchy
namespace OElite.Common.Domain.Entities
{
    public class Product : BaseEntity
    {
        // Entity implementation
    }
}

namespace OElite.Data.Repositories.Implementations
{
    public class ProductRepository : DataRepository<Product>, IProductRepository
    {
        // Repository implementation
    }
}

namespace OElite.Services.Business
{
    public class ProductService : IOEliteService
    {
        // Service implementation
    }
}

namespace OElite.Servers.Nexus.Controllers
{
    [ApiController]
    public class ProductsController : ControllerBase
    {
        // Controller implementation
    }
}

// ❌ Incorrect namespace patterns
namespace Products                      // Missing OElite prefix
namespace OElite.product.service       // camelCase
namespace OElite_Common_Domain         // Underscore usage
namespace OElite.Common.Domain.Product // Too specific
```

### 2. **Namespace Depth Guidelines**
Maintain appropriate namespace depth for clarity:

```csharp
// ✅ Good namespace depth (3-5 levels)
namespace OElite.Common.Domain.Entities
namespace OElite.Data.Repositories.Interfaces
namespace OElite.Services.Business.Catalog
namespace OElite.Servers.Nexus.Controllers.Api

// ✅ Acceptable for specialized cases (6 levels max)
namespace OElite.Migration.CollectionMerger.Strategies.Legacy

// ❌ Too shallow (lacks organization)
namespace OElite.Common
namespace OElite.Services

// ❌ Too deep (over-engineering)
namespace OElite.Common.Domain.Entities.Catalog.Products.Electronics.Smartphones
```

### 3. **Using Directives Organization**
Organize using statements in a standardized order:

```csharp
// ✅ Correct using statement organization
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

using MongoDB.Bson;
using Newtonsoft.Json;

using OElite.Common.Domain.Entities;
using OElite.Common.Infrastructure;
using OElite.Data.Repositories.Interfaces;
using OElite.Services.Business;

namespace OElite.Servers.Nexus.Controllers
{
    // Class implementation
}
```

## Class and Interface Naming

### 1. **Interface Naming Standards**
All interfaces MUST follow 'I' prefix convention with descriptive names:

```csharp
// ✅ Correct interface names
public interface IProductService : IOEliteService
{
    Task<Product> GetProductAsync(string id);
}

public interface IProductRepository : IDataRepository<Product>
{
    Task<List<Product>> GetProductsByCategoryAsync(string categoryId);
}

public interface ICacheService
{
    Task<T> GetAsync<T>(string key);
    Task SetAsync<T>(string key, T value, TimeSpan expiration);
}

public interface IEmailNotificationService
{
    Task SendEmailAsync(string to, string subject, string body);
}

// ❌ Incorrect interface names
public interface ProductService         // Missing 'I' prefix
public interface IProductSvc          // Abbreviated
public interface IProduct             // Too generic
public interface IProductServiceInterface  // Redundant suffix
```

### 2. **Class Naming Standards**
Classes should be descriptive and follow single responsibility principle:

```csharp
// ✅ Correct class names
public class ProductService : IOEliteService
public class ProductRepository : DataRepository<Product>, IProductRepository
public class CreateProductRequest
public class ProductResponse
public class ProductNotFoundException : NotFoundException
public class EmailNotificationService : IEmailNotificationService
public class JwtTokenValidator
public class DatabaseConnectionFactory

// ❌ Incorrect class names
public class ProductSvc                 // Abbreviated
public class ProductMgr                 // Abbreviated
public class ProductHelper             // Vague purpose
public class ProductUtility            // Vague purpose
public class ProductData               // Unclear responsibility
public class ProductHandler           // Generic handler
```

### 3. **Abstract Classes and Base Classes**
Use descriptive names indicating their role:

```csharp
// ✅ Correct base class names
public abstract class BaseEntity
public abstract class BaseAppConfig
public abstract class DataRepository<T>
public abstract class BackgroundService
public abstract class ValidationException
public abstract class OEliteException

// ❌ Incorrect base class names
public abstract class Base             // Too generic
public abstract class AbstractProduct // Redundant 'Abstract'
public abstract class EntityBase      // Backwards naming
public abstract class CommonEntity    // Unclear purpose
```

## Method and Property Conventions

### 1. **Method Naming Standards**
Methods should clearly describe their action and purpose:

```csharp
// ✅ Correct method names
public async Task<Product> GetProductAsync(string id)
public async Task<Product> CreateProductAsync(CreateProductRequest request)
public async Task<bool> DeleteProductAsync(string id)
public async Task<List<Product>> GetProductsByCategoryAsync(string categoryId)
public async Task<Product> UpdateProductAsync(string id, UpdateProductRequest request)
public bool ValidateProductData(Product product)
public void LogProductCreated(Product product)
public decimal CalculateProductTotalPrice(Product product, int quantity)

// Async method variants
public Task<Product> GetProductAsync(string id)          // Async version
public Product GetProduct(string id)                     // Sync version (when needed)

// ❌ Incorrect method names
public async Task<Product> Get(string id)                // Too generic
public async Task<Product> getProduct(string id)         // camelCase
public async Task<Product> GetProd(string id)            // Abbreviated
public async Task<Product> Product_Get(string id)        // Snake case
public async Task<Product> GetProductFromDatabase(string id)  // Too implementation-specific
```

### 2. **Property Naming Standards**
Properties should be descriptive nouns in PascalCase:

```csharp
// ✅ Correct property names
public class Product : BaseEntity
{
    public string Name { get; set; }
    public string Description { get; set; }
    public decimal Price { get; set; }
    public string CategoryId { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedOnUtc { get; set; }
    public DateTime LastModifiedOnUtc { get; set; }
    public List<string> Tags { get; set; } = new();
    public Dictionary<string, object> Specifications { get; set; } = new();

    // Computed properties
    public bool IsAvailableForPurchase => IsActive && Price > 0;
    public string DisplayName => $"{Name} - {Price:C}";
}

// ❌ Incorrect property names
public string name { get; set; }                 // camelCase
public string product_name { get; set; }         // snake_case
public string productName { get; set; }          // camelCase (should be PascalCase)
public bool isActive { get; set; }               // camelCase
public DateTime created { get; set; }            // Too abbreviated
public bool Active { get; set; }                 // Missing 'Is' prefix for boolean
```

### 3. **Field Naming Standards**
Private fields use camelCase with underscore prefix:

```csharp
// ✅ Correct field names
public class ProductService : IOEliteService
{
    private readonly IProductRepository _productRepository;
    private readonly ICategoryRepository _categoryRepository;
    private readonly ILogger<ProductService> _logger;
    private readonly IMemoryCache _cache;
    private readonly ProductServiceOptions _options;

    // Static fields
    private static readonly string DefaultCacheKey = "products";
    private static readonly TimeSpan DefaultCacheExpiration = TimeSpan.FromMinutes(5);

    // Constants
    public const int MaxProductNameLength = 100;
    public const decimal MinimumPrice = 0.01m;
    private const string ProductCachePrefix = "product:";
}

// ❌ Incorrect field names
private readonly IProductRepository productRepository;     // Missing underscore
private readonly IProductRepository ProductRepository;     // PascalCase
private readonly IProductRepository _repo;                 // Abbreviated
private readonly IProductRepository m_productRepository;   // Hungarian notation
```

## Database Naming Conventions

### 1. **Collection Naming Standards**
MongoDB collections MUST use lowercase, plural, snake_case names:

```csharp
// ✅ Correct collection names
[DbCollection("products")]
[DbCollection("product_categories")]
[DbCollection("customer_orders")]
[DbCollection("shipping_methods")]
[DbCollection("payment_transactions")]
[DbCollection("user_preferences")]

// ❌ Incorrect collection names
[DbCollection("Products")]              // PascalCase
[DbCollection("product")]               // Singular
[DbCollection("product-categories")]    // kebab-case
[DbCollection("productCategories")]     // camelCase
[DbCollection("ProductCategories")]     // PascalCase
```

### 2. **Field Naming Standards**
MongoDB fields MUST use snake_case naming when different from property names. DbField is optional when property name matches field name:

```csharp
// ✅ Correct field naming patterns
public class Product : BaseEntity
{
    // No DbField needed - property matches field
    public string name { get; set; }
    public string description { get; set; }

    // DbField needed - PascalCase property → snake_case field
    [DbField("unit_price")]
    public decimal UnitPrice { get; set; }

    [DbField("category_id")]
    public string CategoryId { get; set; }

    [DbField("is_active")]
    public bool IsActive { get; set; }

    [DbField("created_on_utc")]
    public DateTime CreatedOnUtc { get; set; }

    [DbField("last_modified_on_utc")]
    public DateTime LastModifiedOnUtc { get; set; }

    [DbField("shipping_address")]
    public string ShippingAddress { get; set; }

    [DbField("payment_method")]
    public string PaymentMethod { get; set; }
}

// ❌ Incorrect field names
[DbField("Name")]                       // PascalCase in database
[DbField("unitPrice")]                  // camelCase in database
[DbField("UnitPrice")]                  // PascalCase in database
[DbField("payment-method")]             // kebab-case not allowed
[DbField("name")]                       // Unnecessary when property name matches
public string name { get; set; }
```

### 3. **Schema Constants Organization**
Organize database schema constants systematically:

```csharp
// ✅ Correct schema constants organization
public static class DbSchema
{
    public static class Products
    {
        public const string Name = "products";

        public static class Fields
        {
            public const string Id = "_id";
            public const string Name = "name";
            public const string Description = "description";
            public const string UnitPrice = "unitPrice";
            public const string CategoryId = "categoryId";
            public const string IsActive = "isActive";
            public const string CreatedOnUtc = "createdOnUtc";
            public const string LastModifiedOnUtc = "lastModifiedOnUtc";
        }

        public static class Indexes
        {
            public const string CategoryActive = "idx_category_active";
            public const string TextSearch = "idx_text_search";
            public const string PriceRange = "idx_price_range";
        }
    }

    public static class Orders
    {
        public const string Name = "orders";

        public static class Fields
        {
            public const string Id = "_id";
            public const string CustomerId = "customerId";
            public const string Status = "status";
            public const string Total = "total";
            public const string Items = "items";
            public const string CreatedOnUtc = "createdOnUtc";
        }
    }
}
```

## File and Directory Organization

### 1. **Project Structure Standards** (Domain-Based Organization)
All OElite projects MUST follow the domain-based directory structure:

```
OElite.Common/                         # Shared components and DTOs under Business Domains
│   Customers/                    # Customer domain
│   ├── Requests/                 # Customer API request models
│   ├── Responses/                # Customer API response models
│   ├── Reports/                  # Customer reporting models
│   └── ModelTransformation/      # Customer model transformers
│   Products/                     # Product domain
│   ├── Requests/                 # Product API request models
│   ├── Responses/                # Product API response models
│   ├── Reports/                  # Product reporting models
│   └── ModelTransformation/      # Product model transformers
│   Orders/                       # Order domain
│   ├── Requests/                 # Order API request models
│   ├── Responses/                # Order API response models
│   ├── Reports/                  # Order reporting models
│   └── ModelTransformation/      # Order model transformers
└── Infrastructure/                   # Cross-cutting concerns

OElite.Data.Repositories/              # Business domain based Data access layer
├── Customers/                    # Customer data access
│   ├── CustomerRepository.cs
│   └── ICustomerRepository.cs
├── Products/                     # Product data access
│   ├── ProductRepository.cs
│   └── IProductRepository.cs
│── Orders/                       # Order data access
│   ├── OrderRepository.cs
│   └── IOrderRepository.cs
├── Base/                             # Base repository classes
└── Shared/                           # Shared query implementations

OElite.Services/                       # Business doain based services
├── Customers/                    # Customer business logic
│   ├── CustomerService.cs
│   └── CustomerProfileService.cs
├── Products/                     # Product business logic
│   ├── ProductService.cs
│   └── ProductCatalogService.cs
│── Orders/                       # Order business logic
│   ├── OrderService.cs
│   └── OrderProcessingService.cs
├── Base/                             # Base service classes
├── Integration/                      # External service integrations
└── Background/                       # Background processing services

OElite.Servers.ProjectName/            # Application servers
├── Controllers/                      # API controllers (organized by domain)
│   ├── Customers/                    # Customer controllers
│   │   └── CustomersController.cs
│   ├── Products/                     # Product controllers
│   │   └── ProductsController.cs
│   └── Orders/                       # Order controllers
│       └── OrdersController.cs
├── Infrastructure/                   # Cross-cutting concerns
│   ├── Logging/                      # Logging configurations
│   ├── Security/                     # Security implementations
│   ├── Caching/                      # Caching implementations
│   └── Extensions/                   # Extension methods
├── configs/                          # Configuration files (NEW STANDARD)
│   ├── appsettings.init.json        # Base configuration
│   └── .dev/                        # Environment overrides
│       ├── Development/
│       ├── Production/
│       └── Staging/
└── Docs/                    # Project documentation
```

### 2. **Domain-Based File Grouping** (NEW STANDARD)
Group related functionality by business domain for better organization and maintainability:

```
// ✅ Good domain-based file grouping
OElite.Common/
├── Products/                          # All product-related models together
│   ├── Requests/
│   │   ├── CreateProductRequest.cs
│   │   ├── UpdateProductRequest.cs
│   │   ├── GetProductsRequest.cs
│   │   └── SearchProductsRequest.cs
│   ├── Responses/
│   │   ├── ProductResponse.cs
│   │   ├── ProductSummaryResponse.cs
│   │   ├── ProductDetailsResponse.cs
│   │   └── ProductSearchResponse.cs
│   ├── Reports/
│   │   ├── ProductSalesReport.cs
│   │   └── ProductInventoryReport.cs
│   └── ModelTransformation/
│       ├── ProductTransformer.cs
│       └── ProductSummaryTransformer.cs
├── Orders/                            # All order-related models together
│   ├── Requests/
│   │   ├── CreateOrderRequest.cs
│   │   ├── UpdateOrderStatusRequest.cs
│   │   └── GetOrdersRequest.cs
│   ├── Responses/
│   │   ├── OrderResponse.cs
│   │   └── OrderSummaryResponse.cs
│   └── Reports/
│       ├── OrderAnalyticsReport.cs
│       └── OrderTrendsReport.cs

OElite.Services/
├── Products/                          # All product services together
│   ├── ProductService.cs
│   ├── ProductCatalogService.cs
│   └── ProductInventoryService.cs
├── Orders/                            # All order services together
│   ├── OrderService.cs
│   ├── OrderProcessingService.cs
│   └── OrderFulfillmentService.cs

OElite.Data.Repositories/
├── Products/                          # All product repositories together
│   ├── ProductRepository.cs
│   ├── ProductCategoryRepository.cs
│   └── IProductRepository.cs
├── Orders/                            # All order repositories together
│   ├── OrderRepository.cs
│   ├── OrderItemRepository.cs
│   └── IOrderRepository.cs

// ❌ Poor file grouping (old layered approach)
OElite.Common/
├── Requests/                          # Requests separated from responses
│   ├── ProductRequest.cs              # All requests mixed together
│   ├── OrderRequest.cs
│   └── CustomerRequest.cs
├── Responses/                         # Responses separated from requests
│   ├── ProductResponse.cs             # Mixed with unrelated responses
│   ├── OrderResponse.cs
│   └── CustomerResponse.cs
└── Services/                          # Services separated from related models
    ├── ProductService.cs              # Mixed with unrelated services
    ├── OrderService.cs
    └── CustomerService.cs
```

## Constant and Enum Naming

### 1. **Constants Naming Standards**
Use PascalCase for public constants, descriptive names:

```csharp
// ✅ Correct constant names
public static class ProductConstants
{
    public const int MaxNameLength = 100;
    public const int MaxDescriptionLength = 1000;
    public const decimal MinimumPrice = 0.01m;
    public const decimal MaximumPrice = 999999.99m;
    public const string DefaultCurrency = "USD";
    public const int DefaultPageSize = 20;
    public const int MaxPageSize = 100;
}

public static class CacheKeys
{
    public const string ProductPrefix = "product:";
    public const string CategoryPrefix = "category:";
    public const string UserSessionPrefix = "session:";

    public static string ProductKey(string id) => $"{ProductPrefix}{id}";
    public static string CategoryKey(string id) => $"{CategoryPrefix}{id}";
}

// ❌ Incorrect constant names
public const int MAX_NAME_LENGTH = 100;           // SCREAMING_SNAKE_CASE
public const int maxNameLength = 100;             // camelCase
public const int NameLength = 100;                // Too generic
public const int ProductNameMaxLength = 100;      // Too verbose
```

### 2. **Enum Naming Standards**
Enums should be descriptive with PascalCase values:

```csharp
// ✅ Correct enum names and values
public enum OrderStatus
{
    Pending = 1,
    Confirmed = 2,
    Processing = 3,
    Shipped = 4,
    Delivered = 5,
    Cancelled = 6,
    Refunded = 7
}

public enum PaymentMethod
{
    CreditCard = 1,
    DebitCard = 2,
    PayPal = 3,
    BankTransfer = 4,
    Cash = 5,
    Cryptocurrency = 6
}

public enum UserRole
{
    Guest = 0,
    Customer = 1,
    Moderator = 2,
    Administrator = 3,
    SuperAdministrator = 4
}

// ❌ Incorrect enum names and values
public enum orderStatus                    // camelCase enum name
{
    pending = 1,                          // camelCase values
    CONFIRMED = 2,                        // SCREAMING_CASE
    in_progress = 3                       // snake_case
}

public enum Status                        // Too generic name
{
    Status1 = 1,                         // Non-descriptive values
    Status2 = 2
}
```

## Variable and Parameter Naming

### 1. **Local Variables**
Use camelCase for local variables with descriptive names:

```csharp
// ✅ Correct local variable names
public async Task<Product> CreateProductAsync(CreateProductRequest request)
{
    var existingProduct = await _productRepository.GetByNameAsync(request.Name);
    if (existingProduct != null)
    {
        throw new BusinessException("Product with this name already exists");
    }

    var newProduct = new Product
    {
        Name = request.Name,
        Description = request.Description,
        Price = request.Price,
        CategoryId = request.CategoryId
    };

    var createdProduct = await _productRepository.CreateAsync(newProduct);
    var productResponse = new ProductResponse(createdProduct);

    return productResponse;
}

// ❌ Incorrect local variable names
var p = await _productRepository.GetByNameAsync(request.Name);  // Too short
var ProductFromDatabase = await _productRepository.GetByNameAsync(request.Name);  // PascalCase
var product_from_db = await _productRepository.GetByNameAsync(request.Name);  // snake_case
var existingProd = await _productRepository.GetByNameAsync(request.Name);  // Abbreviated
```

### 2. **Method Parameters**
Use camelCase for parameters with clear, descriptive names:

```csharp
// ✅ Correct parameter names
public async Task<Product> GetProductAsync(string productId)
public async Task<List<Product>> GetProductsByCategoryAsync(string categoryId, int pageSize, int pageNumber)
public async Task<bool> UpdateProductPriceAsync(string productId, decimal newPrice)
public async Task<Product> CreateProductAsync(CreateProductRequest request)
public async Task SendEmailNotificationAsync(string emailAddress, string subject, string messageBody)

// ❌ Incorrect parameter names
public async Task<Product> GetProductAsync(string id)             // Too generic
public async Task<Product> GetProductAsync(string ProductId)      // PascalCase
public async Task<Product> GetProductAsync(string product_id)     // snake_case
public async Task<Product> GetProductAsync(string prodId)         // Abbreviated
```

## Exception and Error Naming

### 1. **Custom Exception Classes**
Follow descriptive naming with Exception suffix:

```csharp
// ✅ Correct exception names
public class ProductNotFoundException : NotFoundException
{
    public ProductNotFoundException(string productId)
        : base($"Product with ID {productId} was not found")
    {
        ProductId = productId;
    }

    public string ProductId { get; }
}

public class InvalidProductDataException : ValidationException
{
    public InvalidProductDataException(string message, IEnumerable<ValidationError> errors)
        : base(message)
    {
        Errors = errors.ToList();
    }

    public List<ValidationError> Errors { get; }
}

public class ProductOutOfStockException : OEliteException
{
    public override int StatusCode => 400;

    public ProductOutOfStockException(string productId, int requestedQuantity, int availableQuantity)
        : base($"Product {productId} has insufficient stock. Requested: {requestedQuantity}, Available: {availableQuantity}")
    {
        ProductId = productId;
        RequestedQuantity = requestedQuantity;
        AvailableQuantity = availableQuantity;
    }

    public string ProductId { get; }
    public int RequestedQuantity { get; }
    public int AvailableQuantity { get; }
}

public class InvalidPaymentMethodException : OEliteException
{
    public override int StatusCode => 400;

    public InvalidPaymentMethodException(string paymentMethod)
        : base($"Payment method '{paymentMethod}' is not supported")
    {
        PaymentMethod = paymentMethod;
    }

    public string PaymentMethod { get; }
}

public class CustomerNotAuthorizedException : OEliteException
{
    public override int StatusCode => 403;

    public CustomerNotAuthorizedException(string customerId, string operation)
        : base($"Customer {customerId} is not authorized to perform operation: {operation}")
    {
        CustomerId = customerId;
        Operation = operation;
    }

    public string CustomerId { get; }
    public string Operation { get; }
}

// ❌ Incorrect exception names
public class ProductError : Exception                    // Missing Exception suffix
public class ProdNotFound : Exception                   // Abbreviated
public class ProductExc : Exception                     // Abbreviated suffix
public class Error : Exception                          // Too generic
```



## Compliance Checklist

### File and Structure Requirements
- [ ] All C# files use PascalCase matching their primary class
- [ ] Configuration files use correct naming conventions
- [ ] Test files clearly indicate their purpose and target
- [ ] Project names follow OElite namespace hierarchy
- [ ] Directory structure follows standardized organization
- [ ] Related files are properly grouped by functionality

### Code Naming Requirements
- [ ] All interfaces use 'I' prefix with descriptive names
- [ ] Classes follow single responsibility naming
- [ ] Methods clearly describe their action and purpose
- [ ] Properties use descriptive PascalCase nouns
- [ ] Private fields use camelCase with underscore prefix
- [ ] Constants use PascalCase with descriptive names
- [ ] Enums use PascalCase with meaningful values

### Database Naming Requirements
- [ ] Collections use lowercase, plural, kebab-case names
- [ ] Fields use camelCase naming consistently
- [ ] Schema constants are properly organized
- [ ] Index names are descriptive and follow patterns
- [ ] Database-related classes follow entity naming conventions

### Quality Standards
- [ ] No abbreviated names unless universally understood
- [ ] No Hungarian notation or prefixes (except interfaces)
- [ ] Consistent naming patterns across related functionality
- [ ] Names are self-documenting and reduce need for comments
- [ ] Exception classes are descriptive with proper inheritance

This comprehensive naming convention system ensures consistency, readability, and maintainability across the entire OElite platform while providing clear guidance for all development activities.