#!/bin/bash
# agent-sdlc PostToolUse hook (Write|Edit).
# If an SDLC state file was just written, verify it is still valid JSON.
# Exit 2 feeds the error straight back to the model for an immediate fix —
# a corrupted state file otherwise surfaces much later as a broken dispatch.

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

[ -n "$FILE_PATH" ] || exit 0

case "$FILE_PATH" in
  *docs/state/*.json) ;;
  *) exit 0 ;;
esac

[ -f "$FILE_PATH" ] || exit 0

ERR=$(jq empty "$FILE_PATH" 2>&1)
if [ $? -ne 0 ]; then
  echo "agent-sdlc: $FILE_PATH is now INVALID JSON after your edit. Parser said: $ERR. Fix the file immediately — the pipeline cannot dispatch from corrupted state." >&2
  exit 2
fi

exit 0
