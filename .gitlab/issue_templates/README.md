# GitLab Issue Templates

> **⚠️ ONE-TIME REPO SETUP ONLY**: These files are for repository initialization. 
> Do NOT copy or create `.gitlab/issue_templates/` files during feature implementation.
> 
> To create a new issue ticket, use the CLI:
> ```bash
> ../../coding-standards/scripts/oelite-gitlab.sh issue-create <project> <agent> "<title>" "<description>"
> ```

These templates are the golden standard for all OElite repositories.

## Usage

Copy the `.gitlab/issue_templates/` and `.gitlab/merge_request_templates/` directories into each OElite repo during **initial setup only**, or configure GitLab to use a shared template repository.

## Templates

- `Feature.md` — New features and enhancements
- `Bug.md` — Bug reports and fixes
- `Task.md` — Technical tasks, refactors, documentation work, and tooling changes
- `Default.md` (in `merge_request_templates/`) — Standard MR template

For the detailed specification of each template, see `coding-standards/5_git_workflow_standards/ISSUE-MR-TEMPLATES.md` in the `oelite/coding-standards` repository.

## Target Branch

Unless a repo specifically documents otherwise in its `AGENTS.md`, MRs must target the `develop` branch.
