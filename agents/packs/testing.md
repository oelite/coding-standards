# Task Pack: Testing

## Who Loads This
Olivia (primary), Daniel (backend testing reference), Sophia (frontend testing reference)

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
- 8 Quality Gates:
  1. Min 3 assertions/test
  2. Real server + real API
  3. Interaction Coverage Matrix (9 categories)
  4. AC Traceability (`US-XXX/AC-XXX`)
  5. RBAC Matrix (per role)
  6. Interactive Component Pattern
  7. No-Op Detection
  8. Execution Evidence

## Minimum Test Counts
| Feature | Tests |
|---------|-------|
| Read-only list | 8-15 |
| CRUD page | 25-50 |
| Form + validation + API | 15-30 |
| Permission-dependent UI | 10-20 per role |
| Dashboard | 10-20 |
| Multi-step workflow | 30-60 |

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
