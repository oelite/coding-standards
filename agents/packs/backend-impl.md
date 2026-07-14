# Task Pack: Backend Implementation

## Who Loads This
Daniel (primary), Marcus (architecture review reference)

## Standards to Read (via tools)
- `coding-standards/1_dotNet_coding_standards/` — files 02, 03, 04, 05, 06, 09, 12, 13, 14
- Target repo `.ai/standards/coding-standards.md` (if exists)
- Target repo `.ai/standards/architecture-standards.md` (if exists)
- Target repo `.ai/standards/testing-standards.md` (if exists)
- Target repo `.ai/standards/security-standards.md` (if exists, for auth/security work)
- Target repo `.ai/standards/workflow-standards.md` (if exists)

## Implementation Flow (6-Step)
1. **UI Ops / API contract** — understand the operation needed
2. **API/Controller** — versioned route, `[TransformedResponse]`, clean DTO
3. **Entity** — `BaseEntity` + `[DbCollection("snake_case")]` + denormalized fields
4. **Service** — `IOEliteService` marker, auto-discovered, all business logic here
5. **Repository** — `DataRepository<T>` / `PlatformDbRepository`, data access only
6. **Config** — `BaseAppConfig` with correct `OeAppType` + `DbCentreFullClassName`

## Backend Patterns (from OElite Framework)
- **Entity**: `[DbCollection]` + `BaseEntity` + `[DenormalizedField]`
- **Repository**: inherit `PlatformDbRepository`/`DataRepository<T>`; constructor injection of DbCentre + `IAppConfig`
- **Service**: implement the right `I*Service` marker; rely on auto-discovery
- **Controller**: `[ApiController]`, versioned routes, `[TransformedResponse(typeof(T))]`, return DTOs
- **Startup**: `await OeApp.RunWebAppAsync<TAppConfig>(args, …)`
- **Data ops**: `IRestme` providers; background work via `DataSyncJob`/runners
- **Naming**: snake_case DB, PascalCase C#; `DbObjectId`; `EntityStatus`; `Region` for tenancy

## Testing Requirements
- **Unit tests**: Every service method with business logic — cover happy path, null/empty, invalid, boundary, error
- **Integration tests**: Every repository method + every controller action using `WebApplicationFactory<T>` against REAL Docker containers
- **Mark**: `[Trait("Category", "Integration")]` + `[Category("SkipCI")]`
- **Coverage**: ≥70% line coverage for all new code
- **Pre-commit gate**: `docker compose -f docker-compose.dev.yml up -d` → `dotnet test --filter "Category=Integration"` → ALL pass locally
- **No mocked persistence**: never mock `IRestme`, `DataRepository<T>`, `MongoDbCentre`, or any persistence-layer component

## Infrastructure Requirements
- Request `docker-compose.dev.yml` from Ethan for new repos
- Port conflict check: `docker ps` + `lsof -i :<port>` before `compose up`
- Remap ports in compose — NEVER kill existing containers
- Confirm all required containers healthy before tests

## Security Requirements (load security.md if auth/CRUD)
- Tenant isolation: `Region` + `IOwnedEntity` on every query
- Auth: JWT via origin-auth TokenService (RS256, Redis blacklist)
- Crypto: Argon2id (passwords), AES-GCM (field encryption), RSA 2048/4096 (keys)
- Maya MUST review any auth/security/crypto change

## Performance Requirements (load performance.md if queries/denormalization)
- No N+1 — use denormalized fields for read paths
- Indexes via `[DbCollection]` options
- Cache strategy: grace-period + background refresh

## Code Review Gates (Grace + Felix Standards)
- No stub implementations (`NotImplementedException`, empty bodies, `// TODO`)
- No simplified implementations (happy-path-only)
- No temporary quick-fixes ("hack", "workaround", "temporary", "for now")
- No mock/fake data in production code
- Naming: snake_case DB, PascalCase C#

## Handoff Target
- Grace (code review) → Maya (if auth/CRUD) → Victor (if perf/data) [can be parallel] → Olivia (testing) → Ethan (deploy) → Isabella (docs + biz validation)

## Verification Checklist
- [ ] `dotnet build <project> --configuration Release` → 0 errors
- [ ] `docker compose -f docker-compose.dev.yml up -d` → all services healthy
- [ ] `dotnet test --filter "Category=Integration"` → ALL pass
- [ ] `dotnet test --collect:"XPlat Code Coverage"` → ≥70% new code
- [ ] Service starts, health endpoint 200
- [ ] Zero mock/TODO/placeholder/hard-coded data
- [ ] No `as any`, `@ts-ignore`, `@ts-expect-error`
- [ ] Worktree created with correct role identity
- [ ] Next owner identified and triggered
