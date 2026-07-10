# State Sharding — active/backlog/archive + transition log (state v2)

**Status:** approved 2026-07-10 (user-selected: bucket split, log.jsonl, feedback pointers)
**Problem:** `docs/state/stories.json` / `epics.json` grow without bound (inline `history` per entry, verbatim feedback texts, done items never leave), so the PM burns context reading them every session and falls back to jq slicing.

## What grows, and where it goes

| Growth driver | v1 (monolith) | v2 |
|---------------|---------------|----|
| `history` array per entry | inside every entry, forever | append-only `docs/state/log.jsonl`, one line per transition, written via Bash `>>` (never enters context) |
| Verbatim `review_feedback` / `qa_feedback` / `regression_feedback` | copied into state AND pasted into rework briefs | state holds a **file path** (`docs/reviews/{ID}-{n}.md`, `docs/reports/{ID}-qa-{n}.md`, `docs/reports/{ID}-regression-{n}.md`); briefs pass the path |
| Done epics + far-future stories | same file as current work | `archive/done-YYYY-MM.json` bundles / `backlog.json` |

## File layout

```
docs/state/
  project.json               config, worktrees, counters (+ "state_version": 2)
  epics.json                 index: priority_order + non-archived epic entries (no history)
  active.json                {"stories":{}, "content_tasks":{}} — items of epics in flight
  backlog.json               same shape — items of epics not yet started
  log.jsonl                  append-only transition log
  archive/done-YYYY-MM.json  {"epics":{}, "stories":{}, "content_tasks":{}}
```

## Bucket law (mechanical — the epic's status decides)

| Epic status | Items live in |
|---|---|
| `planning` / `ready` / `frozen` | backlog.json |
| `in_progress` / `ready_for_deploy` / `deployed` | active.json |
| `done` | archive/done-{YYYY-MM}.json (epic entry too, out of priority_order) |

Moves happen at exactly two epic transitions, always whole-epic, never per item:
`ready → in_progress` (backlog → active) and `deployed → done` (active → archive sweep).
Deliberate deviation from the first sketch: stories are NOT archived at their own `done` —
the `ready_for_deploy` check stays a presence check ("every epic item in active is done"),
not an absence check, which weak executors get wrong.

**Move discipline (LAW):** destination write first, validate, then delete from source, both
in one response. Crash between = duplicate, never loss; duplicate resolution: the bucket-law
file wins, delete the other copy.

**Read discipline:** a PM session reads project.json + epics.json + active.json. backlog.json
only for planning registration / starting the next epic. archive/ and log.jsonl are never read
during orchestration (/status verbose and crash forensics only).

## Entry slimming

Story entry keeps: epic, title, status, branch, worktree, assignee, three feedback **paths**.
`history` removed. `rejection_reason` stays inline (dispatch switch enum, not text).
log.jsonl line: `{"item","from","to","by":"pm","at":"ISO-8601 UTC","trigger"}`; registrations
log `"from": null`. Bucket moves are not logged (consequences of the logged epic transition).

## Migration (in /agent-sdlc:init, idempotent, marker: project.json.state_version == 2)

1. Create v2 files; 2. merge all history arrays → log.jsonl sorted by `.at`; 3. non-null verbatim
feedback → `docs/reports/{ID}-migrated-{field}.md`, field := path; 4. bucket items by epic status,
done epics → archive/done-{current month}; 5. delete stories.json/content-tasks.json, strip
history from epics.json, set state_version; 6. one commit.

## Touch list

sdlc-state/SKILL.md (layout+bucket law section, schemas, log), start.md (Step 1 reads, legacy
guard, epic-start move, archive sweep, log lines), status.md (new reads + backlog/archive counts,
verbose = log tail), init.md (bootstrap + migration), session-start.sh (bucket summaries + legacy
fallback), briefs.md ({feedback-file} semantics, file renames), README. Version v1.4.0.
