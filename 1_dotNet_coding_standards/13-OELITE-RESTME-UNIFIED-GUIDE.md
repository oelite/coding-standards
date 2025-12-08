# OElite.Restme Unified Development Guide

## Overview

OElite.Restme is a powerful, modular .NET library that provides a unified interface for HTTP requests, caching, message queuing, cloud storage operations, and database management. Built with modern .NET and designed for simplicity, performance, and flexibility.

## 🚀 Key Features

- **Unified API**: Single `Rest` class for all operations
- **Named Provider Support**: Multiple provider instances of the same type with `GetProvider<T>(string name)`
- **Modular Architecture**: Load only the backends you need
- **Multiple Backend Support**: Redis, RabbitMQ, Azure Blob Storage, S3-compatible providers, ClickHouse, Kafka, OpenSearch, MongoDB
- **Cache Providers**: Redis, Azure Blob Storage, S3 (perfect for CDN scenarios)
- **Analytics & Search**: ClickHouse for time-series analytics, OpenSearch for full-text search
- **MongoDB-Free Application Layer**: Complete abstraction eliminates MongoDB dependencies from application code
- **Region-Aware Sharding**: GDPR compliance with geographic data placement
- **Zero Vendor Lock-in**: Application developers work with pure .NET types and collections

## 📦 Package Structure

### Core Packages
- **OElite.Restme** - Core abstractions and HTTP client
- **OElite.Restme.Utils** - Utility extensions and helpers
- **OElite.Restme.Hosting** - ASP.NET Core integration extensions

### Backend Providers
- **OElite.Restme.Redis** - Redis cache and queue provider
- **OElite.Restme.RabbitMQ** - RabbitMQ message queue provider
- **OElite.Restme.Azure** - Azure Blob Storage provider
- **OElite.Restme.S3** - S3-compatible storage provider
- **OElite.Restme.MongoDb** - MongoDB operations and aggregation (MongoDB-free API)
- **OElite.Restme.ClickHouse** - Columnar analytics provider
- **OElite.Restme.Kafka** - Streaming provider
- **OElite.Restme.OpenSearch** - Search provider

### Integration Packages
- **OElite.Restme.RateLimiting** - Advanced rate limiting middleware
- **OElite.Restme.GoogleUtils** - Google Cloud integrations

## Development Standards

### 1. Provider Pattern Usage

#### ✅ Correct: Use Provider Pattern
```csharp
// Get specific provider for focused operations
var httpProvider = rest.GetProvider<IHttpProvider>();
var user = await httpProvider.GetAsync<User>("/users/123");

var cacheProvider = rest.GetProvider<ICacheProvider>();
await cacheProvider.SetAsync("user:123", userData, TimeSpan.FromMinutes(60));

var storageProvider = rest.GetProvider<IStorageProvider>();
await storageProvider.PutAsync("documents/report.pdf", fileData);
```

#### ❌ Wrong: Direct Rest Operations (Legacy)
```csharp
// Avoid direct operations on Rest class for specific provider tasks
var user = await rest.GetAsync<User>("/users/123"); // Less clear which provider
```

### 2. Named Providers for Multi-Instance Scenarios

#### ✅ Correct: Named Providers
```csharp
// Create Rest instance
var rest = new Rest("redis://localhost:6379", new RestConfig { OperationMode = RestMode.Redis });

// Get named providers for different purposes
var userCache = rest.GetProvider<ICacheProvider>("users");
var sessionCache = rest.GetProvider<ICacheProvider>("sessions");
var apiCache = rest.GetProvider<ICacheProvider>("api-responses");

// Use different cache providers for logical separation
await userCache.SetAsync("user:123", userData, TimeSpan.FromMinutes(30));
await sessionCache.SetAsync("session:abc123", sessionData, TimeSpan.FromHours(24));
```

### 3. Configuration Standards

#### ✅ Correct: RestConfig Pattern (Recommended)
```csharp
// Use RestConfig for better maintainability and security
var config = new RestConfig
{
    AuthKey = "username/account/id",        // Provider-specific username/account
    AuthSecret = "password/secret/key",     // Provider-specific password/secret
    Endpoint = "https://service.endpoint",  // Service endpoint (optional)
    Region = "us-east-1",                   // Region for cloud services (optional)
    BucketName = "my-bucket",               // Bucket/container name (optional)
    RootPath = "my-app/data",               // Logical path prefix (optional)
    OperationMode = RestMode.Redis
};
var rest = new Rest("redis://localhost:6379", config);
```

#### ❌ Discouraged: Legacy Connection Strings
```csharp
// Still supported but less maintainable
var rest = new Rest("redis://localhost:6379,password=your-password", RestMode.Redis);
```

### 4. MongoDB Integration Standards

#### ✅ Correct: MongoDB-Free Application Layer
```csharp
// Use IMongoDbCollection interface - no MongoDB dependencies
public async Task<List<Product>> GetActiveProducts()
{
    var productsCollection = DbCentre.GetMongoDbCollection<Product>();

    // Lambda expressions - no MongoDB types needed
    return await productsCollection.FindAsync(p => p.Status == EntityStatus.Active);
}

// Dictionary-based filters for dynamic queries
public async Task<List<Product>> GetProductsByCategory(string categoryName)
{
    var productsCollection = DbCentre.GetMongoDbCollection<Product>();

    var filter = new Dictionary<string, object>
    {
        ["categoryName"] = categoryName,
        ["status"] = (int)EntityStatus.Active
    };

    return await productsCollection.FindAsync(filter);
}
```

#### ✅ Correct: MongoDbDocument API (Replaces BsonDocument)
```csharp
// Use MongoDbDocument instead of BsonDocument
public async Task<List<MongoDbDocument>> GetProductDocuments(string searchTerm)
{
    var collection = DbCentre.GetMongoDbCollection("products");

    // Create filter using MongoDbDocument
    var filter = new MongoDbDocument
    {
        ["name"] = new MongoDbDocument { ["$regex"] = searchTerm, ["$options"] = "i" },
        ["status"] = 1
    };

    // Returns pure .NET types, no MongoDB dependencies
    return await collection.FindAsync(filter);
}
```

#### ❌ Wrong: Direct MongoDB Dependencies
```csharp
using MongoDB.Driver;  // ❌ Avoid direct MongoDB dependencies in application layer
using MongoDB.Bson;    // ❌ Exposes internal types

// Don't use BsonDocument directly in application code
public async Task<List<BsonDocument>> GetReports() // ❌ MongoDB types in return signature
{
    // Application code should be MongoDB-agnostic
}
```

### 5. Region-Aware Data Management

#### ✅ Correct: GDPR Compliance
```csharp
[DbCollection("customers", DbNamingConvention.SnakeCase)]
public class Customer : BaseEntity
{
    public string Email { get; set; } = string.Empty;
    public string FirstName { get; set; } = string.Empty;

    // Region field controls geographic data placement for GDPR compliance
    // Automatically inherited from BaseEntity
    // public string? Region { get; set; } // from BaseEntity
}

// Entity automatically placed in correct geographic zone
var customer = new Customer
{
    Email = "user@example.com",
    FirstName = "John",
    Region = "EU" // Ensures data stays in European jurisdiction
};
```

### 6. Enhanced LINQ and High-Performance Operations

#### ✅ Correct: MongoQuery Pattern
```csharp
public class ProductRepository : DataRepository
{
    public MongoQuery<Product> Products => new(_adapter.GetCollection<Product>());

    // Enhanced LINQ queries with extension method support
    public async Task<List<Product>> GetExpensiveProductsAsync(decimal minPrice)
    {
        return await Products
            .Where(p => p.Price > minPrice)
            .Where(p => p.Name.IsNotNullOrEmpty()) // Extension method support
            .OrderByDescending(p => p.Price)
            .Take(10)
            .ToListAsync();
    }

    // High-performance updates with fluent API
    public async Task UpdateProductAsync(DbObjectId productId, string newName, decimal newPrice)
    {
        await Products
            .Where(p => p.Id == productId)
            .UpdateAsync(u => u
                .Set(p => p.Name, newName)
                .Set(p => p.Price, newPrice)
                .Inc(p => p.ViewCount, 1)
                .CurrentDate(p => p.UpdatedAt));
    }

    // Performance-optimized collection fetching
    public async Task<ProductCollection> GetActiveProductsAsync(int pageIndex, int pageSize)
    {
        return await Products
            .Where(p => p.Status == EntityStatus.Active)
            .OrderBy(p => p.Name)
            .FetchAsync<Product, ProductCollection>(pageIndex, pageSize, returnTotalCount: false);
    }
}
```

### 7. Cache Extension Methods

#### ✅ Correct: Enhanced Caching with Grace Periods
```csharp
// Store with expiry and grace period
var cacheProvider = rest.GetProvider<ICacheProvider>();
var success = await cacheProvider.CachemeAsync("user:123", userData, expiryInSeconds: 3600);

// Retrieve with validation and refresh action
var user = await cacheProvider.FindmeAsync<User>("user:123",
    additionalValidation: async (u) => u.IsActive && u.LastLoginDate > DateTime.UtcNow.AddDays(-30),
    refreshAction: async () => await userService.GetUserFromDatabaseAsync(123));

// Force expiry
await cacheProvider.ExpiremeAsync("user:123");

// Using query objects as keys (MD5 hash generated automatically)
var query = new { UserId = 123, IncludeProfile = true };
await cacheProvider.CachemeAsync(query, userData, expiryInSeconds: 1800);
```

### 8. HTTP Provider Patterns

#### ✅ Correct: Enhanced HTTP Operations
```csharp
// Get HTTP provider using modern provider pattern
var httpProvider = rest.GetProvider<IHttpProvider>();

// Basic operations
var user = await httpProvider.GetAsync<User>("/users/123");
var newUser = await httpProvider.PostAsync<User>("/users", userData);

// Enhanced requests with full response details
var response = await httpProvider.HttpRequestFullWithDetailsAsync<User>(
    HttpMethod.Get, "/users/123");

if (response?.Data != null)
{
    Console.WriteLine($"Status: {response.StatusCode}");
    Console.WriteLine($"Headers: {response.ResponseHeaders?.Count}");
    Console.WriteLine($"User: {response.Data.Name}");
}
```

### 9. ASP.NET Core Integration

#### ✅ Correct: Hosting Package Integration
```csharp
// Program.cs
builder.Services.AddRestmeRedisCache(options =>
{
    options.ConnectionString = "localhost:6379";
    options.InstanceName = "myapp:";
});

// Service usage with enhanced cache methods
public class ProductService : IOEliteService
{
    private readonly IDistributedCache _cache;

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";

        // Enhanced caching with grace period and background refresh
        var cachedProduct = await _cache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));

        return cachedProduct ?? await _productRepository.GetByIdAsync(id);
    }
}
```

## Error Handling and Best Practices

### 1. Graceful Degradation
```csharp
public async Task<Product?> GetProductAsync(int id)
{
    try
    {
        return await _cache.FindmeAsync<Product>($"product:{id}");
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Cache error for product {ProductId}", id);
        return await _repository.GetByIdAsync(id); // Fallback to database
    }
}
```

### 2. Multi-Tier Architecture
```csharp
public class MultiTierDataService
{
    private readonly ICacheProvider _l1Cache;    // Fast cache
    private readonly ICacheProvider _l2Cache;    // Slower but larger cache
    private readonly IStorageProvider _hotStorage;   // Frequently accessed data
    private readonly IStorageProvider _coldStorage;  // Archival data

    public MultiTierDataService(Rest rest)
    {
        _l1Cache = rest.GetProvider<ICacheProvider>("l1-cache");
        _l2Cache = rest.GetProvider<ICacheProvider>("l2-cache");
        _hotStorage = rest.GetProvider<IStorageProvider>("hot-storage");
        _coldStorage = rest.GetProvider<IStorageProvider>("cold-storage");
    }

    public async Task<T> GetDataAsync<T>(string key) where T : class
    {
        // Try L1 cache first (fastest)
        var l1Data = await _l1Cache.GetAsync<T>(key);
        if (l1Data != null) return l1Data;

        // Try L2 cache
        var l2Data = await _l2Cache.GetAsync<T>(key);
        if (l2Data != null)
        {
            // Store in L1 for next time
            await _l1Cache.SetAsync(key, l2Data, TimeSpan.FromMinutes(5));
            return l2Data;
        }

        // Continue with hot and cold storage...
        return await GetFromStorageAsync<T>(key);
    }
}
```

### 3. Cache Key Naming Conventions
```csharp
// ✅ Good - Consistent, hierarchical naming
var cacheKey = $"product:{id}";
var cacheKey = $"user:{userId}:profile";
var cacheKey = $"category:{categoryId}:products:page:{page}";

// ❌ Bad - Inconsistent naming
var cacheKey = $"Product_{id}";
var cacheKey = $"userProfile{userId}";
```

## Package Selection Guidelines

### For Different Scenarios

1. **Core HTTP only**: Use `OElite.Restme`
2. **ASP.NET Core apps**: Add `OElite.Restme.Hosting`
3. **Caching needs**: Use `OElite.Restme.Redis` or memory providers
4. **Database operations**: Add `OElite.Restme.MongoDb`
5. **API protection**: Include `OElite.Restme.RateLimiting`
6. **Cloud storage**: Add `OElite.Restme.S3` or `OElite.Restme.Azure`
7. **Message queuing**: Use `OElite.Restme.RabbitMQ` or `OElite.Restme.Kafka`
8. **Search capabilities**: Add `OElite.Restme.OpenSearch`
9. **Analytics**: Use `OElite.Restme.ClickHouse`

## Migration from Legacy Patterns

### From MongoDB.Driver Direct Usage
```csharp
// Before (direct MongoDB dependencies)
var collection = _database.GetCollection<BsonDocument>("products");
var pipeline = new BsonDocument[]
{
    new BsonDocument("$match", new BsonDocument("status", "active"))
};

// After (MongoDB-free with OElite.Restme.MongoDb)
var productsCollection = DbCentre.GetMongoDbCollection("products");
var pipeline = new Dictionary<string, object>[]
{
    new Dictionary<string, object> {
        ["$match"] = new Dictionary<string, object> { ["status"] = "active" }
    }
};
```

### From Microsoft.Extensions.Caching
```csharp
// Before (Microsoft caching)
services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
    options.InstanceName = "myapp:";
});

// After (OElite.Restme.Hosting)
services.AddRestmeRedisCache(options =>
{
    options.ConnectionString = "localhost:6379";
    options.InstanceName = "myapp:";
});
```

## Architecture Benefits

- 🎯 **Zero Vendor Lock-in**: Switch databases/providers without changing application logic
- 🧪 **Enhanced Testability**: Mock with standard .NET interfaces and collections
- 📚 **Clean Domain Models**: Business logic free from infrastructure concerns
- 🔄 **Future-Proof**: Provider implementation changes don't affect application code
- 👥 **Developer Experience**: Team members don't need provider-specific expertise
- 🌍 **GDPR Compliance**: Built-in region-aware data placement and management
- ⚡ **Performance**: Provider-optimized implementations with intelligent caching
- 🔧 **Flexibility**: Mix and match providers based on requirements

This unified guide ensures consistent usage of OElite.Restme across all development scenarios while maintaining high performance, compliance, and maintainability.