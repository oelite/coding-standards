#!/bin/zsh
# oelite-gitlab-env.sh
# Source this file to load GitLab PATs from macOS Keychain into environment variables.
# Usage: source scripts/oelite-gitlab-env.sh
# NEVER commit this file with actual tokens — it reads from Keychain at runtime.
#
# Features:
#   - Parallel PAT validation (all 12 agents validated simultaneously)
#   - PAT validity cache (skips re-validation within TTL, default 5 minutes)
#   - Pipe guard (prevents subshell sourcing that loses exports)
#
# IMPORTANT: Do NOT pipe this script through `tail` or any command.
# Piping creates a subshell and ALL exported PATs are lost in the parent shell.
# Use `source script.sh 2>/dev/null` to suppress output instead.

OELITE_GITLAB_HOST="https://code.phanes.ltd"
OELITE_GITLAB_API="$OELITE_GITLAB_HOST/api/v4"

# === PIPE GUARD ===
# Detect if this script is running in a subshell (piped output).
# When piped, `source` runs in a subshell and exports never reach the parent.
# We detect this by checking if we're not the main shell process.
# zsh: $$ is the PID of the shell, $ZSH_SUBSHELL indicates subshell depth.
if [[ "$ZSH_SUBSHELL" -gt 0 ]]; then
  echo "[FATAL] oelite-gitlab-env.sh was sourced in a subshell (detected via pipe)." >&2
  echo "        Piping 'source' through 'tail', 'grep', or any command" >&2
  echo "        creates a subshell. All exported PATs are LOST in the parent shell." >&2
  echo "" >&2
  echo "        CORRECT:  source scripts/oelite-gitlab-env.sh" >&2
  echo "        QUIET:    source scripts/oelite-gitlab-env.sh 2>/dev/null" >&2
  echo "        WRONG:    source scripts/oelite-gitlab-env.sh 2>&1 | tail -1" >&2
  echo "" >&2
  echo "        Exiting with no PATs loaded. Fix your sourcing pattern." >&2
  return 1 2>/dev/null || exit 1
fi

# Toggle PAT validation. Skipping is faster but lets stale tokens through.
_validate_pats="${OELITE_VALIDATE_PATS:-true}"

# PAT validity cache TTL in seconds (default: 300 = 5 minutes)
# Set OELITE_PAT_CACHE_TTL=0 to disable caching.
_pat_cache_ttl="${OELITE_PAT_CACHE_TTL:-300}"
_pat_cache_file="${TMPDIR:-/tmp}/oelite-pat-validity-$(id -u)"

_agents=(emma marcus daniel sophia jonathan olivia ethan maya victor grace felix isabella)
_loaded=0
_invalid=0
_missing=0

# ── Cache helpers ──
_pat_cache_age() {
  local file="$1"
  if [[ -f "$file" ]]; then
    local mtime
    mtime=$(stat -f %m "$file" 2>/dev/null || echo 0)
    echo $(( $(date +%s) - mtime ))
  else
    echo -1
  fi
}

_pat_cache_get() {
  local agent="$1"
  [[ -f "$_pat_cache_file" ]] && grep "^${agent}:" "$_pat_cache_file" 2>/dev/null | cut -d: -f2
}

# ── Determine if cache is fresh ──
_cache_fresh=false
if [[ "$_validate_pats" == "true" && "$_pat_cache_ttl" -gt 0 ]]; then
  local _cache_age
  _cache_age=$(_pat_cache_age "$_pat_cache_file")
  if [[ "$_cache_age" -ge 0 && "$_cache_age" -lt "$_pat_cache_ttl" ]]; then
    _cache_fresh=true
  fi
fi

# ── Phase 1: Load all PATs from Keychain (sequential) ──
# Keychain access is fast when warm (~10-50ms per call) and cannot be safely
# parallelized (Keychain may lock). We load all PATs first, then validate
# in parallel if needed.
typeset -A _pats

for agent in $_agents; do
  pat=$(security find-generic-password -s "oelite-gitlab-$agent" -a "oelite" -w 2>/dev/null) || true
  if [[ -z "$pat" ]]; then
    echo "[WARN] PAT not found in Keychain for: $agent (service: oelite-gitlab-$agent, account: oelite)" >&2
    _missing=$((_missing + 1))
    continue
  fi

  _pats[$agent]=$pat

  var_name="OELITE_PAT_${agent:u}"
  alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
  export "${var_name}=$pat"
  export "${alias_name}=$pat"
done

# ── Phase 2: Validate PATs (cached, parallel, or skipped) ──
_cache_entries=()

if [[ "$_validate_pats" == "true" ]]; then
  if [[ "$_cache_fresh" == "true" ]]; then
    # ── Cache hit: use cached validation results, skip curl entirely ──
    for agent in ${(k)_pats}; do
      cached=$(_pat_cache_get "$agent")
      if [[ "$cached" == "valid" ]]; then
        _loaded=$((_loaded + 1))
        _cache_entries+=("$agent:valid")
      else
        # Cached as invalid — unset the PAT
        _invalid=$((_invalid + 1))
        var_name="OELITE_PAT_${agent:u}"
        alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
        unset "$var_name"
        unset "$alias_name"
        echo "[FAIL] PAT for $agent is invalid or expired (cached result). Remove from Keychain and re-add." >&2
        _cache_entries+=("$agent:invalid")
      fi
    done
  else
    # ── Cache miss: validate all PATs in parallel ──
    local _tmpdir
    _tmpdir=$(mktemp -d)
    typeset -a _pids

    for agent in ${(k)_pats}; do
      (
        _status=$(curl -s -o /dev/null -w "%{http_code}" --header "PRIVATE-TOKEN: ${_pats[$agent]}" "$OELITE_GITLAB_API/user" 2>/dev/null) || true
        echo "$_status" > "$_tmpdir/$agent"
      ) &
      _pids+=($!)
    done

    # Wait for all validation jobs to complete
    for pid in $_pids; do
      wait "$pid" 2>/dev/null || true
    done

    # Collect results
    for agent in ${(k)_pats}; do
      local _status=""
      [[ -f "$_tmpdir/$agent" ]] && _status=$(< "$_tmpdir/$agent")
      if [[ "$_status" == "200" ]]; then
        _loaded=$((_loaded + 1))
        _cache_entries+=("$agent:valid")
      else
        _invalid=$((_invalid + 1))
        var_name="OELITE_PAT_${agent:u}"
        alias_name="OELITE_PAT_${agent[1]:u}${agent[2,-1]:l}"
        unset "$var_name"
        unset "$alias_name"
        echo "[FAIL] PAT for $agent is invalid or expired (HTTP $_status on /api/v4/user). Remove from Keychain and re-add." >&2
        _cache_entries+=("$agent:invalid")
      fi
    done

    # Write cache file for future loads
    if (( ${#_cache_entries[@]} > 0 )); then
      printf '%s\n' "${_cache_entries[@]}" | sort > "$_pat_cache_file"
    fi

    # Cleanup temp files
    rm -rf "$_tmpdir"
  fi
else
  # Validation disabled — just count all loaded PATs
  for agent in ${(k)_pats}; do
    _loaded=$((_loaded + 1))
  done
fi

export OELITE_GITLAB_HOST OELITE_GITLAB_API

if [[ $_missing -gt 0 || $_invalid -gt 0 ]]; then
  echo "[WARN] PAT load summary — loaded: $_loaded, missing: $_missing, invalid: $_invalid" >&2
  echo "Run 'security find-generic-password -s oelite-gitlab-<agent> -a oelite -w' to inspect a PAT." >&2
else
  if [[ "$_cache_fresh" == "true" ]]; then
    echo "[OK] $_loaded GitLab PATs loaded and validated (cache hit, TTL ${_pat_cache_ttl}s)." >&2
  else
    echo "[OK] $_loaded GitLab PATs loaded and validated." >&2
  fi
fi

unset _agents _loaded _invalid _missing _validate_pats _pat_cache_ttl _pat_cache_file _cache_age _cache_fresh _cache_entries _pats _pids _tmpdir _status agent var_name alias_name pat cached