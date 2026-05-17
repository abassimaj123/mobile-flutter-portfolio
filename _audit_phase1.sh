#!/usr/bin/env bash
ROOT="/d/mob"

APPS=(
  AutoLoan CreditCardAPR HELOCApp JobOfferUS LoanPayoffUS
  MortgageCA MortgageUK MortgageUS ParkSmart PropertyROISuite
  RentBuyUS RentalExpenses rideprofit SalaryApp StudentLoan
)

GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
PASSED=0; FAILED=0; TOTAL=${#APPS[@]}

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Phase 1 — flutter analyze (zéro erreurs)"
echo "══════════════════════════════════════════════════════"
echo ""

for app in "${APPS[@]}"; do
  dir="$ROOT/$app"
  cd "$dir" || continue
  output=$(flutter analyze --no-pub 2>&1)
  # Flutter 3.x uses "error - " format (not old "error •")
  err=$(echo "$output" | grep -cE "^  error - |error •" || true)
  if [[ $err -gt 0 ]]; then
    echo -e "${RED}❌${RESET}  $app — $err erreur(s)"
    (( FAILED++ ))
  else
    echo -e "${GREEN}✅${RESET}  $app — 0 erreurs"
    (( PASSED++ ))
  fi
done

echo ""
echo "══════════════════════════════════════════════════════"
echo -e "  ${GREEN}${PASSED}${RESET}/${TOTAL} clean   ${RED}${FAILED}${RESET} en erreur"
echo "══════════════════════════════════════════════════════"
echo ""
[[ $FAILED -gt 0 ]] && exit 1; exit 0
