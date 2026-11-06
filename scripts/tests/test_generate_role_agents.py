from __future__ import annotations

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parents[1] / "generate-role-agents.py"
SPEC = importlib.util.spec_from_file_location("generate_role_agents", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


class GenerateRoleAgentsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.source_root = self.root / "standards"
        self.roles_dir = self.source_root / "agents" / "roles"
        self.roles_dir.mkdir(parents=True)
        self.target_root = self.root / "target"

    def add_role(self, name: str, body: str) -> Path:
        role = self.roles_dir / f"{name}.md"
        role.write_text(body, encoding="utf-8")
        return role

    def test_generates_both_hosts_for_each_source_role_and_preserves_body(self) -> None:
        role_body = "# Role: Test — Test Role\n\n## Heading\n\n```text\n---\nmode: invalid\n```\n"
        self.add_role("test", role_body)

        outputs = generator.generated_files(self.source_root)

        self.assertEqual(
            {Path(".opencode/agents/test.md"), Path(".claude/agents/test.md")},
            set(outputs),
        )
        opencode = outputs[Path(".opencode/agents/test.md")]
        claude = outputs[Path(".claude/agents/test.md")]
        self.assertIn('description: "Test: Test Role"', opencode)
        self.assertIn("mode: subagent", opencode)
        self.assertNotIn("mode:", claude.split("---", 2)[1])
        self.assertTrue(opencode.endswith(role_body))
        self.assertTrue(claude.endswith(role_body))

    def test_generation_is_deterministic(self) -> None:
        self.add_role("zeta", "# Role: Zeta — Role\nbody\n")
        self.add_role("alpha", "# Role: Alpha — Role\nbody\n")

        first = generator.generated_files(self.source_root)
        second = generator.generated_files(self.source_root)

        self.assertEqual(first, second)
        self.assertEqual(sorted(first), sorted(second))

    def test_check_mode_reports_missing_and_stale_paths_without_writing(self) -> None:
        role = self.add_role("emma", "# Role: Emma — Coordinator\nbody\n")
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            missing_result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root), "--check"]
            )
        self.assertEqual(1, missing_result)
        self.assertIn(str(self.target_root / ".claude/agents/emma.md"), stdout.getvalue())
        self.assertFalse(self.target_root.exists())

        generated = generator.generated_files(self.source_root)
        for relative_path, content in generated.items():
            destination = self.target_root / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content, encoding="utf-8")
        stale_file = self.target_root / ".claude/agents/emma.md"
        stale_file.write_text("stale\n", encoding="utf-8")
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            stale_result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root), "--check"]
            )
        self.assertEqual(1, stale_result)
        self.assertIn(str(stale_file), stdout.getvalue())
        self.assertEqual("stale\n", stale_file.read_text(encoding="utf-8"))
        self.assertTrue(role.is_file())

    def test_generation_and_clean_check(self) -> None:
        self.add_role("isabella", "# Role: Isabella — Documentation\nbody\n")

        self.assertEqual(
            0,
            generator.main(["--source-root", str(self.source_root), "--target-root", str(self.target_root)]),
        )
        self.assertEqual(
            0,
            generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root), "--check"]
            ),
        )
        self.assertEqual(2, len(list(self.target_root.rglob("*.md"))))


if __name__ == "__main__":
    unittest.main()
