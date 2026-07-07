#!/bin/bash
# agent-sdlc PreToolUse hook (Bash).
# In SDLC-initialized projects, denies git operations the pipeline forbids:
#   - force pushes (rewrite shared history the pipeline depends on)
#   - merge -X theirs / -X ours (silently discards one side's work)
# Silent no-op everywhere else.

[ -f "docs/state/project.json" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$CMD" ] || exit 0

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

if echo "$CMD" | grep -qE 'git[^|;&]*push[^|;&]*(--force([^-]|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  deny "agent-sdlc: force-push is forbidden in this pipeline — shared branches are the audit trail. If the push was rejected, investigate and resolve (pull --rebase, or report the conflict to the PM)."
fi

if echo "$CMD" | grep -qE 'git[^|;&]*merge[^|;&]*-X[[:space:]]*(theirs|ours)'; then
  deny "agent-sdlc: merge -X theirs/ours is forbidden — flag-level resolution silently discards one side's work. Read both sides of every conflict and COMBINE them (see the story-merge skill's conflict-resolution law)."
fi

exit 0
