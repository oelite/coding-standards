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
- **Status:** [ ] planned — see issue #20
- **Owner:** Jonathan

---

### `frontend-design` — Design Aesthetic, Tokens & Component Library

- **Purpose:** Frontend design aesthetic, design tokens, Shadcn/ui patterns, typography scale, brand consistency, visual QA
- **Trigger phrases:** "frontend design", "design tokens", "Shadcn", "typography", "brand", "visual QA", "UI aesthetic"
- **Default loaders:** Sophia, Felix
- **On-demand loaders:** Jonathan, Isabella
- **Location:** `coding-standards/agents/skills/frontend-design/SKILL.md`
- **Status:** [ ] planned — see issue #21
- **Owner:** Sophia

---

### `security-design` — OWASP, Threat Modeling & Pre-MR Security Checklist

- **Purpose:** OWASP Top 10 awareness, threat modeling, secure design patterns, pre-MR security checklist, and security code review guidance
- **Trigger phrases:** "security", "OWASP", "threat model", "pre-MR security", "secrets", "injection", "XSS", "CSRF", "JWT", "encryption"
- **Default loaders:** Maya
- **On-demand loaders:** Marcus, Daniel, Grace, Ethan
- **Location:** `coding-standards/agents/skills/security-design/SKILL.md`
- **Status:** [ ] planned — see issue #22
- **Owner:** Maya

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
| `visual-qa` | Visual QA | Screenshot/TUI diff, design-system check, responsive check, CJK text clipping | "visual QA", "screenshot diff", "design fidelity" |
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
