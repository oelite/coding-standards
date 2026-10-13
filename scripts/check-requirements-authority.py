#!/usr/bin/env python3
"""check-requirements-authority.py — deterministic tripwire for factual-requirements churn.

Flags clearly structured delivery-progress markers on ADDED lines of changed
factual-requirements documents (BRD, SRS, business rulebook, user stories,
process flows, `.spec` business requirements). It is deliberately narrow:

- Only added diff lines are inspected, so historical text never re-triggers.
- Generic words such as "implemented" or "progress" alone never fail the check;
  only structural markers (issue/MR status, checkboxes, code paths, test
  tallies, branch names as evidence) do.
- There is no inline bypass. If a detector produces a false positive, change
  the narrow detector and add a regression test; reviewers still assess meaning
  and approved decision provenance.

Exit codes: 0 = clean, 1 = findings, 2 = usage/IO error.

Usage:
    python3 scripts/check-requirements-authority.py --staged
    python3 scripts/check-requirements-authority.py --diff <file>
    python3 scripts/check-requirements-authority.py --diff - <<'EOF'
    ...unified diff text...
    EOF
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass

# Files treated as factual requirements. Matched against repo-relative POSIX paths.
FACTUAL_PATH_PATTERNS = (
    re.compile(r"(^|/)docs/business/BRD\.md$"),
    re.compile(r"(^|/)docs/business/SRS\.md$"),
    re.compile(r"(^|/)docs/business/rules/BR-[^/]+\.md$"),
    re.compile(r"(^|/)docs/business/rules/README\.md$"),
    re.compile(r"(^|/)docs/business/user-stories/[^/]+\.md$"),
    re.compile(r"(^|/)docs/business/process-flows/[^/]+\.md$"),
    re.compile(r"(^|/)\.spec/0\.1_business_requirements\.md$"),
    re.compile(r"(^|/)\.spec/0\.2_software_requirements\.md$"),
)

# Excluded subpaths (delivery evidence must not live under these anyway, but a
# repo may keep audits next to rules during migration; keep them out of scope).
EXCLUDED_PATH_PATTERNS = (
    re.compile(r"(^|/)\.worktrees/"),
    re.compile(r"-ARCHIVE\.md$"),
)

# Each detector: (id, description, compiled pattern, human hint).
# Patterns anchor on clearly structured delivery artifacts, NOT generic words.
DETECTORS = (
    (
        "mr-issue-status",
        "issue/MR state as progress",
        re.compile(
            r"\b(?:MR|PR)\s*!?\s*\d+\s*(?:is\s+)?"
            r"(?:merged|approved|pending review|awaiting review|in review|"
            r"ready to merge|can_be_merged|closed)\b"
            r"|\b(?:issue|bug|task|us|feature)\s*#\s*\d+\s*"
            r"(?:merged|closed|resolved|fixed|done)\b",
            re.IGNORECASE,
        ),
        "Issue/MR state is delivery evidence; cite it only as decision provenance in Change History.",
    ),
    (
        "resolved-mr-tail",
        "RESOLVED/Open status tied to an MR or issue",
        re.compile(
            r"\b(?:RESOLVED|CLOSED|OPEN)\b[^\n]*\((?:issue|MR|PR)[^\n]*#\s*\d+"
            r"|\b(?:issue|MR|PR)[^\n]*#\s*\d+[^\n]*\b(?:RESOLVED|CLOSED)\b",
            re.IGNORECASE,
        ),
        "Track resolution state in GitLab or a delivery record, not in requirements text.",
    ),
    (
        "implemented-in-code",
        "feature status tied to implementation",
        re.compile(
            r"\b(?:now\s+|fully\s+|partially\s+)?implemented\b[^\n]*"
            r"(?:in\s+|via\s+|at\s+)[^\n]*"
            r"(?:[\w./-]+\.(?:cs|ts|tsx|js|py|go|java)|#[0-9]+|![0-9]+)",
            re.IGNORECASE,
        ),
        "State the required behavior, not where/how it is currently implemented.",
    ),
    (
        "impl-status-heading",
        "implementation-status section",
        re.compile(
            r"^#{1,6}[^\n]*\bimplementation status\b|\bimplementation status\b\s*\(",
            re.IGNORECASE,
        ),
        "Remove implementation-status sections; use GitLab or a delivery record.",
    ),
    (
        "gaps-vs-code",
        "gaps-vs-current-code tracker",
        re.compile(r"\bgaps?\s+vs\.?\s+(?:the\s+)?current\s+code\b", re.IGNORECASE),
        "'Gaps vs current code' is an audit artifact; keep it out of factual documents.",
    ),
    (
        "code-path-evidence",
        "source-code path as status evidence",
        re.compile(
            r"(?:^|[\s(])src/[^\s)\]]+\.(?:cs|ts|tsx|js|py|go|java)(?::[0-9]+)?"
            r"|(?:^|[\s(])app/[^\s)\]]+\.(?:ts|tsx|js)(?::[0-9]+)?",
        ),
        "Code paths are not requirements content; remove the source-location reference.",
    ),
    (
        "test-count-status",
        "test tally as completion evidence",
        re.compile(
            r"\b[0-9]+\s+(?:unit\s+)?tests?\s+(?:pass|passed|passing|green)\b"
            r"|\btests?\s+pass(?:ed|ing)?\s*[:(-]?\s*[0-9]+",
            re.IGNORECASE,
        ),
        "Test results are delivery evidence; record them in the MR/issue, not here.",
    ),
    (
        "branch-name-evidence",
        "feature branch reference as status",
        re.compile(
            r"(?:on|in|from)\s+(?:branch\s+)?`?feature/[\w./-]+`?",
            re.IGNORECASE,
        ),
        "Branches are delivery artifacts; reference the approved decision instead.",
    ),
    (
        "assignment-tracking",
        "assignee/sprint/points tracking in requirements",
        re.compile(
            r"^\s*[-*>|]?\s*(?:\*\*)?(?:assigned to|assignee|sprint|story points|"
            r"story-points|estimated effort)(?:\*\*)?\s*[:|]",
            re.IGNORECASE,
        ),
        "Ownership and sprint data live in GitLab, not in factual documents.",
    ),
    (
        "story-delivery-status",
        "delivery lifecycle state in a factual document status field",
        re.compile(
            r"^\s*[-*>|]?\s*(?:\*\*)?status(?:\*\*)?\s*[:|].*"
            r"\b(?:ready|in progress|done|verified|to do|blocked|pr review|"
            r"ready to merge|complete[ds]?)\b",
            re.IGNORECASE,
        ),
        "Status in factual documents is only document approval (Draft/Active/Deprecated); track feature state in GitLab.",
    ),
    (
        "completion-checkbox",
        "completion checkbox",
        re.compile(r"^\s*[-*+]\s+\[[xX]\]\s+"),
        "Tick state is delivery progress; move DoD/sign-off tracking to the linked GitLab issue.",
    ),
    (
        "signoff-status-row",
        "sign-off status table row",
        re.compile(
            r"^\s*\|\s*(?:developer|code reviewer|qa|security|business analyst|"
            r"product owner|reviewer|approver)\b[^\n]*\|\s*(?:✅|☑|\[[xX]\]|complete[ds]?|approved|passed)\b",
            re.IGNORECASE,
        ),
        "Sign-off progress belongs in the linked GitLab issue, not the document body.",
    ),
)

@dataclass
class Finding:
    file: str
    line_no: int
    detector: str
    hint: str
    text: str


def is_factual(path: str) -> bool:
    p = path.lstrip("./")
    if any(prx.search(p) for prx in EXCLUDED_PATH_PATTERNS):
        return False
    return any(prx.search(p) for prx in FACTUAL_PATH_PATTERNS)


def parse_added_lines(diff_text: str) -> list[tuple[str, int, str]]:
    """Yield (file, new-file line number, added line) for added lines."""
    out: list[tuple[str, int, str]] = []
    current_file = ""
    new_line = 0
    for line in diff_text.splitlines():
        if line.startswith("+++"):
            # +++ b/path/to/file.md
            name = line[4:].strip() if len(line) > 4 else ""
            if name.startswith("b/"):
                name = name[2:]
            current_file = name
            continue
        if line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            new_line = int(m.group(1)) if m else 0
            continue
        if line.startswith("+") and not line.startswith("+++"):
            out.append((current_file, new_line, line[1:]))
            new_line += 1
        elif line.startswith("-") and not line.startswith("---"):
            continue
        elif line.startswith(("diff --git", "index ", "---")):
            continue
        else:
            # context line
            new_line += 1
    return out


def run(args: argparse.Namespace) -> int:
    if args.staged:
        try:
            diff_text = subprocess.run(
                ["git", "diff", "--cached", "--unified=0"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        except subprocess.CalledProcessError as exc:  # pragma: no cover
            print(f"error: git diff --cached failed: {exc.stderr}", file=sys.stderr)
            return 2
        if not diff_text.strip():
            diff_text = subprocess.run(
                ["git", "diff", "--unified=0"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
    elif args.diff is not None:
        if args.diff == "-":
            diff_text = sys.stdin.read()
        else:
            with open(args.diff, "r", encoding="utf-8") as fh:
                diff_text = fh.read()
    else:
        print("error: provide --staged or --diff <file|->", file=sys.stderr)
        return 2

    findings: list[Finding] = []
    for path, line_no, text in parse_added_lines(diff_text):
        if not is_factual(path):
            continue
        for det_id, _desc, pattern, hint in DETECTORS:
            if pattern.search(text):
                findings.append(Finding(path, line_no, det_id, hint, text.strip()))

    if findings:
        print(
            "❌ Requirements-authority check failed: delivery-progress content "
            "found in factual requirements documents."
        )
        for f in findings:
            print(f"  {f.file}:{f.line_no} [{f.detector}] {f.text}")
            print(f"      -> {f.hint}")
            print(
                "      -> Fix the document; if this is a false positive, narrow "
                "the detector and add a regression test."
            )
        print(
            "\nPolicy: 6_documentation_standards/REQUIREMENTS-AUTHORITY.md "
            "(factual documents record approved requirements, not delivery state)."
        )
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--staged",
        action="store_true",
        help="scan added lines of the current staged (fallback: unstaged) diff",
    )
    parser.add_argument(
        "--diff",
        metavar="FILE|-",
        help="scan added lines of a unified diff ('-' = stdin)",
    )
    args = parser.parse_args()
    try:
        return run(args)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
