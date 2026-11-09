#!/usr/bin/env python3
"""Pure validation tests; no persistence, credentials or live GitLab mutations."""
import contextlib
import copy
import importlib.util
import io
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    "guard", Path(__file__).parents[2] / "scripts/lib/mr_pipeline_guard.py")
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)


class PipelineGuardTests(unittest.TestCase):
    def setUp(self):
        self.sha = "a" * 40
        self.project = {"id": 102}
        self.mr = {"iid": 1268, "project_id": 102, "source_project_id": 102,
                   "target_project_id": 102, "state": "opened", "sha": self.sha,
                   "source_branch": "feature/test", "diff_refs": {"head_sha": self.sha}}
        self.refs = (self.sha + "\trefs/heads/feature/test\n" + self.sha
                     + "\trefs/merge-requests/1268/head\n")
        self.pipeline = {"id": 42, "sha": self.sha, "source": "merge_request_event",
                         "ref": "refs/merge-requests/1268/head", "status": "created"}

    def test_matching_heads(self):
        self.assertEqual(self.sha, GUARD.validate_heads(self.mr, self.project, 1268, self.refs))

    def test_each_missing_or_stale_git_ref_fails(self):
        for index in (0, 1):
            for missing in (False, True):
                with self.subTest(index=index, missing=missing):
                    lines = self.refs.splitlines()
                    lines[index] = "" if missing else lines[index].replace(self.sha, "b" * 40)
                    with self.assertRaises(ValueError):
                        GUARD.validate_heads(self.mr, self.project, 1268, "\n".join(lines))

    def test_unknown_and_inconsistent_metadata(self):
        for key, value in (("state", "merged"), ("sha", None), ("diff_refs", None),
                           ("diff_refs", {"head_sha": "b" * 40}), ("source_project_id", 200),
                           ("target_project_id", 200), ("project_id", 200), ("iid", 1),
                           ("source_branch", None)):
            with self.subTest(key=key, value=value):
                mr = copy.deepcopy(self.mr)
                mr[key] = value
                with self.assertRaises(ValueError):
                    GUARD.validate_heads(mr, self.project, 1268, self.refs)

    def test_duplicate_ref_fails(self):
        with self.assertRaises(ValueError):
            GUARD.validate_heads(self.mr, self.project, 1268, self.refs + self.refs)

    def test_matching_pipeline(self):
        with contextlib.redirect_stdout(io.StringIO()):
            GUARD.validate_pipeline(self.pipeline, self.sha, 1268)

    def test_wrong_or_unknown_pipeline_evidence_fails(self):
        for key, value in (("sha", "b" * 40), ("source", "api"), ("source", None),
                           ("ref", "refs/merge-requests/1268/merge"), ("status", None), ("id", None)):
            with self.subTest(key=key, value=value):
                pipeline = dict(self.pipeline, **{key: value})
                with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                    GUARD.validate_pipeline(pipeline, self.sha, 1268)


if __name__ == "__main__":
    unittest.main()
