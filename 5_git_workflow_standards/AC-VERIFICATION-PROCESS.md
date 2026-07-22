# Acceptance Criteria Verification Process

> **Repository**: coding-standards
> **Last Updated**: 2026-07-22
> **Maintained by**: Olivia (QA & Test Automation), Isabella (Business Analysis)
> **Status**: Active
> **Version**: 1.0.0

---

## Overview

This document defines the process for verifying that user story acceptance criteria (AC) are fully implemented in source code before marking a story as "Implemented". This ensures traceability and prevents false-positive status claims.

---

## Purpose

- **Prevent false positives**: Stories marked "Implemented" must have actual code backing
- **Ensure traceability**: Every AC must link to a specific implementation artifact
- **Enable accurate progress tracking**: Catalog/inventory reflects true implementation state
- **Support automated verification**: Structure AC for potential automated checking

---

## Verification Workflow

### Step 1: AC Extraction

For each user story being claimed as "Implemented":

1. Extract all AC from the story file: `docs/business/user-stories/US-<NNN>.md`
2. List each AC with its GIVEN/WHEN/THEN format
3. Identify the expected observable behavior for each AC

### Step 2: Implementation Mapping

For each AC, find the corresponding implementation:

| AC Type | Where to Verify | Verification Method |
|---------|-----------------|---------------------|
| API endpoint | Backend controller | `grep -R "HttpGet|HttpPost" --include="*Controller.cs"` |
| Business logic | Service class | `grep -R "<MethodName>" --include="*Service.cs"` |
| Database operation | Repository | `grep -R "<CollectionName>" --include="*Repository.cs"` |
| Frontend UI | Component file | `grep -R "<ComponentName>" --include="*.tsx"` |
| Event emission | EventService | `grep -R "DispatchAsync" --include="*Service.cs"` |
| Webhook dispatch | WebhookService | `grep -R "WebhookDelivery" --include="*.cs"` |
| Test coverage | Test files | `dotnet test --filter "FullyQualifiedName~<Feature>"` |

### Step 3: Status Determination

| Condition | Status |
|-----------|--------|
| All AC implemented with passing tests | ✅ Implemented |
| Core AC implemented, edge cases missing | ⚠️ Partial |
| Implementation started but incomplete | 🟡 In Progress |
| No implementation found | ❌ Not Implemented |

### Step 4: Documentation Update

Update the following files with verified status:

1. `docs/business/user-stories/US-<NNN>.md` — Update `Status:` field
2. `docs/business/user-stories/user-story-catalog-complete.md` — Update summary table
3. `docs/business/user-stories/user-story-inventory.md` — Update inventory table

---

## AC Verification Checklist

When verifying a story, check ALL of the following:

### Backend Verification

- [ ] Controller endpoint exists with correct HTTP method
- [ ] Request DTO matches AC input specification
- [ ] Response DTO matches AC output specification
- [ ] Service method implements business logic
- [ ] Repository performs required data operations
- [ ] Domain events emitted where specified
- [ ] Error handling matches AC error cases
- [ ] Unit tests exist for service methods
- [ ] Integration tests exist for API endpoints

### Frontend Verification

- [ ] Component exists with correct name
- [ ] UI elements match AC wireframe/spec
- [ ] Form validation matches AC requirements
- [ ] API calls wired to correct endpoints
- [ ] Error states handled per AC
- [ ] Loading states implemented
- [ ] Accessibility requirements met
- [ ] E2E tests cover user journey

### Integration Verification

- [ ] Backend-frontend integration tested
- [ ] Webhook delivery verified (if applicable)
- [ ] Event flow verified end-to-end
- [ ] Database writes verified
- [ ] External service calls verified (Stripe, etc.)

---

## Common Verification Patterns

### Pattern 1: CRUD Endpoint

```bash
# Find controller
grep -R "class.*Controller" backend/OElite.Servers.Apex/Controllers/

# Find endpoint
grep -R "HttpGet|HttpPost|HttpPut|HttpDelete" backend/OElite.Servers.Apex/Controllers/<Name>Controller.cs

# Find service
grep -R "class.*Service" backend/OElite.Services.Apex/<Domain>/<Name>Service.cs

# Find tests
dotnet test --filter "FullyQualifiedName~<Name>Controller"
```

### Pattern 2: Subscription State Machine

```bash
# Find state transitions
grep -R "TransitionTo|Cancel|Pause|Resume" backend/OElite.Services.Apex/Subscriptions/

# Find state machine tests
grep -R "SubscriptionState" backend/OElite.Services.Apex.Tests/Subscriptions/

# Verify event emission
grep -R "subscription\." backend/OElite.Services.Apex/Events/EventService.cs
```

### Pattern 3: Payment Processing

```bash
# Find payment gateway
grep -R "IPaymentGateway|StripePaymentGateway" backend/OElite.Services.Apex/Payments/

# Find payment intent creation
grep -R "PaymentIntent|CreatePaymentIntent" backend/OElite.Services.Apex/Payments/

# Find webhook handlers
grep -R "payment\." backend/OElite.Services.Apex/Events/EventService.cs
```

### Pattern 4: Frontend Component

```bash
# Find component
find dashboard/src/components -name "*.tsx" | xargs grep -l "<ComponentName>"

# Check API wiring
grep -R "apiClient\.|api\." dashboard/src/components/<Area>/<Component>.tsx

# Check E2E test
grep -R "<feature>" dashboard/e2e/*.spec.ts
```

---

## False Positive Prevention

### Known False Positive Patterns

| Pattern | Example | Fix |
|---------|---------|-----|
| ID mismatch | US-170 catalog says "Rate Limiting ✅" but file is "Workflow Triggers" | Verify story ID matches file content |
| Epic status mismatch | Epic 10 says "Implemented" but all stories are ❌ | Check story-level status, not epic summary |
| Catalog vs file mismatch | Inventory says "Stripe Integration" but US-061 is "Multi-Currency" | Cross-reference catalog IDs with US files |
| Implementation claimed but no tests | "Implemented" with no test files | Require passing tests for "Implemented" |

### Verification Rules

1. **Never trust status at face value** — Always verify against source code
2. **Check both catalog and file** — They can drift
3. **Require test evidence** — No tests = not fully implemented
4. **Verify end-to-end** — Backend + frontend + integration
5. **Check edge cases** — Happy path only = partial implementation

---

## Integration with Issue Workflow

### During Issue Creation

1. Link issue to user story: `Related to US-<NNN>`
2. Copy AC from user story into issue description
3. Use AC IDs in task breakdown: "Implement AC-001"

### During Implementation

1. Create test files that reference AC IDs
2. Use AC IDs in commit messages: "feat: implement US-015 AC-001"
3. Comment on issue with implementation links

### Before Marking Complete

1. Run full AC verification checklist
2. Update story status file
3. Update catalog/inventory tables
4. Comment on issue with verification summary
5. Link to evidence (commit, test run)

---

## Template: AC Verification Report

```markdown
## AC Verification Report: US-<NNN>

**Story**: <Title>
**Verified By**: <Agent>
**Date**: <YYYY-MM-DD>
**Status**: ✅ Implemented | ⚠️ Partial | 🟡 In Progress | ❌ Not Implemented

### AC-001: <Title>
- **Status**: ✅ Implemented
- **Evidence**:
  - Controller: `backend/.../XController.cs:42`
  - Service: `backend/.../XService.cs:87`
  - Test: `backend/.../XControllerTests.cs:123`
- **Notes**: All GIVEN/WHEN/THEN verified

### AC-002: <Title>
- **Status**: ⚠️ Partial
- **Evidence**: Backend implemented, frontend pending
- **Gap**: Frontend component `XDialog.tsx` not created

### Summary
- Total AC: <N>
- Implemented: <N>
- Partial: <N>
- Not Implemented: <N>
- Recommended Status: <status>
```

---

## Appendix: Phase 1/2 Verification Results

### TASK-001: Rate Limiting Middleware
- ✅ `RateLimitingMiddleware.cs` implemented
- ✅ `RateLimitingService.cs` implemented
- ✅ Redis sliding window algorithm
- ✅ Tier configuration
- ✅ Tests passing

### TASK-002: Payment/Customer Events
- ✅ `payment.succeeded`, `payment.failed`, `payment.refunded`
- ✅ `customer.created`, `customer.updated`
- ✅ `EventService.DispatchAsync` wired
- ✅ Tests passing

### TASK-003: Subscription Management UI
- ✅ `CreateSubscriptionDialog.tsx`
- ✅ `ChangePlanDialog.tsx` with proration
- ✅ `CancelSubscriptionDialog.tsx`
- ✅ `ViewSubscriptionDialog.tsx`
- ✅ Build passes

### TASK-004: Settings Page Wiring
- ✅ All 8 tabs wired to real API
- ✅ `settings-api.ts` typed client
- ✅ Zero `setTimeout` mocks
- ✅ Build passes

### TASK-005: IPaymentGateway Abstraction
- ✅ Interface extracted
- ✅ `StripePaymentGateway` implements interface
- ✅ `PaymentService` injects abstraction
- ✅ Build passes

### TASK-006: Stripe Elements
- ✅ Card elements in portal
- ✅ Apple Pay / Google Pay
- ✅ Card brand detection
- ✅ Build passes

### TASK-007: Usage to ClickHouse
- ✅ `UsageService` → RabbitMQ
- ✅ `EventPipeline` → ClickHouse
- ✅ Dual write preserved
- ✅ Build passes

### TASK-008: Fix NotImplementedException
- ✅ `WalletService.cs` fixed
- ✅ `HierarchyUsageService.cs` fixed
- ✅ `InvoiceService` fixed
- ✅ Codebase scanned

### TASK-009: Marketing Site Auth
- ✅ `auth-api.ts` created
- ✅ `signin/page.tsx` rewritten
- ✅ `signup/page.tsx` rewritten
- ✅ Form validation, error handling
- ✅ lucide-react icons
- ✅ Build passes

### TASK-010: Subscription States
- ✅ Expired state added
- ✅ Incomplete state added
- ✅ All transitions emit events
- ✅ Build passes

### TASK-011: Invoice Modal Fixes
- ✅ All `alert()` replaced with toast
- ✅ Customer dropdown wired to API
- ✅ Line item amount computed
- ✅ All @heroicons converted to lucide-react
- ✅ tsc clean

---

## Document Control

- **Owner**: Olivia (QA), Isabella (BA)
- **Reviewers**: Emma, Marcus, Grace, Felix
- **Update Frequency**: Per release
- **Next Review**: 2026-08-22
- **Version Control**: See Git history
