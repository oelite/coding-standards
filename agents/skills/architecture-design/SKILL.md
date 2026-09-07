# Architecture Design Skill

**Skill ID:** architecture-design
**Status:** active (registered in agents/skills/SKILLS.md)
**Default loaders:** Marcus
**On-demand loaders:** Daniel, Sophia, Grace, Felix, Emma
**Owner:** Marcus
**Issue:** #19
**Built on:** Skills Framework (#18) | Formatting Policy (#17) | OElite Framework Primer (agents/core/principles.md)

---

## 1. Mission and When to Load

This skill equips agents with structured architecture decision-making so that backend features land in ways that are maintainable, scalable, tenant-safe, and consistent with the OElite platform. It is the source of truth for layer boundaries, service decomposition, data modeling, API design, trade-off analysis, ADRs, dependency hygiene, scalability, and security-by-design at the architecture level.

**Load this skill when the request contains any of these trigger phrases:**

- architect, architecture, system design, service design
- design pattern, which pattern, should I use X vs Y, compare X and Y
- data modeling, MongoDB schema, denormalize, cascade
- ADR, architecture decision record, decision doc
- layer violation, anemic domain model, god service, service split
- refactor architecture, modernize the service, decompose the monolith
- REST conventions, API design, versioning strategy
- trade-off, performance vs maintainability, CAP, build vs buy
- caching strategy, queue, horizontal scale, premature optimization
- OWASP, threat model, authn/authz, multi-tenant isolation, GDPR
- before and after, what is the OElite way to do X, is this idiomatic

**When NOT to load this skill:**

- The request is purely cosmetic -- load formatting instead.
- The request is a UI-only polish -- load frontend-design or ux-design.
- The request is a security audit of a specific change -- load security-design.
- The request is a known bug with a known fix -- apply debugging and skip ahead.

If after loading this skill a decision is architecturally significant, stop and ask Marcus explicitly. Do not proceed.

## 2. OElite Architecture Patterns (Canonical)

The OElite framework enforces a strict N-tier layering. The rules below are non-negotiable; deviations require an ADR.

### 2.1 Layering overview

    Common  ->  Data  ->  Services  ->  Servers/Api
    (pure)   (IO)    (logic)      (transport)

- Common: POCOs, enums, extension methods, value objects. No I/O.
- Data: repositories, Mongo entities, IRestme gateways. No business rules.
- Services: business logic, orchestration, transactions, cross-cutting. All business decisions live here.
- Servers/Api: controllers, DTOs, response formatters. Translate transport concerns only.

### 2.2 Entity layer

Entities inherit BaseEntity (uranus/restme/OElite.Restme.Utils/BaseEntity.cs):

```csharp
[DbCollection("products")]
public class Product : BaseEntity
{
    public string Name { get; set; }
    public decimal Price { get; set; }
    public string? Region { get; set; }
    public MetaData MetaData { get; set; }
    public EntityStatus Status { get; set; }
}
```

Rules:

- Inherit BaseEntity always. Provides DbObjectId Id, Status, Region, MetaData.
- Decorate every entity with [DbCollection("snake_case_name")].
- Typed lists: BaseEntityCollection<T> (not List<T>).
- Tenant isolation: Region (nullable). Use IOwnedEntity for strict tenant scoping.
- No DTOs in this layer. No HTTP attributes. No business methods on entities.
- Soft delete via Status = EntityStatus.Deleted. Never hard-delete without an ADR.
- Reference: helios/core/OElite.Common.Platform/Biz/Products/Product.cs

### 2.3 Repository layer

```csharp
public class ProductRepository : DataRepository<PlatformDb>, IProductRepository
{
    public Task<Product?> GetByIdAsync(DbObjectId id) => ...;
    public Task<BaseEntityCollection<Product>> ListAsync(Query query) => ...;
    public Task InsertAsync(Product product) => ...;
    public Task UpdateAsync(Product product) => ...;
}
```

Repositories do exactly four things:
1. GetByIdAsync(DbObjectId id) -> T?
2. ListAsync(Query query) -> BaseEntityCollection<T>
3. InsertAsync(T entity)
4. UpdateAsync(T entity)

Anything beyond these four is business logic and belongs in a service.

Forbidden in repositories: validation, transformation, multi-entity orchestration, caching policy, event emission, logging beyond a single repository call, HTTP concerns.

- Inherit DataRepository<TDbCentre> (helios/core/OElite.Data/).
- Never use MongoDB.Driver, BsonDocument, or new MongoClient(...) directly. Use IRestme / Rest (uranus/restme).

### 2.4 Service layer

```csharp
public interface IProductService : IScopedService
{
    Task<ProductDto> CreateAsync(CreateProductRequest req, CancellationToken ct);
    Task<ProductDto?> GetAsync(DbObjectId id, CancellationToken ct);
    Task<BaseEntityCollection<ProductDto>> ListAsync(ListProductsQuery q, CancellationToken ct);
}

public class ProductService : IProductService
{
    public ProductService(IProductRepository repo, IAuditService audit) { ... }
}
```

Rules:

- Implement IOEliteService, ISingletonService, IScopedService, or ITransientService. The lifetime is a deliberate choice documented in the interface.
- Auto-discovered via AddOEliteDependencyInjections(). No manual services.AddScoped<...>() in Program.cs.
- Constructor injection only. No service locator. No static state.
- Cancellation tokens on every async method. Required.
- Throw typed exceptions (NotFoundException, ValidationException, ConflictException) -- never raw Exception and never raw HTTP status numbers.

### 2.5 Controller layer

```csharp
[ApiController]
[Route("api/v1/products")]
public class ProductController : ControllerBase
{
    public ProductController(IProductService service) { ... }

    [HttpPost]
    [TransformedResponse(typeof(ProductDto))]
    public async Task<ProductDto> Create([FromBody] CreateProductRequest req, CancellationToken ct)
        => await _service.CreateAsync(req, ct);
}
```

Rules:

- Controllers are thin: parse input, call service, return DTO.
- Never call repositories from a controller.
- Never return entities. Always return DTOs.
- Decorate endpoints with [TransformedResponse(typeof(T))] so Swagger shows the unwrapped type while the runtime wraps it in ApiResponse<T>.
- OEliteApiOutputFormatter (auto-registered) is the only response wrapper. Do not hand-build { success: true, data: ... } envelopes.
- Validate input with FluentValidation; validation lives in the service layer for domain rules; transport-level shape validation lives in the controller.

### 2.6 DTO layer

DTOs are POCO classes with no behavior and no entity leakage.

```csharp
public record ProductDto(
    DbObjectId Id, string Name, decimal Price,
    string? Region, EntityStatus Status, DateTimeOffset CreatedAt);

public record CreateProductRequest(string Name, decimal Price, string? Region);

public record ListProductsQuery(string? Search, int Page = 1, int PageSize = 25);
```

Rules:

- Request DTO: input shape (what the client sends).
- Response DTO: output shape (what the client receives).
- Never share a DTO between request and response. They drift.
- Never include a BaseEntity field directly. Map entity to DTO via explicit ToDto() or Mapster (not AutoMapper, which is reflective and breaks NativeAOT).
- DTOs live next to the controller that uses them, or in Api/Contracts/ per bounded context.
- DTOs must include an explicit versioned namespace or folder (V1/, V2/) when the API version changes.

## 3. Data Modeling Principles

OElite is document-first (MongoDB via Restme). The right model maximizes read locality and consistency safety while keeping write amplification reasonable.

### 3.1 When to denormalize

| Signal | Decision |
|--------|----------|
| High read, low write, small payload | Denormalize -- copy the field with [DenormalizedField] |
| High write (sustained above one write per sec) | Reference -- store the ID, join at read time |
| Large sub-document (over N KB where N is db limit) | Reference -- keeps the doc under size limit |
| Frequently independent queries | Reference -- keeps the index small |
| Cross-collection consistency under one second | Reference plus cascade (see Section 3.2) |

Decorate entities:

```csharp
public class Order
{
    [DenormalizedField(fromCollection: "customers", fromField: "Name", referenceKey: "CustomerId")]
    public string CustomerName { get; set; }

    [DenormalizedCollection(typeof(LineItem), "OrderId")]
    public BaseEntityCollection<LineItem> LineItems { get; set; }
}
```

Substitution syntax: at-PuppetName (current entity), hash-PuppetName (one level nested).

### 3.2 Cascade rules

- Real-time (via CascadeUpdateService): for invariants that must hold within the same request -- e.g., a customer's default address change must be visible on the order before the next read.
- Async (via DataSyncJob to RabbitMQ): for invariants that can lag by seconds-to-minutes -- e.g., aggregate counters, search indexes, audit trails.

Choose real-time when the user can observe the staleness in the same session. Choose async when the staleness is invisible to the user.

### 3.3 Modeling relationships in a document DB

- One-to-one: usually embedded unless the sub-document is large or independent.
- One-to-few (fewer than fifty children): embedded array.
- One-to-many (fifty to 10000): child collection with parent ID plus cascade.
- One-to-millions: child collection with parent ID and bucketed partition key (e.g., EventsByDay). Never embed millions.
- Many-to-many: join collection with two ID arrays indexed. Avoid array-of-IDs on both sides.

### 3.4 Indexes

- Every entity must declare its query-critical indexes in EnsureIndexesAsync (called on app bootstrap). Unindexed queries are a P-one incident at scale.
- Compound index field order matters: equality first, then range, then sort.
- TTL indexes for time-bounded data (sessions, audit windows, OTP codes).

## 4. Service Design Heuristics

### 4.1 When to create a new service

Create a new service when any of these is true:

1. The responsibility is distinct from existing services (single responsibility).
2. The new service has different lifetime needs (singleton vs scoped).
3. The new service is reused across multiple bounded contexts.
4. The new service encapsulates an external integration (payment gateway, email provider, search indexer) -- keeps vendor lock-in local.

Do NOT create a new service when:
- The logic is a single small method used in one place. Put it in the existing service.
- The service is just a static helper. Use a static class or an extension method.
- You are splitting for cleanliness alone with no reuse and no distinct boundary. That is premature decomposition.

### 4.2 Single-responsibility check

A service should answer one question: "What does this service own?"

- OK: OrderPricingService -- owns pricing rules and discounts.
- NOT OK: OrderEverythingService -- owns order CRUD, pricing, payment, email, PDF.

If you cannot state the service's responsibility in a single noun phrase without "and", it is doing too much. Split.

### 4.3 Service composition patterns

Orchestration (preferred):

```csharp
public class CheckoutService : ICheckoutService
{
    public CheckoutService(
        IOrderService orders, IPaymentService payments,
        IInventoryService inventory, INotificationService notifications) { ... }

    public async Task<Receipt> CheckoutAsync(Cart cart, CancellationToken ct)
    {
        await _inventory.ReserveAsync(cart.Items, ct);
        var order = await _orders.CreateAsync(cart, ct);
        var payment = await _payments.ChargeAsync(order, ct);
        await _notifications.SendReceiptAsync(order, payment, ct);
        return new Receipt(order, payment);
    }
}
```

Anti-patterns to reject in code review:

- God service -- 50+ methods, depends on 10+ other services, more than 500 LOC. Split.
- Anemic service -- interface with 30 methods, each a one-line pass-through to a repository. Either delete the service or move the logic into it.
- Circular service dependency -- A depends on B depends on A. Extract a third service C.
- Static state -- `public static List<X> Cache = new();` in a service. Use IMemoryCache or IRestmeCache with explicit TTL.

### 4.4 Cross-service coordination

- Synchronous within one bounded context: orchestrator calls services sequentially inside one transaction (Restme IUnitOfWork).
- Asynchronous across bounded contexts: publish a RabbitMQ event (`_restme.PublishAsync<IntegrationEvent>(...)`) and let the consumer react. Never call across contexts synchronously.

## 5. API Design Principles

### 5.1 REST conventions

- Resource nouns, not verbs. /orders not /createOrder.
- Plural collections. /orders/{id}/line-items.
- HTTP verbs map to CRUD: GET (read), POST (create), PUT (replace), PATCH (partial update), DELETE (remove).
- Sub-resources for ownership: /orders/{id}/payments, not /payments?orderId=...
- Filtering, sorting, paging on collections: query string params.

### 5.2 HTTP status code usage

| Status | When |
|--------|------|
| 200 OK | Successful read or update with body |
| 201 Created | Successful create -- Location header points to new resource |
| 204 No Content | Successful delete or update with no body |
| 400 Bad Request | Validation failure, malformed input |
| 401 Unauthorized | No or invalid token |
| 403 Forbidden | Token valid but lacks permission for this resource/tenant |
| 404 Not Found | Resource does not exist (or is not visible to this tenant) |
| 409 Conflict | Uniqueness violation, optimistic concurrency conflict |
| 422 Unprocessable Entity | Semantically invalid (state transition not allowed) |
| 429 Too Many Requests | Rate limit exceeded -- Retry-After header set |
| 500 Internal Server Error | Unhandled server fault (logged with correlation ID) |
| 503 Service Unavailable | Maintenance or upstream dependency down -- Retry-After set |

Do not return 200 with { success: false, error: "..." } in the body. Use the correct status code and let OEliteApiOutputFormatter shape the body.

### 5.3 Idempotency

- All POST endpoints that create resources must accept an Idempotency-Key header. Replays return the original result.
- All PUT and DELETE are naturally idempotent. PATCH is not.
- GET is always idempotent and safe.

### 5.4 Pagination -- the standard shape

Use BaseEntityCollection<T> everywhere. Do not invent ad-hoc envelopes.

```csharp
public record PagedResult<T>(
    IReadOnlyList<T> Items, int Page, int PageSize, int TotalCount, bool HasMore);
```

Query string convention: ?page=1&pageSize=25&sort=-createdAt.
Default pageSize is 25. Max pageSize is 200 -- reject anything larger with 400 Bad Request.
For very large datasets, prefer cursor-based pagination (?after=<opaqueCursor>) over offset pagination to avoid deep-page scans.

### 5.5 Error response format

OEliteApiOutputFormatter produces:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "Name is required",
    "details": [{ "field": "name", "code": "REQUIRED", "message": "Name is required" }],
    "correlationId": "0HMD..."
  }
}
```

- code: stable machine-readable identifier. Clients switch on it.
- message: human-readable, may be localized.
- details: per-field array for validation errors.
- correlationId: ties the response to the structured log entry.

### 5.6 Versioning strategy

- URI versioning is the default: /api/v1/orders, /api/v2/orders.
- Major version bump when breaking: removed field, renamed field, type change, new required field, semantic change.
- Minor additive changes stay within the same major version.
- Maintain v(N-1) for at least six months after v(N) ships.

### 5.7 [TransformedResponse] usage

Annotate every action that returns a DTO so Swagger displays the unwrapped type. The runtime still wraps it in ApiResponse<T> for the wire.

```csharp
[HttpGet("{id}")]
[TransformedResponse(typeof(ProductDto))]
public async Task<ProductDto> Get(DbObjectId id, CancellationToken ct) => ...;
```

## 6. Trade-Off Analysis Framework

Every significant architectural decision is a trade-off. Be explicit.

### 6.1 The trade-off axes

| Axis | Left side | Right side |
|------|-----------|------------|
| Performance vs Maintainability | Faster, less idiomatic | Slower, idiomatic |
| Simplicity vs Flexibility | Single use case solved well | Pluggable / configurable |
| Consistency vs Availability | Strong consistency | High availability |
| Build vs Buy | Custom code we own | SaaS / managed service |
| Sync vs Async | Inline, request-scoped | Queue / event, fire-and-forget |
| Strong typing vs Dynamic | Typed contracts end-to-end | Dictionary / JSON pass-through |
| One vs Many | Single service, multiple | Separate services per concern |

Choose left: hot path, measured bottleneck, YAGNI, money/inventory, core differentiator, user waits for result, multiple teams, tight coupling.
Choose right: cold path, team velocity, two or more consumers, commodity capability, side effects, one-shot internal tool, independent scaling/ownership.

### 6.2 One-vs-Many decision table (concrete)

| Question | Yes means split | No means keep together |
|----------|----------------|----------------------|
| Do the concerns have different scaling profiles? | Yes | |
| Do they have different security or tenancy boundaries? | Yes | |
| Are they owned by different teams? | Yes | |
| Do they have different availability requirements? | Yes | |
| Is the shared code a library, not orchestration? | | Yes |
| Does splitting add network hops for every call? | | Yes |

If you answer "Yes" to two or more of the first four, split.
If you answer "Yes" to either of the last two, keep together.

### 6.3 Decision template (copy-paste)

    ## Decision: <one-sentence title>

    ### Context
    What problem are we solving? What constraints exist?

    ### Options considered
    For each option:
    - Description
    - Pros (concrete, measurable)
    - Cons (concrete, measurable)
    - Cost (LOC, dev-time, runtime, operational)

    ### Decision
    We will <option>. Because <reasoning that weighs the pros/cons>.

    ### Consequences
    - Positive: what gets better.
    - Negative: what gets worse, what we accept.
    - Neutral: what changes but is neither better nor worse.

    ### Reversibility
    How easy is it to undo? (cheap / moderate / expensive)

    ### Follow-ups
    - Monitoring, metrics, owner of follow-up tasks.

## 7. Architecture Decision Record (ADR) Template

ADRs are immutable once accepted. To change a decision, write a new ADR that supersedes the old one. ADRs live in <repo>/docs/adr/NNNN-title.md (NNN is a zero-padded sequence number, monotonically increasing).

```markdown
# ADR-NNNN: <Short imperative title>

- **Status:** proposed | accepted | superseded by ADR-XXXX | deprecated
- **Date:** YYYY-MM-DD
- **Deciders:** Marcus, <other stakeholders>
- **Consulted:** Daniel, Grace, Maya, Victor
- **Informed:** Emma, Sophia, Ethan, Olivia, Isabella

## Context and Problem Statement

<context-placeholder>. <problem-placeholder>.

## Decision Drivers

- <driver one>
- <driver two>
- <driver three>

## Considered Options

1. <option alpha>
2. <option beta>
3. <option gamma>

## Decision Outcome

**Chosen option:** "<option>", because <consequence paragraph>.

### Positive Consequences

- <positive one>
- <positive two>

### Negative Consequences

- <negative one and mitigation>

### Neutral Consequences

- <neutral change>

## Pros and Cons of the Options

### <Option Alpha>

- **Good**, because <argument>
- **Bad**, because <argument>
- **Neutral**, because <argument>

### <Option Beta>

- **Good**, because ...
- **Bad**, because ...

## Links / References

- <link to relevant issue, RFC, doc, or external reference>

## Follow-ups

- [ ] <task> -- owner: <name> -- due: <date>
```

Rules for ADRs:

- One decision per ADR. If you need to decide two things, write two ADRs.
- Use imperative mood in the title ("Use cursor pagination", not "Cursor pagination considered").
- Status transitions: proposed, then accepted, then superseded or deprecated.
- Never edit an accepted ADR. To change, write a new one and link to the old.
- ADRs are code-reviewed like code. They go through the same MR flow.

## 8. Dependency Management Heuristics

### 8.1 When to introduce a new library

Introduce a library when all of these are true:

1. The capability is not already in the OElite platform (Restme, origin-auth, Kortex, helios/core).
2. The library is maintained (last commit under 6 months, recent releases, responsive issues).
3. The library is permissively licensed (MIT, Apache 2.0, BSD). Avoid GPL/LGPL/AGPL.
4. The library is used in production elsewhere at scale.
5. The library is small or has a tree-shakable distribution.
6. The transitive dependency tree is reasonable (fewer than 30 packages, no known conflicts).

If any one of these is false, stop and ask. If the capability is in Restme or another OElite platform package, always choose the platform capability. Consistency and supportability outweigh minor feature differences.

### 8.2 When to use OElite platform capabilities instead

| Need | OElite platform capability | Avoid |
|------|---------------------------|-------|
| HTTP, Redis, Mongo, etc. | IRestme / Rest (uranus/restme) | Raw MongoDB.Driver, StackExchange.Redis, RabbitMQ.Client |
| Caching | IRestmeCache with TTL semantics | Microsoft.Extensions.Caching.Memory (raw) |
| Auth, JWT, tokens | uranus/origin-auth | System.IdentityModel.Tokens.Jwt, jose-jwt |
| API gateway or edge auth | helios/kortex | Ocelot, YARP |
| Background jobs | mercury/runners/Backplane | Hangfire (per-service), Quartz |
| PDF generation | Platform report service | Raw iTextSharp, PdfSharp ad hoc |
| Email | Platform notification service | Direct SMTP via MailKit per service |
| Search | IRestme to OpenSearch | Raw OpenSearch.Net |

### 8.3 Cargo-cult anti-pattern

Do not adopt a library because: "Everyone uses it", "it looks cool on the README", a blog post said so, or it is what the developer used at their previous company. Each dependency is a long-term maintenance cost. Treat it like a hire.

### 8.4 Transitive dependency audit

- Run dotnet list package --vulnerable --include-transitive in CI.
- Fail the build on any High or Critical CVE.
- Review the transitive tree on every major upgrade. Lock file is authoritative.
- Quarterly: run dotnet list package --outdated and triage.

## 9. Scalability Heuristics

### 9.1 When premature optimization is wrong

Do not optimize before you have a measured bottleneck (pprof, dotTrace, Application Insights, Grafana). Do not introduce caching, sharding, queues, or read replicas on day one.

The right time to optimize:
1. The bottleneck is measured, not guessed.
2. The optimization is the simplest one that fixes the measurement.
3. The team has the observability to verify the fix worked.

### 9.2 Horizontal vs. vertical scaling

- Vertical first (bigger box) is fine for most services up to roughly 80 percent CPU sustained. It is a one-line config change.
- Horizontal (more boxes) when: CPU is sustained high and the box is already large; you need availability (N+1 redundancy); the workload is stateless (or you have sticky sessions or shared state).
- Sharded (data partitioned) when: a single Mongo collection is too large for one node; write throughput exceeds one primary; the shard key is high-cardinality and the access pattern is shard-local.

### 9.3 Caching -- the OElite standard

Use the grace period + background refresh pattern via IRestmeCache:

```csharp
return await _cache.GetOrRefreshAsync(
    key: $"product:{id}",
    gracePeriod: TimeSpan.FromMinutes(5),
    refreshInterval: TimeSpan.FromMinutes(1),
    factory: async (token) => await _repo.GetByIdAsync(id, token),
    cancellationToken: ct);
```

- Grace period: how long the stale value may be served while a fresh fetch is in flight.
- Refresh interval: how often the background refresh runs.
- Stampede protection: only one process refreshes at a time per key (Restme handles this).
- Cache invalidation on write: call _cache.RemoveAsync(key) in the same transaction.
- Never cache without a TTL. Never cache without an invalidation path on writes.

### 9.4 Queue-based processing

Use mercury/runners/Backplane (or Restme queue) when:

- The work is asynchronous by nature (email, indexing, analytics).
- The work is CPU- or time-expensive and would blow the request budget.
- The work must survive process restart (durable queue, ack-on-success).
- The work is rate-limited by an upstream (payment gateway, search indexer).

Do not queue when: the user is waiting for the result in the same request; the work is trivial (under five ms) -- queue overhead exceeds the work; you need exactly-once semantics. Queues give at-least-once. Design idempotently.

### 9.5 Read replicas

- Use read replicas when the read-to-write ratio exceeds ten to one and the primary is saturated.
- Replicas lag. Do not read from a replica when the user just wrote and expects to see their write. Read-after-write must go to the primary.
- Replica selection via IRestme connection string per environment.

## 10. Security-by-Design at Architecture Level

### 10.1 Authentication and Authorization model

- All API endpoints (except /health, /metrics, /auth/login) require a valid JWT issued by origin-auth.
- Authorization: RBAC via role claims in the JWT. Roles map to permission sets defined in helios/kortex.
- Never trust the user's input for authorization decisions. The JWT tenant and user ID are the source of truth.
- Validate the JWT on every request (middleware in helios/core). Do not decode JWT manually in service code.
- Reference: uranus/origin-auth, helios/core OElite.Auth.

### 10.2 Multi-tenant isolation

- Tenant isolation is enforced at the data layer. Every repository query MUST include the tenant Region filter.
- Use IOwnedEntity or the Region field on BaseEntity. Never rely on application-layer filtering alone.
- Cross-tenant data access is blocked at the repository query level. Any discovered cross-tenant data leak is a P-zero security incident.
- API endpoints must not accept a tenant ID from the client. The tenant comes from the JWT claims.
- No data from one tenant in the logs, metrics, or error messages visible to another tenant.

### 10.3 GDPR and region handling

- Data residency: each region has its own MongoDB cluster and API endpoint. Users are pinned to their home region.
- Right to erasure: IRestme supports soft-delete via Status = Deleted. Hard-delete with cryptographic erasure (DB rename + drop) is supported via uranus/restme-dapper for relational data. Document any hard-delete with Maya.
- Data portability: the /api/v1/export endpoint serves all user data as JSON. Audit the export before implementing.
- PII minimization: do not collect PII unless it is necessary for the feature. If collected, log it only in redacted form.

### 10.4 Secret management

- Secrets are never in code, config files committed to git, or environment variables that are logged.
- Use uranus/restme SecretsService (backed by Azure Key Vault or similar per environment).
- Secrets are injected at runtime via IOptions<T> pattern or ISecretProvider.
- Rotation: secrets rotate every 90 days automatically via the platform. Do not hard-code expiry assumptions.
- In code, use nameof(WellknownSecret.ApiKey) -- never the literal string value.

### 10.5 Audit logging

- Every mutation (create, update, delete) on business entities must emit an audit event to the audit log (Restme IAuditLog).
- Audit event schema: who (user ID + JWT), what (entity type + ID + before/after diff), when (UTC timestamp), where (API endpoint + correlation ID).
- Audit logs are immutable and retained for seven years. They live in a separate MongoDB collection.
- Sensitive fields (password, payment card, SSN) are redacted before logging. Verify redaction with Maya.

### 10.6 Common vulnerability patterns to block at architecture level

| Vulnerability | Architecture mitigation |
|---|---|
| SQL / NoSQL injection | Parameterized queries via Restme ORM -- never string-concatenate queries |
| Broken auth | origin-auth JWT validation middleware -- never bypass |
| Sensitive data exposure | DTO projection -- never return entities; always project to a defined DTO |
| Mass assignment | Request DTOs -- client can never set Id, Status, TenantId, computed fields |
| XXE | Restme HTTP client disables external entity resolution by default |
| SSRF | Restme HttpClientFactory with allowlist for internal endpoints |
| CSRF | SameSite cookies + CSRF token on state-changing endpoints |
| Insecure deserialization | Use System.Text.Json with type-name handling disabled; never BinaryFormatter |

## 11. Before/After Architecture Examples

### 11.1 Example A -- God service split into composition

Before -- anti-pattern (REJECT in code review):

```csharp
public class OrderService
{
    public OrderService(
        IOrderRepository orders, ICustomerRepository customers,
        IPaymentGateway payment, IEmailService email,
        IPdfGenerator pdf, IInventoryRepository inventory) { ... }

    public async Task<Order> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.ShippingAddress))
            throw new Exception("bad address");
        if (req.Items == null || !req.Items.Any())
            throw new Exception("no items");

        decimal total = 0;
        foreach (var item in req.Items)
        {
            var product = await _inventory.GetByIdAsync(item.ProductId, ct);
            if (product.Stock < item.Quantity) throw new Exception("out of stock");
            total += product.Price * item.Quantity;
        }
        ApplyBulkDiscount(ref total);

        var order = new Order { /* ... */ };
        await _orders.InsertAsync(order, ct);
        var charge = await _payment.ChargeAsync(req.CardToken, total, ct);

        await _email.SendAsync(req.CustomerEmail, "Order placed", "Thanks!");
        var invoice = _pdf.Generate(order);
        await _email.SendAttachmentAsync(req.CustomerEmail, invoice);
        return order;
    }
}
```

Why this is rejected:

- OrderService does six distinct responsibilities. Violates single responsibility.
- Throws raw Exception with unstructured messages. No correlation ID.
- The 10 percent discount is buried in the middle of a method. No test surface, no reuse.
- PDF generation is a blocking call in an async path.
- Email and PDF are inline -- if email provider is down, order succeeds but customer never knows.
- No CancellationToken propagation throughout.

After -- clean composition (PASS):

```csharp
public interface IOrderService : IScopedService
{
    Task<OrderDto> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct);
}

public class OrderService : IOrderService
{
    public OrderService(
        IOrderValidator validator, IOrderPricingService pricing,
        IOrderRepository orders, IPaymentService payments,
        IOrderEventPublisher events) { ... }

    public async Task<OrderDto> PlaceOrderAsync(PlaceOrderRequest req, CancellationToken ct)
    {
        await _validator.ValidateAsync(req, ct);
        var priced = await _pricing.PriceAsync(req.Items, ct);
        var order = Order.CreateFrom(priced, req.ShippingAddress);
        await _orders.InsertAsync(order, ct);
        var payment = await _payments.ChargeAsync(order, ct);
        await _events.PublishAsync(new OrderPlaced(order, payment), ct);
        return order.ToDto();
    }
}

public interface IOrderValidator : IScopedService
    { Task ValidateAsync(PlaceOrderRequest req, CancellationToken ct); }
public interface IOrderPricingService : IScopedService
    { Task<PricedOrder> PriceAsync(IReadOnlyList<LineItem> items, CancellationToken ct); }
public interface IPaymentService : IScopedService
    { Task<Payment> ChargeAsync(Order order, CancellationToken ct); }
public interface IOrderEventPublisher : ISingletonService
    { Task PublishAsync(OrderPlaced evt, CancellationToken ct); }
```

What improved:

- Each service has one responsibility. Testable in isolation.
- OrderPricingService owns all pricing logic. Discounts live here.
- OrderEventPublisher is ISingletonService -- fire-and-forget queue publisher. Lifetime choice is explicit.
- Email and PDF are subscribers to OrderPlaced, not inline calls. They happen async. If email is down, the order still succeeds.
- Typed exceptions replace raw Exception. Framework formatter translates to HTTP.
- The controller is one line: `_service.PlaceOrderAsync(req, ct)`.

### 11.2 Example B -- controller returning entities vs. clean DTOs

Before -- anti-pattern:

```csharp
[ApiController]
[Route("api/orders")]
public class OrderController : ControllerBase
{
    public OrderController(IOrderRepository repo) { ... }

    [HttpGet("{id}")]
    public async Task<Order> Get(string id)
        => await _repo.GetByIdAsync(new DbObjectId(id));

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Order order)
    {
        await _repo.InsertAsync(order);
        return Ok(order);
    }
}
```

Why this is rejected:

- Controller depends on the repository (layer violation).
- Returns the entity directly -- leaks Mongo internals.
- Accepts an entity in the request body -- mass assignment vulnerability.
- No [TransformedResponse], no ApiResponse<T> wrapping.
- No CancellationToken. No DTO separation. Hard-coded route.

After -- clean DTOs (PASS):

```csharp
[ApiController]
[Route("api/v1/orders")]
public class OrderController : ControllerBase
{
    public OrderController(IOrderService service) { ... }

    [HttpGet("{id}")]
    [TransformedResponse(typeof(OrderDto))]
    public async Task<OrderDto> Get(string id, CancellationToken ct)
        => await _service.GetAsync(new DbObjectId(id), ct);

    [HttpPost]
    [TransformedResponse(typeof(OrderDto))]
    public async Task<OrderDto> Create([FromBody] CreateOrderRequest request, CancellationToken ct)
        => await _service.PlaceOrderAsync(request, ct);

    [HttpGet]
    [TransformedResponse(typeof(PagedResult<OrderDto>))]
    public async Task<PagedResult<OrderDto>> List([FromQuery] ListOrdersQuery query, CancellationToken ct)
        => await _service.ListAsync(query, ct);
}
```

What improved:

- Controller depends only on the service.
- Returns DTOs -- never entities.
- Request DTO (CreateOrderRequest) is distinct from the response DTO. No mass assignment.
- [TransformedResponse] on every action. Swagger shows the unwrapped type.
- Versioned route (/api/v1/).
- CancellationToken on every action.
- Paged list uses the platform pagination shape.
- OEliteApiOutputFormatter wraps everything in ApiResponse<T>.

## 12. When to Escalate to Marcus

Loading this skill is not the same as deciding. Some decisions are architecturally significant and MUST go to Marcus for sign-off. If the answer to any of the following is yes, stop, write an ADR (see Section 7), and request Marcus review before proceeding.

| Num | Trigger | Why |
|-----|---------|-----|
| 1 | New service in a new bounded context | Multi-tenant boundaries, scaling, ownership |
| 2 | Introducing a new shared library or framework | Long-term maintenance cost, affects all services |
| 3 | Cross-cutting change (auth, logging, caching, messaging) | Platform-wide blast radius |
| 4 | Security-sensitive architecture (auth, crypto, secrets, GDPR) | Needs Maya plus Marcus together |
| 5 | Breaking change to a public API | Customer-facing, requires deprecation plan |
| 6 | Data model change affecting a shared Mongo collection | Other services may depend on the shape |
| 7 | Choice between two valid OElite patterns (sync vs async) | Trade-off needs adjudication |
| 8 | Migration off a deprecated OElite pattern | Platform coherence |
| 9 | Multi-region or multi-tenant data residency change | Regulatory implications |
| 10 | Performance or scale architecture at the platform level | Operational impact |

For everything else -- routine feature work, bug fixes, single-service refactors, standard CRUD -- load this skill, follow it, ship it. Do not add a Marcus review step to every PR.

How to escalate:
1. Write an ADR draft per Section 7.
2. Open a GitLab issue referencing the ADR draft and tag Marcus.
3. State the question in one sentence, link the ADR, propose a deadline.
4. Do not start implementation until Marcus has signed off.

## 13. Verification Checklist

Code review MUST verify:

- [ ] No business logic in repositories (look for service-layer imports inside repository classes).
- [ ] No raw MongoDB.Driver, BsonDocument, new Rest() in service or controller code.
- [ ] No manual services.AddScoped(...) for types that implement IOEliteService / ISingletonService / IScopedService / ITransientService.
- [ ] No hand-built API response envelopes ({ success: ... }).
- [ ] No entity leakage to controllers (look for using ... Entities in controller files).
- [ ] No shared Request/Response DTOs.
- [ ] All controllers have [TransformedResponse(typeof(T))] on every action.
- [ ] All async methods take CancellationToken and pass it through.
- [ ] All mutations emit an audit log entry when the entity is security-relevant.
- [ ] No "as any", no "@ts-ignore", no "@ts-expect-error".
- [ ] No secrets in code or logs.
- [ ] All new public API endpoints versioned in the URI (/api/v{N}/...).
- [ ] Architecturally significant decisions have an ADR committed in <repo>/docs/adr/.

Self-check at the end of every architecture-touching task:

    Could a new engineer, reading only the OElite framework primer and this skill,
    predict where this code lives, what it depends on, and how it behaves at the
    boundaries? If yes, you followed the skill. If no, refactor.

## 14. Cross-References

- OElite Framework Primer: agents/core/principles.md -- "OElite Framework Primer (Backend)"
- Skills Framework: agents/skills/SKILLS.md (#18)
- Formatting Policy: agents/skills/formatting/SKILL.md (#17)
- Security Design (planned): agents/skills/security-design/SKILL.md (#22)
- Frontend Design (planned): agents/skills/frontend-design/SKILL.md (#21)
- UX Design (planned): agents/skills/ux-design/SKILL.md (#20)
- Git Workflow: 5_git_workflow_standards/GIT-WORKFLOW-STANDARDS.md
- Issue / MR templates: 5_git_workflow_standards/ISSUE-MR-TEMPLATES.md
- OElite Restme: uranus/restme/OElite.Restme/
- Origin-Auth: uranus/origin-auth/
- Kortex: helios/kortex/

---

This skill is owned by Marcus. Updates require an MR and a review from at least one other role. If you find a gap, an anti-pattern not documented here, or an example that has drifted from current OElite practice, open a GitLab issue referencing this file and tag Marcus.
