# Database Entities & Attributes Standards

## Overview

The OElite platform uses an advanced entity mapping system with MongoDB integration, featuring sophisticated denormalized field management, `@` parameter substitution, and cascade update patterns. This document establishes the mandatory standards for entity definitions, database attributes, and data synchronization patterns across all OElite applications.

## Entity Base Classes and Inheritance

### 1. **BaseEntity Pattern** (Mandatory)
All domain entities MUST inherit from `BaseEntity` to ensure consistent identity, auditing, and lifecycle management.

```csharp
// ✅ Required inheritance pattern
[DbCollection("products")]
public class Product : BaseEntity
{
    [DbField("name")]
    public string Name { get; set; }

    [DbField("description")]
    public string Description { get; set; }

    [DbField("price")]
    public decimal Price { get; set; }

    [DbField("categoryId")]
    public string CategoryId { get; set; }

    [DbField("isActive")]
    public bool IsActive { get; set; } = true;

    // Business logic methods
    public bool IsAvailableForPurchase()
    {
        return IsActive && Price > 0;
    }
}

// ❌ Wrong - Not inheriting from BaseEntity
public class Product
{
    public string Id { get; set; }  // Missing audit fields, inconsistent ID handling
    public string Name { get; set; }
}
```

### 2. **BaseEntity Features**
The `BaseEntity` provides essential functionality for all entities:

```csharp
// BaseEntity provides:
public abstract class BaseEntity
{
    [DbField("_id")]
    public string Id { get; set; } = ObjectId.GenerateNewId().ToString();

    [DbField("createdOnUtc")]
    public DateTime CreatedOnUtc { get; set; } = DateTime.UtcNow;

    [DbField("lastModifiedOnUtc")]
    public DateTime LastModifiedOnUtc { get; set; } = DateTime.UtcNow;

    [DbField("version")]
    public long Version { get; set; } = 1;

    [DbField("isDeleted")]
    public bool IsDeleted { get; set; } = false;

    // Soft delete support
    public void MarkAsDeleted()
    {
        IsDeleted = true;
        LastModifiedOnUtc = DateTime.UtcNow;
    }
}
```

## Database Collection Attributes

### 1. **DbCollection Attribute** (Mandatory)
Every entity class MUST have the `[DbCollection]` attribute specifying the MongoDB collection name.

```csharp
// ✅ Required collection attribute
[DbCollection("products")]
public class Product : BaseEntity
{
    // Entity properties
}

[DbCollection("orders")]
public class Order : BaseEntity
{
    // Entity properties
}

[DbCollection("customers")]
public class Customer : BaseEntity
{
    // Entity properties
}

// ❌ Wrong - Missing DbCollection attribute
public class Product : BaseEntity
{
    // Will cause runtime errors
}
```

### 2. **Collection Naming Conventions**
- Use **lowercase** collection names
- Use **plural** forms (products, orders, customers)
- Use **snake_case** for multi-word collections (product_categories, shipping_methods)

```csharp
// ✅ Good collection names
[DbCollection("products")]
[DbCollection("product_categories")]
[DbCollection("shipping_methods")]
[DbCollection("payment_transactions")]

// ❌ Bad collection names
[DbCollection("Product")]          // Not lowercase
[DbCollection("product")]          // Not plural
[DbCollection("product-categories")]  // Use snake_case, not kebab-case
```

## Database Field Attributes

### 1. **DbField Attribute** (Optional When Names Match)
The `[DbField]` attribute is **optional** when the property name matches the MongoDB field name in snake_case. Only specify it when the field name differs.

```csharp
// ✅ Optimal field attributes (only when names differ)
[DbCollection("products")]
public class Product : BaseEntity
{
    // No DbField needed - "name" property maps to "name" field
    public string Name { get; set; }

    // No DbField needed - "description" property maps to "description" field
    public string Description { get; set; }

    // No DbField needed - "price" property maps to "price" field
    public decimal Price { get; set; }

    // DbField needed - property is PascalCase but field is snake_case
    [DbField("category_id")]
    public string CategoryId { get; set; }

    // No DbField needed - "tags" property maps to "tags" field
    public List<string> Tags { get; set; } = new();

    // No DbField needed - "specifications" property maps to "specifications" field
    public Dictionary<string, object> Specifications { get; set; } = new();

    // DbField needed - property is PascalCase but field is snake_case
    [DbField("created_by")]
    public string CreatedBy { get; set; }
}

// ❌ Wrong - Unnecessary DbField attributes when names match
[DbCollection("products")]
public class Product : BaseEntity
{
    [DbField("name")]               // Unnecessary - property name matches field name
    public string Name { get; set; }

    [DbField("price")]              // Unnecessary - property name matches field name
    public decimal Price { get; set; }
}
```

### 2. **Field Naming Conventions**
- Use **snake_case** for MongoDB field names when property names are PascalCase
- Use **lowercase** for simple field names
- Be explicit and descriptive
- Avoid abbreviations unless universally understood

```csharp
// ✅ Good field names (when DbField is needed)
[DbField("product_name")]      // PascalCase property → snake_case field
[DbField("unit_price")]        // PascalCase property → snake_case field
[DbField("category_id")]       // PascalCase property → snake_case field
[DbField("is_available")]      // PascalCase property → snake_case field
[DbField("created_on_utc")]    // PascalCase property → snake_case field
[DbField("shipping_address")]  // PascalCase property → snake_case field

// ✅ Good field names (no DbField needed when names match)
public string name { get; set; }           // Lowercase property matches field
public decimal price { get; set; }         // Lowercase property matches field
public List<string> tags { get; set; }     // Lowercase property matches field

// ❌ Bad field names
[DbField("prc")]               // Abbreviated
[DbField("ProductName")]       // PascalCase in database
[DbField("product-name")]      // Kebab-case not allowed
```

## Advanced Denormalized Field System

### 1. **DenormalizedField Attribute** (Core Innovation)
Use `[DenormalizedField]` for automatic data population from related collections with `@` parameter substitution.

```csharp
// ✅ Simple denormalized field
[DbCollection("orders")]
public class Order : BaseEntity
{
    [DbField("customerId")]
    public string CustomerId { get; set; }

    [DbField("productId")]
    public string ProductId { get; set; }

    // Automatic population from customers collection
    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Name)]
    public string CustomerName { get; set; }

    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Email)]
    public string CustomerEmail { get; set; }

    // Product information denormalization
    [DenormalizedField(DbSchema.Products.Name, DbSchema.Products.Fields.Name)]
    public string ProductName { get; set; }

    [DenormalizedField(DbSchema.Products.Name, DbSchema.Products.Fields.Price)]
    public decimal ProductPrice { get; set; }
}
```

### 2. **Advanced Query-Based Denormalization with @ Parameters**
Use `@` parameters for dynamic query-based denormalization:

```csharp
// ✅ Advanced denormalized fields with @ parameter substitution
[DbCollection("customers")]
public class Customer : BaseEntity
{
    [DbField("name")]
    public string Name { get; set; }

    [DbField("email")]
    public string Email { get; set; }

    [DbField("addressId")]
    public string AddressId { get; set; }

    // Query-based denormalization with @ parameter
    [DenormalizedField("addresses", new RestmeSimpleQuery("{ '_id': @AddressId }"))]
    public Address PrimaryAddress { get; set; }

    // Complex query with multiple conditions
    [DenormalizedField("orders",
        new RestmeSimpleQuery("{ 'customerId': @Id, 'status': { '$in': [10, 20] } }"),
        limit: 5)]
    public List<Order> RecentActiveOrders { get; set; }

    // Aggregation-based denormalization
    [DenormalizedField("orders",
        new RestmeSimpleQuery("{ 'customerId': @Id }"),
        aggregation: "{ '$group': { '_id': null, 'totalSpent': { '$sum': '$total' } } }")]
    public decimal TotalLifetimeSpent { get; set; }
}
```

### 3. **DenormalizedCollection Attribute**
Use `[DenormalizedCollection]` for automatic population of related entity collections:

```csharp
// ✅ Denormalized collection with filtering and sorting
[DbCollection("categories")]
public class Category : BaseEntity
{
    [DbField("name")]
    public string Name { get; set; }

    [DbField("description")]
    public string Description { get; set; }

    // Products in this category with advanced filtering
    [DenormalizedCollection("products",
        "{ 'categoryId': @Id, 'isActive': true, 'stock': { '$gt': 0 } }",
        limit: 20,
        orderBy: "{ 'createdOnUtc': -1 }")]
    public List<Product> ActiveProducts { get; set; } = new();

    // Top-selling products in category
    [DenormalizedCollection("products",
        "{ 'categoryId': @Id, 'isActive': true }",
        limit: 10,
        orderBy: "{ 'salesCount': -1 }")]
    public List<Product> TopSellingProducts { get; set; } = new();

    // Category statistics via aggregation
    [DenormalizedCollection("products",
        "{ 'categoryId': @Id }",
        aggregation: "{ '$group': { '_id': null, 'count': { '$sum': 1 }, 'avgPrice': { '$avg': '$price' } } }")]
    public CategoryStatistics Statistics { get; set; }
}
```

## Schema Constants and Organization

### 1. **DbSchema Static Class Organization**
Organize database schema constants for consistency and refactoring safety:

```csharp
// ✅ Required schema organization
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
            public const string Price = "price";
            public const string CategoryId = "category_id";
            public const string IsActive = "is_active";
            public const string Tags = "tags";
            public const string CreatedOnUtc = "created_on_utc";
        }
    }

    public static class Orders
    {
        public const string Name = "orders";

        public static class Fields
        {
            public const string Id = "_id";
            public const string CustomerId = "customer_id";
            public const string Status = "status";
            public const string Total = "total";
            public const string Items = "items";
            public const string CreatedOnUtc = "created_on_utc";
        }
    }

    public static class Customers
    {
        public const string Name = "customers";

        public static class Fields
        {
            public const string Id = "_id";
            public const string Name = "name";
            public const string Email = "email";
            public const string Phone = "phone";
            public const string IsActive = "is_active";
        }
    }
}
```

### 2. **Using Schema Constants in Entities**
```csharp
// ✅ Using schema constants for consistency
[DbCollection(DbSchema.Orders.Name)]
public class Order : BaseEntity
{
    [DbField(DbSchema.Orders.Fields.CustomerId)]
    public string CustomerId { get; set; }

    [DbField(DbSchema.Orders.Fields.Status)]
    public OrderStatus Status { get; set; }

    [DbField(DbSchema.Orders.Fields.Total)]
    public decimal Total { get; set; }

    // Denormalized fields using schema constants
    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Name)]
    public string CustomerName { get; set; }

    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Email)]
    public string CustomerEmail { get; set; }
}
```

## MongoDB Integration Patterns

### 1. **Complex Data Types**
Handle complex MongoDB data types properly:

```csharp
// ✅ Complex data type handling
[DbCollection("products")]
public class Product : BaseEntity
{
    [DbField("specifications")]
    public Dictionary<string, object> Specifications { get; set; } = new();

    [DbField("images")]
    public List<ProductImage> Images { get; set; } = new();

    [DbField("pricing")]
    public PricingInformation Pricing { get; set; }

    [DbField("inventory")]
    public InventoryDetails Inventory { get; set; }

    [DbField("metadata")]
    public BsonDocument Metadata { get; set; }
}

// Nested objects
public class ProductImage
{
    [DbField("url")]
    public string Url { get; set; }

    [DbField("altText")]
    public string AltText { get; set; }

    [DbField("isPrimary")]
    public bool IsPrimary { get; set; }

    [DbField("displayOrder")]
    public int DisplayOrder { get; set; }
}

public class PricingInformation
{
    [DbField("basePrice")]
    public decimal BasePrice { get; set; }

    [DbField("salePrice")]
    public decimal? SalePrice { get; set; }

    [DbField("currencyCode")]
    public string CurrencyCode { get; set; }

    [DbField("taxIncluded")]
    public bool TaxIncluded { get; set; }
}
```

### 2. **Index Specifications**
Define indexes using attributes:

```csharp
// ✅ Index specifications
[DbCollection("products")]
[DbIndex("{ 'categoryId': 1, 'isActive': 1 }", Name = "idx_category_active")]
[DbIndex("{ 'name': 'text', 'description': 'text' }", Name = "idx_text_search")]
[DbIndex("{ 'price': 1 }", Name = "idx_price")]
[DbIndex("{ 'createdOnUtc': -1 }", Name = "idx_created_desc")]
public class Product : BaseEntity
{
    // Entity properties
}
```

## Data Validation and Business Rules

### 1. **Entity-Level Validation**
Implement validation directly in entities:

```csharp
// ✅ Entity validation patterns
[DbCollection("products")]
public class Product : BaseEntity, IValidatableObject
{
    [DbField("name")]
    [Required(ErrorMessage = "Product name is required")]
    [StringLength(100, ErrorMessage = "Product name cannot exceed 100 characters")]
    public string Name { get; set; }

    [DbField("price")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Price must be greater than 0")]
    public decimal Price { get; set; }

    [DbField("categoryId")]
    [Required(ErrorMessage = "Category is required")]
    public string CategoryId { get; set; }

    [DbField("weight")]
    [Range(0, double.MaxValue, ErrorMessage = "Weight cannot be negative")]
    public decimal? Weight { get; set; }

    // Custom validation logic
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Price > 0 && Weight.HasValue && Weight.Value == 0)
        {
            yield return new ValidationResult(
                "Products with a price must have a weight greater than 0",
                new[] { nameof(Weight) });
        }

        if (Name?.ToLower().Contains("test") == true && Price > 100)
        {
            yield return new ValidationResult(
                "Test products cannot have a price greater than 100",
                new[] { nameof(Price), nameof(Name) });
        }
    }

    // Business rule validation
    public bool IsValidForSale()
    {
        return !string.IsNullOrWhiteSpace(Name) &&
               Price > 0 &&
               !string.IsNullOrWhiteSpace(CategoryId) &&
               IsActive &&
               !IsDeleted;
    }
}
```

### 2. **Enum Handling**
Properly handle enums in MongoDB entities:

```csharp
// ✅ Enum handling patterns
[DbCollection("orders")]
public class Order : BaseEntity
{
    [DbField("status")]
    [BsonRepresentation(BsonType.String)]  // Store as string for readability
    public OrderStatus Status { get; set; }

    [DbField("paymentMethod")]
    [BsonRepresentation(BsonType.Int32)]   // Store as integer for performance
    public PaymentMethod PaymentMethod { get; set; }
}

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
    PayPal = 2,
    BankTransfer = 3,
    Cash = 4
}
```

## Cascade Updates and Data Synchronization

### 1. **Cascade Update Patterns**
Design entities to support automatic cascade updates:

```csharp
// ✅ Cascade update support
[DbCollection("products")]
public class Product : BaseEntity
{
    public string Name { get; set; }

    [DbField("category_id")]
    public string CategoryId { get; set; }

    // Business logic methods
    public bool IsAvailableForPurchase()
    {
        return IsActive && !IsDeleted && Name != null;
    }

    public void UpdateCategory(string newCategoryId)
    {
        if (string.IsNullOrWhiteSpace(newCategoryId))
            throw new ArgumentException("Category ID cannot be empty");

        CategoryId = newCategoryId;
        LastModifiedOnUtc = DateTime.UtcNow;
    }
}

[DbCollection("orders")]
public class Order : BaseEntity
{
    [DbField("productId")]
    public string ProductId { get; set; }

    // Will be automatically updated when Product.Name changes
    [DenormalizedField(DbSchema.Products.Name, DbSchema.Products.Fields.Name)]
    [CascadeUpdate(triggerField: "productId", targetCollection: "products")]
    public string ProductName { get; set; }
}
```

### 2. **Data Sync Strategy Integration**
Support for OElite.Runners.DataSync integration:

```csharp
// ✅ Data sync strategy support
[DbCollection("customers")]
[DataSyncStrategy(typeof(CustomerDataSyncStrategy))]
public class Customer : BaseEntity
{
    [DbField("name")]
    [SyncTrigger] // Changes to this field trigger sync
    public string Name { get; set; }

    [DbField("email")]
    [SyncTrigger]
    public string Email { get; set; }

    [DbField("isActive")]
    [SyncTrigger]
    public bool IsActive { get; set; }

    // Fields that DON'T trigger sync
    [DbField("lastLoginUtc")]
    public DateTime? LastLoginUtc { get; set; }

    [DbField("loginCount")]
    public int LoginCount { get; set; }
}
```

## Performance Optimization Patterns

### 1. **Lazy Loading Configuration**
Configure lazy loading for denormalized fields:

```csharp
// ✅ Lazy loading configuration
[DbCollection("orders")]
public class Order : BaseEntity
{
    [DbField("customerId")]
    public string CustomerId { get; set; }

    // Always loaded (essential data)
    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Name)]
    public string CustomerName { get; set; }

    // Lazy loaded (optional data)
    [DenormalizedField(DbSchema.Customers.Name, DbSchema.Customers.Fields.Address, lazy: true)]
    public Address CustomerAddress { get; set; }

    // Lazy loaded collection (expensive data)
    [DenormalizedCollection("order-items",
        "{ 'orderId': @Id }",
        lazy: true,
        limit: 100)]
    public List<OrderItem> Items { get; set; }
}
```

### 2. **Selective Field Loading**
Support selective field loading for performance:

```csharp
// ✅ Selective field loading
public class ProductRepository : DataRepository<Product>, IProductRepository
{
    // Load only essential fields for listing
    public async Task<List<Product>> GetProductSummariesAsync()
    {
        var projection = new[]
        {
            DbSchema.Products.Fields.Id,
            DbSchema.Products.Fields.Name,
            DbSchema.Products.Fields.Price,
            DbSchema.Products.Fields.IsActive
        };

        return await GetAllAsync(filter: "{ 'isActive': true }", projection: projection);
    }

    // Load full product with all denormalized data
    public async Task<Product> GetProductWithFullDetailsAsync(string id)
    {
        return await GetByIdAsync(id, includeRelated: true, includeLazy: true);
    }
}
```

## Error Handling and Diagnostics

### 1. **Entity State Validation**
```csharp
// ✅ Entity state validation
[DbCollection("products")]
public class Product : BaseEntity
{
    // Validate entity state before operations
    public void ValidateForCreate()
    {
        if (string.IsNullOrWhiteSpace(Name))
            throw new EntityValidationException("Product name is required for creation");

        if (Price <= 0)
            throw new EntityValidationException("Product price must be greater than 0");

        if (string.IsNullOrWhiteSpace(CategoryId))
            throw new EntityValidationException("Product must belong to a category");
    }

    public void ValidateForUpdate()
    {
        ValidateForCreate(); // Same rules apply

        if (string.IsNullOrWhiteSpace(Id))
            throw new EntityValidationException("Product ID is required for update");

        if (Version <= 0)
            throw new EntityValidationException("Product version must be positive");
    }
}
```

### 2. **Denormalization Health Checks**
```csharp
// ✅ Denormalization health monitoring
[DbCollection("orders")]
public class Order : BaseEntity
{
    [DenormalizedField(DbSchema.Products.Name, DbSchema.Products.Fields.Name)]
    [HealthCheck(checkInterval: TimeSpan.FromHours(24))]
    public string ProductName { get; set; }

    // Validate denormalized data consistency
    public async Task<bool> ValidateDenormalizedDataAsync(IProductRepository productRepository)
    {
        if (string.IsNullOrWhiteSpace(ProductId) || string.IsNullOrWhiteSpace(ProductName))
            return true; // Nothing to validate

        var product = await productRepository.GetByIdAsync(ProductId);
        if (product == null)
        {
            // Product was deleted - order needs update
            return false;
        }

        return product.Name == ProductName;
    }
}
```

## Compliance Checklist

### Entity Structure Requirements
- [ ] All entities inherit from `BaseEntity`
- [ ] All entities have `[DbCollection]` attribute with correct collection name
- [ ] All properties have `[DbField]` attribute with correct field name
- [ ] Collection names use lowercase, plural, kebab-case conventions
- [ ] Field names use camelCase conventions
- [ ] Schema constants are defined and used consistently

### Denormalized Field Requirements
- [ ] Denormalized fields use `[DenormalizedField]` or `[DenormalizedCollection]` attributes
- [ ] Complex queries use `@` parameter substitution correctly
- [ ] Cascade update patterns are implemented where needed
- [ ] Performance considerations (lazy loading, selective loading) are addressed
- [ ] Data sync strategies are configured for critical entities

### Validation and Business Rules
- [ ] Entity validation uses data annotations and `IValidatableObject`
- [ ] Business rule methods are implemented in entities
- [ ] Enum handling uses appropriate `BsonRepresentation`
- [ ] Index specifications are defined using `[DbIndex]` attributes
- [ ] Error handling includes entity-specific validation methods

### Performance and Monitoring
- [ ] Large collections use pagination and limits
- [ ] Expensive denormalized fields use lazy loading
- [ ] Health checks are implemented for critical denormalized data
- [ ] Projection queries are used for list/summary operations
- [ ] Database indexes are properly configured and documented

This database entity framework ensures consistent, performant, and maintainable data access patterns across the entire OElite platform while leveraging advanced MongoDB capabilities and denormalized field management.