# Frontend Design — Aesthetic Principles, Design Tokens & Shadcn/ui Mastery

> **Skill ID:** `frontend-design`
> **Owner:** Sophia (Frontend Implementation)
> **Default loaders:** Sophia, Felix
> **On-demand loaders:** Jonathan, Isabella
> **Status:** active
> **Issue:** #21 (US-021)
> **Sister skills:** `ux-design` (#20, Jonathan — usability & WCAG) — **load together for user-facing features**
> **Canonical reference:** `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md`

---

## 1. Mission & When to Load

### Purpose
Give every frontend-capable agent (Sophia, Felix) and any agent writing UI code the
visual, structural, and design-system knowledge to produce code that is
**visually premium, brand-consistent, design-system-compliant** — without a
human designer re-polishing every PR.

### Load this skill when the request matches any of:
- **Component**: "add a button", "build a modal", "create a card", "show a toast", "drawer", "table", "form"
- **Styling**: "style this", "make it pretty", "spacing", "shadow", "border", "background"
- **Shadcn**: "shadcn", "shadcn/ui", "components/ui", "extend the button", "new variant"
- **Design tokens**: "design tokens", "CSS variables", "theme", "color", "primary color", "dark mode"
- **Spacing**: "spacing", "padding", "margin", "gap", "4px grid", "8px grid"
- **Typography**: "font", "text size", "heading", "weight", "line height", "type scale"
- **Responsive**: "responsive", "mobile", "breakpoint", "tablet", "desktop", "container query"
- **Animation**: "animation", "transition", "motion", "hover", "micro-interaction", "skeleton"
- **Tailwind**: "tailwind", "utility class", "className", "arbitrary value", "rounded-[12px]"
- **Color**: "color", "hex", "HSL", "contrast", "destructive", "muted", "primary"
- **Visual QA**: "visual review", "design fidelity", "brand consistency", "looks generic", "premium feel"

### When NOT to load
- Pure backend / API work with no UI
- Non-OElite stacks (other than as reference for principles)
- Pure UX research / usability (load `ux-design` instead — or in addition)
- Infrastructure / DevOps work

---

## 2. OElite Design Aesthetic Philosophy

> **The goal:** code that a human designer would sign off on without a single revision.

### 2.1 The Design Language — "Luxury Minimalism, Restrained Confidence"

OElite is **not** generic Bootstrap. **Not** stock Material. **Not** Tailwind UI defaults.
The look is:

- **Luxury minimalism** — generous whitespace, restrained decoration, confident typography
- **Visual hierarchy** — clear focus, clear secondary, clear tertiary. Never flat. Never busy.
- **Subtle depth** — shadows that *imply* elevation, not scream it. One elevation tier per region.
- **Precise alignment** — 4px / 8px grid adherence. Optical alignment over mathematical.
- **Restrained motion** — purposeful, never decorative, accessibility-aware (`prefers-reduced-motion`).
- **Brand-consistent** — a recognisable OElite feel across every product: dark-mode-first, deep neutrals, accent of restrained color, generous line-height.

### 2.2 The Six Principles (Mandate)

| # | Principle | What it means | How it shows up in code |
|---|-----------|---------------|-------------------------|
| 1 | **Hierarchy over decoration** | Use size, weight, and spacing to communicate. Never decoration alone. | `text-3xl font-semibold tracking-tight` not `text-xl text-blue-500 underline` |
| 2 | **Whitespace is content** | Empty space is a design decision, not a default. | `space-y-8`, `py-12`, container max-widths with `mx-auto` |
| 3 | **One accent at a time** | Use `--primary` sparingly. Restrained color = premium feel. | One `Button` per region is `default`; everything else is `outline` or `ghost` |
| 4 | **Depth via shadow, not border** | Use `shadow-sm/md/lg` to imply elevation. Avoid heavy borders everywhere. | Cards use `shadow-sm`; modals use `shadow-lg`; inputs use `border` only |
| 5 | **Motion is feedback, not flair** | Animate to confirm an action, not to entertain. | 150–200ms `ease-in-out`. Never bounce. Never spin. |
| 6 | **Dark mode is the default** | OElite ships dark-mode-first. Light mode is a respected alternate. | `globals.css` is dark by default; the `.dark` class toggles, not the other way around |

### 2.3 Anti-Patterns (BANNED — the "AI Slop" Look)

| Anti-pattern | Why it's banned | What to do instead |
|--------------|----------------|---------------------|
| Rainbow gradient text | Reads as 2018 SaaS, screams "AI default" | Use `--primary` on a single word, or no color |
| Stock illustrations (unsplash) | Generic, breaks brand cohesion | Use Lucide icons + `Skeleton` for loading |
| Busy multi-color backgrounds | Destroys hierarchy, induces eye fatigue | One `bg-background` + one `bg-card` for layered surfaces |
| `shadow-2xl` on every card | Looks theatrical, not premium | `shadow-sm` on cards; `shadow-lg` reserved for modals/dropdowns |
| `hover:scale-105` on every button | Feels toy-like; ignores accessibility | Use `hover:bg-primary/90` for feedback |
| Emoji as icons | Inconsistent rendering, breaks brand | `lucide-react` only |
| Multi-color status badges | Visual noise | `Badge` with one of: `default` / `secondary` / `destructive` / `outline` |
| Inline `style={{ ... }}` | Bypasses the design system | Tailwind utilities, or `className` via `cn()` |
| Decorative `bg-gradient-to-r from-purple-500 to-pink-500` | The single most recognizable AI tell | Use semantic tokens; gradients only for data-viz if needed |

---

## 3. Design Token Mastery (MANDATORY)

> **Hard rule:** Every color, spacing value, radius, shadow, and transition MUST be a design token.
> No `#3b82f6`. No `p-[13px]`. No `text-[#fff]`. Ever.

### 3.1 Color Tokens (HSL CSS variables)

OElite theme is **HSL-channel** (not raw HSL) so Tailwind can compose alpha (`/10`, `/20`).
All values are defined in `src/app/globals.css` and mapped in `tailwind.config.ts`.

| Token | CSS variable | Tailwind class | Semantic usage |
|-------|--------------|----------------|----------------|
| Background | `--background` | `bg-background` | App/page background |
| Foreground | `--foreground` | `text-foreground` | Body text on background |
| Card | `--card` | `bg-card` | Elevated surface (cards, panels) |
| Card Foreground | `--card-foreground` | `text-card-foreground` | Text on cards |
| Popover | `--popover` | `bg-popover` | Floating surfaces (menus, popovers) |
| Popover Foreground | `--popover-foreground` | `text-popover-foreground` | Text in popovers |
| Primary | `--primary` | `bg-primary` / `text-primary` | **Sparingly** — primary action, brand emphasis |
| Primary Foreground | `--primary-foreground` | `text-primary-foreground` | Text on primary-filled elements |
| Secondary | `--secondary` | `bg-secondary` | Secondary surfaces, muted chips |
| Secondary Foreground | `--secondary-foreground` | `text-secondary-foreground` | Text on secondary |
| Muted | `--muted` | `bg-muted` | Subtle backgrounds (table headers, code blocks) |
| Muted Foreground | `--muted-foreground` | `text-muted-foreground` | De-emphasized text (captions, helper) |
| Accent | `--accent` | `bg-accent` | Hover state backgrounds, focus rings |
| Accent Foreground | `--accent-foreground` | `text-accent-foreground` | Text on accent |
| Destructive | `--destructive` | `bg-destructive` | Destructive actions, errors |
| Destructive Foreground | `--destructive-foreground` | `text-destructive-foreground` | Text on destructive |
| Border | `--border` | `border-border` | Hairline borders, dividers |
| Input | `--input` | `border-input` | Form input borders (slightly stronger than border) |
| Ring | `--ring` | `ring-ring` | Focus ring color (always 2px on focus-visible) |
| Radius | `--radius` | `rounded-{sm,md,lg}` | Border radius (see §3.4) |

**Dark mode** is the default; the `.dark` class on `<html>` re-defines all of the above.
Never hard-code a color; never use `dark:` to override a hex value.

### 3.2 Spacing Tokens (4px base, Tailwind scale)

| Token | Value | Common use |
|-------|-------|------------|
| `p-0` / `m-0` | 0px | Reset only |
| `p-1` | 4px | Hairline gaps (icon-to-text within a button) |
| `p-2` | 8px | Tight padding (chip, badge) |
| `p-3` | 12px | Compact padding (small card, dense list) |
| `p-4` | 16px | Default padding (card content, button vertical) |
| `p-6` | 24px | Section padding (modal content, panel) |
| `p-8` | 32px | Card / form padding (comfortable) |
| `p-12` | 48px | Hero section padding, top-of-page |
| `p-16` | 64px | Marketing-level whitespace |
| `p-24` | 96px | Page-level vertical rhythm (rare) |

**Rule of thumb:** if you need a value that isn't on the scale, you're either using
the wrong scale step or the design is wrong. Use the closest scale value; never invent
a new one with `p-[13px]`.

### 3.3 Typography Tokens

| Token | Class | Size | Use |
|-------|-------|------|-----|
| Display | `text-4xl` | 36px / 2.25rem | Hero, marketing |
| H1 | `text-3xl` | 30px / 1.875rem | Page title |
| H2 | `text-2xl` | 24px / 1.5rem | Section header |
| H3 | `text-xl` | 20px / 1.25rem | Card title |
| H4 | `text-lg` | 18px / 1.125rem | Sub-section |
| Body | `text-base` | 16px / 1rem | Default body (NEVER go below) |
| Small | `text-sm` | 14px / 0.875rem | Helper, caption, dense list |
| Extra small | `text-xs` | 12px / 0.75rem | Label, metadata, badge |

**Font weights:** `font-normal` (400), `font-medium` (500), `font-semibold` (600), `font-bold` (700).
Headings: `font-semibold` or `font-bold`. Body: `font-normal`. Buttons: `font-medium`.

**Line height:** `leading-tight` (1.25) for headings, `leading-normal` (1.5) for body,
`leading-relaxed` (1.625) for marketing prose.

**Letter spacing:** `tracking-tight` (-0.025em) on display/H1, default elsewhere,
`tracking-wider` (0.05em) only on uppercase labels.

### 3.4 Radius Tokens

| Token | Value | Use |
|-------|-------|-----|
| `rounded-sm` | `calc(--radius - 4px)` | Badges, chips |
| `rounded-md` | `calc(--radius - 2px)` | Buttons, inputs (default) |
| `rounded-lg` | `--radius` | Cards, modals |
| `rounded-xl` | `calc(--radius + 4px)` | Hero surfaces |
| `rounded-full` | 9999px | Avatars, circular icons |

### 3.5 Shadow Tokens

| Token | Use |
|-------|-----|
| `shadow-sm` | Cards, subtle elevation |
| `shadow` | Default (rare — prefer `shadow-sm` or `shadow-md`) |
| `shadow-md` | Popovers, dropdowns |
| `shadow-lg` | Modals, sheets, drawers |
| `shadow-xl` | Reserved (avoid) |
| `shadow-none` | Explicit no-shadow (e.g., in flat lists) |

**Rule:** One shadow per region. Cards are `shadow-sm`. Modals are `shadow-lg`. Don't stack.

### 3.6 Transition Tokens

| Token | Use |
|-------|-----|
| `transition-all` | Most UI (color + opacity + transform) |
| `transition-colors` | Color-only (hover, focus) |
| `transition-opacity` | Fade in/out (modals, tooltips) |
| `transition-transform` | Scale/translate (rare) |
| `duration-150` | Snappy feedback (button press) |
| `duration-200` | Default (hover, focus) |
| `duration-300` | Page transition (slow, deliberate) |
| `ease-in-out` | Default easing |

**Always pair with `prefers-reduced-motion`:** see §8.

### 3.7 BANNED Patterns (Hard No)

```tsx
// ❌ BANNED — hard-coded hex
<div className="bg-[#3b82f6] text-[#ffffff]">

// ❌ BANNED — arbitrary pixel value for spacing
<div className="p-[13px] gap-[7px]">

// ❌ BANNED — arbitrary radius
<div className="rounded-[14px]">

// ❌ BANNED — inline style with hex
<div style={{ color: '#333', padding: '13px' }}>

// ❌ BANNED — Tailwind palette (bg-blue-500) instead of semantic
<button className="bg-blue-500 text-white">

// ✅ CORRECT — semantic tokens, scale values
<div className="bg-primary text-primary-foreground p-4 rounded-md">
```

The exception: data-viz (charts) where you need a discrete color scale — then document
the palette in `tailwind.config.ts` and use it deliberately.

---

## 4. Shadcn/ui Component Library (MANDATORY)

> **Hard rule:** If Shadcn has it, you use it. You do not build your own.
> Reference: `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md` § UI Library Policy.

### 4.1 Decision Flow

```
Need a UI component?
│
├─ Does Shadcn have it? (See catalog §4.2)
│   │
│   ├─ YES → Import from @/components/ui/
│   │         If styling beyond className/asChild is needed,
│   │         edit the Shadcn component file directly (it's
│   │         copy-paste code you own).
│   │
│   └─ NO → Does a Radix UI primitive cover it?
│            │
│            ├─ YES → Use @radix-ui/* with Shadcn composition patterns.
│            │
│            └─ NO → Does a third-party lib fit (TanStack Table, Recharts, date-fns)?
│                     │
│                     ├─ YES → Use that lib.
│                     │
│                     └─ NO → Build minimal custom; document why no Shadcn fits.
```

### 4.2 Component Catalog

#### Button

**When:** Any clickable action. Always.

| Variant | Use |
|---------|-----|
| `default` | Primary action (one per region) |
| `secondary` | Less prominent actions |
| `destructive` | Delete, remove, irreversible |
| `outline` | Secondary action with more visual weight |
| `ghost` | Tertiary action, minimal visual weight |
| `link` | Inline link styled as button |

**Sizes:** `sm`, `default` (h-10), `lg`, `icon` (square).

**Anti-patterns:**
- ❌ Custom `<button className="...">` (use `Button`)
- ❌ `<a>` styled as a button (use `<Button asChild><a>...</a></Button>`)
- ❌ Two `default` buttons in the same row (use one `default` + one `outline` or `ghost`)

**Loading state pattern:**
```tsx
<Button disabled={isLoading}>
  {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
  Save changes
</Button>
```

**With icon pattern:**
```tsx
<Button>
  <Plus className="mr-2 h-4 w-4" />
  Add item
</Button>
```

**asChild pattern (for navigation):**
```tsx
<Button asChild>
  <Link href="/dashboard">Go to dashboard</Link>
</Button>
```

#### Input / Textarea / Label / Form

**Always use react-hook-form + zod + Shadcn `<Form>`.** Never raw `<form onSubmit>`.

```tsx
const form = useForm<z.infer<typeof schema>>({
  resolver: zodResolver(schema),
});

<Form {...form}>
  <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
    <FormField
      control={form.control}
      name="email"
      render={({ field }) => (
        <FormItem>
          <FormLabel>Email</FormLabel>
          <FormControl>
            <Input type="email" placeholder="you@example.com" {...field} />
          </FormControl>
          <FormDescription>We'll never share your email.</FormDescription>
          <FormMessage />
        </FormItem>
      )}
    />
    <Button type="submit">Submit</Button>
  </form>
</Form>
```

**Anti-patterns:** Raw `<input className="...">`, manual `useState` for form values, no schema validation.

#### Select / Combobox

| Need | Use |
|------|-----|
| Pick from 3–10 known options | `<Select>` |
| Pick from many options, or needs search | `<Combobox>` (Command + Popover) |
| Pick from a date/time | `<Calendar>` / `<DatePicker>` |
| Toggle a single option on/off | `<Switch>` |
| Pick 0/1 of N mutually exclusive | `<RadioGroup>` |
| Pick 0+ of N independent | `<Checkbox>` |

**Anti-pattern:** raw `<select>` (inaccessible, unstyled, breaks theme).

#### Dialog / Sheet / Drawer / Popover / Command

| Need | Use |
|------|-----|
| Modal blocking action (confirm, form) | `<Dialog>` |
| Side-anchored panel (filters, details) | `<Sheet>` |
| Bottom-anchored panel (mobile-first action) | `<Drawer>` |
| Floating menu / non-modal info | `<Popover>` |
| Command palette / search | `<Command>` |
| Hover-only hint (no click) | `<Tooltip>` |
| Rich hover content | `<HoverCard>` |

**Anti-patterns:** Custom modal with `<div className="fixed inset-0">`, raw `<dialog>`, alert() / confirm().

#### Table / DataTable

**Plain static table:** use Shadcn `<Table>` (not raw `<table>`).
**Sortable/filterable/paginated table:** wrap with TanStack Table.

```tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
```

**Anti-pattern:** raw `<table className="border">` — unstyled, unaccessible, breaks theme.

#### Card

**Always use `<Card>` with its sub-components.** Never bare `<div className="border rounded-lg">`.

```tsx
<Card>
  <CardHeader>
    <CardTitle>Card title</CardTitle>
    <CardDescription>Optional description</CardDescription>
  </CardHeader>
  <CardContent>Main content here.</CardContent>
  <CardFooter className="flex justify-end gap-2">
    <Button variant="outline">Cancel</Button>
    <Button>Confirm</Button>
  </CardFooter>
</Card>
```

#### Toast / Sonner

**Use Sonner for toasts.** (It's the Shadcn-recommended toast library.)

| Use case | Variant |
|----------|---------|
| Success confirmation | `toast.success("Saved")` |
| Error | `toast.error("Failed to save")` |
| Info | `toast.info("Heads up")` |
| Loading → success | `toast.promise(saveFn(), { loading: "...", success: "...", error: "..." })` |

**Anti-pattern:** Custom toast component, alert() for success messages, error banner that doesn't disappear.

#### Tabs / Accordion / Collapsible

- **Tabs:** switch between views of related content (Settings tabs).
- **Accordion:** stack collapsible sections (FAQ).
- **Collapsible:** single togglable region (Advanced options).

**Anti-pattern:** Custom tab implementation with `useState` + manual class toggling.

#### Alert / AlertDialog / Badge

- **Alert:** inline status communication (info banner in a page).
- **AlertDialog:** modal confirmation for destructive actions (Delete account?).
- **Badge:** tiny status label (Active, Pending, Failed).

**Anti-pattern:** `<div className="bg-yellow-100 text-yellow-800 px-2 py-1 rounded">` as a Badge.

#### Avatar / Checkbox / RadioGroup / Switch / Slider / ScrollArea / Progress / Skeleton

- **Avatar:** `lucide-react` fallback icons or initials. Always.
- **Checkbox/RadioGroup:** use with `<Label htmlFor>`. Never `<label>` wrapping a custom control.
- **Switch:** for boolean settings (notifications, dark mode).
- **Slider:** for numeric ranges (volume, price).
- **ScrollArea:** when content scrolls in a constrained region (modal body).
- **Progress:** determinate progress (upload, install).
- **Skeleton:** for loading states. Always combine with aria-busy on the parent.

#### Calendar / DatePicker

**Anti-pattern:** raw `<input type="date">` (inconsistent across browsers, unstyled).

```tsx
<DatePicker selected={date} onSelect={setDate} />
```

#### Tooltip / HoverCard

- **Tooltip:** short hint on hover/focus. ≤ 6 words.
- **HoverCard:** rich preview on hover (user card, link preview).

**Anti-pattern:** Tooltip that opens on click (use Popover for click-triggered content).

#### Separator / AspectRatio / Resizable

- **Separator:** horizontal/vertical divider. Use instead of `<hr>` or `<div className="border-t">`.
- **AspectRatio:** for images/video that need to maintain ratio.
- **Resizable:** for resizable split panes (advanced).

### 4.3 BANNED Component Patterns (Quick Reference)

| Never build | Use instead |
|-------------|-------------|
| Custom modal | `Dialog` or `Sheet` |
| Custom dropdown | `DropdownMenu` or `Select` |
| Custom tooltip | `Tooltip` |
| Custom toast | `Sonner` |
| Raw `<select>` | `Select` or `Combobox` |
| Raw `<table>` | `Table` (+ TanStack for data tables) |
| Raw `<input>` / `<textarea>` | `Input` / `Textarea` (inside `Form` with `FormField`) |
| Raw `<button>` | `Button` |
| Raw `<div>` as card | `Card` |
| Raw `<input type="checkbox">` | `Checkbox` |
| Raw `<input type="radio">` | `RadioGroup` |
| Raw `<input type="date">` | `DatePicker` |
| Custom tabs | `Tabs` |
| Custom accordion | `Accordion` |
| Custom avatar circle | `Avatar` |
| Custom badge | `Badge` |
| Inline `<svg>` for icons | `lucide-react` |
| Emoji as icons | `lucide-react` |

---

## 5. Spacing & Layout System

### 5.1 The 4px / 8px Base

Every spacing value in the system is a multiple of 4px. The Tailwind scale
(`p-1`=4, `p-2`=8, `p-4`=16, `p-6`=24, `p-8`=32) maps directly. Use these
and only these. Never `p-[13px]`.

### 5.2 When to Use Each Scale Step

| Step | Use |
|------|-----|
| `gap-1` / `space-x-1` | Icon-to-label inside a button or chip |
| `gap-2` / `p-2` | Tight (badges, chip) |
| `gap-3` / `p-3` | Compact (small cards, dense lists) |
| `gap-4` / `p-4` | Default (form fields, list items) |
| `gap-6` / `p-6` | Section (modal body, panel) |
| `gap-8` / `p-8` | Card interior (comfortable) |
| `gap-12` / `p-12` | Section divider (between major regions) |
| `p-16`+ | Marketing / hero |

### 5.3 Flexbox Composition Patterns

**Stack (vertical):**
```tsx
<div className="flex flex-col gap-4">{children}</div>
```

**Row (horizontal):**
```tsx
<div className="flex items-center gap-4">{children}</div>
```

**Distribute:**
```tsx
<div className="flex items-center justify-between">{children}</div>
```

**Wrap:**
```tsx
<div className="flex flex-wrap gap-2">{children}</div>
```

**Centered (single child):**
```tsx
<div className="flex items-center justify-center min-h-screen">{children}</div>
```

### 5.4 Grid Composition Patterns

**Equal columns:**
```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  {items.map(item => <Card key={item.id}>...</Card>)}
</div>
```

**Sidebar + main:**
```tsx
<div className="grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-8">
  <Sidebar />
  <main>{children}</main>
</div>
```

**Dashboard (12-col):**
```tsx
<div className="grid grid-cols-12 gap-6">
  <Card className="col-span-12 md:col-span-6 lg:col-span-4">KPI 1</Card>
  <Card className="col-span-12 md:col-span-6 lg:col-span-4">KPI 2</Card>
  <Card className="col-span-12 md:col-span-6 lg:col-span-4">KPI 3</Card>
  <Card className="col-span-12 lg:col-span-8">Chart</Card>
  <Card className="col-span-12 lg:col-span-4">Activity</Card>
</div>
```

### 5.5 Container

Use `<div className="container mx-auto px-4 md:px-6 lg:px-8">` for centered, responsive content.
The `container` class sets a max-width per breakpoint.

### 5.6 Common Layout Recipes

**Settings page:**
```tsx
<div className="container max-w-3xl py-8 space-y-8">
  <div>
    <h1 className="text-3xl font-semibold tracking-tight">Settings</h1>
    <p className="text-muted-foreground mt-2">Manage your account preferences.</p>
  </div>
  <Separator />
  <Card>
    <CardHeader>
      <CardTitle>Profile</CardTitle>
      <CardDescription>Update your personal information.</CardDescription>
    </CardHeader>
    <CardContent className="space-y-4">{/* form fields */}</CardContent>
  </Card>
</div>
```

**Dashboard layout (sidebar + main):**
```tsx
<div className="grid min-h-screen grid-cols-1 lg:grid-cols-[240px_1fr]">
  <aside className="border-r bg-muted/30 p-6">Sidebar</aside>
  <main className="p-6 lg:p-8">{children}</main>
</div>
```

---

## 6. Typography System

### 6.1 Font Stack

OElite apps use **Geist Sans** for body and **Geist Mono** for code, with system fallbacks.
Configuration is in `src/app/layout.tsx` via `next/font/google` (or `@vercel/geist`).

```tsx
import { GeistSans } from 'geist/font/sans';
import { GeistMono } from 'geist/font/mono';

<body className={`${GeistSans.variable} ${GeistMono.variable} font-sans`}>
```

**Tailwind mapping (in `tailwind.config.ts`):**
```ts
fontFamily: {
  sans: ['var(--font-geist-sans)', 'system-ui', 'sans-serif'],
  mono: ['var(--font-geist-mono)', 'ui-monospace', 'monospace'],
}
```

### 6.2 Heading Hierarchy

| HTML | Class | When |
|------|-------|------|
| `<h1>` | `text-3xl md:text-4xl font-semibold tracking-tight` | Page title (one per page) |
| `<h2>` | `text-2xl font-semibold tracking-tight` | Section header |
| `<h3>` | `text-xl font-semibold` | Card title, sub-section |
| `<h4>` | `text-lg font-semibold` | Sub-sub-section |
| `<h5>` | `text-base font-semibold` | Group label |
| `<h6>` | `text-sm font-semibold uppercase tracking-wider text-muted-foreground` | Tiny label (rare) |

**Never skip levels** (h1 → h3). Screen readers and SEO depend on it.

### 6.3 Body Text

| Context | Class |
|---------|-------|
| Default paragraph | `text-base leading-normal` |
| Long-form prose | `text-base leading-relaxed max-w-prose` |
| Helper / caption | `text-sm text-muted-foreground` |
| Code | `font-mono text-sm` |
| Numbers (tabular) | `font-mono tabular-nums` (or `font-variant-numeric: tabular-nums`) |

### 6.4 Lists

```tsx
<ul className="list-disc space-y-2 pl-6 text-muted-foreground">
  <li>Item one</li>
  <li>Item two</li>
</ul>
```

### 6.5 Truncation

For inline truncation, use `truncate` (single line) or `line-clamp-{n}` (multi-line, requires `@tailwindcss/line-clamp`).

---

## 7. Color System

### 7.1 Semantic vs Decorative

**Semantic (use these):**
- `bg-primary` / `text-primary` / `text-primary-foreground` — for emphasis
- `bg-card` / `text-card-foreground` — for elevated surfaces
- `bg-muted` / `text-muted-foreground` — for de-emphasized content
- `bg-destructive` / `text-destructive` — for errors, destructive actions
- `border-border` — for hairlines
- `ring-ring` — for focus rings

**Decorative (rarely, deliberately):**
- Data-viz color scales (charts only)
- Brand logo (raw color is fine in the logo SVG)
- Marketing hero images (asset-level, not component-level)

**Never decorative on text.** `text-purple-500` to highlight a word is banned. Use `text-primary` or no color.

### 7.2 Dark Mode (OElite Default)

The OElite theme is **dark-mode-first**. `globals.css` defines the dark palette in `:root`,
and light mode in `.light`. This is the inverse of most Shadcn scaffolds — do not "fix" it.

```css
:root {
  --background: 222 47% 6%;        /* dark slate */
  --foreground: 210 40% 98%;
  /* ... */
}

.light {
  --background: 0 0% 100%;
  --foreground: 222 47% 11%;
  /* ... */
}
```

### 7.3 Contrast Verification (WCAG 2.1 AA)

Before merging UI code, verify these combinations pass AA contrast (≥ 4.5:1 for text):

| Pair | Expected ratio |
|------|----------------|
| `text-foreground` on `bg-background` | ≥ 4.5:1 |
| `text-primary-foreground` on `bg-primary` | ≥ 4.5:1 |
| `text-muted-foreground` on `bg-background` | ≥ 4.5:1 |
| `text-card-foreground` on `bg-card` | ≥ 4.5:1 |
| `text-destructive-foreground` on `bg-destructive` | ≥ 4.5:1 |

Use a contrast-checker (e.g., WebAIM, axe-core) to verify. Felix rejects MRs that fail.

### 7.4 State Colors

Use opacity on `--primary` for state, not new colors:

```tsx
<Button className="bg-primary hover:bg-primary/90 active:bg-primary/80">
```

| State | Pattern |
|-------|---------|
| Hover | `hover:bg-primary/90` or `hover:bg-accent` |
| Focus | `focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2` |
| Active | `active:bg-primary/80` |
| Disabled | `disabled:opacity-50 disabled:pointer-events-none` (built into Shadcn) |

### 7.5 Status Colors (info / success / warning / error)

| Status | Token | Use |
|--------|-------|-----|
| Info | `--primary` (low opacity) or text-only | Informational banners |
| Success | `text-emerald-600 dark:text-emerald-400` + `bg-emerald-500/10` | Success toasts, badges |
| Warning | `text-amber-600 dark:text-amber-400` + `bg-amber-500/10` | Warning banners, badges |
| Error | `--destructive` | Errors, destructive actions |

**Note:** Success and warning use the *only* acceptable raw palette colors,
because they are status communication, not decoration.

---

## 8. Animation & Motion

### 8.1 When to Animate

**Animate:**
- Hover state on interactive elements (color change, 150ms)
- Focus state (ring appearance)
- Toast appearance / dismissal
- Modal open / close
- Skeleton → content swap
- Dropdown open / close
- Tab content cross-fade

**Don't animate:**
- Layout shifts (use Skeleton during load, not animation to settle)
- Page navigation (let the browser handle it)
- Decorative elements (logo, hero illustration)
- Multi-property transitions on critical UI (slows perceived speed)

### 8.2 Tailwind Transition Utilities

```tsx
// Hover feedback (button, link)
<Button className="transition-colors duration-200">

// Modal fade
<DialogContent className="data-[state=open]:animate-in data-[state=closed]:animate-out fade-0 zoom-95">

// Tooltip
<TooltipContent className="data-[state=delayed-open]:animate-in data-[state=closed]:animate-out fade-0 zoom-95">
```

### 8.3 Reduced Motion (MANDATORY for accessibility)

Wrap or guard every animation with `prefers-reduced-motion`:

```tsx
// Tailwind: motion-safe / motion-reduce variants
<div className="motion-safe:transition-all motion-safe:duration-200 motion-reduce:transition-none">

// Or in CSS (globals.css):
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

**Banned:** `animate-spin` on a full-page loader. Use `<Loader2 className="animate-spin">` (auto-respects reduced motion via Shadcn).

### 8.4 Skeleton Loading

Always use `<Skeleton>` for loading states. Pair with `aria-busy` and `aria-live="polite"`:

```tsx
<div aria-busy={isLoading} aria-live="polite">
  {isLoading ? (
    <div className="space-y-2">
      <Skeleton className="h-4 w-[250px]" />
      <Skeleton className="h-4 w-[200px]" />
    </div>
  ) : (
    <p>{content}</p>
  )}
</div>
```

**Banned:** spinner-only loaders with no content preview, blank screens during fetch.

---

## 9. Responsive Design (Mobile-First)

### 9.1 Breakpoints

| Prefix | Min width | Device |
|--------|-----------|--------|
| (none) | 0 | Mobile (default) |
| `sm:` | 640px | Large phone, small tablet |
| `md:` | 768px | Tablet |
| `lg:` | 1024px | Laptop, small desktop |
| `xl:` | 1280px | Desktop |
| `2xl:` | 1536px | Large desktop |

**Mobile-first:** write the mobile class first, then layer on larger breakpoints with prefixes.

```tsx
// ✅ Mobile-first
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">

// ❌ Desktop-first (works but bigger bundle, harder to reason about)
<div className="grid grid-cols-3 md:grid-cols-2 sm:grid-cols-1">
```

### 9.2 Touch Targets

All interactive elements MUST have a hit area of **at least 44×44px** (WCAG 2.5.5).

```tsx
// Buttons meet this by default (h-10 = 40px, h-11 for icon buttons)
// For inline links or icon-only buttons, add padding:
<Button variant="ghost" size="icon" className="h-11 w-11">
  <Plus />
</Button>
```

### 9.3 Navigation Patterns

| Breakpoint | Pattern |
|------------|---------|
| Mobile (< 768px) | Bottom nav bar (4–5 items max) OR hamburger menu |
| Tablet (768–1024px) | Collapsible sidebar (icons only, expand on hover) |
| Desktop (≥ 1024px) | Persistent sidebar (full labels) |

### 9.4 Content Prioritization

Mobile screens have less room. Hide or collapse secondary content:

```tsx
<div className="flex items-center gap-2">
  <Avatar />
  <div className="hidden sm:block">
    <p className="text-sm font-medium">{name}</p>
    <p className="text-xs text-muted-foreground">{email}</p>
  </div>
</div>
```

### 9.5 Responsive Type

Headings scale down on mobile:

```tsx
<h1 className="text-2xl md:text-3xl lg:text-4xl font-semibold tracking-tight">
```

### 9.6 Container Queries (Advanced)

For component-level responsiveness (e.g., a card that changes layout based on its own width, not viewport):

```tsx
<div className="@container">
  <div className="@md:flex @md:items-center @md:gap-4">
    {/* ... */}
  </div>
</div>
```

Requires `@tailwindcss/container-queries` plugin.

---

## 10. Before / After Examples

> The fastest way to internalize these rules: see the bad code, see the fix.

### Example A: Custom Modal → Shadcn Dialog

❌ **BEFORE — hand-rolled modal:**
```tsx
function MyModal({ isOpen, onClose, children }: MyModalProps) {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center">
      <div className="bg-white rounded-lg p-6 w-full max-w-lg shadow-2xl">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-lg font-semibold">Confirm</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">✕</button>
        </div>
        {children}
      </div>
    </div>
  );
}
```

**Problems:**
- No focus trap → keyboard users escape
- No `escape` key handler
- No `aria-modal`, `role="dialog"`, `aria-labelledby`
- Inline `bg-white` (light-mode only, breaks dark mode)
- `shadow-2xl` is excessive
- Manual `if (!isOpen) return null` (no exit animation)

✅ **AFTER — Shadcn Dialog:**
```tsx
import {
  Dialog, DialogContent, DialogDescription, DialogFooter,
  DialogHeader, DialogTitle, DialogTrigger,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';

<Dialog>
  <DialogTrigger asChild>
    <Button variant="outline">Open dialog</Button>
  </DialogTrigger>
  <DialogContent className="sm:max-w-lg">
    <DialogHeader>
      <DialogTitle>Confirm action</DialogTitle>
      <DialogDescription>This action cannot be undone.</DialogDescription>
    </DialogHeader>
    <div className="py-4">{/* content */}</div>
    <DialogFooter>
      <Button variant="outline">Cancel</Button>
      <Button>Confirm</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

**Gains:** focus trap, escape key, ARIA attributes, exit animation, dark mode, design tokens.

---

### Example B: Inline-Styled Div as Button → Shadcn Button

❌ **BEFORE:**
```tsx
<div
  onClick={handleSave}
  className="inline-flex items-center justify-center rounded-md bg-blue-500 text-white px-4 py-2 cursor-pointer hover:bg-blue-600"
>
  Save
</div>
```

**Problems:**
- Not focusable → keyboard users can't activate
- No `role="button"`, no `tabIndex`
- No disabled state
- `bg-blue-500` (raw palette, not semantic)
- No loading state

✅ **AFTER:**
```tsx
<Button onClick={handleSave} disabled={isSaving}>
  {isSaving && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
  Save
</Button>
```

**Gains:** native focus, ARIA, disabled handling, loading state, semantic color, spinner built-in.

---

### Example C: Hard-Coded Hex → Semantic Token

❌ **BEFORE:**
```tsx
<div className="bg-[#1e293b] border border-[#334155] text-[#f1f5f9]">
  <h3 className="text-[#60a5fa]">Dashboard</h3>
  <p className="text-[#94a3b8]">Welcome back, user.</p>
</div>
```

**Problems:**
- 5 hard-coded hex values
- Breaks the moment the theme changes
- No dark mode switching
- Inconsistent with the rest of the app

✅ **AFTER:**
```tsx
<Card>
  <CardHeader>
    <CardTitle>Dashboard</CardTitle>
    <CardDescription>Welcome back, user.</CardDescription>
  </CardHeader>
</Card>
```

**Gains:** every color is a semantic token, dark mode works for free, theming is centralized.

---

### Example D: Non-Responsive Layout → Mobile-First Grid

❌ **BEFORE:**
```tsx
<div className="flex justify-between gap-4">
  <div className="w-1/3 bg-white p-4">Sidebar</div>
  <div className="w-2/3 bg-white p-4">Main content</div>
</div>
```

**Problems:**
- 33% / 66% on mobile = sidebar is too narrow, content overflows
- No stacking on mobile
- Raw `bg-white` (breaks dark mode)
- Fixed widths prevent responsiveness

✅ **AFTER:**
```tsx
<div className="grid grid-cols-1 lg:grid-cols-[240px_1fr] gap-6 p-4 lg:p-8">
  <aside>
    <Card><CardContent className="p-4">Sidebar</CardContent></Card>
  </aside>
  <main>
    <Card><CardContent className="p-4">Main content</CardContent></Card>
  </main>
</div>
```

**Gains:** stacks on mobile, fixed sidebar width on desktop, semantic surface, responsive padding.

---

### Example E (Bonus): No Loading State → Skeleton + ARIA

❌ **BEFORE:**
```tsx
{isLoading ? <p>Loading...</p> : <UserList users={users} />}
```

**Problems:**
- Layout shift when content arrives
- Screen readers don't announce the content update
- "Loading..." is non-specific

✅ **AFTER:**
```tsx
<div aria-busy={isLoading} aria-live="polite">
  {isLoading ? (
    <div className="space-y-2">
      {Array.from({ length: 5 }).map((_, i) => (
        <Skeleton key={i} className="h-12 w-full" />
      ))}
    </div>
  ) : (
    <UserList users={users} />
  )}
</div>
```

**Gains:** no layout shift, screen readers announce the update, content shape is previewed.

---

### Example F (Bonus): Inline Style → Tailwind + cn()

❌ **BEFORE:**
```tsx
<div
  style={{
    backgroundColor: '#f9fafb',
    padding: '16px',
    borderRadius: '8px',
    border: '1px solid #e5e7eb',
  }}
>
```

✅ **AFTER:**
```tsx
<div className={cn('bg-muted/30 p-4 rounded-lg border border-border')}>
```

**Gains:** themeable, responsive, no inline-style risk, Tailwind tree-shakeable.

---

## 11. Common Anti-Patterns Catalog (Self-Check)

Before committing, scan your diff for these. Felix will reject any that remain.

| # | Anti-pattern | Banned? | Fix |
|---|--------------|---------|-----|
| 1 | Hard-coded hex / hsl in `className` or `style` | ❌ BANNED | Use semantic tokens (`bg-primary`, `text-foreground`) |
| 2 | Arbitrary Tailwind values (`p-[13px]`, `text-[#fff]`, `rounded-[14px]`) | ❌ BANNED | Use scale (`p-3`, scale `rounded-md`) |
| 3 | Custom `<button>`, `<input>`, `<select>`, `<table>`, `<dialog>` | ❌ BANNED | Use Shadcn `Button`, `Input`, `Select`, `Table`, `Dialog` |
| 4 | Custom modal with `<div className="fixed inset-0">` | ❌ BANNED | Use Shadcn `Dialog` or `Sheet` |
| 5 | Animation without `prefers-reduced-motion` handling | ❌ BANNED | Use `motion-safe:` / `motion-reduce:` or `@media` guard |
| 6 | Decorative gradient (`bg-gradient-to-r from-purple-500 to-pink-500`) | ❌ BANNED | Use semantic tokens; gradients only for data-viz |
| 7 | Color contrast violation (no contrast check) | ❌ BANNED | Verify with axe-core / WebAIM; aim for AA (4.5:1) |
| 8 | `text-purple-500` / `bg-blue-500` for emphasis | ❌ BANNED | Use `text-primary` / `bg-primary` |
| 9 | `style={{ ... }}` inline styles | ❌ BANNED | Use Tailwind utilities or `cn()` |
| 10 | Two `default` Buttons in the same row | ❌ BANNED | One `default` + one `outline` / `ghost` |
| 11 | Emoji as icons | ❌ BANNED | Use `lucide-react` |
| 12 | Inline `<svg>` for icons | ❌ BANNED | Use `lucide-react` |
| 13 | Raw `<form onSubmit>` without `react-hook-form` + zod | ❌ BANNED | Use `Form` + `FormField` + zod resolver |
| 14 | Raw `useState` for form values | ❌ BANNED | Use `react-hook-form` |
| 15 | `bg-white` (raw) instead of `bg-background` or `bg-card` | ❌ BANNED | Use semantic surface tokens |
| 16 | `shadow-2xl` on every card | ❌ BANNED | `shadow-sm` for cards, `shadow-lg` for modals only |
| 17 | `hover:scale-105` on every button | ❌ BANNED | Use `hover:bg-primary/90` |
| 18 | Desktop-first responsive (`grid-cols-3 sm:grid-cols-2`) | ❌ BANNED | Mobile-first: `grid-cols-1 md:grid-cols-2 lg:grid-cols-3` |
| 19 | `<div className="border rounded-lg p-4">` as a card | ❌ BANNED | Use `<Card>` |
| 20 | `text-3xl` body text | ❌ BANNED | Headings only; body is `text-base` max |
| 21 | Loading state: just `<p>Loading...</p>` | ❌ BANNED | Use `<Skeleton>` with `aria-busy` |
| 22 | Non-mobile-first layout (fixed pixel widths) | ❌ BANNED | Mobile-first; use breakpoints |
| 23 | `p-[13px]` or any arbitrary spacing | ❌ BANNED | Use Tailwind scale (`p-3` or `p-4`) |
| 24 | Stock illustrations / Unsplash random photo | ❌ BANNED | Use Lucide icons + Skeleton |
| 25 | `font-bold` on body text | ❌ BANNED | `font-normal` for body; `font-semibold` for emphasis |

---

## 12. Brand Voice in UI (Microcopy)

UI text is design. Bad microcopy is the difference between a product that feels
"thrown together" and one that feels intentional.

### 12.1 Button Labels

- ✅ Verb-first, specific, action-oriented
- ❌ Generic ("Submit", "Click here", "OK")

| ❌ | ✅ |
|----|----|
| Submit | Save changes |
| Click here | View order details |
| OK | Got it |
| Yes | Delete project |
| Cancel | Keep editing |

### 12.2 Error Messages

The formula: **What happened → Why → What to do next.**

- ❌ "Error"
- ❌ "Something went wrong"
- ✅ "Couldn't save your changes. Check your connection and try again."
- ✅ "Email already in use. Try signing in instead."
- ✅ "File too large. Max upload size is 10 MB."

### 12.3 Empty States

The formula: **What this is → Why it's empty → What to do.**

```tsx
<Card>
  <CardContent className="flex flex-col items-center gap-4 py-12 text-center">
    <Inbox className="h-12 w-12 text-muted-foreground" />
    <div>
      <h3 className="text-lg font-semibold">No projects yet</h3>
      <p className="text-sm text-muted-foreground mt-1">
        Create your first project to get started.
      </p>
    </div>
    <Button>
      <Plus className="mr-2 h-4 w-4" />
      New project
    </Button>
  </CardContent>
</Card>
```

**Never:** cute illustrations of sad faces, or "Nothing here yet!" as if the product is a child.

### 12.4 Confirmations

- ✅ "Project deleted." (past tense, specific)
- ❌ "Done!" (vague, generic)
- ❌ "Success" (jargon)

### 12.5 Helper Text

- One sentence max
- Specific, not generic
- Place below the field, in `text-sm text-muted-foreground`

```tsx
<FormItem>
  <FormLabel>Workspace URL</FormLabel>
  <FormControl>
    <Input placeholder="acme" {...field} />
  </FormControl>
  <FormDescription>Your workspace will be available at acme.oelite.app</FormDescription>
  <FormMessage />
</FormItem>
```

### 12.6 Headings & Page Titles

- Match the page's primary user intent
- Don't be cute ("Welcome to the future!")
- Do be clear ("Projects" or "Manage your projects")

---

## 13. Verification Checklist (Before MR)

Use this checklist before requesting review. Every unchecked item blocks Felix's approval.

### Design Tokens
- [ ] No hard-coded hex, hsl, or pixel values in any className or style
- [ ] All colors reference semantic tokens (background, foreground, primary, etc.)
- [ ] All spacing uses Tailwind scale values (no `p-[Npx]`)
- [ ] All radii use scale values (no `rounded-[Npx]`)
- [ ] All shadows use scale values (no arbitrary shadow classes)
- [ ] Dark mode renders correctly (toggle and verify)

### Shadcn Components
- [ ] Every interactive element uses a Shadcn component (no raw `<button>`, `<input>`, `<select>`, etc.)
- [ ] Every modal uses `<Dialog>` or `<Sheet>` (no custom modal)
- [ ] Every form uses `<Form>` + `FormField` + zod resolver
- [ ] Every table uses `<Table>` (+ TanStack if sortable/filterable)
- [ ] Every card uses `<Card>` (no bare `<div className="border rounded-lg">`)

### Accessibility
- [ ] All interactive elements have ≥ 44×44px hit area
- [ ] All images have `alt` text (or `alt=""` if decorative)
- [ ] All form fields have associated `<Label>` via `FormLabel` or `htmlFor`
- [ ] Focus states are visible (ring-2 on focus-visible)
- [ ] Color contrast passes AA (4.5:1 for text)
- [ ] All animations respect `prefers-reduced-motion`
- [ ] Loading states use `<Skeleton>` + `aria-busy` + `aria-live`

### Responsive
- [ ] Mobile layout works at 375px width (iPhone SE)
- [ ] Tablet layout works at 768px
- [ ] Desktop layout works at 1280px
- [ ] Mobile-first composition (no fixed pixel widths for layout)
- [ ] No horizontal scroll on mobile

### Motion
- [ ] Transitions use 150–200ms `ease-in-out` (or scale)
- [ ] No animation on critical-path elements
- [ ] All animation respects `prefers-reduced-motion`

### Code Quality
- [ ] `cn()` used for all `className` composition
- [ ] No `as any`, `@ts-ignore`, `@ts-expect-error`
- [ ] No mock/placeholder data
- [ ] All icons are `lucide-react`
- [ ] All text follows microcopy guidelines (verb-first buttons, specific errors)

### Build
- [ ] `npx next build` passes with 0 errors
- [ ] `npm run lint` passes
- [ ] TypeScript compilation is clean

---

## 14. Cross-References

### Internal Standards
- **Shadcn policy:** `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md` → § UI Library Policy → Shadcn Component Priority
- **Code formatting:** `coding-standards/agents/skills/formatting/SKILL.md` (issue #17) — load together for any new component
- **Architecture (component layering):** `coding-standards/agents/skills/architecture-design/SKILL.md` (issue #19)
- **UX / accessibility:** `coding-standards/agents/skills/ux-design/SKILL.md` (issue #20, Jonathan) — **load together for any user-facing feature**
- **Security (XSS, form input):** `coding-standards/agents/skills/security-design/SKILL.md` (issue #22)

### External References
- **Shadcn/ui docs:** https://ui.shadcn.com
- **Tailwind CSS:** https://tailwindcss.com
- **Radix UI primitives:** https://www.radix-ui.com/primitives
- **Lucide icons:** https://lucide.dev
- **next/font:** https://nextjs.org/docs/app/building-your-application/optimizing/fonts
- **WCAG 2.1 AA:** https://www.w3.org/WAI/WCAG21/quickref/

### Loading This Skill

In your role file's `load_skills` parameter, add:
```
load_skills: ["frontend-design", "ux-design"]
```

In OpenCode, invoke via:
```
skill(name="frontend-design")
```

---

## 15. Summary — The 10 Things to Remember

1. **Use semantic tokens, never hard-code.** (`bg-primary`, not `bg-blue-500`.)
2. **Use Shadcn, never build your own.** (Dialog, Button, Card, Table, Select, etc.)
3. **Use Tailwind scale, never arbitrary values.** (`p-4`, not `p-[13px]`.)
4. **Mobile-first responsive.** (Default = mobile, layer up with `md:`, `lg:`.)
5. **One `default` button per region.** (Everything else is `outline` or `ghost`.)
6. **Dark mode is the default.** (Don't fight it.)
7. **Animation respects `prefers-reduced-motion`.** (Always.)
8. **Loading = Skeleton + `aria-busy`, not a spinner.** (Always.)
9. **Icons = `lucide-react`, not inline SVG, not emoji.** (Always.)
10. **Microcopy is design.** (Verb-first buttons, specific errors, helpful empty states.)

---

*End of skill. Maintained by Sophia. Issues / improvements → GitLab issue tagged `frontend-design`.*
