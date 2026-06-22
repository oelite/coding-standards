# 14. .NET Testing Standards

## Overview

This document establishes **mandatory testing standards** for all .NET 10 backend development across the OElite platform. These standards ensure that every feature is tested against **real infrastructure** (Docker containers for MongoDB, Redis, ClickHouse, etc.) — never mocked or faked.

**Technology Stack**: .NET 10 / C#, xUnit, MongoDB (via OElite.Restme), Redis, Docker Compose

---

## Core Principle: Real Infrastructure, No Mocks

OElite data structures are too complex (`BaseEntity`, `DbCollection`, denormalized fields, cascade updates, multi-tenant scoping via `Region`) to faithfully mock. Mocked repositories produce **false confidence** — they pass locally but fail in production because the mock cannot reproduce the real persistence layer's behavior.

**Therefore**: ALL integration and E2E tests that touch the data persistence layer MUST run against real Docker infrastructure. ALL unit tests that test pure business logic (no persistence) may use in-memory objects.

---

## Test Categories

### 1. Unit Tests (Pure Logic, No Persistence)

Unit tests test **business logic in isolation** — service methods, validators, formatters, converters — WITHOUT any data access.

**Rules:**
- May use in-memory objects, `List<T>`, mocks of interfaces (not `IRestme`)
- Must NOT access `MongoDbCentre`, `DataRepository<T>`, or any persistence-layer component
- Must NOT require Docker containers to be running
- Must run in CI/CD (no `[SkipCI]` attribute needed)

**Example:**
```csharp
public class ProductServiceTests
{
    [Fact]
    public void CalculatePrice_WithDiscount_ReturnsCorrectAmount()
    {
        var product = new Product { BasePrice = 100m, DiscountPercent = 15m };
        var result = ProductService.CalculatePrice(product);
        Assert.Equal(85m, result);
    }

    [Fact]
    public void CalculatePrice_NullProduct_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => ProductService.CalculatePrice(null!));
    }
}
```

### 2. Integration Tests (Real Infrastructure, Data Layer)

Integration tests exercise **data access** — repositories, API endpoints, services that query/write to the database.

**Rules:**
- MUST use `[Trait("Category", "Integration")]` on test classes/methods
- MUST use `[Category("SkipCI")]` to exclude from CI/CD
- MUST run against **real Docker containers** (MongoDB, Redis, ClickHouse, etc.)
- Must seed real test data before each test
- Must NOT use `FakeMongoCollection<T>`, `InMemoryDatabase`, or mock `IRestme`
- Must NOT run in CI/CD (`dotnet test --filter "Category!=Integration"`)

**Prerequisites before running:**
```bash
# Step 1: Verify required services are healthy
docker compose -f docker-compose.dev.yml ps

# Step 2: If any required service is down, start it
docker compose -f docker-compose.dev.yml up -d mongodb redis clickhouse

# Step 3: Run integration tests
dotnet test --filter "Category=Integration"
```

**Test project structure:**
```
MyProject.IntegrationTests/
├── Repositories/
│   ├── ProductRepositoryTests.cs      # [Trait("Category", "Integration")]
│   ├── OrderRepositoryTests.cs
│   └── CustomerRepositoryTests.cs
├── Services/
│   ├── ProductServiceIntegrationTests.cs
│   └── OrderServiceIntegrationTests.cs
├── Controllers/
│   ├── ProductsControllerTests.cs      # WebApplicationFactory<T>
│   └── OrdersControllerTests.cs
├── TestFixtures/
│   ├── MongoTestContainerFixture.cs    # Docker container lifecycle
│   └── TestDataSeeder.cs               # Real test data seeding
└── MyProject.IntegrationTests.csproj
```

### 3. API Tests (Endpoint-Level Integration)

API tests use `WebApplicationFactory<T>` to hit **actual HTTP endpoints** — not calling the service method directly.

**Rules:**
- MUST test every controller action (GET, POST, PUT, DELETE)
- MUST use `WebApplicationFactory<TProgram>` for in-process testing
- MUST run against real Docker infrastructure (connected via localhost)
- MUST verify the full pipeline: request → middleware → controller → service → repository → database → response

**Example:**
```csharp
public class ProductsControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ProductsControllerTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    [Trait("Category", "Integration")]
    [Category("SkipCI")]
    public async Task GetProducts_ReturnsProductsList()
    {
        var response = await _client.GetAsync("/api/v1/products");
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<ApiResponse<List<ProductDto>>>(json);
        Assert.NotNull(result);
        Assert.NotEmpty(result.Data);
    }

    [Fact]
    [Trait("Category", "Integration")]
    [Category("SkipCI")]
    public async Task CreateProduct_WithValidData_Returns201()
    {
        var product = new CreateProductDto
        {
            Name = "Test Product",
            Price = 99.99m,
            Sku = "TEST-001"
        };
        var content = new StringContent(
            JsonSerializer.Serialize(product),
            Encoding.UTF8,
            "application/json");

        var response = await _client.PostAsync("/api/v1/products", content);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        // Verify data was persisted (round-trip)
        var createdProduct = await _client.GetAsync("/api/v1/products");
        var json = await createdProduct.Content.ReadAsStringAsync();
        Assert.Contains("Test Product", json);
    }
}
```

### 4. E2E Browser Tests (Playwright — Sophia/Olivia responsibility)

E2E tests validate the **complete user journey** in real browsers. These are the responsibility of Sophia (implementation) and Olivia (validation).

**Rules:**
- MUST run against a **live running dev server** (`npm run dev` / `dotnet run`)
- MUST verify API calls are actually made (use `page.route()`)
- MUST NOT assert on hardcoded data ("Premium Widget", "$49.99")
- MUST follow the 8 E2E Quality Gates (see AGENTS.md Part II, Olivia role)

---

## Mandatory Test Coverage

### Per Feature Minimums

| Component Type | Unit Tests | Integration Tests | API Tests |
|---------------|-----------|-------------------|-----------|
| Service method (business logic) | 1 per method, covering: happy path, null input, invalid input, boundary, error | N/A | N/A |
| Repository method (data access) | N/A | 1 per method, against real Docker | N/A |
| Controller action (API endpoint) | N/A | N/A | 1 per action, using `WebApplicationFactory<T>` |
| Full CRUD feature | 5+ | 10+ | 5+ |

### Code Coverage Thresholds

- **Minimum**: 70% line coverage for ALL new code
- **Target**: 80%+ for service and repository layers
- **Enforced**: `dotnet test --collect:"XPlat Code Coverage"`

---

## Test Data Seeding

Integration tests MUST seed **real test data** into Docker-based MongoDB/Redis before running.

**Rules:**
- Test data must match real entity shapes and constraints
- Must NOT use hardcoded fake data ("Test Product", "Fake User")
- Must NOT rely on pre-existing seed data from development
- Must clean up test data after each test (or use unique collections per test)

**Example:**
```csharp
public class TestDataSeeder
{
    private readonly IMongoCollection<Product> _products;

    public TestDataSeeder(IMongoCollection<Product> products)
    {
        _products = products;
    }

    public async Task SeedTestProductsAsync()
    {
        // Clean existing test data
        await _products.DeleteManyAsync(p => p.Name.StartsWith("TEST-"));

        // Seed real entity shapes
        var products = new List<Product>
        {
            new()
            {
                Name = "TEST-Widget-Alpha",
                Price = 49.99m,
                Sku = "TEST-WG-001",
                Status = EntityStatus.Active,
                CreatedOnUtc = DateTime.UtcNow
            },
            new()
            {
                Name = "TEST-Widget-Beta",
                Price = 29.99m,
                Sku = "TEST-WG-002",
                Status = EntityStatus.Active,
                CreatedOnUtc = DateTime.UtcNow
            }
        };

        await _products.InsertManyAsync(products);
    }
}
```

---

## Pre-Commit Gate (Daniel MUST Follow)

Before pushing to remote (MR), Daniel MUST execute this exact sequence:

```bash
# Step 1: Start Docker infrastructure
docker compose -f docker-compose.dev.yml up -d

# Step 2: Verify all services are healthy
docker compose -f docker-compose.dev.yml ps
# All required services must show "healthy"

# Step 3: Run unit tests (CI mode — no Docker required)
dotnet test --configuration Release --filter "Category!=Integration"
# MUST pass with 0 failures

# Step 4: Run integration tests (requires Docker running)
dotnet test --configuration Release --filter "Category=Integration"
# MUST pass with 0 failures

# Step 5: Verify code coverage
dotnet test --configuration Release --collect:"XPlat Code Coverage"
# MUST be >=70% line coverage for all new code

# Step 6: If ANY test fails, FIX IT LOCALLY
# DO NOT push with failing tests.
# DO NOT push with "I'll fix later."
```

---

## CI/CD Configuration

All `.gitlab-ci.yml` pipelines MUST skip data-layer integration tests:

```yaml
# In CI/CD pipeline:
test:
  script:
    - dotnet test --configuration Release --filter "Category!=Integration"
```

**Never** attempt to spawn Docker containers in CI/CD. The CI environment does not have Docker available, and container spawning is a security and resource risk.

---

## Common Anti-Patterns (REJECTED)

| Anti-Pattern | Why It's Wrong |
|-------------|----------------|
| `FakeMongoCollection<T>` or `InMemoryDatabase` | Cannot reproduce real persistence behavior (denormalized fields, cascade updates, multi-tenant scoping) |
| Mocking `IRestme` interface | OElite data structures are too complex to faithfully mock |
| Assertions on hardcoded data ("Test Product") | Tests pass even if the API returns completely different data |
| Unit test calling `MongoDbCentre` directly | This IS an integration test — must use `[Trait("Category", "Integration")]` |
| No cleanup of test data after test | Tests become non-deterministic and flaky |
| Running integration tests in CI/CD | Docker containers are not permitted in CI/CD |

---

## Verification

Before declaring any backend change "done", Daniel MUST confirm:

- [ ] `docker compose -f docker-compose.dev.yml ps` shows all required services healthy
- [ ] `dotnet test --filter "Category!=Integration"` → 0 failures
- [ ] `dotnet test --filter "Category=Integration"` → 0 failures
- [ ] `dotnet test --collect:"XPlat Code Coverage"` → >=70% line coverage
- [ ] No mock/placeholder/TODO data in delivered code
- [ ] All integration tests use real Docker containers (no `FakeMongoCollection`, no `InMemoryDatabase`)
- [ ] All API tests use `WebApplicationFactory<T>` (no direct service method calls)
