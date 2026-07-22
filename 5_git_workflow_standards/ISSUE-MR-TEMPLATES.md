# OElite GitLab Issue & Merge Request Templates

> **Repository**: coding-standards  
> **Last Updated**: 2026-06-29  
> **Maintained by**: Emma (Product & Delivery Coordinator) & Isabella (Business Analyst)  
> **Status**: Active  > **Version**: 1.0.0

---

## Overview

This document defines the standard GitLab issue and merge request templates for all OElite repositories. These templates MUST be installed in every active repository under `<repo>/.gitlab/`.

The templates enforce consistent, detailed, and verifiable task information so that agents can execute work without re-clarification.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Issue Template: Feature](#2-issue-template-feature)
3. [Issue Template: Bug](#3-issue-template-bug)
4. [Issue Template: Task](#4-issue-template-task)
5. [Merge Request Template](#5-merge-request-template)
6. [Required Labels Reference](#6-required-labels-reference)

---

## 1. Installation

Every active OElite repository MUST contain the following files:

```
<repo>/
└── .gitlab/
    ├── issue_templates/
    │   ├── Feature.md
    │   ├── Bug.md
    │   └── Task.md
    └── merge_request_templates/
        └── Default.md
```

To install:
1. Copy the templates below into the corresponding files.
2. Customize only the repo-specific sections (e.g., component list, health endpoint port).
3. **Enable GitLab auto-close**: In each project, go to Settings → General → Merge requests → check "Close issues automatically when merged from MR". This ensures issues referenced via `Closes #<iid>` are auto-closed when the MR merges, providing a safety net alongside the manual closure enforcement in the workflow.
4. Commit and push to `develop` via MR.

---

## 2. Issue Template: Feature

**File**: `.gitlab/issue_templates/Feature.md`

```markdown
## Title
[US-XXX] <Short, actionable feature title>

## User Story
**As a** <role/persona>, **I want** <goal>, **So that** <benefit>.

## Context
<Why this feature exists. Link to BRD/SRS/user story.>

## Acceptance Criteria
- [ ] **AC-001**: GIVEN <context> WHEN <action> THEN <observable outcome>
- [ ] **AC-002**: GIVEN <context> WHEN <action> THEN <observable outcome>
- [ ] **AC-003**: GIVEN <context> WHEN <action> THEN <observable outcome>

## Source References
- User Story: `docs/business/user-stories/US-<NNN>-<feature>.md`
- BRD: FR-<NNN>
- SRS: Section <X.X>
- Design Spec: <link>
- Related Issues: #<NNN>, #<NNN>

## Area / Component
- [ ] Backend (.NET)
- [ ] Frontend (Next.js / Angular / MAUI)
- [ ] Infrastructure / DevOps
- [ ] Security
- [ ] Data / Performance
- [ ] Documentation
- [ ] UX / Design

## Dependencies
- [ ] <US-XXX or issue that must complete first>
- [ ] <API endpoint availability>
- [ ] <Design spec approval>
- [ ] <Infrastructure readiness>

## Story Points
<Fibonacci estimate>

## Priority
- [ ] Critical
- [ ] High
- [ ] Medium
- [ ] Low

## Estimated Effort
<X hours / days>

## Verification Approach
<How will the assignee prove completion? Build, tests, health check, screenshots.>

## AC Verification
All acceptance criteria MUST be verified against source code per [AC-VERIFICATION-PROCESS.md](./AC-VERIFICATION-PROCESS.md):
- [ ] Each AC has corresponding implementation artifact (controller, service, component)
- [ ] Each AC has passing test coverage
- [ ] Edge cases implemented (not just happy path)
- [ ] Story status updated in catalog and inventory after completion

## Documentation Impact
- [ ] No documentation changes needed
- [ ] BRD/SRS update needed
- [ ] API docs update needed
- [ ] User guide update needed
- [ ] README update needed

/label ~"To Do"
/milestone %"Sprint-<X>"
```

---

## 3. Issue Template: Bug

**File**: `.gitlab/issue_templates/Bug.md`

```markdown
## Title
[BUG-XXX] <Short description of the bug>

## Severity
- [ ] Critical — production outage, data loss, security breach
- [ ] High — major feature broken, no workaround
- [ ] Medium — feature impaired, workaround exists
- [ ] Low — cosmetic, edge case, or minor inconvenience

## Environment
- [ ] Development
- [ ] UAT / Staging
- [ ] Production

## Affected Component
<Backend service, frontend page, API endpoint, infrastructure, etc.>

## Steps to Reproduce
1. <Step 1>
2. <Step 2>
3. <Step 3>

## Expected Behavior
<What should happen>

## Actual Behavior
<What actually happens. Include error messages, stack traces, screenshots.>

## Root Cause Analysis
<To be filled by assignee after investigation>

## Proposed Fix
<To be filled by assignee>

## Regression Risk
- [ ] Low — isolated change
- [ ] Medium — touches shared component
- [ ] High — affects critical path

## Verification
- [ ] Bug no longer reproducible with steps above
- [ ] Unit test added
- [ ] Integration test added (if data-layer related)
- [ ] E2E test added (if user-facing)
- [ ] No regressions in related functionality

## Related Issues
- Caused by: #<NNN>
- Related to: #<NNN>

/label ~"To Do" ~"Bug"
```

---

## 4. Issue Template: Task

**File**: `.gitlab/issue_templates/Task.md`

```markdown
## Title
[TASK-XXX] <Short, actionable task title>

## Context
<Why this task exists. Reference user story, BRD, SRS, or technical requirement.>

## Objective
<What must be accomplished>

## Acceptance Criteria
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] <Criterion 3>

## Source References
- User Story: `docs/business/user-stories/US-<NNN>-<feature>.md`
- Related Issue: #<NNN>
- Related MR: !<NNN>

## Area / Component
- [ ] Backend (.NET)
- [ ] Frontend (Next.js / Angular / MAUI)
- [ ] Infrastructure / DevOps
- [ ] Security
- [ ] Data / Performance
- [ ] Documentation
- [ ] UX / Design

## Dependencies
- [ ] <Issue or system dependency>

## Story Points
<Fibonacci estimate>

## Priority
- [ ] Critical
- [ ] High
- [ ] Medium
- [ ] Low

## Verification
<How will completion be verified?>

## AC Verification
All acceptance criteria MUST be verified against source code per [AC-VERIFICATION-PROCESS.md](./AC-VERIFICATION-PROCESS.md):
- [ ] Each AC has corresponding implementation artifact
- [ ] Each AC has passing test coverage
- [ ] Edge cases implemented (not just happy path)
- [ ] Story status updated in catalog and inventory after completion

/label ~"To Do"
/milestone %"Sprint-<X>"
```

---

## 5. Merge Request Template

**File**: `.gitlab/merge_request_templates/Default.md`

```markdown
## Related Issue
Closes #<issue-iid>

## Summary
<What changed and why. Keep to 3-5 bullet points.>

## Changes
- <Change 1>
- <Change 2>
- <Change 3>

## Verification
- [ ] Build passes (`dotnet build` / `npm run build` / `ng build`)
- [ ] Unit tests pass
- [ ] Integration tests pass against real Docker infrastructure
- [ ] E2E tests pass against running dev server (if user-facing)
- [ ] **AC Verification**: All acceptance criteria verified per [AC-VERIFICATION-PROCESS.md](./AC-VERIFICATION-PROCESS.md)
- [ ] **NO stub implementations**: Every method/endpoint/component has full production-ready logic (no `throw new NotImplementedException()`, no empty method bodies, no `// TODO: implement later` comments)
- [ ] **NO simplified implementations**: All business logic, error handling, validation, and edge cases are implemented per acceptance criteria (no "happy path only", no "basic version for now")
- [ ] **NO temporary quick-fixes**: All solutions are permanent and production-ready (no "quick fix", "temporary workaround", "hack", "for now" comments or code)
- [ ] **NO placeholder/fake/mock data**: All data comes from real APIs/databases (no hardcoded strings, no mock objects in production code, no sample/test data)
- [ ] Code follows OElite coding standards
- [ ] Directory scope respected (no changes outside assigned scope)
- [ ] Commit messages follow convention (title + bulleted body)
- [ ] No secrets, PATs, or credentials in committed files
- [ ] No `as any`, `@ts-ignore`, or type-error suppression (frontend)
- [ ] No raw `MongoDB.Driver`, `BsonDocument`, or manual DI (backend)
- [ ] Health endpoint verified if service is runnable

### E2E Test Coverage Verification (For UI Features - Olivia Mandate)
- [ ] **API integration tests**: Verify request payloads, response data mapping, error handling, loading states
- [ ] **UI layout tests**: Verify responsive breakpoints, design token compliance, Shadcn component usage
- [ ] **Interactive element tests**: Verify all buttons/links, form validation, keyboard navigation, focus management
- [ ] **Full-stack tests**: Verify data persistence, authentication/authorization, multi-step workflows
- [ ] **Accessibility tests**: Verify WCAG 2.1 AA compliance (ARIA labels, keyboard navigation, focus states, aXe scan, touch targets)
- [ ] **Business logic validation tests**: Verify UI enforces business rules before API submission, derived/calculated values correct, state machine transitions valid
- [ ] **User journey tests**: Happy path, branching, error recovery, permission-based, cancellation/rollback flows
- [ ] **State management tests**: Cache invalidation, optimistic updates, stale data handling, error boundary in cache
- [ ] **Playwright evidence captured**: Screenshots/videos for critical journeys, network logs, console verification
- [ ] **Coverage mapping**: Each E2E test maps to user story acceptance criteria (US-XXX/AC-YYY)

**REVIEWER MANDATE**: If ANY stub/fake/simplified/temporary implementation is detected, the MR MUST be rejected with specific citations. Approval without verifying full implementation is a code review failure.

**E2E MANDATE**: If UI feature lacks comprehensive E2E coverage (API + layout + interactive + full-stack validation), the MR MUST be rejected. "Unit tests pass" is NOT sufficient for user-facing features.

## Commands Executed
```bash
# Build
<command>

# Tests
<command>

# Health check
curl -f http://localhost:<port>/health
```

## Screenshots (if UI changes)
<Before/After screenshots or Playwright evidence>

## Documentation Impact
- [ ] No documentation changes needed
- [ ] BRD/SRS updated
- [ ] API docs updated
- [ ] User guide updated
- [ ] README updated

## Reviewer
<Per workflow chain: Grace (backend), Felix (frontend), Maya (security), Marcus (architecture)>

### Post-Approval Actions (Reviewer or Emma)
- [ ] **Merge verified**: `mr-status <project> <mr-iid>` confirms `merged` state
- [ ] **Issue labeled `Done`** (after Isabella business validation)
- [ ] **Issue closed in GitLab**: `issue-status <project> <issue-iid> emma closed` — in same session as merge verification

/label ~"PR Review"
```

---

## 6. Required Labels Reference

Every OElite GitLab project MUST have the following labels:

| Label | Color | Meaning | Who Sets |
|-------|-------|---------|----------|
| `To Do` | `#666666` | Issue created, not yet started | Emma (on creation) |
| `In Progress` | `#0075CA` | Agent actively working | Assignee |
| `PR Review` | `#FCA326` | MR created, awaiting review | Assignee |
| `Ready to Merge` | `#009966` | MR approved + CI green | Reviewer |
| `Done` | `#3CB371` | MR merged + business validation passed | Emma |
| `Blocked` | `#FF0000` | External dependency blocking progress | Assignee |
| `Bug` | `#DC3545` | Defect or regression | Emma / Reporter |
| `Priority::Critical` | `#FF0000` | Must be resolved immediately | Emma |
| `Priority::High` | `#FF8C00` | Significant business impact | Emma |
| `Priority::Medium` | `#FFD700` | Normal priority | Emma |
| `Priority::Low` | `#90EE90` | Can be deferred | Emma |

---

## Related Documentation

- `AGENTS.md` — OElite team roles and workflow chains
- [GIT-WORKFLOW-STANDARDS.md](./GIT-WORKFLOW-STANDARDS.md) — GitLab workflow and issue lifecycle
- [TASK-TEMPLATES.md](./TASK-TEMPLATES.md) — Task, bug, and sprint templates
- [DOC-STANDARDS.md](../6_documentation_standards/DOC-STANDARDS.md) — Documentation templates

## Change History

| Date | Author | Version | Changes |
|------|--------|---------|---------|
| 2026-07-22 | Orchestrator / Isabella | 1.1.0 | Added AC verification checklist from AC-VERIFICATION-PROCESS.md to all templates |
| 2026-06-29 | Emma / Isabella | 1.0.0 | Created dedicated ISSUE-MR-TEMPLATES.md for GitLab issue and MR templates |
