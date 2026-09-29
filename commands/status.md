---
name: "agent-sdlc:status"
description: "Display current SDLC project status"
---

Display the current SDLC project status. This is read-only — no agents are launched, and nothing under `docs/state/` is written (only the `/agent-sdlc:start` session writes state — sdlc-state section 1).

Every count below comes from the command shown next to it. A `grep -c` prints a count: read the printed number, never its exit status (it exits 1 when the count is 0) — `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`, shell rule 3.

**Steps:**

1. **Read project state:**
   Read `docs/state/project.json`. If it doesn't exist, output:
   > "SDLC not initialized. Run `/agent-sdlc:init` first."
   and stop.
   Keep: `name`, `prefix`, `max_parallel_teammates`, the lane for new epics (`process.lane`; absent block or key → `classic`), `process.max_local_stacks` (absent → `2`).

2. **Read state:**
   - Read `docs/state/epics.json` and `docs/state/active.json` fully.
   - Counts only, via Bash jq (do NOT Read these files):
     - backlog per status: `jq -r '[(.stories // {}), (.content_tasks // {}) | to_entries[].value.status] | group_by(.) | map("\(.[0]): \(length)") | join(", ")' docs/state/backlog.json`
     - backlog items per epic (for the not-started epics' `0/{total}`): `jq -r '[(.stories // {}), (.content_tasks // {}) | to_entries[].value.epic] | group_by(.) | map("\(.[0]) \(length)") | .[]' docs/state/backlog.json`
     - archived total: `find docs/state/archive -name 'done-*.json' -exec cat {} + 2>/dev/null | jq -s '[.[] | (.stories//{}|length)+(.content_tasks//{}|length)] | add // 0'`

3. **Determine project phase** (sdlc-state phase table):
   - `not_started` — no BRDs exist
   - `planning` — BRDs exist but epics are in `planning` status
   - `implementation` — at least one epic is `ready` or `in_progress`
   - `done` — `epics.json` has no epics left (all archived) and BRDs exist

4. **Milestones** — only when `milestone_order` in `epics.json` is non-empty (otherwise skip to step 5; the block is omitted).
   1. Read the progress command — the one source of how progress is computed:
      `sed -n '/^## 6\. Progress/,/^## 7\./p' ${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/milestones.md` (prints nothing → Read that file's section 6).
   2. Run it once per ID in `milestone_order`, in that order, with `{MS-ID}` replaced by the ID. Each run prints one JSON object: `status`, `epics_delivered`, `awaiting_main_regression`, `items_done`, `drift`, `in_flight`, `blocked`. Never count milestone items by hand from the files you read — archived items are reachable only through this command.
   3. Held epics and items (the progress command does not report `held`):
      - `jq -r '.epics | to_entries[] | select(.value.held) | "\(.key) \(.value.held)"' docs/state/epics.json` → `{EPIC-ID} {reason}` per line
      - `cat docs/state/active.json docs/state/backlog.json | jq -rs '.[] | (.stories // {}), (.content_tasks // {}) | to_entries[] | select(.value.held) | "\(.key) \(.value.epic) \(.value.held)"'` → `{ITEM-ID} {EPIC-ID} {reason}` per line
   4. Build each milestone's lines per **The Milestones block** below.

5. **Books and resources:**
   - Open notes per in-flight fast-lane epic (lane `fast`, status `in_progress` / `ready_for_deploy` / `deployed`) → `{EPIC-ID} {count}` per line:
     `jq -r '.epics | to_entries[] | select(.value.lane == "fast" and (.value.status | IN("in_progress","ready_for_deploy","deployed"))) | .key' docs/state/epics.json | while read -r e; do printf '%s %s\n' "$e" "$(cat "docs/reviews/$e-notes.md" 2>/dev/null | grep -c '^- \[ \] N-')"; done`
   - Open follow-ups per epic file → `{EPIC-ID} {count}` per line (both lanes; archived epics' carried entries included):
     `find docs/issues -mindepth 2 -maxdepth 2 -name followups.md 2>/dev/null | sort | while read -r f; do printf '%s %s\n' "$(basename "$(dirname "$f")" | sed -E 's/^([A-Za-z0-9]+-C?EPIC-[0-9]+).*/\1/')" "$(grep -c '^- \[ \]' "$f")"; done`
   - Open fix branches → `{branch} {n}` per line; `{n}` = how many of `main`, `feature/*`, `content/*` already contain the branch tip — `0` = open (its work has not reached a feature or `main`), anything else = already fast-forwarded, not shown:
     `git branch --list 'fix/*' --format='%(refname:short)' | while read -r b; do printf '%s %s\n' "$b" "$(git branch --list main 'feature/*' 'content/*' --contains "$b" | grep -c .)"; done`
   - Local stacks in use vs the budget → `{s}/{max}`: `jq -r '"\([(.worktrees // {})[] | select(.stack == "local")] | length)/\(.process.max_local_stacks // 2)"' docs/state/project.json`
   - Runner slots in use → `{holder} {stack}` per line: `jq -r '(.worktrees // {}) | to_entries[] | select(.value.stack != null and .value.stack != "local") | "\(.key) \(.value.stack)"' docs/state/project.json`
   - Held epics and items: step 4.3's two commands (run them here if step 4 was skipped).

6. **Count directives:**
   Count files in `docs/directives/active/`.

7. **Count active worktrees:**
   Count entries in `project.json.worktrees`.

8. **Format and output:**

   ```
   Project: {name} ({prefix})
   Phase: {phase}
   Lane for new epics: {fast | classic}

   Milestones:
     {PREFIX}-MS-{K} {title}  [{status}]  target {date | none}
       epics delivered {d}/{n} ({x} awaiting main regression) · items done {i}/{t} (slice planned {p})
       in flight: {EPIC-ID} {batch stage / gate run N}; {EPIC-ID} {k} in review, {m} in progress
       blocked: {ITEM-ID} parked (budget gate); {ID} held ({reason}); {EPIC-ID} frozen
     {PREFIX}-MS-{K} {title}  [planned]  epics {d}/{n} · items {i}/{t}
   Epics:
     {PREFIX}-EPIC-{N} {title}  [MS-{K}]  [{done}/{total} stories done]  [{status}]  [{lane}]  [{batch stage}]
     ...

   Active work:
     {PREFIX}-STORY-NNN {title}   [{status}]  [{tier} · {returns}/{budget}]    → {next action}
     {PREFIX}-BUG-NNN   {title}   [{status}]  [bug · {tier} · {returns}/1]     → {next action}
     ...

   Content:
     {PREFIX}-CTASK-NNN {title}   [{status}]    → {next action}
     ...

   Open notes: {EPIC-ID} {count}; {EPIC-ID} {count} | none
   Open follow-ups: {total} — {EPIC-ID} {count}; {EPIC-ID} {count} | none
   Fix branches (open): {branch}; {branch} | none
   Held: {ID} ({reason}); {ID} ({reason}) | none

   Backlog: {N} items across {M} not-started epics ({per-status counts})
   Archived: {N} done items

   Worktrees: {active}/{max_parallel_teammates} active · local stacks {s}/{max_local_stacks}{ · runner slots: {holder} {stack}, …}
   Directives: {count} pending
   ```

   - `Open notes`: every line of step 5's notes command, zero counts included (`none` when no fast-lane epic is in flight). `Open follow-ups`: only non-zero counts, `{total}` = their sum (`none` when the sum is 0). `Fix branches (open)`: only branches with `{n}` = 0. `Held`: step 4.3's epics then items. The runner-slots part appears only when that command printed something.

   **The Milestones block** — one entry per milestone in `milestone_order`; the whole block (header included) is omitted when there are no milestones. A milestone with status `planned` and an empty `in_flight` takes the one-line form `{PREFIX}-MS-{K} {title}  [planned]  epics {d}/{n} · items {i}/{t}` (`{n}` and `{t}` = the denominators of `epics_delivered` and `items_done`) instead of lines 1–3; its `blocked:` line (line 4) still follows when it has entries. Every other milestone takes the four lines:

   | Line of the template | Built from | Omit |
   |---|---|---|
   | 1 — ID, title, status, target | the entry in `epics.json` (`target` null → `none`) | never |
   | 2 — `epics delivered …` | `{d}/{n}` = `epics_delivered` (`{d}` counts `done` epics only); `{x}` = the number of IDs in `awaiting_main_regression`; `{i}/{t}` = `items_done`; `{p}` = `planned_count.items` from the entry | `({x} awaiting main regression)` when `{x}` is 0; `(slice planned {p})` when `planned_count` is null |
   | 3 — `in flight: …` | `in_flight` (rules below) | the line, when `in_flight` is empty |
   | 4 — `blocked: …` | `blocked` + the milestone's held entries (rules below) | the line, when both are empty |

   `in flight` — parts joined with `; `: walk the milestone's `epics` in order; for each, one part `{EPIC-ID} {batch stage label}` when `in_flight` has `{EPIC-ID} batch {stage}` (label table below), and/or the counts of that epic's `{ITEM-ID} {status}` entries (each item's `epic` from `active.json` — every item in a working status lives there), printed as `{k} in review, {q} in QA, {m} in progress, {c} creating, {g} integrating` — non-zero counts only, in that order, joined to the label with `, `. Then one part `{ITEM-ID} {status in words}` (the same words: `in review`, `in QA`, `in progress`, `creating`, `integrating`) for each entry whose item is listed in the milestone's `stories` (the uncut exception — its epic is not linked).

   `blocked` — parts joined with `; `, in this order: each `{ITEM-ID} parked` (an item whose entry carries `"parked": true` — sdlc-state section 4) → `{ITEM-ID} parked (budget gate)`; each held epic in the milestone's `epics` and each held item whose epic is in `epics` or which is in `stories` → `{ID} held ({reason})`; then the remaining entries exactly as printed (`{EPIC-ID} red gate run {N}`, `{EPIC-ID} frozen`, `{EPIC-ID} waits for {EPIC-ID}`).

   **Epic lines:**
   - `[MS-{K}]` — the epic's `milestone` without the `{PREFIX}-` prefix (`TST-MS-3` → `MS-3`); no `milestone` field → omit the bracket.
   - `[{done}/{total} stories done]` — counted in `active.json` for epics in `in_progress` / `ready_for_deploy` / `deployed` (every entry of the `stories` or `content_tasks` map whose `epic` is this epic, bugs included); `0/{total}` from the backlog per-epic count for `planning` / `ready` / `frozen` epics (bucket law, sdlc-state section 2).
   - `[{lane}]` — the epic's `lane` stamp; no stamp: `type: cepic` → `classic`; status `planning` / `ready` / `frozen` → `{lane for new epics} at start` (the stamp it will get — sdlc-state section 4, Lanes); any other status → `classic`.
   - `[{batch stage}]` — only when `batch.stage` is set. The label (used here and in the Milestones `in flight` line) is `{batch} {stage}`: `{batch}` = `batch` while `batch.n` is 1, `batch {n}` when `batch.n` ≥ 2; `{stage}` from this table (e.g. `batch gate run 2`, `batch 2 fix`):

   | `batch.stage` | `{stage}` |
   |---|---|
   | `triage` | `triage` |
   | `main_in` | `main-in` |
   | `batch_fix` | `fix` |
   | `gate` | `gate run {gate_run + 1}` |
   | `fix_loop` | `fix loop after red gate run {gate_run}` |
   | `books` | `books` |
   | `delivery` | `delivery` |

   **Active work:** `{tier}` / `{returns}` come from the entry (absent = `standard` / `0`); `{budget}` is the return budget of the item's lane and tier (sdlc-state section 4, Kinds, tiers, budgets): classic lane — light 1, standard 2, critical 3, bugs always 1; fast lane — 1 at every tier, every kind. The item's lane is its epic's (`lane` stamp; absent → classic). Two overrides beat every table below:
   - An item whose entry carries `"parked": true` is **parked** (sdlc-state section 4 — the flag, never a `returns` formula) — its next action is always "PARKED — budget exhausted; answer the budget gate in /agent-sdlc:start or drop an unpark directive".
   - An item with `held` — its next action is always "HELD — {held}; answer the gate in /agent-sdlc:start or drop an `unhold-{ITEM-ID}.md` directive".

   Where `{next action}` maps status to human-readable action:

   **Story statuses:**
   - `todo` → "waiting for Developer"
   - `in_progress` → "Developer working"
   - `ready_for_review` → "ready for Reviewer"
   - `in_review` → "Reviewer working"
   - `ready_for_qa` → "ready for QA" (light-tier story: "light tier — PM advances to merge without QA")
   - `in_qa` → "QA testing"
   - `review_rejected` → "rejected by Reviewer, back to Developer"
   - `qa_rejected` → "rejected by QA, back to Developer"
   - `ready_for_merge` → "ready for Deploy (merge to feature branch)"
   - `merged` → "merged to feature branch, awaiting regression QA"
   - `regression_failed` → "regression failed — a bug was registered for it (see Active work)"
   - `done` → "completed"

   **Fast-lane overrides** (the item's epic has `lane: fast`; `ready_for_qa`, `in_qa`, `qa_rejected`, `merged` and `regression_failed` never occur there):
   - `in_progress` with `returns` 1 → "Developer fix pass (the one return)"
   - `review_rejected` without `parked` → "rejected by Reviewer — one fix pass, checked by the PM's diff read"
   - `ready_for_merge` → "ready to merge into the feature (PM fast-forward, or Deploy real merge; a red merge goes to a merge-fix Developer)"

   **Bug statuses** (`kind: bug` — same statuses, fewer stages by tier and lane):
   - `todo` → "waiting for Developer (bug)" · `in_progress` → "Developer fixing"
   - `ready_for_review` → "ready for Reviewer (delta review)" · `in_review` → "Reviewer working"
   - `ready_for_qa` / `in_qa` → only critical-tier bugs of the classic lane reach QA; otherwise this status does not occur
   - `ready_for_merge` → "ready for Deploy (light bugs arrive here straight from the Developer)"

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
   - `planning` → "in planning" · `ready` → "ready to start" · `in_progress` → "stories in flight" (fast lane with `batch.stage` set → "batch end: {batch stage}")
   - `ready_for_deploy` → classic: "all items done, follow-ups handled — ready for Deploy (merge to main)"; fast: "batch gate green, books done — delivery to main"
   - `deployed` → "on main, awaiting the main-regression decision (`process.main_regression`)" · `frozen` → "frozen by directive" · `done` → "completed"

   Only show items in non-done statuses under "Active work" and "Content". Epic story counts come from `active.json` for in-flight epics and from the backlog per-epic counts for not-started ones.

9. **Verbose mode** (invoked as `/agent-sdlc:status verbose`): additionally show the last 20 transitions — `tail -20 docs/state/log.jsonl` via Bash, formatted one per line as `{at} {item} {from}→{to} ({trigger})`. This is the only routine reader of log.jsonl.

## MUST NOT DO

- Write anything under `docs/state/`, or run a git command that changes state (commit, checkout, merge, branch creation) — this command only reads.
- Read `docs/state/backlog.json`, `docs/state/archive/` or `docs/state/log.jsonl` with the Read tool — counts come from the jq commands above (verbose mode's `tail -20` is the one log read).
- Compute milestone progress by hand, or with your own formula — the milestones reference's section 6 command is the one source (the archive holds delivered items you never see).
- Read a `grep -c` exit status as a result — a count of 0 exits 1; the printed number is the result.
