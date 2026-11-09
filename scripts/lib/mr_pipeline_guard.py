#!/usr/bin/env python3
"""Fail-closed validation for dedicated detached MR pipeline creation (#107)."""
import json
import re
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_heads(mr, project, iid, refs):
    project_id = project.get("id")
    require(isinstance(project_id, int), "Missing project ID")
    require(mr.get("iid") == int(iid), "MR IID mismatch")
    require(mr.get("state") == "opened", "MR must be open")
    require(mr.get("source_project_id") == project_id
            and mr.get("target_project_id") == project_id
            and mr.get("project_id") == project_id,
            "Cross-project/fork MR unsupported; no pipeline created")
    sha = mr.get("sha")
    require(isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{40}", sha), "Missing/invalid API SHA")
    branch = mr.get("source_branch")
    require(isinstance(branch, str) and branch, "Missing source branch")
    required = ["refs/heads/" + branch, "refs/merge-requests/" + str(iid) + "/head"]
    for ref in required:
        values = [line.split()[0] for line in refs.splitlines()
                  if len(line.split()) == 2 and line.split()[1] == ref]
        require(values == [sha], "Remote ref disagreement: " + ref + " vs API " + sha)
    require(isinstance(mr.get("diff_refs"), dict)
            and mr["diff_refs"].get("head_sha") == sha, "Diff head disagrees with API SHA")
    return sha


def validate_pipeline(pipeline, sha, iid):
    # Merged-results commits differ from source SHA and need a separate evidence policy.
    require(isinstance(pipeline.get("id"), int), "Missing pipeline ID")
    for key in ("id", "status", "ref", "sha", "source", "web_url"):
        print("  {}: {}".format(key, pipeline.get(key, "unknown")))
    require(pipeline.get("sha") == sha, "Created pipeline SHA differs; do not rely on this evidence")
    require(pipeline.get("source") == "merge_request_event", "Unexpected/missing pipeline source")
    require(pipeline.get("ref") == "refs/merge-requests/" + str(iid) + "/head",
            "Only detached MR pipeline refs supported")
    require(bool(pipeline.get("status")), "Missing pipeline status")


def main():
    try:
        if sys.argv[1] == "--pipeline":
            validate_pipeline(json.load(sys.stdin), sys.argv[2], sys.argv[3])
        else:
            print(validate_heads(json.loads(sys.argv[1]), json.loads(sys.argv[2]),
                                 sys.argv[3], sys.stdin.read()))
    except (ValueError, TypeError, KeyError, IndexError) as error:
        print("[ERROR] " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
