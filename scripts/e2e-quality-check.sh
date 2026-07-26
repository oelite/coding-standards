#!/bin/zsh
# ============================================================================
# E2E Quality Check Script — OElite Platform
# ============================================================================
# Detects prohibited patterns, missing API verification, and insufficient test
# depth BEFORE merge approval.
#
# USAGE:
#   ./e2e-quality-check.sh [--fix] [--dir <test-directory>] [--ci] [--verbose]
#
# EXIT CODES:
#   0 = All checks passed
#   1 = Violations found (CI mode)
#   2 = Script error
# ============================================================================

set -euo pipefail
SCRIPT_DIR="${0:A:h}"

TAUTOLOGICAL_PATTERNS=(
  'expect.*body.*toBeVisible'
  'expect.*html.*toBeVisible'
  'expect.*page.*toHaveURL()'
  'toBeGreaterThanOrEqual(0)'
)

FORBIDDEN_ASSERTION_PATTERNS=(
  'expect.*body.*toBeVisible'
  'expect.*html.*toBeVisible'
)

TARGET_DIR=""
FIX_MODE=false
CI_MODE=false
VERBOSE=false
VIOLATION_COUNT=0
FIXED_COUNT=0

print_header() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║  OElite E2E Quality Check                                      ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
}

print_section() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_violation() {
  local file="$1"
  local line="$2"
  local pattern="$3"
  echo "  ❌ $file:$line"
  echo "     Pattern: $pattern"
  VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
}

print_ok() {
  echo "  ✅ $1"
}

print_warning() {
  echo "  ⚠️  $1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) TARGET_DIR="$2"; shift 2 ;;
    --fix) FIX_MODE=true; shift ;;
    --ci) CI_MODE=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    --help)
      echo "Usage: $0 [--fix] [--dir <path>] [--ci] [--verbose]"
      echo "  --dir <path>    Target test directory (default: ./tests)"
      echo "  --fix           Auto-remove tautological assertions"
      echo "  --ci            CI mode — exit with error if violations found"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

print_header

if [[ -z "$TARGET_DIR" ]]; then
  for candidate in "tests" "e2e-tests" "specs"; do
    if [[ -d "$candidate" ]]; then
      TARGET_DIR="$candidate"
      break
    fi
  done
  if [[ -z "$TARGET_DIR" ]]; then
    for candidate in web/*/tests web/*/e2e; do
      if [[ -d "$candidate" ]]; then
        TARGET_DIR="$candidate"
        break
      fi
    done
  fi
  if [[ -z "$TARGET_DIR" ]]; then
    echo "[ERROR] No test directory found. Specify with --dir <path>"
    exit 2
  fi
  echo "  Auto-detected test directory: $TARGET_DIR"
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "[ERROR] Test directory not found: $TARGET_DIR"
  exit 2
fi

# CHECK 1: Tautological/No-Op Assertions
print_section "CHECK 1: Tautological/No-Op Assertions"
TAUTOLOGY_FOUND=false

for pattern in "${TAUTOLOGICAL_PATTERNS[@]}"; do
  while IFS= read -r result; do
    [[ -z "$result" ]] && continue
    file=$(echo "$result" | cut -d: -f1)
    line=$(echo "$result" | cut -d: -f2)
    
    if $FIX_MODE && [[ " ${FORBIDDEN_ASSERTION_PATTERNS[*]} " =~ " $pattern " ]]; then
      if sed -i '' "/$pattern/d" "$file" 2>/dev/null; then
        echo "  🔧 FIXED: Removed tautological assertion in $file:$line"
        FIXED_COUNT=$((FIXED_COUNT + 1))
      fi
    else
      print_violation "$file" "$line" "$pattern"
      TAUTOLOGY_FOUND=true
    fi
  done < <(grep -rn "$pattern" "$TARGET_DIR" 2>/dev/null || true)
done

if ! $TAUTOLOGY_FOUND; then
  print_ok "No tautological assertions found"
fi

# CHECK 2: page.route() Usage
print_section "CHECK 2: API Call Verification (page.route() Mandate)"
MISSING_ROUTE=false

while IFS= read -r test_file; do
  [[ -z "$test_file" ]] && continue
  if grep -q 'page\.goto\|page\.navigate' "$test_file" 2>/dev/null; then
    if ! grep -q 'page\.route' "$test_file" 2>/dev/null; then
      print_warning "$test_file navigates to pages but does not intercept API calls"
      MISSING_ROUTE=true
    fi
  fi
done < <(find "$TARGET_DIR" -name '*.spec.ts' -o -name '*.spec.tsx' 2>/dev/null || true)

if ! $MISSING_ROUTE; then
  print_ok "All data-driven tests use page.route() API interception"
fi

# CHECK 3: Button Works (Not Just Exists)
print_section "CHECK 3: Button-Works Verification"
POTENTIAL_BUTTON_ONLY=false

while IFS= read -r result; do
  [[ -z "$result" ]] && continue
  file=$(echo "$result" | cut -d: -f1)
  line=$(echo "$result" | cut -d: -f2)
  
  if ! grep -q 'click' "$file" 2>/dev/null; then
    print_violation "$file" "$line" "Button existence without click"
    POTENTIAL_BUTTON_ONLY=true
  fi
done < <(grep -rn 'toBeVisible\|toBeEnabled' "$TARGET_DIR" 2>/dev/null | grep -i 'button\|link\|submit\|save\|delete\|create\|edit\|cancel' || true)

if ! $POTENTIAL_BUTTON_ONLY; then
  print_ok "All interactive elements have action verification"
fi

# CHECK 4: AC Traceability
print_section "CHECK 4: AC Traceability (US-XXX/AC-YYY)"
AC_REF_COUNT=$(grep -rn 'US-[0-9]\|AC-[0-9]' "$TARGET_DIR" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$AC_REF_COUNT" -eq 0 ]]; then
  print_warning "No test files reference user story acceptance criteria"
else
  print_ok "$AC_REF_COUNT AC references found"
fi

# CHECK 5: Data Persistence
print_section "CHECK 5: Data Persistence (page.reload())"
PERSISTENCE_COUNT=$(grep -rn 'page\.reload\|page\.refresh' "$TARGET_DIR" 2>/dev/null | wc -l | tr -d ' ')

if [[ "$PERSISTENCE_COUNT" -eq 0 ]]; then
  print_warning "No tests verify data persistence via page.reload()"
else
  print_ok "$PERSISTENCE_COUNT persistence tests found"
fi

# SUMMARY
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if $FIX_MODE && [[ "$FIXED_COUNT" -gt 0 ]]; then
  echo "  🔧 Fixed $FIXED_COUNT tautological assertions"
fi

if [[ "$VIOLATION_COUNT" -eq 0 ]]; then
  echo "  ✅ ALL CHECKS PASSED"
else
  echo "  ❌ $VIOLATION_COUNT violations found"
  echo ""
  echo "  See: PROHIBITED-PATTERNS.md §5"
fi

echo ""

if $CI_MODE && [[ "$VIOLATION_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
