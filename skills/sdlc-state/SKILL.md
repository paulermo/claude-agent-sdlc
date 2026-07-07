---
name: sdlc-state
description: "The state law of the SDLC pipeline: single-writer protocol, status machines, transition table, JSON entry schemas, history and commit conventions. Read by the PM orchestrator; every agent skill cites its own slice of it."
---

# SDLC State Law

Authoritative definition of pipeline state. If any other file contradicts this one, this one wins — fix the other file.

## 1. Single-writer protocol

**Only the PM session writes `docs/state/*.json`, and only from the main working copy.**

WHY: agents work in git worktrees on their own branches. A state write inside a worktree lives on that branch — the PM's copy never sees it until merge, and merge conflict rules discard the branch side. Transitions written by agents silently vanish. One writer, one working copy, no forks.

Consequences (each agent's skill repeats its own slice):

| Actor | May write state? | Instead does |
|-------|------------------|--------------|
| PM (lead session) | YES — all `docs/state/*.json` | applies transitions + history, commits |
| Every dispatched agent | **NEVER** | ends with a structured report; PM applies the transition |

- PM sets the *working* statuses at dispatch time: `in_progress`, `creating`, `in_review`, `in_qa`, `integrating` — never the agent.
- PM sets the *outcome* statuses after parsing the agent's report: `ready_for_review`, `review_rejected`, `ready_for_qa`, `qa_rejected`, `ready_for_integration`, `ready_for_merge`, `merged`, `regression_failed`, `done`.
- Feedback fields (`review_feedback`, `qa_feedback`, `regression_feedback`, `rejection_reason`) are copied by PM from the agent's report verbatim.
- An agent's in-flight progress lives in its story/task `.md` file inside its worktree (checkboxes) — one file, one owner, merges cleanly.

## 2. Agent report envelope

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

## 3. Status machines

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
| `done` | all epics `done` |

(The `phase` labels in the agent registry — planning/infrastructure/implementation/content/on_demand — are grouping labels for humans, NOT this enum.)

## 4. Transition table (PM applies ALL of these)

| From | Event (agent report) | To | Also store |
|------|----------------------|----|------------|
| todo / review_rejected / qa_rejected | PM dispatches Developer | in_progress | assignee |
| in_progress | Developer OUTCOME: IMPLEMENTED | ready_for_review | — |
| ready_for_review | PM dispatches Reviewer | in_review | — |
| in_review | Reviewer OUTCOME: APPROVED | ready_for_qa | — |
| in_review | Reviewer OUTCOME: REJECTED | review_rejected | review_feedback |
| ready_for_qa | PM dispatches QA | in_qa | — |
| in_qa | QA OUTCOME: PASSED | ready_for_merge | — |
| in_qa | QA OUTCOME: FAILED | qa_rejected | qa_feedback (+rejection_reason for content) |
| ready_for_merge | Deploy OUTCOME: MERGED | merged | — |
| merged | QA(regression) OUTCOME: PASSED | done | — |
| merged | QA(regression) OUTCOME: FAILED | regression_failed | regression_feedback; PM creates bug-story |
| all stories done | PM check | epic → ready_for_deploy | — |
| ready_for_deploy | Deploy OUTCOME: MERGED (to main) | epic → deployed | — |
| deployed | QA(regression on main) OUTCOME: PASSED | epic → done | — |

Content tasks follow the same pattern with their extra statuses (`creating`, `ready_for_integration`, `integrating`; Content Reviewer/Integrator instead of Reviewer).

## 5. Entry schemas (verbatim — create entries EXACTLY like this)

`docs/state/stories.json` — map of story ID → entry:

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
  "regression_feedback": null,
  "history": []
}
```

`docs/state/content-tasks.json` — same shape plus:

```json
  "epic": "{PREFIX}-CEPIC-{M}",
  "branch": "content/{PREFIX}-CTASK-{N}-{slug}",
  "rejection_reason": null
```

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
      "branch": "feature/{PREFIX}-EPIC-{N}-{slug}",
      "history": []
    }
  }
}
```

(`type` is `"epic"` or `"cepic"`; cepic branches use `content/{PREFIX}-CEPIC-{N}-{slug}` and `brd` is the content plan ID.)

`docs/state/project.json` `worktrees` map — one entry per active worktree:

```json
"{ITEM-ID}": {
  "path": "{worktree_dir}/{ITEM-ID}",
  "branch": "{branch}",
  "ports": { "app": {port}, "db": {port} }
}
```

Ports: allocate `app` starting at 3100, `db` at 5433, incrementing per active worktree — collisions break parallel Docker stacks.

## 6. History and commits

Every transition appends to the entry's `history` (PM does this in the same edit):

```json
{"from": "{old}", "to": "{new}", "by": "pm", "at": "{ISO-8601 UTC}", "trigger": "{agent role or directive filename}"}
```

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
- Writing history entries with relative or local times — ISO-8601 UTC only.
