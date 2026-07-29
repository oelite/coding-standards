/**
 * OElite Guard Plugin for OpenCode
 *
 * Wires `oelite-guard.sh` into OpenCode's `tool.execute.before` hook so that
 * OpenCode enforces the same hard gates as Claude Code:
 *   A. Root-write block
 *   B. Worktree-presence (edits must be inside .worktrees/<agent>-<iid>/)
 *   C. Protected-branch (develop/main/master)
 *   D. Issue-IID via .oe-scope (advisory)
 *
 * On block, the plugin throws with the guard's stderr message — OpenCode
 * surfaces the error to the agent and aborts the tool call.
 *
 * Human bypass: set OELITE_HUMAN=1 in the env.
 *
 * The plugin resolves the guard script relative to the project root using
 * the well-known path `<root>/coding-standards/scripts/hooks/oelite-guard.sh`.
 * Override via OELITE_GUARD_PATH if your standards repo lives elsewhere.
 */
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
const TOOLS_THAT_MUTATE = new Set([
    "edit",
    "write",
    "patch",
    "multiedit",
    "bash",
]);
/** Resolve the absolute path to oelite-guard.sh. */
function resolveGuardPath(projectRoot) {
    const override = process.env.OELITE_GUARD_PATH;
    if (override && existsSync(override))
        return override;
    const candidate = resolve(projectRoot, "coding-standards/scripts/hooks/oelite-guard.sh");
    if (existsSync(candidate))
        return candidate;
    throw new Error(`oelite-guard.sh not found at ${candidate}. ` +
        `Set OELITE_GUARD_PATH or ensure coding-standards/ is at the project root.`);
}
/**
 * Translate OpenCode's `tool.execute.before` payload into the JSON shape the
 * guard script expects (Claude Code's PreToolUse format), then exec the guard.
 *
 * @throws Error when the guard exits with code 2 (block). The error message
 *         is the guard's stderr so the agent sees the full diagnostic.
 */
function runGuard(guardPath, tool, args) {
    if (process.env.OELITE_HUMAN === "1")
        return;
    let payload;
    switch (tool) {
        case "edit":
        case "write":
        case "patch":
        case "multiedit":
            payload = {
                tool_name: "Write",
                tool_input: { file_path: args.filePath ?? args.file_path },
            };
            break;
        case "bash":
            payload = {
                tool_name: "Bash",
                tool_input: { command: args.command },
            };
            break;
        default:
            return;
    }
    const result = spawnSync("bash", [guardPath], {
        input: JSON.stringify(payload),
        encoding: "utf8",
        stdio: ["pipe", "inherit", "pipe"],
    });
    if (result.status === 2) {
        throw new Error(result.stderr || "OElite guard blocked the tool call.");
    }
}
const OEliteGuard = async (_ctx) => ({
    "tool.execute.before": async (input, output) => {
        if (!TOOLS_THAT_MUTATE.has(input.tool))
            return;
        const projectRoot = process.env.OPENCODE_PROJECT_DIR || process.cwd();
        const guardPath = resolveGuardPath(projectRoot);
        runGuard(guardPath, input.tool, output.args);
    },
});
export const OEliteGuardPlugin = OEliteGuard;
export default OEliteGuard;
