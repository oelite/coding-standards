# OElite Coding Standards - Master Index

**Last Updated**: June 2026
**Authoritative Source**: This `/coding-standards/` directory is the SINGLE SOURCE OF TRUTH for all OElite coding standards.

---

## 📚 Standards Structure

```
coding-standards/
├── README.md                              # This file - master index
├── rulespec_checklist.md                  # AI agent project bootstrapping guide
│
├── 0_project_planning_standards/          # Project specification templates
│   ├── 0.0_team_tech_stack_template.md
│   ├── 0.1_business_requirement_template.md
│   ├── 0.2_software_requirement_template.md
│   ├── 0.3_project_data_schema_template.md
│   ├── 0.4_api_design_template.md
│   └── 0.5_project_implementation_plan_template.md
│
├── 1_dotNet_coding_standards/             # .NET C# Backend Standards (13 files)
│   ├── 01-PROJECT-ARCHITECTURE.md         # N-tier architecture, domain organization
│   ├── 02-FUNCTIONAL-REQUIREMENTS-DRIVEN-DEVELOPMENT.md
│   ├── 03-DEPENDENCY-INJECTION.md         # OElite.Restme, OElite.Common.Hosting
│   ├── 04-DATABASE-ENTITIES.md            # BaseEntity, denormalized fields, MongoDB-free
│   ├── 05-APPLICATION-LIFECYCLE.md        # OeWebApp, OeHybridApp, OeConsoleApp
│   ├── 06-API-RESPONSE-PATTERNS.md        # OEliteApiOutputFormatter, ModelTransformation
│   ├── 07-CONFIGURATION-MANAGEMENT.md     # configs-only pattern, BaseAppConfig
│   ├── 09-NAMING-CONVENTIONS.md           # snake_case DB, PascalCase C#
│   ├── 10-OELITE-RESTME-HOSTING-GUIDE.md  # IDistributedCache/IMemoryCache adapters
│   ├── 11-OELITE-HOSTING-GUIDE.md         # One-line startup, auto-discovery
│   ├── 12-ENTITY-COLLECTION-PATTERNS.md   # BaseEntityCollection<T>, DataCollection<T>
│   └── 13-OELITE-RESTME-UNIFIED-GUIDE.md  # Unified data operations
│
├── 2_general_web_coding_standards/        # General web development standards
│   └── README.md
│
├── 3_angular_coding_standards/            # Angular Standards (ec-std-01)
│   └── 11-ANGULAR-CODING-STANDARDS.md     # Mobile-first, Bootstrap, No-Mock-Data Policy
│
├── 4_react_nextjs_coding_standards/       # Next.js Standards (ec-nx-01)
│   └── 12-NEXTJS-CODING-STANDARDS.md      # App Router, Tailwind, server/client components
│
├── 5_git_workflow_standards/              # Git workflow, worktree, issue lifecycle, task templates
│   ├── GIT-WORKFLOW-STANDARDS.md          # Main GitLab MR-centric workflow
│   ├── WORKTREE-OWNER-DNA.md              # Commit attribution protocol
│   ├── TASK-TEMPLATES.md                  # Task creation, bug fix, DoR, DoD
│   └── ISSUE-MR-TEMPLATES.md              # GitLab issue and MR templates
│
├── 6_documentation_standards/             # Documentation templates
│   └── DOC-STANDARDS.md                   # BRD, SRS, User Story, README, User Guide templates
│
└── .gitlab/                               # GitLab golden-standard templates
    ├── issue_templates/                   # Feature, Bug, Task issue templates
    └── merge_request_templates/           # Default MR template
```

---

## 🚨 AGENTS.md

`AGENTS.md` is maintained inside this repository as the authoritative team workflow guide.
A symlink at the OElite root directory points to `coding-standards/AGENTS.md` so agentic sessions
continue to discover it at the expected location. See the file itself for full role definitions,
workflow chains, and mandatory verification steps.

## 🔥 CRITICAL UPDATES (November 2025)

### .NET Standards - Latest Additions

| Standard | Key Update | Impact |
|----------|------------|--------|
| **04-DATABASE-ENTITIES.md** | MongoDB-Free Application Layer v2.1.0 | Zero vendor lock-in, pure .NET types |
| **10-OELITE-RESTME-HOSTING-GUIDE.md** | IDistributedCache/IMemoryCache adapters | Standard .NET caching interfaces |
| **11-OELITE-HOSTING-GUIDE.md** | OeApp.RunWebAppAsync one-line startup | Streamlined application initialization |
| **12-ENTITY-COLLECTION-PATTERNS.md** | BaseEntityCollection<T> standards | Strongly-typed collection patterns |
| **02-FUNCTIONAL-REQUIREMENTS-DRIVEN-DEVELOPMENT.md** | Formalized 6-step process | Mandatory requirements-first flow |

### Angular Standards - Latest Additions

| Standard | Key Update | Impact |
|----------|------------|--------|
| **11-ANGULAR-CODING-STANDARDS.md** | No-Mock-Data Policy | ZERO tolerance for fake/mock data |
| | Mobile-First Mandate | All components designed mobile-first |
| | Domain Library Structure | NPM-package-ready organization |

---

## 🎯 AI TOOL INTEGRATION

### For OpenCode Users

The OElite standards are automatically loaded via `.opencode/` configuration in the project root.

**To use**: Simply reference "OElite coding standards" in your prompts.

### For Claude Code Users

The OElite standards are automatically applied via `.cursor/rules/oelite-standards.mdc` rule.

**To use**: Simply reference "OElite coding standards" or "coding standards" in your prompts.

---

## 📋 Quick Reference - Key Standards

### .NET Backend

| Area | Standard File | Key Requirement |
|------|---------------|-----------------|
| Architecture | 01-PROJECT-ARCHITECTURE.md | Domain-based folder organization |
| Development Flow | 02-FUNCTIONAL-REQUIREMENTS-DRIVEN-DEVELOPMENT.md | UI Operations → API → Entity → Service → Repository |
| Dependency Injection | 03-DEPENDENCY-INJECTION.md | OElite.Restme for data, IMemoryCache/IDistributedCache for caching |
| Database Entities | 04-DATABASE-ENTITIES.md | BaseEntity inheritance, snake_case collections/fields |
| Application Lifecycle | 05-APPLICATION-LIFECYCLE.md | OeWebApp/OeHybridApp/OeConsoleApp runners |
| API Responses | 06-API-RESPONSE-PATTERNS.md | OEliteApiOutputFormatter, ModelTransformation |
| Configuration | 07-CONFIGURATION-MANAGEMENT.md | configs-only pattern, BaseAppConfig inheritance |
| Naming | 09-NAMING-CONVENTIONS.md | snake_case DB, PascalCase C# |
| Caching | 10-OELITE-RESTME-HOSTING-GUIDE.md | Grace period caching, background refresh |
| Hosting | 11-OELITE-HOSTING-GUIDE.md | Auto-discovery, one-line startup |
| Collections | 12-ENTITY-COLLECTION-PATTERNS.md | BaseEntityCollection<T>, DataCollection<T> |
| Restme | 13-OELITE-RESTME-UNIFIED-GUIDE.md | Unified HTTP, caching, storage, messaging, database |

### Frontend

| Technology | Standard File | Key Requirements |
|------------|---------------|------------------|
| Angular (ec-std-01) | 11-ANGULAR-CODING-STANDARDS.md | Mobile-first, Bootstrap 4, No-Mock-Data, SSR, i18n |
| Next.js (ec-nx-01) | 12-NEXTJS-CODING-STANDARDS.md | App Router, Tailwind CSS, server/client components, SWR |

### Task & Documentation Templates

| Template | Location | Purpose |
|----------|----------|---------|
| Task / Bug / Sprint | `5_git_workflow_standards/TASK-TEMPLATES.md` | Task creation, bug fixes, Definition of Ready/Done |
| GitLab Issue / MR | `5_git_workflow_standards/ISSUE-MR-TEMPLATES.md` | Reference templates for `.gitlab/` folders |
| Documentation | `6_documentation_standards/DOC-STANDARDS.md` | BRD, SRS, User Story, README, User Guide templates |

---

## 🚨 NON-NEGOTIABLE RULES

### Backend (.NET)

1. **ALL entities** MUST inherit from `BaseEntity`
2. **ALL collections** MUST use snake_case naming: `[DbCollection("product_categories")]`
3. **ALL repositories** MUST implement 4 core CRUD methods
4. **NO business logic** in repositories - data access only
5. **configs-only pattern** - NO traditional appsettings.json
6. **OEliteApiOutputFormatter** for ALL API responses
7. **Domain-based organization** - OElite.Common/{Domain}/

### Frontend (Angular/Next.js)

1. **NO MOCK DATA** - ZERO tolerance for fake/hard-coded values
2. **Mobile-first** - ALL components designed for mobile first
3. **Reusable components** - Generic, modular design mandatory
4. **No hard-coding** - Centralized configuration classes
5. **Proper error states** - Show errors, never fallback to mock data

---

## 📖 Standards Maintenance

### Update Process

1. **All updates** go to `/coding-standards/` FIRST
2. **Sync to** `/uranus/arc-agents/standards/` for backward compatibility
3. **Update** AI tool configurations if standards change significantly
4. **Document** changes in this README

### Version History

| Date | Update |
|------|--------|
| Jun 2026 | Extracted documentation templates to `6_documentation_standards/DOC-STANDARDS.md`; added `TASK-TEMPLATES.md` and `ISSUE-MR-TEMPLATES.md` for task/MR creation |
| Nov 2025 | MongoDB-Free v2.1.0, No-Mock-Data Policy, Restme.Hosting |
| Nov 2025 | Entity Collection Patterns standard |
| Nov 2025 | Application Lifecycle standard |
| Nov 2025 | Functional Requirements-Driven Development formalized |

---

## 🔗 Related Documentation

- **CLAUDE.md** - Project-specific AI instructions
- **.cursor/rules/oelite-standards.mdc** - Claude Code rules
- **.opencode/** - OpenCode configuration
- **uranus/arc-agents/standards/** - Mirror copy for backward compatibility

---

**For AI Tools**: When the user references "OElite coding standards" or "coding standards", you MUST read and follow the standards in this directory. Start by reading the relevant standard file for the technology being used.
