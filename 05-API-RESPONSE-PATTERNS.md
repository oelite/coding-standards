# API Design & Response Patterns

## Overview

The OElite platform implements standardized API design patterns using `OEliteApiOutputFormatter` for consistent response formatting, domain folder organization, and comprehensive Swagger documentation. This document establishes the mandatory patterns for API controllers, request/response models, and API documentation across all OElite applications.

## OEliteApiOutputFormatter Usage

### 1. **Automatic Response Formatting** (Mandatory)
All API controllers MUST use `OEliteApiOutputFormatter` for consistent response structure across the platform.

```csharp
// ✅ Required controller setup with OEliteApiOutputFormatter
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ProductsController : ControllerBase
{
    private readonly ProductService _productService;
    private readonly ILogger<ProductsController> _logger;

    public ProductsController(ProductService productService, ILogger<ProductsController> logger)
    {
        _productService = productService;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(typeof(List<ProductResponse>), 200)]
    [ProducesResponseType(400)]
    [ProducesResponseType(500)]
    public async Task<ActionResult<List<ProductResponse>>> GetProducts([FromQuery] GetProductsRequest request)
    {
        var products = await _productService.GetProductsAsync(request);

        // Use ModelTransformation for consistent response mapping
        var transformer = new ProductModelTransformer(_categoryRepository, _inventoryService);
        var response = await transformer.TransformAsync(products);

        // OEliteApiOutputFormatter automatically formats response
        return Ok(response);
    }

    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<ProductResponse>), 201)]
    [ProducesResponseType(typeof(ApiErrorResponse), 400)]
    [ProducesResponseType(typeof(ApiErrorResponse), 409)]
    public async Task<ActionResult<ProductResponse>> CreateProduct([FromBody] CreateProductRequest request)
    {
        var product = await _productService.CreateProductAsync(request);
        var response = new ProductResponse(product);

        // Returns standardized success response with 201 status
        return CreatedAtAction(nameof(GetProduct), new { id = product.Id }, response);
    }
}
```

### 2. **Standardized Response Structure**
The `OEliteApiOutputFormatter` automatically wraps responses in a consistent structure:

```json
// ✅ Success Response Format (using OEliteApiOutputFormatter)
{
    "id": "507f1f77bcf86cd799439011",
    "name": "Sample Product",
    "price": 99.99,
    "categoryId": "507f1f77bcf86cd799439012"
}

// ✅ Error Response Format (handled by middleware)
{
    "error": {
        "message": "One or more validation errors occurred",
        "details": [
            {
                "field": "name",
                "message": "Product name is required"
            },
            {
                "field": "price",
                "message": "Price must be greater than 0"
            }
        ]
    }
}

// ✅ Collection Response Format
{
    "items": [...],
    "pagination": {
        "page": 1,
        "pageSize": 20,
        "totalItems": 156,
        "totalPages": 8
    }
}
```

## Domain Folder Organization

### 1. **Required Domain Structure** (Domain-Based Organization)
All API-related models MUST be organized using the OElite domain-based folder structure where each business domain contains all related components:

```
OElite.Common/Biz/
├── Products/                  # Product domain
│   ├── Requests/              # Product API request models
│   │   ├── CreateProductRequest.cs
│   │   ├── UpdateProductRequest.cs
│   │   ├── GetProductsRequest.cs
│   │   └── DeleteProductRequest.cs
│   ├── Responses/             # Product API response models
│   │   ├── ProductResponse.cs
│   │   ├── ProductSummaryResponse.cs
│   │   └── ProductDetailsResponse.cs
│   ├── Reports/               # Product reporting models
│   │   ├── ProductSalesReport.cs
│   │   └── ProductInventoryReport.cs
│   └── ModelTransformation/   # Product model transformers
│       ├── ProductTransformer.cs
│       └── ProductSummaryTransformer.cs
├── Orders/                    # Order domain
│   ├── Requests/              # Order API request models
│   │   ├── CreateOrderRequest.cs
│   │   ├── UpdateOrderStatusRequest.cs
│   │   └── GetOrdersRequest.cs
│   ├── Responses/             # Order API response models
│   │   ├── OrderResponse.cs
│   │   └── OrderSummaryResponse.cs
│   ├── Reports/               # Order reporting models
│   │   ├── OrderAnalyticsReport.cs
│   │   └── OrderTrendsReport.cs
│   └── ModelTransformation/   # Order model transformers
│       ├── OrderTransformer.cs
│       └── OrderSummaryTransformer.cs
├── Customers/                 # Customer domain
│   ├── Requests/              # Customer API request models
│   │   ├── CreateCustomerRequest.cs
│   │   └── UpdateCustomerRequest.cs
│   ├── Responses/             # Customer API response models
│   │   ├── CustomerResponse.cs
│   │   └── CustomerProfileResponse.cs
│   ├── Reports/               # Customer reporting models
│   │   ├── CustomerAnalyticsReport.cs
│   │   └── CustomerSegmentationReport.cs
│   └── ModelTransformation/   # Customer model transformers
│       ├── CustomerTransformer.cs
│       └── CustomerProfileTransformer.cs
└── Payments/                  # Payment domain
    ├── Requests/              # Payment API request models
    ├── Responses/             # Payment API response models
    ├── Reports/               # Payment reporting models
    └── ModelTransformation/   # Payment model transformers
```

### 2. **Request Models Standards**
All request models must follow validation and documentation patterns:

```csharp
// ✅ Request model best practices
public class CreateProductRequest
{
    [Required(ErrorMessage = "Product name is required")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Product name must be between 2 and 100 characters")]
    [SwaggerSchema("The name of the product", Example = "Samsung Galaxy S24")]
    public string Name { get; set; }

    [StringLength(1000, ErrorMessage = "Description cannot exceed 1000 characters")]
    [SwaggerSchema("Detailed description of the product", Example = "Latest smartphone with advanced camera features")]
    public string Description { get; set; }

    [Required(ErrorMessage = "Price is required")]
    [Range(0.01, double.MaxValue, ErrorMessage = "Price must be greater than 0")]
    [SwaggerSchema("Product price in the base currency", Example = "999.99")]
    public decimal Price { get; set; }

    [Required(ErrorMessage = "Category ID is required")]
    [SwaggerSchema("ID of the product category", Example = "507f1f77bcf86cd799439011")]
    public string CategoryId { get; set; }

    [SwaggerSchema("Product tags for search and categorization", Example = "smartphone,electronics,samsung")]
    public List<string> Tags { get; set; } = new();

    [SwaggerSchema("Product specifications as key-value pairs")]
    public Dictionary<string, string> Specifications { get; set; } = new();

    // Custom validation method
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Tags?.Count > 10)
        {
            yield return new ValidationResult(
                "Maximum of 10 tags allowed",
                new[] { nameof(Tags) });
        }

        if (Specifications?.Count > 20)
        {
            yield return new ValidationResult(
                "Maximum of 20 specifications allowed",
                new[] { nameof(Specifications) });
        }
    }
}

// ✅ Query/Filter request models
public class GetProductsRequest : PaginationRequest
{
    [SwaggerSchema("Filter products by category ID", Example = "507f1f77bcf86cd799439011")]
    public string CategoryId { get; set; }

    [SwaggerSchema("Search term for product name or description", Example = "smartphone")]
    public string SearchTerm { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Minimum price cannot be negative")]
    [SwaggerSchema("Minimum price filter", Example = "100.00")]
    public decimal? MinPrice { get; set; }

    [Range(0, double.MaxValue, ErrorMessage = "Maximum price cannot be negative")]
    [SwaggerSchema("Maximum price filter", Example = "2000.00")]
    public decimal? MaxPrice { get; set; }

    [SwaggerSchema("Filter by product tags", Example = "electronics,smartphone")]
    public List<string> Tags { get; set; } = new();

    [SwaggerSchema("Sort order: name, price, created", Example = "name")]
    public string SortBy { get; set; } = "created";

    [SwaggerSchema("Sort direction: asc, desc", Example = "desc")]
    public string SortDirection { get; set; } = "desc";

    // Validation for price range
    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (MinPrice.HasValue && MaxPrice.HasValue && MinPrice > MaxPrice)
        {
            yield return new ValidationResult(
                "Minimum price cannot be greater than maximum price",
                new[] { nameof(MinPrice), nameof(MaxPrice) });
        }
    }
}

// ✅ Base pagination request
public abstract class PaginationRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Page must be greater than 0")]
    [SwaggerSchema("Page number (1-based)", Example = "1")]
    public int Page { get; set; } = 1;

    [Range(1, 100, ErrorMessage = "Page size must be between 1 and 100")]
    [SwaggerSchema("Number of items per page", Example = "20")]
    public int PageSize { get; set; } = 20;

    // Calculate skip for database queries
    public int Skip => (Page - 1) * PageSize;
}
```

### 3. **Response Models with ModelTransformation** (OElite Pattern)
Response models should use the centralized ModelTransformation pattern from the domain's ModelTransformation folder:

```csharp
// ✅ Response model with ModelTransformation integration
public class ProductResponse
{
    [SwaggerSchema("Unique product identifier", Example = "507f1f77bcf86cd799439011")]
    public string Id { get; set; }

    [SwaggerSchema("Product name", Example = "Samsung Galaxy S24")]
    public string Name { get; set; }

    [SwaggerSchema("Product description", Example = "Latest smartphone with advanced camera features")]
    public string Description { get; set; }

    [SwaggerSchema("Product price", Example = "999.99")]
    public decimal Price { get; set; }

    [SwaggerSchema("Category information")]
    public CategorySummaryResponse Category { get; set; }

    [SwaggerSchema("Product availability status")]
    public bool IsAvailable { get; set; }

    [SwaggerSchema("Product tags")]
    public List<string> Tags { get; set; }

    [SwaggerSchema("Product specifications")]
    public Dictionary<string, string> Specifications { get; set; }

    [SwaggerSchema("When the product was created")]
    public DateTime CreatedOnUtc { get; set; }

    [SwaggerSchema("When the product was last modified")]
    public DateTime LastModifiedOnUtc { get; set; }

    // Parameterless constructor for serialization
    public ProductResponse() { }
}

// ✅ ModelTransformation class (in OElite.Common/Biz/Products/ModelTransformation/)
public class ProductModelTransformer : IModelTransformer<Product, ProductResponse>
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly IInventoryService _inventoryService;

    public ProductModelTransformer(ICategoryRepository categoryRepository, IInventoryService inventoryService)
    {
        _categoryRepository = categoryRepository;
        _inventoryService = inventoryService;
    }

    public async Task<ProductResponse> TransformAsync(Product product)
    {
        var response = new ProductResponse
        {
            Id = product.Id,
            Name = product.Name,
            Description = product.Description,
            Price = product.Price,
            IsAvailable = product.IsActive && !product.IsDeleted,
            Tags = product.Tags ?? new List<string>(),
            CreatedOnUtc = product.CreatedOnUtc,
            LastModifiedOnUtc = product.LastModifiedOnUtc
        };

        // Transform category using repository if needed
        if (!string.IsNullOrWhiteSpace(product.CategoryId))
        {
            var category = await _categoryRepository.GetByIdAsync(product.CategoryId);
            if (category != null)
            {
                response.Category = new CategorySummaryResponse
                {
                    Id = category.Id,
                    Name = category.Name
                };
            }
        }

        // Add inventory information
        var inventory = await _inventoryService.GetInventoryAsync(product.Id);
        response.StockLevel = inventory?.AvailableQuantity ?? 0;
        response.IsAvailable = response.IsAvailable && response.StockLevel > 0;

        return response;
    }

    public async Task<List<ProductResponse>> TransformAsync(List<Product> products)
    {
        if (!products.Any()) return new List<ProductResponse>();

        // Batch load related data to avoid N+1 queries
        var categoryIds = products.Select(p => p.CategoryId).Distinct().ToList();
        var productIds = products.Select(p => p.Id).ToList();

        var categoriesTask = _categoryRepository.GetByIdsAsync(categoryIds);
        var inventoriesTask = _inventoryService.GetInventoriesAsync(productIds);

        await Task.WhenAll(categoriesTask, inventoriesTask);

        var categories = (await categoriesTask).ToDictionary(c => c.Id, c => c);
        var inventories = (await inventoriesTask).ToDictionary(i => i.ProductId, i => i);

        return products.Select(product =>
        {
            var response = new ProductResponse
            {
                Id = product.Id,
                Name = product.Name,
                Description = product.Description,
                Price = product.Price,
                IsAvailable = product.IsActive && !product.IsDeleted,
                Tags = product.Tags ?? new List<string>(),
                CreatedOnUtc = product.CreatedOnUtc,
                LastModifiedOnUtc = product.LastModifiedOnUtc
            };

            if (categories.TryGetValue(product.CategoryId, out var category))
            {
                response.Category = new CategorySummaryResponse
                {
                    Id = category.Id,
                    Name = category.Name
                };
            }

            if (inventories.TryGetValue(product.Id, out var inventory))
            {
                response.StockLevel = inventory.AvailableQuantity;
                response.IsAvailable = response.IsAvailable && inventory.AvailableQuantity > 0;
            }

            return response;
        }).ToList();
    }
}

// ✅ Summary response for list operations
public class ProductSummaryResponse
{
    [SwaggerSchema("Product ID", Example = "507f1f77bcf86cd799439011")]
    public string Id { get; set; }

    [SwaggerSchema("Product name", Example = "Samsung Galaxy S24")]
    public string Name { get; set; }

    [SwaggerSchema("Product price", Example = "999.99")]
    public decimal Price { get; set; }

    [SwaggerSchema("Category name", Example = "Smartphones")]
    public string CategoryName { get; set; }

    [SwaggerSchema("Primary product image URL")]
    public string PrimaryImageUrl { get; set; }

    [SwaggerSchema("Product availability")]
    public bool IsAvailable { get; set; }

    public ProductSummaryResponse(Product product)
    {
        Id = product.Id;
        Name = product.Name;
        Price = product.Price;
        CategoryName = product.CategoryName;
        PrimaryImageUrl = product.Images?.FirstOrDefault(i => i.IsPrimary)?.Url;
        IsAvailable = product.IsActive && !product.IsDeleted;
    }

    public ProductSummaryResponse() { }
}
```

## ModelTransformation Patterns

### 1. **Domain-Based Model Transformation**
Use model transformation services organized by business domain for complex mapping scenarios:

```csharp
// ✅ Domain-specific model transformation service (OElite.Common/Biz/Products/ModelTransformation/)
public class ProductModelTransformer : IModelTransformer<Product, ProductResponse>
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly IInventoryService _inventoryService;

    public ProductModelTransformer(ICategoryRepository categoryRepository, IInventoryService inventoryService)
    {
        _categoryRepository = categoryRepository;
        _inventoryService = inventoryService;
    }

    public async Task<ProductResponse> TransformAsync(Product entity)
    {
        var response = new ProductResponse(entity);

        // Enrich with additional data
        if (!string.IsNullOrWhiteSpace(entity.CategoryId))
        {
            var category = await _categoryRepository.GetByIdAsync(entity.CategoryId);
            if (category != null)
            {
                response.Category = new CategorySummaryResponse(category);
            }
        }

        // Add real-time inventory information
        var inventory = await _inventoryService.GetInventoryAsync(entity.Id);
        response.StockLevel = inventory?.AvailableQuantity ?? 0;
        response.IsAvailable = response.IsAvailable && response.StockLevel > 0;

        return response;
    }

    public async Task<List<ProductResponse>> TransformAsync(List<Product> entities)
    {
        var tasks = entities.Select(TransformAsync);
        return (await Task.WhenAll(tasks)).ToList();
    }
}

// ✅ Using transformation in controllers
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly ProductService _productService;
    private readonly ProductModelTransformer _transformer;

    public ProductsController(ProductService productService, ProductModelTransformer transformer)
    {
        _productService = productService;
        _transformer = transformer;
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<ProductResponse>> GetProduct(string id)
    {
        var product = await _productService.GetProductAsync(id);
        if (product == null)
            return NotFound();

        var response = await _transformer.TransformAsync(product);
        return Ok(response);
    }
}
```

### 2. **Batch Transformation Optimization**
Optimize transformations for collections:

```csharp
// ✅ Efficient batch transformation
public class OptimizedProductTransformer : IModelTransformer<Product, ProductResponse>
{
    private readonly ICategoryRepository _categoryRepository;
    private readonly IInventoryService _inventoryService;

    public async Task<List<ProductResponse>> TransformAsync(List<Product> products)
    {
        if (!products.Any()) return new List<ProductResponse>();

        // Batch load related data to avoid N+1 queries
        var categoryIds = products.Select(p => p.CategoryId).Distinct().ToList();
        var productIds = products.Select(p => p.Id).ToList();

        var categoriesTask = _categoryRepository.GetByIdsAsync(categoryIds);
        var inventoriesTask = _inventoryService.GetInventoriesAsync(productIds);

        await Task.WhenAll(categoriesTask, inventoriesTask);

        var categories = (await categoriesTask).ToDictionary(c => c.Id, c => c);
        var inventories = (await inventoriesTask).ToDictionary(i => i.ProductId, i => i);

        // Transform with pre-loaded data
        return products.Select(product =>
        {
            var response = new ProductResponse(product);

            if (categories.TryGetValue(product.CategoryId, out var category))
            {
                response.Category = new CategorySummaryResponse(category);
            }

            if (inventories.TryGetValue(product.Id, out var inventory))
            {
                response.StockLevel = inventory.AvailableQuantity;
                response.IsAvailable = response.IsAvailable && inventory.AvailableQuantity > 0;
            }

            return response;
        }).ToList();
    }
}
```

## Swagger Configuration and Documentation

### 1. **Comprehensive Swagger Setup** (Mandatory)
All APIs MUST have complete Swagger documentation:

```csharp
// ✅ Required Swagger configuration in Program.cs
public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Add API versioning
        builder.Services.AddApiVersioning(opt =>
        {
            opt.DefaultApiVersion = new ApiVersion(1, 0);
            opt.AssumeDefaultVersionWhenUnspecified = true;
            opt.ApiVersionReader = ApiVersionReader.Combine(
                new UrlSegmentApiVersionReader(),
                new HeaderApiVersionReader("X-Version"),
                new MediaTypeApiVersionReader("ver")
            );
        });

        builder.Services.AddVersionedApiExplorer(setup =>
        {
            setup.GroupNameFormat = "'v'VVV";
            setup.SubstituteApiVersionInUrl = true;
        });

        // Configure Swagger
        builder.Services.AddSwaggerGen(c =>
        {
            c.SwaggerDoc("v1", new OpenApiInfo
            {
                Version = "v1",
                Title = "OElite Kortex API",
                Description = "Comprehensive API for OElite Kortex edge computing platform",
                Contact = new OpenApiContact
                {
                    Name = "OElite Development Team",
                    Email = "dev@oelite.io",
                    Url = new Uri("https://oelite.io")
                },
                License = new OpenApiLicense
                {
                    Name = "OElite License",
                    Url = new Uri("https://oelite.io/license")
                }
            });

            // Add JWT authentication support
            c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Description = "JWT Authorization header using the Bearer scheme",
                Name = "Authorization",
                In = ParameterLocation.Header,
                Type = SecuritySchemeType.ApiKey,
                Scheme = "Bearer"
            });

            c.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Bearer"
                        }
                    },
                    new string[] {}
                }
            });

            // Include XML comments
            var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
            var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
            if (File.Exists(xmlPath))
            {
                c.IncludeXmlComments(xmlPath);
            }

            // Custom schema IDs
            c.CustomSchemaIds(type => type.FullName);

            // Add examples and filters
            c.ExampleFilters();
            c.OperationFilter<SwaggerDefaultValues>();
            c.SchemaFilter<EnumSchemaFilter>();
        });

        var app = builder.Build();

        // Enable Swagger in all environments
        app.UseSwagger();
        app.UseSwaggerUI(c =>
        {
            c.SwaggerEndpoint("/swagger/v1/swagger.json", "OElite Kortex API v1");
            c.RoutePrefix = "api-docs";
            c.DocExpansion(DocExpansion.None);
            c.DefaultModelsExpandDepth(2);
            c.EnableDeepLinking();
            c.EnableFilter();
            c.EnableValidator();
        });

        app.Run();
    }
}
```

### 2. **Controller Documentation Standards**
All controller actions MUST have comprehensive documentation:

```csharp
// ✅ Comprehensive controller documentation
/// <summary>
/// Products management API endpoints
/// </summary>
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
[ApiVersion("1.0")]
[Produces("application/json")]
[ProducesResponseType(typeof(ApiErrorResponse), 401)]
[ProducesResponseType(typeof(ApiErrorResponse), 403)]
[ProducesResponseType(typeof(ApiErrorResponse), 500)]
public class ProductsController : ControllerBase
{
    private readonly ProductService _productService;

    public ProductsController(ProductService productService)
    {
        _productService = productService;
    }

    /// <summary>
    /// Retrieves a paginated list of products with optional filtering
    /// </summary>
    /// <param name="request">Product filtering and pagination parameters</param>
    /// <returns>A paginated list of products matching the specified criteria</returns>
    /// <remarks>
    /// Sample request:
    ///
    ///     GET /api/v1/products?page=1&amp;pageSize=20&amp;categoryId=507f1f77bcf86cd799439011&amp;searchTerm=smartphone
    ///
    /// This endpoint supports the following features:
    /// - Full-text search across product names and descriptions
    /// - Category-based filtering
    /// - Price range filtering
    /// - Tag-based filtering
    /// - Multiple sorting options (name, price, created date)
    /// - Pagination with configurable page sizes
    /// </remarks>
    /// <response code="200">Returns the requested page of products</response>
    /// <response code="400">Invalid request parameters</response>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<PaginatedResponse<ProductSummaryResponse>>), 200)]
    [ProducesResponseType(typeof(ApiErrorResponse), 400)]
    public async Task<ActionResult<PaginatedResponse<ProductSummaryResponse>>> GetProducts([FromQuery] GetProductsRequest request)
    {
        var result = await _productService.GetProductsAsync(request);
        return Ok(result);
    }

    /// <summary>
    /// Retrieves detailed information for a specific product
    /// </summary>
    /// <param name="id">The unique identifier of the product</param>
    /// <returns>Detailed product information including specifications and images</returns>
    /// <remarks>
    /// This endpoint returns comprehensive product information including:
    /// - Basic product details (name, description, price)
    /// - Category information
    /// - Product specifications and attributes
    /// - Image gallery
    /// - Inventory status
    /// - Related products
    /// </remarks>
    /// <response code="200">Returns the requested product details</response>
    /// <response code="404">Product not found</response>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<ProductResponse>), 200)]
    [ProducesResponseType(typeof(ApiErrorResponse), 404)]
    public async Task<ActionResult<ProductResponse>> GetProduct(
        [FromRoute] [SwaggerParameter("Product ID", Required = true)] string id)
    {
        var product = await _productService.GetProductAsync(id);
        if (product == null)
            return NotFound($"Product with ID {id} not found");

        return Ok(product);
    }

    /// <summary>
    /// Creates a new product
    /// </summary>
    /// <param name="request">Product creation details</param>
    /// <returns>The created product with assigned ID</returns>
    /// <remarks>
    /// Sample request:
    ///
    ///     POST /api/v1/products
    ///     {
    ///         "name": "Samsung Galaxy S24",
    ///         "description": "Latest flagship smartphone",
    ///         "price": 999.99,
    ///         "categoryId": "507f1f77bcf86cd799439011",
    ///         "tags": ["smartphone", "electronics", "samsung"],
    ///         "specifications": {
    ///             "screen": "6.2 inches",
    ///             "storage": "256GB",
    ///             "ram": "8GB"
    ///         }
    ///     }
    ///
    /// </remarks>
    /// <response code="201">Product created successfully</response>
    /// <response code="400">Invalid product data</response>
    /// <response code="409">Product with the same name already exists</response>
    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<ProductResponse>), 201)]
    [ProducesResponseType(typeof(ApiErrorResponse), 400)]
    [ProducesResponseType(typeof(ApiErrorResponse), 409)]
    public async Task<ActionResult<ProductResponse>> CreateProduct([FromBody] CreateProductRequest request)
    {
        var product = await _productService.CreateProductAsync(request);
        return CreatedAtAction(nameof(GetProduct), new { id = product.Id }, product);
    }
}
```

## Error Handling and Status Codes

### 1. **Standardized Error Responses**
Implement consistent error handling across all endpoints:

```csharp
// ✅ Global exception handling middleware
public class ApiExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ApiExceptionMiddleware> _logger;

    public ApiExceptionMiddleware(RequestDelegate next, ILogger<ApiExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        _logger.LogError(exception, "An unhandled exception occurred");

        var response = context.Response;
        response.ContentType = "application/json";

        var errorResponse = exception switch
        {
            ValidationException vex => new ApiErrorResponse
            {
                Success = false,
                Error = new ErrorDetails
                {
                    Code = "VALIDATION_ERROR",
                    Message = "One or more validation errors occurred",
                    Details = vex.Errors.Select(e => new ErrorDetail
                    {
                        Field = e.PropertyName,
                        Message = e.ErrorMessage
                    }).ToList()
                },
                Timestamp = DateTime.UtcNow,
                RequestId = context.TraceIdentifier
            },
            NotFoundException nfex => new ApiErrorResponse
            {
                Success = false,
                Error = new ErrorDetails
                {
                    Code = "NOT_FOUND",
                    Message = nfex.Message
                },
                Timestamp = DateTime.UtcNow,
                RequestId = context.TraceIdentifier
            },
            BusinessException bex => new ApiErrorResponse
            {
                Success = false,
                Error = new ErrorDetails
                {
                    Code = "BUSINESS_RULE_VIOLATION",
                    Message = bex.Message
                },
                Timestamp = DateTime.UtcNow,
                RequestId = context.TraceIdentifier
            },
            _ => new ApiErrorResponse
            {
                Success = false,
                Error = new ErrorDetails
                {
                    Code = "INTERNAL_SERVER_ERROR",
                    Message = "An internal server error occurred"
                },
                Timestamp = DateTime.UtcNow,
                RequestId = context.TraceIdentifier
            }
        };

        response.StatusCode = exception switch
        {
            ValidationException => 400,
            NotFoundException => 404,
            BusinessException => 400,
            UnauthorizedAccessException => 401,
            _ => 500
        };

        var jsonResponse = JsonSerializer.Serialize(errorResponse, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await response.WriteAsync(jsonResponse);
    }
}
```

### 2. **HTTP Status Code Standards**
Use appropriate HTTP status codes consistently:

```csharp
// ✅ Proper status code usage in controllers
[ApiController]
public class OrdersController : ControllerBase
{
    // 200 OK - Successful GET requests
    [HttpGet]
    public async Task<ActionResult<List<OrderResponse>>> GetOrders()
    {
        var orders = await _orderService.GetOrdersAsync();
        return Ok(orders); // 200 OK
    }

    // 201 Created - Successful resource creation
    [HttpPost]
    public async Task<ActionResult<OrderResponse>> CreateOrder([FromBody] CreateOrderRequest request)
    {
        var order = await _orderService.CreateOrderAsync(request);
        return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order); // 201 Created
    }

    // 204 No Content - Successful deletion or update with no response body
    [HttpDelete("{id}")]
    public async Task<ActionResult> DeleteOrder(string id)
    {
        await _orderService.DeleteOrderAsync(id);
        return NoContent(); // 204 No Content
    }

    // 400 Bad Request - Validation errors
    [HttpPut("{id}")]
    public async Task<ActionResult<OrderResponse>> UpdateOrder(string id, [FromBody] UpdateOrderRequest request)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState); // 400 Bad Request

        var order = await _orderService.UpdateOrderAsync(id, request);
        return Ok(order); // 200 OK
    }

    // 404 Not Found - Resource doesn't exist
    [HttpGet("{id}")]
    public async Task<ActionResult<OrderResponse>> GetOrder(string id)
    {
        var order = await _orderService.GetOrderAsync(id);
        if (order == null)
            return NotFound($"Order with ID {id} not found"); // 404 Not Found

        return Ok(order); // 200 OK
    }

    // 409 Conflict - Business rule violations
    [HttpPost("{id}/cancel")]
    public async Task<ActionResult> CancelOrder(string id)
    {
        try
        {
            await _orderService.CancelOrderAsync(id);
            return NoContent(); // 204 No Content
        }
        catch (BusinessException ex)
        {
            return Conflict(ex.Message); // 409 Conflict
        }
    }
}
```

## Performance and Caching Patterns

### 1. **Response Caching**
Implement appropriate caching strategies:

```csharp
// ✅ Response caching for read-heavy operations
[ApiController]
[Route("api/[controller]")]
public class CategoriesController : ControllerBase
{
    private readonly CategoryService _categoryService;

    // Cache categories for 5 minutes
    [HttpGet]
    [ResponseCache(Duration = 300, VaryByQueryKeys = new[] { "includeProducts" })]
    [ProducesResponseType(typeof(ApiResponse<List<CategoryResponse>>), 200)]
    public async Task<ActionResult<List<CategoryResponse>>> GetCategories([FromQuery] bool includeProducts = false)
    {
        var categories = await _categoryService.GetCategoriesAsync(includeProducts);
        return Ok(categories);
    }

    // Don't cache individual category lookups (might change frequently)
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<CategoryResponse>), 200)]
    [ProducesResponseType(typeof(ApiErrorResponse), 404)]
    public async Task<ActionResult<CategoryResponse>> GetCategory(string id)
    {
        var category = await _categoryService.GetCategoryAsync(id);
        if (category == null)
            return NotFound();

        return Ok(category);
    }
}
```

### 2. **Pagination and Performance**
Implement efficient pagination patterns:

```csharp
// ✅ Efficient pagination with performance considerations
public class PaginatedResponse<T>
{
    [SwaggerSchema("The items in the current page")]
    public List<T> Items { get; set; } = new();

    [SwaggerSchema("Pagination metadata")]
    public PaginationMetadata Pagination { get; set; }

    [SwaggerSchema("Additional metadata like filters applied")]
    public Dictionary<string, object> Metadata { get; set; } = new();

    public PaginatedResponse(List<T> items, int totalItems, int page, int pageSize)
    {
        Items = items;
        Pagination = new PaginationMetadata
        {
            Page = page,
            PageSize = pageSize,
            TotalItems = totalItems,
            TotalPages = (int)Math.Ceiling((double)totalItems / pageSize),
            HasNext = page * pageSize < totalItems,
            HasPrevious = page > 1
        };
    }
}

public class PaginationMetadata
{
    [SwaggerSchema("Current page number (1-based)", Example = "1")]
    public int Page { get; set; }

    [SwaggerSchema("Number of items per page", Example = "20")]
    public int PageSize { get; set; }

    [SwaggerSchema("Total number of items across all pages", Example = "156")]
    public int TotalItems { get; set; }

    [SwaggerSchema("Total number of pages", Example = "8")]
    public int TotalPages { get; set; }

    [SwaggerSchema("Whether there is a next page available")]
    public bool HasNext { get; set; }

    [SwaggerSchema("Whether there is a previous page available")]
    public bool HasPrevious { get; set; }
}
```

## Compliance Checklist

### API Design Requirements
- [ ] All controllers use `OEliteApiOutputFormatter` for consistent responses
- [ ] All endpoints have proper HTTP status codes
- [ ] Request/Response models are in appropriate domain folders
- [ ] All models have comprehensive validation attributes
- [ ] Swagger documentation is complete with examples
- [ ] Error handling follows standardized patterns
- [ ] Authentication and authorization are properly implemented

### Documentation Standards
- [ ] All controller actions have XML documentation comments
- [ ] All request/response models have `SwaggerSchema` attributes
- [ ] API versioning is implemented and documented
- [ ] Swagger UI is configured with proper metadata
- [ ] Examples are provided for complex operations
- [ ] Security schemes are properly documented

### Performance Requirements
- [ ] Pagination is implemented for list operations
- [ ] Response caching is used where appropriate
- [ ] Model transformation is optimized to avoid N+1 queries
- [ ] Large payloads are properly handled
- [ ] Request/response compression is enabled
- [ ] API rate limiting is configured

### Quality Standards
- [ ] All endpoints have proper unit and integration tests
- [ ] API contracts are validated in tests
- [ ] Error scenarios are thoroughly tested
- [ ] Performance testing is conducted for critical endpoints
- [ ] Security testing includes authorization verification
- [ ] API breaking changes are properly versioned

This API design framework ensures consistent, well-documented, and high-performance REST APIs across the entire OElite platform while maintaining excellent developer experience and comprehensive error handling.