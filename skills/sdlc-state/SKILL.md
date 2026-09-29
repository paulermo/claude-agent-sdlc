---
name: sdlc-state
description: "The state law of the SDLC pipeline: single-writer protocol, file layout and bucket law, lanes (fast/classic), item kinds (story/bug), tiers and return budgets, status machines (story, bug, epic, milestone), notes and follow-ups, transition table, JSON entry schemas (process block, epic batch, milestones), transition log and commit conventions. Read by the PM orchestrator; every agent skill cites its own slice of it."
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
- PM-only tracking documents outside `docs/state/`: saved reviews (`docs/reviews/{ITEM-ID}-{n}.md`), the epic notes file (`docs/reviews/{EPIC-ID}-notes.md`), QA/regression reports and batch-gate reports (`docs/reports/`, section 6), the epic follow-ups file (`docs/issues/{EPIC-ID}-{slug}/followups.md`) and bug records (`docs/issues/{EPIC-ID}-{slug}/bugs/`). The PM writes them on the main working copy only; branches never touch them (so merges never conflict on them); agents read them by their main-copy path — the session cwd — and never edit them.
- **The main checkout stays on `main`.** Never check out another branch there, never park it, never move the PM's writes to another worktree. WHY: `/agent-sdlc:tracker` and `/agent-sdlc:status` read `docs/state/` from the main checkout's working tree — a board once froze for an hour while the pipeline ran on elsewhere.
- **State is staged and committed by exact path** — `git add -- docs/state {each document this step wrote}` then `git commit -m "{message}" -- docs/state {the same documents}`. Never `git add -A`/`git add .` followed by a bare `git commit`. WHY: a bare commit once swept an agent's 15 staged renames into a PM state commit.
- **Planning artifacts are not PM-only:** BRDs, epics, stories, the demo-slice document (`docs/reports/demo-slice-{K}.md`, K = the milestone's number) and the recut report (`docs/reports/milestone-{K}-recut.md`) are written by planning agents in their own worktrees and reach `main` when the PM merges the planning branch.
- **Agents' report files** (review documents, gate reports, long logs) go to `{reports}/{name}` — `{reports}` is the ABSOLUTE path of `{worktree_dir}/.reports` inside the main checkout, which the PM writes into every brief (git-ignored with the worktree dir; a relative path would resolve inside the agent's own worktree and could be committed). The PM copies review documents and gate reports into `docs/reviews/` or `docs/reports/`. WHY: long documents truncate in the report channel — a 15 KB review was cut three times before it arrived through a file.

## 2. File layout and bucket law

```
docs/state/
  project.json               config, process block, worktrees, counters ("state_version": 2)
  epics.json                 index: priority_order + all non-archived epic entries + milestones + milestone_order
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

Bulk moves happen at exactly TWO epic transitions, always whole-epic, never per item (plus a milestone recut, below):

| Epic transition | Move (same response as the transition) |
|-----------------|----------------------------------------|
| `ready` → `in_progress` (you dispatch its first item) | ALL its items: backlog.json → active.json |
| `deployed` → `done` (main regression passed or skipped by policy) | ALL its items + the epic entry → `archive/done-{YYYY-MM of today, UTC}.json`; remove the epic from `priority_order` |

A story's own `done` does NOT archive it — done stories stay in active.json until the epic completes, so "every epic item done → ready_for_deploy" remains a presence check, never an absence check. New items register directly into the bucket the law dictates (a bug of an in-flight epic → active.json; planning output → backlog.json; a directive bug against a not-started epic → backlog.json). An epic that returns `deployed` → `in_progress` (a cut batch delivered with items left, or a failed main regression — section 5) keeps its items in active.json: both statuses are active, nothing moves. **A milestone recut** re-parents items to a remainder epic registered as `ready`: each re-parented item moves to the file its NEW epic's status dictates (remainder `ready` → `backlog.json`), destination first, in the same response as its `recut` log line (milestones reference). An item registered while its epic's batch end is running (`batch.stage` set) — other than the triage hygiene bug — does not join that batch: the PM cuts the batch first (start.md, bug registration), so the new item waits for the next batch.

**Milestones never move.** They live in `epics.json` (`milestones` + `milestone_order`) for their whole life, `demoed` ones included; the bucket law does not apply to them. An archived epic keeps its `milestone` field in the archive. WHY: a milestone spans epics in different buckets — moving it with any one of them would split its links.

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
REPORT FILE: {the {reports}/… path the brief named — only when it named one}
CONTINUE: {next task = … — only on a planned hand-off, with OUTCOME: BLOCKED}
BLOCKERS: {none | list, each with what is needed to unblock}
DETAILS: {anything PM must store as feedback, verbatim}
=== END REPORT ===
```

- `REPORT FILE` and `CONTINUE` lines appear only when they apply; every other section is mandatory.
- A targeted-set EVIDENCE line names why each path was selected: `- targeted: {command} — selected because {touched | consumer of {symbol} | whole-tree check for {fact} | always-run dir}: {counts}, exit {code}`.
- The whole final message stays under `process.report_max_chars` characters (absent: 3500). Longer material goes into the `REPORT FILE`. WHY: the teammate channel truncates reports near 5,000 characters.
- What counts as evidence, and how to read an exit code, is defined once in `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md` — every agent follows it.

PM MUST NOT apply a transition from a report whose EVIDENCE section is empty or contains claims without results ("tests pass" with no counts) — re-dispatch the agent with instruction to provide evidence.

## 4. Status machines

### Lanes

The lane decides how an item proves itself and how an epic reaches `main`. It is stamped **per epic**:

- `project.json.process.lane` (`fast` | `classic`) is the lane for epics that START from now on.
- When the PM applies epic `ready` → `in_progress`, it writes `"lane": "{process.lane}"` into the epic entry (`"classic"` for a content epic) in the same response. From then on the epic follows its stamp until `done`, whatever `process.lane` says later — switching the project default never changes an epic in flight.
- No stamp on the epic, or no `process` block at all → `classic`. Content epics (`"type": "cepic"`) are always `classic`.
- An item's lane is its epic's: `jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`.

**The lane table — every lane-dependent rule lives here; other files cite it:**

| | `classic` (1.6 behaviour) | `fast` |
|---|---|---|
| Developer / bug proof | the full quality gate | the targeted set (`.claude/rules/quality-gate.md` §Per story) |
| Review rounds | as many as the return budget allows | 1 |
| Return budget | by tier: 1 / 2 / 3 (bugs 1) | 1 at every tier, every kind |
| Rework verification | a re-review round (scope law) | the PM reads the fix pass's diff against the named findings |
| QA per item | by tier (standard mode) | none |
| Regression after an item merge | QA regression on the feature branch | none — a real merge runs whole static analysis on the merged tree; a changed whole-tree scanner is re-run |
| Full gate | after every merge | once per batch, after `main` is merged into the feature (the batch end) |
| Merge failure | a bug | `fix/{ITEM-ID}-merge` + a merge-fix Developer; never a bug |
| Bug path | by tier (Kinds, tiers, budgets) | light: Developer → merge; standard / critical: Developer → one review round → merge |
| Epic → `main` | the Deploy flow in `start.md` (epic merge in the main working copy) | the batch end — `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/batch-end.md` |

The tier still decides, in both lanes, the Reviewer's lenses and whether an IMPORTANT finding blocks in round 1 (Kinds, tiers, budgets).

### Story

Classic lane:

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

Fast lane:

```
todo → in_progress → ready_for_review → in_review → ready_for_merge → done
          ↑                                  │               ↑
          └──── review_rejected ←────────────┘               │
                     (fix pass) in_progress ──PM diff check──┘
```

- `in_review` → APPROVED → `ready_for_merge` (decision line `QA skipped: fast lane`).
- `in_review` → REJECTED → `review_rejected`, `returns` + 1 → ONE fix pass by a fresh Developer → `in_progress` → its IMPLEMENTED report + the PM's diff check → `ready_for_merge`. There is no second review round. WHY: every return costs a fresh Developer and a fresh Reviewer — two full context loads — and a fix pass scoped to named findings is cheap to check by its diff.
- `ready_for_merge` → `done` by a PM fast-forward or a Deploy MERGED. A red merge keeps `ready_for_merge` and goes to a merge-fix Developer (section 5); never a bug.
- `ready_for_qa`, `in_qa`, `qa_rejected`, `merged` and `regression_failed` are never entered.

### Kinds, tiers, budgets

Every entry in the `stories` map has a `kind` (`story` | `bug`) and a `tier` (`light` | `standard` | `critical`). **Absent fields read as `story` / `standard` / `returns: 0`** — entries created before v1.6 need no migration. The tier is assigned by the System Analyst (story-breakdown signal table), may be changed by the Architect in Design Mode (reported in DETAILS — the PM updates state), and is inherited by bugs from their origin item. **The tier decides — one table, every skill cites it:**

| | `light` | `standard` | `critical` |
|---|---|---|---|
| Reviewer lenses | story + rules (the gate / targeted set is still run) | all three | all three + adversarial pass |
| IMPORTANT finding, round 1 | follow-up | follow-up (promotable once, with a stated downstream cost) | blocks |
| IMPORTANT finding, round ≥ 2 (classic lane) | follow-up | follow-up | follow-up |
| QA standard mode (stories, classic lane) | NOT dispatched — `ready_for_qa` → `ready_for_merge` by decision line | E2E per AC | E2E per AC + every exception flow + negative tests |
| Return budget (stories, content tasks), classic lane | 1 | 2 | 3 |
| Bug path, classic lane | Developer → merge → regression | Developer → delta review → merge → regression | Developer → review → QA → merge → regression |
| Return budget (bugs), classic lane | 1 | 1 | 1 |
| Return budget (every kind), fast lane | 1 | 1 | 1 |
| Bug path, fast lane | Developer → merge | Developer → one review → merge | Developer → one review → merge |

*Default, not law — for the QA-skip and review-skip cells only: the PM may dispatch the skipped stage on concrete grounds and record the rationale as a decision line (section 7). The budgets and the IMPORTANT rows are LAW: the only outlet past a budget is the parking gate below.*

### Bug

A bug is a defect item: it restores behavior or closes findings; it never delivers an acceptance criterion from a use case (that is a story). ID `{PREFIX}-BUG-{N}` (counter `bug`), branch `bug/{PREFIX}-BUG-{N}-{slug}`, record `docs/issues/{EPIC-ID}-{slug}/bugs/{BUG-ID}-{slug}.md` (from `docs/templates/bug-template.md`, written by the PM from the originating report or directive). No story file, use case, or spec artifacts — the record is the specification; acceptance = a regression test that reproduces the symptom and passes after the fix, plus the lane's proof (classic: a green quality gate; fast: a green targeted set).

```
classic: todo → in_progress → [ready_for_review → in_review →] [ready_for_qa → in_qa →] ready_for_merge → merged → done
         light: neither bracket · standard: review only · critical: both
fast:    todo → in_progress → [ready_for_review → in_review →] ready_for_merge → done
         light: no bracket · standard / critical: one review round
```

Who may originate a bug (the PM registers it — single-writer):

| Origin | Trigger | Lane |
|--------|---------|------|
| QA regression | OUTCOME: FAILED after an item merge (feature branch) | classic |
| QA regression on `main` | OUTCOME: FAILED after an epic delivery (section 5) | both |
| Deploy | OUTCOME: MERGE_FAILED / VERIFICATION_FAILED | classic (fast: a merge fix, never a bug) |
| Reviewer, QA, Developer reports | an out-of-scope defect larger than a follow-up (more than ~5 lines, or more than one file) | both |
| User | a directive file `docs/directives/active/bug-{slug}.md` (format in start.md Step 2) | both |
| PM, epic end | open follow-ups per `process.followups_gate` → ONE hygiene bug (Follow-ups below) | both |

A red full-gate step at the batch end is never a bug — it is a fix loop (batch end); WHY: one bug per red step cost a full pipeline cycle each. A defect of ≤ 5 lines in one file is never a bug — it is a follow-up. Nobody proposes *stories* for defects: stories come from use cases (System Analyst); defects become bugs or follow-ups. WHY: CBS epic 1 registered 23 `fix:` stories in one day, each paying for a story document, a dispatch, a review and a QA pass — most were one-line changes.

### Notes (fast lane)

`docs/reviews/{EPIC-ID}-notes.md` — one file per epic, PM-only, written on main, created from `docs/templates/notes-file-template.md` when the epic's first NOTE arrives. (Classic reviews keep their Notes inside the saved review, as in 1.6.)

A **NOTE** is (a) a Minor finding — no rule violated, no quality concern — or (b) a finding about the prose of a story, use case or spec where the implemented behavior is right. **A NOTE never returns an item and never changes a verdict.** WHY: NOTE-level and prose findings used to cost full rounds; kept in one file, the cheap ones land in one pass on the merged tree at the batch end.

After every saved review the PM appends each of its NOTEs, under a heading for that review, as one line:

```markdown
## {ITEM-ID} (review round 1, docs/reviews/{ITEM-ID}-1.md)

- [ ] N-{n} · {category} · {finding, with file:line where it applies}
```

`{n}` = `counters.note` + 1, one project-wide sequence (it makes carrying a note to another epic trivial). Categories: test · prose · prose ({role}) · style · docblock · contract · named arguments · selection · performance (later) · rule gap (Architect) · rule text (Architect) · planning (for {items}) · for the {EPIC-ID} merge · Architect ruling before {ITEM-ID}.

At the batch end every open line gets exactly ONE resolution; the line becomes `- [x] N-{n} · … · **{resolution}**`:

| Resolution | Written as |
|---|---|
| fixed by the batch fix | `→ fixed in the batch ({sha})` |
| recorded as a follow-up | `→ FU-{m}` |
| dropped | `dropped: {one-line reason}` |
| carried to another epic's notes file | `→ carried to {EPIC-ID} as N-{k} ({its next merge of main | before {ITEM-ID}})` |
| ruled by the Architect (a rule or ADR on `main`, not part of the delivered diff) | `→ ruled ({sha})` |

A carried note is appended to the receiving epic's notes file under `## Carried from {EPIC-ID}` as `- [ ] N-{k} · {category} · {finding} (was {EPIC-ID} N-{n})`. Under `followups_gate: hygiene_bug`, a note that would become a follow-up is resolved `→ FU-{m}` at triage (not at books), so the hygiene bug covers it and `ready_for_deploy` still sees zero open follow-ups.

The default resolution per category is a signal table in the batch-end reference. Open-line count (a count, never an exit code):

```bash
cat docs/reviews/{EPIC-ID}-notes.md 2>/dev/null | grep -c '^- \[ \] N-'
```

### Follow-ups

`docs/issues/{EPIC-ID}-{slug}/followups.md` — one file per epic, PM-only, written on main. One line per **class** of finding (the same rule or the same pattern), never per instance:

```markdown
# Follow-ups — {EPIC-ID}
- [ ] FU-{n} · {class, one clause} · instances: {file:line, file:line} · origin: {report path | {EPIC-ID} N-{k}} · owner: {ITEM-ID | EPIC-ID} · size: small | larger
- [x] FU-{n} · {class} · … · size: small — **closed by {ITEM-ID}:** {how}
```

- `{n}` = `counters.followup` + 1, one project-wide sequence. `owner:` is optional — the item or epic that will touch the files, or a role (`System Analyst`, `Architect`) for prose and rule follow-ups, which that role's next dispatch closes. Closure texts: `— **closed by {ITEM-ID}:** {how}` · `— **closed by {EPIC-ID} batch fix ({sha}):** {how}` · `— **closed by {Role} ({dispatch}):** {how}` · `— **dropped:** {reason}` · `— **moved to {EPIC-ID}**`.
- Fed from the Reviewer's `## Follow-ups` section, QA's `## Out-of-scope defects`, the Developer's `OUT OF SCOPE` lines, and NOTEs resolved `→ FU-{m}`. Closed by Developers in passing (their briefs point at the file: close entries whose instances lie in files they modify anyway; they report `follow-ups closed:` and the PM ticks the lines with the closure text).
- Also closed by the epic-end hygiene bug (`hygiene_bug`) or resolved at the batch-end triage (`triage`) — below.
- Open-entry count (a count, never an exit code — never Read the file for this): `cat docs/issues/{EPIC-ID}-{slug}/followups.md 2>/dev/null | grep -c '^- \[ \]'`

**Epic end, per `process.followups_gate`** (absent: `hygiene_bug`):

| Value | When every item of the epic (classic) / of the batch (fast) is done |
|---|---|
| `hygiene_bug` (1.6 behaviour) | open entries → ONE hygiene bug; the epic waits for it (`ready_for_deploy` requires zero open entries) |
| `triage` | the PM triages every open entry once (table below); delivery does not wait for zero open entries; the release notes list them by existing IDs |

Triage — *Default, not law: deviate only on concrete grounds, and record the rationale on the follow-up line*:

| Open entry | Outcome (written on the line) |
|---|---|
| gate-breaking, or a correctness defect in delivered behavior, size small | into the batch fix (fast lane) / the hygiene bug (classic lane) — closed by it |
| gate-breaking or correctness, size larger | ONE hygiene bug for the epic, registered now; the batch waits for it |
| infrastructure or operations hardening for things not built yet | `→ moved to {hardening EPIC-ID}` when the project has a deferred-hardening epic, else carried |
| stale, or documentation-only | `— dropped: {reason}` |
| everything else | carried: stays open with `owner:` = the epic that will touch its files; no later epic exists → `owner: backlog` (the next epic to start takes it over, start.md) |

### Return budget and parking (LAW)

`returns` counts an item's rework dispatches. On every REJECTED / FAILED report from a Reviewer, Content Reviewer, or QA (standard mode):

| `returns` before the report | PM does |
|-----------------------------|---------|
| `< budget(tier)` | save the feedback file, set `review_rejected` / `qa_rejected`, `returns` + 1, re-dispatch a fresh Developer (or content agent) when capacity allows |
| `== budget(tier)` | set the rejected status, do NOT increment, set `"parked": true`, do NOT re-dispatch — the item is **parked**: decision line `"note": "budget exhausted ({returns}/{budget}): parked"`; interactive sessions run the budget gate (start.md), `--no-human` parks silently and narrates |

**Fast lane:** the budget is 1 at every tier, so the first REJECTED sends the item to its one fix pass. A fix pass is verified by the PM's diff check instead of a second review: if the check finds a blocking finding still open, apply the `== budget` row (status `review_rejected`, `"parked": true`, budget gate). "One more round" in the fast lane = one more fix pass, verified the same way.

**Parked = the entry carries `"parked": true`** — never a formula: an item at `returns == budget` in a rejected status is still owed its last rework until a report parks it (with a budget of 1, the first REJECTED leaves `returns: 1` and the item is NOT parked). A parked item is not dispatchable — the dispatch map skips it. It leaves parking only through the budget gate — every answer deletes the `parked` key: "one more round" (one extra Developer + verdict cycle, after which this rule runs again), "accept" (the open findings move to followups.md and the item advances to the status the verdict would have granted) — or a directive (unpark, rollback), which deletes it the same way. WHY a field: a formula cannot tell "owed its last rework" from "exhausted" — both have `returns == budget` and a rejected status. WHY: unbounded rounds were the single largest cost in CBS epic 1 — 27 of 50 dispatches were returns, and a README took seven.

### Content task

```
todo → creating → ready_for_review → in_review → ready_for_integration → integrating
     → ready_for_qa → in_qa → ready_for_merge → merged → done
```

Rejections: `review_rejected` → Content Creator; `qa_rejected` with `rejection_reason: "content"` → Content Creator, `"integration"` → Content Integrator. `regression_failed` as for stories. Content tasks always follow this machine (their epics are always `classic`).

### Epic (and content epic)

```
planning → ready → in_progress → ready_for_deploy → deployed → done
                        ↑                                │
                        └────────────────────────────────┘  (a cut batch delivered with items left; a failed main regression)
           (frozen — via directive, from any status; unfreeze restores prior status)
```

- `ready`: planning artifacts complete (BRD, stories, architecture).
- `in_progress`: stamped with its lane on entry (Lanes above).
- `ready_for_deploy` — classic: every item of the epic (stories AND bugs) `done`, and follow-ups handled per `followups_gate`. Fast: the batch's full gate PASSED on `batch.gated_sha`, every note of the batch resolved, follow-ups handled per `followups_gate` (the batch end).
- `deployed`: the feature branch (classic) or the gated SHA (fast) is merged to `main`, awaiting the main-regression decision.
- `done`: main regression PASSED, or skipped by `process.main_regression` with a decision line (section 5).

**The `batch` object (fast lane).** A *batch* is the items merged into one feature branch between two deliveries to `main` — by default the whole epic. The epic entry carries `"batch"` from the moment a batch is cut or its batch end starts:

| Field | Meaning |
|---|---|
| `n` | batch number within the epic, from 1 |
| `items` | `null` = every item of the epic; a list = the members of a cut batch (only they are dispatched until the delivery) |
| `stage` | `null` while items are being built; then `triage` → `main_in` → `batch_fix` → `gate` ⇄ `fix_loop` → `books` → `delivery` (the batch-end reference defines each) |
| `gate_run` | number of full-gate runs so far for this batch, re-gates included (0 before the first) — `{N}` in report names |
| `red_runs` | number of those runs that were FAILED — the fix-loop bound counts these |
| `gated_sha` | the feature SHA the last PASSED gate ran on — the only SHA the delivery may merge |
| `fix_attempts` | dispatches of the current batch fix or fix loop (absent = 0) — the "failed twice" bound counts these; reset to 0 when `stage` moves to `gate` |

After a delivery with items left, the PM resets it to `{"n": n + 1, "items": null, "stage": null, "gate_run": 0, "red_runs": 0, "gated_sha": null}`.

**Held (both lanes, LAW).** An optional `"held": "{reason}"` on an epic or an item entry means: dispatch nothing for it — the dispatch map skips it — until the user answers the gate that set it, or a directive (`unhold-{ID}.md`, or any directive naming it) clears it. The PM sets it with a decision line and removes it with another (`held cleared: {ID} — {answer}`). Who sets it:

| Set by | On | `held` value |
|---|---|---|
| the fix-loop bound gate answered "park", or `--no-human` at the bound | epic (its `batch.stage` stays `fix_loop`) | `"fix loop bound"` |
| a batch fix or fix loop that failed twice (diff check open, or BLOCKED) | epic | `"batch fix failed twice"` |
| a main-in that cannot be combined (MERGE_FAILED) | epic | `"main-in conflict"` |
| a merge fix that failed twice | item (stays `ready_for_merge`) | `"merge fix failed twice"` |

WHY: every loop is bounded; the budget gate parks rejected items (above), `held` parks the loops that have no rejection status.

### Milestone

```
planned → in_progress → delivered → demoed
               ↑             │
               └─────────────┘  (an epic or story linked to a delivered milestone)
```

- `planned`: defined by the user (dialogue or directive); may have no epics yet.
- `in_progress`: the first item of a linked epic, or a linked story, was dispatched. Precondition — the recut check: every epic that gives the milestone some but not all of its stories is either recut or listed as an accepted exception in the milestone's `stories` (milestones reference). If the check fails, the PM narrates the blocker and does not start the milestone.
- `delivered`: every linked epic is `done`, and the epic of every linked story has delivered the batch holding it. The pipeline stops here — no dispatch ever waits for `demoed`.
- `demoed`: the user said the demo ran. Only on the user's word.

### Project phase (cached in `project.json.phase`, computed)

| Phase | Condition |
|-------|-----------|
| `not_started` | no BRDs exist |
| `planning` | BRDs exist, some epic still `planning` |
| `implementation` | at least one epic `ready`/`in_progress`/`ready_for_deploy`/`deployed` — takes precedence over `planning` when both hold (start.md Step 3 runs planning beside it) |
| `done` | `epics.json` `.epics` is empty (every epic archived) and BRDs exist |

(The `phase` labels in the agent registry — planning/infrastructure/implementation/content/on_demand — are grouping labels for humans, NOT this enum.)

## 5. Transition table (PM applies ALL of these)

`Lane` = the lane of the item's epic (section 4, Lanes); `both` rows apply in either lane.

| Lane | From | Event (agent report) | To | Also store / do |
|------|------|----------------------|----|------------------|
| both | epic `ready` | PM dispatches its first item | epic → in_progress | move ALL its items backlog → active (bucket law); stamp `"lane"` (`"classic"` for a cepic); a linked milestone `planned` → `in_progress` in the same response |
| both | todo / review_rejected / qa_rejected (not parked) | PM dispatches Developer | in_progress | assignee; fast lane: a dispatch from `review_rejected` is the fix pass (fresh `developer-{ITEM-ID}-fix`) |
| both | in_progress | Developer IMPLEMENTED — story, or bug of tier standard/critical; fast lane: only when `returns == 0` | ready_for_review | tick `follow-ups closed:` lines; route `OUT OF SCOPE` lines (follow-up or bug, section 4) |
| both | in_progress | Developer IMPLEMENTED — bug of tier light | ready_for_merge | decision line `"review skipped: light bug"` |
| fast | in_progress | Developer IMPLEMENTED — fix pass (`returns == 1`), and the PM's diff check finds every named finding closed | ready_for_merge | decision line `"fix pass verified by the PM reading {a}..{b} against {finding ids}"` |
| fast | in_progress | Developer IMPLEMENTED — fix pass, and the diff check finds a named finding still open | review_rejected, `"parked": true` | decision line `"budget exhausted (1/1): parked"`; budget gate |
| both | ready_for_review | PM dispatches Reviewer | in_review | brief carries ROUND = returns + 1 (fast lane: always 1) |
| classic | in_review | Reviewer APPROVED — story, or bug of tier critical | ready_for_qa | append the review's `## Follow-ups` to followups.md |
| classic | in_review | Reviewer APPROVED — bug of tier standard | ready_for_merge | same |
| fast | in_review | Reviewer APPROVED | ready_for_merge | decision line `"QA skipped: fast lane"`; save the review (`docs/reviews/{ITEM-ID}-1.md`); NOTEs → notes file; Follow-ups → followups.md |
| both | in_review | Reviewer REJECTED | review_rejected (or parked) | review_feedback (path, section 6); returns rule (section 4); follow-ups appended; fast lane: NOTEs → notes file |
| classic | ready_for_qa | story of tier light — no QA dispatch | ready_for_merge | decision line `"QA skipped: light tier"` |
| classic | ready_for_qa | PM dispatches QA | in_qa | — |
| classic | in_qa | QA PASSED | ready_for_merge | route `## Out-of-scope defects` (follow-up or bug) |
| classic | in_qa | QA FAILED | qa_rejected (or parked) | qa_feedback (path) + rejection_reason for content; returns rule |
| classic | ready_for_merge | Deploy MERGED | merged | — |
| classic | ready_for_merge | Deploy MERGE_FAILED / VERIFICATION_FAILED | ready_for_merge (unchanged) | register a bug from the report (tier = the item's tier) |
| fast | ready_for_merge | PM fast-forward (the item branch contains the feature tip) | done | log line with `"trigger": "fast-forward"` and the note `"fast-forward: {feature} {a}..{b}; worktree removed"`; remove the item worktree |
| fast | ready_for_merge | Deploy MERGED (story merge) | done | decision line `"regression QA skipped: fast lane"`; remove the item worktree |
| fast | ready_for_merge | Deploy VERIFICATION_FAILED / MERGE_FAILED | ready_for_merge (unchanged) | dispatch a merge-fix Developer — VERIFICATION_FAILED: on the fix branch exactly as Deploy's report names it (`fix/{ITEM-ID}-merge`, or `…-{k}`), worktree key `{ITEM-ID}-merge-fix`; MERGE_FAILED: in the item's own worktree (merge the feature in); `"fix_attempts"` + 1 on the item; dispatch line; **no bug** |
| fast | ready_for_merge | Developer IMPLEMENTED (merge fix), PM diff check passes | done | the PM fast-forwards the feature to the fix head; log `"report: Developer (merge fix); PM verified the diff"` |
| fast | ready_for_merge | merge fix: the diff check finds the collision still open, or the Developer reports BLOCKED | ready_for_merge (unchanged) | `fix_attempts` < 2: re-dispatch once naming what is open (`fix_attempts` + 1); `fix_attempts` = 2: item `held: "merge fix failed twice"`, surface to the user. `fix_attempts` is deleted when the item is `done` |
| classic | merged | QA(regression) PASSED | done | — |
| classic | merged | QA(regression) FAILED | regression_failed | regression_feedback (path); register a bug (active.json, tier = the item's tier) |
| classic | every epic item done, `followups_gate: hygiene_bug`, open follow-ups > 0 | PM check | (epic unchanged) | register ONE hygiene bug from followups.md, then continue |
| classic | every epic item done, follow-ups handled per `followups_gate` | PM check | epic → ready_for_deploy | — |
| fast | every batch item done | PM check | (epic unchanged) | the batch end starts: `batch.stage` = `triage` (batch-end reference) |
| fast | epic in_progress, `batch.stage` = `triage` | PM triage: follow-ups per `followups_gate`, the notes the batch fix takes | (unchanged) | a larger gate-breaking or correctness follow-up (or any open follow-up under `hygiene_bug`) → register ONE hygiene bug (add it to `batch.items` when that is a list), `stage` back to `null` until it is done; otherwise `stage` = `main_in` |
| fast | `batch.stage` = `main_in` | Deploy (main-in) MERGED | (unchanged) | `stage` = `batch_fix` — or `gate` with decision `batch fix skipped: main-in green, no note chosen` when triage chose nothing |
| fast | `batch.stage` = `main_in` | Deploy (main-in) VERIFICATION_FAILED | (unchanged) | `stage` = `batch_fix`; the batch fix branches from `fix/{EPIC-ID}-main-in` |
| fast | `batch.stage` = `main_in` | Deploy (main-in) MERGE_FAILED | (unchanged) | epic `held: "main-in conflict"`; surface to the user (a ruling may resolve it) |
| fast | `batch.stage` = `batch_fix` or `fix_loop` | Developer IMPLEMENTED, PM diff check closes every named defect | (unchanged) | the PM fast-forwards the feature to the fix head; `stage` = `gate` (a fix loop: QA re-runs from the failed step) |
| fast | `batch.stage` = `batch_fix` or `fix_loop` | diff check finds a defect still open, or BLOCKED | (unchanged) | `batch.fix_attempts` < 2: re-dispatch once naming it (`fix_attempts` + 1); = 2: epic `held: "batch fix failed twice"`. `batch.fix_attempts` resets to 0 whenever `stage` moves to `gate` |
| fast | epic in_progress, `batch.stage` = `gate` | QA (batch gate) FAILED | (unchanged) | `gate_run` + 1 = `{N}`, `red_runs` + 1; save `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md`; decision `gate run {N} red: {step}`; `stage` = `fix_loop`; a fix-loop Developer; **no bug**. When `red_runs` reaches 3 (then 4, 5 … after each "one more run"): the fix-loop bound gate first — "one more run" → decision `fix loop bound: one more run`, continue; "park" (or `--no-human`) → epic `held: "fix loop bound"` |
| fast | epic in_progress, `batch.stage` = `gate` | QA (batch gate) PASSED | (unchanged) | `gate_run` + 1 = `{N}`; `gated_sha` = the SHA the report names; save `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md`; then the re-gate check (batch-end reference): `main` gained code → `stage` = `main_in`; otherwise `stage` = `books` |
| fast | epic in_progress, `batch.stage` = `books` | PM: notes resolved, follow-ups handled | epic → ready_for_deploy | `stage` = `delivery` |
| classic | ready_for_deploy | Deploy (epic merge) MERGE_FAILED / VERIFICATION_FAILED | epic → in_progress | register ONE bug in the epic from the report (origin = the report); the epic re-delivers after it |
| both | ready_for_deploy | Deploy MERGED (to main) | epic → deployed | fast, `deploy_push: never` or no remote: fast-forward `main` to the `delivery/{EPIC-ID}-{n}` branch first (batch-end reference) |
| fast | ready_for_deploy | Deploy (delivery) MERGE_FAILED — code arrived on `main`, or a code conflict | epic → in_progress | `batch.stage` = `main_in`, `gated_sha` = null (re-merge and re-gate) |
| any | any | any agent OUTCOME: BLOCKED | (unchanged) | no transition — resolve the BLOCKERS (sdlc-dispatch section 3); an infrastructure outage waits, it is never a failure |
| both | deployed | `process.main_regression` says skip (decision line with the value and the count) | epic → done | archive sweep + drop from priority_order (bucket law); fast: only when no items outside the delivered batch remain (else the cut-batch row) |
| both | deployed | QA(regression on main) PASSED | epic → done | archive sweep + drop from priority_order (bucket law); fast: only when no items outside the delivered batch remain (else the cut-batch row) |
| both | deployed | QA(regression on main) FAILED | epic → in_progress | the report path on the epic's log line; register ONE bug in the epic (active.json, origin = the report); the epic re-delivers after it — classic: the Deploy flow; fast: `batch` reset to `{"n": n + 1, "items": ["{BUG-ID}"], "stage": null, "gate_run": 0, "red_runs": 0, "gated_sha": null}` |
| fast | deployed | the main-regression decision is made (PASSED or skipped) and items outside the delivered batch remain | epic → in_progress | decision `batch {n} delivered: {item ids}; {k} items left`; reset `batch` (section 4) |
| — | milestone (none) | the user defines it — dialogue or directive | planned | log `"from": null`, `"trigger": "decision: user"` |
| — | milestone planned | the first item of a linked epic or a linked story is dispatched, recut check passed | in_progress | same response as the epic's `ready` → `in_progress` |
| — | milestone in_progress | the last linked epic is `done` and every linked story's batch is delivered | delivered | `delivered_at`; the delivery's decision line names the milestone and the count |
| — | milestone delivered | an epic or a story is linked to it | in_progress | log line naming the addition |
| — | milestone planned | the user says everything the demo needs is already delivered (no epic left to link) | delivered | `delivered_at`; `"trigger": "decision: user"`; nothing to plan or dispatch |
| — | milestone delivered | the user says the demo ran | demoed | `demoed_at`, `closed_at`; `"trigger": "decision: user"` |

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

There is NO `history` field — transitions go to `log.jsonl` (section 7). `kind` / `tier` / `returns` are defined in section 4 (Kinds, tiers, budgets); absent = `story` / `standard` / `0`. An item carries `"milestone": "{PREFIX}-MS-{n}"` ONLY when it is listed in a milestone's `stories` (the uncut exception) — otherwise its milestone is its epic's. `"parked": true` appears only while the item is parked (section 4, Return budget and parking); `"held": "{reason}"` only while it is held (section 4, Epic); `"fix_attempts": {n}` only while a merge fix is in flight (section 5).

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

Counters: `project.json.counters` holds `brd`, `uc`, `epic`, `story`, `bug`, `note`, `followup`, `milestone`, `cp`, `cepic`, `ctask`. If an older `project.json` lacks one, add it with `0` when first needed (init also merges them on repair runs) — except `followup`: seed it with the highest `FU-{n}` already used (`find docs/issues -name followups.md -exec cat {} + 2>/dev/null | grep -oE 'FU-[0-9]+' | sed 's/FU-//' | sort -n | tail -1`, empty → 0), or new numbers collide with 1.6's per-epic ones.

**Feedback fields hold a file path, never verbatim text:**

| Field | You write the agent's DETAILS (or its REPORT FILE) to | Then store |
|-------|----------------------------------|------------|
| `review_feedback` | `docs/reviews/{ITEM-ID}-{n}.md` (you save the Reviewer's document there anyway) | that path |
| `qa_feedback` | `docs/reports/{ITEM-ID}-qa-{n}.md` | that path |
| `regression_feedback` | `docs/reports/{ITEM-ID}-regression-{n}.md` | that path |

`{n}` starts at 1 and increments per round; the field always holds the LATEST path. Rework briefs pass the path and the agent reads the file — never paste feedback text into state or briefs. The notes file has no field either — its path is fixed: `docs/reviews/{EPIC-ID}-notes.md`. Batch-gate reports have no field — every run, PASSED or FAILED, is saved as `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md` (`{n}` = `batch.n`, `{N}` = `batch.gate_run` after the increment), so no batch and no re-gate ever overwrites another run's report; the delivery cites the run whose SHA is `batch.gated_sha`.

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
  },
  "milestones": {},
  "milestone_order": []
}
```

(no `history`; `type` is `"epic"` or `"cepic"`; cepic branches use `content/{PREFIX}-CEPIC-{N}-{slug}` and `brd` is the content plan ID.)

Optional epic fields — absent means the default in the right column; write them only when they carry a value:

```json
"{PREFIX}-EPIC-{N}": {
  "title": "{title}",
  "status": "in_progress",
  "type": "epic",
  "brd": "{PREFIX}-BRD-{M}",
  "branch": "feature/{PREFIX}-EPIC-{N}-{slug}",
  "lane": "fast",
  "batch": { "n": 1, "items": null, "stage": null, "gate_run": 0, "red_runs": 0, "gated_sha": null },
  "milestone": "{PREFIX}-MS-{K}",
  "continued_by": null,
  "base_branch": null,
  "carries": [],
  "delivers_after": []
}
```

| Field | Written when | Absent = |
|---|---|---|
| `lane` | epic `ready` → `in_progress` (section 4, Lanes) | `classic` |
| `batch` | a batch is cut, or the batch end starts (section 4, Epic) | whole epic, not in its batch end |
| `milestone` | the epic is linked to a milestone (same response as the milestone's `epics` list) | no milestone |
| `continued_by` | a milestone recut split this epic; names the remainder epic | not split |
| `base_branch` | the feature was cut from another epic's feature, not from `main` (cross-epic reference) | `main` |
| `carries` | the feature merged another epic's feature: `[{"epic": "{EPIC-ID}", "sha": "{sha}"}]` | nothing carried |
| `delivers_after` | epic IDs that must be `done` before this epic's delivery (cross-epic reference) | no ordering |

Milestone entry (inside `"milestones"`) and its order:

```json
"milestones": {
  "{PREFIX}-MS-{K}": {
    "id": "{PREFIX}-MS-{K}",
    "title": "{short name}",
    "goal": "{the goal or the demo, one or two sentences}",
    "target": null,
    "status": "planned",
    "epics": [],
    "stories": [],
    "slice_doc": null,
    "planned_count": null,
    "created_at": "{ISO-8601 UTC}",
    "delivered_at": null,
    "demoed_at": null,
    "closed_at": null
  }
},
"milestone_order": ["{PREFIX}-MS-{K}"]
```

- `target`: `"YYYY-MM-DD"` or `null`. `slice_doc`: `"docs/reports/demo-slice-{N}.md"` once written. `planned_count`: `{"epics": {E}, "items": {I}}` from the slice document's final count — kept to show drift against the live count.
- An epic belongs to at most one milestone. A milestone's `epics` and each epic's `milestone` field are written **in the same PM response** (like the bucket-law move pair). `stories` lists only items of an epic that is NOT linked whole (the uncut exception); each such item carries its own `milestone`.
- ID `{PREFIX}-MS-{K}` from `counters.milestone` + 1.

`archive/done-{YYYY-MM}.json` — three maps; entries arrive unchanged from their source files:

```json
{ "epics": {}, "stories": {}, "content_tasks": {} }
```

`docs/state/project.json` `worktrees` map — one entry per active worktree, keyed by `{ITEM-ID}`, or for epic- and planning-level worktrees by their directory name (`{ITEM-ID}-merge-fix`, `{EPIC-ID}-merge`, `{EPIC-ID}-merge-fix` (feature-in), `{EPIC-ID}-batch-fix`, `{EPIC-ID}-gate-run{N}`, `{EPIC-ID}-main-regression`, `{EPIC-ID}-delivery`, `{ROLE}-{topic}`, `ARCH-{topic}`):

```json
"{ITEM-ID}": {
  "path": "{worktree_dir}/{ITEM-ID}",
  "branch": "{branch}",
  "ports": { "app": 3100, "db": 5433 },
  "stack": null
}
```

`project.json.max_parallel_teammates` (absent: 4) caps working teammates (sdlc-dispatch section 2). An item's `assignee` = the teammate name it was dispatched to (`{role}-{ITEM-ID}`), or `subagent` in fallback mode. Ports: allocate `app` starting at 3100, `db` at 5433, for item worktrees at creation and for epic-level worktrees only when a stack runs there; incrementing per active worktree (the numbers above are the first worktree's) — collisions break parallel Docker stacks. `stack`: `null` while the holder runs no stack, `"local"` while it runs a stack on this machine, `"runner {NN} slot {x}"` while it holds a runner slot — the PM sets it at dispatch and clears it at release (the stack budget in sdlc-dispatch section 2 counts `"local"` entries). Exception: a Developer's runner slot stays with the item until its review is verified — the Reviewer re-runs on the story's own slot (runners reference).

`docs/state/project.json` `process` block — how this project runs. **Absent block, absent key → the classic preset value.** `/agent-sdlc:init` writes the fast preset for a new project and the classic preset when it repairs a 1.x project:

```json
"process": {
  "lane": "fast",
  "main_regression": "if_main_gained_code",
  "docs_only_paths": ["docs/", ".claude/"],
  "followups_gate": "triage",
  "demo_gate": "on_request",
  "planning_depth": "just_in_time",
  "deploy_push": "on_green",
  "deploy_exclusivity": "per_target_branch",
  "max_local_stacks": 2,
  "report_max_chars": 3500,
  "commit_attribution": false,
  "attribution_patterns": ["co-authored-by", "generated with claude", "🤖", "claude-session"],
  "commit_conventions": null,
  "shell": "zsh",
  "models": { "default": "inherit" },
  "standing_brief_lines": { "all": [] },
  "content_guard": null
}
```

| Key | Values | fast preset | classic preset (= absent) | Read by |
|---|---|---|---|---|
| `lane` | `fast` \| `classic` | `fast` | `classic` | epic stamp (section 4) |
| `main_regression` | `always` \| `if_main_gained_code` \| `never` | `if_main_gained_code` | `always` | after every delivery (section 5; batch-end reference) |
| `docs_only_paths` | path prefixes that count as "documents" | `["docs/", ".claude/"]` | same | the main-regression count, the re-gate check, delivery conflicts |
| `followups_gate` | `triage` \| `hygiene_bug` | `triage` | `hygiene_bug` | epic end (section 4, Follow-ups) |
| `demo_gate` | `on_request` \| `blocking` \| `off` | `on_request` | `blocking` | after every delivery (start.md) |
| `planning_depth` | `just_in_time` \| `all` | `just_in_time` | `all` | planning phase (start.md) |
| `deploy_push` | `on_green` \| `never` | `on_green` | `never` | Deploy (story-merge skill) |
| `deploy_exclusivity` | `per_target_branch` \| `per_epic` | `per_target_branch` | `per_epic` | sdlc-dispatch section 2 |
| `max_local_stacks` | integer | `2` | `2` | sdlc-dispatch section 2 |
| `report_max_chars` | integer | `3500` | `3500` | every brief's REPORT cap |
| `commit_attribution` | `false` (the hook denies attribution) \| `true` | `false` | `false` | `hooks/scripts/guard-commit.sh` |
| `attribution_patterns` | case-insensitive fixed strings | as shown | same | the same hook |
| `commit_conventions` | `null` \| `{"prefix_pattern": "{POSIX ERE with {PREFIX}}"}` — applies to EVERY commit with a single `-m`, PM state commits included, so the pattern must accept `{PREFIX}: …` too; no `\d`/`\w` (POSIX ERE) | `null` | `null` | the same hook |
| `shell` | `zsh` \| `bash` | from `$SHELL` | from `$SHELL` | the evidence-and-shell reference |
| `models` | `{"default": "inherit", "{Role}": "{model}", "{Role}:{mode}": "{model}"}` | `{"default": "inherit"}` | same | sdlc-dispatch section 1 |
| `standing_brief_lines` | `{"all": [...], "{Role}": [...]}` | `{"all": []}` | same | every brief's `{standing lines}` |
| `content_guard` | `null` \| `{"command": "{cmd}", "pre_commit": true \| false}` | `null` | `null` | quality-gate Step 0; init's pre-commit hook |

(`commit_attribution: false` is lane-independent git hygiene: the classic preset keeps it — turning the hook off is one key.)

`docs/state/project.json` `integrations.runners` — remote stack runners (runners reference):

```json
"runners": { "enabled": false, "tooling_dir": null, "inventory": null }
```

## 7. Transition log and commits

Every transition appends ONE line to `docs/state/log.jsonl` — via Bash append, so the file never enters context:

```bash
echo '{"item":"{ITEM-ID}","from":"{old}","to":"{new}","by":"pm","at":"{ISO-8601 UTC}","trigger":"{agent role or directive filename}"}' >> docs/state/log.jsonl
```

- Registering a new item or epic logs `"from": null` (trigger = the registering agent's role). Registering a bug logs `"trigger": "{QA | Deploy | Reviewer | Developer | directive: {filename} | hygiene}"` plus `"origin": "{report path or directive filename}"`.
- A line's `item` may be an item, an epic, or a milestone ID. A milestone transition caused by an epic or item event (its first dispatch, its delivery) carries that event's trigger; one caused by the user carries `decision: user`. A session-wide event (teammates stopped at a usage limit) logs one line per affected item.
- **One line per transition.** A status change is logged once, with the trigger of its cause (`report: {Role} {OUTCOME}`, `fast-forward`, `batch end`, a directive filename); where section 5 says "decision line `{note}`" on a row that changes a status, that note goes on this same line as `"note"` — never a second line. A separate decision line exists only when no status changes.
- A recorded deviation from a default (e.g. skipping Designer or the infra phase for an epic) is a **decision line**: `from` and `to` both equal the current status, `"trigger": "decision"`, plus `"note": "{rationale}"`. Extra keys are allowed on any line.
- **Planning-chain visibility:** planning work changes no statuses, so it is invisible without these two lines. Before dispatching any planning-chain agent (Product Manager, System Analyst, Architect, Designer, Cloud Architect, DevOps Engineer) log a **dispatch line** — `from` == `to` == the epic's current status, `"trigger": "dispatch: {Role}"`, `"note": "{mode/scope, one clause}"`. After verifying its report, log a **completion line** — same shape, `"trigger": "{Role}"`, `"note": "{OUTCOME + one clause}"` — unless the verified report immediately changes a status (then the normal transition line IS the completion record). /status and the tracker read these as the live "who is working now" signal.
- Bucket moves and archive sweeps are NOT logged — they are consequences of the epic transition, which is.
- Append only: never Read or Edit log.jsonl. Its readers are /agent-sdlc:status (verbose) and crash forensics, not orchestration. A wrong line is voided by a `correction` line, never edited.

**Vocabulary of the `trigger` field:**

| Trigger | Status change | `note` carries |
|---|---|---|
| `dispatch: {Role}` / `dispatch: {Role} ({mode})` | none, or the working status | base sha, stack (`local` / `runner {NN} slot {x}` / `none`), model when not inherited, parallel items. Modes: `fix pass`, `merge fix`, `batch fix`, `fix loop`, `main in`, `{EPIC-ID} in`, `delivery`, `full gate`, `regression`, `ruling`, `pre-ruling`, `notes triage`, `story cut`, `amendment pass`, `demo preparation`, `milestone`, `milestone recut`, `milestone slice`, `continuation`, `resumed` |
| `report: {Role} {OUTCOME}` | as the transition table says | head sha and counts |
| `report: Developer ({mode}); PM verified the diff` | as the transition table says | the sha range, each finding → fixed, the counts |
| `decision` | none | a fixed note (below) or a rationale |
| `decision: user` | none, or the milestone transition | the user's ruling, quoted or paraphrased |
| `recut` | an item's `epic` changes | from-epic → to-epic, the milestone |
| `batch end` | a PM-initiated epic transition or `batch.stage` change during the batch end (books → `ready_for_deploy`) | the stage and what closed it |
| `fast-forward` | an item `ready_for_merge` → `done` by the PM's fast-forward | the fixed note `fast-forward: …` |
| `correction` | none | the lines it voids, and why |
| `{directive filename}` | as the directive says | — |

**Fixed decision notes** (write exactly these, filling the braces):

| Mechanism | `note` |
|---|---|
| light tier / light bug skips | `QA skipped: light tier` · `review skipped: light bug` |
| budgets | `budget exhausted ({returns}/{budget}): parked` · `budget gate: one more round` · `budget gate: accepted — findings to follow-ups` |
| fast lane stages | `QA skipped: fast lane` · `regression QA skipped: fast lane` · `fix pass verified by the PM reading {a}..{b} against {finding ids}` |
| PM fast-forward | `fast-forward: {feature} {a}..{b}; worktree removed` (+ `; {ITEM-ID} will need a real merge` for each in-flight item now behind) |
| merge queue | `merge queued behind {ITEM-ID}'s` |
| batches | `batch cut: {item ids} — {reason}` · `batch end: {stage}` · `batch fix skipped: main-in green, no note chosen` · `main-in skipped: main already in the feature` · `gate run {N} red: {step}` · `fix loop bound: {one more run | parked}` · `re-gate skipped: {A} code paths on main, all already on the feature` · `batch {n} delivered: {item ids}; {k} items left` · `refinement skipped: {MS-ID} plan is live` |
| held | `held: {ID} — {reason}` · `held cleared: {ID} — {answer or directive}` |
| milestones (on the milestone ID) | `{EPIC-ID} done: {d}/{t} epics delivered` · `milestone complete: {t}/{t} epics delivered` · `recut check failed: {EPIC-ID} gives {k}/{n} stories` |
| main regression | `main regression: {always | if_main_gained_code | never}, {count} code paths — {dispatched | skipped}` (+ `; override: {reason}` when the PM dispatches anyway) |
| cross-epic | `delivery order: {EPIC-ID} before {EPIC-ID}` · `carries {EPIC-ID} at {sha}` |
| demo | `demo offered on request ({milestone | epic})` · `demo gate: {answer}` |
| stacks and recovery | `stack released: {holder} {slot} (stale)` · `teammates stopped: session limit` · `teammates resumed: {names}` |

Commit conventions (exact formats):

| Actor | Format |
|-------|--------|
| PM state updates | `{PREFIX}: Update state — {ID} {old}→{new} [by PM]` — `{ID}` an item, an epic or a milestone; a batch-end stage change uses the stages as `{old}`/`{new}`; several items in one step: `{PREFIX}: Update state after dispatch [by PM]` / `{PREFIX}: Update state — {summary} [by PM]` (staged and committed by path, section 1) |
| PM: an epic reaches `done` (both lanes) | `{PREFIX}: Complete epic {EPIC-ID} [by PM]` |
| Agent work commits (in worktree) | `{ITEM-ID}: {description} [by {Role}]` |
| Fix-branch commits (merge fix, batch fix, fix loop) | `{ITEM-ID or EPIC-ID}: {description} [by Developer]` |
| Planning/infra commits | `{PREFIX}: {description} [by {Role}]` |
| PM merge of a planning or ruling branch into `main` | `{PREFIX}: Merge {Role} {topic} [by PM]` |
| Deploy: item merge (classic) / story merge (fast) | `{ITEM-ID}: Merge to feature branch [by Deploy]` / `{PREFIX}: Merge {ITEM-ID} into {EPIC-ID} [by Deploy]` |
| Deploy: main-in / feature-in | `{PREFIX}: Merge main into {EPIC-ID} for the batch end [by Deploy]` / `{PREFIX}: Merge {EPIC-ID} into {EPIC-ID} [by Deploy]` |
| Deploy: epic to main (classic) / delivery (fast) | `{PREFIX}: Deploy {EPIC-ID} ({title}) to main [by Deploy]` / first line of `docs/templates/delivery-commit-template.md` |

While `process.commit_attribution` is `false` (both presets): no attribution trailers (`Co-Authored-By`, "Generated with Claude", session links) in any commit or PR — `hooks/scripts/guard-commit.sh` denies them, and this project rule overrides the harness's default commit template.

## MUST NOT DO

- An agent editing `docs/state/*.json` — under any circumstances, including "just fixing" a stale status it noticed (report it instead).
- PM applying a transition without a matching agent report with evidence — the only exceptions are the PM's own mechanical steps, each logged with its trigger: `fast-forward` (an item branch that already contains the feature tip, start.md Merge flow) and `batch end` (the books → `ready_for_deploy` step).
- Inventing entry fields or statuses not defined here — extend this file first (see docs/extending-sdlc.md).
- Writing log lines with relative or local times — ISO-8601 UTC only.
- Deleting an entry from its source file before the destination file is written and parses — move discipline is destination-first, and the tempting "delete first so I don't forget" order turns a crash into data loss.
- Pasting feedback text into state fields or briefs — feedback fields hold paths (section 6); the text lives once, in its file.
- Reading `archive/`, `log.jsonl`, or (outside registration / epic start) `backlog.json` during orchestration — the read discipline exists precisely so state size never taxes the session again.
- Registering a *story* for a defect — defects are bugs or follow-ups (section 4); stories come only from the System Analyst's breakdown.
- Registering one item per instance of the same finding class — one class, one record (bug or follow-up line) with the instances listed.
- Dispatching a parked or `held` item or epic, or incrementing `returns` past the budget — the gates and directives are the only exits.
- Registering a bug for a fast-lane merge failure or a red batch-gate step — those are a merge fix and a fix loop.
- Changing an in-flight epic's `lane` stamp, or reading the lane from `process.lane` for an epic that already has one — WHY: half an epic on each lane has no defined batch end.
- Moving milestones between files, or writing one side of a milestone link without the other in the same response — WHY: a crash between the two writes leaves an epic counted by a milestone that does not list it.
- Checking out another branch in the main checkout, or committing state with a bare `git commit`.
- Accepting a runner step's result whose start token does not match the dispatch — an old log is never this run's pass.
