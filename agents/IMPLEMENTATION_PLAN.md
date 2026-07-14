# OElite Context Optimization — Exact Implementation Plan

## Overview
Transform the monolithic 5000+ line AGENTS.md into a modular, lazy-loading system that reduces per-request context from ~50k to ~8k tokens while preserving 100% of behavioral requirements, standards, and workflow chains.

---

## Directory Structure to Create

```
coding-standards/
├── agents/
│   ├── core/
│   │   └── principles.md          # Universal foundation (~2k tokens)
│   ├── roles/
│   │   ├── emma.md                # Product & Delivery Coordinator
│   │   ├── marcus.md              # Principal Software Architect
│   │   ├── daniel.md              # Senior Backend Engineer
│   │   ├── sophia.md              # Senior Frontend Engineer
│   │   ├── jonathan.md            # Lead UX Designer
│   │   ├── olivia.md              # QA & Test Automation Lead
│   │   ├── ethan.md               # DevOps & Reliability Engineer
│   │   ├── maya.md                # Security Engineer
│   │   ├── victor.md              # Data & Performance Engineer
│   │   ├── grace.md               # Lead Backend Code Reviewer
│   │   ├── felix.md               # Lead Frontend Code Reviewer
│   │   └── isabella.md            # Business Analyst & Documentation Lead
│   ├── packs/
│   │   ├── planning.md            # Emma/Marcus/Jonathan/Isabella
│   │   ├── backend-impl.md        # Daniel (+ Maya/Victor/Grace refs)
│   │   ├── backend-review.md      # Grace/Maya/Victor
│   │   ├── frontend-impl.md       # Sophia (+ Jonathan/Felix refs)
│   │   ├── frontend-review.md     # Felix/Jonathan
│   │   ├── testing.md             # Olivia (includes e2e-gates)
│   │   ├── infrastructure.md      # Ethan
│   │   ├── security.md            # Maya
│   │   ├── documentation.md       # Isabella
│   │   └── architecture.md        # Marcus
│   └── IMPLEMENTATION_PLAN.md     # This file
├── AGENTS.md                       # NEW ultra-condensed navigator (~3k tokens)
└── AGENTS.md.backup                # Original preserved
```

---

## File 1: coding-standards/agents/core/principles.md

```markdown
# OElite Core Principles — Universal Foundation

> **Loaded by EVERY agent, EVERY request.** Contains all shared standards, workflows, and non-negotiables.

---

## 🚨 HARD GATES (Non-Negotiable — Enforced by Pre-Commit Hooks & Protocol)

| Gate | Rule | Enforcement |
|------|------|-------------|
| **Worktree Identity** | `scripts/oelite-gitlab.sh worktree-create <role> <branch>` BEFORE any edit | Git pre-commit hook blocks commits outside worktree |
| **Sync First** | `git checkout develop && git pull origin develop` BEFORE worktree creation | Manual verification in bootstrap |
| **Zero Mock Data** | No fake/placeholder/TODO/hard-coded data in delivered code | Olivia rejects; Grace/Felix reject |
| **Zero Mock Persistence** | Integration/E2E tests use REAL Docker infra (`docker-compose.dev.yml`) | CI skips via `[Trait("Category","Integration")]` + `@skipCI` |
| **No Type Suppression** | `as any`, `@ts-ignore`, `@ts-expect-error` = blocked | LSP diagnostics + code review |
| **Verification Mandatory** | Build + tests + health check = required before "done" | Role-specific verification checklists |
| **Autonomous Handoff** | Complete task → trigger next role per workflow chain | Handoff format mandatory |

---

## 🏗️ OELITE FRAMEWORK PRIMER (Backend)

### Entities
- Inherit `BaseEntity` (`uranus/restme/OElite.Restme.Utils/BaseEntity.cs`): `DbObjectId Id`, `EntityStatus Status`, `string? Region` (GDPR), `MetaData`
- Decorate: `[DbCollection("snake_case_name")]`
- Typed lists: `BaseEntityCollection<T>`
- Example: `helios/core/OElite.Common.Platform/Biz/Products/Product.cs`

### Denormalization & Cascade
- `[DenormalizedField(fromCollection, fromField, referenceKey)]` + `[DenormalizedCollection(...)]`
- Substitution: `@PropertyName` (current) / `#PropertyName` (nested)
- Populated by `DataPopulationService`; consistency via `CascadeUpdateService` (real-time) + `DataSyncJob` (async RabbitMQ)

### Repositories
- Inherit `DataRepository<TDbCentre>` (`helios/core/OElite.Data/`)
- App layer: `PlatformDb` + `PlatformDbRepository`
- **Data access ONLY** — no business logic

### Services
- Implement `IOEliteService` / `ISingletonService` / `IScopedService` / `ITransientService`
- Auto-discovered via `AddOEliteDependencyInjections()` — **NO manual DI registration**

### Hosting & Lifecycle
- One-line startup: `await OeApp.RunWebAppAsync<TAppConfig>(args, ...)` (also `RunConsoleAppAsync`, `RunHybridAppAsync`)
- Wires: Serilog, DI, auto-discovery, middleware, bootstrap providers

### Configuration
- `configs-only` pattern: inherit `BaseAppConfig` with correct `OeAppType` + `DbCentreFullClassName`
- No root `appsettings.json` business config; use `appsettings.{Env}.json` + `configs/appsettings.init.json`
- Paths via `OElitePathResolver` — **never hard-coded**

### API Responses
- Controllers return clean DTOs
- `OEliteApiOutputFormatter` auto-wraps in `ApiResponse<T>`
- Annotate: `[TransformedResponse(typeof(T))]` for Swagger
- **Never hand-build response envelopes**

### Data Access
- `IRestme` / `Rest` = unified gateway to HTTP, Redis, RabbitMQ, MongoDB, S3, Azure, ClickHouse, Kafka, OpenSearch
- **Forbidden**: raw `MongoDB.Driver`, `BsonDocument`, `new Rest()`, direct `Microsoft.Extensions.Caching`

---

## 🌐 FRONTEND STACK (Universal)

| Layer | Standard |
|-------|----------|
| **Primary** | Next.js 16.2 + React 19 + TypeScript (App Router, server components default, `'use client'` only when needed) |
| **UI Library** | **Shadcn/ui** (Radix + Tailwind) — DEFAULT for ALL Next.js apps |
| **Icons** | `lucide-react` exclusively — no inline SVG, no icon fonts |
| **Styling** | Tailwind CSS 4, mobile-first, design tokens only (no arbitrary values) |
| **Data** | SWR / TanStack React Query / fetch-based OElite API clients |
| **Legacy Angular** | ec-std-01: Angular 12 + Bootstrap 4/SCSS; bizsmart: Angular 17 + Bootstrap 5/Material; slate: Angular 15 + Electron |

### Shadcn/ui Component Priority (MANDATORY)
**ALWAYS check `components/ui/` first.** If component exists (Button, Dialog, Table, Card, Select, Input, Badge, Alert, Tabs, Separator, Avatar, Collapsible, Sheet, Drawer, Popover, Tooltip, Toast, Checkbox, RadioGroup, Switch, Slider, ScrollArea, Skeleton, Progress, Form, Label, Command, Calendar, etc.) — **USE IT**. Never build custom, never use bare HTML, never hand-write styles for these.

### Theme & Typography Requirements (Every New Next.js App)
- `globals.css` with Shadcn CSS variables (HSL colors)
- `tailwind.config.ts` extending those variables
- `next/font` with type scale: Inter (body), JetBrains Mono (code)
- Shared `Typography` component
- `cn()` utility in `lib/utils.ts` (`clsx` + `tailwind-merge`) — use for ALL `className` composition

---

## 🧪 TESTING POLICY (Zero Tolerance for Mocks)

### Unit Tests
- Pure business logic only — NO persistence
- Coverage: happy path, null/empty, invalid, boundary, error

### Integration Tests (Data Layer)
- **MUST run against REAL Docker containers** (`docker-compose.dev.yml`)
- MongoDB, Redis, ClickHouse, OpenSearch, RabbitMQ, Kafka, MinIO
- Mark: `[Trait("Category", "Integration")]` + `[Category("SkipCI")]`
- CI runs: `dotnet test --filter "Category!=Integration"`

### E2E Browser Tests (Playwright)
- **MANDATORY for all web apps** — unit tests alone insufficient
- Run headless in CI/CD, headed for debugging
- 8 Quality Gates (NON-NEGOTIABLE):
  1. **Min 3 assertions/test** — no no-op navigation tests
  2. **Real server + real API** — no mock data assertions
  3. **Interaction Coverage Matrix** — 9 categories per feature
  4. **AC Traceability** — every test references `US-XXX/AC-XXX`
  5. **RBAC Matrix** — test every role
  6. **Interactive Component Pattern** — auth → navigate → interact → assert
  7. **No-Op Detection** — pre-commit checks assertion count
  8. **Execution Evidence** — captured output, screenshots, traces

### Minimum Test Counts
| Feature | Tests |
|---------|-------|
| Read-only list | 8-15 |
| CRUD page | 25-50 |
| Form + validation + API | 15-30 |
| Permission-dependent UI | 10-20 per role |
| Dashboard | 10-20 |
| Multi-step workflow | 30-60 |

---

## 🔄 GIT WORKFLOW (MR-Centric, GitLab)

### Worktree-First Development
```bash
# 1. Sync main develop
git checkout develop && git pull origin develop

# 2. Create worktree with YOUR role identity
scripts/oelite-gitlab.sh worktree-create <role> <feature-branch>
cd .worktrees/<role>/

# 3. Work, commit (authored as <role>@phanes.ltd), push
git push origin <feature-branch>

# 4. Create MR targeting develop
scripts/oelite-gitlab.sh mr-create <project> <role> <branch> develop "<title>"

# 5. After MR merged: cleanup
scripts/oelite-gitlab.sh worktree-remove <role>
git checkout develop && git pull origin develop
```

### Issue Lifecycle (Mandatory Labels + Comments)
`To Do` → `In Progress` (Emma assigns) → `PR Review` (MR created) → `Ready to Merge` (approved + CI green) → `Done` (Emma closes after Isabella validation)

**Only Emma closes issues.** Reopening requires stakeholder/Emma approval.

### Commit Format
```
Title: concise imperative summary

- Bullet 1: what changed
- Bullet 2: why
- Bullet 3: verification

Closes #<issue>
```
**Never**: AI references, emojis, co-authors.

---

## 📦 DOCUMENTATION STRUCTURE (All Repos)

```
docs/
├── business/
│   ├── BRD.md
│   ├── SRS.md
│   ├── user-stories/US-XXX.md
│   └── process-flows/
├── technical/
│   ├── architecture/ARCHITECTURE.md + ADRs
│   ├── api/API.md + endpoints/ + openapi.yaml
│   ├── data/DATA-MODEL.md + entities/ + migrations/
│   ├── configuration/CONFIG.md + env-vars + app-settings
│   └── deployment/DEPLOYMENT.md + docker/ + kubernetes/
├── user-guides/
│   ├── USER-GUIDES.md
│   ├── getting-started/
│   ├── admin/ + screenshots/
│   ├── end-user/ + screenshots/
│   └── troubleshooting/
├── releases/
│   ├── CHANGELOG.md
│   ├── release-notes/vX.Y.Z.md
│   └── migration-guides/
└── onboarding/
    ├── ONBOARDING.md
    ├── developer-setup.md
    └── glossary.md
```

**README.md** = gateway only (1-2 paragraphs + links to docs/). Detailed content → `docs/`.

---

## 👥 ROLE TAXONOMY (12 Roles)

| Role | Code | Primary Domain |
|------|------|----------------|
| Emma | `emma` | Product & Delivery Coordination |
| Marcus | `marcus` | Principal Architecture |
| Daniel | `daniel` | Backend Implementation |
| Sophia | `sophia` | Frontend Implementation |
| Jonathan | `jonathan` | UX Design |
| Olivia | `olivia` | QA & Test Automation |
| Ethan | `ethan` | DevOps & Reliability |
| Maya | `maya` | Security |
| Victor | `victor` | Data & Performance |
| Grace | `grace` | Backend Code Review |
| Felix | `felix` | Frontend Code Review |
| Isabella | `isabella` | Business Analysis & Documentation |

---

## 🎯 TASK TYPE TAXONOMY (10 Types)

| Type | Code | Trigger Keywords |
|------|------|------------------|
| Planning | `planning` | plan, decompose, estimate, design spec, break down |
| Backend Implementation | `backend-impl` | implement/add/create/build + entity/service/controller/API/repository/migration |
| Backend Review | `backend-review` | review/audit/check + backend code |
| Frontend Implementation | `frontend-impl` | implement/add/create/build + component/page/UI/Next.js/Angular/Shadcn |
| Frontend Review | `frontend-review` | review/audit/check + frontend code |
| Testing | `testing` | test/validate/verify/E2E/Playwright/integration |
| Infrastructure | `infrastructure` | Docker/K8s/deploy/CI/CD/pipeline/compose |
| Security | `security` | auth/JWT/encryption/secrets/vulnerability/penetration |
| Documentation | `documentation` | document/README/user guide/API docs/changelog |
| Architecture | `architecture` | design/architecture/Marcus/system design/cross-system |

---

## ⛓️ AUTONOMOUS HANDOFF CHAINS

### Backend Chain
```
Emma (plan) → Isabella (docs if reqs changed) → Marcus (arch review) → 
Daniel (impl) → Maya (auth/CRUD) + Victor (perf) [parallel] → 
Grace (code review) → Olivia (API/integ/E2E tests) → 
Ethan (deploy) → Isabella (final biz validation + docs + release notes)
```

### Frontend Chain
```
Emma+Marcus (brief Jonathan) → Isabella (docs if reqs changed) → 
Jonathan (design spec) → Emma+Marcus (approve) → 
Sophia (impl) → Jonathan (UX review) + Felix (code review) [parallel] → 
Build verify → Olivia (E2E) → Ethan (deploy) → Isabella (biz validation + screenshots + docs)
```

### Infrastructure Chain
```
Isabella (docs if reqs changed) → Implement → Marcus (review) → 
Olivia (container health) + Maya (secrets) [parallel] → 
Ethan (deploy validate) → Isabella (infra docs + biz validation)
```

### Failure Escalation
- 2 fix attempts → escalate to Marcus (arch) / Emma (reqs) / Maya (sec) / Victor (perf)
- Olivia enforces ALL 8 E2E gates — any violation = immediate rejection

---

## 🏷️ REPOSITORY MAP (Active Only)

| Family | Repos |
|--------|-------|
| **Helios** | `core/`, `kortex/`, `oesterling/`, `compass/`, `k8s/` |
| **Jupiter** | `ec-std-01`, `ec-nx-01`, `occ`, `bizsmart`, `apex/`, `apps-ec-store`, `apps-biz-suite` |
| **Mercury** | `runners/Backplane`, `DataSync`, `LoadBalanceHealthCheckker`, `SubscriptionBilling` |
| **Uranus** | `origin-auth/`, `restme/`, `restme-dapper/`, `orion/`, `stella/`, `hermes/`, `lattice/`, `quantrix/`, `slate/`, `arc-cli/`, `arc-agents/` |
| **Venus** | `obelisk/`, `sip/`, `stela/` |

**Deprecated (do not touch)**: `pluto/`, `*-legacy`, `helios/sites`, `helios/app-config-server`, `jupiter/oes`, `jupiter/gemni-dev`, `jupiter/ec-std-03`, `mercury/runners/Legacy`, `mercury/workflows`, `uranus/restme-wildduck`, `venus/wildduck-*`, `venus/mail-quarantine`, `venus/runners`, `helios/kortex/web/kortex-dashboard-archived`

---

## 📐 STANDARDS AUTHORITY

1. **Global**: `coding-standards/` (1_dotNet_*, 3_angular_*, 4_react_nextjs_*, 0_project_planning_*, 2_general_web_*)
2. **Repo Override**: `<repo>/.ai/standards/*` — extends, never contradicts
3. **Mirror (may drift)**: `uranus/arc-agents/standards/` — never treat as source