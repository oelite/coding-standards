# Functional Requirements-Driven Development Standards

## Overview

This document establishes the **mandatory functional requirements-driven development process** for all OElite projects. **NO CODE** should be written until this process is completed and approved.

## The Functional Requirements Flow

### **MANDATORY: 6-Step Development Process**

```
Functional Requirements Document
           ↓
    3.1 UI Operations Analysis
           ↓
    3.2 API Endpoints Design
           ↓
    3.3 Data Entity Design
           ↓
    3.4 Functional Methods Implementation
           ↓
    3.5 Data Repository Creation
           ↓
    3.6 CRUD Standards Implementation
```

## Step 3.1: UI Operations Analysis

### **MANDATORY: Start with User Needs**

**BEFORE WRITING ANY CODE**, identify what UI level operations users actually need:

#### **Requirements Analysis**
- [ ] Review functional requirements document thoroughly
- [ ] Identify **specific user interactions** (clicks, forms, navigation)
- [ ] Map user journeys and workflows
- [ ] Define success criteria for each operation
- [ ] Document edge cases and error scenarios

#### **UI Operations Examples**
```yaml
# ✅ GOOD: User-centric operations
- User logs in with email/password
- User views product catalog with search/filter
- User adds items to shopping cart
- User completes checkout process
- Admin creates new product listing
- Admin views sales analytics dashboard

# ❌ BAD: Technical operations
- System validates JWT token
- Database executes SELECT query
- Cache stores product data
- Queue processes order
```

#### **Deliverable**: UI Operations Specification
```markdown
## UI Operation: User Places Order

**User Journey:**
1. User browses products
2. User adds items to cart
3. User proceeds to checkout
4. User enters shipping/payment info
5. User confirms order

**Success Criteria:**
- Order is created in database
- Payment is processed
- Confirmation email is sent
- Inventory is updated
- Order status tracking is available
```

## Step 3.2: API Endpoints Design

### **MANDATORY: Design APIs Based on UI Operations**

Based on identified UI operations, design RESTful API endpoints:

#### **API Contract Design**
- [ ] Each UI operation maps to 1+ API endpoints
- [ ] Use RESTful conventions (GET, POST, PUT, DELETE)
- [ ] Define request/response models
- [ ] Include proper HTTP status codes
- [ ] Document authentication/authorization requirements

#### **API Design Examples**
```yaml
# UI Operation: User views product catalog
GET /api/products?page=1&pageSize=20&category=electronics&search=laptop

# UI Operation: User adds item to cart
POST /api/cart/items
{
  "productId": "123",
  "quantity": 2,
  "variantId": "blue-large"
}

# UI Operation: User completes checkout
POST /api/orders
{
  "cartId": "cart-456",
  "shippingAddress": {...},
  "paymentMethod": {...}
}
```

#### **Deliverable**: API Specification Document
```markdown
## API Endpoint: POST /api/orders

**Purpose:** Create new order from cart
**UI Operation:** User completes checkout

**Request:**
```json
{
  "cartId": "string",
  "shippingAddress": "Address",
  "paymentMethod": "PaymentMethod"
}
```

**Response:**
```json
{
  "orderId": "string",
  "status": "confirmed",
  "total": 99.99
}
```

**Status Codes:**
- 201: Order created successfully
- 400: Invalid request data
- 409: Insufficient inventory
```

## Step 3.3: Data Entity Design

### **MANDATORY: Design Persistence Models**

Based on API contracts, design data entities for persistence:

#### **Entity Design Requirements**
- [ ] All entities inherit from `BaseEntity`
- [ ] Use proper database attributes
- [ ] Consider normalization vs denormalization
- [ ] Design for query performance
- [ ] Include audit fields (CreatedOnUtc, UpdatedOnUtc, etc.)

#### **Database Attributes (MANDATORY)**
```csharp
// ✅ CORRECT: Proper entity design
[DbCollection("orders")]
public class Order : BaseEntity
{
    [DbField("orderNumber")]
    public string OrderNumber { get; set; }

    [DbField("customerId")]
    [DbIndex] // For customer order lookups
    public string CustomerId { get; set; }

    [DbField("status")]
    [DbIndex] // For status-based queries
    public OrderStatus Status { get; set; }

    [DbField("total")]
    public decimal Total { get; set; }

    // Denormalized for performance (frequent access)
    [DenormalizedField("customers", "name")]
    public string CustomerName { get; set; }

    [DenormalizedField("customers", "email")]
    public string CustomerEmail { get; set; }

    // Nested data for order details
    [DbField("items")]
    public List<OrderItem> Items { get; set; }

    [DbField("shippingAddress")]
    public Address ShippingAddress { get; set; }
}
```

#### **Normalization vs Denormalization Decision Matrix**
- [ ] **Normalize** for: Data integrity, write-heavy workloads, complex relationships
- [ ] **Denormalize** for: Read-heavy workloads, frequent joins, performance-critical queries

#### **Indexing Strategy**
```csharp
// ✅ GOOD: Strategic indexing
[DbIndex] // Customer order history
public string CustomerId { get; set; }

[DbIndex] // Order status filtering
public OrderStatus Status { get; set; }

[DbShardKey] // Horizontal scaling
public string TenantId { get; set; }
```

#### **Deliverable**: Entity Design Document
```markdown
## Entity: Order

**Purpose:** Persist order data for checkout operations

**Database Design:**
- Collection: `orders`
- Indexes: `customerId`, `status`, `createdOnUtc`
- Shard Key: `tenantId`

**Fields:**
- `orderNumber`: Unique order identifier
- `customerId`: Reference to customer (indexed)
- `status`: Order status (indexed)
- `total`: Order total amount
- `customerName`: Denormalized for display (no joins needed)
- `items[]`: Order line items
- `shippingAddress`: Shipping details
```

## Step 3.4: Functional Methods Implementation

### **MANDATORY: Implement Logic Supporting API Contracts**

Based on API endpoints, implement functional methods:

#### **Method Implementation Requirements**
- [ ] Each API endpoint maps to exactly one service method
- [ ] Methods contain business logic and validation
- [ ] Methods orchestrate repository calls
- [ ] Methods handle errors and edge cases
- [ ] Methods return data matching API contracts

#### **Service Method Examples**
```csharp
// ✅ CORRECT: Service method supporting API contract
public class OrderService : IOEliteService
{
    public async Task<OrderResult> CreateOrderAsync(CreateOrderRequest request)
    {
        // Validate request
        await ValidateOrderRequestAsync(request);

        // Check inventory
        await ValidateInventoryAsync(request.Items);

        // Process payment
        var paymentResult = await _paymentService.ProcessPaymentAsync(request.Payment);

        // Create order
        var order = await _orderRepository.CreateAsync(new Order {
            CustomerId = request.CustomerId,
            Items = request.Items,
            Total = request.Total,
            PaymentId = paymentResult.PaymentId
        });

        // Update inventory
        await _inventoryService.ReserveItemsAsync(request.Items);

        // Send confirmation
        await _emailService.SendOrderConfirmationAsync(order);

        return new OrderResult {
            OrderId = order.Id,
            Status = OrderStatus.Confirmed
        };
    }
}
```

#### **Deliverable**: Service Method Specifications
```markdown
## Service Method: CreateOrderAsync

**API Contract:** POST /api/orders
**Purpose:** Create order with payment processing and inventory management

**Logic Flow:**
1. Validate order request data
2. Check product availability
3. Process payment
4. Create order record
5. Reserve inventory
6. Send confirmation email
7. Return order confirmation
```

## Step 3.5: Data Repository Creation

### **MANDATORY: Create Data-Focused Repositories**

Based on data persistence needs, create repositories:

#### **Repository Requirements**
- [ ] **NO BUSINESS LOGIC** - Only data access operations
- [ ] Implement CRUD operations using standardized naming
- [ ] Use proper collection types (EntityCollection, not List<T>)
- [ ] Accept query objects for filtering
- [ ] Handle database-specific optimizations

#### **Repository Examples**
```csharp
// ✅ CORRECT: Data-focused repository
public class OrderRepository : OrionDbRepository, IOrderRepository
{
    // CRUD Operations Only
    public async Task<Order?> GetOrderAsync(OrderQuery query)
    {
        var mongoQuery = DbCentre.Orders;
        // Apply query filters...
        return await mongoQuery.FetchAsync();
    }

    public async Task<OrderCollection> GetOrdersAsync(OrderQuery query)
    {
        var mongoQuery = DbCentre.Orders;
        // Apply query filters...
        return await mongoQuery.FetchAsync<Order, OrderCollection>();
    }

    public async Task<Order> UpdateOrderAsync(Order order)
    {
        order.UpdatedOnUtc = DateTime.UtcNow;
        await DbCentre.Orders.ReplaceAsync(order);
        return order;
    }

    public async Task<bool> DeleteOrderAsync(OrderQuery query)
    {
        var mongoQuery = DbCentre.Orders;
        // Apply query filters...
        var result = await mongoQuery.DeleteAsync();
        return result.DeletedCount > 0;
    }
}
```

#### **Repository Boundaries**
```csharp
// ✅ ALLOWED in repositories
- Data filtering and querying
- Pagination and sorting
- Simple aggregations (counts, sums)
- Database constraint validation
- Index utilization

// ❌ FORBIDDEN in repositories
- Business rule validation
- Email sending
- Payment processing
- Complex calculations
- External API calls
- Cross-entity business logic
```

## Step 3.6: CRUD Standards Implementation

### **MANDATORY: Standardized CRUD Operations**

All repositories must implement the 4 core CRUD operations:

#### **CRUD Naming Convention (MANDATORY)**
```csharp
public interface IEntityRepository : IDataRepository<OrionDbCentre>
{
    // Get single entity
    Task<Entity?> GetEntityAsync(EntityQuery query);

    // Get multiple entities
    Task<EntityCollection> GetEntitiesAsync(EntityQuery query);

    // Update entity
    Task<Entity> UpdateEntityAsync(Entity entity);

    // Delete entities
    Task<bool> DeleteEntityAsync(EntityQuery query);
}
```

#### **Query Object Standards**
```csharp
// ✅ CORRECT: Query object pattern
public class OrderQuery : BaseQuery
{
    public string? OrderId { get; set; }
    public string? CustomerId { get; set; }
    public OrderStatus? Status { get; set; }
    public DateTime? CreatedAfterUtc { get; set; }
    public DateTime? CreatedBeforeUtc { get; set; }
    public string? SearchTerm { get; set; }
}
```

#### **Collection Type Standards**
```csharp
// ✅ CORRECT: Entity collection types
public async Task<OrderCollection> GetOrdersAsync(OrderQuery query)
{
    return await mongoQuery.FetchAsync<Order, OrderCollection>();
}

// ❌ WRONG: Generic collections
public async Task<List<Order>> GetOrdersAsync(OrderQuery query)
{
    return await mongoQuery.ToListAsync();
}
```

### **Service Layer Query Pattern Standard (SL-QP-001)**

**Universal Query Objects for Service Methods**

1. **Query Object Design**:
   - Query objects shall inherit from `BaseQuery` (from `OElite.Common`) to ensure consistent base query parameters
   - Query objects shall encapsulate all filtering, pagination, and contextual parameters for operations
   - Query objects shall be designed to flow through the application stack where beneficial
   - Query objects shall be serializable when exposed to API consumers

2. **Service Method Simplification**:
   ```csharp
   // BAD PRACTICE: Multiple scattered parameters with inappropriate return type
   Task<DataCollection<OrionUser>> GetUsersForTenantAsync(ITenantContext, int, int, string?, bool?)

   // GOOD PRACTICE: Single comprehensive query object inheriting from BaseQuery
   Task<OrionUserCollection> GetUsersAsync(UserQuery query) // UserQuery : BaseQuery
   ```

3. **Security and Tenant Isolation Requirements**:
   - **Batch Query Security**: When implementing batch query operations, developers must ensure security and tenant/ownership-aware record isolation is properly implemented
   - **Service Layer Validation**: Services shall include sufficient checks to enforce security policies and tenant isolation before executing queries
   - **Context Awareness**: Query objects should support the application's security model, with services responsible for validating and enforcing access controls

4. **Entity Collection Usage**:
   - When returning batch results of entities (classes inheriting from `BaseEntity`), services shall use the entity's bespoke collection type (e.g., `OrionUserCollection` for `OrionUser` entities)
   - This ensures type safety and leverages built-in collection functionality

5. **Query Flow Benefits**:
   - Reduces method signature complexity through `BaseQuery` inheritance
   - Enables consistent query patterns across services
   - Supports advanced filtering and pagination requirements through standardized base parameters
   - Maintains security boundaries through service layer validation

## Compliance Checklist

### Functional Requirements Flow
- [ ] **3.1 UI Operations**: Documented user-centric operations, not technical operations
- [ ] **3.2 API Endpoints**: Each UI operation maps to RESTful API contracts
- [ ] **3.3 Data Entities**: Entities inherit from BaseEntity with proper database attributes
- [ ] **3.4 Functional Methods**: Service methods implement business logic supporting API contracts
- [ ] **3.5 Data Repositories**: Repositories contain only data access logic
- [ ] **3.6 CRUD Standards**: All repositories implement the 4 core CRUD operations

### Code Quality Gates
- [ ] No business logic in repositories
- [ ] No data access in services (only through repositories)
- [ ] No business logic in controllers (only orchestration)
- [ ] Proper separation of concerns across all layers
- [ ] Query objects used for all repository filtering
- [ ] Entity collection types used instead of List<T>
- [ ] FetchAsync used for all collection operations

### Documentation Requirements
- [ ] UI operations specification document
- [ ] API contract specifications
- [ ] Entity design documentation
- [ ] Service method specifications
- [ ] Repository interface documentation

## Consequences of Non-Compliance

**MANDATORY ENFORCEMENT:**
- Code reviews will reject implementations not following this flow
- Technical debt will accumulate from improper layering
- Maintenance costs will increase significantly
- System scalability and performance will be compromised
- Always run `dotnet build` or equivalent build command after making changes
- Fix any compilation errors immediately
- Ensure all dependencies are properly restored
- Verify the build succeeds in the target environment
- Only mark tasks as complete when the code compiles without errors

**START WITH FUNCTIONAL REQUIREMENTS OR RISK PROJECT FAILURE**