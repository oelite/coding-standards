#!/bin/zsh
# oelite-gitlab-env.sh
# Source this file to load GitLab PATs from macOS Keychain into environment variables.
# Usage: source scripts/oelite-gitlab-env.sh
# NEVER commit this file with actual tokens — it reads from Keychain at runtime.

OELITE_GITLAB_HOST="https://code.phanes.ltd"
OELITE_GITLAB_API="$OELITE_GITLAB_HOST/api/v4"

# Toggle PAT validation. Skipping is faster but lets stale tokens through.
_validate_pats="${OELITE_VALIDATE_PATS:-true}"

_agents=(emma marcus daniel sophia jonathan olivia ethan maya victor grace felix isabella)
_loaded=0
_invalid=0
_missing=0

for agent in $_agents; do
  var_name="OELITE_PAT_${agent:u}"
  pat=$(security find-generic-password -s "oelite-gitlab-$agent" -a "oelite" -w 2>/dev/null) || true
  if [[ -z "$pat" ]]; then
    echo "[WARN] PAT not found in Keychain for: $agent (service: oelite-gitlab-$agent, account: oelite)" >&2
    _missing=$((_missing + 1))
    continue
  fi

  export "${var_name}=$pat"

  local alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
  export "${alias_name}=$pat"

  _valid=true

  if [[ "$_validate_pats" == "true" ]]; then
    # Validate token by calling /user. GitLab returns 401 for invalid tokens.
    _status=$(curl -s -o /dev/null -w "%{http_code}" --header "PRIVATE-TOKEN: $pat" "$OELITE_GITLAB_API/user" 2>/dev/null) || true
    if [[ "$_status" != "200" ]]; then
      echo "[FAIL] PAT for $agent is invalid or expired (HTTP $_status on /api/v4/user). Remove from Keychain and re-add." >&2
      unset "$var_name"
      unset "$alias_name"
      _valid=false
      _invalid=$((_invalid + 1))
    fi
    unset _status
  fi

  if $_valid; then
    _loaded=$((_loaded + 1))
  fi
done

export OELITE_GITLAB_HOST OELITE_GITLAB_API

if [[ $_missing -gt 0 || $_invalid -gt 0 ]]; then
  echo "[WARN] PAT load summary — loaded: $_loaded, missing: $_missing, invalid: $_invalid" >&2
  echo "Run 'security find-generic-password -s oelite-gitlab-<agent> -a oelite -w' to inspect a PAT." >&2
else
  echo "[OK] $_loaded GitLab PATs loaded and validated."
fi

unset _agents _loaded _invalid _missing _validate_pats _valid agent var_name alias_name pat
