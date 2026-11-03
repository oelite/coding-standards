#!/usr/bin/env python3
"""Regression tests for oelite-gitlab.sh pipeline and CI/CD admin commands."""

import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "oelite-gitlab.sh"
ENV_SCRIPT = REPO / "scripts" / "oelite-gitlab-env.sh"

FAKE_SECURITY = r'''#!/bin/sh
if [ "$1" = "find-generic-password" ]; then
  printf 'fake-pat-%s' "$3"
  exit 0
fi
exit 1
'''

FAKE_CURL = r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
method = "GET"
output = None
url = ""
body = ""
i = 0
while i < len(args):
    arg = args[i]
    if arg == "--request":
        method = args[i + 1]
        i += 2
    elif arg == "-o":
        output = args[i + 1]
        i += 2
    elif arg == "--data-binary":
        body = sys.stdin.read()
        i += 2
    elif arg.startswith("http"):
        url = arg
        i += 1
    else:
        i += 1
path = url.split("/api/v4", 1)[-1]
request = {"method": method, "path": path, "body": body}
with open(os.environ["FAKE_REQUEST_LOG"], "a", encoding="utf-8") as stream:
    stream.write(json.dumps(request) + "\n")
key = method + " " + path
routes = json.loads(os.environ.get("FAKE_API_ROUTES", "{}"))
result = routes.get(key, {"status": 200, "response": {"id": 11, "path_with_namespace": "oelite/source"}})
response = result.get("response", {})
if isinstance(response, (dict, list)):
    response = json.dumps(response)
if output:
    with open(output, "w", encoding="utf-8") as stream:
        stream.write(str(response))
print(result.get("status", 200), end="")
'''


class GitLabAdminCommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        (self.root / "scripts" / "oelite-gitlab.sh").write_text(SCRIPT.read_text())
        (self.root / "scripts" / "oelite-gitlab-env.sh").write_text(ENV_SCRIPT.read_text())
        self.bin = self.root / "bin"
        self.bin.mkdir()
        security = self.bin / "security"
        security.write_text(FAKE_SECURITY)
        security.chmod(0o755)
        curl = self.bin / "curl"
        curl.write_text(FAKE_CURL)
        curl.chmod(0o755)
        self.request_log = self.root / "requests.jsonl"

    def tearDown(self):
        self.temp.cleanup()

    def run_command(self, *args, routes=None):
        env = os.environ.copy()
        env.update({
            "PATH": str(self.bin) + os.pathsep + env.get("PATH", ""),
            "OELITE_VALIDATE_PATS": "false",
            "FAKE_REQUEST_LOG": str(self.request_log),
            "FAKE_API_ROUTES": json.dumps(routes or {}),
        })
        completed = subprocess.run(
            ["zsh", str(self.root / "scripts" / "oelite-gitlab.sh"), *args],
            cwd=self.root,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        requests = []
        if self.request_log.exists():
            requests = [json.loads(line) for line in self.request_log.read_text().splitlines()]
            self.request_log.unlink()
        return completed, requests

    @staticmethod
    def project_get(path, project_id):
        return ("GET " + path, {"status": 200, "response": {"id": project_id}})

    def allowlist_routes(self, status=201, response=None, path_form_status=None):
        source_path = "/projects/oelite%2Fsource"
        target_path = "/projects/oelite%2Ftarget"
        routes = {
            **dict([self.project_get(source_path, 11)]),
            **dict([self.project_get(target_path, 22)]),
            "POST /projects/11/job_token_scope/allowlist": {
                "status": status,
                "response": response if response is not None else {"source_project_id": 11, "target_project_id": 22},
            },
        }
        if path_form_status is not None:
            routes["POST " + source_path + "/job_token_scope/allowlist"] = {
                "status": path_form_status,
                "response": {"source_project_id": 11, "target_project_id": 22},
            }
        return routes

    def test_allowlist_uses_supported_post_method_path_and_body(self):
        result, requests = self.run_command(
            "job-token-allowlist-add", "oelite/source", "emma", "oelite/target",
            routes=self.allowlist_routes(),
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests[-1], {
            "method": "POST",
            "path": "/projects/11/job_token_scope/allowlist",
            "body": '{"target_project_id":22}',
        })
        self.assertIn("[OK]", result.stdout)

    def test_allowlist_404_and_410_retry_supported_path_endpoint(self):
        for first_status in (404, 410):
            with self.subTest(status=first_status):
                routes = self.allowlist_routes(status=first_status, path_form_status=201)
                result, requests = self.run_command(
                    "job-token-allowlist-add", "oelite/source", "emma", "oelite/target", routes=routes,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(requests[-2]["method"], "POST")
                self.assertEqual(requests[-2]["path"], "/projects/11/job_token_scope/allowlist")
                self.assertEqual(requests[-1]["method"], "POST")
                self.assertEqual(requests[-1]["path"], "/projects/oelite%2Fsource/job_token_scope/allowlist")
                self.assertEqual(json.loads(requests[-1]["body"]), {"target_project_id": 22})

    def test_allowlist_403_and_401_fail_without_fallback_or_token_leak(self):
        for status in (403, 401):
            with self.subTest(status=status):
                result, requests = self.run_command(
                    "job-token-allowlist-add", "oelite/source", "emma", "oelite/target",
                    routes=self.allowlist_routes(status=status),
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(requests), 3)
                self.assertIn("HTTP " + str(status), result.stderr)
                self.assertNotIn("fake-pat", result.stdout + result.stderr)

    def test_allowlist_requires_response_confirmation(self):
        result, _ = self.run_command(
            "job-token-allowlist-add", "oelite/source", "emma", "oelite/target",
            routes=self.allowlist_routes(response={"source_project_id": 11, "target_project_id": 99}),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not confirm", result.stderr)
        self.assertNotIn("[OK]", result.stdout)

    def test_project_permissions_reports_maximum_access(self):
        route = "/projects/oelite%2Fsource"
        result, _ = self.run_command(
            "project-permissions", "oelite/source", "emma",
            routes={"GET " + route: {"status": 200, "response": {
                "path_with_namespace": "oelite/source",
                "permissions": {
                    "project_access": {"access_level": 30},
                    "group_access": {"access_level": 40},
                },
            }}},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Caller access level:  40", result.stdout)

    def test_project_permissions_401_and_403_are_clean(self):
        route = "/projects/oelite%2Fsource"
        for status in (401, 403):
            with self.subTest(status=status):
                result, _ = self.run_command(
                    "project-permissions", "oelite/source", "emma",
                    routes={"GET " + route: {"status": status, "response": {"message": "denied"}}},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("HTTP " + str(status), result.stderr)
                self.assertNotIn("fake-pat", result.stdout + result.stderr)

    def test_code_owner_existing_branch_lists_then_patches_without_access_changes(self):
        list_route = "/projects/oelite%2Fsource/protected_branches"
        patch_route = list_route + "/develop?code_owner_approval_required=true"
        authoritative_route = list_route + "/develop"
        existing = {
            "name": "develop", "code_owner_approval_required": False,
            "allow_force_push": True,
            "push_access_levels": [{"access_level": 30}],
            "merge_access_levels": [{"access_level": 40}],
        }
        result, requests = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + list_route: {"status": 200, "response": [existing]},
                "PATCH " + patch_route: {"status": 200, "response": {
                    **existing, "code_owner_approval_required": False,
                }},
                "GET " + authoritative_route: {"status": 200, "response": {
                    **existing, "code_owner_approval_required": True,
                }},
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests[0]["method"], "GET")
        self.assertEqual(requests[0]["path"], list_route)
        self.assertEqual(requests[1]["method"], "PATCH")
        self.assertEqual(requests[1]["path"], patch_route)
        self.assertEqual(requests[1]["body"], "")
        self.assertEqual(requests[2]["method"], "GET")
        self.assertEqual(requests[2]["path"], authoritative_route)
        self.assertIn("[OK]", result.stdout)

    def test_code_owner_missing_branch_creates_least_privilege_configuration(self):
        list_route = "/projects/oelite%2Fsource/protected_branches"
        create_route = list_route
        authoritative_route = list_route + "/develop"
        result, requests = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + list_route: {"status": 200, "response": []},
                "POST " + create_route: {"status": 201, "response": {
                    "name": "develop", "code_owner_approval_required": False,
                }},
                "GET " + authoritative_route: {"status": 200, "response": {
                    "name": "develop", "code_owner_approval_required": True,
                }},
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests[0]["method"], "GET")
        self.assertEqual(requests[1]["method"], "POST")
        self.assertEqual(json.loads(requests[1]["body"]), {
            "name": "develop", "allow_force_push": False,
            "code_owner_approval_required": True,
            "allowed_to_push": [{"access_level": 0}],
            "allowed_to_merge": [{"access_level": 40}],
            "allowed_to_unprotect": [{"access_level": 40}],
        })
        self.assertEqual(requests[2]["method"], "GET")
        self.assertEqual(requests[2]["path"], authoritative_route)

    def test_code_owner_read_only_single_branch_reports_missing_without_mutation(self):
        route = "/projects/oelite%2Fsource/protected_branches/develop"
        result, requests = self.run_command(
            "protected-branch-show", "oelite/source", "emma", "develop",
            routes={"GET " + route: {"status": 404, "response": {"message": "404 Protected Branch Not Found"}}},
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(requests, [{"method": "GET", "path": route, "body": ""}])
        self.assertIn("HTTP 404", result.stderr)

    def test_code_owner_list_read_only_reports_branch_access_settings(self):
        route = "/projects/oelite%2Fsource/protected_branches"
        result, requests = self.run_command(
            "protected-branches", "oelite/source", "emma",
            routes={"GET " + route: {"status": 200, "response": [{
                "name": "develop", "code_owner_approval_required": False,
                "allow_force_push": False,
                "push_access_levels": [{"access_level_description": "Maintainers"}],
                "merge_access_levels": [{"access_level_description": "Maintainers"}],
            }]}},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests[0]["method"], "GET")
        self.assertIn("develop", result.stdout)
        self.assertIn("Maintainers", result.stdout)

    def test_code_owner_create_failure_does_not_claim_success(self):
        route = "/projects/oelite%2Fsource/protected_branches"
        result, _ = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + route: {"status": 200, "response": []},
                "POST " + route: {"status": 403, "response": {"message": "denied"}},
            },
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 403", result.stderr)
        self.assertNotIn("[OK]", result.stdout)

    def test_code_owner_confirmation_mismatch_fails_after_authoritative_readback(self):
        route = "/projects/oelite%2Fsource/protected_branches/develop"
        patch_route = route + "?code_owner_approval_required=true"
        list_route = "/projects/oelite%2Fsource/protected_branches"
        result, requests = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + list_route: {"status": 200, "response": [{
                    "name": "develop", "code_owner_approval_required": False,
                }]},
                "PATCH " + patch_route: {"status": 200, "response": {"code_owner_approval_required": False}},
                "GET " + route: {"status": 200, "response": {"code_owner_approval_required": False}},
            },
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([request["method"] for request in requests], ["GET", "PATCH", "GET"])
        self.assertIn("read-back did not confirm", result.stderr)
        self.assertNotIn("[OK]", result.stdout)

    def test_code_owner_patch_applies_but_response_omits_field_then_get_confirms(self):
        route = "/projects/oelite%2Fsource/protected_branches/develop"
        patch_route = route + "?code_owner_approval_required=true"
        list_route = "/projects/oelite%2Fsource/protected_branches"
        result, requests = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + list_route: {"status": 200, "response": [{
                    "name": "develop", "code_owner_approval_required": False,
                }]},
                "PATCH " + patch_route: {"status": 200, "response": {"name": "develop"}},
                "GET " + route: {"status": 200, "response": {"code_owner_approval_required": True}},
            },
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([request["method"] for request in requests], ["GET", "PATCH", "GET"])
        self.assertIn("[OK]", result.stdout)

    def test_code_owner_readback_failure_reports_error_without_success(self):
        route = "/projects/oelite%2Fsource/protected_branches/develop"
        patch_route = route + "?code_owner_approval_required=true"
        list_route = "/projects/oelite%2Fsource/protected_branches"
        result, _ = self.run_command(
            "protected-branch-code-owner", "oelite/source", "emma", "develop", "on",
            routes={
                "GET " + list_route: {"status": 200, "response": [{
                    "name": "develop", "code_owner_approval_required": False,
                }]},
                "PATCH " + patch_route: {"status": 200, "response": {"code_owner_approval_required": True}},
                "GET " + route: {"status": 500, "response": {"message": "boom"}},
            },
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 500", result.stderr)
        self.assertNotIn("[OK]", result.stdout)

    def test_pipeline_must_succeed_put_body_and_confirmed_state(self):
        route = "/projects/oelite%2Fsource"
        result, requests = self.run_command(
            "pipeline-must-succeed", "oelite/source", "emma", "on",
            routes={"PUT " + route: {"status": 200, "response": {"only_allow_merge_if_pipeline_succeeds": True}}},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(requests[-1], {
            "method": "PUT", "path": route,
            "body": '{"only_allow_merge_if_pipeline_succeeds":true}',
        })
        self.assertIn("[OK]", result.stdout)

    def test_pipeline_must_succeed_confirmation_mismatch_fails(self):
        route = "/projects/oelite%2Fsource"
        result, _ = self.run_command(
            "pipeline-must-succeed", "oelite/source", "emma", "on",
            routes={"PUT " + route: {"status": 200, "response": {"only_allow_merge_if_pipeline_succeeds": False}}},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("[OK]", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
