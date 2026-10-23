# OElite Skills Registry

> **Source of Truth** for every loadable skill in the OElite agent platform.
> Each skill is a portable, self-contained capability following the
> OpenAgentSkill/agentskills.io `SKILL.md` format. Any role loads a skill via
> the `skill` tool or `load_skills` parameter in task delegations.
>
> **Non-negotiable rule:** Every new cross-cutting capability MUST be created as
> a skill, not duplicated in role files. Role files reference skills via
> `load_skills`; they do NOT inline skill content.

---

## 📋 How to Read This Registry

| Field | Description |
|-------|-------------|
| **ID** | Unique skill identifier (kebab-case, used in `load_skills`) |
| **Purpose** | One-line summary of what the skill provides |
| **Trigger phrases** | User/agent phrases that should auto-load this skill |
| **Default loaders** | Roles that should always load this skill (via `load_skills` in task()) |
| **On-demand loaders** | Roles that may load it when the trigger phrase fires |
| **Location** | Path to the skill's `SKILL.md` file |
| **Status** | `[ ] planned` = folder exists, awaiting content; `[x] active` = SKILL.md exists with real content |

---

## 🏗️ OElite Skills (coding-standards/agents/skills/)

---

### `formatting` — Code Formatting Standard

- **Purpose:** JetBrains-based formatting standard for .NET/C# projects
- **Trigger phrases:** "format this code", "apply formatting", "run formatter", "fix formatting", "lint"
- **Default loaders:** Daniel, Grace
- **On-demand loaders:** All roles when working on .NET/C# code
- **Location:** `coding-standards/agents/skills/formatting/SKILL.md`
- **Status:** [ ] planned — see issue #17
- **Owner:** Emma

---

### `architecture-design` — Architecture Patterns & Trade-off Analysis

- **Purpose:** Software architecture patterns, ADRs, system design, trade-off analysis, and OElite framework compliance guidance
- **Trigger phrases:** "architecture", "system design", "trade-off", "ADR", "layer violation", "pattern", "refactor architecture"
- **Default loaders:** Marcus
- **On-demand loaders:** Daniel, Sophia, Grace, Felix, Emma
- **Location:** `coding-standards/agents/skills/architecture-design/SKILL.md`
- **Status:** [x] active — see issue #19
- **Owner:** Marcus

---

### `ux-design` — UX Design, Usability Heuristics & WCAG

- **Purpose:** UX design principles, Nielsen's usability heuristics, WCAG accessibility, interaction patterns, and user research guidance
- **Trigger phrases:** "UX", "usability", "heuristics", "WCAG", "accessibility", "user flow", "interaction pattern"
- **Default loaders:** Jonathan
- **On-demand loaders:** Sophia, Felix, Isabella
- **Location:** `coding-standards/agents/skills/ux-design/SKILL.md`
- **Status:** [x] active — see issue #20
- **Owner:** Jonathan

---

### `frontend-design` — Design Aesthetic, Tokens & Component Library

- **Purpose:** OElite design aesthetic, design tokens, Shadcn/ui patterns, typography scale, brand consistency, anti-pattern catalog, before/after examples
- **Trigger phrases:** "frontend design", "design tokens", "Shadcn", "typography", "brand", "visual QA", "UI aesthetic", "styling", "component", "responsive", "animation", "spacing", "color"
- **Cross-load:** for UI feature work, load `ui-usability` (#73) together — implementation patterns apply after pre-design analysis and playbook selection.
- **Default loaders:** Sophia, Felix
- **On-demand loaders:** Jonathan, Isabella
- **Location:** `coding-standards/agents/skills/frontend-design/SKILL.md`
- **Status:** [x] active — see issue #21
- **Owner:** Sophia
- **Sister skill:** `ux-design` (#20, Jonathan) — **load together for any user-facing feature**; `frontend-design` covers the visual/structural layer, `ux-design` covers usability, WCAG, and interaction patterns

---

### `design-system` — Canonical Ecosystem Design Principles (Typography, Color, Spacing, Journeys)

- **Purpose:** Ecosystem-wide canonical design defaults — font stacks & type scale, semantic color tokens (light/dark), 4px spacing grid, component behavior, mandatory async state triad, user-journey practices, dashboard patterns (KPI cards, tabular numerals), motion, and the per-project override policy
- **Trigger phrases:** "new UI", "dashboard design", "styling", "design tokens", "typography", "fonts", "color system", "user journey", "empty state", "KPI card", "spacing grid", "dark mode", "design principles"
- **Default loaders:** Jonathan, Sophia, Felix
- **On-demand loaders:** Emma, Isabella, any role touching UI/UX
- **Cross-load:** for UI feature work, load `ui-usability` (#73) together — it supplies the pre-design thinking this skill's values are applied to.
- **Location:** `coding-standards/agents/skills/design-system/SKILL.md`
- **Status:** [x] active — see issue #70
- **Owner:** Jonathan
- **Related skills:** `ux-design` (#20) and `frontend-design` (#21) — load together for any user-facing feature; `design-system` sets the ecosystem defaults they implement and review against

---

### `ui-usability` — Professional UI Usability: Pre-Design Thinking, Playbooks & Validation Strategy

- **Purpose:** The usability THINKING layer applied before any UI work — mandatory pre-design analysis (users/task/data/decisions + screen-type classification with anti-CRUD gate), feature-type playbooks (CRUD / Business Workflow / Dashboard / Operator Console), applied Nielsen heuristics, validation & error-prevention strategy, in-product guidance, and a measurable reviewer/QA usability checklist
- **Trigger phrases:** "UI design", "new feature UI", "usability review", "is this CRUD", "form validation", "approval flow", "error messages", "empty states", "user workflow", "how should this screen work"
- **Default loaders:** Jonathan, Sophia, Olivia, Felix
- **On-demand loaders:** Emma, Isabella
- **Location:** `coding-standards/agents/skills/ui-usability/SKILL.md`
- **Status:** [x] active — see issue #73
- **Owner:** Jonathan
- **Related skills & layering:** `design-system` (#70) = the VALUES layer (tokens, typography, async states) · **`ui-usability` (this) = the THINKING layer (analysis before building)** · `frontend-design` (#21) = the IMPLEMENTATION layer (Shadcn patterns, aesthetic) · `ux-design` (#20) = WCAG/heuristic detail reference. Load together for any user-facing feature.

---

### `security-design` — OWASP Top 10, Threat Modeling & Pre-MR Security Checklist

- **Purpose:** OWASP Top 10 (2025) awareness, threat modeling (STRIDE), secure coding patterns for auth/authz/validation/secrets, pre-MR security checklist (40+ items), dependency security, GDPR/PII handling, and security audit framework for AI agents
- **Trigger phrases:** "auth", "permission", "secret", "token", "input validation", "encrypt", "PII", "GDPR", "vulnerability", "OWASP", "CVE", "rate limit", "audit log", "injection", "XSS", "CSRF", "JWT", "threat model", "STRIDE"
- **Default loaders:** Maya
- **On-demand loaders:** Marcus, Daniel, Sophia, Grace, Ethan, Olivia (for test-security requirements)
- **Location:** `coding-standards/agents/skills/security-design/SKILL.md`
- **Status:** [x] active — see issue #22
- **Owner:** Maya
- **Related skills:** `architecture-design` (#19) — load together for security architecture reviews; complements `agents/packs/security.md`

---

### `requirements-authority` — Factual Requirements Governance

- **Purpose:** Protect approved BRDs, SRSs, rulebooks, user stories, journeys, and process flows from implementation-status churn; scope context to cited requirements
- **Trigger phrases:** "update requirements", "edit BRD", "edit SRS", "change user story", "business rulebook", "requirements conflict", "requirements audit", "user journey requirements"
- **Default loaders:** None (keep universal context concise)
- **On-demand loaders:** Isabella, Emma, and any role changing/reviewing factual requirements
- **Location:** `coding-standards/agents/skills/requirements-authority/SKILL.md`
- **Status:** [x] active — issue #40
- **Owner:** Isabella
- **Canonical detailed policy:** `coding-standards/6_documentation_standards/REQUIREMENTS-AUTHORITY.md`

---

### `business-change-impact` — Emma→Isabella Impact-Analysis Gate

- **Purpose:** Mandatory two-phase gate for business changes: Emma analyses product change + implied logic and advises Isabella on documentation impact BEFORE development; Isabella revisits documentation accuracy AFTER development, before Emma closes the issue
- **Trigger phrases:** "business change", "feature request", "new feature", "change business logic", "change workflow", "documentation impact", "impact analysis", "update BRD", "update SRS", "UI change", "user-facing change", "what else changes if we do this"
- **Default loaders:** Emma, Isabella
- **On-demand loaders:** Marcus, Jonathan, Daniel, Sophia, Olivia, Grace, Felix (when their work reveals a factual-requirements impact)
- **Location:** `coding-standards/agents/skills/business-change-impact/SKILL.md`
- **Status:** [x] active — issue #54
- **Owners:** Emma (gate orchestration) + Isabella (documentation execution)
- **Related skills:** `requirements-authority` (#40) — load together whenever a factual requirement may need amending

---

### `emma-continuous-orchestration` — Emma Continuous Orchestration Subagent

- **Purpose:** Emma as a continuously-running subagent: watches for new business-change/feature requests, runs the Emma→Isabella impact-analysis gate (Phase 1 + Phase 2) end-to-end for each request, delegates implementation to best-fit roles, tracks progress, runs retrospective goal review, and closes only after MR merge verified + issue closed in same session
- **Trigger phrases:** "emma continuous", "emma orchestration", "run emma as subagent", "continuous orchestration", "durable mission", "mission loop", "keep monitoring", "keep progressing", "full completion of original goals", "delegate to roles", "assign best-fit roles", "sequence dependencies", "monitor worktree", "monitor MR", "track progress to done", "retrospective goal review", "original request achieved", "mission state", "mission ledger", "orchestration state"
- **Default loaders:** Emma
- **On-demand loaders:** Marcus, Jonathan, Daniel, Sophia, Olivia, Ethan, Maya, Victor, Grace, Felix, Isabella (when the continuous loop hands off to them or reports mission state)
- **Location:** `coding-standards/agents/skills/emma-continuous-orchestration/SKILL.md`
- **Status:** [x] active — issue #56
- **Owner:** Emma (continuous orchestration loop)
- **Related skills:** `business-change-impact` (#54) — the Phase 1 + Phase 2 gate this skill operationalizes continuously; `requirements-authority` (#40) — load together whenever a factual requirement may need amending

---

## 🔧 Built-in OpenCode Skills (Available via `skill` Tool)

These skills are built into the OpenCode CLI and accessible via the `skill` tool or
`load_skills` in task() delegations. They are NOT managed in `coding-standards/agents/skills/`
— they ship with OpenCode itself.

| Skill ID | Name | Purpose | Trigger Phrases |
|----------|------|---------|-----------------|
| `playwright` | Playwright Browser Automation | Browser automation, verification, web scraping, E2E testing, screenshots | "playwright", "browser", "e2e", "screenshot", "web scraping" |
| `frontend` | Frontend Design & Polish | UI/UX construction, React, styling, animation, Core Web Vitals, accessibility | "frontend", "UI", "React", "styling", "design", "visual QA" |
| `git-master` | Git Mastery | Atomic commits, rebase, squash, history search, blame, bisect | "commit", "rebase", "squash", "git history", "blame", "who wrote" |
| `review-work` | Post-Implementation Review | 5-agent parallel review: goal verification, code quality, security, QA execution, context mining | "review work", "review my changes", "QA my work", "verify implementation" |
| `remove-ai-slops` | AI Slop Cleanup | Remove 10 categories of AI-generated code smells with regression tests | "remove slop", "clean AI code", "deslop", "clean up AI-generated" |
| `init-deep` | Deep Context Initialization | Initialize hierarchical AGENTS.md knowledge base | "init deep", "initialize knowledge base" |
| `debugging` | Runtime Debugging | Hypothesis-driven debugging loop for crashes, hangs, memory leaks, async issues | "debug", "why is X not working", "hanging", "attach debugger" |
| `security-research` | Security Research (Team Mode) | 5-agent parallel: 3 vulnerability hunters + 2 PoC engineers, exploitability audit | "security research", "security review", "vulnerability audit" |
| `security-review` | Security Review (Team Mode) | Alias for `security-research` | Same as above |
| `visual-qa` | Visual QA (**OpenCode example — IDE-agnostic capability**) | Screenshot/TUI diff, design-system check, responsive check, CJK text clipping. **This entry is an example implementation, not a requirement to use OpenCode**: visual QA is a mandatory capability for user-facing UI on ANY IDE/toolchain — Playwright screenshot capture, browser devtools, or another IDE's equivalent tooling satisfies it equally | "visual QA", "screenshot diff", "design fidelity" |
| `team-mode` | Team Orchestration | Create and manage parallel agent teams | "team", "parallel agents", "orchestrate" |
| `context7-mcp` | Context7 Documentation | Fetch up-to-date library/framework docs for React, Next.js, Prisma, Express, etc. | "React docs", "Next.js", "Prisma", "Express", "how to use X" |

---

## 🚀 How to Create a New Skill

1. **Check the registry first.** If the capability already exists (even as planned), add your
   use case to the existing entry rather than creating a duplicate.
2. **Create the folder:**
   ```
   coding-standards/agents/skills/<skill-id>/
   ```
3. **Create `SKILL.md`** following this minimal template:

   ```markdown
   # <Skill Name>

   ## Purpose
   One-line summary of what this skill provides.

   ## When to Load
   - Default loaders: roles that should always load this
   - On-demand triggers: phrases that auto-load this skill

   ## Standards & Rules
   [Detailed content — conventions, patterns, anti-patterns, examples]

   ## Verification
   [How to verify this skill's standards are being followed]
   ```

4. **Register the skill** in this `SKILLS.md` registry with all required fields.
5. **Update role files** to reference the skill via `load_skills` instead of inlining content.

---

## 📝 Registry Maintenance

- Add new skills to this registry when they are created
- Update `Status` field: `[ ] planned` → `[x] active` when the SKILL.md is filled
- Update `Default loaders` / `On-demand loaders` as patterns emerge
- Remove entries only when a skill is deprecated (leave a tombstone note)
