# Task Pack: Architecture

## Who Loads This
Marcus (primary), Emma (planning reference)

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
