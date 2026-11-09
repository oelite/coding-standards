#!/usr/bin/env python3
"""Exercise mr-update argument encoding without credentials or network calls."""
import json
import subprocess
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/oelite-gitlab.sh"


class MrUpdateTargetTests(unittest.TestCase):
    def payload(self, title="", description="", target=None):
        source = SCRIPT.read_text()
        function = source.split("cmd_mr_update() {", 1)[1].split("\n}\n", 1)[0]
        harness = """
validate_agent() { return 0; }
url_encode_path() { printf '%s' "$1"; }
get_pat() { printf 'unused'; }
api_put() { printf '%s\\n' "$3"; _API_STATUS=200; }
cmd_mr_update() {
""" + function + "\n}\ncmd_mr_update \"$@\"\n"
        args = ["zsh", "-c", harness, "test", "oelite/uranus/orion", "124", "ethan", title, description]
        if target is not None:
            args.append(target)
        result = subprocess.run(args, text=True, capture_output=True, check=True)
        return json.loads(result.stdout.splitlines()[0])

    def test_existing_title_description_call(self):
        self.assertEqual(self.payload("title", "description"), {"title": "title", "description": "description"})

    def test_retarget_preserves_other_fields(self):
        self.assertEqual(self.payload(target="develop"), {"target_branch": "develop"})

    def test_empty_target_is_omitted(self):
        self.assertEqual(self.payload(target=""), {})

    def test_values_are_literal(self):
        title = "don't expand $HOME or `id`"
        description = "first line\nsecond 'quoted' line\\n"
        target = "feature/triple'''quote-$HOME-`id`"
        self.assertEqual(self.payload(title, description, target), {
            "title": title, "description": description, "target_branch": target,
        })


if __name__ == "__main__":
    unittest.main()
