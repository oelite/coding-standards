# UI Usability — Professional Pre-Design Thinking, Playbooks & Validation Strategy

> **Skill ID:** `ui-usability`
> **Owner:** Jonathan (UX Design)
> **Default loaders:** Jonathan, Sophia, Olivia, Felix
> **On-demand loaders:** Emma, Isabella
> **Status:** active
> **Issue:** #73
> **Sister skills (the UX knowledge layering):** `design-system` (#70 — the VALUES layer: tokens, typography, states) · `ui-usability` (THIS skill — the THINKING layer: analysis, playbooks, validation) · `frontend-design` (#21 — the IMPLEMENTATION layer: Shadcn patterns, aesthetic).
>
> Load together for any user-facing feature: **think** (ui-usability) → **decide** (design-system values) → **build** (frontend-design implementation).

---

## Purpose

Stop shipping "useless or way-too-simple CRUD designs for features that require decent knowledge of what best serves the feature/functionality, required logic/UI validation, and user-friendly guidance."

This skill provides the professional usability KNOWLEDGE applied BEFORE building: pre-design analysis, feature-type playbooks, validation & error-prevention strategy, in-product guidance, and a measurable reviewer/QA checklist. Usability dictates design quality — not just style tokens. Style consistency alone (design-system) does not make a screen useful; thinking about users, tasks, and failure modes does.

## When to Load

- **Default loaders:** Jonathan (all design work), Sophia (all frontend implementation), Olivia (QA of UI features), Felix (all frontend review)
- **On-demand triggers:** "UI design", "new feature UI", "usability review", "is this CRUD", "form validation", "user workflow", "approval flow", "dashboard UX", "error messages", "empty states", "how should this screen work"
- MANDATORY before estimating, designing, or implementing ANY screen that goes beyond trivial reference data.

---

## Standards & Rules

### §1 Pre-Design Analysis Framework (MANDATORY BEFORE ANY UI WORK)

Answer these BEFORE designing, implementing, or estimating. Put the answers in the PR/MR description or the task document. Designing without them is how useless CRUD screens get built.

| Question | What to answer |
|----------|---------------|
| **Users** | WHO uses this screen: role, expertise, frequency of use? Daily operators need shortcuts/bulk/keyboard paths; annual users need guided flows. Are there power-user shortcut needs? |
| **Task** | WHAT job does the screen do? What are the consequences of errors — **reversible? financial? legal? clinical?** Task frequency: daily vs annual? Annual + consequential = guided + heavily validated; daily + benign = fast, dense, keyboardable. |
| **Data** | Volume per view (10 rows or 10,000)? Density needs (scanning many rows vs mostly empty space in 6 months)? Growth over time? |
| **Decisions** | How many choices per screen? Branching workflows (answer A sends it to a different queue)? More than ~7 significant choices per zone = you need grouping or progressive disclosure (§2). |
| **Output — classification** | Screen-type classification (§3): **Simple CRUD · Business Workflow · Analytical Dashboard · Operator Console · Consumer Media Surface · Mixed** — with the DESIGN IMPLICATIONS chosen from the corresponding playbook. |

**Every UI PR description includes a one-line classification**, e.g.:
`UI classification: Business Workflow (approval state machine, priority playbook §3.2)` — Felix/Olivia reject UI PRs missing it.

#### Anti-CRUD Gate (the core complaint, made enforceable)

Plain CRUD is **explicitly ALLOWED only when ALL of the following are true**:

- [ ] Reference/master data (payer lists, product catalogs, user preferences, tenant settings)
- [ ] Low error cost (a wrong entry is trivially fixable, not financial/legal/clinical)
- [ ] Single-table ownership (the entity has no cross-entity workflow it triggers)
- [ ] <10 form fields
- [ ] No cross-entity workflow (creating/editing it does not hand work to another role)
- [ ] No audit requirements (no "who changed this and when must be provable" need)

**ANY unmet condition → escalate to §3 playbook (usually §3.2 Business Workflow or Mixed).**

Common OElite failure patterns this gate catches — do NOT build plain CRUD for:

| Wrongly-CRUD'd feature | Why CRUD fails it | Correct playbook |
|------------------------|-------------------|------------------|
| Claim / expense approval | State machine + SLA + audit reasons | §3.2 Business Workflow |
| Permission / role assignment | Consequential, audited, cross-entity | §3.2 (+ confirmation/undo rules §4) |
| Order / booking lifecycle | Multi-state, draft, resumable | §3.2 |
| Patient appointment handling | Statuses, cancellation reasons, conflict checks | §3.2 |
| Metrics / revenue / ops monitoring | Aggregates, drill-down, comparison | §3.3 Analytical Dashboard |
| Support / ops triage queues | High volume, keyboard-first, modes | §3.4 Operator Console |
| Onboarding wizards | Multi-step, resumable, per-step validation | §3.2 (stepper patterns) |
| Consumer media feed / video grid | Media-first cards, not data rows | §3.5 Consumer Media Surface |
| Consumer media feed / video grid | Media-first cards, not data rows | §3.5 Consumer Media Surface |

#### API-to-UI Shape Mapping (MANDATORY before implementing data-bound UI)

Before writing any component that renders API data, map every UI surface area to its served API field. Designing from imagination and typing from assumption is how contract-drift crashes happen (the UI assumes a nested shape the API never served; the page renders raw internals or crashes).

| Rule | Requirement |
|------|-------------|
| **Mapping table in the PR** | Every data-bound UI MR includes a field map: UI surface area → exact served field name + shape (from the controller DTO/projection, never from an assumed client-side shape). Felix/Olivia reject data-bound UI PRs missing it. |
| **Served contract is the source** | Field names/types come from the SERVED response (read the controller/projection), not from client-side TypeScript assumptions. A component whose types don't match the served shape is a defect even if it compiles. |
| **No internal terminology as user copy** | Server/rank/tier/status strings (`RANK tier=E4`, `status_name`, entity ids) NEVER render as user-facing body copy — map to designed vocabulary from the domain rulebook (§2 Match the real world). A raw internal string in the rendered UI = reviewer-blocked defect. |
| **Missing documented fields = blocking contract gap** | If the documented experience requires a field the API does not serve (e.g., media in a video feed card), that is a BLOCKING contract gap: raise it to Marcus/Isabella/Emma and ship a DESIGNED interim state (media-shaped skeleton, honest empty state) — never silently degrade the card into a raw data dump. |


### §2 Cognitive & Heuristic Foundations (Applied, Not Textbook)

Nielsen's 10 (adapted so each has a concrete OElite application rule). Domain docs and screen language come from the repo's business rulebook (`docs/business/rules/` or `BUSINESS-RULEBOOK.md`).

| Heuristic | OElite application rule | Example |
|-----------|------------------------|---------|
| **Visibility of system status** | Every async operation shows progress; every multi-step flow shows WHERE the user is — and stepper state **persists on reload**. | Approval flow shows "Step 2 of 4 — Submitted · Under review (Sarah, since Oct 3)" |
| **Match the real world** | Use business terminology from the domain rulebook — claims, panels, periods, referrers — never internal names ("entity C-12", "record type B"). Backend naming leaks to UI = defect. | "Processing claim #A-1042" not "Executing job on DocumentObject" |
| **Consistency** | Within the app AND across the OElite ecosystem — via `design-system` tokens. Same verb = same action everywhere; don't rename "Approve" to "Confirm" on one screen. | Every OElite app uses the same status-chip vocabulary per state |
| **Recognition over recall** | Show, don't make users remember: dropdowns/combos over free-typing IDs; breadcrumb over back-button reliance; show computed consequences instead of expecting users to hold data in their head. | Picking a referrer shows their specialty + next availability, not just a bare name to recall |
| **Error prevention over error messages** | Prefer preventing the impossible over reporting the impossible — full strategy in §4. | Booking UI disables dates outside the open billing period instead of rejecting them on submit |
| **Flexibility & efficiency** | Daily-frequency tasks MUST offer bulk actions + keyboard paths; power users accelerate, novices aren't blocked. | Approvals queue: Shift-click range + `A` approve / `R` reject keys |
| **Minimalist design** | Progressive disclosure; **max ~7 primary interactive items per screen zone** (menu rows, form fieldsets, primary buttons — the cognitive-load ceiling). Advanced options behind "Advanced". | Booking form shows 5 essential fields; recurrence + insurance details live under "Advanced" |
| **Recognize/recover from errors** | 3-part message format (§4); recovery never costs the user their input. | Server rejects save → inline banner + retry; form fields intact |
| **Help & documentation** | In-product help at the point of need (§5) — never "see the wiki". | Help icon next to "Panel" links to rulebook rule BR-14 |

Beyond Nielsen — three psychophysical laws with concrete placement consequences:

- **Fitts's Law:** bigger + nearer targets are faster. Primary action of the current step sized/positioned for the flow, not habitually top-right every time; destructive controls isolated, small, or anchored away from frequent-path buttons. Touch ≥44px (design-system rule).
- **Hick's Law:** time-to-decision grows with simultaneous choices. Limit visible options; chunk long lists into categorical steps (group-by-specialty before pick-a-clinician); a wall of 30 filter chips is a redesign signal.
- **Serial-position effect:** users remember first and last items best. Place destructive/primary actions at work-flow-logical positions — e.g., in an approval, primary "Approve" sits where the reviewer's eye finishes reading the claim content, and "Reject" is deliberately separated — not just wherever momentum past layouts put it. Re-examine placement per feature instead of copy-pasting header rows.

### §3 Feature-Type Playbooks (The Core Differentiator)

Classify first (§1), then apply the matching playbook. Each playbook gives: screen pattern, state→screen mapping, validation strategy, common mistakes, and when NOT to use it.

#### §3.1 Plain CRUD (Reference Data)

**Screen pattern:** single table (or card grid) + drawer/dialog form. Inline editing for ≤3 fields; full dialog form beyond that. Pagination (design-system §4 table rules). Simple-filters row (search + 1–2 dropdowns).
**State→screen mapping:** loading skeleton · empty + primary CTA ("Add payer") · error + retry · success list. That's it — do NOT add a stepper, audit panel, or SLA chips to a payer list.
**Validation strategy:** client-side completeness on blur + submit; server-side uniqueness (debounced "name already in use"); no business-rule bands needed.
**Common mistakes:** (a) the opposite failure — paginating 15-row lists that want a single page; (b) adding workflow vocabulary ("approve payer") which the anti-CRUD gate says shouldn't exist; (c) making 8 mandatory fields for a 2-attribute entity.
**When NOT to use:** ANY anti-CRUD gate condition fails (§1) → don't ship CRUD; hands it to §3.2.

#### §3.2 Business Workflow (Approvals, Claims, Orders, Onboarding) — the default for consequential work

**Screen pattern:** state-machine driven UI.

1. **Enumerate states from business logic FIRST** (source: repo rulebook §2 / state machine in docs). Design decision follows the machine — never invent UI states that don't exist in the machine.
2. **One visible screen-state per machine state, clearly distinct:** e.g. Draft (editable form) · Submitted (read-only + recent activity) · Under Review (reviewer actions active) · Approved/Rejected (immutable record + outcome banner). Distinction = layout change + banner + available-actions set, not a color chip alone.
3. **Queue/inbox pattern:** "My Tasks" list with status chips + SLA indicators; each row shows state, age, assignee, and the ONE primary action.
4. **Per-state action set:** the actions visible on a record are exactly the machine's allowed transitions for the current state + user role — never show "Approve" on a Draft or "Edit" on an Approved record.
5. **Audit-trail panel always visible** (collapsible section, not a hidden tab): who/when/what changed per state transition, with the mandatory reason on state-changing actions.
6. **Draft autosave + resumable steps:** drafts persist server-side; user closes the browser mid-draft, returns tomorrow, continues (stepper state persists per §2).
7. **Bulk approve/reject with reason capture:** reason is required on reject, captured once for the batch with per-item outcomes reviewable.
8. **SLA/escalation indicators:** aging chips (escalate color as threshold approaches: neutral → warning → danger).

**Validation strategy:** stage-scoped — the validations of stage N never block progress of stage N−1. Draft allows save-with-incomplete (save ≠ submit); SUBMIT-time validation runs the full rule set; each required rule indicator is visible before submit ("2 items missing: insurance ID, panel confirmation").
**Common mistakes:** one giant form mirroring the database instead of distinct state screens; validations gating early drafting; no audit panel ("who rejected and why?"); losing "my" task filter; confirmation-free rejection.
**When NOT to use:** if the entity has no meaningful states (just add/list/delete), it is §3.1; if it's read-only analysis over many records, it's §3.3.

#### §3.3 Analytical Dashboard

**Screen pattern:** progressive filtering global → scoped (period + org filters at top feed AND-limited to every chart/table); drill-down from aggregate to detail on click (click the underperformance KPI → filtered record list); export always available (CSV/API parity is Isabella/Isa-level concern, but the affordance is Jonathan's); skeleton-then-data loading (design-system §5); KPI layout per design-system §9; **end-user config persistence: saved views** (name + filter set + column choice) with the user's default view restored on return.
**State→screen mapping:** skeleton mirror → data; filtered-no-results ≠ no-data (offer "Clear filters"); per-widget error with retry so one dead chart doesn't blank the page.
**Validation strategy:** less "validation", more defensiveness — out-of-range date ranges handled, empty filter combinations, row-cap notes on exports.
**Common mistakes:** single immutable view for five audiences; filters that don't apply to all widgets (silent inconsistency); drill-down dead ends; bake-and-obsolete exports.
**When NOT to use:** when the user must ACT per record (approve, assign), a dashboard is a complement — the workflow screen (§3.2) is the primary.

#### §3.4 Operator / Console

**Screen pattern:** keyboard-first — every flow reachable without mouse; visible key legend (`?` emits shortcut sheet); dense tables (design-system compact mode); **explicit mode switches** (view/edit/bulk) with current mode always visible in the chrome; **undo everywhere** — every mutation is reversible or clearly logged; audit log prominent, not buried.
**State→screen mapping:** same triad (design-system §5) + "selection state" and "mode state" are FIRST-CLASS (persist selection through mode switches; mode is visible, never inferred).
**Validation strategy:** prefer inline correction and undo over modals; blocking validation only where correctness is critical (dispensing, payments).
**Common mistakes:** mouse-only flows for keyboard operators; hidden modes (`bulk edits firing silently`); confirm-dialog spam instead of undo (§4).
**When NOT to use:** for occasional/admin users this is hostile — §3.2/§3.3 fit better.

#### §3.5 Consumer Media Surface

**When to use:** any consumer-facing surface where the primary content unit is MEDIA (video, photo, audio) — social feeds, video-first home tabs, galleries, product-media grids, review-with-media cards. Distinct from §3.3 (analytical) and §3.1 (CRUD lists): the card is a *media object*, not a data row.

**Screen pattern:** media-first cards with a fixed aspect-ratio slot (e.g. 9:16 vertical, 1:1 square, 16:9 landscape — locked per surface, never free-height); poster frame + low-quality/blur placeholder while media loads; text overlay sits on a gradient scrim (never raw text on unpredictable media — WCAG contrast must hold over the darkest and lightest frame); title clamped to 2 lines; persistent, thumb-reachable engagement affordances (like/save/share) OUTSIDE the media hit area so tapping the card opens the media, not the like button; immersive vertical scroll on mobile (one card ≈ one viewport for video surfaces); designed empty state ("content appears once creators publish" — never a sample/fake card).

**State→screen mapping:** skeleton card shaped like the media slot (aspect-ratio box, not a spinner) → poster/blur-up → playing media; per-card error keeps the card frame (broken-media glyph + retry) so the feed never collapses; media-load-failure ≠ empty-feed.

**Validation strategy:** media dimensions/aspect validated at upload (server-side, not just client); caption/alt-text presence is a publish gate where accessibility law applies (see domain rulebook — e.g. prerecorded-video captions); no autoplay with sound.

**Common mistakes:** free-height cards causing layout shift as media loads; text directly on media without a scrim; engagement buttons overlapping the media tap target; a data-row card (title + metadata) masquerading as a media card because the API serves no media field (see §1 API-to-UI Shape Mapping — that is a blocking contract gap, not a design choice); auto-playing video with sound; infinite scroll with no designed end/empty state.

**When NOT to use:** if the primary unit is a record with attributes (orders, tickets, claims), it's §3.1/§3.2/§3.4 — media, if present, is a thumbnail attribute, not the card.

#### Mapping Table

| Feature example | Playbook | Key patterns |
|----------------|----------|---------------|
| Social/video feed, gallery, discovery grid | §3.5 Consumer Media | Aspect-locked media cards, poster frames, scrims, thumb-reachable engagement, designed empty state |
| Payer / specialty reference lists | §3.1 CRUD | Table + drawer form, inline edit, pagination |
| Claim approval queue | §3.2 Workflow | State screens, my-tasks inbox, audit panel, bulk + reason |
| Patient appointment booking & handling | §3.2 Workflow | Draft autosave, conflict checks, per-state actions, cancellation reasons |
| Revenue / SLA / grid ops monitoring | §3.3 Dashboard | Progressive filters, drill-down, saved views |
| Support ticket triage | §3.4 Console | Keyboard-first, dense tables, modes, undo |
| Order lifecycle (quote → order → invoice) | §3.2 (+dashboard) | Workflow primary; dashboard for throughput |
| Tenant settings | §3.1 CRUD | Reference data, low error cost → deliberately simple |

### §4 Validation & Error-Prevention Strategy

**Client/server split rules:**
- **Client validation = format/completeness** (required fields, email shape, date sanity) → instant feedback, low trust cost.
- **Server validation = business rules + authz** (period closed, quota exhausted, role lacking authority) → the ONLY source of truth; never duplicated client trust that a rule is satisfied.
- Every server rule worth surfacing is surfaced client-side as a **visible precondition where feasible** (disabled control with reason text, not a mystery field).

**Timing table:**

| Validation type | When it runs | Example |
|-----------------|--------------|---------|
| Format/completeness | on blur (then re-validate on change after first error) | Email shape |
| Gating (required to proceed) | on submit/step-advance | Missing panel confirmation on approving a policy |
| Business rules (server — uniqueness, cross-entity) | async on blur + debounce with pending state | Payer name already exists |
| Consequence warnings | before committing the change | "Approving this claim triggers payment batch — 6 claims in it" |

**Error message format — mandatory 3 parts: what happened / which business rule / how to fix.**
> "Invoice date cannot be in a closed period — the period closed 2026-10-01. Choose a date before 2026-10-01."

Never raw codes ("ERR_4021"), never bare "Invalid value."

**Prevention-first priority order** (cheapest prevention beats most verbose error):

1. **Constrained choice** — dropdown/combos over free text
2. **Structured input** — masks/parsers for dates, phone, IDs
3. **Real-time check** — debounced server checks while typing
4. **On-submit block** — gate with per-field errors + summary
5. **Error message** — last resort, in 3-part format

**Undo-friendly destructive design:** soft-delete + restore and other undo states are preferred over confirm-dialog spam. Confirmations are ONLY for irreversible/costly actions, and the wording states the consequence ("Delete claim #A-1042 and its 3 attached documents — cannot be undone"), never "Are you sure?"

**Multi-step forms:** state preservation on back AND on reload; per-step validation (no carried-forward errors for steps already validated); progress visibility always; explicit "changes not saved" affordance whenever leaving a step with unsaved edits.

### §5 In-Product User Guidance

- **Empty states = onboarding:** every empty list/table/dashboard answers *what this is + why empty + primary CTA* (design-system §5) — never blank.
- **Contextual help placement:** help icon on complex form fields, linked to the rulebook rule ID where applicable (`BR-14: eligibility requires panel confirmation` in a tooltip/popover) — the answer lives where the question forms.
- **First-run hints:** dismissible, one hint per screen, vanish once the user demonstrates the action.
- **No toast-only instructions for multi-step guidance:** anything the user must keep in mind across steps lives in persistent UI (stepper, side panel, banner), not a toast that fades in 4 seconds.

---

## §6 Reviewer & QA Usability Checklist (Measurable AC for Felix/Olivia)

Paste-ready pass/fail block:

```
## Usability Checklist (ui-usability §6)
- [ ] Journey completes WITHOUT external docs/wikis/institutional memory
- [ ] Error recovery possible WITHOUT losing user input
- [ ] Back/refresh never destroys work silently (drafts/steps persist where §3.2 applies)
- [ ] Bulk operation (or keyboard path) available for daily-frequency lists
- [ ] Every async view implements the state triad (loading/empty/error — design-system §5)
- [ ] Cognitive load: ≤7 primary interactive items per screen zone
- [ ] Actions per machine state: only allowed transitions visible (no dead actions)
- [ ] Audit trail visible for consequential state changes
- [ ] Destructive actions: consequence-stated confirmation OR undo; 3-part error messages (what/why/fix); no raw codes
- [ ] Consistency: design tokens only, no raw hex/px fonts
- [ ] UTC/timezone and status-chip vocabulary consistent with sibling screens
- [ ] PR includes the §1 one-line UI classification
```

Felix blocks the MR on any unchecked row whose feature does NOT document an intentional, justified exception. Olivia re-verifies via journey tests (Playwright).

---

## §7 Worked Example — "Medical Appointment Approval Flow" (medii/Phanes-domain style)

**§1 Analysis answers:**

- **Users:** clinic admin (daily, high volume), doctor/panel reviewer (daily, judgments), patient-facing staff (occasional). Need shortcuts for admin, guided clarity for reviewer.
- **Task:** approve/cancel doctor appointment requests. Consequences: **clinical** (double-booking, missed panels), moderate financial. Frequency: daily.
- **Data:** dozens–hundreds of requests/day; aging matters (SLA warns at 24h, escalates at 48h).
- **Decisions:** per request, 3 outcomes (approve/reschedule/cancel-with-reason) + optional confirmation-notes; ~5 fields visible, ≤7 zone rule.
- **Output — classification:** Business Workflow (§3.2), NOT CRUD. Anti-CRUD gate fails on: consequential errors (clinical), cross-entity workflow (patient notified, panel review triggered), audit requirements.

**Chosen playbook:** §3.2.

**Screen list (~5 screens):**

1. **Appointments Queue** (my-tasks inbox): state chips + SLA aging, filters (doctor, period, state), bulk approve ready.
2. **Appointment Detail — Draft**: editable request; autosave; per-stage validation (conflict check on blur, none of the submit-stage rules).
3. **Detail — Submitted**: read-only + activity timeline; "Recall to draft" action.
4. **Detail — Under Review**: panel checklist, approve/reschedule/cancel-with-mandatory-reason; consequence banners where relevant.
5. **Detail — Resolved**: immutable record, outcome banner, full audit trail.

**Validation map (§4):** conflicts checked in real time against the doctor's calendar (prevention tier 3) · cancellation reason required (server rule, surfaced as a visible/mandatory field) · submit blocked with a 3-part message where a rule fails · dates constrained to the scheduling horizon (prevention tier 1/2) · everything destructive = soft-cancel + restore.

**QA checklist answers (§6):** all rows pass — the reviewer's job is to prove them in Playwright journeys, including "reload mid-draft → step state intact" and "reject without reason is impossible."

---

## Verification

Jonathan (design), Felix (review), Olivia (QA) — Verification for this skill:

- [ ] The §1 analysis questions (Users/Task/Data/Decisions/Output) are answered IN the PR/task doc before implementation
- [ ] §1 one-line classification present in every UI PR description with chosen playbook + design implications
- [ ] Anti-CRUD gate: any feature failing a gate condition uses a proper §3 playbook; reference data stays deliberately simple
- [ ] §3.2 features: machine states enumerated from rulebook docs; one visible screen-state per machine state; per-state actions; audit panel; draft autosave + resumable steps; SLA aging chips (SLA thresholds defined with Emma before design)
- [ ] §4: 3-part error messages; prevention-first ordering followed; server-sourced business rules shown as visible preconditions where feasible; confirmations state consequences, not "Are you sure?"
- [ ] §5: empty states authored as onboarding; help anchored to rulebook rule IDs on complex fields; multi-step guidance lives in persistent UI, never only toasts
- [ ] §6: reviewers paste the checklist and reject on unexplained unchecked rows
