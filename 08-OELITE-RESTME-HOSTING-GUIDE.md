# OElite.Restme.Hosting Integration Guide

## Overview

OElite.Restme.Hosting provides seamless integration between OElite.Restme's advanced caching capabilities and standard ASP.NET Core caching interfaces (`IDistributedCache` and `IMemoryCache`). This allows developers to use familiar ASP.NET Core patterns while leveraging OElite.Restme's powerful features like grace periods, background refresh, and intelligent caching.

## Key Benefits

- ✅ **Drop-in replacement** for Microsoft.Extensions.Caching packages
- ✅ **Grace period caching** with background refresh capabilities
- ✅ **Enhanced extension methods** with advanced caching patterns
- ✅ **Multi-tier caching** support (distributed + memory)
- ✅ **Seamless migration** from existing Microsoft caching implementations
- ✅ **Consistent OElite patterns** across all caching operations

## Installation

```bash
dotnet add package OElite.Restme.Hosting
```

## Service Registration Patterns

### 1. Redis Distributed Cache

Replace `Microsoft.Extensions.Caching.StackExchangeRedis` with OElite's Redis provider:

```csharp
using OElite.Restme.Hosting.Redis;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Option 1: Simple configuration
        builder.Services.AddRestmeRedisCache(
            connectionString: "localhost:6379",
            instanceName: "myapp:"
        );

        // Option 2: Configuration-based setup
        builder.Services.AddRestmeRedisCache(options =>
        {
            options.ConnectionString = builder.Configuration["oelite:data:redis:platform"];
            options.InstanceName = "myapp:";
        });

        var app = builder.Build();
        app.Run();
    }
}
```

### 2. Memory Cache

Replace `Microsoft.Extensions.Caching.Memory` with OElite's memory provider:

```csharp
using OElite.Restme.Hosting.Memory;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Option 1: IMemoryCache only
        builder.Services.AddRestmeMemoryCache("myapp:");

        // Option 2: Both IMemoryCache and IDistributedCache
        builder.Services.AddRestmeMemoryCacheWithDistributed("myapp:");

        var app = builder.Build();
        app.Run();
    }
}
```

### 3. Hybrid Approach (Recommended)

Use both Redis and Memory caching for optimal performance:

```csharp
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Redis for distributed caching
        builder.Services.AddRestmeRedisCache(options =>
        {
            options.ConnectionString = builder.Configuration["oelite:data:redis:platform"];
            options.InstanceName = "myapp:";
        });

        // Memory cache for local caching
        builder.Services.AddRestmeMemoryCache("myapp:");

        var app = builder.Build();
        app.Run();
    }
}
```

## Usage Patterns

### 1. Basic Caching with Grace Periods

```csharp
public class ProductService : IOEliteService
{
    private readonly IDistributedCache _distributedCache;
    private readonly IMemoryCache _memoryCache;
    private readonly IProductRepository _productRepository;
    private readonly ILogger<ProductService> _logger;

    public ProductService(
        IDistributedCache distributedCache,
        IMemoryCache memoryCache,
        IProductRepository productRepository,
        ILogger<ProductService> logger)
    {
        _distributedCache = distributedCache;
        _memoryCache = memoryCache;
        _productRepository = productRepository;
        _logger = logger;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";

        // Try distributed cache first with grace period
        var cachedProduct = await _distributedCache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,        // Don't return expired data
            returnInGrace: true,         // Return data in grace period
            refreshAction: async () =>   // Background refresh when expired
            {
                _logger.LogInformation("Refreshing product {ProductId} in background", id);
                return await _productRepository.GetByIdAsync(id);
            });

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
            // Cache in both stores with different expiry times
            await _distributedCache.CachemeAsync(cacheKey, product, 
                expiryInSeconds: 3600,  // 1 hour
                graceInSeconds: 300);   // 5 minute grace period

            _memoryCache.CachemeAsync(cacheKey, product, 
                expiryInSeconds: 1800,   // 30 minutes
                graceInSeconds: 180);   // 3 minute grace period
            
            _logger.LogInformation("Product {ProductId} cached in both stores", id);
        }

        return product;
    }
}
```

### 2. Query Object Caching

Cache complex query results using query objects:

```csharp
public class ProductService : IOEliteService
{
    private readonly IDistributedCache _distributedCache;
    private readonly IProductRepository _productRepository;

    public async Task<List<Product>> SearchProductsAsync(ProductSearchRequest request)
    {
        // Create query object for consistent caching
        var queryObject = new
        {
            SearchTerm = request.SearchTerm,
            CategoryId = request.CategoryId,
            MinPrice = request.MinPrice,
            MaxPrice = request.MaxPrice,
            Page = request.Page,
            PageSize = request.PageSize
        };

        // Use query object for caching
        var cachedResults = await _distributedCache.FindmeAsync<List<Product>>(queryObject,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.SearchProductsAsync(request));

        if (cachedResults != null)
        {
            return cachedResults;
        }

        // Database fallback
        var results = await _productRepository.SearchProductsAsync(request);
        
        // Cache the results
        await _distributedCache.CachemeAsync(queryObject, results,
            expiryInSeconds: 1800,  // 30 minutes
            graceInSeconds: 300);   // 5 minute grace period

        return results;
    }
}
```

### 3. Cache Invalidation

```csharp
public class ProductService : IOEliteService
{
    private readonly IDistributedCache _distributedCache;
    private readonly IMemoryCache _memoryCache;

    public async Task<Product> UpdateProductAsync(string id, UpdateProductRequest request)
    {
        var product = await _productRepository.UpdateAsync(id, request);

        // Invalidate cache entries
        var cacheKey = $"product:{id}";
        
        // Remove from both caches
        await _distributedCache.RemoveAsync(cacheKey);
        _memoryCache.Remove(cacheKey);

        // Also invalidate search results that might include this product
        await InvalidateProductSearchCacheAsync();

        return product;
    }

    private async Task InvalidateProductSearchCacheAsync()
    {
        // This would typically involve pattern-based cache invalidation
        // For now, we'll use a simple approach
        var searchCacheKey = "product-search:*";
        // Note: Pattern-based invalidation would require additional implementation
    }
}
```

### 4. Advanced Cache Expiration

```csharp
public class ProductService : IOEliteService
{
    private readonly IDistributedCache _distributedCache;

    public async Task<bool> ExpireProductCacheAsync(string productId)
    {
        var cacheKey = $"product:{productId}";

        // Option 1: Complete removal
        await _distributedCache.RemoveAsync(cacheKey);

        // Option 2: Graceful expiration (keep in grace period)
        var expired = await _distributedCache.ExpiremeAsync(cacheKey, 
            invalidateGracePeriod: false); // Keep grace period active

        return expired;
    }

    public async Task<bool> ExpireProductSearchCacheAsync(ProductSearchRequest request)
    {
        var queryObject = new
        {
            SearchTerm = request.SearchTerm,
            CategoryId = request.CategoryId,
            MinPrice = request.MinPrice,
            MaxPrice = request.MaxPrice
        };

        return await _distributedCache.ExpiremeAsync<List<Product>>(queryObject,
            invalidateGracePeriod: true); // Remove completely
    }
}
```

## Migration from Microsoft.Extensions.Caching

### Before (Microsoft.Extensions.Caching.StackExchangeRedis)

```csharp
// Service registration
services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "localhost:6379";
    options.InstanceName = "myapp:";
});

// Service usage
public class ProductService
{
    private readonly IDistributedCache _cache;

    public ProductService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";
        var cachedData = await _cache.GetStringAsync(cacheKey);
        
        if (cachedData != null)
        {
            return JsonSerializer.Deserialize<Product>(cachedData);
        }

        var product = await _productRepository.GetByIdAsync(id);
        if (product != null)
        {
            await _cache.SetStringAsync(cacheKey, JsonSerializer.Serialize(product), 
                new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(1)
                });
        }

        return product;
    }
}
```

### After (OElite.Restme.Hosting)

```csharp
// Service registration
services.AddRestmeRedisCache(options =>
{
    options.ConnectionString = "localhost:6379";
    options.InstanceName = "myapp:";
});

// Service usage
public class ProductService
{
    private readonly IDistributedCache _cache;

    public ProductService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<Product> GetProductAsync(string id)
    {
        var cacheKey = $"product:{id}";
        
        // Enhanced caching with grace period and background refresh
        var cachedProduct = await _cache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));

        if (cachedProduct != null)
        {
            return cachedProduct;
        }

        var product = await _productRepository.GetByIdAsync(id);
        if (product != null)
        {
            // Enhanced caching with grace period
            await _cache.CachemeAsync(cacheKey, product,
                expiryInSeconds: 3600,  // 1 hour
                graceInSeconds: 300);   // 5 minute grace period
        }

        return product;
    }
}
```

## Performance Considerations

### 1. Grace Period Strategy

- **Short grace periods** (1-5 minutes) for frequently changing data
- **Long grace periods** (15-30 minutes) for relatively stable data
- **No grace period** for critical real-time data

```csharp
// Frequently changing data (user sessions, cart contents)
await _cache.CachemeAsync(cacheKey, data, 
    expiryInSeconds: 300,   // 5 minutes
    graceInSeconds: 60);     // 1 minute grace

// Stable data (product catalogs, user profiles)
await _cache.CachemeAsync(cacheKey, data, 
    expiryInSeconds: 3600,  // 1 hour
    graceInSeconds: 600);    // 10 minute grace

// Real-time data (inventory, pricing)
await _cache.CachemeAsync(cacheKey, data, 
    expiryInSeconds: 60,     // 1 minute
    graceInSeconds: 0);      // No grace period
```

### 2. Multi-Tier Caching

```csharp
public async Task<Product> GetProductAsync(string id)
{
    var cacheKey = $"product:{id}";

    // Tier 1: Memory cache (fastest)
    var memoryCached = await _memoryCache.FindmeAsync<Product>(cacheKey,
        returnExpired: false,
        returnInGrace: true,
        refreshAction: async () => await GetFromDistributedCacheAsync(cacheKey));

    if (memoryCached != null)
        return memoryCached;

    // Tier 2: Distributed cache (fast)
    var distributedCached = await _distributedCache.FindmeAsync<Product>(cacheKey,
        returnExpired: false,
        returnInGrace: true,
        refreshAction: async () => await _productRepository.GetByIdAsync(id));

    if (distributedCached != null)
    {
        // Populate memory cache
        _memoryCache.CachemeAsync(cacheKey, distributedCached, 
            expiryInSeconds: 900, graceInSeconds: 90);
        return distributedCached;
    }

    // Tier 3: Database (slowest)
    var product = await _productRepository.GetByIdAsync(id);
    if (product != null)
    {
        // Populate both caches
        await _distributedCache.CachemeAsync(cacheKey, product, 
            expiryInSeconds: 3600, graceInSeconds: 300);
        _memoryCache.CachemeAsync(cacheKey, product, 
            expiryInSeconds: 900, graceInSeconds: 90);
    }

    return product;
}
```

### 3. Background Refresh Optimization

```csharp
public async Task<Product> GetProductAsync(string id)
{
    var cacheKey = $"product:{id}";

    return await _distributedCache.FindmeAsync<Product>(cacheKey,
        returnExpired: false,
        returnInGrace: true,
        additionalValidation: async (product) =>
        {
            // Additional validation before returning cached data
            return product.IsActive && !product.IsDeleted;
        },
        refreshAction: async () =>
        {
            // Optimized refresh with related data loading
            return await _productRepository.GetProductWithInventoryAsync(id);
        });
}
```

## Best Practices

### 1. Cache Key Naming

```csharp
// ✅ Good - Consistent, hierarchical naming
var cacheKey = $"product:{id}";
var cacheKey = $"user:{userId}:profile";
var cacheKey = $"category:{categoryId}:products:page:{page}";

// ❌ Bad - Inconsistent naming
var cacheKey = $"Product_{id}";
var cacheKey = $"userProfile{userId}";
```

### 2. Error Handling

```csharp
public async Task<Product> GetProductAsync(string id)
{
    try
    {
        var cacheKey = $"product:{id}";
        
        var cachedProduct = await _distributedCache.FindmeAsync<Product>(cacheKey,
            returnExpired: false,
            returnInGrace: true,
            refreshAction: async () => await _productRepository.GetByIdAsync(id));

        return cachedProduct ?? await _productRepository.GetByIdAsync(id);
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Cache error for product {ProductId}, falling back to database", id);
        return await _productRepository.GetByIdAsync(id);
    }
}
```

### 3. Cache Warming

```csharp
public class CacheWarmingService : BackgroundService
{
    private readonly IDistributedCache _distributedCache;
    private readonly IProductRepository _productRepository;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Warm frequently accessed products
                var popularProducts = await _productRepository.GetPopularProductsAsync();
                
                foreach (var product in popularProducts)
                {
                    var cacheKey = $"product:{product.Id}";
                    await _distributedCache.CachemeAsync(cacheKey, product,
                        expiryInSeconds: 3600,
                        graceInSeconds: 300);
                }

                await Task.Delay(TimeSpan.FromMinutes(10), stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during cache warming");
                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
            }
        }
    }
}
```

## Troubleshooting

### Common Issues

1. **Cache Misses**: Ensure consistent cache key generation
2. **Memory Usage**: Monitor memory cache size and implement eviction policies
3. **Network Latency**: Use multi-tier caching for frequently accessed data
4. **Stale Data**: Implement proper cache invalidation strategies

### Monitoring

```csharp
public class CacheMetricsService
{
    private readonly IDistributedCache _distributedCache;
    private readonly IMemoryCache _memoryCache;

    public async Task<CacheMetrics> GetCacheMetricsAsync()
    {
        // Implement cache hit/miss ratio monitoring
        // Track cache size and performance metrics
        // Monitor grace period effectiveness
    }
}
```

## Compliance Checklist

### Required Patterns
- [ ] Use OElite.Restme.Hosting adapters for IDistributedCache/IMemoryCache
- [ ] Implement grace period caching for critical data
- [ ] Configure background refresh actions for stale data
- [ ] Use consistent cache key naming conventions
- [ ] Implement proper error handling with database fallback
- [ ] Monitor cache performance and hit ratios

### Performance Requirements
- [ ] Multi-tier caching strategy implemented where appropriate
- [ ] Grace periods configured based on data volatility
- [ ] Background refresh actions optimized for performance
- [ ] Cache warming implemented for frequently accessed data
- [ ] Proper cache invalidation strategies in place

### Quality Standards
- [ ] Cache operations wrapped in try-catch blocks
- [ ] Consistent logging for cache operations
- [ ] Cache keys follow hierarchical naming convention
- [ ] Database fallback implemented for all cache operations
- [ ] Cache metrics and monitoring implemented

This guide ensures optimal usage of OElite.Restme.Hosting while maintaining high performance and reliability across the OElite platform.
