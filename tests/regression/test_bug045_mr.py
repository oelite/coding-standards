import contextlib
import importlib.util
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("readiness", Path(__file__).parents[2] / "scripts/mr_readiness.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReadinessTests(unittest.TestCase):
    def fixture(self, **changes):
        mr = dict(iid=1, state="opened", title="Fix", draft=False,
                  has_conflicts=False, detailed_merge_status="mergeable",
                  sha="abc", head_pipeline=dict(id=1, sha="abc", status="success"),
                  labels=[], created_at="2020-01-01T00:00:00Z")
        mr.update(changes)
        return mr

    def test_mergeable_success_pipeline_is_eligible(self):
        self.assertTrue(module.eligibility(self.fixture())[0])

    def test_not_approved_is_merge_ready_and_approvable(self):
        mr = self.fixture(detailed_merge_status="not_approved")
        self.assertEqual(module.merge_axis(mr)[0], "ready")
        self.assertTrue(module.eligibility(mr)[0])

    def test_conflict_value_blocks_merge_axis(self):
        mr = self.fixture(detailed_merge_status="conflict", has_conflicts=False)
        self.assertEqual(module.merge_axis(mr)[0], "blocked")
        ok, reasons, _, _ = module.eligibility(mr)
        self.assertFalse(ok)
        self.assertIn("merge readiness conflict", reasons)

    def test_ci_gated_status_is_unknown_merge_axis(self):
        mr = self.fixture(detailed_merge_status="ci_must_pass")
        self.assertEqual(module.merge_axis(mr)[0], "unknown")
        ok, reasons, _, _ = module.eligibility(mr)
        self.assertFalse(ok)
        self.assertIn("merge readiness ci_must_pass", reasons)

    def test_failed_pipeline_reason_names_pipeline_only(self):
        ok, reasons, _, _ = module.eligibility(
            self.fixture(head_pipeline=dict(id=1, sha="abc", status="failed")))
        self.assertFalse(ok)
        self.assertEqual(reasons, ["pipeline failed"])

    def test_pipeline_evidence_fails_closed(self):
        for pipeline in (None, {}, {"status": "success"},
                         {"id": 1, "status": "success", "sha": "old"},
                         {"id": 1, "status": "skipped", "sha": "abc"}):
            with self.subTest(pipeline=pipeline):
                self.assertFalse(module.eligibility(self.fixture(head_pipeline=pipeline))[0])

    def test_non_open_states_ineligible(self):
        for state in ("merged", "closed", None, ""):
            with self.subTest(state=state):
                ok, reasons, _, _ = module.eligibility(self.fixture(state=state))
                self.assertFalse(ok)
                self.assertTrue(any("not open" in r for r in reasons))

    def test_conflicts_unknown_drafts_manual_age_fail_closed(self):
        for changes in ({"has_conflicts": True}, {"detailed_merge_status": "checking"},
                        {"draft": True}, {"labels": ["requires-manual-review"]}, {"created_at": None},
                        {"created_at": "invalid"}, {"created_at": "2099-01-01T00:00:00Z"}):
            with self.subTest(changes=changes):
                self.assertFalse(module.eligibility(self.fixture(**changes))[0])

    def test_no_reason_ever_claims_ci_not_green(self):
        cases = [self.fixture(detailed_merge_status=s)
                 for s in ("checking", "conflict", "ci_must_pass", "not_approved")]
        cases += [self.fixture(head_pipeline=None), self.fixture(state="merged")]
        for mr in cases:
            reasons = module.eligibility(mr)[1]
            self.assertNotIn("CI not green", reasons)

    def test_unknown_approval_is_not_approved(self):
        self.assertEqual(module.approval_axis(None)[0], "unknown")
        self.assertEqual(module.approval_axis({})[0], "unknown")
        self.assertEqual(module.approval_axis({"approved": False, "approved_by": [{}], "approvals_required": 2})[0], "pending")
        self.assertEqual(module.approval_axis({"approved": True, "approved_by": [{"user": {"username": "x"}}]})[0], "approved")

    def test_opened_report_has_three_axis_verdict(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            module.status_report(self.fixture(), None)
        text = output.getvalue()
        self.assertIn("State:           opened", text)
        self.assertIn("is OPENED", text)
        self.assertIn("Merge Readiness: ready", text)
        self.assertIn("pipeline=success", text)
        self.assertIn("Approvals:       unknown", text)

    def test_approval_axis_returns_state_count_required(self):
        self.assertEqual(
            module.approval_axis({"approved": True, "approved_by": [{"user": {}}, {"user": {}}],
                                  "approvals_required": 2}),
            ("approved", "2", "2"))
        self.assertEqual(
            module.approval_axis({"approved": False, "approved_by": []}),
            ("pending", "0", "n/a"))
        self.assertEqual(module.approval_axis(None), ("unknown", "n/a", "n/a"))
        self.assertEqual(module.approval_axis({}), ("unknown", "n/a", "n/a"))

    def test_status_report_renders_approval_counts_separately(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            module.status_report(self.fixture(),
                                 {"approved": True, "approved_by": [{"user": {}}],
                                  "approvals_required": 2})
        self.assertIn("Approvals:       approved (approved_by=1, approvals_required=2)",
                      output.getvalue())
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            module.status_report(self.fixture(), None)
        self.assertIn("Approvals:       unknown (approved_by=n/a, approvals_required=n/a)",
                      output.getvalue())


class ReadinessCliTests(unittest.TestCase):
    SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "mr_readiness.py"

    def fixture(self, **changes):
        mr = dict(iid=1, state="opened", title="Fix", draft=False,
                  has_conflicts=False, detailed_merge_status="mergeable",
                  sha="abc", head_pipeline=dict(id=1, sha="abc", status="success"),
                  labels=[], created_at="2020-01-01T00:00:00Z")
        mr.update(changes)
        return mr

    def run_cli(self, command, mrs):
        with tempfile.NamedTemporaryFile("w", suffix=".ndjson", delete=False) as handle:
            for mr in mrs:
                handle.write(json.dumps(mr) + "\n")
            path = handle.name
        try:
            proc = subprocess.run([sys.executable, str(self.SCRIPT), command, path],
                                  capture_output=True, text=True)
        finally:
            Path(path).unlink()
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc.stdout

    def test_ids_prints_only_eligible_iids(self):
        eligible = self.fixture()
        ineligible = self.fixture(iid=2, head_pipeline=None)
        self.assertEqual(self.run_cli("ids", [eligible, ineligible]).split(), ["1"])

    def test_ids_prints_nothing_when_none_eligible(self):
        output = self.run_cli("ids", [self.fixture(iid=3, draft=True)])
        self.assertEqual(output.strip(), "")

    def test_eligible_table_separates_pipeline_and_merge_evidence(self):
        output = self.run_cli("eligible", [self.fixture(),
                                           self.fixture(iid=2, head_pipeline=None),
                                           self.fixture(iid=3, detailed_merge_status="conflict",
                                                        has_conflicts=True)])
        self.assertIn("IID    | State   | Merge", output)
        self.assertIn("OK ELIGIBLE", output)
        self.assertIn("XX INELIGIBLE", output)
        self.assertIn("pipeline evidence unknown", output)
        self.assertNotIn("CI not green", output)
        rows = [line.split("|") for line in output.splitlines() if line[:1].isdigit()]
        self.assertEqual([row[0].strip() for row in rows], ["1", "2", "3"])
        self.assertEqual([row[4].strip() for row in rows],
                         ["OK ELIGIBLE", "XX INELIGIBLE", "XX INELIGIBLE"])

    def test_eligible_handles_empty_input(self):
        output = self.run_cli("eligible", [])
        self.assertIn("No open merge requests found.", output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
