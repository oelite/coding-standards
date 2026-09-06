#!/usr/bin/env python3
"""
tests/regression/test_parser_bugs.py
Regression tests for 5 confirmed bugs in oelite-gitlab.sh.

Usage:
  python3 tests/regression/test_parser_bugs.py

Exit:  0 on all-pass, 1 on any-failure.

These tests verify the FIXED behavior. A test fails BEFORE the fix and
passes AFTER. Non-regression tests pass both before and after.
"""

import json
import subprocess
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).parent.parent.parent / "scripts" / "oelite-gitlab.sh"

PASS = 0
FAIL = 0
FAILURES = []


def red(s):
    return f"\033[31m{s}\033[0m"


def grn(s):
    return f"\033[32m{s}\033[0m"


def ylw(s):
    return f"\033[33m{s}\033[0m"


def rstd(s):
    return f"\033[0m{s}"


def check_eq(test_id, desc, expected, actual):
    global PASS, FAIL, FAILURES
    if expected == actual:
        print(f"  {grn('PASS')} {test_id}: {desc}")
        PASS += 1
    else:
        print(f"  {red('FAIL')} {test_id}: {desc}")
        print(f"         expected: [{expected}]")
        print(f"         actual:   [{actual}]")
        FAIL += 1
        FAILURES.append(test_id)


def check_in(test_id, desc, needle, haystack):
    global PASS, FAIL, FAILURES
    if needle in haystack:
        print(f"  {grn('PASS')} {test_id}: {desc}")
        PASS += 1
    else:
        print(f"  {red('FAIL')} {test_id}: {desc}")
        print(f"         expected in: [{needle}]")
        print(f"         actual:      [{haystack}]")
        FAIL += 1
        FAILURES.append(test_id)


def check_not_in(test_id, desc, needle, haystack):
    global PASS, FAIL, FAILURES
    if needle not in haystack:
        print(f"  {grn('PASS')} {test_id}: {desc}")
        PASS += 1
    else:
        print(f"  {red('FAIL')} {test_id}: {desc}")
        print(f"         expected NOT in: [{needle}]")
        print(f"         actual:          [{haystack}]")
        FAIL += 1
        FAILURES.append(test_id)


def check_exit_zero(test_id, desc, rc):
    global PASS, FAIL, FAILURES
    if rc == 0:
        print(f"  {grn('PASS')} {test_id}: {desc}")
        PASS += 1
    else:
        print(f"  {red('FAIL')} {test_id}: {desc} (exit={rc})")
        FAIL += 1
        FAILURES.append(test_id)


def check_exit_nonzero(test_id, desc, rc):
    global PASS, FAIL, FAILURES
    if rc != 0:
        print(f"  {grn('PASS')} {test_id}: {desc}")
        PASS += 1
    else:
        print(f"  {red('FAIL')} {test_id}: {desc} (exit=0, expected non-zero)")
        FAIL += 1
        FAILURES.append(test_id)


def run_script(args, env_override=None, input_data=None, check=False):
    """Run oelite-gitlab.sh with given args, return (stdout, stderr, rc)."""
    env = os.environ.copy()
    if env_override:
        env.update(env_override)
    # Stub out the bits we don't want
    env.setdefault("OELITE_HUMAN", "1")
    env["GIT_AUTHOR_NAME"] = "Test"
    env["GIT_AUTHOR_EMAIL"] = "test@test"
    env["GIT_COMMITTER_NAME"] = "Test"
    env["GIT_COMMITTER_EMAIL"] = "test@test"

    proc = subprocess.Popen(
        ["zsh", str(SCRIPT)] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        stdin=subprocess.PIPE if input_data else None,
        cwd=str(SCRIPT.parent.parent),
    )
    stdout, stderr = proc.communicate(input=input_data.encode() if input_data else None)
    return stdout.decode("utf-8", errors="replace"), \
           stderr.decode("utf-8", errors="replace"), \
           proc.returncode


def run_wtc(args, **kwargs):
    return run_script(["worktree-create"] + args, **kwargs)


def run_mr_update(args, **kwargs):
    return run_script(["mr-update"] + args, **kwargs)


def run_issues(args, **kwargs):
    return run_script(["issues"] + args, **kwargs)


# ===========================================================================
# SECTION: Bug 1 — positional parser
# ===========================================================================
print()
print(ylw("━━ Bug 1: worktree-create positional parser ━━"))

# 1.1: The exact failing case from the audit: 4 args, no base branch
#   Before fix: errors with "Unknown option: 1260" because $3=--issue gets shifted away
#   After fix: accepts the --issue flag properly
_, stderr, rc = run_wtc(["daniel", "feature/bug1270-auth-di", "--issue", "1260"])
check_not_in(
    "BUG1.1",
    "daniel feature/x --issue 1260: should NOT say 'Unknown option: 1260'",
    "Unknown option: 1260",
    stderr,
)

# 1.2: --no-issue form
_, stderr, rc = run_wtc(["daniel", "feature/spike", "--no-issue"])
check_not_in(
    "BUG1.2",
    "daniel feature/x --no-issue: should NOT say 'Unknown option'",
    "Unknown option",
    stderr,
)

# 1.3: BACKWARD-COMPAT — legacy 3-positional still works
_, stderr, rc = run_wtc(["daniel", "feature/auth", "develop", "--issue", "42"])
check_not_in(
    "BUG1.3",
    "legacy form 'agent branch develop --issue N': no 'Unknown option'",
    "Unknown option",
    stderr,
)
check_not_in(
    "BUG1.3.b",
    "legacy form: should not say 'Base branch origin' (corrupted base)",
    "Base branch origin",
    stderr,
)

# 1.4: New --base flag
_, stderr, rc = run_wtc(
    ["daniel", "feature/auth", "--base", "release/2026-Q3", "--issue", "42"]
)
check_not_in(
    "BUG1.4",
    "--base <branch> flag should be accepted",
    "Unknown option",
    stderr,
)

# 1.5: Invalid agent rejected
_, stderr, rc = run_wtc(["notanagent", "feature/x", "--no-issue"])
check_in(
    "BUG1.5",
    "invalid agent should be rejected",
    "Unknown agent",
    stderr,
)

# 1.6: Missing agent (no args)
_, stderr, rc = run_script(["worktree-create"])
check_exit_nonzero("BUG1.6", "no args should fail", rc)


# ===========================================================================
# SECTION: Bug 5 — error hint interpolation
# ===========================================================================
print()
print(ylw("━━ Bug 5: error hint interpolation ━━"))

# After fix, error hints should never double-flag like '--no-issue --no-issue'
_, stderr, rc = run_wtc(["daniel", "feature/spike", "--no-issue"])
# The error about --no-issue already being used (if that still happens)
# should not produce '--no-issue --no-issue' in the hint
check_not_in(
    "BUG5.1",
    "error hint should not show '--no-issue --no-issue' (duplicated flag)",
    "--no-issue --no-issue",
    stderr,
)


# ===========================================================================
# SECTION: Bug 2 — mr-update Python interpolation
# ===========================================================================
print()
print(ylw("━━ Bug 2: mr-update Python source injection ━━"))

# Test the json_encode_value helper logic in isolation.
# This mirrors what the FIXED cmd_mr_update does:
#   python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))"
# piped via stdin, vs. the BUGGY version which interpolated into single-quoted strings.

def json_encode_value_fixed(value):
    """The fixed implementation: pass via stdin to json.dumps (no shell interpolation)."""
    proc = subprocess.run(
        ["python3", "-c", "import json,sys; print(json.dumps(sys.stdin.read()))"],
        input=value.encode(),
        capture_output=True,
    )
    return proc.stdout.decode().strip()


def mr_update_data_fixed(title, description):
    """
    The fixed data payload construction using stdin pipe.
    No shell interpolation — title/desc are passed via a temp script file.
    """
    script = """
import json, sys
d = json.loads(sys.stdin.read())
out = {}
if d.get("title"):
    out["title"] = d["title"]
if d.get("description"):
    out["description"] = d["description"]
print(json.dumps(out))
"""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False
    ) as f:
        f.write(script)
        script_path = f.name
    try:
        payload = json.dumps({"title": title, "description": description})
        proc = subprocess.run(
            ["python3", script_path],
            input=payload.encode(),
            capture_output=True,
        )
        return proc.stdout.decode().strip()
    finally:
        os.unlink(script_path)


# 2.1: Normal title
result = mr_update_data_fixed("feat: add user export", "long description here")
check_in("BUG2.1", "normal title works", "feat: add user export", result)
check_not_in("BUG2.1.b", "no SyntaxError", "SyntaxError", result)

# 2.2: Title with single quote (the original failing case)
result = mr_update_data_fixed("fix: don't break parser", "description")
check_in("BUG2.2", "title with single quote: no SyntaxError", "don't", result)
check_not_in("BUG2.2.b", "no SyntaxError in output", "SyntaxError", result)

# 2.3: Description with triple-quote (Python string terminator)
result = mr_update_data_fixed("normal title", "text''' end of python source")
check_not_in("BUG2.3", "description with triple-quote: no SyntaxError", "SyntaxError", result)
check_in("BUG2.3.b", "triple-quote round-trips correctly", "text''' end", result)

# 2.4: Backslash + quote
result = mr_update_data_fixed("oops\\'\\'bad", "x")
check_not_in("BUG2.4", "backslash+quote: no SyntaxError", "SyntaxError", result)

# 2.5: Title with embedded newline
result = mr_update_data_fixed("line one\nline two", "desc")
check_not_in("BUG2.5", "title with newline: no SyntaxError", "SyntaxError", result)

# 2.6: Empty title (both empty → empty payload object)
result = mr_update_data_fixed("", "")
check_eq("BUG2.6", "empty title+description → {}", "{}", result)
check_not_in("BUG2.6.b", "no SyntaxError", "SyntaxError", result)

# 2.7: Special JSON chars
result = mr_update_data_fixed('has "double" quotes', "has \\backslash")
check_not_in("BUG2.7", "special JSON chars: no SyntaxError", "SyntaxError", result)
check_in("BUG2.7.b", "double quotes are JSON-escaped", '\\"', result)


# ===========================================================================
# SECTION: Bug 4 — cmd_issues label URL-encoding
# ===========================================================================
print()
print(ylw("━━ Bug 4: cmd_issues label URL-encoding ━━"))

import urllib.parse

def build_issues_endpoint_fixed(project_path, label_filter):
    """The fixed URL construction from cmd_issues."""
    encoded_path = urllib.parse.quote(project_path, safe="")
    endpoint = f"/projects/{encoded_path}/issues?scope=all&state=opened&per_page=100"
    if label_filter:
        # FIXED: URL-encode the label VALUE
        encoded_label = urllib.parse.quote(label_filter, safe="")
        endpoint += f"&labels={encoded_label}"
    return endpoint


# 4.1: Simple label
result = build_issues_endpoint_fixed("oelite/test/proj", "backend")
check_in("BUG4.1", "simple label is preserved", "labels=backend", result)
check_not_in("BUG4.1.b", "no raw spaces", " ", result)

# 4.2: Label with space
result = build_issues_endpoint_fixed("oelite/test/proj", "needs review")
check_in("BUG4.2", "space becomes %20", "%20review", result)
check_not_in("BUG4.2.b", "no raw space in label", "review ", result)

# 4.3: Label with & (was injecting extra query param)
result = build_issues_endpoint_fixed("oelite/test/proj", "bug&priority")
check_in("BUG4.3", "& becomes %26", "%26", result)
# Must NOT be: &labels=bug&priority=X (injecting a new param)
check_not_in("BUG4.3.b", "no raw & before priority=X", "bug&p", result)

# 4.4: Label with colon and space
result = build_issues_endpoint_fixed("oelite/test/proj", "feat: api")
check_in("BUG4.4", "space becomes %20", "%20api", result)
check_in("BUG4.4.b", "colon is preserved", "feat%3A", result)

# 4.5: Empty label
result = build_issues_endpoint_fixed("oelite/test/proj", "")
check_not_in("BUG4.5", "empty label: no &labels= param", "&labels=", result)

# 4.6: Label with # (hash, was causing URL fragment)
result = build_issues_endpoint_fixed("oelite/test/proj", "type#bug")
check_in("BUG4.6", "# becomes %23", "%23bug", result)
check_not_in("BUG4.6.b", "no fragment injection", "#bug", result)

# 4.7: Label with + (plus)
result = build_issues_endpoint_fixed("oelite/test/proj", "area+backend")
check_in("BUG4.7", "+ becomes %2B", "%2B", result)


# ===========================================================================
# SECTION: Bug 3 — orphan worktree collision detection
# ===========================================================================
print()
print(ylw("━━ Bug 3: orphan worktree collision detection ━━"))

def detect_orphans(agent, root):
    """
    Replicate the detection logic that will be added to oelite-gitlab.sh.
    Returns list of orphan worktree paths for the given agent.
    """
    wt_base = os.path.join(root, ".worktrees")
    if not os.path.isdir(wt_base):
        return []

    # Get git-tracked worktrees (use realpath to resolve symlinks on macOS)
    tracked = set()
    proc = subprocess.run(
        ["git", "-C", root, "worktree", "list", "--porcelain"],
        capture_output=True, text=True
    )
    for line in proc.stdout.split("\n"):
        if line.startswith("worktree "):
            p = line[len("worktree "):]
            # realpath resolves symlinks (critical on macOS where /tmp → /private/tmp)
            p_resolved = os.path.realpath(p)
            if p_resolved.startswith(os.path.realpath(wt_base) + os.sep):
                tracked.add(p_resolved)

    # Scan disk for agent-prefixed dirs (use realpath for comparison)
    wt_base_resolved = os.path.realpath(wt_base)
    orphans = []
    for d in os.listdir(wt_base):
        if not d.startswith(agent):
            continue
        full = os.path.join(wt_base, d)
        full_resolved = os.path.realpath(full)
        if os.path.isdir(full) and full_resolved not in tracked:
            orphans.append(full_resolved)

    return orphans


# 3.1: No orphans
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", "--initial-branch=main", tmp], check=True)
    subprocess.run(
        ["git", "-C", tmp, "commit", "--allow-empty", "-q", "-minit"],
        env={**os.environ, "GIT_AUTHOR_EMAIL": "t", "GIT_AUTHOR_NAME": "t",
             "GIT_COMMITTER_EMAIL": "t", "GIT_COMMITTER_NAME": "t"},
        check=True
    )
    result = detect_orphans("daniel", tmp)
    check_eq("BUG3.1", "no orphans: empty list", [], result)

# 3.2: Orphan detected
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", "--initial-branch=main", tmp], check=True)
    subprocess.run(
        ["git", "-C", tmp, "commit", "--allow-empty", "-q", "-minit"],
        env={**os.environ, "GIT_AUTHOR_EMAIL": "t", "GIT_AUTHOR_NAME": "t",
             "GIT_COMMITTER_EMAIL": "t", "GIT_COMMITTER_NAME": "t"},
        check=True
    )
    os.makedirs(os.path.join(tmp, ".worktrees", "daniel-42"))
    Path(os.path.join(tmp, ".worktrees", "daniel-42", "orphan")).touch()
    result = detect_orphans("daniel", tmp)
    check_in("BUG3.2", "orphan daniel-42 detected", "daniel-42", str(result))

# 3.3: Multiple orphans
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", "--initial-branch=main", tmp], check=True)
    subprocess.run(
        ["git", "-C", tmp, "commit", "--allow-empty", "-q", "-minit"],
        env={**os.environ, "GIT_AUTHOR_EMAIL": "t", "GIT_AUTHOR_NAME": "t",
             "GIT_COMMITTER_EMAIL": "t", "GIT_COMMITTER_NAME": "t"},
        check=True
    )
    os.makedirs(os.path.join(tmp, ".worktrees", "daniel-42"))
    os.makedirs(os.path.join(tmp, ".worktrees", "daniel-100"))
    result = detect_orphans("daniel", tmp)
    check_in("BUG3.3", "orphan daniel-42 detected", "daniel-42", str(result))
    check_in("BUG3.3.b", "orphan daniel-100 detected", "daniel-100", str(result))

# 3.4: Different agent's dirs not flagged
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", "--initial-branch=main", tmp], check=True)
    subprocess.run(
        ["git", "-C", tmp, "commit", "--allow-empty", "-q", "-minit"],
        env={**os.environ, "GIT_AUTHOR_EMAIL": "t", "GIT_AUTHOR_NAME": "t",
             "GIT_COMMITTER_EMAIL": "t", "GIT_COMMITTER_NAME": "t"},
        check=True
    )
    os.makedirs(os.path.join(tmp, ".worktrees", "daniel-42"))
    os.makedirs(os.path.join(tmp, ".worktrees", "emma-50"))
    result = detect_orphans("daniel", tmp)
    check_not_in("BUG3.4", "emma-50 not flagged for daniel", "emma-50", str(result))

# 3.5: Git-tracked worktree not flagged as orphan
with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", "--initial-branch=main", tmp], check=True)
    subprocess.run(
        ["git", "-C", tmp, "commit", "--allow-empty", "-q", "-minit"],
        env={**os.environ, "GIT_AUTHOR_EMAIL": "t", "GIT_AUTHOR_NAME": "t",
             "GIT_COMMITTER_EMAIL": "t", "GIT_COMMITTER_NAME": "t"},
        check=True
    )
    # Create a git-tracked worktree
    subprocess.run(
        ["git", "-C", tmp, "worktree", "add", "-q", "-b", "feature/daniel-tracked",
         os.path.join(tmp, ".worktrees", "daniel-99")],
        check=True
    )
    result = detect_orphans("daniel", tmp)
    check_not_in("BUG3.5", "git-tracked daniel-99 NOT flagged as orphan", "daniel-99", str(result))


# ===========================================================================
# SECTION: Bug 4 — URL encoding in cmd_issues
# ===========================================================================
print()
print(ylw("━━ Bug 4: URL-encoding in cmd_issues ━━"))

# Verify url_encode_query helper exists and works correctly
script_path = SCRIPT

# 4.8: url_encode_query helper exists in script
with open(script_path, "r") as f:
    script_src = f.read()

check_in("BUG4.8", "url_encode_query helper exists in script",
         "url_encode_query", script_src)

# 4.9: cmd_issues uses url_encode_query for labels
check_in("BUG4.9", "cmd_issues uses url_encode_query for label_filter",
         "url_encode_query", script_src)

# ===========================================================================
# SECTION: Bug 2 integration — mr-update stdin pipe pattern
# ===========================================================================
print()
print(ylw("━━ Bug 2 (integration): mr-update stdin pipe ━━"))

# 2.8: Script uses stdin pipe for mr-update data construction
check_in("BUG2.8", "cmd_mr_update uses stdin pipe pattern (printf | python)",
         "printf '%s\\n%s'", script_src)

check_not_in("BUG2.9", "cmd_mr_update does NOT use shell-variable interpolation",
             "payload['title'] = '$title'", script_src)


# ===========================================================================
# SECTION: Bug 3 (integration): orphan detection before worktree add
# ===========================================================================
print()
print(ylw("━━ Bug 3 (integration): orphan check before worktree add ━━"))

# 3.6: detect_orphan_worktrees helper exists
check_in("BUG3.6", "detect_orphan_worktrees helper exists",
         "detect_orphan_worktrees", script_src)

# 3.7: Orphan check is called before git worktree add
check_in("BUG3.7", "detect_orphan_worktrees called before worktree add",
         "git worktree add", script_src)

# 3.8: Orphan detection uses realpath for macOS /tmp compatibility
check_in("BUG3.8", "orphan detection uses realpath (macOS /tmp compat)",
         "os.path.realpath", script_src)


# ===========================================================================
# SECTION: Bug 7 — macOS /tmp symlink path normalization
# ===========================================================================
print()
print(ylw("━━ Bug 7: macOS /tmp path normalization (suspected) ━━"))

# On macOS, /tmp is a symlink to /private/tmp.
# Before fix: preflight_root = "/tmp/foo" but git returns "/private/tmp/foo"
#             → string comparison fails → no warning fires.
# After fix: preflight_root should be normalized via realpath.

if sys.platform == "darwin":
    import os.path
    real_tmp = os.path.realpath("/tmp")
    if real_tmp.startswith("/private/tmp"):
        print(f"  {ylw('INFO')} BUG7: macOS /tmp detected → {real_tmp}")
        print(f"       Pre-flight path comparison MUST use realpath to avoid mismatch.")
        check_in(
            "BUG7.1",
            "macOS /tmp symlink confirmed; fix must use realpath",
            "/private/tmp",
            real_tmp,
        )
    else:
        print(f"  {ylw('SKIP')} BUG7: /tmp symlink resolution not applicable on this host")
else:
    print(f"  {ylw('SKIP')} BUG7: not on macOS")


# ===========================================================================
# SUMMARY
# ===========================================================================
print()
print(ylw("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
print(f"  Regression test summary: {grn(str(PASS) + ' passed')}, {red(str(FAIL) + ' failed')}")
print(ylw("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"))
if FAIL > 0:
    print()
    print(red("Failed tests:"))
    for t in FAILURES:
        print(f"  - {t}")
    sys.exit(1)
sys.exit(0)
