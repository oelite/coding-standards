# Task Pack: Frontend Implementation

## Who Loads This
Sophia (primary), Jonathan (design spec reference), Felix (code review reference)

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
- `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md`
- `coding-standards/3_angular_coding_standards/11-ANGULAR-CODING-STANDARDS.md`
- `coding-standards/2_general_web_coding_standards/README.md`
- `coding-standards/agents/packs/ux-design.md` (Jonathan's design spec for reference)
- Target repo `.ai/standards/coding-standards.md` (deviation-only — skip unless repo is in AGENTS.md STANDARDS AUTHORITY §2)
- Target repo `README.md`

## Skills to Load
- `load_skills: ["frontend-design", "design-system", "ui-usability", "ux-design", "security-design"]` — frontend-design for design tokens, Shadcn patterns, typography, responsive, animation, brand consistency, and consumer-media anatomy (§9.7); design-system for canonical ecosystem design defaults (typography, color tokens, spacing, journeys, dashboard patterns); ui-usability for pre-design analysis (§1), playbooks (§3), and validation strategy (§4) — the forces behind every implementation rule below; ux-design for WCAG/heuristic detail; security-design for auth/PII/payment patterns.

## Implementation Standards
- Use the correct stack per app:
  - Next.js 16.2 + React 19 + Shadcn/ui + Tailwind CSS 4 + Lucide React (default)
  - Angular 12/15/17 + Bootstrap/Material (legacy apps)
  - MAUI for mobile
- **Shadcn/ui component priority**: check `components/ui/` first; use existing Shadcn components instead of custom HTML/hand-written styles
- `lucide-react` icons only — no inline SVGs or icon fonts
- `globals.css` with Shadcn CSS variables, `tailwind.config.ts` extending them
- `next/font` with type scale: Inter (body), JetBrains Mono (code)
- Shared `Typography` component
- `cn()` utility for all `className` composition
- Design tokens only — no arbitrary Tailwind values
- Server components by default; `'use client'` only when needed

## No-Mock-Data Policy (Zero Tolerance)
- Never ship fake/placeholder/hard-coded data
- Start empty, load from real API
- Render explicit loading/empty/error states
- If API missing → mark task BLOCKED and document required endpoints

## Data Integration
- Use real backend API clients
- SWR / TanStack React Query / fetch-based OElite API clients
- Handle loading, error, empty states
- Respect auth guards and role-based access

## Testing Requirements
- `npx next build` / `ng build` must pass
- `npm run lint` must pass
- **E2E**: Playwright tests mandatory for all web apps
- E2E prerequisites: dev server running + Docker containers healthy

## Code Review Gates (Felix)
- No mock/placeholder data
- No duplicated style code when theme tokens exist
- No `any` types
- Accessibility: ARIA labels, keyboard navigation, focus management, WCAG AA
- Performance: lazy loading, code splitting, image optimization
- Implementation matches Jonathan's design spec

## Handoff Target
- Jonathan (UX review) + Felix (code review) [parallel] → Build verify → Olivia (E2E) → Ethan (deploy) → Isabella (docs + biz validation)

## Verification Checklist
- [ ] `npx next build` / `ng build` succeeds with 0 errors
- [ ] `npm run lint` passes
- [ ] No mock/placeholder data
- [ ] Loading/empty/error states implemented
- [ ] Uses Shadcn/ui components where applicable
- [ ] Theme tokens consistent
- [ ] Accessibility audit passes (Lighthouse ≥ 90)
- [ ] **Visual QA evidence — user-facing UI ships with rendered screenshots**: attach screenshots of every user-facing surface in its primary states (default/populated, loading, empty, error; minimum mobile breakpoint) to the handoff/MR. Screenshot mechanism is IDE-agnostic — your IDE's visual QA tooling (e.g., OpenCode's built-in `visual-qa` skill as one example), Playwright capture, or browser devtools all satisfy this; the capability is mandatory, the tool is not. Text-only handoffs for user-facing UI are rejected.
- [ ] **API-to-UI shape mapping included** (ui-usability §1): data-bound surfaces carry the field map from served API contract → UI surface in the MR description
- [ ] Worktree created with correct role identity
- [ ] Next owner identified and triggered
