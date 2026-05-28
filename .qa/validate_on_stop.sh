#!/bin/bash
# =============================================================================
# validate_on_stop.sh  — Stop hook
# After each Claude session: runs flutter analyze on all modified apps.
# For calcwise_core: also runs flutter test (1422 tests).
# Writes results to /d/mob/.qa/regression_log.md
#
# INSTALL:
#   cp /d/mob/.qa/validate_on_stop.sh /c/Users/DALI/.claude/hooks/
#   chmod +x /c/Users/DALI/.claude/hooks/validate_on_stop.sh
#
# Also run manually:
#   SESSION_FILE=/tmp/mylist.txt bash /d/mob/.qa/validate_on_stop.sh
# =============================================================================

SESSION_ID="${CLAUDE_SESSION_ID:-default}"
SESSION_FILE="/tmp/claude_flutter_edits_${SESSION_ID}.txt"
REPORT_FILE="/d/mob/.qa/regression_log.md"
SESSION_DATE=$(date '+%Y-%m-%d %H:%M')

# Nothing was modified in D:/mob/ → skip silently
if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
  exit 0
fi

APPS_OK=0
APPS_FAIL=0
FAIL_LIST=""

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  🔍 Flutter Portfolio — Non-Regression Check  ║"
echo "╚═══════════════════════════════════════════════╝"

# Ensure report file exists with header
if [ ! -f "$REPORT_FILE" ]; then
  mkdir -p "$(dirname "$REPORT_FILE")"
  cat > "$REPORT_FILE" <<'HEADER'
# Flutter Portfolio — Regression Log

Généré automatiquement après chaque session Claude.

| App | Status | Date |
|-----|--------|------|
HEADER
fi

# --- Process each modified app ---
while IFS= read -r APP_PATH; do
  APP_NAME=$(basename "$APP_PATH")
  echo ""
  echo "  ▶ $APP_NAME"

  if [ ! -d "$APP_PATH" ]; then
    echo "    ⚠️  Répertoire introuvable — skip"
    continue
  fi

  cd "$APP_PATH" || continue

  # ── calcwise_core : analyze + full test suite ──
  if echo "$APP_PATH" | grep -q "calcwise_core"; then
    echo "    [calcwise_core] dart analyze + flutter test..."
    ANALYZE_OUT=$(dart analyze lib/ --no-pub 2>&1 | tail -3)
    TEST_OUT=$(flutter test 2>&1 | tail -3)

    ANALYZE_OK=false
    TEST_OK=false
    echo "$ANALYZE_OUT" | grep -q "No issues found" && ANALYZE_OK=true
    echo "$TEST_OUT"    | grep -q "All tests passed"  && TEST_OK=true

    if $ANALYZE_OK && $TEST_OK; then
      echo "    ✅  analyze: clean | tests: all passed"
      echo "| $APP_NAME | ✅ analyze OK · tests OK | $SESSION_DATE |" >> "$REPORT_FILE"
      APPS_OK=$((APPS_OK + 1))
    else
      STATUS=""
      $ANALYZE_OK || STATUS+="❌ analyze issues "
      $TEST_OK    || STATUS+="❌ tests FAILED"
      echo "    $STATUS"
      $ANALYZE_OK || echo "$ANALYZE_OUT"
      $TEST_OK    || echo "$TEST_OUT"
      echo "| $APP_NAME | $STATUS | $SESSION_DATE |" >> "$REPORT_FILE"
      APPS_FAIL=$((APPS_FAIL + 1))
      FAIL_LIST+=" $APP_NAME"
    fi

  # ── App Flutter standard : flutter analyze ──
  else
    echo "    flutter analyze --no-pub..."
    ANALYZE_OUT=$(flutter analyze --no-pub 2>&1 | tail -3)

    if echo "$ANALYZE_OUT" | grep -q "No issues found"; then
      echo "    ✅  clean"
      echo "| $APP_NAME | ✅ clean | $SESSION_DATE |" >> "$REPORT_FILE"
      APPS_OK=$((APPS_OK + 1))
    else
      echo "    ❌  issues trouvés"
      echo "$ANALYZE_OUT"
      echo "| $APP_NAME | ❌ issues | $SESSION_DATE |" >> "$REPORT_FILE"
      APPS_FAIL=$((APPS_FAIL + 1))
      FAIL_LIST+=" $APP_NAME"
    fi
  fi

done < "$SESSION_FILE"

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════════"
if [ $APPS_FAIL -gt 0 ]; then
  echo "  ⚠️   $APPS_FAIL app(s) avec issues :$FAIL_LIST"
  echo "  ✅  $APPS_OK app(s) propres"
  echo "  ➜  Corriger avant le prochain commit"
else
  echo "  ✅  Tout propre — $APPS_OK app(s) validées"
fi
echo "  📋  Rapport → $REPORT_FILE"
echo "═══════════════════════════════════════════════"
echo ""

# Cleanup session tracking file
rm -f "$SESSION_FILE"

# Exit 0 even if issues — don't block (informational only)
exit 0
