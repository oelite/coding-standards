#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timezone


def merge_axis(mr):
    raw = mr.get("detailed_merge_status") or mr.get("merge_status") or "unknown"
    if mr.get("has_conflicts") or raw in {"conflict", "cannot_be_merged"}:
        return "blocked", raw
    if raw in {"mergeable", "approved", "can_be_merged", "not_approved", "blocked_approval"}:
        return "ready", raw
    if raw in {"draft_status", "discussion_not_resolved", "commit_signature_required", "external_status_checks", "author_not_allowed_to_merge", "not_fork"}:
        return "blocked", raw
    return "unknown", raw


def pipeline_axis(mr):
    pipeline = mr.get("head_pipeline") or mr.get("pipeline")
    if not isinstance(pipeline, dict):
        return "unknown", "none"
    status = pipeline.get("status") or "unknown"
    if status == "success":
        if not pipeline.get("id") or not pipeline.get("sha") or not mr.get("sha"):
            return "unknown", "incomplete"
        if pipeline["sha"] != mr["sha"]:
            return "unknown", "stale"
        return "success", status
    if status in {"failed", "canceled", "canceling"}:
        return "failed", status
    return "unknown", status


def approval_axis(approvals):
    if not isinstance(approvals, dict):
        return "unknown", "n/a", "n/a"
    approved_by = approvals.get("approved_by") or []
    required = approvals.get("approvals_required")
    required_text = "n/a" if required is None else str(required)
    if approvals.get("approved") is True:
        return "approved", str(len(approved_by)), required_text
    if approvals.get("approved") is False:
        return "pending", str(len(approved_by)), required_text
    return "unknown", "n/a", required_text


def age_minutes(mr):
    value = mr.get("created_at")
    if not value:
        return None
    try:
        created = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return (datetime.now(timezone.utc) - created).total_seconds() / 60
    except (TypeError, ValueError):
        return None


def eligibility(mr):
    merge, merge_raw = merge_axis(mr)
    pipeline, pipeline_raw = pipeline_axis(mr)
    reasons = []
    if mr.get("state") != "opened":
        reasons.append(f"state not open ({mr.get('state') or 'unknown'})")
    if merge != "ready":
        reasons.append(f"merge readiness {merge_raw}")
    if pipeline != "success":
        reasons.append("pipeline failed" if pipeline == "failed" else "pipeline evidence unknown")
    if mr.get("draft") or mr.get("work_in_progress") or mr.get("title", "").startswith("WIP:"):
        reasons.append("draft/WIP")
    if "requires-manual-review" in (mr.get("labels") or []):
        reasons.append("manual review flag")
    age = age_minutes(mr)
    if age is not None and age < 10:
        reasons.append(f"age <10m ({age:.0f}m)")
    if age is None:
        reasons.append("creation age unknown")
    return not reasons, reasons, merge_raw, pipeline_raw


def status_report(mr, approvals):
    merge, merge_raw = merge_axis(mr)
    pipeline, pipeline_raw = pipeline_axis(mr)
    approval, approved_by, approvals_required = approval_axis(approvals)
    iid = mr.get("iid", "")
    state = mr.get("state", "unknown")
    print("=== MR Status ===")
    print("  Endpoint:        GET /merge_requests/:iid + GET /merge_requests/:iid/approvals")
    print(f"  IID:             !{iid}")
    print(f"  Title:           {mr.get('title', '')}")
    print(f"  State:           {state}")
    print(f"  Merge Readiness: {merge} (detailed_merge_status/merge_status={merge_raw})")
    print(f"  CI Pipeline:     {pipeline} (head_pipeline.status={pipeline_raw})")
    print(f"  Approvals:       {approval} (approved_by={approved_by}, approvals_required={approvals_required})")
    print(f"  Source Branch:   {mr.get('source_branch', '')}")
    print(f"  Target Branch:   {mr.get('target_branch', '')}")
    print(f"  URL:             {mr.get('web_url', '')}")
    print()
    if state == "merged":
        print(f"[OK] MR !{iid} is MERGED")
    elif state == "opened":
        print(f"[INFO] MR !{iid} is OPENED; merge readiness={merge}, pipeline={pipeline}, approvals={approval}")
    elif state == "closed":
        print(f"[WARN] MR !{iid} is CLOSED (not merged) — may need a new MR")
    else:
        print(f"[WARN] MR !{iid} state: {state}")


def load_mrs(path):
    with open(path) as handle:
        content = handle.read().strip()
    if not content:
        return []
    if content.startswith("["):
        return json.loads(content)
    return [json.loads(line) for line in content.splitlines() if line.strip()]


def eligible_report(mrs):
    if not mrs:
        print("No open merge requests found.")
        return
    print("Endpoint: GET /merge_requests?state=opened -> per-MR GET /merge_requests/:iid (fields: detailed_merge_status, has_conflicts, draft, head_pipeline.status, labels, created_at)")
    print("Eligibility requires pipeline success on the head SHA; missing evidence fails closed.")
    print("IID    | State   | Merge              | Pipeline | ELIGIBLE | REASONS")
    print("-" * 100)
    for mr in mrs:
        ok, reasons, merge, pipeline = eligibility(mr)
        marker = "OK ELIGIBLE" if ok else "XX INELIGIBLE"
        print(f"{str(mr.get('iid', '')):<6} | {mr.get('state', ''):<7} | {merge:<18} | {pipeline:<8} | {marker:<11} | {', '.join(reasons) if reasons else '-'}")
    print(f"\nTotal: {len(mrs)} open MR(s)")


def main():
    command = sys.argv[1]
    if command == "status":
        with open(sys.argv[2]) as handle:
            mr = json.load(handle)
        approvals = None
        if len(sys.argv) > 3:
            with open(sys.argv[3]) as handle:
                approvals = json.load(handle)
        status_report(mr, approvals)
    elif command == "eligible":
        eligible_report(load_mrs(sys.argv[2]))
    elif command == "ids":
        for mr in load_mrs(sys.argv[2]):
            if eligibility(mr)[0]:
                print(mr.get("iid"))
    else:
        raise SystemExit(f"unknown command: {command}")


if __name__ == "__main__":
    main()
