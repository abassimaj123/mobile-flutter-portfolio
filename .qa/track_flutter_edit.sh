#!/bin/bash
# =============================================================================
# track_flutter_edit.sh  — PostToolUse hook (Edit + Write)
# Tracks which D:/mob/<App> directories were touched during a session.
# Fast (< 5ms): no analysis, just appends app path to a temp session file.
#
# INSTALL:
#   cp /d/mob/.qa/track_flutter_edit.sh /c/Users/DALI/.claude/hooks/
#   chmod +x /c/Users/DALI/.claude/hooks/track_flutter_edit.sh
#
# Input: JSON via stdin — { tool_name, tool_input: { file_path }, tool_response }
# =============================================================================

INPUT=$(cat)

# Extract file_path from JSON
FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"\K[^"]+' | head -1)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only track files inside D:/mob/ (Windows or Unix style)
if echo "$FILE_PATH" | grep -qiE '^([Dd][:/\\]mob[/\\]|/d/mob/)'; then
  # Normalize to /d/mob/AppName
  NORM=$(echo "$FILE_PATH" \
    | sed 's|[Dd]:\\|/d/|g; s|\\|/|g' \
    | sed 's|[Dd]:/mob|/d/mob|g')
  APP_PATH=$(echo "$NORM" | grep -oP '^/d/mob/[^/]+')

  if [ -n "$APP_PATH" ]; then
    SESSION_ID="${CLAUDE_SESSION_ID:-default}"
    SESSION_FILE="/tmp/claude_flutter_edits_${SESSION_ID}.txt"
    echo "$APP_PATH" >> "$SESSION_FILE"
    sort -u "$SESSION_FILE" -o "$SESSION_FILE"
  fi
fi

exit 0
