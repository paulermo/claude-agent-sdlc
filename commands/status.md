---
name: "agent-sdlc:status"
description: "Display current SDLC project status"
---

Display the current SDLC project status. This is read-only — no agents are launched.

**Steps:**

1. **Read project state:**
   Read `docs/state/project.json`. If it doesn't exist, output:
   > "SDLC not initialized. Run `/agent-sdlc:init` first."
   and stop.

2. **Read state:**
   - Read `docs/state/epics.json` and `docs/state/active.json` fully.
   - Counts only, via Bash jq (do NOT Read these files):
     - backlog per status: `jq -r '[.stories,.content_tasks] | map(to_entries[]?.value.status) | group_by(.) | map("\(.[0]): \(length)") | join(", ")' docs/state/backlog.json`
     - archived total: `cat docs/state/archive/done-*.json 2>/dev/null | jq -s '[.[] | (.stories//{}|length)+(.content_tasks//{}|length)] | add // 0'`

3. **Determine project phase** (sdlc-state phase table):
   - `not_started` — no BRDs exist
   - `planning` — BRDs exist but epics are in `planning` status
   - `implementation` — at least one epic is `ready` or `in_progress`
   - `done` — `epics.json` has no epics left (all archived) and BRDs exist

4. **Count directives:**
   Count files in `docs/directives/active/`.

5. **Count active worktrees:**
   Count entries in `project.json.worktrees`.

6. **Format and output:**

   ```
   Project: {name} ({prefix})
   Phase: {phase}

   Epics:
     {PREFIX}-EPIC-001 {title}    [{done_stories}/{total_stories} stories done]  [{status}]
     {PREFIX}-EPIC-002 {title}    [{done_stories}/{total_stories} stories done]  [{status}]
     ...

   Active work:
     {PREFIX}-STORY-NNN {title}   [{status}]    → {next action}
     ...

   Content:
     {PREFIX}-CTASK-NNN {title}   [{status}]    → {next action}
     ...

   Backlog: {N} items across {M} not-started epics ({per-status counts})
   Archived: {N} done items

   Worktrees: {active}/{max} active
   Directives: {count} pending
   ```

   Where `{next action}` maps status to human-readable action:

   **Story statuses:**
   - `todo` → "waiting for Developer"
   - `in_progress` → "Developer working"
   - `ready_for_review` → "ready for Reviewer"
   - `in_review` → "Reviewer working"
   - `ready_for_qa` → "ready for QA"
   - `in_qa` → "QA testing"
   - `review_rejected` → "rejected by Reviewer, back to Developer"
   - `qa_rejected` → "rejected by QA, back to Developer"
   - `ready_for_merge` → "ready for Deploy (merge to feature branch)"
   - `merged` → "merged to feature branch, awaiting regression QA"
   - `regression_failed` → "regression failed, bug-story needed"
   - `done` → "completed"

   **Content task statuses (additional):**
   - `creating` → "Content Creator working"
   - `ready_for_integration` → "ready for Content Integrator"
   - `integrating` → "Content Integrator working"
   - `review_rejected` → "rejected by Content Reviewer, back to Content Creator"
   - `qa_rejected` (content) → "rejected by QA, back to Content Creator"
   - `qa_rejected` (integration) → "rejected by QA, back to Content Integrator"
   - `ready_for_merge` → "ready for Deploy (merge to content-epic branch)"
   - `merged` → "merged, awaiting regression QA"

   **Epic statuses:**
   - `planning` → "in planning" · `ready` → "ready to start" · `in_progress` → "stories in flight"
   - `ready_for_deploy` → "all stories done, ready for Deploy (merge to main)"
   - `deployed` → "on main, awaiting regression QA" · `frozen` → "frozen by directive" · `done` → "completed"

   Only show items in non-done statuses under "Active work" and "Content". Epic story counts come from `active.json` for in-flight epics and from the backlog jq counts for not-started ones.

7. **Verbose mode** (invoked as `/agent-sdlc:status verbose`): additionally show the last 20 transitions — `tail -20 docs/state/log.jsonl` via Bash, formatted one per line as `{at} {item} {from}→{to} ({trigger})`. This is the only routine reader of log.jsonl.
