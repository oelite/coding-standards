#!/usr/bin/env python3
"""Exercise production command with transport doubles; never contact GitLab."""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).parents[2]
WRAPPER = (ROOT / "scripts/oelite-gitlab.sh").read_text()
COMMAND = WRAPPER.split("cmd_mr_pipeline_create() {", 1)[1].split("\ncmd_pipeline_run()", 1)[0]


class CommandTests(unittest.TestCase):
    def run_command(self, mode):
        sha = "a" * 40
        mr = {"iid": 1268, "project_id": 102, "source_project_id": 102,
              "target_project_id": 102, "state": "opened", "sha": sha,
              "source_branch": "feature/test", "diff_refs": {"head_sha": sha}}
        project = {"id": 102, "ssh_url_to_repo": "git@code.phanes.ltd:oelite/test.git"}
        pipeline = {"id": 42, "sha": sha, "source": "merge_request_event",
                    "ref": "refs/merge-requests/1268/head", "status": "created"}
        prelude = '''
set -euo pipefail
validate_agent() { [[ "$1" == ethan ]]; }
get_pat() { print test-transport-not-a-credential; }
url_encode_path() { print "$1"; }
api_error_hint() { :; }
json_scalar() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"; }
api_get() {
  _API_STATUS=200
  if [[ "$1" == */merge_requests/* ]]; then
    _API_RESPONSE="$MR"
    if [[ "$MODE" == drift && "$POSTED" == yes ]]; then
      _API_RESPONSE="${MR//aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}"
    fi
  else
    _API_RESPONSE="$PROJECT"
  fi
}
api_post() {
  print "POST:$1"
  POSTED=yes
  _API_STATUS=201
  _API_RESPONSE="$PIPELINE"
  if [[ "$MODE" == error ]]; then _API_STATUS=422; _API_RESPONSE='{"message":"rejected"}'; fi
}
git() {
  if [[ "$MODE" == git-error ]]; then return 1; fi
  print 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/heads/feature/test'
  if [[ "$MODE" != stale ]]; then
    print 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\trefs/merge-requests/1268/head'
  fi
}
POSTED=no
'''
        assignments = "\n".join(key + "='" + value + "'" for key, value in {
            "MR": json.dumps(mr), "PROJECT": json.dumps(project), "PIPELINE": json.dumps(pipeline),
            "MODE": mode, "SCRIPT_DIR": str(ROOT / "scripts")}.items())
        script = prelude + assignments + "\ncmd_mr_pipeline_create() {" + COMMAND
        script += "\ncmd_mr_pipeline_create oelite/test 1268 ethan\n"
        return subprocess.run(["zsh", "-c", script], text=True, capture_output=True)

    def test_success(self):
        result = self.run_command("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout.count("POST:"), 1)
        self.assertIn("POST:/projects/oelite/test/merge_requests/1268/pipelines", result.stdout)
        self.assertIn("source: merge_request_event", result.stdout)
        self.assertIn("head reverified", result.stdout)

    def test_precondition_failures_never_post(self):
        for mode in ("stale", "git-error"):
            result = self.run_command(mode)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("POST:", result.stdout)

    def test_api_error_is_not_retried(self):
        result = self.run_command("error")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count("POST:"), 1)
        self.assertIn("HTTP 422", result.stderr)
        self.assertIn("rejected", result.stderr)

    def test_concurrent_push_fails_closed(self):
        result = self.run_command("drift")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.count("POST:"), 1)
        self.assertNotIn("head reverified", result.stdout)


if __name__ == "__main__":
    unittest.main()
