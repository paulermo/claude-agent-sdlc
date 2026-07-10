#!/bin/bash
# agent-sdlc SessionStart hook.
# In SDLC-initialized projects, injects a state summary so every session
# (including agents in worktrees) starts aware of the pipeline state.
# Silent no-op everywhere else.

STATE_DIR="docs/state"
PROJECT_JSON="$STATE_DIR/project.json"

[ -f "$PROJECT_JSON" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

NAME=$(jq -r '.name // "unknown"' "$PROJECT_JSON" 2>/dev/null)
PREFIX=$(jq -r '.prefix // "?"' "$PROJECT_JSON" 2>/dev/null)
PHASE=$(jq -r '.phase // "unknown"' "$PROJECT_JSON" 2>/dev/null)
WORKTREES=$(jq -r '.worktrees | length' "$PROJECT_JSON" 2>/dev/null || echo 0)

summarize() { # $1 = state file with a flat map of entries having .status (legacy v1 layout)
  [ -f "$1" ] || { echo "none"; return; }
  jq -r 'to_entries | map(.value.status) | group_by(.) | map("\(.[0]): \(length)") | join(", ") // "none"' "$1" 2>/dev/null || echo "unreadable"
}

summarize_kind() { # $1 = stories|content_tasks — across active.json + backlog.json (v2 layout)
  jq -r --arg k "$1" -s '[.[] | (.[$k] // {}) | to_entries[] | .value.status] | group_by(.) | map("\(.[0]): \(length)") | join(", ") // "none"' \
    "$STATE_DIR/active.json" "$STATE_DIR/backlog.json" 2>/dev/null || echo "unreadable"
}

EPICS=$([ -f "$STATE_DIR/epics.json" ] && jq -r '.epics | to_entries | map(.value.status) | group_by(.) | map("\(.[0]): \(length)") | join(", ") // "none"' "$STATE_DIR/epics.json" 2>/dev/null || echo "none")
if [ -f "$STATE_DIR/active.json" ]; then
  STORIES=$(summarize_kind stories)
  CONTENT=$(summarize_kind content_tasks)
  ARCHIVED=$(cat "$STATE_DIR"/archive/done-*.json 2>/dev/null | jq -s '[.[] | (.stories // {} | length) + (.content_tasks // {} | length)] | add // 0' 2>/dev/null || echo 0)
else
  STORIES=$(summarize "$STATE_DIR/stories.json")
  CONTENT=$(summarize "$STATE_DIR/content-tasks.json")
  ARCHIVED=0
fi
DIRECTIVES=$(find docs/directives/active -type f 2>/dev/null | wc -l | tr -d ' ')

CONTEXT="## agent-sdlc pipeline state (auto-injected)

Project: ${NAME} (${PREFIX}) | Phase: ${PHASE}
Epics: ${EPICS:-none}
Stories: ${STORIES:-none}
Content tasks: ${CONTENT:-none}
Archived done items: ${ARCHIVED:-0}
Active worktrees: ${WORKTREES} | Pending directives: ${DIRECTIVES}

Rules of this project:
- Everything under docs/state/ is written ONLY by the PM orchestrator session (single-writer). If you are a dispatched agent: never edit state files — end with your report envelope instead.
- Project rules in .claude/rules/ are law for all code work.
- /agent-sdlc:status shows details; /agent-sdlc:start continues the pipeline."

jq -n \
  --arg msg "agent-sdlc: state loaded (${PHASE}, ${WORKTREES} worktrees, ${DIRECTIVES} directives)" \
  --arg ctx "$CONTEXT" \
  '{
    "systemMessage": $msg,
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": $ctx
    }
  }'
