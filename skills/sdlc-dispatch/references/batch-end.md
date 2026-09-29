# Batch end (fast lane)

A fast-lane batch proves itself once: `main` is merged into the feature, one batch fix, the full gate, one delivery merge to `main`. This procedure is LAW step by step; only the tables marked *Default* are defaults. The epic machine, the `batch` object and its stages, the transitions, the schemas and the fixed log notes live in `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-state/SKILL.md` (§4 Epic, §5, §6, §7) — cited here, never restated. **Classic lane:** the Deploy flow in `commands/start.md`.

**Legend.** `{EPIC-ID}` the epic · `{feature}` its `branch` · `{merge}` = `{worktree_dir}/{EPIC-ID}-merge` · `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout (sdlc-state §1) · `{n}` = `batch.n` · `{N}` a gate run number (`batch.gate_run` after its increment) · `{main}` = `origin/main` after `git fetch origin` when a remote exists (`git remote | grep -c .` prints ≥ 1), else `main` · `(remote only)` = skip the command without a remote · `{excludes}` = one `':(exclude){prefix}'` per `process.docs_only_paths` entry (fast preset: `':(exclude)docs/' ':(exclude).claude/'`) · "the next epic" = the first epic after this one in `priority_order`. Commands run from the main checkout unless `-C` names a worktree; counts are read as counts, exit codes on their own line (`references/evidence-and-shell.md`).

## Every stage change (LAW)

In ONE response: write `batch.stage` in `epics.json`, append the log line (trigger `batch end`, sdlc-state §7; `from` = `to` unless the epic status changes too), commit by path (sdlc-state §1), narrate.

```bash
echo '{"item":"{EPIC-ID}","from":"{epic status}","to":"{epic status}","by":"pm","at":"{ISO-8601 UTC}","trigger":"batch end","note":"batch end: {stage}"}' >> docs/state/log.jsonl
git add -- docs/state {documents this step wrote}
git commit -m "{PREFIX}: Update state — {EPIC-ID} {old stage}→{new stage} [by PM]" -- docs/state {documents this step wrote}
```

Every other decision line below: this shape with `"trigger":"decision"` and its fixed note, verbatim (sdlc-state §7). Dispatch line: `"trigger":"dispatch: {Role} ({mode})","note":"base {sha}, stack {local | runner {NN} slot {x} | none}"`; report line: `"trigger":"report: {Role} {OUTCOME}","note":"{head sha}, {counts}"`. Model per dispatch: sdlc-dispatch §1 with the model key each step names. Narration: start.md's batch-end line, `▷ {EPIC-ID} «{title}» batch {n}: {stage} — {what happens, one clause}`. After a session restart, an epic whose `batch.stage` is set — and that is not `held` (a held epic waits for its gate answer or a directive, sdlc-state §4) — re-enters that stage's step from its start; a dispatch whose report never arrived is re-dispatched (recovery reference).

## 0. Trigger — stage `null` → `triage`

Precondition: every item of the batch is `done` (`batch.items` `null` = every item of the epic in `active.json`; a list = its members). Open items — `0` means the batch is complete:

```bash
jq -n --arg e "{EPIC-ID}" --slurpfile ep docs/state/epics.json --slurpfile ac docs/state/active.json '$ep[0].epics[$e].batch.items as $ids | [$ac[0].stories | to_entries[] | select(.value.epic == $e) | select($ids == null or (.key | IN($ids[]))) | select(.value.status != "done")] | length'
```

`0` → sdlc-state §5 row "every batch item done": an epic without `batch` gets `{"n": 1, "items": null, "stage": "triage", "gate_run": 0, "red_runs": 0, "gated_sha": null}`, otherwise set `stage` = `triage`; step 1. A hygiene bug registered at triage is a batch item (for a cut batch, add its ID to `batch.items` when registering it) — the count stays non-zero until it is `done`.

## 1. Triage — stage `triage` (PM, no dispatch)

Decide what the batch fix carries before anything merges — so nothing found here lands after the gate.

1. **Notes** (first — the follow-up rules below depend on them). Open count: `cat docs/reviews/{EPIC-ID}-notes.md 2>/dev/null | grep -c '^- \[ \] N-'`. Give every open line its default from the table.
2. **Follow-ups.** Open count: `cat docs/issues/{EPIC-ID}-{slug}/followups.md 2>/dev/null | grep -c '^- \[ \]'`. A hygiene bug registered below → `batch.stage` = `null`; back to step 0.
   - `process.followups_gate` = `triage`: apply the triage table (sdlc-state §4, Follow-ups) to every open entry, acting now on two rows only — *gate-breaking or correctness, small* → the batch-fix list; *…, larger* → ONE hygiene bug (registration procedure in `commands/start.md`: title `hygiene: {EPIC-ID} follow-ups`, `origin: followups`, the record lists those FU lines). The other outcomes are written at step 6.
   - `hygiene_bug` (absent = `hygiene_bug`): first resolve `→ FU-{m}` now the notes whose default from 1 is a follow-up (step 6 formats; sdlc-state §4 Notes), so they count as open entries; then count > 0 → ONE hygiene bug for all open entries (sdlc-state §5).
3. The batch-fix list = the notes marked "batch fix" + the follow-ups from 2. Step 2 — its `batch end: main_in` line carries the extra key `"chosen":"{N-ids and FU-ids | none}"`; notes routed to the Architect → step 2b starts beside it.

| Category | At triage | Resolution written at step 6 |
|---|---|---|
| test · style · docblock · named arguments · contract · selection | the line names a file:line AND a concrete change → batch fix; else nothing | fixed → `→ fixed in the batch ({sha})`; not chosen, or chosen and not fixed → `→ FU-{m}` |
| prose | nothing | `dropped: {reason}` — unless it misleads a reader of the story, use case or spec: `→ FU-{m}`, owner `System Analyst` |
| prose ({role}) | nothing | `→ FU-{m}`, owner `{role}` (that role's next dispatch closes it) |
| rule gap (Architect) · rule text (Architect) | step 2b | ruled → `→ ruled ({ruling sha})`; the Architect's other outcomes as its skill's Notes-triage table says |
| performance (later) | nothing | `→ FU-{m}` |
| for the {EPIC-ID} merge | {EPIC-ID} = this epic (a note carried here) → batch fix, never carried again; another epic → nothing | this epic: as the first row; another epic → `→ carried to {EPIC-ID} as N-{k} (its next merge of main)` |
| Architect ruling before {ITEM-ID} | not yet ruled and {ITEM-ID} in this epic (dispatched or not) → a ruling now (`rulings.md`) | ruled → `→ ruled ({ruling sha})`; {ITEM-ID} in another epic, not ruled → `→ carried to {EPIC-ID} as N-{k} (before {ITEM-ID})` |
| planning (for {items}) | nothing | `→ FU-{m}`, owner = the epic holding {items}, else the next epic |

*Default, not law: deviate only on concrete grounds, and record the rationale on the note line.*

## 2. Main-in — stage `main_in`

Precondition: Deploy exclusivity for target `{feature}` (sdlc-dispatch §2).

1. Merge worktree — `git worktree list | grep -cF '/{EPIC-ID}-merge '` → `0` means missing: `git worktree add {merge} {feature}; echo "exit=$?"`. Whenever `jq -r '.worktrees["{EPIC-ID}-merge"] // "missing"' docs/state/project.json` prints `missing` — the directory new or not — register `"{EPIC-ID}-merge"` in `project.json.worktrees` (sdlc-state §6).
1b. Nothing to merge? `{main}` = `origin/main` (remote; `git -C {merge} fetch origin` first) or `main`: `git -C {merge} merge-base --is-ancestor {main} HEAD; echo "exit=$?"` → `exit=0` means `main` is already in the feature: no Deploy dispatch — decision `main-in skipped: main already in the feature`, `{main-in}` = `git -C {merge} rev-parse HEAD`, continue as the MERGED row. `exit=1` → step 2.
2. Dispatch Deploy — `briefs/deploy.md` "Deploy — main-in / feature-in (F5)", main-in; teammate `deploy-{EPIC-ID}`; model key `Deploy:main_in`; dispatch line `dispatch: Deploy (main in)`.
3. Verified report → report line with `{main-in}` = its `merge:` SHA (`merge: none — already up to date` → `git -C {merge} rev-parse HEAD`). No status change (sdlc-state §4 Epic):

| OUTCOME | Then |
|---|---|
| MERGED | the feature is at `{main-in}`; `push:` says not pushed and a remote exists → `git -C {merge} push origin {feature}; echo "exit=$?"`. Stage `batch_fix`, step 3 — or, when step 3's skip rule holds, its decision and stage `gate`, step 4 |
| VERIFICATION_FAILED | `{main-in}` is on the fix branch the report names (`fix/{EPIC-ID}-main-in`, or `…-{k}` when that name was taken — use the reported name, never the pattern), the feature untouched → stage `batch_fix`; step 3 branches from `{main-in}` and fixes the failures (never skipped) |
| MERGE_FAILED | stage stays `main_in`; epic `held: "main-in conflict"` (decision `held: {EPIC-ID} — main-in conflict`, sdlc-state §4 Held); surface the files that cannot be combined to the user as a design question and offer an Architect ruling (`rulings.md`) — `--no-human`: dispatch that ruling. After it merges: `held cleared: {EPIC-ID} — ruling {sha}`, and this step again with the ruling named in the brief's resolve list |
| BLOCKED — an outage, or `not started: {why}` (a dirty target, a mode/lane mismatch) | no transition; resolve the blocker (sdlc-dispatch §3), then re-dispatch |

| Situation | Action |
|---|---|
| A feature-in is due (`cross-epic.md` §2 — this epic carries another's feature) | after a MERGED main-in: run it now (cross-epic §2), still stage `main_in`; then `{main-in}` = the feature tip after it (`git -C {merge} rev-parse HEAD`) and go on as the MERGED row. After a VERIFICATION_FAILED main-in: run it after step 3's fast-forward, before step 4 — `batch.stage` stays `batch_fix` until the feature-in is MERGED (a restart in that window re-runs it, never skips it) |
| `worktree add` fails: `{feature}` is checked out elsewhere | `git worktree list` names the holder: a finished item's worktree → `git worktree remove {path}`; an agent at work → wait |
| Another merge into `{feature}` is in flight | queue it; decision `merge queued behind {ITEM-ID}'s` |
| The report has no `merge:` line | message the same Deploy for it (sdlc-dispatch §3) |

## 2b. Architect notes triage — beside steps 2–3 (optional)

When step 1 routed ≥ 1 note to the Architect: `git worktree add -b architect/{EPIC-ID}-notes {worktree_dir}/ARCH-{EPIC-ID}-notes main; echo "exit=$?"`; dispatch Architect — `briefs/planning.md` "Architect — batch-end notes triage" listing those N-ids, stackless, teammate `architect-{EPIC-ID}-notes`, dispatch line `dispatch: Architect (notes triage)`. On the verified report: check, merge, push, remove the worktree and delete the branch exactly as a ruling (`rulings.md`, PM steps 4–8; nothing ruled — `git rev-list --count main..architect/{EPIC-ID}-notes` prints `0` → step 7 only). Each note's outcome feeds step 6. Docs and rules only — step 5b counts nothing for it.

## 3. Batch fix — stage `batch_fix`

**Skip** when step 2 was MERGED and no id chosen at step 1 is left unfixed (on a re-gate pass none is): decision `batch fix skipped: main-in green, no note chosen`; stage `gate`; step 4. *Default, not law: deviate only on concrete grounds (e.g. a meeting fix another epic already made — `cross-epic.md`), and record the rationale in a decision line.*

1. `git worktree add -b fix/{EPIC-ID}-batch {worktree_dir}/{EPIC-ID}-batch-fix {main-in}; echo "exit=$?"`; register `"{EPIC-ID}-batch-fix"` (`stack` per the brief's STACK).
2. Dispatch Developer — `briefs/developer.md` "Developer — batch fix (F9)": PART 1 = the main-in's failures and any cherry-pick `cross-epic.md` names; PART 3 = the chosen N- and FU-ids. Teammate `developer-{EPIC-ID}-batch`; model key `Developer:batch_fix`; dispatch line `dispatch: Developer (batch fix)`. In the same response `batch.fix_attempts` + 1 (sdlc-state §4 Epic).
3. IMPLEMENTED → the diff read (sdlc-dispatch §3, the fast-lane exception — the named defects and notes only): `git rev-parse fix/{EPIC-ID}-batch` prints the reported head; then `git diff {main-in}..{head}`.
4. All closed → report line `report: Developer (batch fix); PM verified the diff` (note: `{main-in}..{head}`, each id → fixed, the counts); fast-forward the feature, remove the worktree and delete the merged fix branch — and the main-in's fix branch, when step 2 was VERIFICATION_FAILED — as below (`-d` from `{merge}`: its HEAD holds the branch; WHY: a leftover fix branch collides with the next red run); drop the worktree entry; stage `gate`; step 4.

```bash
git -C {merge} merge --ff-only fix/{EPIC-ID}-batch; echo "exit=$?"
git -C {merge} push origin {feature}; echo "exit=$?"          # (remote only) plain, never forced
git worktree remove {worktree_dir}/{EPIC-ID}-batch-fix; echo "exit=$?"
git -C {merge} branch -d fix/{EPIC-ID}-batch; echo "exit=$?"
git push origin --delete fix/{EPIC-ID}-batch; echo "exit=$?"  # (remote only; skip when never pushed)
git -C {merge} branch -d {main-in fix branch}; echo "exit=$?"     # only after a VERIFICATION_FAILED main-in: the name Deploy reported
git push origin --delete {main-in fix branch}; echo "exit=$?"     # (remote only; skip when never pushed)
```

| Situation | Action |
|---|---|
| A named id is `open`, or the Developer reports BLOCKED | `batch.fix_attempts` < 2: re-dispatch once (+ 1) — a fresh Developer on the same branch naming only the open ids (a design question: a ruling first, `rulings.md`). `batch.fix_attempts` ≥ 2: an open note → leave it (step 6: `→ FU-{m}`); a defect or BLOCKED → epic `held: "batch fix failed twice"` (decision `held: {EPIC-ID} — batch fix failed twice`, sdlc-state §4 Held), surface to the user |
| A push is refused | never force: `git -C {merge} fetch origin`, show what moved, surface to the user |

## 4. Full gate — stage `gate`

1. Stack: no selected gate section needs a stack (quality-gate.md's precondition is `none`) → `"none"`; otherwise `integrations.runners.enabled` is true and a slot is free (runners reference) → `"runner {NN} slot {x}"`; else room in the local budget (sdlc-dispatch §2) → `"local"`; else queue, narrate, dispatch stackless work meanwhile. Set it on the `{EPIC-ID}-merge` worktree entry.
2. `{head}` = `git -C {merge} rev-parse HEAD`. Dispatch QA — `briefs/qa.md` "QA — batch gate (F7)" at `{head}`, REPORT FILE `{reports}/{EPIC-ID}-batch{n}-gate-run{gate_run + 1}.md`; after a fix loop the brief names the failed step to re-run from. Teammate `qa-{EPIC-ID}-run{gate_run + 1}`; model key `QA:batch_gate`; dispatch line `dispatch: QA (full gate)`. A re-run's report states, for every step it did not re-run, the run and SHA that step passed on; the delivery's test plan quotes the steps exactly so — never as if every step ran on `gated_sha`.
3. Verify (sdlc-dispatch §3) plus: the report's run SHA equals `{head}` — a run on another SHA is not this run. Clear `stack`.
4. PASSED or FAILED → `gate_run` + 1 (= `{N}`); copy the report file to `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md` — every run, PASSED or FAILED (sdlc-state §6):

| OUTCOME | Then (sdlc-state §5, rows "QA (batch gate)") |
|---|---|
| PASSED | `gated_sha` = `{head}`; step 5b decides the next stage |
| FAILED | `red_runs` + 1; decision `gate run {N} red: {step}`; stage `fix_loop`; step 5a. **No bug** |
| BLOCKED (an infrastructure outage) | nothing saved; `gate_run` unchanged; stage stays `gate`; re-dispatch when it clears |

## 5a. Fix loop — stage `fix_loop`

Runs after a red run while `red_runs` < 3, and once per "one more run". `{run}` = the SHA run {N} ran on.

1. `git worktree add -b fix/{EPIC-ID}-gate-run{N} {worktree_dir}/{EPIC-ID}-gate-run{N} {run}; echo "exit=$?"`; register it.
2. Dispatch Developer — `briefs/developer.md` "Developer — fix loop (F11)" with the red step and `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md`; teammate `developer-{EPIC-ID}-run{N}`; model key `Developer:fix_loop`; dispatch line `dispatch: Developer (fix loop)`. In the same response `batch.fix_attempts` + 1 (sdlc-state §4 Epic).
3. IMPLEMENTED → the diff read against the red step's failure only; report line `report: Developer (fix loop); PM verified the diff`; fast-forward, push, remove the worktree and delete the branch as in step 3.4, with `fix/{EPIC-ID}-gate-run{N}`; stage `gate`; step 4, re-run from the failed step. No review, no bug (sdlc-state §5). An open id or BLOCKED: as step 3's Situation table.

**The bound (LAW).** A FAILED report that brings `red_runs` to 3 or more dispatches nothing. Present —

> ## Fix loop bound: {EPIC-ID} — {title} ({R} red gate runs)
> **Red runs:** run {N₁}: {red step} · run {N₂}: {red step} · … · run {N}: {red step}
> **Reports:** `docs/reports/{EPIC-ID}-batch{n}-gate-run{N₁}.md` · … · `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md`
> Options: "one more run" (one more fix-loop Developer and gate run; this gate returns if it is red) · "park" (the epic waits; nothing is dispatched for it until you answer or a directive says so)

**>>> GATE: user response required. Make NO tool calls in the same message as this question. <<<**
Acceptable answers: "one more run" / "run", "park". Anything else is feedback — treat it as a directive (start.md Step 2), apply it, re-present the FULL updated picture, and gate again. Record the answer: decision `fix loop bound: {one more run | parked}`. "park", or `--no-human` (silently, narrated): also epic `held: "fix loop bound"` (decision `held: {EPIC-ID} — fix loop bound`, sdlc-state §4 Held); `batch.stage` stays `fix_loop`, nothing is dispatched for it. A later "one more run" (the gate's answer or a directive) → `held cleared: {EPIC-ID} — one more run`, then steps 1–3 once. WHY: every loop is bounded — an unbounded fix loop is the same leak the return budget closed for items.

## 5b. Re-gate check — after every PASSED run (PM, no dispatch)

Did `main` gain code since the main-in? Count A — code paths `main` changed since the commit the main-in took:

```bash
git fetch origin                                                    # (remote only)
git merge-base {gated_sha} {main}; echo "exit=$?"                   # prints {base}
git diff --name-only {base} {main} -- . {excludes} > {reports}/{EPIC-ID}-regate.paths; echo "exit=$?"
wc -l < {reports}/{EPIC-ID}-regate.paths
```

Count A `0` → stage `books`; step 6. Count A > 0 → count B, the paths among them where `main` differs from the gated tree (both lists sorted by the same `sort`):

```bash
git diff --name-only {gated_sha} {main} -- . {excludes} > {reports}/{EPIC-ID}-regate.differ; echo "exit=$?"
comm -12 <(sort {reports}/{EPIC-ID}-regate.paths) <(sort {reports}/{EPIC-ID}-regate.differ) | wc -l
```

Count B `0` → `main` gained only code the feature already carries (a carried epic's delivery, `cross-epic.md`): decision `re-gate skipped: {A} code paths on main, all already on the feature`; stage `books`. Count B > 0 → stage `main_in`; step 2 again, then 3–4 (the re-gate's runs continue the `{N}` sequence). WHY: the gate must prove what will ship; documents, state and rules prove nothing the gate runs, and the delivery takes `main`'s side where they conflict (story-merge skill).

## 6. Books — stage `books` (PM, no dispatch)

Precondition: step 2b's Architect, if dispatched, has reported and its branch is merged.

1. **Notes** — every open N-line gets exactly ONE resolution (sdlc-state §4 Notes), from the step-1 table and the verified batch-fix report (its DETAILS name the commit per note):
   - `→ FU-{m}`: first append `- [ ] FU-{m} · {class} · instances: {file:line} · origin: {EPIC-ID} N-{n} · owner: {owner} · size: small` to followups.md (`m` = `counters.followup` + 1, written back to `project.json` per line; no owner in the table → omit `· owner:`);
   - carried: first append to `docs/reviews/{OTHER-EPIC-ID}-notes.md` (from `docs/templates/notes-file-template.md` if missing), under `## Carried from {EPIC-ID}`, the line `- [ ] N-{k} · {category} · {finding} (was {EPIC-ID} N-{n})` (`k` = `counters.note` + 1, written back per line);
   - then rewrite the line as `- [x] N-{n} · … · **{resolution}**`. Check: `cat docs/reviews/{EPIC-ID}-notes.md 2>/dev/null | grep -c '^- \[ \] N-'` → `0`.
2. **Follow-ups** per `process.followups_gate`: `triage` → write every open entry's outcome on its line (sdlc-state §4 triage table); one the batch fix closed → `- [x] FU-{n} · … — **closed by {EPIC-ID} batch fix ({sha}):** {how}`. `hygiene_bug` → the open count is `0`.
3. Epic → `ready_for_deploy`, stage `delivery` (sdlc-state §5, row "`batch.stage` = `books`"): one log line, trigger `batch end`, `from` `in_progress`, `to` `ready_for_deploy`, note `batch end: delivery`; commit by path — `docs/state` (with `project.json`'s counters) and every notes and follow-ups file written.

## 7. Delivery — stage `delivery`

1. Delivery order — prerequisite epics not yet `done` (absent from `epics.json` = archived = `done`): `jq --arg e "{EPIC-ID}" '. as $r | [($r.epics[$e].delivers_after // [])[] | select($r.epics[.] != null)] | length' docs/state/epics.json` → `0`; else wait, narrate "{EPIC-ID} is ready; its delivery waits for {IDs}", re-check whenever one goes `done`.
2. Deploy exclusivity for target `main` (sdlc-dispatch §2). Push `main` now (remote only); from this dispatch until Deploy reports the PM pushes nothing to `main` — it keeps committing state locally; a ruling or planning merge due meanwhile is merged locally and pushed after the report.
3. Dispatch Deploy — `briefs/deploy.md` "Deploy — delivery (F6)": `gated_sha`, `batch.n`, the batch's item IDs, the report of the run whose SHA is `gated_sha`, the notes file, followups.md — as paths; items left outside a cut batch → the brief says to keep `{merge}`. Deploy composes the message from `docs/templates/delivery-commit-template.md` in a temporary detached worktree from `{main}`. Teammate `deploy-{EPIC-ID}`; model key `Deploy:delivery`; dispatch line `dispatch: Deploy (delivery)`.
4. Verified report (`{delivered}` = its `merge:` SHA):

| OUTCOME | Then |
|---|---|
| MERGED, `push:` names `main` | `git pull --rebase origin main; echo "exit=$?"` in the main checkout (your state commits made during the delivery rebase onto the delivered `main`); step 7.5 |
| MERGED, `push: not pushed (deploy_push: never \| no remote)` | the merge is on local branch `delivery/{EPIC-ID}-{n}`: the fast-forward below; step 7.5 |
| MERGE_FAILED — code arrived on `main`, or a code conflict | epic → `in_progress`, `gated_sha` = `null`, stage `main_in` (sdlc-state §5); step 2 — re-merge, re-gate |
| BLOCKED — an outage, or `not started: {why}` | no transition; resolve the blocker (sdlc-dispatch §3), then re-dispatch |

   Fast-forward (main checkout, on `main`, your state commits made):
   1. `git rev-parse delivery/{EPIC-ID}-{n}` prints the reported merge SHA.
   2. `git merge --ff-only delivery/{EPIC-ID}-{n}; echo "exit=$?"`.
   3. `exit` ≠ 0 → you committed state after Deploy's base: `git rebase delivery/{EPIC-ID}-{n}; echo "exit=$?"` (replays only your own unpushed state commits — a delivery never changes `docs/state`), then `git merge-base --is-ancestor delivery/{EPIC-ID}-{n} HEAD; echo "exit=$?"` → `exit=0`. A rebase conflict → `git rebase --abort`, surface to the user.
   4. Remote exists → `git push origin main; echo "exit=$?"` (plain); `git ls-remote origin refs/heads/main` prints the SHA of `git rev-parse HEAD`.
   5. `git branch -d delivery/{EPIC-ID}-{n}; echo "exit=$?"`.
5. Report line with `{delivered}`; epic → `deployed` (sdlc-state §5 "Deploy MERGED (to main)"); commit state by path, push `main` (remote only) — the hold ends; step 8.

## 8. Main regression — epic `deployed`

1. Count: `git diff --name-only {gated_sha} {delivered} -- . {excludes} > {reports}/{EPIC-ID}-main.paths; echo "exit=$?"`, then `wc -l < {reports}/{EPIC-ID}-main.paths`.
2. `process.main_regression` (absent: `always`): `always` → dispatched · `if_main_gained_code` → count `0` skipped, ≥ 1 dispatched · `never` → skipped. Decision `main regression: {value}, {count} code paths — {dispatched | skipped}`; when a skip applies the PM may dispatch anyway, with `; override: {reason}` on the same line.
3. Dispatched: `git worktree add --detach {worktree_dir}/{EPIC-ID}-main-regression {delivered}; echo "exit=$?"`; register it, stack as step 4.1; QA — `briefs/qa.md` "QA — regression mode" on `main`; model key `QA:regression`; dispatch line `dispatch: QA (regression)`; after the verified report, `git worktree remove {worktree_dir}/{EPIC-ID}-main-regression; echo "exit=$?"` and drop its entry.
4. Items left outside a cut batch (`0` = none): `jq -n --arg e "{EPIC-ID}" --slurpfile ep docs/state/epics.json --slurpfile ac docs/state/active.json '$ep[0].epics[$e].batch.items as $ids | [$ac[0].stories | to_entries[] | select(.value.epic == $e) | select($ids != null and (.key | IN($ids[]) | not)) | select(.value.status != "done")] | length'`

| Result (sdlc-state §5, `deployed` rows) | Then |
|---|---|
| skipped or PASSED, items left > 0 | epic → `in_progress`; decision `batch {n} delivered: {item ids}; {k} items left`; reset `batch` (sdlc-state §4) |
| skipped or PASSED, items left `0` | epic → `done`; archive sweep (sdlc-state §2); cleanup below; steps 9–10 |
| FAILED | save `docs/reports/{EPIC-ID}-regression-{r}.md` (`{r}` = its round, from 1), its path on the epic's log line; epic → `in_progress`; ONE bug in the epic (origin = that report; start.md registration); `batch` becomes the bug alone, `n` + 1 (sdlc-state §5) — the bug's `done` starts the next batch end |

Cleanup at `done`: `git worktree list | grep -F '/{EPIC-ID}-'`; for each listed path, one command: `git worktree remove {path}; echo "exit=$?"`; then `git worktree list | grep -cF '/{EPIC-ID}-'` → `0` (verify by a listing — evidence-and-shell rule 6); drop the epic's `project.json.worktrees` entries; commit by path.

## 9. Milestone bookkeeping

An epic with a `milestone`, in the same response as its `→ done` (after the archive sweep): the milestones reference §5 — the count `{d}/{t}`, the decision line `{EPIC-ID} done: {d}/{t} epics delivered` on the milestone, or its `in_progress → delivered` (sdlc-state §5) when this was the last linked epic; narrate the count. A cut-batch delivery of an epic that holds a linked story: §5 steps 2–4 of that reference.

## 10. Refinement and demo — after `done`

1. Refinement: a milestone with a `slice_doc` is `planned` or `in_progress` → that plan is the live refinement: decision `refinement skipped: {MS-ID} plan is live`. Otherwise dispatch the Product Manager refinement (`briefs/planning.md`). What is planned next: `process.planning_depth` (milestones reference §8).
2. Demo per `process.demo_gate` — the milestones reference §7 (`on_request`: decision `demo offered on request ({MS-ID | EPIC-ID})`, continue, offer it when the user next speaks; `blocking`: the demo gate in `commands/start.md`; `off`: nothing; `--no-human`: as `off`).
3. Next: pick the next epic by `priority_order` and continue the implementation loop (start.md Step 3) — a fast-lane delivery ends here, exactly like the classic Deploy flow's step 5.

## Cut a batch (PM action)

*Default, not law: cut when a downstream epic needs this epic's first items (carried, or on `main`) before this epic can finish; deviate only on concrete grounds and record the rationale in the reason.* Never cut to reach a demo sooner.

1. Members: every item of the epic already `done` (the feature holds their code) + the in-flight items chosen to finish.
2. In one response: no `batch`, or `batch.stage` = `null` → `batch` = `{"n": {current n, or 1}, "items": [{ids}], "stage": null, "gate_run": 0, "red_runs": 0, "gated_sha": null}`; `batch.stage` set (its batch end is running) → set `batch.items` only, never reset `stage`, `gate_run`, `red_runs` or `gated_sha`. Decision `batch cut: {ids} — {reason}`; commit by path.
3. Items outside `batch.items` are not dispatched and not merged into the feature until the delivery; one already in flight finishes its dispatch and waits at its status. After the delivery, step 8: items left → epic `in_progress`, `batch` reset (sdlc-state §4, §5).

## Any step — Situation | Action

| Situation | Action |
|---|---|
| A command that must print a SHA or a count prints nothing, or exits non-zero | red: stop the step, show the output, fix the input (state entry, report) or surface it — never proceed on silence |
| `worktree add` fails: the path exists (a restart) | `git worktree list` first: the path is listed on the branch this step wants → reuse it; another branch, or not a worktree → surface to the user |
| `worktree add -b` fails: the fix branch exists | `git merge-base --is-ancestor {branch} {feature}; echo "exit=$?"`: `exit=1` (this dispatch's unmerged work, after a restart) → `git worktree add {path} {branch}`; `exit=0` (a merged leftover) → `git -C {merge} branch -d {branch}`, then `-b` again |
| A restart lost `{main-in}` | step 2 was MERGED → `git -C {merge} rev-parse HEAD`; VERIFICATION_FAILED → `git rev-parse fix/{EPIC-ID}-main-in` |

## MUST NOT DO

- Register a bug for a main-in failure or a red gate step — they are the batch fix and the fix loop.
- Review a batch fix or a fix loop, or judge anything in its diff beyond the named ids.
- Deliver any SHA but `gated_sha`, or before every `delivers_after` epic is `done`; push to `main` while a delivery Deploy works; push anything forced.
- Skip step 5b, or dispatch a fix loop past the bound without the gate's answer.
- Move an epic to `ready_for_deploy` with an open N-line, or give a line two resolutions.
