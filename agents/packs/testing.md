# Task Pack: Testing

## Who Loads This
Olivia (primary), Daniel (backend testing reference), Sophia (frontend testing reference)

## Workflow Prerequisites (Before ANY Code)
> **Mandatory — non-negotiable.** These steps MUST be completed before any file edits, builds, or tests.

1. **Verify issue exists** in GitLab with acceptance criteria + owner assigned
2. **Safe sync** (does NOT checkout develop — avoids footgun):
   ```bash
   ../../coding-standards/scripts/oelite-gitlab.sh worktree-sync
   ```
3. **Create worktree** with YOUR role identity:
   ```bash
   ../../coding-standards/scripts/oelite-gitlab.sh worktree-create <role> feature/<branch> --issue <iid>
   ```
4. **Enter worktree**:
   ```bash
   cd .worktrees/<role>-<iid>/
   ```
5. **Verify .oe-scope** exists (compaction-resilient context anchor):
   ```bash
   test -f .oe-scope && cat .oe-scope
   ```
6. **ONLY NOW** may you write code. The pre-commit hook will block any commit made outside the worktree or on protected branches (develop/main/master).

⚠️ **Never** run `git checkout develop` to work — use `worktree-sync` for syncing. The `develop` branch is reserved for human developers and MR merges only.

## Standards to Read (via tools)
- `coding-standards/1_dotNet_coding_standards/02` (acceptance flow)
- `coding-standards/5_git_workflow_standards/TASK-TEMPLATES.md` (E2E requirements)
- `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md` (Insufficient E2E Coverage section)
- Target repo `.ai/standards/testing-standards.md` (if exists)
- User stories from `docs/business/user-stories/` (source of truth)

## Testing Levels

### Unit Tests
- Pure business logic only
- Cover: happy path, null/empty, invalid, boundary, error
- Every service method with business logic needs a unit test

### Integration Tests (Data Layer)
- **REAL Docker containers** — zero mocks
- Every repository method + controller action
- Mark: `[Trait("Category", "Integration")]` + `[Category("SkipCI")]`
- CI runs: `dotnet test --filter "Category!=Integration"`
- Confirm containers healthy before running tests

### E2E Browser Tests (Playwright)
- **MANDATORY for all web apps**
- Run headless: `npx playwright test`
- Real dev server + real API calls
- 12 Quality Gates:
   1. Min 3 assertions/test
   2. Real server + real API
   3. Interaction Coverage Matrix (9 categories)
   4. AC Traceability (`US-XXX/AC-XXX`)
   5. RBAC Matrix (per role)
   6. Interactive Component Pattern
   7. No-Op Detection
   8. Execution Evidence

### Business Logic Validation in UI (MANDATORY — New Gate 9)

Every E2E test MUST verify that UI components enforce business rules correctly. Tests must validate that business logic is applied in the UI layer before data reaches the API, and that the UI correctly reflects server-side business logic responses.

#### Business Logic Test Patterns

| Pattern | What to Test | Example |
|---------|-------------|---------|
| **Pre-submission validation** | UI blocks invalid input before API call | Submit button disabled until required fields filled; price cannot be negative |
| **Conditional UI based on data** | UI elements change based on data values | "Out of stock" badge when quantity = 0; "Pending" status shown for unapproved items |
| **Business rule enforcement** | UI prevents violating business constraints | Cannot order more than max quantity; discount code only valid for specific categories |
| **Derived/calculated values** | Computed fields match business logic | Cart total = sum(item.price * item.quantity); tax calculated at correct rate |
| **Role-based business logic** | Different roles see different business actions | Admin sees "Approve" button; viewer only sees "View" |
| **State machine transitions** | UI only allows valid state transitions | Cannot "Ship" an order that is not "Paid"; cannot "Delete" a "Completed" order |
| **Cross-field validation** | Combined field rules enforced | If "Country = US", "State" is required; if "Shipping = Express", cost > $50 |
| **Business rule feedback** | Error messages match business domain | "Order minimum is $25.00" not generic "Invalid amount" |
| **Sequential business flow** | UI enforces step ordering | Cannot proceed to checkout without items in cart; cannot pay without shipping address |

#### Minimum Business Logic Tests Per Feature

| Feature Complexity | Minimum Business Logic Tests |
|-------------------|----------------------------|
| Simple form (CRUD create/edit) | 5-10 |
| Complex form (conditional fields, multi-step) | 10-20 |
| Workflow/state machine (order processing, approvals) | 15-25 |
| Dashboard with computed metrics | 8-12 |
| Permission-dependent business actions | 5-10 per role |

### Accessibility Testing (MANDATORY — New Gate 10)

Every E2E test suite MUST include automated accessibility verification:

| Test Type | Tool/Method | Requirements |
|-----------|-------------|-------------|
| **Automated aXe scan** | `@axe-core/playwright` | Run on every page: no critical/serious violations |
| **Keyboard navigation** | Playwright `page.keyboard` | All interactive elements reachable and operable via Tab/Enter/Escape |
| **Focus management** | Playwright assertions | Focus moves correctly on navigation; focus trapped in modals; visible focus indicators |
| **Color contrast** | Automated check + design spec verification | Text contrast >= 4.5:1 (normal) or >= 3:1 (large); UI component contrast >= 3:1 |
| **ARIA attributes** | Playwright assertions | All interactive elements have correct roles, labels, and descriptions |
| **Screen reader** | Manual + automated (aria-live regions) | Dynamic content changes announced; error messages associated with inputs via aria-describedby |
| **Touch targets** | Viewport assertions | All interactive elements >= 44x44px on mobile viewport |

#### Accessibility Test Implementation

```typescript
// Example: aXe scan in Playwright
import { injectAxe, checkAxe } from 'axe-playwright';

test('page has no accessibility violations', async ({ page }) => {
  await page.goto('/products');
  await injectAxe(page);
  const results = await checkAxe(page);
  expect(results.violations.length).toBe(0);
});

// Example: Keyboard navigation test
test('user can navigate form with keyboard', async ({ page }) => {
  await page.goto('/products/create');
  await page.keyboard.press('Tab');
  await expect(page.locator('[name="name"]')).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.locator('[name="price"]')).toBeFocused();
  await page.keyboard.press('Enter');
  // Verify form submitted or next step triggered
});
```

### User Journey Testing (MANDATORY — New Gate 11)

Every E2E test suite MUST include complete user journey tests that span multiple pages and steps:

| Journey Type | What to Test | Minimum Tests |
|-------------|-------------|---------------|
| **Happy path** | Complete flow from start to finish without errors | 2-3 per feature |
| **Branching path** | Flow that forks based on user input or data state | 1-2 per branch |
| **Error recovery path** | Flow that encounters errors and recovers | 1-2 per error type |
| **Permission-based path** | Flow that varies by user role | 1 per role |
| **Cancellation/rollback path** | Flow that is cancelled mid-way, verify clean state | 1 per multi-step flow |

#### User Journey Test Structure

```typescript
test('US-042/AC-001: Complete product creation journey', async ({ page }) => {
  // Step 1: Navigate to product list
  await page.goto('/products');
  await expect(page.locator('h1')).toContainText('Products');

  // Step 2: Click create
  await page.click('[data-testid="create-product"]');
  await expect(page.locator('[role="dialog"]')).toBeVisible();

  // Step 3: Fill form with valid data
  await page.fill('[name="name"]', 'Test Product');
  await page.fill('[name="price"]', '29.99');

  // Step 4: Submit and verify redirect
  await page.click('[data-testid="submit"]');
  await expect(page).toHaveURL(/\/products\/[a-f0-9]+/);

  // Step 5: Verify data persisted
  await expect(page.locator('[data-testid="product-name"]')).toContainText('Test Product');

  // Step 6: Verify business logic applied
  await expect(page.locator('[data-testid="product-status"]')).toContainText('Draft');
  // (Business rule: newly created products start as "Draft")
});
```

### State Management Testing (MANDATORY — New Gate 12)

For apps using SWR, TanStack React Query, or any client-side state management:

| Test Pattern | What to Verify |
|-------------|----------------|
| **Cache invalidation** | After mutation (create/update/delete), cache refreshes and UI shows updated data |
| **Optimistic updates** | UI shows expected state immediately, then reconciles with server response |
| **Stale data handling** | Stale data shows stale indicator, refreshes when component gains focus |
| **Error boundary in cache** | Failed mutations show error state, cache not corrupted |
| **Loading state from cache** | Loading state shown during revalidation, not blank screen |

### State Testing (New addition to Interaction Coverage)

Extend the Interaction Coverage Matrix with state testing:

| Category | What to Test | Example |
|----------|-------------|---------|
| **State transition** | UI correctly transitions between states | Skeleton -> Data -> Empty -> Error -> Retry -> Data |
| **State persistence** | State survives page navigation | Filters applied -> navigate away -> back -> filters still applied |
| **State on refresh** | State survives page reload | Data persisted after browser refresh |
| **Concurrent state** | Multiple state changes handled correctly | Two filters change simultaneously, both applied correctly |

## Minimum Test Counts
| Feature | Tests |
|---------|-------|
| Read-only list | 8-15 |
| CRUD page | 25-50 |
| Form + validation + API | 15-30 |
| Permission-dependent UI | 10-20 per role |
| Dashboard | 10-20 |
| Multi-step workflow | 30-60 |

**Additional minimums (added):**
| Test Category | Minimum Tests |
|---------------|---------------|
| Business logic validation | 5-25 (per complexity, see Business Logic section) |
| Accessibility (aXe + keyboard) | 3-8 per page |
| User journey (end-to-end flows) | 5-15 per feature |
| State management | 3-8 per data entity |

## Coverage Mapping
Every feature must document:
- Which user stories (US-XXX) are covered
- Which acceptance criteria (AC-XXX) are covered
- Test count vs Gate 3 minimums

## Failure Reporting
- Exact repro steps
- Logs/screenshots/videos
- Specific files/lines to fix
- Severity: blocker / warning

## Handoff Target
- Ethan (deploy) → Isabella (docs + biz validation)

## Verification Checklist
- [ ] All tests executed and passing
- [ ] Evidence captured (logs, screenshots, videos)
- [ ] Coverage mapping complete
- [ ] Test count meets Gate 3 minimums
- [ ] No-op tests rejected
- [ ] All user story acceptance criteria covered
- [ ] Docker infrastructure confirmed healthy before tests
- [ ] Business logic validation tests cover all business rules
- [ ] Accessibility tests pass (aXe scan, keyboard nav, ARIA, contrast)
- [ ] User journey tests cover happy path, branching, error recovery, permission-based, cancellation
- [ ] State management tests verify cache invalidation, optimistic updates, stale data handling
- [ ] E2E tests verify UI enforces business rules before API submission
