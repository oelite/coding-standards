#!/usr/bin/env bash
# =============================================================================
# verify-uat-deployed.sh — Artifact Continuity Check (Ethan / DevOps)
#
# Enforces GIT-WORKFLOW-STANDARDS.md §2.1.2 Rule 4 & Audit Item B6.
# Fails closed (exit 1) if the candidate image/commit SHA was never deployed
# to the UAT environment.
#
# Supported backends (via UAT_CHECK_BACKEND):
#   - kubectl (default): queries running deployments in oelite-uat for
#                        the annotation 'oelite.io/sha'
#   - gitlab: queries the GitLab Deployments API for 'uat' environment
#
# Self-test mode:
#   verify-uat-deployed.sh --test
# =============================================================================
set -euo pipefail

run_self_test() {
  local test_count=0
  local pass_count=0

  assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    test_count=$((test_count + 1))
    if [[ "$expected" == "$actual" ]]; then
      pass_count=$((pass_count + 1))
      echo "  [PASS] $msg"
    else
      echo "  [FAIL] $msg (expected: $expected, got: $actual)" >&2
      return 1
    fi
  }

  echo "Running verify-uat-deployed.sh self-tests..."

  # Test 1: Empty SHA should exit with usage error (exit 1)
  local rc=0
  ("$0" "" >/dev/null 2>&1) || rc=$?
  assert_eq "1" "$rc" "Empty SHA fails with exit code 1"

  # Test 2: Mock kubectl backend — SHA present in annotations -> exit 0
  local mock_dir
  mock_dir="$(mktemp -d "${TMPDIR:-/tmp}/verify-uat-test.XXXXXX")"
  cat <<'MOCK' > "$mock_dir/kubectl"
#!/usr/bin/env bash
if [[ "$*" == *"get deploy"* ]]; then
  echo "abc1234def5678 7890abcdef1234"
  exit 0
fi
exit 0
MOCK
  chmod +x "$mock_dir/kubectl"

  rc=0
  (
    export PATH="$mock_dir:$PATH"
    export UAT_CHECK_BACKEND=kubectl
    export PHANES_K8S="/fake/kubeconfig"
    "$0" "abc1234def5678" >/dev/null 2>&1
  ) || rc=$?
  assert_eq "0" "$rc" "kubectl backend: SHA present succeeds (exit 0)"

  # Test 3: Mock kubectl backend — SHA absent -> exit 1
  rc=0
  (
    export PATH="$mock_dir:$PATH"
    export UAT_CHECK_BACKEND=kubectl
    export PHANES_K8S="/fake/kubeconfig"
    "$0" "deadbeef9999" >/dev/null 2>&1
  ) || rc=$?
  assert_eq "1" "$rc" "kubectl backend: SHA absent fails (exit 1)"

  # Test 4: Mock gitlab backend — SHA present in deployments -> exit 0
  cat <<'MOCK_CURL' > "$mock_dir/curl"
#!/usr/bin/env bash
# Mock GitLab API response
cat <<'JSON'
[
  {"id": 1, "sha": "abc1234def5678", "status": "success", "environment": {"name": "uat"}},
  {"id": 2, "sha": "11112222333344", "status": "success", "environment": {"name": "uat"}}
]
JSON
exit 0
MOCK_CURL
  chmod +x "$mock_dir/curl"

  rc=0
  (
    export PATH="$mock_dir:$PATH"
    export UAT_CHECK_BACKEND=gitlab
    export CI_API_V4_URL="https://code.phanes.ltd/api/v4"
    export CI_PROJECT_ID="123"
    export GITLAB_TOKEN="mock-token"
    "$0" "abc1234def5678" >/dev/null 2>&1
  ) || rc=$?
  assert_eq "0" "$rc" "gitlab backend: SHA present succeeds (exit 0)"

  # Test 5: Mock gitlab backend — SHA absent -> exit 1
  rc=0
  (
    export PATH="$mock_dir:$PATH"
    export UAT_CHECK_BACKEND=gitlab
    export CI_API_V4_URL="https://code.phanes.ltd/api/v4"
    export CI_PROJECT_ID="123"
    export GITLAB_TOKEN="mock-token"
    "$0" "deadbeef9999" >/dev/null 2>&1
  ) || rc=$?
  assert_eq "1" "$rc" "gitlab backend: SHA absent fails (exit 1)"

  rm -rf "$mock_dir"

  echo "Self-tests completed: $pass_count/$test_count passed."
  if [[ "$test_count" -ne "$pass_count" ]]; then
    return 1
  fi
  return 0
}

if [[ "${1:-}" == "--test" ]]; then
  run_self_test
  exit 0
fi

SHA="${1:-}"
if [[ -z "$SHA" ]]; then
  echo "Usage: verify-uat-deployed.sh <sha>" >&2
  echo "       verify-uat-deployed.sh --test" >&2
  exit 1
fi

BACKEND="${UAT_CHECK_BACKEND:-kubectl}"

case "$BACKEND" in
  kubectl)
    # Check running deployments in the oelite-uat namespace for the oelite.io/sha annotation.
    # Accepts $PHANES_K8S env var as kubeconfig if defined.
    KUBECTL_CMD=(kubectl)
    if [[ -n "${PHANES_K8S:-}" && -f "${PHANES_K8S}" ]]; then
      KUBECTL_CMD+=(--kubeconfig "$PHANES_K8S")
    fi

    NAMESPACE="${UAT_NAMESPACE:-oelite-uat}"

    DEPLOYED_SHAS="$("${KUBECTL_CMD[@]}" -n "$NAMESPACE" \
      get deploy -o jsonpath='{.items[*].metadata.annotations.oelite\.io/sha}' 2>/dev/null || true)"

    if [[ -z "$DEPLOYED_SHAS" ]] || ! echo "$DEPLOYED_SHAS" | grep -q "$SHA"; then
      echo "ERROR: Image/Commit SHA '$SHA' was never deployed to UAT ($NAMESPACE)." >&2
      echo "       Artifact continuity check failed (GIT-WORKFLOW-STANDARDS.md §2.1.2 rule 4)." >&2
      exit 1
    fi
    ;;

  gitlab)
    # Check GitLab Environments / Deployments API for project's UAT environment
    API_URL="${CI_API_V4_URL:-https://code.phanes.ltd/api/v4}"
    PROJECT_ID="${CI_PROJECT_ID:-}"
    TOKEN="${GITLAB_TOKEN:-${CI_JOB_TOKEN:-}}"

    if [[ -z "$PROJECT_ID" ]]; then
      echo "ERROR: CI_PROJECT_ID is required when UAT_CHECK_BACKEND=gitlab" >&2
      exit 1
    fi

    CURL_AUTH=()
    if [[ -n "$TOKEN" ]]; then
      if [[ -n "${CI_JOB_TOKEN:-}" && "$TOKEN" == "$CI_JOB_TOKEN" ]]; then
        CURL_AUTH=(-H "JOB-TOKEN: $TOKEN")
      else
        CURL_AUTH=(-H "PRIVATE-TOKEN: $TOKEN")
      fi
    fi

    # Fetch successful deployments for 'uat' environment
    RESPONSE="$(curl -s -f "${CURL_AUTH[@]}" \
      "${API_URL}/projects/${PROJECT_ID}/deployments?environment=uat&status=success" 2>/dev/null || true)"

    if [[ -z "$RESPONSE" ]] || ! echo "$RESPONSE" | grep -q "$SHA"; then
      echo "ERROR: Image/Commit SHA '$SHA' was never deployed to UAT (GitLab environment: uat)." >&2
      echo "       Artifact continuity check failed (GIT-WORKFLOW-STANDARDS.md §2.1.2 rule 4)." >&2
      exit 1
    fi
    ;;

  *)
    echo "ERROR: Unsupported UAT_CHECK_BACKEND '$BACKEND'. Supported values: kubectl, gitlab" >&2
    exit 1
    ;;
esac

echo "OK: Image/Commit SHA '$SHA' verified as deployed to UAT ($BACKEND backend)."
exit 0
