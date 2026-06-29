# OElite Task Templates

> **Repository**: coding-standards  
> **Last Updated**: 2026-06-29  
> **Maintained by**: Emma (Product & Delivery Coordinator) & Isabella (Business Analyst)  
> **Status**: Active  
> **Version**: 1.0.0

---

## Overview

This document provides the standard templates for creating tasks, issues, bugs, and sprint artifacts in the OElite development workflow. Emma MUST use these templates when creating work for agents. Agents MUST verify that every issue they receive meets the Definition of Ready before starting work.

---

## Table of Contents

1. [Definition of Ready](#1-definition-of-ready)
2. [Definition of Done (Issue Level)](#2-definition-of-done-issue-level)
3. [Task Creation Template](#3-task-creation-template-emma--agent)
4. [Bug Fix Template](#4-bug-fix-template)
5. [Sprint Goal Template](#5-sprint-goal-template)
6. [Post-Mortem / Retrospective Template](#6-post-mortem--retrospective-template)

---

## 1. Definition of Ready

An issue is **Ready** when ALL of the following are true. Emma MUST NOT assign an issue that is not Ready.

- [ ] **User story exists** in `docs/business/user-stories/US-<NNN>-<feature>.md` using the [User Story Template](../6_documentation_standards/DOC-STANDARDS.md#4-user-story-template)
- [ ] **Acceptance criteria** are written in GIVEN/WHEN/THEN format and are verifiable
- [ ] **Owner assigned** based on workflow chain and domain expertise
- [ ] **Story points estimated**
- [ ] **Priority labeled** (Critical / High / Medium / Low)
- [ ] **Dependencies identified** and not blocking
- [ ] **Design spec approved** (if frontend/UI work)
- [ ] **API contract defined** (if backend integration or frontend API consumption)
- [ ] **No `Blocked` label**
- [ ] **Source references** provided (BRD/SRS section, related issues, external docs)

If any item is missing, the assignee MUST ask Emma to clarify before starting work.

---

## 2. Definition of Done (Issue Level)

An issue is **Done** when ALL of the following are true. Only Emma may mark an issue Done after MR merge + Isabella's business validation.

- [ ] MR merged into `develop` via GitLab
- [ ] CI pipeline green (build + unit tests)
- [ ] Integration tests pass against real Docker infrastructure (if applicable)
- [ ] E2E tests pass against running dev server (if user-facing)
- [ ] Code review approved by required reviewer(s) (Grace/Felix/Marcus/Maya)
- [ ] Security review completed (if auth/security/CRUD-sensitive)
- [ ] Performance review completed (if queries/denormalization/caching changed)
- [ ] Business validation passed (Isabella confirms deliverable matches requirements)
- [ ] Documentation updated per [Documentation Triggers](../6_documentation_standards/DOC-STANDARDS.md#9-documentation-triggers)
- [ ] No `Blocked` label remaining
- [ ] Issue status updated through the lifecycle: `In Progress` → `PR Review` → `Ready to Merge` → `Done`

---

## 3. Task Creation Template (Emma → Agent)

**Use for**: Feature work, enhancements, refactor tasks, infrastructure work.

```markdown
# Task: [US-XXX] <Actionable Title>

## Title Format
[US-XXX] <Verb> <Object> — <Short Context>

## Owner
<Daniel / Sophia / Ethan / Jonathan / etc.>

## Context
<Why does this task exist? What business problem does it solve? Reference the user story and BRD/SRS.>

## User Story Reference
- **File**: `docs/business/user-stories/US-<NNN>-<feature>.md`
- **BRD Reference**: FR-<NNN>
- **SRS Reference**: Section <X.X>

## Scope

### In Scope
- <Specific deliverable 1>
- <Specific deliverable 2>

### Out of Scope
- <Explicitly excluded item 1>
- <Explicitly excluded item 2>

## Acceptance Criteria
- [ ] **AC-001**: GIVEN <context> WHEN <action> THEN <observable outcome>
- [ ] **AC-002**: GIVEN <context> WHEN <action> THEN <observable outcome>
- [ ] **AC-003**: GIVEN <context> WHEN <action> THEN <observable outcome>

## Source References
- <Link to design spec, Figma, architecture diagram, related issue, or external doc>
- <Related issue: #<NNN>>
- <Related MR: !<NNN>>

## Technical Notes
<Architecture decisions, patterns to follow, files to modify, APIs to use, constraints.
Reference existing code patterns where possible.>

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
- [ ] <API endpoint from Daniel>
- [ ] <Design spec from Jonathan>
- [ ] <Infrastructure from Ethan>

## Estimated Effort
- **Story Points**: <Fibonacci number>
- **Sprint**: <Sprint number>

## Priority
- [ ] Critical
- [ ] High
- [ ] Medium
- [ ] Low

## Verification Approach
<How will the assignee prove completion? E.g., build command, test command, health check, screenshots.>

## Documentation Impact
- [ ] No documentation changes needed
- [ ] BRD/SRS update needed
- [ ] API docs update needed
- [ ] User guide update needed
- [ ] README update needed

/label ~"To Do" ~"Priority::<Level>"
/milestone %"Sprint-<X>"
```

---

## 4. Bug Fix Template

**Use for**: Bugs, defects, regressions, hotfixes.

```markdown
# Bug: [BUG-XXX] <Short Description>

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

/label ~"To Do" ~"Bug" ~"Priority::<Level>"
```

---

## 5. Sprint Goal Template

**Use for**: Milestone / sprint planning in GitLab.

```markdown
# Sprint <X>: <Sprint Goal>

## Sprint Goal
<One-sentence objective. What business outcome are we trying to achieve?>

## Dates
- **Start**: <YYYY-MM-DD>
- **End**: <YYYY-MM-DD>

## Capacity
| Role | Owner | Capacity (points / days) |
|------|-------|-------------------------|
| Backend | Daniel | <X> |
| Frontend | Sophia | <X> |
| DevOps | Ethan | <X> |
| UX | Jonathan | <X> |
| QA | Olivia | <X> |

## Committed Issues
| Issue | US | Owner | Points | Status |
|-------|-----|-------|--------|--------|
| #<NNN> | US-<NNN> | <owner> | <X> | To Do |

## Dependencies & Risks
- <Dependency or risk 1>
- <Dependency or risk 2>

## Definition of Done for Sprint
- [ ] All committed issues meet [Definition of Done](#2-definition-of-done-issue-level)
- [ ] E2E smoke tests pass
- [ ] Documentation updated for shipped features
- [ ] Demo prepared for stakeholders

/milestone %"Sprint-<X>"
```

---

## 6. Post-Mortem / Retrospective Template

**Use for**: Incident post-mortems and sprint retrospectives.

```markdown
# Post-Mortem / Retrospective: <Incident or Sprint Name>

## Date
<YYYY-MM-DD>

## Participants
- <Emma>
- <Isabella>
- <Daniel/Sophia/etc.>

## Summary
<What happened? Or: what went well / what didn't go well in the sprint?>

## Impact
- **Severity**: Critical / High / Medium / Low
- **Duration**: <How long was the issue present?>
- **Affected Users / Systems**: <...>

## Timeline
| Time | Event |
|------|-------|
| HH:MM | <Event 1> |
| HH:MM | <Event 2> |

## Root Cause Analysis (post-mortem)
<5 Whys or equivalent analysis>

## What Went Well
- <...>

## What Didn't Go Well
- <...>

## Action Items
| Action | Owner | Due Date | Status |
|--------|-------|----------|--------|
| <Action 1> | <Owner> | <Date> | Open |

## Lessons Learned
<Key takeaways to apply to future work>
```

---

## Related Documentation

- `AGENTS.md` — OElite team roles and workflow chains
- [GIT-WORKFLOW-STANDARDS.md](./GIT-WORKFLOW-STANDARDS.md) — GitLab workflow and issue lifecycle
- [ISSUE-MR-TEMPLATES.md](./ISSUE-MR-TEMPLATES.md) — GitLab issue and MR templates
- [DOC-STANDARDS.md](../6_documentation_standards/DOC-STANDARDS.md) — Documentation templates

## Change History

| Date | Author | Version | Changes |
|------|--------|---------|---------|
| 2026-06-29 | Emma / Isabella | 1.0.0 | Created dedicated TASK-TEMPLATES.md from AGENTS.md workflow content |
