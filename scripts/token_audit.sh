#!/usr/bin/env bash
# token_audit.sh — Calcwise design token compliance scanner
# Scans lib/screens/ and lib/widgets/ only, excludes PDF import files
# Usage: ./scripts/token_audit.sh [app_name|all]
# Returns: per-app score and total violation count

set -euo pipefail

APPS=(AutoLoan CreditCardAPR HELOCApp JobOfferUS LoanPayoffUS MortgageCA MortgageUK MortgageUS PropertyROISuite RentBuyUS RentalExpenses rideprofit SalaryApp StudentLoan)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

# Global — set by scan_app, read by caller (avoids subshell capture issues)
LAST_COUNT=0

# Grade thresholds
grade() {
  local count=$1
  if   [ "$count" -eq 0 ];  then echo -e "${GREEN}A+${RESET}"
  elif [ "$count" -le 5 ];  then echo -e "${GREEN}A${RESET}"
  elif [ "$count" -le 15 ]; then echo -e "${YELLOW}B${RESET}"
  elif [ "$count" -le 30 ]; then echo -e "${YELLOW}C${RESET}"
  else                            echo -e "${RED}D${RESET}"
  fi
}

scan_app() {
  # grep returns exit 1 for "no matches" — disable pipefail locally
  set +o pipefail
  local app=$1
  local app_dir="$ROOT_DIR/$app/lib"

  if [ ! -d "$app_dir" ]; then
    printf "  %-20s  %s\n" "$app" "directory not found — skipped"
    LAST_COUNT=0
    return 0
  fi

  # Collect directories to scan (UI only — not services, models, PDF gen)
  local scan_dirs=()
  [ -d "$app_dir/screens" ]      && scan_dirs+=("$app_dir/screens")
  [ -d "$app_dir/widgets" ]      && scan_dirs+=("$app_dir/widgets")
  [ -d "$app_dir/presentation" ] && scan_dirs+=("$app_dir/presentation")
  [ -d "$app_dir/ui" ]           && scan_dirs+=("$app_dir/ui")
  [ ${#scan_dirs[@]} -eq 0 ]     && scan_dirs+=("$app_dir")

  # Build list of non-PDF dart files into a temp file
  local tmpfile
  tmpfile=$(mktemp)

  for dir in "${scan_dirs[@]}"; do
    find "$dir" -name "*.dart" 2>/dev/null | while read -r f; do
      # Skip files that import the PDF package (false positive source)
      grep -q "package:pdf/" "$f" 2>/dev/null || echo "$f"
    done
  done > "$tmpfile"

  local file_count
  file_count=$(wc -l < "$tmpfile" | tr -d ' ')

  local spacing_violations=0
  local radius_violations=0
  local color_violations=0

  if [ "$file_count" -gt 0 ]; then
    spacing_violations=$(xargs grep -hE \
      'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(\s*[0-9]+|SizedBox\s*\(\s*(height|width)\s*:\s*[0-9]+' \
      < "$tmpfile" 2>/dev/null \
      | grep -Ev 'AppSpacing\.|^\s*//' \
      | wc -l); spacing_violations=${spacing_violations//[[:space:]]/}

    radius_violations=$(xargs grep -hE \
      'BorderRadius\.circular\s*\(\s*[0-9]+' \
      < "$tmpfile" 2>/dev/null \
      | grep -Ev 'AppRadius\.|^\s*//' \
      | wc -l); radius_violations=${radius_violations//[[:space:]]/}

    color_violations=$(xargs grep -hE \
      'Colors\.(green|red|orange|yellow|amber|teal|cyan|pink|purple|deepOrange|lightGreen)[^A-Za-z]' \
      < "$tmpfile" 2>/dev/null \
      | grep -Ev 'CalcwiseSemanticColors\.|^\s*//' \
      | wc -l); color_violations=${color_violations//[[:space:]]/}
  fi

  rm -f "$tmpfile"

  local total=$(( spacing_violations + radius_violations + color_violations ))
  local app_grade
  app_grade=$(grade "$total")

  printf "  %-20s  spacing:%-4s  radius:%-4s  colors:%-4s  total:%-4s  %s\n" \
    "$app" "$spacing_violations" "$radius_violations" "$color_violations" "$total" "$app_grade"

  LAST_COUNT=$total
}

# ─── Main ────────────────────────────────────────────────────────────────────

target="${1:-all}"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     CALCWISE DESIGN TOKEN COMPLIANCE AUDIT           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo -e "  Scans: screens/, widgets/, presentation/ (excl. PDF files)"
echo -e "  Date: $(date '+%Y-%m-%d %H:%M')"
echo ""

total_violations=0
app_count=0

if [ "$target" = "all" ]; then
  for app in "${APPS[@]}"; do
    scan_app "$app"
    total_violations=$(( total_violations + LAST_COUNT ))
    app_count=$(( app_count + 1 ))
  done
else
  scan_app "$target"
  total_violations=$LAST_COUNT
  app_count=1
fi

echo ""
echo -e "${BOLD}─────────────────────────────────────────────────────${RESET}"
echo -e "  Apps scanned  : $app_count"
echo -e "  Total violations: $total_violations"
overall_grade=$(grade "$total_violations")
echo -e "  Portfolio grade : $overall_grade"
echo ""

# Exit 1 in CI mode if any violations found
if [ "${CI:-false}" = "true" ] && [ "$total_violations" -gt 0 ]; then
  echo -e "${YELLOW}⚠  Token violations detected. Run locally: bash scripts/token_audit.sh <app>${RESET}"
  exit 1
fi
