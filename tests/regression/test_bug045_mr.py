import contextlib
import importlib.util
import io
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
