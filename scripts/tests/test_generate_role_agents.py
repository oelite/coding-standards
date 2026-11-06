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

    def _write_canonical_roles(self) -> None:
        for role_name in sorted({Path(filename).stem for filename in generator.CANONICAL_ROLE_FILENAMES}):
            body = f"# Role: {role_name.title()} — Role {role_name.title()}\nbody\n"
            self.add_role(role_name, body)

    def _write_all_roles(self, extra_role_names: list[str] | None = None) -> None:
        self._write_canonical_roles()
        for role_name in extra_role_names or []:
            body = f"# Role: {role_name.title()} — Extra role\nbody\n"
            self.add_role(role_name, body)

    def test_generates_both_hosts_for_each_canonical_role_and_preserves_body(self) -> None:
        self._write_canonical_roles()
        role_name = "daniel"
        role_body = f"# Role: {role_name.title()} — Test Role\n\n## Heading\n\n```text\n---\nmode: invalid\n```\n"
        self.add_role(role_name, role_body)

        outputs = generator.generated_files(self.source_root)

        self.assertEqual(24, len(outputs))
        opencode = outputs[Path(".opencode/agents/daniel.md")]
        claude = outputs[Path(".claude/agents/daniel.md")]
        self.assertIn('description: "Daniel: Test Role"', opencode)
        self.assertIn("mode: subagent", opencode)
        self.assertNotIn("mode:", claude.split("---", 2)[1])
        self.assertTrue(opencode.endswith(role_body))
        self.assertTrue(claude.endswith(role_body))

    def test_generation_is_deterministic(self) -> None:
        self._write_canonical_roles()

        first = generator.generated_files(self.source_root)
        second = generator.generated_files(self.source_root)

        self.assertEqual(first, second)
        self.assertEqual(sorted(first), sorted(second))

    def test_canonical_role_coverage_requires_all_canonical_roles(self) -> None:
        with self.assertRaises(ValueError) as context:
            self.add_role("emma", "# Role: Emma — Coordinator\nbody\n")
            generator.generated_files(self.source_root)

        self.assertIn("missing roles", str(context.exception))

    def test_generation_rejects_unexpected_role_files(self) -> None:
        self._write_all_roles(["test"])

        with self.assertRaises(ValueError) as context:
            generator.generated_files(self.source_root)

        self.assertIn("unexpected roles", str(context.exception))

    def test_generation_rejects_missing_canonical_role_before_writing(self) -> None:
        canonical_names = {Path(filename).stem for filename in generator.CANONICAL_ROLE_FILENAMES}
        for role_name in sorted(canonical_names):
            if role_name != "daniel":
                self.add_role(role_name, f"# Role: {role_name.title()} — Role\nbody\n")

        self.target_root.mkdir(parents=True)
        captured_stderr = io.StringIO()
        with contextlib.redirect_stderr(captured_stderr):
            result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root)]
            )

        self.assertEqual(2, result)
        self.assertIn("missing roles: daniel.md", captured_stderr.getvalue())

    def test_generation_rejects_symlinked_output_directory_escape(self) -> None:
        self._write_canonical_roles()
        outside = self.root / "outside"
        outside.mkdir()
        target_agents = self.target_root / ".claude" / "agents"
        target_agents.parent.mkdir(parents=True)
        target_agents.symlink_to(outside, target_is_directory=True)

        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root)]
            )

        self.assertEqual(2, result)
        self.assertIn("symlinked output path", stderr.getvalue())
        self.assertEqual([], list(outside.iterdir()))

    def test_check_mode_reports_missing_and_stale_paths_without_writing(self) -> None:
        self._write_canonical_roles()
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            missing_result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root), "--check"]
            )
        self.assertEqual(1, missing_result)
        self.assertIn(str(self.target_root / ".claude/agents/daniel.md"), stdout.getvalue())
        self.assertFalse(self.target_root.exists())

        generated = generator.generated_files(self.source_root)
        for relative_path, content in generated.items():
            destination = self.target_root / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(content, encoding="utf-8")
        stale_file = self.target_root / ".claude/agents/daniel.md"
        stale_file.write_text("stale\n", encoding="utf-8")
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            stale_result = generator.main(
                ["--source-root", str(self.source_root), "--target-root", str(self.target_root), "--check"]
            )
        self.assertEqual(1, stale_result)
        self.assertIn(str(stale_file), stdout.getvalue())
        self.assertEqual("stale\n", stale_file.read_text(encoding="utf-8"))

    def test_generation_and_clean_check(self) -> None:
        self._write_canonical_roles()

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
        self.assertEqual(
            2 * len(generator.CANONICAL_ROLE_FILENAMES),
            len(list(self.target_root.rglob("*.md"))),
        )


if __name__ == "__main__":
    unittest.main()
