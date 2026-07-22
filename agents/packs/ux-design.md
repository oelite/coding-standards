# Task Pack: UX Design

## Who Loads This
Jonathan (primary), Sophia (design spec reference), Felix (design fidelity review reference)

## Standards to Read (via tools)
- `coding-standards/4_react_nextjs_coding_standards/12-NEXTJS-CODING-STANDARDS.md` (UI Library Policy, Mobile-First, Typography, Theme)
- `coding-standards/3_angular_coding_standards/11-ANGULAR-CODING-STANDARDS.md` (legacy app design patterns)
- `coding-standards/2_general_web_coding_standards/README.md`
- `coding-standards/agents/core/principles.md` (Frontend Stack, Shadcn/ui priority)
- Target repo `.ai/standards/design-standards.md` (if exists)
- Target repo `README.md` (app-specific theming)

---

## 1. Design Process and Deliverables

### 1.1 Pre-Design Briefing (MANDATORY)
Before any design work begins, Jonathan MUST receive a business context briefing from Emma (product) and Marcus (architecture):

| Input | Source | Purpose |
|-------|--------|---------|
| Business requirements | Emma (BRD/SRS) | Understand what the business needs |
| Business rules and logic | Marcus | Understand constraints, validation rules, state machines |
| User roles and permissions | Marcus | Design role-based UI adaptation |
| Expected behaviors | Emma | Define interaction flows |
| Edge cases and error flows | Emma + Marcus | Design error states, empty states, boundary conditions |
| API contracts | Marcus | Know data shapes for wireframes |
| Success criteria | Emma | Define acceptance criteria for UX |

### 1.2 Required Design Deliverables

Every feature with frontend impact MUST produce ALL of the following before Sophia starts implementation:

| Deliverable | Format | Description |
|-------------|--------|-------------|
| User Journey Map | Markdown document | Step-by-step user flow across pages, including decision points, branching, error recovery paths |
| Wireframes / Layout Spec | Mermaid diagram or visual mockup | Page layout, component placement, information hierarchy |
| Navigation Flow | Mermaid state diagram | Page-to-page transitions, redirects, modal triggers |
| Interaction State Spec | Text table | All states per component: default, hover, focus, active, disabled, loading, empty, error, success |
| Responsive Behavior Spec | Breakpoint table | How layout adapts at each breakpoint (mobile to tablet to desktop) |
| Accessibility Spec | Checklist | WCAG 2.1 AA requirements per component: ARIA roles, keyboard navigation, focus management, color contrast, screen reader announcements |
| Error and Edge Case Spec | Table | Failure modes: API error, validation error, network timeout, empty response, permission denied |

### 1.3 Approval Gate
All design deliverables MUST be approved by:
1. Emma (product) - verifies design meets business requirements and user needs
2. Marcus (architecture) - verifies design is technically feasible and aligns with API contracts

No Sophia implementation work begins until design approval is documented.

---

## 2. Mobile-First Design Standards (MANDATORY)

### 2.1 Design Breakpoints

All designs MUST be authored for mobile-first. Layouts start from the smallest viewport and scale up.

| Breakpoint | Width | Design Target | Layout Behavior |
|------------|-------|---------------|-----------------|
| Mobile | 320px - 639px | Primary design target | Single column, stacked layout, bottom navigation, touch-friendly targets (min 44px) |
| Mobile Large | 640px - 767px | Enhanced mobile | Wider single column, split cards possible |
| Tablet | 768px - 1023px | Secondary design target | 2-column grid, side navigation possible, hybrid touch+pointer |
| Desktop | 1024px - 1279px | Tertiary design target | Multi-column layout, full sidebar, hover states |
| Wide | 1280px+ | Maximum layout | Full content width, whitespace-balanced, max-width container |

### 2.2 Mobile-First Design Principles

1. Content-first: Prioritize content hierarchy. Mobile forces focus - the most important action/content must be immediately visible without scrolling.
2. Touch targets: All interactive elements MUST be minimum 44x44px tap targets with 8px spacing between touchable elements.
3. Thumb zone: Primary actions MUST be placed within the thumb-friendly zone (bottom 1/3 of screen on mobile, left/right bottom corners).
4. Progressive disclosure: Show essential content first, reveal secondary content on interaction or at larger viewports.
5. Avoid horizontal scroll: All content must fit within the viewport width. Use vertical stacking, horizontal scroll only for carousels/galleries with visible scroll indicators.
6. Bottom navigation: On mobile, primary navigation should be at the bottom (thumb reachable). On desktop, move to sidebar or top nav.

### 2.3 Responsive Adaptation Strategy

| UI Element | Mobile | Tablet | Desktop |
|------------|--------|--------|---------|
| Navigation | Bottom tab bar / hamburger drawer | Sidebar collapsed / hamburger | Full sidebar or top nav |
| Data tables | Card list (horizontal scroll if needed) | Card list with key columns | Full table with all columns |
| Modals | Full-screen sheet (bottom-up) | Centered modal (medium) | Centered modal (large) |
| Forms | Single column, stacked | Single column, wider inputs | Multi-column where logical |
| Filters | Slide-out drawer (bottom) | Slide-out panel (side) | Inline sidebar |
| Action buttons | Bottom-anchored, full-width | Inline, positioned | Inline, positioned |

### 2.4 Mobile-Specific Patterns

When desktop UI cannot be reasonably adapted for mobile, create dedicated mobile components:

| Pattern | Mobile Implementation | Desktop Implementation |
|---------|----------------------|----------------------|
| Navigation | Bottom tab bar + hamburger drawer | Sidebar or top navigation bar |
| Data selection | Bottom sheet with search | Dropdown or inline picker |
| Multi-select | Chip + bottom sheet list | Checkbox list |
| Date picker | Native input type="date" | Shadcn Calendar popover |
| Rich editing | Simplified toolbar, scrollable | Full toolbar, fixed |

---

## 3. Accessibility Design Standards (WCAG 2.1 AA)

### 3.1 Mandatory Accessibility Requirements

Every design spec MUST address ALL of the following:

| Category | Requirement | WCAG Criterion |
|----------|-------------|----------------|
| Color contrast | Text: 4.5:1 ratio (normal), 3:1 (large text). UI components: 3:1 | 1.4.3, 1.4.11 |
| Keyboard navigation | All functionality operable via keyboard. Logical tab order. Visible focus indicators (2px outline, 3:1 contrast) | 2.1.1, 2.4.7 |
| Focus management | Focus moves to new content on navigation. Modal focus trap. Skip-to-content link at top of page | 2.4.3 |
| Screen reader | Semantic HTML structure. ARIA labels for all interactive elements. Status announcements for dynamic content (aria-live) | 4.1.2, 4.1.3 |
| Touch targets | Minimum 44x44px (mobile). Adequate spacing between touch targets | 2.5.5 |
| Error identification | Error messages associated with specific inputs via aria-describedby. Error summary at top of form | 3.3.1, 3.3.2 |
| Motion and animation | Respect prefers-reduced-motion. No auto-playing animations that cannot be paused | 2.2.2, 2.3.3 |
| Text resizing | Content readable at 200% zoom without loss of functionality | 1.4.4 |
| Images | All meaningful images have alt text. Decorative images have empty alt | 1.1.1 |

### 3.2 Accessibility Design Spec Format

Each component in the design spec MUST include an accessibility section:

```markdown
### Component: ProductCard

**Accessibility Spec:**
- Role: article (semantic), or button if clickable
- ARIA Label: {product.name} - {product.price} (dynamically generated)
- Keyboard: Enter/Space to activate, Tab to navigate between cards
- Focus: 2px solid blue outline on focus-visible
- Screen Reader: Announce name, price, availability status on focus
- Color Contrast: Price text (green on white) = 4.8:1
- Touch Target: min 44px for action buttons within card
```

---

## 4. Design System and Component Library Standards

### 4.1 Shadcn/ui as Default Design System

- All new apps use Shadcn/ui with Tailwind CSS - Shadcn IS the design system
- No custom component library unless explicitly justified and approved by Marcus
- No Storybook - Shadcn components are self-documenting via components/ui/

### 4.2 Theme Design Standards

| Token Category | Design Responsibility | Implementation Responsibility |
|----------------|----------------------|-------------------------------|
| Primary/Secondary colors | Jonathan selects palette | Sophia configures in globals.css |
| Typography scale | Jonathan defines hierarchy | Sophia configures via next/font + Typography component |
| Spacing rhythm | Jonathan defines spacing | Sophia uses Tailwind spacing tokens |
| Border radius | Jonathan selects rounding | Sophia sets --radius variable |
| Shadow elevation | Jonathan defines depth | Sophia uses Tailwind shadow tokens |
| Icon style | Jonathan selects Lucide icons | Sophia uses lucide-react exclusively |

### 4.3 Dark Mode Design

Every design spec MUST include light and dark mode treatment:

| Element | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Background | --background: 0 0% 100% | --background: 222.2 84% 4.9% |
| Surface/card | White with subtle shadow | Dark gray with subtle border |
| Text primary | Near-black | Near-white |
| Borders | Light gray | Dark gray |
| Shadows | Subtle dark shadow | Subtle light shadow (inverted) |

---

## 5. User Journey and Interaction Design Standards

### 5.1 User Journey Map Template

For every feature, produce a user journey map:

```markdown
## User Journey: [Feature Name]

### Actors
- [Role 1]: [Description]
- [Role 2]: [Description]

### Flow
graph TD
    A[Start: User lands on page] --> B{Has permission?}
    B -->|Yes| C[View list]
    B -->|No| D[Show empty state / redirect]
    C --> E[Click create button]
    E --> F[Open create dialog]
    F --> G{Form validation}
    G -->|Valid| H[Submit API call]
    G -->|Invalid| I[Show inline errors]
    I --> F
    H --> J{API response}
    J -->|Success| K[Show success toast, redirect to list]
    J -->|Error| L[Show error state, retain form data]
    L --> F
```

### States Per Step
| Step | Loading | Empty | Success | Error | Edge Case |
|------|---------|-------|---------|-------|-----------|
| View list | Skeleton cards (3 rows) | No items yet + CTA | Data grid with items | Error banner + retry button | Slow network: progressive loading |
| Create form | Submit button disabled + spinner | N/A | Toast + redirect | Inline error per field | Double-click prevention |

### 5.2 Interaction State Matrix (MANDATORY)

Every interactive component MUST have ALL states defined:

| Component | Default | Hover | Focus | Active | Disabled | Loading | Error | Empty | Success |
|-----------|---------|-------|-------|--------|----------|---------|-------|-------|---------|
| Button | Primary fill | Slightly darker | Focus ring | Pressed state | 50% opacity, no pointer | Spinner replaces icon | N/A | N/A | N/A |
| Text Input | Border, white bg | Border darken | Focus ring | Border primary | Gray bg, no pointer | N/A | Red border + error message | N/A | Green border |
| Select | Chevron icon | Border darken | Focus ring | Open dropdown | Gray bg | N/A | Red border | No options text | N/A |
| Table Row | White bg | Light gray bg | Focus ring on cell | Selected highlight | N/A | Row skeleton | N/A | No data message | N/A |
| Card | Shadow, white bg | Elevated shadow | Focus ring | Pressed scale | Faded | Skeleton | Red border | N/A | N/A |

### 5.3 Navigation and Page Flow Design

| Pattern | When to Use | Example |
|---------|-------------|---------|
| Modal/Dialog | Single task, no context loss | Create, edit, confirm |
| Full page | Complex task, new context | Settings, detail view |
| Slide-out panel | Contextual task, keep reference | Filters, quick edit |
| Wizard/Stepper | Multi-step sequential task | Checkout, onboarding |
| Inline edit | Quick value change | Editable table cell, inline title |
| Toast notification | Non-blocking feedback | Save success, error notification |

---

## 6. Error and Edge Case Design Standards

### 6.1 Error State Design

Every API-driven component MUST have designed error states:

| Error Type | UI Treatment | User Action |
|------------|-------------|-------------|
| Network timeout | Error banner with retry button, timestamp | Click retry |
| API 4xx (permission) | Inline error, redirect to login if unauthorized | Re-authenticate or contact admin |
| API 5xx (server error) | Error page with try again later | Contact support |
| Validation error | Inline: red border + error message below field. Top: error summary | Fix highlighted fields |
| Rate limited | Countdown timer + Too many requests message | Wait and retry |
| Offline | Offline indicator banner, disable write operations | Wait for connection |

### 6.2 Empty State Design

Every list/data component MUST have designed empty state:

| Empty State Type | UI Treatment | Example |
|-----------------|-------------|---------|
| No data yet | Illustration + message + primary CTA button | No products yet. Create your first product. |
| No results (filter) | Search icon + message + clear filters link | No results matching your filters. Clear filters. |
| No permission | Lock icon + message + contact admin link | You do not have access to this section. |
| Feature not available | Coming soon badge + notify me CTA | This feature is coming soon. |

### 6.3 Loading State Design

| Loading Type | UI Treatment | Duration Guidance |
|-------------|-------------|-------------------|
| Skeleton | Pulse-animated placeholder matching layout | Always (instant feedback) |
| Spinner | Centered spinner with text | For operations longer than 1s |
| Progress bar | Determinate or indeterminate top bar | For operations longer than 3s |
| Skeleton table | 3-5 rows of skeleton cells matching column widths | Always for data tables |
| Skeleton card | Card-shaped skeleton with image + text lines | Always for card grids |
| Button loading | Spinner replacing icon, button disabled, text remains | For form submissions |

---

## 7. Design Review Checklist

### 7.1 Pre-Implementation Review (Jonathan + Emma + Marcus)

- [ ] User journey map covers all roles and permissions
- [ ] All edge cases and error flows documented
- [ ] Wireframes cover all states (default, loading, empty, error, edge)
- [ ] Responsive behavior defined at all breakpoints
- [ ] Accessibility requirements documented per component
- [ ] Interaction state matrix complete for all interactive components
- [ ] Navigation flow diagram covers all page transitions
- [ ] Dark mode treatment specified
- [ ] Design is technically feasible (Marcus sign-off)
- [ ] Design meets business requirements (Emma sign-off)

### 7.2 Post-Implementation UX Fidelity Review (Jonathan)

- [ ] Implementation matches approved design spec across all breakpoints
- [ ] All interaction states correct (hover, focus, active, disabled, loading, empty, error, success)
- [ ] Responsive behavior matches spec (mobile to tablet to desktop to wide)
- [ ] Touch targets meet minimum 44x44px on mobile
- [ ] Color contrast meets WCAG 2.1 AA minimums
- [ ] Keyboard navigation logical and complete
- [ ] Focus indicators visible and consistent
- [ ] Screen reader experience correct (ARIA labels, roles, live regions)
- [ ] Dark mode renders correctly
- [ ] Animations respect prefers-reduced-motion
- [ ] Loading states match skeleton design
- [ ] Empty states match spec
- [ ] Error states match spec
- [ ] Typography hierarchy matches spec
- [ ] Theme tokens used correctly (no arbitrary values)

---

## 8. Industry Standard References

| Standard | Reference | Applicability |
|----------|-----------|---------------|
| WCAG 2.1 AA | https://www.w3.org/TR/WCAG21/ | Accessibility - ALL deliverables |
| Material Design 3 | https://m3.material.io/ | Layout, navigation, component patterns |
| Apple Human Interface Guidelines | https://developer.apple.com/design/human-interface-guidelines/ | Mobile interaction patterns (iOS) |
| Shadcn/ui Theming | https://ui.shadcn.com/docs/theming | Theme token configuration |
| Tailwind CSS Responsive Design | https://tailwindcss.com/docs/responsive-design | Mobile-first responsive utilities |
| NNG (Nielsen Norman Group) | https://www.nngroup.com/articles/ | UX research, usability heuristics |
| A11y Project Checklist | https://www.a11yproject.com/checklist/ | Accessibility checklist |

---

## 9. Handoff to Sophia (Design-to-Implementation)

When Jonathan hands off to Sophia, the following MUST be included:

```markdown
## Design Handoff: [Feature Name]

### Approved Design Specs
- [ ] User Journey Map: [link to doc]
- [ ] Wireframes: [link to mermaid/visual]
- [ ] Navigation Flow: [link to diagram]
- [ ] Interaction State Matrix: [link to table]
- [ ] Responsive Behavior Spec: [link to table]
- [ ] Accessibility Spec: [link to checklist]
- [ ] Error and Edge Case Spec: [link to table]

### Theme Tokens Used
- Colors: [list of custom tokens beyond default Shadcn]
- Typography: [any custom font variants]
- Spacing: [any custom spacing values]

### API Dependencies
- Required endpoints: [list]
- Expected data shapes: [link to API contracts]

### Approval Sign-off
- Emma (product): [date]
- Marcus (architecture): [date]
```

## Handoff Target
- Sophia (implementation) then Jonathan (UX review) + Felix (code review) [parallel] then Build verify then Olivia (E2E) then Ethan (deploy) then Isabella (docs + biz validation)

## Verification Checklist
- [ ] User journey map complete with all roles and permissions
- [ ] Wireframes approved by Emma + Marcus
- [ ] Interaction state matrix complete for all components
- [ ] Accessibility spec meets WCAG 2.1 AA
- [ ] Responsive behavior defined at all 5 breakpoints
- [ ] Error, empty, loading states designed for every component
- [ ] Dark mode treatment specified
- [ ] Design handoff package delivered to Sophia
