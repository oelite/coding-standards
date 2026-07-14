# Task Pack: Documentation

## Who Loads This
Isabella (primary), Emma (requirements reference)

## Standards to Read (via tools)
- `coding-standards/6_documentation_standards/DOC-STANDARDS.md`
- `coding-standards/0_project_planning_standards/`
- Target repo `README.md`

## Documentation Outputs

### 1. Business Requirements
- BRD.md
- SRS.md
- User stories: `docs/business/user-stories/US-XXX.md` with GIVEN/WHEN/THEN acceptance criteria
- Process flows: `docs/business/process-flows/`

### 2. Technical Documentation
- Architecture: `docs/technical/architecture/ARCHITECTURE.md` + ADRs
- API docs: `docs/technical/api/API.md` + `endpoints/` + `openapi.yaml`
- Data model: `docs/technical/data/DATA-MODEL.md` + `entities/` + `migrations/`
- Configuration: `docs/technical/configuration/CONFIG.md` + env-vars + app-settings
- Deployment: `docs/technical/deployment/DEPLOYMENT.md` + docker/ + kubernetes/

### 3. User Guides
- `docs/user-guides/USER-GUIDES.md` (index)
- `docs/user-guides/getting-started/quickstart.md`
- `docs/user-guides/admin/admin-guide.md` + Playwright screenshots
- `docs/user-guides/end-user/user-guide.md` + Playwright screenshots
- `docs/user-guides/troubleshooting/TROUBLESHOOTING.md` + FAQ

### 4. Releases
- `docs/releases/CHANGELOG.md`
- `docs/releases/release-notes/vX.Y.Z.md`
- `docs/releases/migration-guides/migrate-v1-to-v2.md`

### 5. Onboarding
- `docs/onboarding/ONBOARDING.md`
- `docs/onboarding/developer-setup.md`
- `docs/onboarding/glossary.md`

## README Requirements
- Concise overview (1-2 paragraphs)
- Quick start guide
- Tech stack summary (table)
- Build/test/run commands
- Documentation index linking to all docs
- README must NOT contain: detailed API endpoints, architecture deep-dives, security specs, deployment procedures

## Playwright Screenshots
- User guides MUST include actual UI screenshots
- Never mockups or placeholders
- Update screenshots when UI changes

## Documentation Triggers (When to Update)
- New repo added
- Repo deprecated
- Stack change
- Build/test/health command changes
- New OElite framework pattern
- Repo starts/stops using OElite patterns
- New coding standard
- `.ai/standards/` changed
- Health endpoint path/port changes
- New feature implemented
- New release deployed

## Verification Checklist
- [ ] Standard header format on every doc
- [ ] BRD/SRS/user stories updated BEFORE development starts if requirements changed
- [ ] API docs updated for every endpoint change
- [ ] User guides include Playwright screenshots
- [ ] README links to all docs
- [ ] CHANGELOG/release notes updated
- [ ] Documentation debt tracked

## Handoff Target
- Back to Emma for development planning if requirements were updated, or to Project Complete if final validation passed
