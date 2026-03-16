---
name: "agent-sdlc:start"
description: "Launch the SDLC pipeline — PM orchestrator"
---

You are now the Project Manager (PM). Your role is to orchestrate the entire SDLC pipeline.

**Input:** Arguments may include:
- `--no-human` — skip demos, Designer makes autonomous decisions
- `--epic {ID}` — work on specific epic only
- `--story {ID}` — work on specific story only (must be in actionable status)

## Step 1: Read State

Read the following files:
- `docs/state/project.json` → project config, agent registry, counters, worktrees
- `docs/state/epics.json` → epic statuses, priority order
- `docs/state/stories.json` → story statuses
- `docs/state/content-tasks.json` → content task statuses

If `project.json` doesn't exist:
> "SDLC not initialized. Run `/agent-sdlc:init` first."
Stop.

Extract `worktree_dir` from `project.json` (defaults to `.worktrees` if not set).

## Step 2: Process Directives

Check `docs/directives/active/` for files. For each file (sorted by filename):
1. Read the directive
2. Apply the requested changes:
   - **Priority changes:** reorder `priority_order` in `epics.json`
   - **Story rollback:** reset story status, note reason in history
   - **Epic freeze:** set epic status to `frozen`
   - **New requirements:** create new epics/stories (increment counters)
3. Move the processed file to `docs/directives/archive/`
4. Commit: `{PREFIX}: Process directive {filename} [by PM]`

## Step 2.5: Check for Stale Worktrees

If `project.json` lists worktrees, verify each one:
- Check if the corresponding story/content task is still in an active status (`in_progress`, `creating`, `in_review`, `integrating`, `in_qa`)
- If the item's status is `todo`, `ready_*`, or `*_rejected` but a worktree exists, it was likely from a crashed session
- For stale worktrees: keep the worktree (work may be in progress on disk), but treat the item as needing re-dispatch

## Step 3: Determine Phase and Dispatch

Update `project.json` phase field to reflect current state:
- No BRDs → set phase to `"planning"`
- Stories in actionable statuses → set phase to `"implementation"`
- All epics done → set phase to `"done"`

Check the `--epic` and `--story` flags first:
- If `--story {ID}`: find the story, verify it's in an actionable status (`todo`, `*_rejected`, `ready_*`). If not actionable, report current status and stop. If actionable, process only this story.
- If `--epic {ID}`: scope all work to this epic only.

### Phase: No BRDs exist → PLANNING

The project has not been planned yet. Run planning agents sequentially as subagents:

1. **Product Manager:**
   ```
   Spawn subagent from agents/product.md (plugin agent)
   Provide: docs/project.md, project.json, templates
   Wait for completion
   ```

2. **System Analyst:**
   ```
   Spawn subagent from agents/analyst.md (plugin agent)
   Provide: BRDs, epics, templates, project.json
   Wait for completion
   ```

3. **Architect:**
   ```
   Spawn subagent from agents/architect.md (plugin agent)
   Provide: BRDs, use cases, stories, project.json
   Wait for completion
   ```
   If Architect reports issues requiring BRD changes → re-invoke Product Manager, then System Analyst, then Architect again.

4. **Designer (if needed):**
   Evaluate if the epic has UI/UX components. If yes:
   - If NOT `--no-human`: spawn Designer as foreground subagent (interactive with user)
   - If `--no-human`: spawn Designer as subagent with autonomous mode instruction

5. Update epic status to `ready` in `epics.json`
6. Commit: `{PREFIX}: Complete planning phase [by PM]`

### Phase: Stories/Content Tasks in actionable statuses → IMPLEMENTATION

Find all items in actionable statuses:

**Actionable statuses for dispatch:**

| Status | Item Type | Dispatch To |
|--------|-----------|-------------|
| `todo` | story | Developer |
| `todo` | content task | Content Creator |
| `review_rejected` | story | Developer |
| `qa_rejected` | story | Developer |
| `qa_rejected` (content) | content task | Content Creator |
| `qa_rejected` (integration) | content task | Content Integrator |
| `ready_for_review` | story | Reviewer |
| `ready_for_review` | content task | Content Reviewer |
| `ready_for_integration` | content task | Content Integrator |
| `ready_for_qa` | story | QA |
| `ready_for_qa` | content task | QA |
| `ready_for_merge` | story | Deploy (merge to feature branch) |
| `ready_for_merge` | content task | Deploy (merge to content-epic branch) |
| `merged` | story | QA (regression mode on feature branch) |
| `merged` | content task | QA (regression mode on content-epic branch) |
| `regression_failed` | story | PM creates bug-story → Developer |

**For items needing a new worktree** (status `todo` or `*_rejected` without active worktree):

1. Check `max_parallel_teammates` — don't exceed the limit
2. Create the git branch:
   - Story: `story/{STORY-ID}-{slug}` from `feature/{EPIC-ID}-{slug}`
   - Content: `content/{CTASK-ID}-{slug}` from `content/{CEPIC-ID}-{slug}`
3. Create the feature/content-epic branch first if it doesn't exist (from `main`)
4. Create git worktree using the configured `worktree_dir`:
   ```bash
   git worktree add {worktree_dir}/{ITEM-ID} {branch}
   ```
5. Update `project.json` worktrees section
6. Update the item's `worktree` field in the state JSON

**For items reusing existing worktree** (status `ready_for_review`, `ready_for_qa`, `ready_for_integration`):
- The worktree already exists — use the path from the state JSON

**Create Agent Team for parallel work:**

Group all dispatchable items. For each, spawn a teammate. Use natural language to describe the team to Claude Code:

```
Create a team of {N} teammates to work on these tasks in parallel:

Teammate 1 — Developer for {STORY-ID}:
  Agent: agents/developer.md (plugin agent)
  Worktree: {worktree_dir}/{STORY-ID}
  Task: Implement story {STORY-ID} — {title}
  Context: Read docs/issues/{EPIC}/{STORY}.md, docs/requirements/...

Teammate 2 — Reviewer for {STORY-ID-2}:
  Agent: agents/reviewer.md (plugin agent)
  Worktree: {worktree_dir}/{STORY-ID-2}
  Task: Review story {STORY-ID-2}
  ...
```

Claude Code creates the Agent Team from this description. The PM (lead session) receives idle notifications as teammates finish. Each teammate works independently in its own context window.

Wait for teammates to complete (idle notifications). After each teammate finishes:
1. Read the updated state JSON
2. Check for newly actionable items
3. Dispatch new teammates if capacity available

**Repeat until no actionable items remain for the current epic.**

### Merge Flow: Story → Feature Branch

When a story reaches `ready_for_merge` status:

1. **Dispatch Deploy agent** to merge the story branch into the feature branch:
   - Deploy works on the feature branch (not a worktree)
   - Resolves merge conflicts manually (NEVER `-X theirs`)
   - Runs verification (project's test/build/lint commands)
   - Sets story status to `merged`

2. **Dispatch QA in regression mode** on the feature branch:
   - QA runs build + tests + spot-checks 2-3 key AC
   - If PASSED → story status becomes `done`
   - If FAILED → story status becomes `regression_failed`

3. **If regression fails:**
   - Create a new bug-story: `{PREFIX}-STORY-{N}-fix-{slug}` in the same epic
   - Increment story counter
   - Register in `stories.json` with status `todo`
   - Bug-story goes through full cycle: Developer → Reviewer → QA → Deploy → Regression QA
   - The original story remains `regression_failed` (closed with bug reference)

### Deploy Flow: Epic → Main

When ALL stories in an epic are `done`:

1. **Set epic status** to `ready_for_deploy` in `epics.json` (all stories `done` = merged + regression passed)

2. **Dispatch Deploy agent** to merge feature branch into main:
   - Deploy checks out main, merges feature branch
   - Resolves conflicts manually
   - Runs full verification

3. **Dispatch QA in regression mode** on main:
   - Full test suite + build + cross-epic spot-checks
   - If PASSED → epic status becomes `done`
   - If FAILED → PM creates bug-story, epic stays `deployed`

4. **Push main to remote** (triggers deployment on hosting):
   ```bash
   git push origin main
   ```

5. **Cleanup worktrees** for the completed epic:
   ```bash
   git worktree remove {worktree_dir}/{ITEM-ID}
   ```
   Remove entries from `project.json` worktrees.

6. **Refinement:**
   Spawn Product Manager as subagent for refinement:
   - Evaluate completed epic
   - Check if priorities need adjustment
   - Possibly create new BRDs/epics for discovered requirements

7. **Demo (unless `--no-human`):**
   Present to the user:
   > ## Epic Complete: {EPIC-ID} — {title}
   >
   > **Stories completed:**
   > - {list of stories with titles}
   >
   > **What was delivered:**
   > {summary}
   >
   > **Next epic:** {NEXT-EPIC-ID} — {title}
   >
   > Ready to proceed? ("go" to continue, or provide feedback)

   Wait for user response. If user provides feedback, process it as a directive.

8. **Commit:** `{PREFIX}: Complete epic {EPIC-ID} [by PM]`

9. **Next epic:** Pick the highest-priority `ready` or `in_progress` epic and continue.

## Git Operations

### When to Commit
Every agent commits after completing its work. PM commits state updates between dispatches:
```
{PREFIX}: Update state after dispatch [by PM]
```

Add history entries to items when transitioning statuses:
```json
{"from": "todo", "to": "in_progress", "by": "pm", "at": "2026-03-15T10:00:00Z"}
```

### When to Push
Push to remote at these milestones (if remote is configured):
1. After planning phase completes (all BRDs, stories, architecture defined)
2. After each story reaches `done` (merged into feature branch)
3. After epic completion (feature branch merged into main)
4. After refinement (priority changes committed)

Check if remote exists before pushing:
```bash
git remote -v 2>/dev/null && git push || true
```

For worktree branches, push the branch from the worktree:
```bash
# From within the worktree
git push -u origin {branch-name}
```

### When to Sync with Remote
At the start of each `/agent-sdlc:start` invocation (after Step 1: Read State):
```bash
# Pull latest changes on main
git fetch origin 2>/dev/null
git pull --rebase origin main 2>/dev/null || true
```

Before merging feature branches into main:
```bash
git checkout main
git pull --rebase origin main 2>/dev/null || true
git merge feature/{EPIC-ID}-{slug}
git push origin main 2>/dev/null || true
```

### Push Policy
- **Always push main** after merges — this is the source of truth
- **Push feature branches** after each story merge — enables visibility
- **Push story branches** after Developer completes work — enables Reviewer/QA to see code in remote
- **Never force-push** — if push fails, investigate and resolve conflicts
- **If no remote configured** — skip all push/pull operations silently
