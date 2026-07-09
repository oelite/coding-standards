# Team Announcement: New Prohibited Implementation Patterns Standards

> **To**: All OElite Engineering Team Members (Emma, Marcus, Daniel, Sophia, Jonathan, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella)  
> **From**: Engineering Leadership  
> **Date**: 2026-07-09  
> **Subject**: 🚨 ZERO TOLERANCE: Prohibited Implementation Patterns Enforcement  
> **Reference**: `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md`

---

## 📢 IMPORTANT ANNOUNCEMENT

**Effective immediately**, the OElite engineering team is implementing **strict enforcement** of prohibited implementation patterns to ensure all code delivered to production is **production-ready, complete, and business-value delivering**.

### 🎯 Background

Recent AI-assisted merge requests have violated OElite engineering standards by including:
- Stub implementations (`NotImplementedException`, empty method bodies, TODO comments)
- Simplified implementations (happy-path only, missing validation/error handling)
- Temporary quick-fixes ("hack", "workaround", "for now" code)
- Mock/fake/placeholder data in production code

These patterns give the **illusion of functionality** without delivering actual business value, and **MUST NEVER be approved** in merge requests.

---

## 🔴 ZERO TOLERANCE POLICY

**Code reviewers (Grace, Felix, Marcus, Maya) MUST reject any MR containing prohibited patterns.**

**Approving an MR with stub/simplified/temporary/mock implementations is a CODE REVIEW FAILURE** and violates OElite engineering standards.

---

## 📋 Key Changes

### 1. New Prohibited Patterns Document

A comprehensive new document `PROHIBITED-PATTERNS.md` has been created defining:
- **4 categories of prohibited implementations** with concrete examples
- **Detection checklists** for reviewers
- **Rejection templates** for consistent feedback
- **Escalation paths** for repeated violations
- **Technology-specific examples** (.NET, Next.js, Angular)

### 2. Enhanced MR Templates

The `ISSUE-MR-TEMPLATES.md` and `TASK-TEMPLATES.md` have been updated with:
- Explicit **prohibited patterns verification checkboxes**
- **Reviewer mandate statements** requiring full implementation verification
- Clear **Definition of Done** criteria for implementation quality

### 3. Reviewer Accountability

All reviewers (Grace, Felix, Marcus, Maya) are now **explicitly accountable** for:
- Scanning for prohibited patterns before approving ANY MR
- Verifying **full implementation** of all acceptance criteria
- Rejecting MRs with stub/simplified/temporary/mock code
- Using the new **rejection template** when violations are detected

---

## ✅ Action Items by Role

### 🎯 Grace (Lead Backend Code Reviewer) & Felix (Lead Frontend Code Reviewer)

**IMMEDIATE ACTIONS:**
1. ✅ **Study `PROHIBITED-PATTERNS.md`** - Read all 4 prohibited pattern categories
2. ✅ **Update review checklists** - Add prohibited patterns detection steps
3. ✅ **Begin strict enforcement** - Reject any MR with prohibited patterns starting today
4. ✅ **Use rejection template** - When violations detected, use the standardized rejection format
5. ✅ **Schedule reviewer training** - Conduct team training session (see follow-up task below)

**Review Checklist Additions:**
```markdown
### Prohibited Patterns Check (MANDATORY)
- [ ] NO `NotImplementedException` or empty method bodies
- [ ] NO TODO/FIXME/HACK/XXX comments in production code
- [ ] NO "happy path only" implementations - all AC covered
- [ ] NO error handling gaps for async operations
- [ ] NO input validation missing for user inputs
- [ ] NO mock/fake/placeholder/hard-coded data
- [ ] NO "temporary", "workaround", "hack" comments or code
- [ ] NO commented-out code blocks
- [ ] NO disabled security/validation checks
```

### 🎯 Marcus (Principal Architect) & Maya (Security Engineer)

**UPDATE REVIEW CRITERIA:**
1. ✅ **Architecture reviews** - Include prohibited patterns check in architecture sign-off
2. ✅ **Security reviews** - Verify no disabled security checks or temporary bypasses
3. ✅ **Update review templates** - Add prohibited patterns section to your review checklists
4. ✅ **Support Grace/Felix** - Back their rejections when violations are detected

### 🎯 Daniel (Backend), Sophia (Frontend), Ethan (DevOps), Jonathan (UX), Olivia (QA), etc.

**IMPLEMENTATION STANDARDS:**
1. ✅ **Study examples** - Review prohibited vs correct examples in `PROHIBITED-PATTERNS.md`
2. ✅ **Self-review before MR** - Scan your own code for prohibited patterns before creating MRs
3. ✅ **Full implementation** - Ensure all acceptance criteria are fully implemented
4. ✅ **No "later" promises** - If you can't implement something, mark the issue BLOCKED, don't stub it

### 🎯 All Reviewers (Grace, Felix, Marcus, Maya)

**WHEN DETECTING VIOLATIONS:**

Use this rejection template:
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

### 🎯 Emma (Product & Delivery Coordinator)

**WORKFLOW UPDATES:**
1. ✅ **Update issue templates** - Ensure all new issues include implementation quality requirements
2. ✅ **Communicate to stakeholders** - Explain why "quick stubs" are not acceptable
3. ✅ **Support reviewers** - Back up rejections based on prohibited patterns
4. ✅ **Track violations** - Monitor for repeated patterns and escalate as needed

### 🎯 Isabella (Business Analyst & Documentation Lead)

**DOCUMENTATION UPDATES:**
1. ✅ **Add to onboarding docs** - Include prohibited patterns in new team member onboarding
2. ✅ **Update developer guide** - Reference `PROHIBITED-PATTERNS.md` in `docs/onboarding/developer-setup.md`
3. ✅ **Create training materials** - Work with Grace to create visual examples for training

---

## 📊 Escalation Path

**First violation**: Reviewer rejects with detailed feedback  
**Second violation**: Reviewer escalates to Marcus (architecture review required)  
**Third violation**: Emma (Product Coordinator) notified for team-wide coaching

---

## 🎓 Follow-Up: Reviewer Training Session

**A follow-up task has been created for Grace to conduct a comprehensive reviewer training session.**

**Training Session Details:**
- **Trainer**: Grace (Lead Backend Code Reviewer)
- **Audience**: All reviewers (Grace, Felix, Marcus, Maya) + implementers (Daniel, Sophia, Ethan)
- **Duration**: 60 minutes
- **Format**: Live session with code examples and Q&A
- **Materials**: `PROHIBITED-PATTERNS.md`, real MR examples (anonymized)

**Training Agenda:**
1. **Introduction** (5 min) - Why this matters, recent violations
2. **Pattern Deep Dive** (20 min) - Walk through all 4 prohibited categories with examples
3. **Detection Techniques** (10 min) - IDE search strategies, code review tips
4. **Rejection Process** (10 min) - How to use the rejection template, escalation path
5. **Live Examples** (10 min) - Review real (anonymized) MRs with violations
6. **Q&A** (5 min) - Address questions and concerns

**Expected Outcome**: All reviewers confident in detecting and rejecting prohibited patterns; all implementers understand expectations for production-ready code.

---

## 📚 Reference Materials

- **Primary Document**: `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md`
- **MR Template**: `coding-standards/5_git_workflow_standards/ISSUE-MR-TEMPLATES.md`
- **Task Template**: `coding-standards/5_git_workflow_standards/TASK-TEMPLATES.md`
- **AGENTS.md**: Updated role definitions with explicit prohibited patterns detection

---

## ✅ Success Metrics

We will measure success by:
- **0% approval rate** of MRs with prohibited patterns (target: zero approvals)
- **100% reviewer compliance** with prohibited patterns detection (all reviewers using checklists)
- **Reduced rework** - Fewer MR revisions due to incomplete implementations
- **Improved code quality** - All merged code is production-ready from day one

---

## 🚀 Moving Forward

This is not about being "hard on reviewers" or "picky about code" — this is about **delivering real business value** and **maintaining the highest engineering standards**.

**Every line of code we approve represents a commitment to our stakeholders.** Stub implementations, simplified logic, and temporary fixes break that commitment.

**From today forward:**
- ✅ Reviewers: Reject prohibited patterns without hesitation
- ✅ Implementers: Deliver complete, production-ready code
- ✅ All: Support each other in maintaining OElite's quality bar

**Together, we build excellence.**

---

## 📧 Questions or Concerns?

If you have questions about:
- **What constitutes a prohibited pattern** → Read `PROHIBITED-PATTERNS.md` Section 1-4
- **How to reject an MR properly** → Use the rejection template above
- **Escalation process** → Contact Grace (first), Marcus (second), Emma (third)
- **Training session scheduling** → Wait for Grace's follow-up task

---

**This announcement takes effect immediately.** All MRs created after 2026-07-09 are subject to prohibited patterns enforcement.

**Thank you for your commitment to OElite's engineering excellence.**

---

*This announcement is part of OElite's continuous improvement initiative to maintain the highest code quality standards across the platform.*
