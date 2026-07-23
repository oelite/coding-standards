# Task Pack: Planning

## Who Loads This
Emma, Marcus, Jonathan, Isabella (and anyone doing planning/architecture tasks)

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
- `coding-standards/0_project_planning_standards/` — all 6 templates
- `coding-standards/rulespec_checklist.md`
- `coding-standards/5_git_workflow_standards/TASK-TEMPLATES.md`
- `coding-standards/6_documentation_standards/DOC-STANDARDS.md`

## Required Outputs
- Atomic task list with explicit success criteria
- Role assignment per task
- Dependency mapping
- Cross-document consistency: BRD ↔ SRS ↔ data schema ↔ API design ↔ implementation plan
- If requirements new/changed: Isabella must update BRD, SRS, technical docs, config docs, user guides BEFORE development begins

## Workflow
1. Emma receives request → clarifies requirements, resolves ambiguity
2. Emma notifies Isabella if requirements new/changed
3. Isabella updates docs (BRD, SRS, technical, config, user guides)
4. Marcus reviews architecture/API contracts
5. Plan approved → hand off to Daniel (backend) / Sophia (frontend) / Ethan (infra)

## Handoff Targets
- Backend planning → Daniel (backend-impl)
- Frontend planning → Jonathan (design spec) → Sophia (frontend-impl)
- Infrastructure planning → Ethan (infrastructure)
- Architecture planning → Marcus (architecture)
- Documentation planning → Isabella (documentation)

## Verification Checklist
- [ ] Every plan item is atomic with explicit success criteria
- [ ] Each task names a responsible role
- [ ] Plan references real files/endpoints
- [ ] Cross-document consistency verified
- [ ] Isabella notified if requirements changed
