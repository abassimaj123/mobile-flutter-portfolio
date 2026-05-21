#!/usr/bin/env bash
ROOT="/d/mob"
LOG="$ROOT/_build_results_$(date +%Y%m%d_%H%M%S).log"
GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
echo "" | tee "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
echo "  Builds 2x2 — $(date '+%H:%M')" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"

build_one() {
  local app="$1" label="${2:-$1}" extra="${3:-}"
  cd "$ROOT/$app" || { echo "❌  $label — dir not found" | tee -a "$LOG"; return 1; }
  flutter pub get > /dev/null 2>&1
  local out
  out=$(flutter build apk --debug $extra 2>&1)
  if echo "$out" | grep -qi "Built build"; then
    echo -e "${GREEN}✅${RESET}  $label" | tee -a "$LOG"
  else
    local err=$(echo "$out" | grep -iE "FAILED|Error:" | head -1)
    echo -e "${RED}❌${RESET}  $label — ${err:-build failed}" | tee -a "$LOG"
  fi
}

# Pair 1
build_one "HELOCApp"         "HELOCApp"         &
build_one "CreditCardAPR"    "CreditCardAPR"    &
wait

# Pair 2
build_one "JobOfferUS"       "JobOfferUS"       &
build_one "LoanPayoffUS"     "LoanPayoffUS"     &
wait

# Pair 3
build_one "MortgageCA"       "MortgageCA"       &
build_one "MortgageUK"       "MortgageUK"       &
wait

# Pair 4
build_one "MortgageUS"       "MortgageUS"       &
build_one "PropertyROISuite" "PropertyROISuite" &
wait

# Pair 5
build_one "RentBuyUS"        "RentBuyUS"        &
build_one "RentalExpenses"   "RentalExpenses"   &
wait

# Pair 6
build_one "StudentLoan"      "StudentLoan"      &
build_one "AutoLoan"         "AutoLoan-CA"      "--flavor ca" &
wait

# Pair 7
build_one "AutoLoan"         "AutoLoan-UK"      "--flavor uk" &
build_one "AutoLoan"         "AutoLoan-US"      "--flavor us" &
wait

# Pair 8
build_one "SalaryApp"        "SalaryApp-CA"     "--flavor ca" &
build_one "SalaryApp"        "SalaryApp-UK"     "--flavor uk" &
wait

# Final
build_one "SalaryApp"        "SalaryApp-US"     "--flavor us"

echo "" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
PASS=$(grep -c "✅" "$LOG" || true)
FAIL=$(grep -c "❌" "$LOG" || true)
echo "  ${PASS}/15 OK   ${FAIL} FAILED" | tee -a "$LOG"
echo "══════════════════════════════════════════" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Log: $LOG"
