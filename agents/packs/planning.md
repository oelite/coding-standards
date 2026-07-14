# Task Pack: Planning

## Who Loads This
Emma, Marcus, Jonathan, Isabella (and anyone doing planning/architecture tasks)

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
