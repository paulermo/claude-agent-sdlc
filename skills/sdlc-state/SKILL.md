---
name: sdlc-state
description: "The state law of the SDLC pipeline: single-writer protocol, file layout and bucket law, status machines, transition table, JSON entry schemas, transition log and commit conventions. Read by the PM orchestrator; every agent skill cites its own slice of it."
---

# SDLC State Law

Authoritative definition of pipeline state. If any other file contradicts this one, this one wins — fix the other file.

## 1. Single-writer protocol

**Only the PM session writes `docs/state/` — every file in it, `log.jsonl` included — and only from the main working copy.**

WHY: agents work in git worktrees on their own branches. A state write inside a worktree lives on that branch — the PM's copy never sees it until merge, and merge conflict rules discard the branch side. Transitions written by agents silently vanish. One writer, one working copy, no forks.

Consequences (each agent's skill repeats its own slice):

| Actor | May write state? | Instead does |
|-------|------------------|--------------|
| PM (lead session) | YES — everything under `docs/state/` | applies transitions + log lines, commits |
| Every dispatched agent | **NEVER** | ends with a structured report; PM applies the transition |

- PM sets the *working* statuses at dispatch time: `in_progress`, `creating`, `in_review`, `in_qa`, `integrating` — never the agent.
- PM sets the *outcome* statuses after parsing the agent's report: `ready_for_review`, `review_rejected`, `ready_for_qa`, `qa_rejected`, `ready_for_integration`, `ready_for_merge`, `merged`, `regression_failed`, `done`.
- Feedback fields (`review_feedback`, `qa_feedback`, `regression_feedback`, `rejection_reason`) are copied by PM from the agent's report verbatim.
- An agent's in-flight progress lives in its story/task `.md` file inside its worktree (checkboxes) — one file, one owner, merges cleanly.

## 2. File layout and bucket law

```
docs/state/
  project.json               config, worktrees, counters ("state_version": 2)
  epics.json                 index: priority_order + all non-archived epic entries
  active.json                {"stories":{}, "content_tasks":{}} — items of epics in flight
  backlog.json               same shape — items of epics not yet started
  log.jsonl                  append-only transition log (one JSON object per line)
  archive/done-YYYY-MM.json  {"epics":{}, "stories":{}, "content_tasks":{}}
  environments.json, .secrets.json   (managed by /agent-sdlc:env)
```

**The epic's status decides where its items live** — no other signal:

| Epic status | Its stories / content tasks live in |
|-------------|-------------------------------------|
| `planning` / `ready` / `frozen` | `backlog.json` |
| `in_progress` / `ready_for_deploy` / `deployed` | `active.json` |
| `done` | `archive/done-{YYYY-MM}.json` (epic entry moves there too, out of `priority_order`) |

Bulk moves happen at exactly TWO epic transitions, always whole-epic, never per item:

| Epic transition | Move (same response as the transition) |
|-----------------|----------------------------------------|
| `ready` → `in_progress` (you dispatch its first item) | ALL its items: backlog.json → active.json |
| `deployed` → `done` (main regression passed) | ALL its items + the epic entry → `archive/done-{YYYY-MM of today, UTC}.json`; remove the epic from `priority_order` |

A story's own `done` does NOT archive it — done stories stay in active.json until the epic completes, so "all stories done → ready_for_deploy" remains a presence check, never an absence check. New items register directly into the bucket the law dictates (bug-story of an in-flight epic → active.json; planning output → backlog.json).

**Move discipline (LAW):** write the destination file first, verify it parses, then delete from the source — both edits in the same response, in that order. A crash between the two leaves a duplicate, never a loss. If an ID ever appears in two files, the bucket-law file is correct — delete the other copy.

**Consistency repair:** an item sitting in `backlog.json` with any status other than `todo` means its epic missed the `ready` → `in_progress` transition (pre-v2 histories never set it, and crashes can skip it). Apply that transition immediately — epic → `in_progress`, ALL its items → `active.json`, log line — before any dispatch. Detect it cheaply without reading the file: `jq '[.stories, .content_tasks | to_entries[]? | select(.value.status != "todo")] | length' docs/state/backlog.json` — repair only if the count is non-zero.

**Read discipline:** a normal PM session reads `project.json` + `epics.json` + `active.json` and NOTHING else. Open `backlog.json` only to register planning output or to start the next epic. NEVER read `archive/` or `log.jsonl` during orchestration — they exist for /agent-sdlc:status (verbose) and crash forensics.

## 3. Agent report envelope

Every agent's final message MUST contain this block (agent skills define the role-specific `OUTCOME` values):

```
=== AGENT REPORT ===
AGENT: {Role}
ITEM: {ID or "-"}
OUTCOME: {role-specific verdict, one line}
EVIDENCE:
- {check or command}: {actual result — counts, exit status, not adjectives}
FILES:
- {path} ({created|modified})   [or "- none"]
BLOCKERS: {none | list, each with what is needed to unblock}
DETAILS: {anything PM must store as feedback, verbatim}
=== END REPORT ===
```

PM MUST NOT apply a transition from a report whose EVIDENCE section is empty or contains claims without results ("tests pass" with no counts) — re-dispatch the agent with instruction to provide evidence.

## 4. Status machines

### Story

```
todo → in_progress → ready_for_review → in_review → ready_for_qa → in_qa → ready_for_merge → merged → done
         ↑                                  │                         │                          │
         └── review_rejected ←──────────────┘                         │                          │
         └── qa_rejected ←────────────────────────────────────────────┘                          │
                                                        regression_failed ←──────────────────────┘
```

- `review_rejected`, `qa_rejected` → re-dispatch Developer (with feedback) → `in_progress`.
- `regression_failed` is terminal for the story; PM creates a bug-story (`todo`) referencing it.

### Content task

```
todo → creating → ready_for_review → in_review → ready_for_integration → integrating
     → ready_for_qa → in_qa → ready_for_merge → merged → done
```

Rejections: `review_rejected` → Content Creator; `qa_rejected` with `rejection_reason: "content"` → Content Creator, `"integration"` → Content Integrator. `regression_failed` as for stories.

### Epic (and content epic)

```
planning → ready → in_progress → ready_for_deploy → deployed → done
                       (frozen — via directive, from any status; unfreeze restores prior status)
```

- `ready`: planning artifacts complete (BRD, stories, architecture).
- `ready_for_deploy`: every story `done`.
- `deployed`: feature branch merged to main, awaiting main regression.
- `done`: main regression passed.

### Project phase (cached in `project.json.phase`, computed)

| Phase | Condition |
|-------|-----------|
| `not_started` | no BRDs exist |
| `planning` | BRDs exist, some epic still `planning` |
| `implementation` | at least one epic `ready`/`in_progress`/`ready_for_deploy`/`deployed` |
| `done` | `epics.json` `.epics` is empty (every epic archived) and BRDs exist |

(The `phase` labels in the agent registry — planning/infrastructure/implementation/content/on_demand — are grouping labels for humans, NOT this enum.)

## 5. Transition table (PM applies ALL of these)

| From | Event (agent report) | To | Also store / do |
|------|----------------------|----|------------------|
| epic `ready` | PM dispatches its first item | epic → in_progress | move ALL its items backlog → active (bucket law) |
| todo / review_rejected / qa_rejected | PM dispatches Developer | in_progress | assignee |
| in_progress | Developer OUTCOME: IMPLEMENTED | ready_for_review | — |
| ready_for_review | PM dispatches Reviewer | in_review | — |
| in_review | Reviewer OUTCOME: APPROVED | ready_for_qa | — |
| in_review | Reviewer OUTCOME: REJECTED | review_rejected | review_feedback (path, section 6) |
| ready_for_qa | PM dispatches QA | in_qa | — |
| in_qa | QA OUTCOME: PASSED | ready_for_merge | — |
| in_qa | QA OUTCOME: FAILED | qa_rejected | qa_feedback (path) + rejection_reason for content |
| ready_for_merge | Deploy OUTCOME: MERGED | merged | — |
| merged | QA(regression) OUTCOME: PASSED | done | — |
| merged | QA(regression) OUTCOME: FAILED | regression_failed | regression_feedback (path); PM creates bug-story (active.json) |
| all stories done | PM check | epic → ready_for_deploy | — |
| ready_for_deploy | Deploy OUTCOME: MERGED (to main) | epic → deployed | — |
| deployed | QA(regression on main) OUTCOME: PASSED | epic → done | archive sweep + drop from priority_order (bucket law) |

Content tasks follow the same pattern with their extra statuses (`creating`, `ready_for_integration`, `integrating`; Content Reviewer/Integrator instead of Reviewer).

## 6. Entry schemas (verbatim — create entries EXACTLY like this)

`active.json` and `backlog.json` share one shape — two maps keyed by item ID:

```json
{ "stories": {}, "content_tasks": {} }
```

Story entry (inside `"stories"`):

```json
"{PREFIX}-STORY-{N}": {
  "epic": "{PREFIX}-EPIC-{M}",
  "title": "{title}",
  "status": "todo",
  "branch": "story/{PREFIX}-STORY-{N}-{slug}",
  "worktree": null,
  "assignee": null,
  "review_feedback": null,
  "qa_feedback": null,
  "regression_feedback": null
}
```

There is NO `history` field — transitions go to `log.jsonl` (section 7).

**Feedback fields hold a file path, never verbatim text:**

| Field | You write the agent's DETAILS to | Then store |
|-------|----------------------------------|------------|
| `review_feedback` | `docs/reviews/{STORY-ID}-{n}.md` (you save the Reviewer's document there anyway) | that path |
| `qa_feedback` | `docs/reports/{ITEM-ID}-qa-{n}.md` | that path |
| `regression_feedback` | `docs/reports/{ITEM-ID}-regression-{n}.md` | that path |

`{n}` starts at 1 and increments per round; the field always holds the LATEST path. Rework briefs pass the path and the agent reads the file — never paste feedback text into state or briefs.

Content-task entry (inside `"content_tasks"`) — same shape plus:

```json
  "epic": "{PREFIX}-CEPIC-{M}",
  "branch": "content/{PREFIX}-CTASK-{N}-{slug}",
  "rejection_reason": null
```

(`rejection_reason` stays inline — it is the `content|integration` dispatch switch, an enum, not feedback text.)

`docs/state/epics.json`:

```json
{
  "priority_order": ["{PREFIX}-EPIC-1", "{PREFIX}-CEPIC-1"],
  "epics": {
    "{PREFIX}-EPIC-{N}": {
      "title": "{title}",
      "status": "planning",
      "type": "epic",
      "brd": "{PREFIX}-BRD-{M}",
      "branch": "feature/{PREFIX}-EPIC-{N}-{slug}"
    }
  }
}
```

(no `history`; `type` is `"epic"` or `"cepic"`; cepic branches use `content/{PREFIX}-CEPIC-{N}-{slug}` and `brd` is the content plan ID.)

`archive/done-{YYYY-MM}.json` — three maps; entries arrive unchanged from their source files:

```json
{ "epics": {}, "stories": {}, "content_tasks": {} }
```

`docs/state/project.json` `worktrees` map — one entry per active worktree:

```json
"{ITEM-ID}": {
  "path": "{worktree_dir}/{ITEM-ID}",
  "branch": "{branch}",
  "ports": { "app": {port}, "db": {port} }
}
```

Ports: allocate `app` starting at 3100, `db` at 5433, incrementing per active worktree — collisions break parallel Docker stacks.

## 7. Transition log and commits

Every transition appends ONE line to `docs/state/log.jsonl` — via Bash append, so the file never enters context:

```bash
echo '{"item":"{ITEM-ID}","from":"{old}","to":"{new}","by":"pm","at":"{ISO-8601 UTC}","trigger":"{agent role or directive filename}"}' >> docs/state/log.jsonl
```

- Registering a new item or epic logs `"from": null` (trigger = the registering agent's role).
- A recorded deviation from a default (e.g. skipping Designer or the infra phase for an epic) is a **decision line**: `from` and `to` both equal the current status, `"trigger": "decision"`, plus `"note": "{rationale}"`. Extra keys are allowed on any line.
- **Planning-chain visibility:** planning work changes no statuses, so it is invisible without these two lines. Before dispatching any planning-chain agent (Product Manager, System Analyst, Architect, Designer, Cloud Architect, DevOps Engineer) log a **dispatch line** — `from` == `to` == the epic's current status, `"trigger": "dispatch: {Role}"`, `"note": "{mode/scope, one clause}"`. After verifying its report, log a **completion line** — same shape, `"trigger": "{Role}"`, `"note": "{OUTCOME + one clause}"` — unless the verified report immediately changes a status (then the normal transition line IS the completion record). /status and the tracker read these as the live "who is working now" signal.
- Bucket moves and archive sweeps are NOT logged — they are consequences of the epic transition, which is.
- Append only: never Read or Edit log.jsonl. Its readers are /agent-sdlc:status (verbose) and crash forensics, not orchestration.

Commit conventions (exact formats):

| Actor | Format |
|-------|--------|
| PM state updates | `{PREFIX}: Update state — {ITEM-ID} {old}→{new} [by PM]` |
| Agent work commits (in worktree) | `{ITEM-ID}: {description} [by {Role}]` |
| Planning/infra commits | `{PREFIX}: {description} [by {Role}]` |

## MUST NOT DO

- An agent editing `docs/state/*.json` — under any circumstances, including "just fixing" a stale status it noticed (report it instead).
- PM applying a transition without a matching agent report with evidence.
- Inventing entry fields or statuses not defined here — extend this file first (see docs/extending-sdlc.md).
- Writing log lines with relative or local times — ISO-8601 UTC only.
- Deleting an entry from its source file before the destination file is written and parses — move discipline is destination-first, and the tempting "delete first so I don't forget" order turns a crash into data loss.
- Pasting feedback text into state fields or briefs — feedback fields hold paths (section 6); the text lives once, in its file.
- Reading `archive/`, `log.jsonl`, or (outside registration / epic start) `backlog.json` during orchestration — the read discipline exists precisely so state size never taxes the session again.
