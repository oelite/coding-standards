# Reviewer Training Plan: Prohibited Implementation Patterns

> **Repository**: coding-standards  
> **Last Updated**: 2026-07-09  
> **Trainer**: Grace (Lead Backend Code Reviewer)  
> **Audience**: All reviewers (Grace, Felix, Marcus, Maya) + implementers (Daniel, Sophia, Ethan, etc.)  
> **Duration**: 60 minutes  
> **Status**: Scheduled

---

## 📅 Training Session Overview

**Session Title**: Zero Tolerance: Detecting and Rejecting Prohibited Implementation Patterns

**Objective**: Equip all code reviewers with the skills, checklists, and confidence to detect and reject stub/simplified/temporary/mock implementations in merge requests.

**Target Audience**:
- **Primary**: Code reviewers (Grace, Felix, Marcus, Maya)
- **Secondary**: Implementers (Daniel, Sophia, Ethan, Jonathan, Olivia, etc.)

**Format**: Live interactive session with code examples, hands-on detection exercises, and Q&A

**Materials Needed**:
- `PROHIBITED-PATTERNS.md` (primary reference)
- IDE with search capabilities (VS Code, Rider, or similar)
- Sample MRs with violations (anonymized)
- Training slides (optional)

---

## 🎯 Learning Objectives

By the end of this training, participants will be able to:

1. **Identify** all 4 categories of prohibited implementation patterns
2. **Detect** prohibited patterns using IDE search and manual review techniques
3. **Apply** the rejection template consistently and professionally
4. **Escalate** repeated violations through the proper chain
5. **Implement** production-ready code that passes review on first submission

---

## 📋 Training Agenda (60 minutes)

### 1. Introduction (5 minutes)

**Presenter**: Grace

**Content**:
- Welcome and training objectives
- Why this matters: Recent violations and their impact
- The business case: Why stubs and simplified implementations fail
- Zero tolerance policy overview

**Key Message**: "Every line of code we approve represents a commitment to our stakeholders. Stub implementations break that commitment."

---

### 2. Pattern Deep Dive (20 minutes)

**Presenter**: Grace

**Content**: Walk through all 4 prohibited pattern categories with concrete examples

#### Category 1: Stub Implementations (5 min)

**What to Show**:
```csharp
// ❌ FORBIDDEN - NotImplementedException
public async Task<Product> GetByIdAsync(string id)
{
    throw new NotImplementedException("TODO: Implement this method");
}

// ❌ FORBIDDEN - Empty method body
public async Task CreateProductAsync(CreateProductRequest request)
{
    // TODO: Implement later
}

// ❌ FORBIDDEN - Return null or hardcoded dummy
public async Task<User> GetCurrent_userAsync()
{
    return new User { Id = "1", Name = "Test User" }; // Placeholder
}
```

**Detection Tips**:
- IDE search: `NotImplementedException`, `TODO`, `FIXME`, `XXX`
- Look for methods returning `null`, `default`, or hardcoded values
- Check for methods with only comments in the body

---

#### Category 2: Simplified Implementations (5 min)

**What to Show**:
```csharp
// ❌ SIMPLIFIED - Happy path only, no validation
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

// ✅ CORRECT - Full implementation
public async Task<Product> CreateProductAsync(CreateProductRequest request)
{
    // Validation
    if (string.IsNullOrWhiteSpace(request.Name))
        throw new ValidationException("Product name is required");
    
    if (request.Price < 0)
        throw new ValidationException("Price cannot be negative");
    
    // Business logic with proper error handling
    var product = new Product
    {
        Id = ObjectId.GenerateNewId().ToString(),
        Name = request.Name.Trim(),
        Price = Math.Round(request.Price, 2),
        CreatedAt = DateTime.UtcNow,
        Status = EntityStatus.Active
    };
    
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

**Detection Tips**:
- Cross-reference each acceptance criterion with actual code
- Check for validation on ALL user inputs
- Verify error handling for ALL async operations
- Look for edge case handling: null, empty, boundary values

---

#### Category 3: Temporary Quick-Fixes (5 min)

**What to Show**:
```csharp
// ❌ QUICK-FIX - Temporary workaround
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

// ❌ QUICK-FIX - Commented-out code
public async Task ProcessPaymentAsync(PaymentRequest request)
{
    // Old implementation - keeping for reference
    // var oldProcessor = new LegacyPaymentProcessor();
    // await oldProcessor.ProcessAsync(request);
    
    var newProcessor = new PaymentGateway();
    await newProcessor.ProcessAsync(request);
}
```

**Detection Tips**:
- IDE search: "temporary", "hack", "workaround", "band-aid", "for now"
- Look for commented-out code blocks
- Check for disabled security/validation checks
- Flag magic numbers with explanatory comments

---

#### Category 4: Mock/Fake/Placeholder Data (5 min)

**What to Show**:
```csharp
// ❌ FAKE DATA - Hardcoded in production code
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

**Frontend Example**:
```typescript
// ❌ FAKE DATA - Sample data in production
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

**Detection Tips**:
- Look for hardcoded strings that look like sample data ("Test User", "Sample Product")
- Flag magic numbers used as data values
- Check for placeholder text ("Coming Soon", "Loading...", "N/A")
- Verify all data comes from real APIs/databases

---

### 3. Detection Techniques (10 minutes)

**Presenter**: Grace

**Content**: Practical techniques for finding prohibited patterns during code review

#### IDE Search Strategies (3 min)

**Visual Demo**: Show how to use IDE search effectively

```bash
# Backend (.NET) search patterns
NotImplementedException
TODO|FIXME|HACK|XXX|TEMP|WORKAROUND
return null;
return default;

# Frontend (TypeScript) search patterns
TODO|FIXME|HACK|XXX
console\.log.*not implemented
Coming Soon|Under Construction|Not implemented
```

**Pro Tip**: Use regex search for comprehensive coverage

---

#### Manual Review Checklist (4 min)

**Walk through the checklist**:

```markdown
### Prohibited Patterns Check (MANDATORY)

**Stub Detection**:
- [ ] Any `throw new NotImplementedException()` in code
- [ ] Any method with empty body or only comments
- [ ] Any `// TODO:`, `// FIXME:`, `// HACK:`, `// XXX:` comments
- [ ] Any method returning `null`, `default`, or hardcoded values
- [ ] Any function that logs "not implemented" or similar
- [ ] Any component displaying "Coming Soon", "Under Construction", etc.
- [ ] Any catch block with empty body or only comments

**Simplified Implementation Detection**:
- [ ] Does the code handle ALL acceptance criteria or just the happy path?
- [ ] Are there input validation checks for all user inputs?
- [ ] Are there error handling blocks for all async operations?
- [ ] Are there null/undefined checks for all external data?
- [ ] Are there boundary value validations (min/max, empty, negative)?
- [ ] Are there loading/empty/error states for all async UI operations?
- [ ] Are there security checks (authentication, authorization, input sanitization)?
- [ ] Are there logging statements for error conditions?
- [ ] Are there rollback/cleanup actions for failed operations?

**Temporary Quick-Fix Detection**:
- [ ] Any comments containing "temporary", "hack", "workaround", "band-aid"?
- [ ] Any commented-out code blocks (even with explanations)?
- [ ] Any disabled security/validation checks?
- [ ] Any hardcoded values with "will be replaced" comments?
- [ ] Any "magic numbers" or strings without proper abstraction?
- [ ] Any bypassed error handling with "for now" comments?

**Mock/Fake Data Detection**:
- [ ] Any hardcoded strings that look like sample data ("Test User", "Sample Product")?
- [ ] Any magic numbers used as data values?
- [ ] Any placeholder text ("Coming Soon", "Loading...", "N/A") in production?
- [ ] Any default/fallback values that should come from API?
- [ ] Any mock objects or fake data generators in production code?
- [ ] Any test fixtures or sample data files included in production?
```

---

#### Red Flag Patterns (3 min)

**Common patterns to watch for**:

| Red Flag | What It Means | Action |
|----------|---------------|--------|
| `// TODO:` | Incomplete implementation | REJECT - Full implementation required |
| `throw new NotImplementedException()` | Stub method | REJECT - Implement or remove method |
| `// HACK:` | Temporary workaround | REJECT - Proper solution required |
| `return null;` | Missing implementation | REJECT - Return proper data or error |
| Hardcoded sample data | Fake data in production | REJECT - Use real API/database |
| Empty catch block | Silently swallowing errors | REJECT - Proper error handling required |
| Commented-out code | Legacy code kept around | REJECT - Remove or implement properly |

---

### 4. Rejection Process (10 minutes)

**Presenter**: Grace

**Content**: How to reject an MR professionally and effectively

#### Rejection Template Walkthrough (5 min)

**Show the template**:
```markdown
## REJECTED: Prohibited Implementation Patterns Detected

### Violations Found

**Location**: `ProductService.cs:45`

**Pattern Type**: Stub Implementation

**Code**:
```csharp
public async Task<Product> GetByIdAsync(string id)
{
    throw new NotImplementedException("TODO: Implement this method");
}
```

**Issue**: Method throws NotImplementedException instead of implementing business logic. This is a stub implementation that provides no actual functionality.

**Required Fix**: 
1. Implement full method logic to fetch product from database
2. Add proper error handling for product not found case
3. Add input validation for null/empty id
4. Add logging for the operation
5. Write unit tests covering the implementation

**Reference**: [PROHIBITED-PATTERNS.md#1-stub-implementations](./PROHIBITED-PATTERNS.md#1-stub-implementations)

### Action Required

1. Remove all stub/simplified/temporary implementations
2. Implement full business logic per acceptance criteria
3. Add proper error handling and validation
4. Remove all mock/fake/placeholder data
5. Re-run all tests and verify they pass
6. Resubmit for review

**Note**: Repeated violations will be escalated to Marcus (Principal Architect) and Emma (Product Coordinator).
```

**Key Points**:
- Be **specific** about location and pattern type
- Show the **actual code** that violates standards
- Explain **why** it violates standards
- Provide **clear action items** for fixing
- Reference the **relevant documentation**
- Maintain **professional tone** - focus on code, not person

---

#### Common Rejection Mistakes (3 min)

**What NOT to do**:

```markdown
❌ BAD REJECTION:
"This is incomplete. Fix it."

Issues:
- Not specific about what's wrong
- Doesn't explain why it's a problem
- No guidance on how to fix
- Unprofessional tone
```

```markdown
❌ BAD REJECTION:
"Please implement this later. For now, this is okay."

Issues:
- Contradicts zero tolerance policy
- Allows stub implementations
- Sets wrong precedent
- Violates standards
```

```markdown
✅ GOOD REJECTION:
"REJECTED: Stub implementation detected in ProductService.GetByIdAsync(). 
Method throws NotImplementedException instead of implementing business logic. 
See PROHIBITED-PATTERNS.md Section 1 for requirements. 
Please implement full logic including database query, error handling, and validation. 
Resubmit when complete."
```

---

#### Escalation Process (2 min)

**When and how to escalate**:

```
First Violation:
└─> Reviewer rejects with detailed feedback
    └─> Implementer fixes and resubmits

Second Violation (same MR or same implementer):
└─> Reviewer rejects + escalates to Marcus
    └─> Marcus reviews and provides architecture guidance
        └─> Implementer fixes with Marcus input

Third Violation (same implementer):
└─> Emma notified for team-wide coaching
    └─> Emma discusses with implementer
        └─> Additional training may be required
```

**Escalation Checklist**:
- [ ] Document all previous violations (dates, MRs, patterns)
- [ ] Provide clear evidence of repeated issues
- [ ] Include implementer's response to previous feedback
- [ ] Recommend specific coaching/training actions

---

### 5. Live Examples (10 minutes)

**Presenter**: Grace

**Content**: Review real (anonymized) MRs with violations

#### Exercise 1: Backend Stub (3 min)

**Show MR snippet**:
```csharp
public async Task<Order> ProcessOrderAsync(OrderRequest request)
{
    // TODO: Implement order processing
    // FIXME: Need to integrate with payment gateway
    // HACK: Temporary solution
    return new Order { Id = "1", Status = "Completed" };
}
```

**Ask audience**:
- What prohibited patterns do you see?
- How would you reject this?
- What would you require for resubmission?

**Expected answers**:
- TODO/FIXME/HACK comments
- Simplified implementation (no actual processing)
- Mock data (hardcoded order)
- Reject with specific citations
- Require full implementation with payment integration

---

#### Exercise 2: Frontend Simplified (3 min)

**Show MR snippet**:
```typescript
const ProductList = () => {
  const [products, setProducts] = useState([
    { id: '1', name: 'Sample Product', price: 99.99 }
  ]);
  
  return (
    <ul>
      {products.map(p => <li key={p.id}>{p.name}</li>)}
    </ul>
  );
};
```

**Ask audience**:
- What prohibited patterns do you see?
- What states are missing?
- How would you reject this?

**Expected answers**:
- Mock/fake data (hardcoded product)
- Simplified implementation (no loading/error/empty states)
- No API integration
- Reject and require real data fetching + all states

---

#### Exercise 3: Temporary Quick-Fix (4 min)

**Show MR snippet**:
```csharp
public async Task<decimal> CalculateTaxAsync(decimal amount, string region)
{
    // TEMPORARY: Using flat rate until tax service is ready
    // Will be replaced with proper tax service call
    if (region == "US") return amount * 0.08m;
    if (region == "EU") return amount * 0.20m;
    return amount * 0.05m; // Default
}
```

**Ask audience**:
- What prohibited pattern is this?
- Why is it problematic?
- What's the proper solution?

**Expected answers**:
- Temporary quick-fix pattern
- Magic numbers with "temporary" comment
- Hardcoded tax rates (should come from service/config)
- Reject and require proper tax service integration
- No "temporary" code in production

---

### 6. Q&A (5 minutes)

**Presenter**: Grace

**Content**: Address questions and concerns from participants

**Anticipated Questions**:

**Q**: "What if the implementer says they'll fix it later?"  
**A**: "Later never comes. Production code must be complete. If they can't implement it now, the issue should be BLOCKED, not stubbed."

**Q**: "How do I handle pressure to merge quickly?"  
**A**: "Stand your ground. Approving prohibited patterns is a code review failure. Escalate to Marcus/Emma if pressured."

**Q**: "What about legacy code with TODOs?"  
**A**: "Legacy code is a separate technical debt issue. New code and changes must be complete. If touching legacy code, either fix the TODOs or document them as separate technical debt issues."

**Q**: "How strict should I be on comments?"  
**A**: "TODO/FIXME/HACK comments in production code are prohibited. Documentation comments (/// XML docs) are fine. If you see implementation-related TODOs, reject."

**Q**: "What if I'm not sure if something is a violation?"  
**A**: "When in doubt, reject and ask Marcus for guidance. Better to be cautious than approve substandard code."

---

## 📚 Training Materials

### Handouts

1. **Prohibited Patterns Quick Reference Card** (1-page summary)
2. **Detection Checklist** (printable for code review)
3. **Rejection Template** (copy-paste ready)
4. **Escalation Flowchart** (visual guide)

### Reference Documents

- `PROHIBITED-PATTERNS.md` - Full documentation
- `ISSUE-MR-TEMPLATES.md` - Enhanced MR templates
- `TASK-TEMPLATES.md` - Enhanced task templates
- `AGENTS.md` - Role definitions with prohibited patterns detection

---

## ✅ Post-Training Actions

### For Reviewers (Grace, Felix, Marcus, Maya)

- [ ] Update personal review checklists with prohibited patterns detection
- [ ] Bookmark `PROHIBITED-PATTERNS.md` for quick reference
- [ ] Practice using the rejection template on sample MRs
- [ ] Schedule 1:1 with Grace if additional guidance needed

### For Implementers (Daniel, Sophia, Ethan, etc.)

- [ ] Study `PROHIBITED-PATTERNS.md` examples
- [ ] Add self-review step before creating MRs
- [ ] Update personal development workflow to prevent violations
- [ ] Ask questions if unclear about requirements

### For Grace (Trainer)

- [ ] Collect feedback from training participants
- [ ] Track first-week violation detection and rejection rates
- [ ] Schedule follow-up if needed (2 weeks post-training)
- [ ] Report training effectiveness to Emma and Marcus

---

## 📊 Success Metrics

**Training Effectiveness**:
- 100% of reviewers complete training
- 100% of reviewers update checklists within 1 week
- All reviewers can correctly identify prohibited patterns in test scenarios

**Enforcement Effectiveness** (measured 30 days post-training):
- 0% approval rate of MRs with prohibited patterns
- 100% of rejections use the standard template
- Reduced average MR revision count (fewer rounds of review)
- Increased first-pass approval rate for production-ready code

---

## 🔄 Continuous Improvement

**Monthly Review**:
- Grace reviews all prohibited pattern violations and rejections
- Identify common patterns and root causes
- Update training materials with new examples
- Share learnings with the team

**Quarterly Audit**:
- Emma audits MR approval rates and violation trends
- Assess if additional training is needed
- Update `PROHIBITED-PATTERNS.md` with new patterns if discovered
- Recognize reviewers with 100% compliance

---

## 📧 Contact Information

**Training Questions**: Grace (grace@phanes.ltd)  
**Policy Questions**: Emma (emma@phanes.ltd)  
**Escalation**: Marcus (marcus@phanes.ltd)

---

*This training plan supports OElite's commitment to engineering excellence and production-ready code.*
