# 10. Entity Collection Patterns

## Overview

This document establishes the coding standards for entity collections in OElite APIs. **All paginated API responses MUST use strongly typed collections inheriting from the appropriate base collection class instead of generic `List<T>`, `PagedResult<T>`, or other bespoke collection implementations.**

## Collection Type Selection

### **BaseEntityCollection<T>** - For BaseEntity Objects
Use `BaseEntityCollection<T>` for entities that inherit from `BaseEntity`:

```csharp
// ✅ REQUIRED - For BaseEntity-derived classes
public class MerchantCollection : BaseEntityCollection<Merchant>
{
    // Merchant inherits from BaseEntity
}

public class ProductCollection : BaseEntityCollection<Product>
{
    // Product inherits from BaseEntity
    public decimal TotalValue => this.Sum(p => p.Price * p.Stock);
}
```

### **DataCollection<T>** - For Non-BaseEntity Objects
Use `DataCollection<T>` for DTOs, responses, and other classes that don't inherit from `BaseEntity`:

```csharp
// ✅ REQUIRED - For DTOs and non-BaseEntity classes
public class CartItemDtoCollection : DataCollection<CartItemDto>
{
    // CartItemDto doesn't inherit from BaseEntity
    public decimal TotalValue => this.Sum(item => item.TotalPrice);
}

public class ProductSearchResultCollection : DataCollection<ProductSearchResultDto>
{
    // Search result DTOs don't inherit from BaseEntity
    public int FeaturedProductsCount => this.Count(p => p.IsFeatured);
}
```

## Core Requirements

### 1. **Strongly Typed Collections** (Mandatory)

For every type that requires paginated responses, create a dedicated collection class:

```csharp
// ✅ ENTITIES - Use BaseEntityCollection<T> for BaseEntity objects
public class MerchantCollection : BaseEntityCollection<Merchant>
{
    // Inherits all pagination properties and methods from BaseEntityCollection<T>
}

public class ProductCollection : BaseEntityCollection<Product>
{
    // Additional collection-specific properties can be added if needed
    public decimal TotalValue => this.Sum(p => p.Price * p.Stock);
}

// ✅ DTOs - Use DataCollection<T> for non-BaseEntity objects
public class CartItemDtoCollection : DataCollection<CartItemDto>
{
    public decimal TotalCartValue => this.Sum(item => item.TotalPrice);
    public int TotalQuantity => this.Sum(item => item.Quantity);
}

public class OrderSummaryDtoCollection : DataCollection<OrderSummaryDto>
{
    public decimal TotalOrderValue => this.Sum(order => order.TotalAmount);
    public int PendingOrdersCount => this.Count(order => order.Status == "Pending");
}
```

### 2. **Forbidden Patterns** ❌

The following patterns are **NOT ALLOWED** for paginated API responses:

```csharp
// ❌ FORBIDDEN - Generic list without pagination metadata
public async Task<List<Product>> GetProductsAsync()
public async Task<List<CartItemDto>> GetCartItemsAsync()

// ❌ FORBIDDEN - Generic PagedResult (scattered implementations)
public async Task<PagedResult<Customer>> GetCustomersAsync()
public async Task<PagedResult<OrderSummaryDto>> GetOrderSummariesAsync()

// ❌ FORBIDDEN - ActionResult wrapping collections
public async Task<ActionResult<List<Merchant>>> GetMerchantsAsync()

// ❌ FORBIDDEN - Bespoke collection classes not inheriting from proper base collections
public class CustomProductList : List<Product>
public class CustomCartItemList : List<CartItemDto>

// ❌ FORBIDDEN - Wrong collection type for object type
public class ProductDtoCollection : BaseEntityCollection<ProductDto> // Should use DataCollection<T>
public class MerchantCollection : DataCollection<Merchant> // Should use BaseEntityCollection<T>
```

### 3. **Required Controller Patterns** ✅

All API controllers returning collections MUST follow this pattern:

```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : CrudControllerBase<Product, ProductCollection, CreateProductDto, UpdateProductDto, ProductQuery>
{
    // ✅ CORRECT - BaseEntityCollection<T> for BaseEntity objects
    [HttpGet]
    [ProducesResponseType(typeof(ProductCollection), 200)]
    public async Task<ProductCollection> GetProductsAsync([FromQuery] ProductQuery query)
    {
        var results = await _productService.GetProductsAsync(query);
        return new ProductCollection()
            .SetTotalRecordsCount(results.TotalRecordsCount)
            .AddMetaData("searchTerm", query.SearchTerm ?? string.Empty)
            .AddMetaData("category", query.CategoryId ?? string.Empty)
            .AddEntities(results.Items);
    }

    // ✅ CORRECT - Single entity return (no collection needed)
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Product), 200)]
    public async Task<Product> GetProductAsync(string id)
    {
        return await _productService.GetByIdAsync(id);
    }
}

[ApiController]
[Route("api/[controller]")]
public class CartController : ControllerBase
{
    // ✅ CORRECT - DataCollection<T> for DTO objects
    [HttpGet("items")]
    [ProducesResponseType(typeof(CartItemDtoCollection), 200)]
    public async Task<CartItemDtoCollection> GetCartItemsAsync([FromQuery] CartQuery query)
    {
        var cartItems = await _cartService.GetCartItemsAsync(query);
        return new CartItemDtoCollection()
            .SetTotalRecordsCount(cartItems.TotalRecordsCount)
            .AddMetaData("customerId", query.CustomerId)
            .AddData(cartItems.Items);
    }
}
```

## Collection Base Classes Integration

### 1. **Collection Hierarchy**

The OElite platform provides two base collection types in `OElite.Restme.Utils`:

```csharp
// Located in: uranus/restme/OElite.Restme.Utils/BaseEntity.cs

// For BaseEntity objects
public class BaseEntityCollection<T> : List<T>, IEntityCollection
    where T : BaseEntity
{
    public int TotalRecordsCount { get; set; }
    public Dictionary<string, object>? MetaData { get; set; }
    public string BaseEntityTypeName => typeof(T).Name;
}

// NEW - For non-BaseEntity objects (DTOs, etc.)
public class DataCollection<T> : List<T>, IEntityCollection
    where T : class
{
    public int TotalRecordsCount { get; set; }
    public Dictionary<string, object>? MetaData { get; set; }
    public string BaseEntityTypeName => typeof(T).Name;
}

// Unified interface for all collection types
public interface IEntityCollection : IEnumerable
{
    int TotalRecordsCount { get; set; }
    Dictionary<string, object>? MetaData { get; set; }
    string BaseEntityTypeName { get; }
}
```

### 2. **Collection Selection Rules**

**Use BaseEntityCollection<T> when:**
- The type `T` inherits from `BaseEntity`
- Examples: Merchant, Product, Customer, Order entities

**Use DataCollection<T> when:**
- The type `T` does NOT inherit from `BaseEntity`
- Examples: DTOs, response models, value objects, enums

### 3. **Helper Methods Usage**

Leverage the helper methods from `BaseEntityCollectionHelpers`:

```csharp
// ✅ BaseEntityCollection<T> helper methods for BaseEntity objects
public async Task<ProductCollection> GetProductsAsync(ProductQuery query)
{
    var products = await _repository.GetAsync(query);
    var totalCount = await _repository.CountAsync(query);

    return new ProductCollection()
        .SetTotalRecordsCount(totalCount)
        .AddMetaData("category", query.CategoryId)
        .AddMetaData("searchTerm", query.SearchTerm)
        .AddEntities(products); // Uses AddEntities for BaseEntity objects
}

// ✅ DataCollection<T> helper methods for non-BaseEntity objects
public async Task<CartItemDtoCollection> GetCartItemsAsync(CartQuery query)
{
    var cartItems = await _cartService.GetCartItemsAsync(query);
    var totalCount = await _cartService.CountCartItemsAsync(query);

    return new CartItemDtoCollection()
        .SetTotalRecordsCount(totalCount)
        .AddMetaData("customerId", query.CustomerId)
        .AddData(cartItems); // Uses AddData for non-BaseEntity objects
}

// ✅ Using ToBaseEntityCollection for existing BaseEntity patterns
public async Task<ProductCollection> GetProductsLegacyAsync(ProductQuery query)
{
    var products = await _repository.GetAsync(query);
    var totalCount = await _repository.CountAsync(query);

    return products.ToBaseEntityCollection<Product, ProductCollection>(totalCount);
}

// ✅ Using ToDataCollection for DTO patterns
public async Task<CartItemDtoCollection> GetCartItemsLegacyAsync(CartQuery query)
{
    var cartItems = await _cartService.GetCartItemsAsync(query);
    var totalCount = await _cartService.CountCartItemsAsync(query);

    return cartItems.ToDataCollection<CartItemDto, CartItemDtoCollection>(totalCount);
}
```

### 3. **OEliteApiOutputFormatter Integration**

Entity collections automatically integrate with `OEliteApiOutputFormatter`:

```json
// Automatic response wrapping by OEliteApiOutputFormatter
{
    "success": true,
    "data": {
        "totalRecordsCount": 150,
        "metaData": {
            "searchTerm": "laptop",
            "category": "electronics"
        },
        "baseEntityTypeName": "Product",
        "items": [
            {
                "id": "507f1f77bcf86cd799439011",
                "name": "Gaming Laptop",
                "price": 1299.99
            }
        ]
    },
    "timestamp": "2025-01-15T10:30:00Z"
}
```

## Service Layer Implementation

### 1. **Repository Pattern**

Services should return entity collections from repositories:

```csharp
public interface IProductService
{
    Task<ProductCollection> GetProductsAsync(ProductQuery query);
    Task<Product> GetByIdAsync(string id);
}

public class ProductService : IProductService
{
    public async Task<ProductCollection> GetProductsAsync(ProductQuery query)
    {
        // Repository returns the appropriate collection type
        return await _productRepository.GetCollectionAsync(query);
    }
}
```

### 2. **Repository Implementation**

Repositories should have dedicated methods for collection returns:

```csharp
public interface IProductRepository : IGenericRepository<Product>
{
    Task<ProductCollection> GetCollectionAsync(ProductQuery query);
}

public class ProductRepository : GenericRepository<Product>, IProductRepository
{
    public async Task<ProductCollection> GetCollectionAsync(ProductQuery query)
    {
        var filter = BuildFilter(query);
        var products = await GetAsync(filter, query.Skip, query.Take, query.OrderBy);
        var totalCount = await CountAsync(filter);

        return new ProductCollection()
            .SetTotalRecordsCount(totalCount)
            .AddEntities(products);
    }
}
```

## Collection Naming Conventions

### 1. **Naming Pattern**

Collections MUST follow the pattern: `{TypeName}Collection`

```csharp
// ✅ CORRECT naming for BaseEntity objects
public class MerchantCollection : BaseEntityCollection<Merchant> { }
public class ProductCollection : BaseEntityCollection<Product> { }
public class CustomerCollection : BaseEntityCollection<Customer> { }
public class OrderCollection : BaseEntityCollection<Order> { }

// ✅ CORRECT naming for DTO objects
public class CartItemDtoCollection : DataCollection<CartItemDto> { }
public class OrderSummaryDtoCollection : DataCollection<OrderSummaryDto> { }
public class ProductSearchResultDtoCollection : DataCollection<ProductSearchResultDto> { }

// ✅ CORRECT naming for other non-BaseEntity classes
public class OrderStatusCollection : DataCollection<OrderStatus> { } // Enum collections
public class PaymentMethodCollection : DataCollection<PaymentMethod> { } // Value objects
public class ShippingRateCollection : DataCollection<ShippingRate> { } // Configuration objects

// ❌ INCORRECT naming
public class MerchantList : BaseEntityCollection<Merchant> { }
public class ProductResults : DataCollection<ProductDto> { }
public class Customers : BaseEntityCollection<Customer> { }
public class CartItems : DataCollection<CartItemDto> { }
```

### 2. **File Organization**

Collections should be organized alongside their corresponding types:

```
helios/core/OElite.Common/Domain/Entities/
├── Merchant.cs
├── MerchantCollection.cs
├── Product.cs
├── ProductCollection.cs
├── Customer.cs
├── CustomerCollection.cs

helios/core/OElite.Common/Domain/DTOs/
├── CartItemDto.cs
├── CartItemDtoCollection.cs
├── OrderSummaryDto.cs
├── OrderSummaryDtoCollection.cs
├── ProductSearchResultDto.cs
├── ProductSearchResultDtoCollection.cs
```

## Migration Guide

### 1. **From PagedResult<T>**

Replace existing `PagedResult<T>` implementations:

```csharp
// ❌ OLD - PagedResult pattern
public class PagedResult<T>
{
    public List<T> Data { get; set; } = new();
    public PaginationInfo Pagination { get; set; } = new();
}

// ✅ NEW - Strongly typed collection
public class ProductCollection : BaseEntityCollection<Product>
{
    // All pagination info inherited from BaseEntityCollection
}
```

### 2. **Controller Migration**

Update controller methods:

```csharp
// ❌ OLD - Generic PagedResult
[HttpGet]
public async Task<PagedResult<Product>> GetProducts([FromQuery] ProductQuery query)
{
    return await _service.GetProductsAsync(query);
}

// ✅ NEW - Strongly typed collection
[HttpGet]
[ProducesResponseType(typeof(ProductCollection), 200)]
public async Task<ProductCollection> GetProducts([FromQuery] ProductQuery query)
{
    return await _service.GetProductsAsync(query);
}
```

### 3. **Service Layer Migration**

Update service signatures:

```csharp
// ❌ OLD
Task<PagedResult<Product>> GetProductsAsync(ProductQuery query);

// ✅ NEW
Task<ProductCollection> GetProductsAsync(ProductQuery query);
```

## Advanced Patterns

### 1. **Collection-Specific Metadata**

Add collection-specific computed properties:

```csharp
public class OrderCollection : BaseEntityCollection<Order>
{
    public decimal TotalOrderValue => this.Sum(o => o.Total);
    public int PendingOrdersCount => this.Count(o => o.Status == OrderStatus.Pending);
    public DateTime? OldestOrderDate => this.Min(o => o.CreatedOnUtc);
}
```

### 2. **Nested Collections**

For related data, use denormalized collections:

```csharp
public class CustomerCollection : BaseEntityCollection<Customer>
{
    // Each customer can have denormalized recent orders
    // This follows the DenormalizedCollection pattern from 03-DATABASE-ENTITIES.md
}
```

### 3. **Search Result Collections**

For search-specific metadata:

```csharp
public class ProductSearchCollection : BaseEntityCollection<Product>
{
    public string SearchTerm { get; set; } = string.Empty;
    public List<string> AppliedFilters { get; set; } = new();
    public Dictionary<string, int> FacetCounts { get; set; } = new();
}
```

## Validation Rules

### 1. **Compilation Checks**

- All entity collections MUST inherit from `BaseEntityCollection<T>`
- Entity collections MUST be strongly typed (not generic)
- Controller methods returning collections MUST use entity collection types
- `[ProducesResponseType]` MUST specify the entity collection type for 200 responses

### 2. **Runtime Checks**

- Collections MUST set `TotalRecordsCount` property
- Collections SHOULD include relevant metadata for client consumption
- Collections MUST NOT exceed reasonable size limits (use proper pagination)

## Benefits

1. **Type Safety**: Compile-time checking of collection operations
2. **IntelliSense**: Better IDE support for collection-specific properties
3. **Consistency**: Standardized approach across all API endpoints
4. **Extensibility**: Easy to add collection-specific logic and metadata
5. **Documentation**: Clear Swagger documentation with proper types
6. **Performance**: Optimized serialization with known types

## Common Mistakes to Avoid

1. **Using generic collections in public APIs**
2. **Mixing collection patterns within the same project**
3. **Forgetting to set TotalRecordsCount**
4. **Not using ProducesResponseType with collection types**
5. **Creating bespoke collection classes instead of inheriting from BaseEntityCollection**

---

**Next Steps**: Review existing APIs and migrate all `PagedResult<T>`, `List<T>`, and bespoke collection implementations to follow this standard.