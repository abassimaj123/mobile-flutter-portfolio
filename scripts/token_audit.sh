#!/usr/bin/env bash
# token_audit.sh — Calcwise design token compliance scanner
# Scans lib/screens/ and lib/widgets/ only, excludes PDF import files
# Usage: ./scripts/token_audit.sh [app_name|all]
# Returns: per-app score and total violation count

set -euo pipefail

APPS=(AutoLoan CreditCardAPR HELOCApp JobOfferUS LoanPayoffUS MortgageCA MortgageUK MortgageUS PropertyROISuite RentBuyUS RentalExpenses rideprofit SalaryApp StudentLoan TaxeCA)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Grade thresholds
grade() {
  local count=$1
  if [ "$count" -eq 0 ]; then echo -e "${GREEN}A+${RESET}"
  elif [ "$count" -le 5 ]; then echo -e "${GREEN}A${RESET}"
  elif [ "$count" -le 15 ]; then echo -e "${YELLOW}B${RESET}"
  elif [ "$count" -le 30 ]; then echo -e "${YELLOW}C${RESET}"
  else echo -e "${RED}D${RESET}"
  fi
}

scan_app() {
  local app=$1
  local app_dir="$ROOT_DIR/$app/lib"

  if [ ! -d "$app_dir" ]; then
    echo -e "  ${RED}✗ $app: directory not found${RESET}"
    return 1
  fi

  # Find dart files in screens/ and widgets/ only (not services, models, PDF gen)
  local scan_dirs=()
  [ -d "$app_dir/screens" ] && scan_dirs+=("$app_dir/screens")
  [ -d "$app_dir/widgets" ] && scan_dirs+=("$app_dir/widgets")
  [ -d "$app_dir/presentation" ] && scan_dirs+=("$app_dir/presentation")
  [ -d "$app_dir/ui" ] && scan_dirs+=("$app_dir/ui")

  if [ ${#scan_dirs[@]} -eq 0 ]; then
    scan_dirs+=("$app_dir")
  fi

  # Collect non-PDF dart files
  local tmpfile
  tmpfile=$(mktemp)

  for dir in "${scan_dirs[@]}"; do
    find "$dir" -name "*.dart" 2>/dev/null | while read -r f; do
      # Skip files that import the PDF package (false positive source)
      if ! grep -q "package:pdf/" "$f" 2>/dev/null; then
        echo "$f"
      fi
    done
  done > "$tmpfile"

  local file_count
  file_count=$(wc -l < "$tmpfile")

  # Count violations
  local spacing_violations=0
  local radius_violations=0
  local color_violations=0

  if [ "$file_count" -gt 0 ]; then
    # Hardcoded spacing: EdgeInsets with numeric literal, SizedBox height/width with number
    spacing_violations=$(xargs grep -hE \
      'EdgeInsets\.(all|symmetric|only|fromLTRB)\s*\(\s*[0-9]+|SizedBox\s*\(\s*(height|width)\s*:\s*[0-9]+' \
      < "$tmpfile" 2>/dev/null | \
      grep -v 'AppSpacing\.' | \
      grep -v '\/\/' | \
      wc -l || true)

    # Hardcoded radius: BorderRadius.circular with number
    radius_violations=$(xargs grep -hE \
      'BorderRadius\.circular\s*\(\s*[0-9]+' \
      < "$tmpfile" 2>/dev/null | \
      grep -v 'AppRadius\.' | \
      grep -v '\/\/' | \
      wc -l || true)

    # Raw semantic colors: Colors.green/red/orange etc (not white/black/transparent/grey)
    color_violations=$(xargs grep -hE \
      'Colors\.(green|red|orange|yellow|amber|teal|cyan|pink|purple|deepOrange|lightGreen)[^A-Za-z]' \
      < "$tmpfile" 2>/dev/null | \
      grep -v 'CalcwiseSemanticColors\.' | \
      grep -v '\/\/' | \
      wc -l || true)
  fi

  rm -f "$tmpfile"

  local total=$((spacing_violations + radius_violations + color_violations))
  local app_grade
  app_grade=$(grade "$total")

  printf "  %-20s  spacing:%-4s  radius:%-4s  colors:%-4s  total:%-4s  %s\n" \
    "$app" "$spacing_violations" "$radius_violations" "$color_violations" "$total" "$app_grade"

  echo "$total"
}

# Main
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
    count=$(scan_app "$app" 2>/dev/null || echo "0")
    total_violations=$((total_violations + count))
    app_count=$((app_count + 1))
  done
else
  count=$(scan_app "$target")
  total_violations=$count
  app_count=1
fi

echo ""
echo -e "${BOLD}─────────────────────────────────────────────────────${RESET}"
echo -e "  Apps scanned: $app_count"
echo -e "  Total violations: $total_violations"
overall_grade=$(grade "$total_violations")
echo -e "  Portfolio grade: $overall_grade"
echo ""

# Exit 1 if CI mode and violations found
if [ "${CI:-false}" = "true" ] && [ "$total_violations" -gt 0 ]; then
  echo -e "${YELLOW}⚠  Token violations detected. Run: bash scripts/token_audit.sh <app>${RESET}"
  exit 1
fi
