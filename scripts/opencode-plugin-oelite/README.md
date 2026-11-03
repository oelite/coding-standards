# opencode-plugin-oelite

Wire `coding-standards/scripts/hooks/oelite-guard.sh` into OpenCode so it
enforces the same machine-enforced hard gates as Claude Code.

Lives at `coding-standards/scripts/opencode-plugin-oelite/` — the canonical
location for OElite tooling. Do **not** place this plugin (or any other
script) directly under the `oelite/` monorepo root: it is a non-git
container and the guard itself blocks root writes.

## What it enforces

| Gate | Behaviour |
|---|---|
| **A. Root-write** | Blocks Write/Edit/Bash when the target is under the OElite root but not inside a scoped git sub-repo. `.claude/` and `.opencode/` are auto-allowed. |
| **B. Worktree-presence** | Blocks edits inside a scoped git repo unless they live under `.worktrees/`. Forces the worktree-first workflow. |
| **C. Protected-branch** | Blocks edits in worktrees whose branch is `develop`, `main`, or `master`. |
| **D. Issue-IID / Scope** | Advisory only. When a worktree has `.oe-scope`, the plugin surfaces its declared scope in block messages. |

Human bypass: `OELITE_HUMAN=1` in the environment (same convention as the
pre-commit hook).

## Install

The plugin is referenced from the root `.opencode/opencode.json` (the only
file that should live in the oelite root besides `.claude/`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit":  { "*": "ask" },
    "bash":  { "*": "ask", "git push *": "ask", "git commit *": "ask" }
  },
  "plugin": ["../coding-standards/scripts/opencode-plugin-oelite/index.ts"]
}
```

Then run once from the **standards repo** to compile the TypeScript:

```bash
cd coding-standards/scripts/opencode-plugin-oelite
npm install
npm run build
```

Restart OpenCode so it loads the plugin. On `tool.execute.before` for any
mutating tool, the plugin pipes the tool call to `oelite-guard.sh` and
throws if the guard exits with code 2.

## Path resolution

The plugin looks for the guard at:
- `$OELITE_GUARD_PATH` if set
- `<project root>/coding-standards/scripts/hooks/oelite-guard.sh` otherwise

`<project root>` is `$OPENCODE_PROJECT_DIR` when running inside OpenCode;
falling back to `process.cwd()` if that env var is not set. The plugin
also walks up from the resolved root to find `coding-standards/` — this
matters when OpenCode is launched from inside a sub-repo or a worktree.

If your standards repo lives elsewhere, set `OELITE_GUARD_PATH` in the
OpenCode launch environment.

## Adding it to a new developer machine

1. `git pull` (picks up `coding-standards/scripts/opencode-plugin-oelite/`)
2. `cd coding-standards/scripts/opencode-plugin-oelite && npm install && npm run build`
3. Launch OpenCode — the guard fires automatically.

For multi-machine parity, commit `package-lock.json` and `dist/index.js`
(the build artefact) so users don't need a Node toolchain.