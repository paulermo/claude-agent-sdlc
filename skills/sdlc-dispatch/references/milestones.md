# Milestones

A milestone is a demo the user decides: a name, a goal or demo, an optional target date, and the whole epics that deliver it. Its machine, transitions, entry schema and log vocabulary are law in `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-state/SKILL.md` (section 4 Milestone, section 5 milestone rows, section 6 milestone entry, section 7) — this file holds only the procedures. Load it when the user names or edits a milestone, a milestone directive arrives (start.md Step 2), a milestone needs planning, a linked item is about to be dispatched for the first time, a linked epic reaches `done`, or a demo is due. Brief templates: `${CLAUDE_SKILL_DIR}/references/briefs/{role}.md`. A milestone transition's log line carries the trigger of the line that caused it (the epic's or item's line in the same response); creation (`→ planned`) and `→ demoed` carry `decision: user`.

## 1. Create or edit in dialogue

Runs in the PM session (`/agent-sdlc:start`) and in `/agent-sdlc:milestone new | edit {MS-ID}`; only the acceptance step differs.

**New.** The user names a milestone ("the next demo is X, by Y"). Ask ONLY for what the user has not already given, ONE question per message, in this order; each question ends your message, and that message makes no tool calls:

1. `What should the milestone be called? A short name.`
2. `What is its goal, or the demo you want to see? One or two sentences.`
3. `Is there a target date? A date (YYYY-MM-DD) or "none".`

Convert a relative date ("end of next week") to `YYYY-MM-DD` and show it in the entry. **Edit:** ask one question — `What should change for {MS-ID}: the title, the goal, the target, or the linked epics / stories?` — and apply the answer to a draft. Then present the FULL entry (never a delta):

> ## Milestone {PREFIX}-MS-{K} — {title} ({new | edit})
> **Goal / demo:** {goal}
> **Target:** {YYYY-MM-DD | none}
> **Epics:** {EPIC-ID title, … | none yet — milestone planning links them (section 3)}
> **Stories (uncut exception):** {ITEM-IDs | none}
> {Create | Apply} it? ("yes", "go" or "create" — or tell me what to change)

**>>> GATE: user response required. Make NO tool calls in the same message as this question. <<<**
Acceptable answers: "yes", "go", "create". Anything else is an edit: apply it to the draft, re-present the FULL entry, gate again. In a new entry `{K}` = `counters.milestone` + 1.

**On acceptance — PM session** (one response, in this order):
1. New: `counters.milestone` + 1 in `project.json` (add `"milestone": 0` first if it is missing).
2. New: write the entry into `epics.json` `.milestones` exactly per sdlc-state section 6 — `"status": "planned"`, `"epics": []`, `"stories": []`, `created_at` = now (UTC), every other field `null` — and append the ID to `milestone_order`. Edit: apply each change per section 2.
3. Log (Bash append): new → `{"item":"{MS-ID}","from":null,"to":"planned","by":"pm","at":"{ISO-8601 UTC}","trigger":"decision: user","note":"{the user's words, one clause}"}`; an edit → section 2's lines.
4. Commit by path: `git add -- docs/state && git commit -m "{PREFIX}: Update state — {MS-ID} {old}→{new} [by PM]" -- docs/state` (`{old}` = `null` for a new milestone; an edit without a status change repeats the status). Narrate one line; a new milestone is planned next (section 3).

**On acceptance — `/agent-sdlc:milestone`:** write the directive of section 2 instead and touch NO state — only `/agent-sdlc:start` writes state (sdlc-state section 1).

## 2. The directive, and edits

Path: `docs/directives/active/{YYYY-MM-DD}-milestone-{slug}.md` (`{slug}` = the title in kebab-case). Exact fields, one per line:

```
milestone: new | edit {MS-ID}
title: {short name | unchanged}
goal: {one or two sentences | unchanged}
target: {YYYY-MM-DD | none | unchanged}
epics: {EPIC-ID, EPIC-ID | none | unchanged}
stories: {ITEM-ID, ITEM-ID | none | unchanged}
```

`new` never uses `unchanged`. `epics:` and `stories:` hold the COMPLETE list after the change: in the list but not in state = link; in state but not in the list = unlink. start.md Step 2 applies `new` exactly like the dialogue's acceptance, then its links; `edit` per this table. Each change is its own log line — `"trigger":"decision: user"` (a link applied from a planning report, section 3 step 4, carries `"trigger":"Product Manager"`), `from` = `to` = the milestone's status unless a Situation row says otherwise — and one commit covers the directive:

| Change | PM writes (one response) | Log `note` |
|---|---|---|
| title / goal / target | the field | `renamed: {old} → {new}` / `goal changed: {new}` / `retargeted: {old \| none} → {new \| none}` |
| link / unlink epic | `epics` AND the epic's `"milestone"` key (set / delete) — both sides, same response (sdlc-state section 6) | `linked {EPIC-ID}` / `unlinked {EPIC-ID}` |
| link / unlink story | `stories` AND the item's `"milestone"` key in its bucket file (sdlc-state section 2) | `linked {ITEM-ID} (uncut exception)` / `unlinked {ITEM-ID}` |

| Situation | Action |
|---|---|
| a link to a `delivered` milestone | that link's line is the transition `delivered → in_progress` (sdlc-state section 5) |
| an epic already `in_progress` or later is linked to a `planned` milestone | run the recut check (section 4) now; it passes → `planned → in_progress` in the same response as the link |
| the epic belongs to another milestone | unlink it there first (its own line), then link — an epic belongs to at most one milestone |
| the epic is `done` (archived) | refuse; narrate `{EPIC-ID} is delivered — only epics not yet done can join a milestone` (orchestration never reads the archive) |
| the story's epic is linked whole to any milestone | refuse and narrate — the uncut exception is only for items of an epic NOT linked whole |
| an unlink leaves every linked epic `done` and every linked story delivered | apply `in_progress → delivered` (section 5, step 4) |

## 3. Planning a milestone

Trigger: a `planned` milestone with `slice_doc: null` and no linked epics — the first such in `milestone_order` — right after creation or at the next planning opportunity (planning is stackless and pairs with implementation work, sdlc-dispatch section 2). A milestone whose epics the user linked directly needs no planning unless the user asks for a slice (`planned_count` stays `null`). Every dispatch below gets a dispatch and a completion line (sdlc-state section 7) with `"item": "{MS-ID}"`, runs in a planning worktree that you merge after verification (start.md, planning phase), and uses `briefs/planning.md`. `{K}` = the milestone's number.

1. **Product Manager — milestone**: the milestone's ID, title, goal and target; the user-accepted uncut exceptions (or none); reserved epic IDs `{PREFIX}-EPIC-{c+1}` … `{PREFIX}-EPIC-{c+n}` (`c` = `counters.epic`, `n` = the number of non-archived epics) — register no other epic until step 4 is applied. Log `dispatch: Product Manager (milestone)`. OUTCOME `MILESTONE_PLANNED`: its merge brings `docs/reports/demo-slice-{K}.md`, `docs/reports/milestone-{K}-recut.md` and the `epic.md` files to `main`; keep its RECUT and MILESTONE blocks (formats: `brd-writing`, milestone modes; DETAILS `RECUT: see docs/reports/milestone-{K}-recut.md` → read the block under that document's `## RECUT block`) — do not apply them yet.
2. **System Analyst — milestone slice**: the slice document path. OUTCOME `SLICED`: one `verdict:` line per prerequisite and the fixed line `final count: {"epics": {E}, "items": {I}}` (`story-breakdown`, milestone slice mode).
3. A `pulled in whole ({ITEM-ID} from {EPIC-ID})` verdict whose epic is neither linked whole by the MILESTONE block nor recut by the RECUT block → **Product Manager — milestone recut** for that epic, reserved IDs continuing after the ones used; OUTCOME `RECUT` adds a RECUT block (an epic it reports whole is linked whole in step 4c).
3b. Act on the Product Manager's report lines before step 4 (each one, once):
   - `breakdown owed: {EPIC-ID} (partial)` → dispatch the System Analyst breakdown for that epic next, whatever `process.planning_depth` says, then **Product Manager — milestone recut** for it; apply step 4 for the other epics meanwhile — this epic is linked only after its recut.
   - `exception short: {ITEM-ID}` → present, and gate:
     > ## {MS-ID} needs {ITEM-ID} «{title}» from {EPIC-ID}, which is not recut
     > Options: "accept" (link {ITEM-ID} as an uncut exception — the rest of {EPIC-ID} stays out) · "recut" (split {EPIC-ID} so the milestone gets a whole epic)

     **>>> GATE: user response required. Make NO tool calls in the same message as this question. <<<**
     Acceptable answers: "accept", "recut". Anything else is a question — answer it and gate again. `accept` → link the story (section 2, a `decision: user` line); `recut` → Product Manager — milestone recut for {EPIC-ID}; `--no-human` → recut.
   - `needed from {…}` → narrate it in one line; no state change.
4. Apply every block, in one response (move discipline, sdlc-state section 2):
   a. `EPIC:` → add the entry to `epics.json` `.epics` as given (its `status` is `ready`, or `planning` when the original still is). `PRIORITY: {NEW} after {PRECEDING}` → insert it into `priority_order` there. `CONTINUED_BY: {EPIC-ID} → {NEW}` → the original's `"continued_by"`. `counters.epic` (and `counters.cepic` for a content-epic remainder) = the highest ID used of each kind (the report's `counters consumed`). Log `"from": null`, `"to": "{status}"`, `"trigger": "Product Manager"`. An `EPIC:` entry never carries `"milestone"` — links come only from the MILESTONE block (step 4c), both sides.
   b. `MOVE: {FROM} → {TO}: {ITEM-ID}, …` → set each item's `epic` to `{TO}`. The remainder is `ready` or `planning`, so its items live in `backlog.json`: an original in `planning` / `ready` already has them there (edit in place); an original in `in_progress` or later → move each one `active.json` → `backlog.json`. One line per item: `{"item":"{ITEM-ID}","from":"{status}","to":"{status}","by":"pm","at":"{ISO-8601 UTC}","trigger":"recut","note":"{FROM} → {TO}, {MS-ID}"}`. A MOVE naming an item that is not `todo` → skip that item and re-dispatch milestone recut naming it: an item in flight never changes epic.
   c. MILESTONE block (plus any epic step 3 reported whole) → link its `epics` and `stories` per section 2's link rows (with their log lines); `slice_doc` as given; `planned_count` = the System Analyst's `final count` (the block's own count only when no `SLICED` report exists — it is marked `estimate`). Its `title`, `goal` and `target` are already the entry's.
   d. Commit by path: `git add -- docs/state && git commit -m "{PREFIX}: Update state — {MS-ID} planned: slice and recut [by PM]" -- docs/state`.
5. The slice document's `## Design owed` lines → an Architect Design Mode dispatch before the first item each names.

## 4. The recut check (before `planned → in_progress`)

Run it when the first item of a linked epic, or a linked story, is about to be dispatched while the milestone is `planned` (sdlc-state section 4), and when an epic already in flight is linked to a `planned` milestone (section 2). Reading `backlog.json` is allowed here — this is an epic start.

```bash
cat docs/state/epics.json docs/state/backlog.json docs/state/active.json | jq -s -r --arg ms '{MS-ID}' '
.[0] as $ix | $ix.milestones[$ms] as $m
| [.[1:][] | (.stories // {}), (.content_tasks // {}) | to_entries[] | select(.value.kind != "bug")] as $I
| ($m.epics[] as $e | if $ix.epics[$e] == null then "linked \($e) archived" else
   "linked \($e) items=\([$I[] | select(.value.epic == $e)] | length) continued_by=\($ix.epics[$e].continued_by // "none") milestone=\($ix.epics[$e].milestone // "MISSING")" end),
  ($m.stories[] as $s | $I[] | select(.key == $s) | "exception \(.value.epic) \(.key) milestone=\(.value.milestone // "MISSING")")'
sed -n '/^## The slice by epic/,/^## Placement/p' {slice_doc}
```

Compare each printed line with the slice document's row for the same epic ("Items in the slice", "Items left for later"):

| Finding | Verdict |
|---|---|
| `linked` line with `items` greater than its row's "Items in the slice", or whose row has "Items left for later" > 0 while `continued_by=none` | partial, not recut — FAIL |
| any line with `milestone=MISSING` or another milestone's ID | one-sided link — FAIL: write the missing side (section 2), re-run |
| a row with "Items in the slice" > 0 whose epic has neither a `linked` nor an `exception` line | contributes, but neither linked nor accepted — FAIL |
| an `exception` line carrying this milestone's ID | accepted by the user (its place in `stories` is the record) — pass |
| `linked … archived` (the epic is `done`) | pass |
| `linked` with fewer `items` than its row, or with no row (pulled in by step 3), or `slice_doc` is `null` | pass (only the `milestone=` row applies); a lower count shows as drift (section 6) |

All pass → `planned → in_progress` in the same response as the epic's `ready → in_progress` (or the linked story's dispatch), with its log line. Any FAIL → dispatch no item of an epic that has not started yet for this milestone (an epic already in flight keeps dispatching; only the milestone stays `planned`). Per partial epic, a decision line on the milestone ID (`from` = `to` = `planned`) with the note `recut check failed: {EPIC-ID} gives {k}/{n} stories` and one narrated line `Milestone {MS-ID} not started: {EPIC-ID} gives {k} of {n} stories and is not recut` (`{k}` = its row's "Items in the slice"; `{n}` = `items`, or for an unlinked epic `{k}` + "Items left for later"). Then dispatch Product Manager — milestone recut for those epics and continue other work. The user may instead accept the stories as an uncut exception — only through an `edit` directive (`/agent-sdlc:milestone edit {MS-ID}`, whose gate the user answers: unlink the epic, link the stories), never an ungated answer in chat.

## 5. Delivery bookkeeping, `delivered`, `demoed`

In the same response as a linked epic's `→ done` (after its archive sweep):

1. Count: `jq -r --arg ms '{MS-ID}' '. as $ix | .milestones[$ms].epics | "\([.[] | select($ix.epics[.] == null)] | length)/\(length)"' docs/state/epics.json` → `{d}/{t}` (a linked epic absent from `.epics` is archived, i.e. `done`).
2. Each linked story (`stories`) is delivered when its epic is absent from `.epics` (archived) — its epic is the `epic` of its `active.json` entry, or, when it has none there, the `**Epic:**` line of its file: `grep -rhm1 '^\*\*Epic:\*\*' --include='{ITEM-ID}-*.md' docs/issues` — or when `git merge-base --is-ancestor {its branch} {main-ref}; echo "exit=$?"` prints `exit=0` (`{main-ref}` = `origin/main` after `git fetch origin`; local `main` when `process.deploy_push` is `never` or there is no remote).
3. `{d}` < `{t}`, or a linked story not delivered → decision line: `"item":"{MS-ID}"`, `from` = `to` = `in_progress`, `"trigger":"decision"`, `"note":"{EPIC-ID} done: {d}/{t} epics delivered"`.
4. Otherwise → `in_progress → delivered`, `delivered_at` = now, note `milestone complete: {t}/{t} epics delivered`. The pipeline goes on; nothing waits for `demoed`. Run steps 2–4 also after a cut-batch delivery of an epic that holds a linked story.

**`demoed` — ONLY on the user's word** (in the session, or a directive): `delivered → demoed`, `demoed_at` and `closed_at` = now, `"trigger":"decision: user"`, note = the user's words. Never infer it from a delivery, a demo preparation's `READY` report, or silence. The user says the demo ran for a milestone not yet `delivered` → no transition: log a `decision: user` line with the words and narrate that `demoed` follows `delivered`.

## 6. Progress (what `/agent-sdlc:status` and the tracker show)

| Measure | Definition |
|---|---|
| epics delivered | linked epics `done` / linked epics; a `deployed` one is shown as awaiting main regression |
| items done | the items (stories, bugs, content tasks) of the linked epics plus the linked stories: `done` / all — in the fast lane `done` = merged into the feature, not yet on `main` |
| in flight | those items in a working status (sdlc-state section 1), and each linked epic's `batch.stage` |
| blocked | parked items (sdlc-state section 4), a red gate run (`batch.stage` = `fix_loop`), a `frozen` linked epic, a linked epic whose `delivers_after` names a not-`done` epic outside the milestone |
| drift | live item total − `planned_count.items` (`no plan` when `null`); bugs registered since planning show here |

The command reads the archive, so it is for `/agent-sdlc:status` and the tracker; during orchestration the PM uses only section 5's count (read discipline, sdlc-state section 2). It prints one JSON object and runs in bash and zsh:

```bash
{ cat docs/state/epics.json docs/state/active.json docs/state/backlog.json
  find docs/state/archive -name 'done-*.json' -exec cat {} + 2>/dev/null; } | jq -s --arg ms '{MS-ID}' '
def budget($lane): if $lane == "fast" or .kind == "bug" then 1 else ({"light": 1, "critical": 3}[.tier // "standard"] // 2) end;
.[0] as $ix | $ix.milestones[$ms] as $m | $m.epics as $L
| (([.[1:][] | .epics // {} | to_entries[]] | from_entries) + $ix.epics) as $E
| [.[1:][] | (.stories // {}), (.content_tasks // {}) | to_entries[] | .value + {id: .key}] | unique_by(.id)
| map(select(.epic as $e | .id as $i | any($L[]; . == $e) or any($m.stories[]; . == $i))) as $I
| { status: $m.status,
    epics_delivered: "\([$L[] | select($E[.].status == "done")] | length)/\($L | length)", awaiting_main_regression: [$L[] | select($E[.].status == "deployed")],
    items_done: "\([$I[] | select(.status == "done")] | length)/\($I | length)",
    drift: (if $m.planned_count then ($I | length) - $m.planned_count.items else "no plan" end),
    in_flight: ([$I[] | select(.status | IN("in_progress", "creating", "in_review", "in_qa", "integrating")) | "\(.id) \(.status)"]
      + [$L[] | select($E[.].batch.stage) | "\(.) batch \($E[.].batch.stage)"]),
    blocked: ([$I[] | select((.status | IN("review_rejected", "qa_rejected")) and (.returns // 0) >= budget($E[.epic].lane)) | "\(.id) parked"]
      + [$L[] | select($E[.].batch.stage == "fix_loop") | "\(.) red gate run \($E[.].batch.gate_run)"]
      + [$L[] | select($E[.].status == "frozen") | "\(.) frozen"]
      + [$L[] as $e | ($E[$e].delivers_after // [])[] as $d
         | select((any($L[]; . == $d) | not) and $E[$d].status != "done") | "\($e) waits for \($d)"]) }'
```

## 7. Demos after a delivery (an epic's `→ done`, a milestone's `→ delivered`) — `process.demo_gate` (absent → `blocking`; `--no-human` → as `off`)

| Value | PM does |
|---|---|
| `on_request` | decision line `demo offered on request ({MS-ID \| EPIC-ID})` on that ID; continue the loop at once — overnight too; when the user next speaks, offer it in one line before anything else: `Demo ready: {ID} — {title}. Say "prepare the demo" for a prepared environment.` Never cut a batch early, or reorder work, to reach a demo. |
| `blocking` | the demo gate in start.md after every delivery (the classic behaviour); the answer as the decision line `demo gate: {answer}` |
| `off` | no offer, no gate, no line |

**Demo preparation — only when the user asks:** dispatch **Developer — demo preparation** (`briefs/developer.md`) on the inherited session model (never a `process.models` downgrade — a demo is judgement work); log `dispatch: Developer (demo preparation)`, note `{ID} at {main sha}`. It prepares a runner slot (runners.md) or the local machine (`stack: "local"`, counted by the stack budget) at `main`'s tip; creates the demo data through the system's own paths (its UI, API or import — never direct database writes); writes a helper script and a runbook into `{parent of the repository}/{repository name}-demo-{ID}/`, OUTSIDE the repository, never committed; and reports OUTCOME `READY` (or `BLOCKED`) with the runbook path. Relay the runbook path and its first step to the user.

## 8. `process.planning_depth` (absent → `all`)

- `just_in_time` — only the next epic by `priority_order` is broken down (System Analyst) and designed (Architect, Designer) while the current one implements. Milestone planning is exactly section 3: the slice, the recut and the design pass the slice owes.
- `all` — every epic is broken down and designed before implementation starts (start.md planning phase).

## MUST NOT DO

- Write state from `/agent-sdlc:milestone` — it writes a directive; only `/agent-sdlc:start` writes state.
- Ask two questions in one message, or make a tool call in a question or gate message.
- Write one side of a link without the other in the same response, move a milestone out of `epics.json`, or re-parent an item that is not `todo`.
- Start a milestone whose recut check fails; cut a batch early or hold a dispatch to reach a demo; set `demoed` without the user's word.
