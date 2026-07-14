# Task Pack: Frontend Implementation

## Who Loads This
Sophia (primary), Jonathan (design spec reference), Felix (code review reference)

## Standards to Read (via tools)
- `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md`
- `coding-standards/3_angular_coding_standards/11-ANGULAR-CODING-STANDARDS.md`
- `coding-standards/2_general_web_coding_standards/README.md`
- Target repo `.ai/standards/coding-standards.md` (if exists)
- Target repo `README.md`

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
- [ ] Worktree created with correct role identity
- [ ] Next owner identified and triggered
