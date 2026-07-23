# Task Pack: Frontend Review

## Who Loads This
Felix (primary), Jonathan (UX/design fidelity review)

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
- `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md`
- `coding-standards/agents/packs/ux-design.md` (for Jonathan: UX fidelity review)
- Target repo `.ai/standards/coding-standards.md` (if exists)

## Review Dimensions

### Felix: Code Quality / Theme / TypeScript / Performance
- `npx next build` / `ng build` succeeds with 0 errors
- `npm run lint` passes (no TS/ESLint errors)
- No `any` types; proper type definitions for props/API responses
- Shadcn/ui component priority respected
- Theme tokens used (no arbitrary Tailwind values, no hex/rgb in `className`)
- `cn()` utility used for all `className` composition
- No duplicated style code
- Accessibility: ARIA labels, semantic HTML, keyboard navigation, focus management, WCAG AA
- Performance: lazy loading, code splitting, image optimization, memoization
- No mock/placeholder/hard-coded data
- All interactive states implemented (hover, focus, active, disabled, loading, empty, error)

### Jonathan: Design Fidelity
- Implementation matches approved design spec across breakpoints
- Interaction states (hover/transition/error/empty) correct
- Responsive behavior per spec
- Accessibility requirements met

## Prohibited Patterns (Reject)
- Mock/fake/placeholder/hard-coded data
- Custom components when Shadcn/ui component exists in `components/ui/`
- Hex/rgb colors or arbitrary Tailwind values instead of tokens
- Missing `next/font` / typography system
- Missing theme configuration (`globals.css`, `tailwind.config.ts`)
- Stub/simplified/temporary implementations
- Client components without `'use client'` (Next.js)

## Verification Checklist
- [ ] Build clean (0 errors)
- [ ] Lint passes
- [ ] Theme compliance verified
- [ ] Accessibility audit passes (Lighthouse ≥ 90)
- [ ] No mock data
- [ ] Design spec matched
- [ ] Specific fixes provided for any rejection

## Failure Report Format
- Exact files/lines needing changes
- Expected vs actual behavior
- Severity: blocker / warning
- Reference to relevant standard

## Handoff Target
- Build verify → Olivia (E2E) → Ethan (deploy) → Isabella (docs + biz validation)
