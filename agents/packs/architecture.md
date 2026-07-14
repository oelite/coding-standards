# Task Pack: Architecture

## Who Loads This
Marcus (primary), Emma (planning reference)

## Standards to Read (via tools)
- `coding-standards/1_dotNet_coding_standards/01,02,03,06,07,11,12,13`
- Target repo `.ai/standards/architecture-standards.md` (if exists)
- Target repo `ARCHITECTURE.md` (if exists)

## Architecture Responsibilities
- Enforce OElite framework patterns and N-tier layer boundaries
- Own multi-tenant architecture, API versioning strategy, cross-system design consistency
- Review and approve design specs before implementation
- Adjudicate cross-cutting decisions:
  - Caching strategy
  - Messaging topology
  - Service boundaries
  - Edge/proxy via Kortex

## OElite Framework Decisions
- Entities: `BaseEntity` + `[DbCollection]` + `[DenormalizedField]`
- Repositories: `DataRepository<T>` / `PlatformDbRepository`, data access only
- Services: `IOEliteService` markers, auto-discovered, no manual DI
- API: DTOs + `OEliteApiOutputFormatter` + `[TransformedResponse]`
- Config: `BaseAppConfig` + `configs-only`
- Startup: `OeApp.RunWebAppAsync<TAppConfig>`
- Data: `IRestme` providers only

## Multi-Tenant Design
- `Region` for data sovereignty/GDPR
- `IOwnedEntity` for owner scoping
- Server-side enforcement on every data operation

## API Versioning
- `[ApiVersion]` attributes
- `v{version:apiVersion}` routes (as in Kortex controllers)

## Cross-Repo Consistency
- Helios/Jupiter/Mercury/Uranus/Venus interdependencies
- Shared NuGet packages from `helios/core`
- `IRestme` providers from `uranus/restme`
- Central IAM from `uranus/origin-auth`

## Verification Checklist
- [ ] `dotnet build <solution> --configuration Release` → 0 errors
- [ ] No layer violations
- [ ] No raw MongoDB driver usage
- [ ] No manual DI for auto-discovered types
- [ ] No hand-built API envelopes
- [ ] Tenant scoping designed correctly
- [ ] API versioning strategy defined

## Handoff Target
- Daniel (backend-impl) / Sophia (frontend-impl) / Ethan (infrastructure) / Isabella (docs, if needed)
