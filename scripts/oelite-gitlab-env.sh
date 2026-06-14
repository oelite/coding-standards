#!/bin/zsh
# oelite-gitlab-env.sh
# Source this file to load GitLab PATs from macOS Keychain into environment variables.
# Usage: source scripts/oelite-gitlab-env.sh
# NEVER commit this file with actual tokens — it reads from Keychain at runtime.

OELITE_GITLAB_HOST="https://code.phanes.ltd"
OELITE_GITLAB_API="$OELITE_GITLAB_HOST/api/v4"

_agents=(emma marcus daniel sophia jonathan olivia ethan maya victor grace felix isabella)
_loaded=0
_failed=0

for agent in $_agents; do
  var_name="OELITE_PAT_${agent:u}"
  pat=$(security find-generic-password -s "oelite-gitlab-$agent" -a "oelite" -w 2>/dev/null)
  if [[ -n "$pat" ]]; then
    export "${var_name}=$pat"
    ((_loaded++))
  else
    echo "[WARN] PAT not found in Keychain for: $agent (service: oelite-gitlab-$agent)" >&2
    ((_failed++))
  fi
done

export OELITE_GITLAB_HOST OELITE_GITLAB_API

if [[ $_failed -gt 0 ]]; then
  echo "[WARN] $_failed PAT(s) missing from Keychain. $_loaded loaded successfully." >&2
else
  echo "[OK] $_loaded GitLab PATs loaded from Keychain."
fi

unset _agents _loaded _failed agent var_name pat
