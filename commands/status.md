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

2. **Read all state files:**
   - `docs/state/epics.json`
   - `docs/state/stories.json`
   - `docs/state/content-tasks.json`

3. **Determine project phase:**
   - `not_started` — no BRDs exist
   - `planning` — BRDs exist but epics are in `planning` status
   - `implementation` — at least one epic is `ready` or `in_progress`
   - `done` — all epics are `done`

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

   Only show items in non-done statuses under "Active work" and "Content".
