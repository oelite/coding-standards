# OElite Prohibited Implementation Patterns

> **Repository**: coding-standards  
> **Last Updated**: 2026-07-09  
> **Maintained by**: Grace (Lead Backend Code Reviewer), Felix (Lead Frontend Code Reviewer)  
> **Status**: Active  
> **Version**: 1.0.0

---

## Overview

This document defines **prohibited implementation patterns** that are **STRICTLY FORBIDDEN** in all OElite codebases. These patterns represent **code quality failures** that must be **rejected during code review** and **never approved** in merge requests.

**ZERO TOLERANCE POLICY**: Code reviewers (Grace, Felix, Marcus, Maya) MUST reject any MR containing these patterns. Approval of prohibited implementations is a **code review failure** and violates OElite engineering standards.

---

## Table of Contents

1. [Stub Implementations](#1-stub-implementations)
2. [Simplified Implementations](#2-simplified-implementations)
3. [Temporary Quick-Fixes](#3-temporary-quick-fixes)
4. [Mock/Fake/Placeholder Data](#4-mockfakeplaceholder-data)
5. [Insufficient E2E Test Coverage](#5-insufficient-e2e-test-coverage)
6. [Reviewer Enforcement Protocol](#6-reviewer-enforcement-protocol)
7. [Examples by Technology](#7-examples-by-technology)

---

## 1. Stub Implementations

### Definition
A **stub implementation** is code that is intentionally incomplete, serving as a placeholder for future work. Stub implementations give the **illusion of functionality** without delivering actual business value.

### Prohibited Patterns

#### Backend (.NET) Examples

**FORBIDDEN - NotImplementedException:**
```csharp
// STUB: Method body throws exception
public async Task<Product> GetByIdAsync(string id)
{
    throw new NotImplementedException("TODO: Implement this method");
}

// STUB: Empty method body
public async Task CreateProductAsync(CreateProductRequest request)
{
    // TODO: Implement later
}

// STUB: Return null or default
public async Task<Order> GetOrderAsync(string orderId)
{
    return null; // "Will implement later"
}

// STUB: Return hardcoded dummy value
public async Task<User> GetCurrent_userAsync()
{
    return new User { Id = "1", Name = "Test User" }; // Placeholder
}
```

**FORBIDDEN - TODO/FIXME/HACK Comments:**
```csharp
// STUB: Unimplemented logic
public async Task ProcessPaymentAsync(PaymentRequest request)
{
    // TODO: Add payment gateway integration
    // FIXME: Handle edge cases later
    // HACK: Temporary solution for now
    return new PaymentResult { Success = true };
}
```

**STUB - Empty Catch Blocks:**
```csharp
// STUB: Silently swallowing errors
try
{
    await _repository.SaveAsync(entity);
}
catch (Exception ex)
{
    // TODO: Handle this later
    // Ignoring for now
}
```

#### Frontend (Next.js/Angular) Examples

**FORBIDDEN - Empty/Stub Components:**
```typescript
// STUB: Component with no logic
export const ProductList = () => {
  return <div>TODO: Implement product list</div>;
};

// STUB: Function that does nothing
const handleSubmit = async (data: FormData) => {
  // TODO: Implement form submission
  console.log('Not implemented yet');
};

// STUB: Return hardcoded mock data
const useProducts = () => {
  const [products, setProducts] = useState([
    { id: '1', name: 'Sample Product', price: 99.99 } // Mock data
  ]);
  return { products };
};
```

**FORBIDDEN - TODO Comments in Code:**
```typescript
// STUB: Unimplemented feature
const UserDashboard = () => {
  // TODO: Fetch user data from API
  // TODO: Add charts and metrics
  // TODO: Implement navigation
  return <div>Dashboard - Coming Soon</div>;
};
```

### Detection Checklist for Reviewers

- [ ] Any `throw new NotImplementedException()` in code
- [ ] Any method with empty body or only comments
- [ ] Any `// TODO:`, `// FIXME:`, `// HACK:`, `// XXX:` comments
- [ ] Any method returning `null`, `default`, or hardcoded values
- [ ] Any function that logs "not implemented" or similar
- [ ] Any component displaying "Coming Soon", "Under Construction", etc.
- [ ] Any catch block with empty body or only comments

**If ANY detected REJECT MR immediately with specific citations.**

---

## 2. Simplified Implementations

### Definition
A **simplified implementation** delivers only the "happy path" while omitting critical business logic, error handling, validation, edge cases, or security checks required by acceptance criteria.

### Prohibited Patterns

#### Backend (.NET) Examples

**FORBIDDEN - Happy Path Only:**
```csharp
// SIMPLIFIED: No validation, no error handling
public async Task<Product> CreateProductAsync(CreateProductRequest request)
{
    var product = new Product
    {
        Name = request.Name,
        Price = request.Price
    };
    
    await _repository.SaveAsync(product);
    return product; // What about validation? What if save fails?
}

// CORRECT: Full implementation
public async Task<Product> CreateProductAsync(CreateProductRequest request)
{
    // Validation
    if (string.IsNullOrWhiteSpace(request.Name))
        throw new ValidationException("Product name is required");
    
    if (request.Price < 0)
        throw new ValidationException("Price cannot be negative");
    
    // Business logic
    var product = new Product
    {
        Id = ObjectId.GenerateNewId().ToString(),
        Name = request.Name.Trim(),
        Price = Math.Round(request.Price, 2),
        CreatedAt = DateTime.UtcNow,
        Status = EntityStatus.Active
    };
    
    // Error handling
    try
    {
        await _repository.SaveAsync(product);
        await _eventPublisher.PublishAsync(new ProductCreatedEvent(product.Id));
        return product;
    }
    catch (DbException ex)
    {
        _logger.LogError(ex, "Failed to create product: {ProductId}", product.Id);
        throw new DatabaseException("Failed to save product", ex);
    }
}
```

**FORBIDDEN - Missing Edge Cases:**
```csharp
// SIMPLIFIED: No null checks, no boundary validation
public async Task<decimal> CalculateDiscountAsync(string userId, decimal amount)
{
    var user = await _userRepository.GetByIdAsync(userId);
    var discountRate = user.MembershipLevel switch
    {
        "Gold" => 0.15m,
        "Silver" => 0.10m,
        _ => 0.05m
    };
    
    return amount * discountRate; // What if user is null? What if amount is negative?
}

// CORRECT: Full implementation
public async Task<decimal> CalculateDiscountAsync(string userId, decimal amount)
{
    // Input validation
    if (string.IsNullOrWhiteSpace(userId))
        throw new ValidationException("User ID is required");
    
    if (amount <= 0)
        throw new ValidationException("Amount must be positive");
    
    // Fetch user with error handling
    var user = await _userRepository.GetByIdAsync(userId);
    if (user == null)
        throw new NotFoundException($"User {userId} not found");
    
    if (user.Status != EntityStatus.Active)
        throw new InvalidOperationException($"User {userId} is not active");
    
    // Business logic with boundary checks
    var discountRate = user.MembershipLevel switch
    {
        "Gold" => 0.15m,
        "Silver" => 0.10m,
        "Bronze" => 0.05m,
        _ => throw new InvalidOperationException($"Unknown membership level: {user.MembershipLevel}")
    };
    
    // Apply business rules
    var discount = amount * discountRate;
    var maxDiscount = GetMaxDiscountForLevel(user.MembershipLevel);
    
    return Math.Min(discount, maxDiscount); // Cap discount at maximum
}
```

#### Frontend Examples

**FORBIDDEN - No Error States:**
```typescript
// SIMPLIFIED: Only happy path, no error/empty/loading states
const ProductList = () => {
  const [products, setProducts] = useState([]);
  
  useEffect(() => {
    fetch('/api/products')
      .then(res => res.json())
      .then(data => setProducts(data));
  }, []);
  
  return (
    <ul>
      {products.map(p => <li key={p.id}>{p.name}</li>)}
    </ul>
  );
  // What about loading state? What if API fails? What if empty?
};

// CORRECT: Full implementation
const ProductList = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  useEffect(() => {
    const loadProducts = async () => {
      try {
        setLoading(true);
        const response = await fetch('/api/products');
        if (!response.ok) {
          throw new Error(`Failed to fetch products: ${response.statusText}`);
        }
        const data = await response.json();
        setProducts(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    };
    
    loadProducts();
  }, []);
  
  if (loading) {
    return <SkeletonLoader count={5} />;
  }
  
  if (error) {
    return (
      <ErrorState 
        message={error} 
        onRetry={() => window.location.reload()} 
      />
    );
  }
  
  if (products.length === 0) {
    return <EmptyState message="No products available" />;
  }
  
  return (
    <ul>
      {products.map(p => <ProductItem key={p.id} product={p} />)}
    </ul>
  );
};
```

### Detection Checklist for Reviewers

- [ ] Does the code handle ALL acceptance criteria or just the happy path?
- [ ] Are there input validation checks for all user inputs?
- [ ] Are there error handling blocks for all async operations?
- [ ] Are there null/undefined checks for all external data?
- [ ] Are there boundary value validations (min/max, empty, negative)?
- [ ] Are there loading/empty/error states for all async UI operations?
- [ ] Are there security checks (authentication, authorization, input sanitization)?
- [ ] Are there logging statements for error conditions?
- [ ] Are there rollback/cleanup actions for failed operations?

**If ANY missing REJECT MR with specific AC gaps identified.**

---

## 3. Temporary Quick-Fixes

### Definition
A **temporary quick-fix** is code that intentionally introduces technical debt with the expectation of being replaced later. These are "band-aid" solutions that compromise long-term code quality.

### Prohibited Patterns

**FORBIDDEN - Temporary Workarounds:**
```csharp
// QUICK-FIX: Hardcoded workaround
public async Task ProcessOrderAsync(Order order)
{
    // HACK: Temporary fix for payment gateway issue
    // Will be removed once gateway is fixed
    if (order.Total > 10000)
    {
        order.Total = order.Total * 0.99m; // Manual discount
    }
    
    // TODO: Remove this once we fix the currency conversion bug
    if (order.Currency == "EUR")
    {
        order.Total = order.Total * 1.08m; // Rough conversion
    }
    
    await _orderRepository.SaveAsync(order);
}

// QUICK-FIX: Magic numbers with "temporary" comments
public async Task CalculateShippingAsync(Order order)
{
    // FIXME: This is temporary until we get the real shipping API
    if (order.Weight < 10) return 5.99m;
    if (order.Weight < 50) return 12.99m;
    if (order.Weight < 100) return 24.99m;
    return 49.99m; // Should call shipping service
}
```

**FORBIDDEN - Commented-Out Code:**
```csharp
// QUICK-FIX: Commented out legacy code
public async Task ProcessPaymentAsync(PaymentRequest request)
{
    // Old implementation - keeping for reference
    // var oldProcessor = new LegacyPaymentProcessor();
    // await oldProcessor.ProcessAsync(request);
    
    var newProcessor = new PaymentGateway();
    await newProcessor.ProcessAsync(request);
}
```

**QUICK-FIX - Disabled Validation:**
```csharp
// QUICK-FIX: Commented out security check
public async Task<User> CreateUserAsync(CreateUserRequest request)
{
    // TEMPORARILY DISABLED: Password complexity check
    // if (!IsValidPassword(request.Password))
    //     throw new ValidationException("Password does not meet requirements");
    
    var user = new User
    {
        Email = request.Email,
        PasswordHash = _hasher.Hash(request.Password) // Weak hashing for now
    };
    
    return await _userRepository.CreateAsync(user);
}
```

### Detection Checklist for Reviewers

- [ ] Any comments containing "temporary", "hack", "workaround", "band-aid"?
- [ ] Any commented-out code blocks (even with explanations)?
- [ ] Any disabled security/validation checks?
- [ ] Any hardcoded values with "will be replaced" comments?
- [ ] Any "magic numbers" or strings without proper abstraction?
- [ ] Any bypassed error handling with "for now" comments?

**If ANY detected REJECT MR. Temporary code is NOT acceptable in production.**

---

## 4. Mock/Fake/Placeholder Data

### Definition
**Mock/fake/placeholder data** is any hardcoded, sample, or test data used in production code instead of real data from APIs, databases, or user input.

### Prohibited Patterns

**FORBIDDEN - Hardcoded Data:**
```csharp
// FAKE DATA: Hardcoded in production code
public async Task<Dashboard> GetDashboardAsync(string userId)
{
    return new Dashboard
    {
        TotalOrders = 1234, // Should come from database
        Revenue = 45678.90m, // Should be calculated
        TopProducts = new[] { "Widget", "Gadget", "Gizmo" }, // Mock data
        RecentOrders = new[] // Hardcoded sample orders
        {
            new Order { Id = "1", Total = 99.99m, Status = "Completed" },
            new Order { Id = "2", Total = 149.99m, Status = "Pending" },
            new Order { Id = "3", Total = 299.99m, Status = "Shipped" }
        }
    };
}
```

**FORBIDDEN - Sample/Test Data:**
```typescript
// FAKE DATA: Sample data in production
const useAnalytics = () => {
  const [data, setData] = useState({
    revenue: [1000, 1200, 1500, 1800, 2100], // Mock data
    orders: [45, 52, 48, 61, 58], // Sample data
    customers: [120, 135, 142, 158, 167] // Fake data
  });
  
  // Should fetch from real API
  return { data };
};
```

**FORBIDDEN - Placeholder Values:**
```typescript
// PLACEHOLDER: Placeholder text in production UI
const ProductCard = ({ product }) => (
  <div>
    <img src={product.imageUrl || '/assets/placeholder.png'} alt="Product" />
    <h3>{product.name || 'Product Name'}</h3>
    <p>{product.description || 'Product description will appear here'}</p>
    <span>${product.price?.toFixed(2) || '0.00'}</span>
  </div>
);
```

### Detection Checklist for Reviewers

- [ ] Any hardcoded strings that look like sample data ("Test User", "Sample Product")?
- [ ] Any magic numbers used as data values?
- [ ] Any placeholder text ("Coming Soon", "Loading...", "N/A") in production?
- [ ] Any default/fallback values that should come from API?
- [ ] Any mock objects or fake data generators in production code?
- [ ] Any test fixtures or sample data files included in production?

**If ANY detected REJECT MR. Production code must use REAL data only.**

---

## 5. Insufficient E2E Test Coverage

### Definition
**Insufficient E2E test coverage** occurs when user-facing UI features lack comprehensive Playwright tests that validate API integration, UI layout/design compliance, interactive elements, and full-stack data flow. "Unit tests pass" is NOT sufficient for user-facing features.

### Prohibited Patterns

**❌ FORBIDDEN - Missing API Integration Tests:**
```typescript
// ❌ INSUFFICIENT: E2E test only checks page loads, no API verification
test('product list page loads', async ({ page }) => {
  await page.goto('/en/dashboards/products');
  await expect(page).toHaveTitle(); // Does NOT verify API was called
});

// ✅ CORRECT: Full API integration validation
test('[US-015/AC-002] product list fetches and displays real API data', async ({ page }) => {
  let apiCalled = false;
  let apiResponse: any;
  
  // Intercept and verify API call
  await page.route('**/api/products', async (route) => {
    apiCalled = true;
    apiResponse = await route.continue();
  });
  
  await page.goto('/en/dashboards/products');
  await page.waitForLoadState('networkidle');
  
  // Verify API was called
  expect(apiCalled).toBe(true);
  
  // Verify response status
  expect(apiResponse.status()).toBe(200);
  
  // Verify data renders in UI
  const productRows = page.locator('table tbody tr');
  await expect(productRows).toHaveCount({ greaterThan: 0 });
  
  // Verify first product name matches API response
  const firstProduct = await productRows.first().textContent();
  const products = await apiResponse.json();
  expect(firstProduct).toContain(products.data[0].name);
});
```

**❌ FORBIDDEN - Missing UI Layout/Design Tests:**
```typescript
// ❌ INSUFFICIENT: No responsive or design token verification
test('dashboard displays correctly', async ({ page }) => {
  await page.goto('/en/dashboards');
  await expect(page.locator('h1')).toContainText('Dashboard');
});

// ✅ CORRECT: Full layout and design compliance
test('[US-020/AC-005] dashboard responsive layout and design tokens', async ({ page }) => {
  await page.goto('/en/dashboards');
  
  // Test mobile breakpoint (375px)
  await page.setViewportSize({ width: 375, height: 667 });
  const mobileMenu = page.locator('[role="navigation"]');
  await expect(mobileMenu).toBeVisible();
  
  // Test tablet breakpoint (768px)
  await page.setViewportSize({ width: 768, height: 1024 });
  const tabletGrid = page.locator('.grid-cols-2');
  await expect(tabletGrid).toBeVisible();
  
  // Test desktop breakpoint (1024px)
  await page.setViewportSize({ width: 1024, height: 768 });
  const desktopGrid = page.locator('.grid-cols-4');
  await expect(desktopGrid).toBeVisible();
  
  // Verify design token compliance (no arbitrary values)
  const primaryButton = page.locator('button:has-text("Primary")');
  const bgColor = await primaryButton.evaluate(el => 
    window.getComputedStyle(el).backgroundColor
  );
  // Should use CSS variable, not hardcoded hex
  expect(bgColor).not.toContain('rgb(255, 0, 0)'); // No hardcoded colors
});
```

**❌ FORBIDDEN - Missing Interactive Element Tests:**
```typescript
// ❌ INSUFFICIENT: Only tests happy path
test('create user form works', async ({ page }) => {
  await page.goto('/en/admin/users');
  await page.click('button:has-text("New User")');
  await page.fill('input[name="email"]', 'test@example.com');
  await page.click('button:has-text("Save")');
});

// ✅ CORRECT: Full interactive validation
test('[US-001/AC-003] create user form validation and error handling', async ({ page }) => {
  await page.goto('/en/admin/users');
  
  // Test 1: Form validation - required fields
  await page.click('button:has-text("New User")');
  const dialog = page.locator('[role="dialog"]');
  await expect(dialog).toBeVisible();
  
  // Submit empty form - should show validation errors
  await page.click('button:has-text("Save")');
  await expect(page.locator('.text-red-500')).toContainText('Email is required');
  
  // Test 2: Invalid email format
  await page.fill('input[name="email"]', 'invalid-email');
  await page.click('button:has-text("Save")');
  await expect(page.locator('.text-red-500')).toContainText('Invalid email format');
  
  // Test 3: Valid submission
  await page.fill('input[name="email"]', 'valid@example.com');
  const savePromise = page.waitForResponse('**/api/users');
  await page.click('button:has-text("Save")');
  await savePromise;
  
  // Test 4: Keyboard navigation
  await page.goto('/en/admin/users');
  await page.keyboard.press('Tab'); // Focus should move to search input
  await page.keyboard.press('Enter'); // Should trigger search
});
```

**❌ FORBIDDEN - Missing Full-Stack Integration Tests:**
```typescript
// ❌ INSUFFICIENT: No data persistence verification
test('delete product works', async ({ page }) => {
  await page.goto('/en/dashboards/products');
  await page.click('button:has-text("Delete")');
  await page.click('button:has-text("Confirm")');
});

// ✅ CORRECT: Full-stack data flow validation
test('[US-015/AC-008] delete product persists to database', async ({ page }) => {
  // 1. Get initial product count from API
  const initialResponse = await page.request.get('/api/products');
  const initialProducts = await initialResponse.json();
  const initialCount = initialProducts.data.length;
  
  await page.goto('/en/dashboards/products');
  
  // 2. Delete first product
  const firstProductRow = page.locator('table tbody tr').first();
  const productName = await firstProductRow.locator('td').first().textContent();
  await firstProductRow.locator('button:has-text("Delete")').click();
  await page.locator('button:has-text("Confirm")').click();
  
  // 3. Verify UI updated
  await expect(firstProductRow).not.toBeVisible();
  const remainingRows = page.locator('table tbody tr');
  await expect(remainingRows).toHaveCount(initialCount - 1);
  
  // 4. Verify database persistence (API reflection)
  await page.reload();
  const refreshedResponse = await page.request.get('/api/products');
  const refreshedProducts = await refreshedResponse.json();
  expect(refreshedProducts.data.length).toBe(initialCount - 1);
  
  // 5. Verify deleted product no longer in database
  const deletedProduct = refreshedProducts.data.find(
    (p: any) => p.name === productName
  );
  expect(deletedProduct).toBeUndefined();
});
```

### Detection Checklist for Reviewers

- [ ] Do E2E tests verify API request payloads match expected schema?
- [ ] Do E2E tests verify API response data correctly renders in UI?
- [ ] Do E2E tests verify API error responses display user-friendly messages?
- [ ] Do E2E tests verify loading states during API calls?
- [ ] Do E2E tests verify responsive layout at mobile/tablet/desktop breakpoints?
- [ ] Do E2E tests verify design token compliance (no arbitrary Tailwind values)?
- [ ] Do E2E tests verify Shadcn/ui component usage?
- [ ] Do E2E tests verify accessibility attributes (ARIA labels, roles)?
- [ ] Do E2E tests verify all buttons/links trigger expected actions?
- [ ] Do E2E tests verify form validation (client-side + server-side)?
- [ ] Do E2E tests verify keyboard navigation (Tab, Enter, Escape)?
- [ ] Do E2E tests verify focus management (modal traps, form focus order)?
- [ ] Do E2E tests verify data persistence across page refreshes?
- [ ] Do E2E tests verify authentication/authorization enforcement?
- [ ] Do E2E tests capture network logs showing real API calls?
- [ ] Do E2E tests have screenshots/videos for critical user journeys?
- [ ] Does each E2E test map to a user story acceptance criterion (US-XXX/AC-YYY)?

**If ANY missing → REJECT MR. "Unit tests pass" is NOT sufficient for UI features.**

---

## 6. Reviewer Enforcement Protocol

### Mandatory Review Steps

**Before approving ANY MR, reviewers MUST:**

1. **Scan for Prohibited Patterns**
   - Use IDE search for: `NotImplementedException`, `TODO`, `FIXME`, `HACK`, `XXX`, `TEMP`, `WORKAROUND`
   - Search for: hardcoded strings, sample data, placeholder text
   - Check for: empty method bodies, commented-out code, disabled validations

2. **Verify Full Implementation**
   - Cross-reference each acceptance criterion with actual code
   - Confirm error handling exists for ALL async operations
   - Validate input validation for ALL user inputs
   - Check edge cases: null, empty, boundary values, negative numbers

3. **Test Execution**
   - Run ALL unit tests - they must pass
   - Run ALL integration tests against real infrastructure
   - Run ALL E2E tests for user-facing features
   - Verify no tests are skipped or marked as "todo"

4. **Code Quality Check**
   - No technical debt introduced
   - No "we'll fix this later" code
   - No security bypasses or disabled validations
   - No commented-out code blocks

### Rejection Template

When rejecting an MR with prohibited patterns, use this format:

```markdown
## REJECTED: Prohibited Implementation Patterns Detected

### Violations Found

**Location**: `file.cs:line` or `component.tsx:line`

**Pattern Type**: [Stub | Simplified | Temporary | Mock Data]

**Code**:
```csharp
// Paste the problematic code snippet
```

**Issue**: [Specific explanation of why this violates standards]

**Required Fix**: [Clear instructions on what must be implemented]

**Reference**: [Link to relevant section in PROHIBITED-PATTERNS.md]

### Action Required

1. Remove all stub/simplified/temporary implementations
2. Implement full business logic per acceptance criteria
3. Add proper error handling and validation
4. Remove all mock/fake/placeholder data
5. Re-run all tests and verify they pass
6. Resubmit for review

**Note**: Repeated violations will be escalated to Marcus (Principal Architect) and Emma (Product Coordinator).
```

### Escalation Path

- **First violation**: Reviewer rejects with detailed feedback
- **Second violation**: Reviewer escalates to Marcus (architecture review required)
- **Third violation**: Emma (Product Coordinator) notified for team-wide coaching

---

## 6. Examples by Technology

### Backend (.NET 10)

| Pattern | FORBIDDEN | CORRECT |
|---------|-----------|---------|
| **Method Implementation** | `throw new NotImplementedException()` | Full business logic with error handling |
| **Data Access** | `return new List<Product>(); // TODO` | Real database query with proper error handling |
| **Validation** | `// TODO: Add validation later` | Comprehensive input validation with exceptions |
| **Error Handling** | Empty catch blocks or `catch { }` | Proper logging and exception propagation |
| **Return Values** | `return null; // Will implement` | Real data from database or appropriate error |
| **Configuration** | Hardcoded values | `IOptions<T>` or `OElitePathResolver` |

### Frontend (Next.js/React)

| Pattern | FORBIDDEN | CORRECT |
|---------|-----------|---------|
| **Component State** | Only success state | Loading, empty, error, and success states |
| **Data Fetching** | Hardcoded mock data | Real API calls with error handling |
| **Form Handling** | No validation | Client + server validation with error messages |
| **User Feedback** | No loading indicators | Skeleton loaders, spinners, progress indicators |
| **Error Display** | `console.error()` | User-friendly error messages with retry options |

### Frontend (Angular)

| Pattern | FORBIDDEN | CORRECT |
|---------|-----------|---------|
| **Service Methods** | Return Observable.of(mockData) | Real HTTP calls with error handling |
| **Component Templates** | Static placeholder text | Dynamic data with loading/error states |
| **Form Validation** | No validation | Reactive forms with custom validators |
| **Error Handling** | Empty error blocks | Proper error messages and recovery |

---

## Related Documentation

- [AGENTS.md](../../AGENTS.md) — Team roles and workflow chains
- [TASK-TEMPLATES.md](./TASK-TEMPLATES.md) — Task creation and Definition of Done
- [ISSUE-MR-TEMPLATES.md](./ISSUE-MR-TEMPLATES.md) — GitLab issue and MR templates
- [1_dotNet_coding_standards/](../1_dotNet_coding_standards/) — .NET backend standards
- [4_react_nextjs_coding_standards/](../4_react_nextjs_coding_standards/) — React/Next.js standards
- [3_angular_coding_standards/](../3_angular_coding_standards/) — Angular standards

---

## Change History

| Date | Author | Version | Changes |
|------|--------|---------|---------|
| 2026-07-09 | Sisyphus (per user request) | 1.0.0 | Initial version - defines prohibited patterns to prevent stub/fake/simplified implementations from being approved in MRs |
