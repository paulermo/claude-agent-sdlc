---
name: sdlc-state
description: "The state law of the SDLC pipeline: single-writer protocol, file layout and bucket law, item kinds (story/bug), tiers and return budgets, status machines, transition table, JSON entry schemas, transition log and commit conventions. Read by the PM orchestrator; every agent skill cites its own slice of it."
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
- PM-only tracking documents outside `docs/state/`: saved reviews (`docs/reviews/`), QA/regression reports (`docs/reports/`), the epic follow-ups file (`docs/issues/{EPIC-ID}-{slug}/followups.md`) and bug records (`docs/issues/{EPIC-ID}-{slug}/bugs/`). The PM writes them on the main working copy only; branches never touch them (so merges never conflict on them); agents read them by their main-copy path — the session cwd — and never edit them.

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

A story's own `done` does NOT archive it — done stories stay in active.json until the epic completes, so "every epic item done → ready_for_deploy" remains a presence check, never an absence check. New items register directly into the bucket the law dictates (a bug of an in-flight epic → active.json; planning output → backlog.json; a directive bug against a not-started epic → backlog.json).

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

- `review_rejected`, `qa_rejected` → `returns` + 1 (Return budget below); within budget → re-dispatch a fresh Developer (with feedback) → `in_progress`; at budget → parked.
- `regression_failed` is terminal for the story; PM registers a bug (Bug below) referencing it.
- `light`-tier stories skip QA: `ready_for_qa` → `ready_for_merge` by a PM decision line (Kinds, tiers, budgets below).

### Kinds, tiers, budgets

Every entry in the `stories` map has a `kind` (`story` | `bug`) and a `tier` (`light` | `standard` | `critical`). **Absent fields read as `story` / `standard` / `returns: 0`** — entries created before v1.6 need no migration. The tier is assigned by the System Analyst (story-breakdown signal table), may be changed by the Architect in Design Mode (reported in DETAILS — the PM updates state), and is inherited by bugs from their origin item. **The tier decides — one table, every skill cites it:**

| | `light` | `standard` | `critical` |
|---|---|---|---|
| Reviewer lenses | story + rules (the gate is still run) | all three | all three + adversarial pass |
| IMPORTANT finding, round 1 | follow-up | follow-up (promotable once, with a stated downstream cost) | blocks |
| IMPORTANT finding, round ≥ 2 | follow-up | follow-up | follow-up |
| QA standard mode (stories) | NOT dispatched — `ready_for_qa` → `ready_for_merge` by decision line | E2E per AC | E2E per AC + every exception flow + negative tests |
| Return budget (stories, content tasks) | 1 | 2 | 3 |
| Bug path | Developer → merge → regression | Developer → delta review → merge → regression | Developer → review → QA → merge → regression |
| Return budget (bugs) | 1 | 1 | 1 |

*Default, not law — for the QA-skip and review-skip cells only: the PM may dispatch the skipped stage on concrete grounds and record the rationale as a decision line (section 7). The budgets and the IMPORTANT rows are LAW: the only outlet past a budget is the parking gate below.*

### Bug

A bug is a defect item: it restores behavior or closes findings; it never delivers an acceptance criterion from a use case (that is a story). ID `{PREFIX}-BUG-{N}` (counter `bug`), branch `bug/{PREFIX}-BUG-{N}-{slug}`, record `docs/issues/{EPIC-ID}-{slug}/bugs/{BUG-ID}-{slug}.md` (from `docs/templates/bug-template.md`, written by the PM from the originating report or directive). No story file, use case, or spec artifacts — the record is the specification; acceptance = a regression test that reproduces the symptom and passes after the fix, plus a green quality gate.

```
todo → in_progress → [ready_for_review → in_review →] [ready_for_qa → in_qa →] ready_for_merge → merged → done
       light: neither bracket · standard: review only · critical: both
```

Who may originate a bug (the PM registers it — single-writer):

| Origin | Trigger |
|--------|---------|
| QA regression | OUTCOME: FAILED after a merge |
| Deploy | OUTCOME: MERGE_FAILED / VERIFICATION_FAILED |
| Reviewer, QA, Developer reports | an out-of-scope defect larger than a follow-up (more than ~5 lines, or more than one file) |
| User | a directive file `docs/directives/active/bug-{slug}.md` (format in start.md Step 2) |
| PM, epic end | open follow-ups when every other item of the epic is done → ONE hygiene bug |

A defect of ≤ 5 lines in one file is never a bug — it is a follow-up. Nobody proposes *stories* for defects: stories come from use cases (System Analyst); defects become bugs or follow-ups. WHY: CBS epic 1 registered 23 `fix:` stories in one day, each paying for a story document, a dispatch, a review and a QA pass — most were one-line changes.

### Follow-ups

`docs/issues/{EPIC-ID}-{slug}/followups.md` — one file per epic, PM-only, written on main. One line per **class** of finding (the same rule or the same pattern), never per instance:

```markdown
# Follow-ups — {EPIC-ID}
- [ ] FU-1 · {class, one clause} · instances: {file:line, file:line} · origin: {report path} · size: small | larger
```

Fed from the Reviewer's `## Follow-ups` section, QA's `## Out-of-scope defects`, and the Developer's `OUT OF SCOPE` lines. Closed by Developers in passing (their briefs point at the file: close entries whose instances lie in files they modify anyway; they report `FOLLOW-UPS CLOSED:` and the PM ticks the lines) or by the epic-end hygiene bug. Cheap open-entry check — never Read the file for this:

```bash
grep -c '^- \[ \]' docs/issues/{EPIC-ID}-{slug}/followups.md 2>/dev/null || echo 0
```

### Return budget and parking (LAW)

`returns` counts an item's rework dispatches. On every REJECTED / FAILED report from a Reviewer, Content Reviewer, or QA (standard mode):

| `returns` before the report | PM does |
|-----------------------------|---------|
| `< budget(tier)` | save the feedback file, set `review_rejected` / `qa_rejected`, `returns` + 1, re-dispatch a fresh Developer (or content agent) when capacity allows |
| `== budget(tier)` | set the rejected status, do NOT increment, do NOT re-dispatch — the item is **parked**: decision line `"note": "budget exhausted ({returns}/{budget}): parked"`; interactive sessions run the budget gate (start.md), `--no-human` parks silently and narrates |

Parked = a rejected status with `returns >= budget(tier)`. A parked item is not dispatchable — the dispatch map skips it. It leaves parking only through the budget gate ("one more round" — one extra Developer + verdict cycle, after which this rule runs again; "accept" — the open findings move to followups.md and the item advances to the status the verdict would have granted) or a directive (rollback). WHY: unbounded rounds were the single largest cost in CBS epic 1 — 27 of 50 dispatches were returns, and a README took seven.

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
- `ready_for_deploy`: every item of the epic (stories AND bugs) `done`, and no open follow-ups (section 4 — Follow-ups).
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
| todo / review_rejected / qa_rejected (not parked) | PM dispatches Developer | in_progress | assignee |
| in_progress | Developer OUTCOME: IMPLEMENTED — story, or bug of tier standard/critical | ready_for_review | tick `FOLLOW-UPS CLOSED` lines in followups.md; route `OUT OF SCOPE` lines (follow-up or bug, section 4) |
| in_progress | Developer OUTCOME: IMPLEMENTED — bug of tier light | ready_for_merge | decision line `"review skipped: light bug"` |
| ready_for_review | PM dispatches Reviewer | in_review | brief carries ROUND = returns + 1 |
| in_review | Reviewer OUTCOME: APPROVED — story, or bug of tier critical | ready_for_qa | append the review's `## Follow-ups` to followups.md |
| in_review | Reviewer OUTCOME: APPROVED — bug of tier standard | ready_for_merge | same |
| in_review | Reviewer OUTCOME: REJECTED | review_rejected (or parked) | review_feedback (path, section 6); returns rule (section 4); follow-ups appended |
| ready_for_qa | story of tier light — no QA dispatch | ready_for_merge | decision line `"QA skipped: light tier"` |
| ready_for_qa | PM dispatches QA | in_qa | — |
| in_qa | QA OUTCOME: PASSED | ready_for_merge | route `## Out-of-scope defects` (follow-up or bug) |
| in_qa | QA OUTCOME: FAILED | qa_rejected (or parked) | qa_feedback (path) + rejection_reason for content; returns rule |
| ready_for_merge | Deploy OUTCOME: MERGED | merged | — |
| ready_for_merge | Deploy OUTCOME: MERGE_FAILED / VERIFICATION_FAILED | ready_for_merge (unchanged) | register a bug from the report (tier = the item's tier) |
| merged | QA(regression) OUTCOME: PASSED | done | — |
| merged | QA(regression) OUTCOME: FAILED | regression_failed | regression_feedback (path); register a bug (active.json, tier = the item's tier) |
| every epic item done, open follow-ups > 0 | PM check | (epic unchanged) | register ONE hygiene bug from followups.md, then continue |
| every epic item (stories AND bugs) done, no open follow-ups | PM check | epic → ready_for_deploy | — |
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
  "kind": "story",
  "tier": "standard",
  "returns": 0,
  "status": "todo",
  "branch": "story/{PREFIX}-STORY-{N}-{slug}",
  "worktree": null,
  "assignee": null,
  "review_feedback": null,
  "qa_feedback": null,
  "regression_feedback": null
}
```

There is NO `history` field — transitions go to `log.jsonl` (section 7). `kind` / `tier` / `returns` are defined in section 4 (Kinds, tiers, budgets); absent = `story` / `standard` / `0`.

Bug entry (same map `"stories"`, so every reader of the map sees it):

```json
"{PREFIX}-BUG-{N}": {
  "epic": "{PREFIX}-EPIC-{M}",
  "title": "{symptom, one clause}",
  "kind": "bug",
  "tier": "{inherited from the origin item, or the tier table}",
  "returns": 0,
  "origin": "{docs/reports/... | docs/reviews/... | directive filename | followups}",
  "record": "docs/issues/{PREFIX}-EPIC-{M}-{slug}/bugs/{PREFIX}-BUG-{N}-{slug}.md",
  "status": "todo",
  "branch": "bug/{PREFIX}-BUG-{N}-{slug}",
  "worktree": null,
  "assignee": null,
  "review_feedback": null,
  "qa_feedback": null,
  "regression_feedback": null
}
```

Counter: `project.json.counters.bug`. If an older `project.json` lacks it, add `"bug": 0` when registering the first bug (init also merges it on migration runs).

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

- Registering a new item or epic logs `"from": null` (trigger = the registering agent's role). Registering a bug logs `"trigger": "{QA | Deploy | Reviewer | Developer | directive: {filename} | hygiene}"` plus `"origin": "{report path or directive filename}"`.
- Tier/kind mechanics leave decision lines with fixed notes: `"QA skipped: light tier"`, `"review skipped: light bug"`, `"budget exhausted ({returns}/{budget}): parked"`, `"budget gate: one more round"`, `"budget gate: accepted — findings to follow-ups"`.
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
- Registering a *story* for a defect — defects are bugs or follow-ups (section 4); stories come only from the System Analyst's breakdown.
- Registering one item per instance of the same finding class — one class, one record (bug or follow-up line) with the instances listed.
- Dispatching a parked item, or incrementing `returns` past the budget — the budget gate and directives are the only exits.
