#!/usr/bin/env bash
ROOT="/d/mob"
LOG="$ROOT/_build_results_$(date +%Y%m%d_%H%M%S).log"
GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
echo "" | tee "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
echo "  Builds 2x2 — $(date '+%H:%M')" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"

build_one() {
  local app="$1" extra="${2:-}"
  cd "$ROOT/$app" || { echo "❌  $app — dir not found" | tee -a "$LOG"; return 1; }
  flutter pub get > /dev/null 2>&1
  local out
  out=$(flutter build apk --debug $extra 2>&1)
  if echo "$out" | grep -qi "Built build"; then
    echo -e "${GREEN}✅${RESET}  $app" | tee -a "$LOG"
  else
    local err=$(echo "$out" | grep -iE "FAILED|Error:" | head -1)
    echo -e "${RED}❌${RESET}  $app — ${err:-build failed}" | tee -a "$LOG"
  fi
}

# Pair 1
build_one "HELOCApp"       &  build_one "LoanPayoffUS"     & wait
# Pair 2
build_one "MortgageCA"     &  build_one "MortgageUK"       & wait
# Pair 3
build_one "MortgageUS"     &  build_one "PropertyROISuite" & wait
# Pair 4
build_one "RentBuyUS"      &  build_one "RentalExpenses"   & wait
# Pair 5
build_one "CreditCardAPR"  &  build_one "JobOfferUS"       & wait
# Pair 6
build_one "ParkSmart"      &  build_one "StudentLoan"      & wait
# Pair 7
build_one "rideprofit"     &  build_one "AutoLoan" "--flavor us" & wait
# Pair 8
build_one "SalaryApp" "--flavor us" & wait

echo "" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
PASS=$(grep -c "✅" "$LOG" || true)
FAIL=$(grep -c "❌" "$LOG" || true)
echo "  ${PASS}/15 OK   ${FAIL} FAILED" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
