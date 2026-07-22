# OElite Core Principles — Universal Foundation

> **Loaded by EVERY agent, EVERY request.** Contains all shared standards, workflows, and non-negotiables.
> **Role/task taxonomy, repo map, and handoff chains** live in `AGENTS.md` (navigator) and `workflow.md` respectively — not duplicated here.

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
| **Issue-First** | No work begins (no worktree, no code, no exploration) until a GitLab issue ticket exists and meets Definition of Ready (`TASK-TEMPLATES.md` §1), created using `ISSUE-MR-TEMPLATES.md` | Bootstrap refuses to proceed without issue IID; reviewers reject MRs with no linked issue |
| **Autonomous Handoff** | Complete task → trigger next role per workflow chain | Handoff format mandatory |
| **Merge Verification** | After reviewer approves, the reviewer (or Emma) MUST verify the MR status is `merged` in GitLab before transitioning the linked issue to `Done` | `mr-status` CLI check; no issue closed as `Done` without confirmed merge |
| **Issue Closure Enforcement** | Every merged MR's linked issue MUST be closed in GitLab via `issue-status closed` — not just labeled `Done`. Closure happens in the same session as merge verification. | Post-merge audit flags any issue still open after MR merged |

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

### No-Mock-Data Policy (ZERO tolerance)
Start empty, load from API, render explicit loading/empty/error states. If an API is missing, mark the task **BLOCKED** and document the required endpoints — never fall back to fake data.

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
- 12 Quality Gates (NON-NEGOTIABLE):
   1. **Min 3 assertions/test** — no no-op navigation tests
   2. **Real server + real API** — no mock data assertions
   3. **Interaction Coverage Matrix** — 9 categories per feature
   4. **AC Traceability** — every test references `US-XXX/AC-XXX`
   5. **RBAC Matrix** — test every role
   6. **Interactive Component Pattern** — auth → navigate → interact → assert
   7. **No-Op Detection** — pre-commit checks assertion count
   8. **Execution Evidence** — captured output, screenshots, traces
   9. **Business Logic Validation** — UI enforces business rules before API, derived values correct, state machine transitions valid
   10. **Accessibility Testing** — aXe scan, keyboard nav, ARIA, color contrast, touch targets
   11. **User Journey Testing** — happy path, branching, error recovery, permission-based, rollback
   12. **State Management Testing** — cache invalidation, optimistic updates, stale data handling

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
`To Do` → `In Progress` (Emma assigns) → `PR Review` (MR created) → `Ready to Merge` (approved + CI green) → `Done` (Emma labels after merge verified + Isabella validation) → **Issue closed** (Emma runs `issue-status closed` immediately after labeling `Done`)

**Only Emma closes issues.** Reopening requires stakeholder/Emma approval.

**Closure enforcement:** Labeling an issue `Done` is NOT sufficient — the issue MUST be closed in GitLab via `scripts/oelite-gitlab.sh issue-status <project> <iid> emma closed`. Emma MUST perform this in the same session as verifying the MR merge. A post-merge audit MUST be run periodically to catch any issues left open after their linked MRs were merged.

### Commit Format
```
Title: concise imperative summary

- Bullet 1: what changed
- Bullet 2: why
- Bullet 3: verification

Closes #<issue>
```
**Never**: AI references, emojis, co-authors.

### Branch Strategy & Packaging
- **main**: production releases → NuGet `nuget.org`; Docker `registry.phanes.ltd/oelite`.
- **develop**: development pre-releases → `packages.phanes.ltd`.
- **uat**: UAT pre-releases → `packages.phanes.ltd`.
- K8s namespaces: `oelite-dev` / `oelite-uat` / `oelite-prod`; production deploys are `when: manual`.

---

## 🔒 SECURITY & BEST PRACTICES

### Authentication & Authorization
- Central IAM is **`uranus/origin-auth`**: JWT **RS256** issuance/validation/introspection/revocation (`Origin.Services/Authentication/TokenService.cs`), RSA key generation & rotation with key material encrypted at rest via **AES-GCM** (`RsaKeyManager.cs`).
- App-client credentials + customer bearer-token model. **Server-side access control for every data operation.**
- Edge auth/proxy via **Kortex** (`[Authorize(Roles=…)]`, versioned routes).

### Data Protection
- Passwords: **Argon2id** (`Security/PasswordHashingService.cs`). Field-level encryption: **AES-256** with 90-day rotation and PII/PHI/Financial/Credential classification (`Security/DataProtectionService.cs`, `EncryptionService.cs`).
- Never commit secrets or API keys (use K8s secrets / CI variables). Validate tenant access (`Region` / `IOwnedEntity`) for all data requests. Implement proper error handling and structured logging (Serilog); do not log secrets.

---

## ✅ VERIFICATION COMMANDS (Per Stack)

- **.NET**: `dotnet build <project> --configuration Release`; `dotnet test --configuration Release --logger trx`. Rebuild referencing projects too.
- **Health**: `curl -f http://localhost:50018/health` (Nexus); `/healthz` (Tesseract); per-service health controllers elsewhere.
- **Next.js**: run inside the app folder (e.g. `jupiter/occ`): `npx next build`, `npm run lint`, `npx playwright test`.
- **Angular**: `npm run build` / `build:ssr` (ec-std-01), `npm run test` (Karma); `ng build` + `ng test` (bizsmart).
- **Docker**: `docker build -f <Dockerfile> .`; `docker compose -f docker-compose.dev.yml up` where compose files exist (helios/core, stella, lattice, hermes, quantrix, obelisk, kortex, oesterling).
- **K8s**: `kubectl rollout status deployment/<name> -n oelite-<env>`.
- Note: `mercury/runners` CI is currently disabled (`SKIP_BUILD=true`) — validate runners manually.

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

## 📝 DOCUMENTATION SELF-MAINTENANCE PROTOCOL

The documentation in this monorepo (root `AGENTS.md`, `GEMINI.md`, `REPOS.md`, and per-repo `AGENTS.md` stubs) is a **living system**. It must stay in sync with the codebase. Every agentic coding session is responsible for keeping it current — not just the code it touches.

### Mandatory Pre-Completion Documentation Check

Before declaring **any** task complete, run this checklist. If any item applies, update the relevant doc **in the same commit** as the code change.

| Trigger | Action |
|---------|--------|
| **New repo added** | Add row to `REPOS.md`. Create per-repo `AGENTS.md` stub. Add to topology table in root `AGENTS.md` if deprecated. Isabella creates full `docs/` structure. |
| **Repo deprecated / retired** | Update `REPOS.md` status → `Deprecated`. Move to deprecated list in root `AGENTS.md`. Delete/archive per-repo `AGENTS.md`. |
| **Stack change** | Update per-repo `AGENTS.md` Tech Stack and `REPOS.md`. If platform-wide, update root `AGENTS.md`. Isabella updates `docs/technical/architecture/`. |
| **Build / test / health command changes** | Update per-repo `AGENTS.md` and `REPOS.md` columns. Isabella updates `docs/technical/deployment/`. |
| **New OElite framework pattern introduced** | Update OElite Framework Primer in `principles.md` (this file). Update per-repo `AGENTS.md` as needed. Isabella updates `docs/technical/architecture/` and `docs/technical/data/`. |
| **Repo starts/stops using OElite patterns** | Update per-repo `AGENTS.md` `OElite-Specific Patterns`. Update root `AGENTS.md` OElite-compliant list. Isabella updates migration guides. |
| **New coding standard added** | Reference it in relevant role/pack files. Isabella updates onboarding docs. |
| **Per-repo `.ai/standards/` added or changed** | Note it in per-repo `AGENTS.md` `Standards & Overrides`. Create/update `.ai/standards/` for deviations. Isabella ensures `docs/technical/architecture/` reflects them. |
| **Health endpoint path/port changes** | Update per-repo `AGENTS.md` and `REPOS.md`. Update verification commands in this file if common service. Isabella updates `docs/technical/deployment/`. |
| **New feature implemented** | Isabella updates user stories, API endpoints, user guides, CHANGELOG. Captures Playwright screenshots. |
| **New release deployed** | Isabella creates release notes, updates CHANGELOG, creates migration guide if needed. |

### Self-Verification Checklist (run before every "done")

- [ ] Does the per-repo `AGENTS.md` still accurately describe this repo's stack, commands, and patterns?
- [ ] Does `REPOS.md` still list this repo with the correct status, stack, and commands?
- [ ] If I changed a build/test/health command, did I update both the per-repo `AGENTS.md` and `REPOS.md`?
- [ ] If I added or removed a repo, did I update `REPOS.md`, root `AGENTS.md` topology?
- [ ] If I introduced a new OElite pattern, did I update the Framework Primer in this file (`principles.md`)?
- [ ] If I migrated a repo toward/away from OElite patterns, did I update the per-repo `AGENTS.md` `OElite-Specific Patterns` section?
- [ ] If this repo has `.ai/standards/`, did I update those files to reflect any pattern/command/architecture changes? If this repo deviates from platform standards but has no `.ai/standards/` yet, did I create one documenting the deviation?
- [ ] **Did my changes impact user-facing behavior, APIs, configuration, architecture, or business requirements?** If YES, did I notify Isabella with specific details about what changed and what documentation needs updating?

### Periodic Consistency Audit

When asked to "audit docs" or "check doc consistency":

1. **Cross-reference `REPOS.md` against the filesystem**: every active sub-repo should have a row in `REPOS.md` and a per-repo `AGENTS.md` (except `origin-auth` which has its own full guide).
2. **Cross-reference deprecated lists**: root `AGENTS.md` deprecated list and `REPOS.md` Deprecated rows must match exactly.
3. **Spot-check 3 random per-repo stubs**: verify stack/commands match actual `package.json` / `.csproj` / `Program.cs`.
4. **Check for drift in `uranus/arc-agents/standards/`**: compare against `coding-standards/`. If drifted, note it (do not auto-sync — mirror maintained separately).
5. **Report findings** with specific file paths and what needs updating.

### Pending Enhancements

| Repo | Enhancement |
|------|-------------|
| `uranus/lattice` | Migrate to OElite patterns (startup, config, DI, data access, API responses) |
| `venus/sip` | Modernize Docker base image, add CI pipeline, update global.json, optional health endpoint |

**Do not implement these as part of unrelated feature work** — they require dedicated migration tasks.
