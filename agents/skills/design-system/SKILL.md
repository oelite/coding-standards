# Design System — Canonical OElite Ecosystem Design Principles

> **Skill ID:** `design-system`
> **Owner:** Jonathan (UX Design)
> **Default loaders:** Jonathan, Sophia, Felix
> **On-demand loaders:** Emma, Isabella, any role touching UI/UX
> **Status:** active
> **Issue:** #70 (TASK-UX)
> **Sister skills:** `ux-design` (#20 — usability heuristics & WCAG details) and `frontend-design` (#21 — Shadcn implementation patterns & visual aesthetic) — **load together for any user-facing feature**
>
> **Canonicality:** This skill is the **ecosystem-wide default** for fonts, color tokens, spacing, component behavior, journeys, and dashboard patterns. Per-project overrides are governed by §11 (Project Override Policy). Stray per-doc font/color values elsewhere in `coding-standards/` are superseded by this skill.

---

## Purpose

One canonical source for OElite design quality so dashboards and apps stop shipping with inconsistent fonts, ad-hoc colors, unconsidered states, and broken user journeys. Every value below is an ecosystem default: use it unless a documented, application-driven override exists (§11).

## When to Load

- **Default loaders:** Jonathan (all design work), Sophia (all frontend implementation), Felix (all frontend review)
- **On-demand triggers:** "new UI", "new dashboard", "dashboard design", "styling", "design tokens", "typography", "fonts", "color system", "user journey", "empty state", "KPI card", "design principles", "spacing grid", "dark mode", "accessibility spec"
- Load together with `ux-design` + `frontend-design` for any user-facing feature.

---

## Standards & Rules

### 1. Typography (Canonical Font Stacks)

**Product UI (first choice — self-hosted, never via public CDN):** `Inter`, self-hosted via `@fontsource/inter` (npm/CLI) or `next/font` (Next.js). Do not load fonts from CDN `<link>` tags (privacy, offline builds, CSP strictness).

```css
/* Canonical UI stack */
font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
  'Helvetica Neue', Arial, sans-serif;

/* Canonical code / IDs / metrics stack */
font-family: ui-monospace, 'JetBrains Mono', 'SF Mono', Consolas, monospace;
```

- **font-display:** `swap` on every `@font-face`.
- **Allowed weights:** `400` (regular), `500` (medium), `600` (semibold), `700` (bold) only. Body/paragraph: 400. Emphasis, buttons, labels: 500. Headings & emphasis: 600. Number-one-per-page hero titles may use 700. **Forbidden: 300 and 800+** (thin weights fail contrast on tinted surfaces; extrabold reads shouty).
- This supersedes any other font recommendation in legacy docs — including the stray `Roboto` pairing in older Next.js examples.

**Type scale (rem-based, ~1.25 modular steps per breakpoint; 16px root):**

| Token | rem | px | Line-height | Use |
|-------|-----|----|-------------|-----|
| `text-xs` | 0.6875rem | 11px | 1.45 | Micro labels, badge text, table footers — not body copy |
| `text-sm` | 0.75rem | 12px | 1.45 | Captions, helper text, metadata, dense table cells |
| `text-base` | 0.875rem | 14px | 1.5 | **Dashboard default body**, table body, form text |
| `text-md` | 1rem | 16px | 1.5 | Marketing/long-form body, settings page body |
| `text-lg` | 1.25rem | 20px | 1.3 | Card titles, panel headings, H4 |
| `text-xl` | 1.5rem | 24px | 1.25 | Section headings, H3/H2 |
| `text-2xl` | 2rem | 32px | 1.2 | Page titles, H1 (one per view) |

- Scale is deliberately compact (no 36px+/display step in product UI — those belong to marketing surfaces only).
- Headings: `line-height` tight (1.2–1.3); body: 1.5.
- **Letter-spacing:** `tracking-tight` (≈ −0.02em) only on ≥24px headings; default spacing everywhere else; `tracking-wider` (≈ +0.04em) only on uppercase overline labels.
- **NUMERALS RULE (non-negotiable for dashboards):** `font-variant-numeric: tabular-nums` on ALL numeric columns in tables, KPI card values, metric tiles, prices, counters, and time displays. Proportional figures make columns of numbers jitter and misalign decimal points — never acceptable in data UI. Humanist sans numerals may be used ONLY inside prose sentences.

### 2. Color System (Semantic Tokens)

Colors are **never** hard-coded hex/rgb/artist-palette names. Every view consumes semantic CSS variables (light + dark sets defined in `:root`/`[data-theme='dark']` or Shadcn `globals.css`):

| Token | Light default (guideline) | Dark default (guideline) | Usage |
|-------|--------------------------|--------------------------|-------|
| `--bg` | near-white, hue-neutral gray | near-black, same hue family | Page background |
| `--surface` | pure white / slightly raised | raised dark gray | Cards, panels, sheets |
| `--surface-2` | subtle tint | deeper tint | Secondary surfaces, table headers |
| `--primary` | ONE brand accent | same accent (adjusted lightness) | Primary actions, active states, focus |
| `--secondary` | neutral or desaturated complement | same | Secondary actions, chips |
| `--success` | green ramp step | same | Positive status, confirmations |
| `--warning` | amber ramp step | same | Degraded/attention states |
| `--danger` | red ramp step | same | Errors, destructive actions |
| `--info` | blue ramp step | same | Informational states |
| `--border` / `--border-strong` | subtle / stronger hairline | same | Dividers, input borders |
| `--text-1` | primary text color | primary text color | Titles, body text |
| `--text-2` | muted | muted | Secondary text, captions |
| `--text-3` | faintest readable | faintest readable | Placeholders, disabled text |

**Neutral gray ramp:** one 10–12-step neutral ramp (e.g. `gray-50…gray-950`, HSL 220–240 hue or pure neutral) defines surface/border/text steps — derive the semantic tokens FROM it; never sample ad-hoc grays from screenshots.

- **One accent rule:** exactly ONE `--primary` brand accent per product. Status colors (success/warning/danger/info) are communication, not decoration, and are the only non-neutral accents.
- **Light + dark mode both required:** define every token for both modes via CSS variables. Components must not branch on theme (`dark:` overrides on raw hex are banned; flip the token).
- **Contrast (WCAG AA):** body text ≥ 4.5:1; large text (≥18.66px bold or ≥24px) and UI boundaries (icons, borders on interactive elements) ≥ 3:1. Verify with axe-core or WebAIM before merge.
- **Never invent per-project hex values.** If a color exists outside the token set, it is either a bug or a §11 override request.

Shadcn mapping: `--bg`→`--background`, `--surface`→`--card`, `--text-1`→`--foreground`, `--text-2`→`--muted-foreground`, `--border`→`--border`, `--danger`→`--destructive`. Register success/warning/info as first-class tokens in every new app.

### 3. Spacing & Layout

- **Base grid: 4px.** Use only 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64. Any value between grid steps (`13px`, `18px`) is banned; snap to the nearest step or rethink.
- **Density rhythm:** inside components 8–12; between components in a region 16–24; between page regions 24–32; page chrome 32–64.
- **Max content width:** dashboards/tables 1200–1400px (`max-w-[1400px]`), centered with gutter; forms/settings 560–720px; long-form reading ~65ch.
- **Radii scale:** `sm` 4px (badges, inline elements) · `md` 6px (inputs, buttons) · `lg` 8px (cards, panels) · `xl` 12px (modals, drawers) · `full` (avatars, pills). One radius tier per surface region; nested elements use `inner ≤ outer`.
- **Elevation (subtle, max 1 per region):** level-1 cards `0 1px 2px rgba(0,0,0,.06)`; level-2 dropdowns/popovers `0 4px 12px rgba(0,0,0,.10)`; level-3 modals `0 12px 32px rgba(0,0,0,.18)`. Dark mode: elevation via lighter surface + border, not bigger shadows.
- **Breakpoints:** 320 / 640 / 768 / 1024 / 1280 / 1536 or Tailwind `sm:md:lg:xl:2xl`. Mobile-first authoring always.

### 4. Component Design Principles

- **Buttons:** exactly **ONE primary (accent-filled) button per view** (page header action or the final/primary step of a form). All others: `secondary`/`outline`/`ghost`. A distinct `danger` style is reserved for irreversible destructive actions (with §6 confirmation). Sizes: `sm` 32px / `md` 40px / `lg` 48px height; min touch target 44px on touch screens (pad invisible hit area if needed).
- **Forms:** labels **above** inputs (never placeholder-only); helper text `text-sm text-text-2`; validation **inline** next to the failing field (never only a top-of-form banner — a summary is allowed in addition, not instead); validate on blur, re-validate on change after first error; disable submit during mutation with inline progress; preserve user input on failure. Keep forms short: every field must earn its place.
- **Tables:** default + `compact` density modes (row height 48px / 36px); header row sticky within scroll container; horizontal scroll allowed on mobile with first column pinned where practical; **pagination for admin/data pages** (virtual scroll only >10k rows or real-time feeds — measured, not assumed); right-align numeric columns, left-align text columns; row actions ≤3 visible + overflow menu; column sort on header click; selection via checkbox + bulk-action bar replacing pagination while selected.
- **Cards:** one heading + optional one-line description + content + footer actions right-aligned (secondary → primary). Cards are the unit of scan; avoid nesting cards.
- **Navigation:** primary sidebar on desktop (collapsible, icons persist), bottom tab bar (4–5 destinations) or drawer on mobile; active state unambiguous (accent + weight, not just color); breadcrumb required ≥2 levels deep.
- **Empty states:** every list/table/dashboard region defines its empty state (see §5) — message + illustration/icon + primary CTA; never blank, never "undefined".

### 5. State Design (Required Checklist Item)

Every async view (page, tab, table, card, chart) MUST define all three, and reviewers reject implementations that ship only the success state:

| State | Rule |
|-------|------|
| **Loading** | **Skeletons that mirror the final layout** (same shape/rhythm), never a centered spinner for page or table loads; spinners only inside buttons or ≤300ms micro-operations; pair skeletons with `aria-busy` |
| **Empty** | What/why/what-next: icon, one-line reason, one primary CTA ("No reports yet — Create your first report"); filtered-no-results distinct from no-data (offer "Clear filters") |
| **Error** | What-happened/why/what-next: specific message (not "Something went wrong"), **retry affordance** (button for full-region retry; retry link for inline partials); log handle/trace ID where meaningful for support |

Transitions between states must be instant-feeling (skeleton appears same frame as data fetch starts); never flash a skeleton over already-loaded data.

### 6. User Journey Practices

- **Task-first IA:** structure the product by the user's tasks, not internal data tables or org chart. A screen exists because a task completes there.
- **Max 2-level nav depth:** any destination ≤2 clicks/hops from top nav (sections → item); anything deeper gets navigation aids (tabs, breadcrumbs) not more dd-tree levels.
- **Progressive disclosure:** essentials visible, advanced/rarely-used options behind "Advanced" toggles, "More" links, or detail routes. Defaults must be pre-filled to the safe choice.
- **Destructive actions:** require confirmation naming the object ("Delete 'Q3 Forecast'?" — not "Are you sure?"); the confirm verb matches the action ("Delete"); high-stakes actions may additionally require typing the object name. Offering undo beats confirmation where technically feasible.
- **Predictable placement patterns:** global search top-right; dialog close (X) top-right of dialog; primary page header bottom-right on mobile (thumb zone), top-right on desktop; risk-side null: never move these per-panel.
- **Minimize form length:** single-column; break only along clear task steps; group into fieldsets ≤6–8 fields; pre-fill from context; accept paste; never split last name/first name across separate fields if a single fullName works.
- **Optimistic UI:** for safe, idempotent mutations (like, pin, archive-item, mark-read) update immediately and roll back with an inline error + retry on failure; for consequential mutations (payments, deletions, permission grants) use optimistic feedback only with server confirm; show pending state on the item, not an app-blocking modal.
- Journey coverage: happy path must be navigable by keyboard-only users, and each permission role only sees the branches it can reach (dead ends are journey bugs).

### 7. Accessibility (WCAG 2.1 AA Minimum)

- Contrast per token table (§2) verified programmatically (axe-core / Lighthouse a11y ≥90, both).
- **Visible focus:** every focusable element shows a `focus-visible` ring ≥2px at ≥3:1 contrast, using `--focus` token (default = primary) — never `outline: none` without a replacement.
- **Keyboard:** full reachability; no traps; skip-to-content first tab stop; modals focus-trap + ESC + focus return; menus/tabs arrow-key navigable; disclosure state announced.
- **Touch targets:** ≥44×44px, ≥8px between adjacent targets.
- **Semantics:** native element before ARIA; ARIA dual complete (modern Landmarks: header/nav/main/complementary/footer); `aria-live="polite"` status region per page for toasts/results; form errors tied via `aria-describedby` + `aria-invalid`.
- **Text:** 200% zoom usable without loss of content or function; reflow at 320px no horizontal clipping (except chart legends / tables with horizontal scroll affordance).
- **Motion:** ALL animation behind `prefers-reduced-motion` (cross-fade instead of slide/scale; disable autoplay; keep opacity transitions).
- Meaningful `alt` on images; empty `alt=''` on decorative; icon-only buttons require `aria-label`.

### 8. Motion

| Duration | Use |
|----------|-----|
| **150ms** | Color/opacity feedback (hover, focus, press), tooltips in/out |
| **250ms** | Component entrance/exit (dropdown, popover, toast, modal close), skeleton pulse |
| **350ms** | Layout transitions — modal/drawer/sheet open, panel expand/collapse, view cross-fade |

- **Easing:** `ease-out` default (arrival should feel fast, settle graceful); `ease-in-out` for positional symmetrical transitions; never `ease-in` for entrances, never `linear` for UI motion, never bounce/elastic in product UI.
- **Cage rules:** no parallax; no scroll-hijack; nothing decorative moves on dashboards; hover transitions on class-color/no layout animation; chart animations ≤300ms and never loop; spinners may rotate (rotation is functional).
- Everything reduced to opacity-only ≤150ms under `prefers-reduced-motion`.

### 9. Dashboard-Specific Patterns

**KPI card anatomy (canonical):**

```
┌───────────────────────────────┐
│ Revenue (text-sm text-2)      │  ← label, sentence case, truncate not shrink
│ 1,204,556 (text-xl tabular)   │  ← value: biggest numeral, tabular-nums
│ ▲ 12.4% vs last month         │  ← delta: direction prefix + % + compare basis
└───────────────────────────────┘
```

- Delta chip: `success/danger` color + `▲/▼` + `%` + explicit compare basis (label the baseline or the metric is meaningless).
- **Tabular alignment:** numbers right-aligned (headings included); text left-aligned; status badges column left-aligned with fixed width; DO NOT center-align anything in a data column.
- **Number/date formatting standards:** locale-aware `Intl.NumberFormat`/`date-fns` — monetary with 2 decimals; counts with thousands separators; percents with 1 decimal; dates `MMM DD` (short) / `MMM DD, YYYY` (long) with TOOLTIP full ISO/relative ("3 days ago") for recency columns; always UTC-consistent server data, render in user's timezone; never re-format mid-column (column-level consistency beats row-level).
- **Density:** KPI rows 3–4 cards max on desktop; degree of detail below fold; sticky page header (title + primary action) so long dashboards never lose the primary CTA.
- Cards own their concern: one metric per KPI card (value + delta + sparkline); a card that needs sub-values becomes a panel, not a taller KPI card.
- Charts: single hue ramp from `--primary` for series; status colors only for semantic (danger for error-rate); axes labeled; values readable without hover on printed/exported contexts.

### 10. State Design & Review Hooks

Every state/task checklist in `packs/frontend-impl.md` / `frontend-review.md` / `packs/ux-design.md` inherits §5 (loading/empty/error), §7 (a11y), and the tabular-numerals rule as hard checklist rows. Reviewers: a dashboard shipping a new numeral column without `tabular-nums`, or a new async view without all three async states, is blocked at review regardless of visual polish.

### 11. Project Override Policy

The ecosystem default is "no override". Projects MAY override ONLY for **documented application-driven reasons**:

- Legitimate reasons: standing brand identity (own font/color system mandated by legal/brand), embedded context (widget inside a host product with foreign chrome), hardware/display constraint, regulatory requirement, or audience-specific need (e.g., accessibility-critical high-contrast app).
- HOW to override:
  1. Declare it in the repo (README or `docs/` design section) — name each deviation, the values used, and the reason.
  2. **Do not fork the global token NAMES.** Keep the same semantic tokens (`--bg`, `--primary`, `--text-1`, …) and change only VALUES, so cross-repo tooling/reviews keep working.
  3. Colors and typography stay ecosystem defaults **unless justified** (brand identity is the typical justification; "we already had Bootstrap colors" is not).
  4. Non-negotiable even under override: tabular-nums rule, WCAG AA contrast, 44px touch targets, visible focus rings, three-state (loading/empty/error) async views, per-§6 confirmation for destructive actions, and `prefers-reduced-motion` handling.
- Legacy-framework repos (Angular Bootstrap, occ MUI) map these principles onto their existing variables; they do not owe a port to Shadcn tokens, but they owe the behavioral rules.

---

## Verification

Before MR, the author self-checks; Felix (frontend-review) enforces:

- [ ] Fonts are `Inter` + JetBrains Mono (or documented §11 override), self-hosted, `display: swap`, weights limited to 400/500/600/700
- [ ] Type scale uses the token set (§1); no sub-11px text; headings tracking-tight only ≥24px
- [ ] `tabular-nums` on every numeric table column, KPI value, metric, and counter
- [ ] Zero hard-coded colors/radii/shadows/spacing; all via semantic tokens with light+dark values
- [ ] Exactly one primary button per view; destructive actions confirmed with object-specific wording
- [ ] Every async view has designed loading (skeletons mirroring layout), empty (icon + reason + CTA), error (specific message + retry) states
- [ ] WCAG 2.1 AA: axe-core clean; focus rings visible; keyboard-complete flow; targets ≥44px; `prefers-reduced-motion` honored
- [ ] Motion limited to 150/250/350ms `ease-out` (or reduced-motion fallback); no parallax/dashboard animation beyond state feedback
- [ ] Dashboard: numerals right-aligned, locale-`Intl` formatting, labeled compare baselines, KPI cards follow canonical anatomy
- [ ] Any §11 override is documented in the target repo with reasons, preserves token names, and keeps governing rules intact

Suspicion of drift between this skill and another doc? This file wins for ecosystem defaults; file a GitLab issue tagged `design-system` to reconcile the other doc.
