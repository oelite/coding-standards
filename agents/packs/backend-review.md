# Task Pack: Backend Review

## Who Loads This
Grace (primary), Maya (security review), Victor (performance review)

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
- `coding-standards/1_dotNet_coding_standards/` — files 01, 02, 03, 06, 07, 11, 12, 13
- `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md`
- Target repo `.ai/standards/coding-standards.md` (if exists)
- Target repo `.ai/standards/architecture-standards.md` (if exists)
- Target repo `.ai/standards/security-standards.md` (if exists)
- Target repo `.ai/standards/testing-standards.md` (if exists)

## Review Dimensions

### Grace: Code Quality / OElite Compliance
- N-tier layer boundaries: Common → Data → Services → Servers/Api
- No business logic in repositories
- No raw MongoDB driver / `BsonDocument` / `new Rest()` for standard flows
- No manual DI for auto-discovered types
- No hand-built API response envelopes — use `OEliteApiOutputFormatter` + `[TransformedResponse]`
- Naming: snake_case DB, PascalCase C#
- Entities inherit `BaseEntity` + `[DbCollection("snake_case")]`
- Services implement `IOEliteService` markers
- Controllers versioned, return clean DTOs

### Maya: Security (if auth/security/CRUD)
- Tenant isolation via `Region` + `IOwnedEntity`
- JWT: RS256, introspection (RFC 7662), revocation (RFC 7009), Redis blacklist
- Password hashing: Argon2id (OWASP params)
- Field encryption: AES-256, AES-GCM at rest
- RSA key rotation: 2048/4096
- Secrets: never committed, never logged
- All CRUD operations enforce server-side access control

### Victor: Data / Performance (if queries/denormalization/caching)
- No N+1 in read paths
- Indexes appropriate for new query shapes
- Denormalization justified for access pattern
- Cascade depth/loops bounded
- Cache keys/TTLs sound

## Prohibited Patterns (Reject)
- Stub implementations (`NotImplementedException`, empty bodies, `// TODO`)
- Simplified implementations (happy-path-only)
- Temporary quick-fixes ("hack", "workaround", "temporary", "for now")
- Mock/fake/hard-coded data
- `as any`, `@ts-ignore`, `@ts-expect-error`
- Comments unless explicitly requested

## Verification Checklist
- [ ] `dotnet build` clean (0 errors)
- [ ] Tests exist and pass for new behavior
- [ ] Naming/structure compliant
- [ ] No forbidden patterns remain
- [ ] Security review passed (Maya, if applicable)
- [ ] Performance review passed (Victor, if applicable)
- [ ] All review findings documented with specific fixes

## Failure Report Format
- Exact repro steps (commands, inputs, expected vs actual)
- Logs/screenshots/test output
- Specific files/lines needing fixes
- Severity: blocker / warning

## Handoff Target
- Olivia (API/integration/E2E tests) → Ethan (deploy) → Isabella (docs + biz validation)
