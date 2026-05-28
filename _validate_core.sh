#!/usr/bin/env bash
# =============================================================================
# _validate_core.sh
# Purpose: Validate that all 13 Flutter portfolio apps still build AND pass
#          tests after a change to packages/calcwise_core (the shared library).
#
# Usage:   bash _validate_core.sh
# Output:  Per-app build + test result (green ✅ or red ❌) + final X/13 summary.
# Exit:    0 if all 13 passed, 1 if any app failed.
#
# ARCHIVÉS (2026-05-19) — retirés du validate :
#   ParkSmart  → D:\mob\_ARCHIVE\ParkSmart
#   RideProfit → D:\mob\_ARCHIVE\RideProfit  (GitHub repo archivé)
# =============================================================================

ROOT="D:/mob"

# Apps without --flavor
APPS_NO_FLAVOR=(
  CreditCardAPR
  HELOCApp
  JobOfferUS
  LoanPayoffUS
  MortgageCA
  MortgageUK
  MortgageUS
  PropertyROISuite
  RentBuyUS
  RentalExpenses
  StudentLoan
)

# Apps with --flavor us
APPS_WITH_FLAVOR=(
  AutoLoan
  SalaryApp
)

TOTAL=13
PASSED=0
FAILED=0

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

echo ""
echo "============================================================"
echo "  calcwise_core validation — Build + Tests"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

# ----------------------------------------------------------------
# Helper: build + test one app
# $1 = app name   $2 = extra flutter build args (e.g. "--flavor us")
# ----------------------------------------------------------------
validate_app() {
  local app="$1"
  local extra_args="$2"
  local dir="$ROOT/$app"

  if [[ ! -f "$dir/pubspec.yaml" ]]; then
    echo -e "${YELLOW}⚠️  SKIP${RESET}  $app  (no pubspec.yaml)"
    return
  fi

  cd "$dir"

  # ── Step 1: flutter pub get ──────────────────────────────────
  flutter pub get > /dev/null 2>&1

  # ── Step 2: flutter test ─────────────────────────────────────
  local test_result
  test_result=$(flutter test --no-pub 2>&1 | tail -1)

  if echo "$test_result" | grep -qi "failed\|error"; then
    echo -e "${RED}❌  FAILED${RESET}  $app — tests: $test_result"
    (( FAILED++ ))
    cd "$ROOT"
    return
  fi

  # ── Step 3: flutter build apk (with one retry for transient Gradle issues) ──
  local build_last
  build_last=$(flutter build apk --debug $extra_args 2>&1 \
    | grep -E "Built |FAILED|Error" | tail -1)

  if [[ -z "$build_last" ]]; then
    build_last="(no output captured)"
  fi

  # Retry once for transient Dart engine / Gradle daemon issues
  if echo "$build_last" | grep -qi "FAILED\|Error"; then
    sleep 5
    build_last=$(flutter build apk --debug $extra_args 2>&1 \
      | grep -E "Built |FAILED|Error" | tail -1)
    if [[ -z "$build_last" ]]; then
      build_last="(no output captured on retry)"
    fi
  fi

  if echo "$build_last" | grep -qi "FAILED\|Error"; then
    echo -e "${RED}❌  FAILED${RESET}  $app — build: $build_last"
    (( FAILED++ ))
  else
    # Extract test count from result line (e.g. "+47: All tests passed!")
    local test_count
    test_count=$(echo "$test_result" | grep -oE '\+[0-9]+' | tail -1 | tr -d '+')
    local test_label="${test_count:+${test_count} tests ✓, }build OK"
    echo -e "${GREEN}✅  OK${RESET}     $app — $test_label"
    (( PASSED++ ))
  fi

  cd "$ROOT"
}

# ── Build + test all apps ────────────────────────────────────────
echo "Phase 1/2 — Running tests + builds (this takes ~20-30 min)..."
echo ""

for app in "${APPS_NO_FLAVOR[@]}"; do
  validate_app "$app" ""
done

for app in "${APPS_WITH_FLAVOR[@]}"; do
  validate_app "$app" "--flavor us"
done

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo -e "  Result: ${GREEN}${PASSED}${RESET} / ${TOTAL} passed   ${RED}${FAILED}${RESET} failed"
echo "============================================================"
echo ""

[[ $FAILED -gt 0 ]] && exit 1
exit 0
