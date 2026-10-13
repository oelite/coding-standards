#!/usr/bin/env python3
"""Regression tests for scripts/check-requirements-authority.py (issue #40).

Offline, secret-free: exercises the validator against synthetic unified diffs.
Run: python3 tests/regression/test_requirements_authority.py
"""

import os
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VALIDATOR = os.path.join(REPO_ROOT, "scripts", "check-requirements-authority.py")

CLEAN_DIFF = """diff --git a/docs/business/rules/BR-09-mfa.md b/docs/business/rules/BR-09-mfa.md
--- a/docs/business/rules/BR-09-mfa.md
+++ b/docs/business/rules/BR-09-mfa.md
@@ -10,2 +10,4 @@
 The platform MUST apply progressive delay between failed attempts within a window.
+The delay progression MUST be configurable (linear, exponential, or fixed). Default progression is exponential with a cap.
+Operators SHOULD review lockout events weekly as part of routine monitoring.
"""

CONTAMINATED_DIFF = CLEAN_DIFF.replace(
    "+Operators SHOULD review lockout events weekly as part of routine monitoring.",
    "+The wizard is now implemented via src/Hermes.Api/Auth/JwtRsaKeyProvider.cs. MR !517 merged."
)

GENERIC_WORDING_DIFF = CLEAN_DIFF.replace(
    "+Operators SHOULD review lockout events weekly as part of routine monitoring.",
    "+A fully implemented policy set is REQUIRED before tenant activation per BR-13-049."
)

BUSINESS_PROGRESS_DIFF = CLEAN_DIFF.replace(
    "+Operators SHOULD review lockout events weekly as part of routine monitoring.",
    "+The wizard MUST persist progress so the user can resume after closing the browser."
)

LIFECYCLE_DIFF = """diff --git a/docs/business/user-stories/US-001-login.md b/docs/business/user-stories/US-001-login.md
--- a/docs/business/user-stories/US-001-login.md
+++ b/docs/business/user-stories/US-001-login.md
@@ -4,3 +4,7 @@
 ## Acceptance Criteria
+- [x] All acceptance criteria pass
+| Developer | Daniel | Complete | 2026-10-13 | |
+> **Assigned to**: daniel
+> **Status**: In Progress
+| Sprint | 14 |
"""

PROVENANCE_DIFF = """diff --git a/docs/business/rules/BR-13-security.md b/docs/business/rules/BR-13-security.md
--- a/docs/business/rules/BR-13-security.md
+++ b/docs/business/rules/BR-13-security.md
@@ -100,1 +100,2 @@
+| 2026-10-13 | Isabella | 1.1.0 | Clarified BR-13-010 delay progression; decision #40. |
"""

NON_FACTUAL_DIFF = """diff --git a/docs/technical/api/API.md b/docs/technical/api/API.md
--- a/docs/technical/api/API.md
+++ b/docs/technical/api/API.md
@@ -1,1 +1,2 @@
+Implemented in src/Hermes.Api/Auth/JwtRsaKeyProvider.cs; 2589 unit tests pass. MR !517 merged.
"""

# .spec business requirements are factual documents; a leading-dot directory
# must not be stripped away by path normalization.
SPEC_CONTAMINATED_DIFF = """diff --git a/.spec/0.1_business_requirements.md b/.spec/0.1_business_requirements.md
--- a/.spec/0.1_business_requirements.md
+++ b/.spec/0.1_business_requirements.md
@@ -10,1 +10,2 @@
+Implemented via src/Foo.cs. MR !517 merged.
"""

GAPS_DIFF = """diff --git a/docs/business/rules/BR-31-disaster-recovery.md b/docs/business/rules/BR-31-disaster-recovery.md
--- a/docs/business/rules/BR-31-disaster-recovery.md
+++ b/docs/business/rules/BR-31-disaster-recovery.md
@@ -1,1 +1,4 @@
+#### Implementation status (issue #798)
+Gaps vs Current Code: ephemeral RSA key generation breaks cross-replica JWT verification.
+**RESOLVED (issue #798 / MR !517)**: IJwtSigningKeySource abstraction in place.
"""

STATUS_REGISTER_DIFF = """diff --git a/docs/requirements-status.json b/docs/requirements-status.json
--- a/docs/requirements-status.json
+++ b/docs/requirements-status.json
@@ -1,1 +1,2 @@
+{"BR-09-018": "implemented", "BR-31-011": "resolved"}
"""

# The regression file itself (tests/...) embeds nested diff fixtures; those
# nested fixture lines must not be re-parsed as factual-document additions.
NESTED_FIXTURE_DIFF = """diff --git a/tests/regression/test_requirements_authority.py b/tests/regression/test_requirements_authority.py
--- a/tests/regression/test_requirements_authority.py
+++ b/tests/regression/test_requirements_authority.py
@@ -17,0 +18,3 @@
+CLEAN_DIFF = \"\"\"diff --git a/docs/business/rules/BR-09-mfa.md b/docs/business/rules/BR-09-mfa.md
+--- a/docs/business/rules/BR-09-mfa.md
++++ b/docs/business/rules/BR-09-mfa.md
+@@ -10,2 +10,4 @@
++The wizard is now implemented via src/X.cs. MR !517 merged.
+\"\"\"
"""


class RequirementsAuthorityValidatorTests(unittest.TestCase):
    def run_validator(self, diff_text, *extra):
        with tempfile.NamedTemporaryFile(
            "w", suffix=".diff", delete=False, encoding="utf-8"
        ) as fh:
            fh.write(diff_text)
            path = fh.name
        self.addCleanup(os.unlink, path)
        return subprocess.run(
            [sys.executable, VALIDATOR, "--diff", path, *extra],
            capture_output=True,
            text=True,
        )

    def test_clean_requirements_pass(self):
        result = self.run_validator(CLEAN_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_implementation_progress_fails(self):
        result = self.run_validator(CONTAMINATED_DIFF)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("code-path-evidence", result.stdout)
        self.assertIn("mr-issue-status", result.stdout)

    def test_generic_wording_not_rejected(self):
        result = self.run_validator(GENERIC_WORDING_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_business_progress_language_not_rejected(self):
        result = self.run_validator(BUSINESS_PROGRESS_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_lifecycle_trackers_fail(self):
        result = self.run_validator(LIFECYCLE_DIFF)
        self.assertEqual(result.returncode, 1, result.stdout)
        for detector in (
            "completion-checkbox",
            "signoff-status-row",
            "assignment-tracking",
            "story-delivery-status",
        ):
            self.assertIn(detector, result.stdout)

    def test_change_history_provenance_allowed(self):
        result = self.run_validator(PROVENANCE_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_non_factual_paths_ignored(self):
        result = self.run_validator(NON_FACTUAL_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_spec_business_requirements_are_factual(self):
        result = self.run_validator(SPEC_CONTAMINATED_DIFF)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn(".spec/0.1_business_requirements.md", result.stdout)
        self.assertIn("code-path-evidence", result.stdout)

    def test_no_inline_bypass(self):
        result = self.run_validator(CONTAMINATED_DIFF, "--allow-comment", "MR !517 merged")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_status_sections_fail(self):
        result = self.run_validator(GAPS_DIFF)
        self.assertEqual(result.returncode, 1, result.stdout)
        for detector in ("impl-status-heading", "gaps-vs-code", "resolved-mr-tail"):
            self.assertIn(detector, result.stdout)

    def test_status_register_path_out_of_scope(self):
        result = self.run_validator(STATUS_REGISTER_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nested_diff_fixture_not_reparsed(self):
        result = self.run_validator(NESTED_FIXTURE_DIFF)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_input_errors(self):
        result = subprocess.run(
            [sys.executable, VALIDATOR], capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
