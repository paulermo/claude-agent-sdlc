# Fast lane and the EMI process changes (v2.0.0)

**Status:** approved 2026-09-29 (user: design sections 1–8 confirmed, "go")
**Source:** `docs/plans/2026-09-29-process-changes-handoff.md` — the hand-off spec C1–C29, written against 1.6.1 from
three weeks of one large project ("EMI": ~74 epics, ~900 stories, ~50 bugs). Cited below as *the spec*; its section
numbers (C1…C29, §4.x, §5.x, Q1…Q19, Appendix A–G, F1–F12) are stable references.
**Scope:** C1–C26 and C29. **Out:** C27 (stack leases — only C15's interim `max_local_stacks` ships) and C28 (tracker
backend / Jira), including C29's Jira mapping. Both stay open design problems (spec §5.1, §5.2).

## Why

1.6.x runs the full quality gate four times per story (Developer, Reviewer, QA, Deploy after every merge) plus a
regression per merge and per delivery. On EMI the full test step took 1 h 52 min on the loaded laptop; the user's token
and time budget could not afford it, nor "8 laps through the SDLC loop over imprecise spec prose". EMI replaced the chain
with a two-level proof — a *targeted set* per story, the *full gate* once per batch — plus the mechanics that grew around
it. This release makes those mechanics the plugin's defaults or configurable options.

## 1. Content layout (option B: law inline, procedures on demand)

Taken literally, the spec's §4 would double `start.md`, `briefs.md` and `sdlc-state` — all loaded into the PM's context
every session: the rules-budget trap C18 itself describes. So:

| Content | Lives in | Loaded |
|---|---|---|
| Law: lane table, status machines (story fast/classic, bug, epic, milestone), transitions, schemas, log vocabulary | `skills/sdlc-state/SKILL.md` | PM Step 0 |
| Loop, dispatch map (with a lane column), gates | `commands/start.md` | always (the command) |
| Epic-level procedures | `skills/sdlc-dispatch/references/{batch-end,cross-epic,rulings,milestones,recovery,runners}.md` | via a "Load when" table |
| Evidence and shell discipline (every agent) | `skills/sdlc-dispatch/references/evidence-and-shell.md` | cited by every agent skill |
| Brief templates | `skills/sdlc-dispatch/references/briefs/{planning,developer,reviewer,qa,deploy,content}.md` (split of the old `briefs.md`) | the role being dispatched only |

## 2. The lane

- `project.json.process.lane` (`fast | classic`) is the default for epics that start from now on.
- At `ready → in_progress` the PM stamps `"lane"` on the epic entry; the epic follows its stamp to `done`.
- Absent stamp, absent `process` block → `classic`. So existing projects never change behaviour mid-epic.
- Every lane-dependent rule lives in ONE lane table (`sdlc-state` §4); every other file cites it.
- Lane-implied mechanics (review rounds, per-story QA, per-merge regression, fix-pass verification) are **not** separate
  keys — they follow from the lane. (Deviation: the spec's §5.3 listed them as keys.)

| | `classic` (1.6.1) | `fast` |
|---|---|---|
| Developer / bug proof | full gate | targeted set (`quality-gate.md` §Per story) |
| Review rounds | by return budget | 1 |
| Return budget | tier 1 / 2 / 3 (bugs 1) | 1 at every tier |
| Rework verification | re-review (scope law) | PM reads the fix pass's diff against the named findings |
| QA per item | by tier | none |
| Regression after a story merge | yes | none; whole static analysis on real merges; changed whole-tree scanners re-run |
| Full gate | every merge | once per batch, after main-in |
| Merge failure | bug | `fix/{ID}-merge` + merge-fix Developer |
| Bug path | by tier (1.6.1 table) | light: Developer → merge; standard/critical: Developer → one review → merge |
| Epic → `main` | "Deploy flow" (epic merge in the main working copy) | batch end (§4 below) |

The tier still decides Reviewer lenses and whether an IMPORTANT blocks in round 1 (Q6).

## 3. State and schema (additive; `state_version` stays 2)

**`project.json`:** a `process` block; `integrations.runners: {enabled, tooling_dir, inventory}`; counters `note`,
`followup`, `milestone`; worktree entries gain `stack: null | "local" | "runner {NN} slot {x}"`.

Init writes one of two presets. Keys are independent at runtime (a project may mix):

| Key | fast preset (new projects) | classic preset (repair of an existing project) |
|---|---|---|
| `lane` | `fast` | `classic` |
| `main_regression` | `if_main_gained_code` | `always` |
| `docs_only_paths` | `["docs/", ".claude/"]` | same |
| `followups_gate` | `triage` | `hygiene_bug` |
| `demo_gate` | `on_request` | `blocking` |
| `planning_depth` | `just_in_time` | `all` |
| `deploy_push` | `on_green` | `never` |
| `deploy_exclusivity` | `per_target_branch` | `per_epic` |
| `max_local_stacks` | `2` | `2` |
| `report_max_chars` | `3500` | `3500` |
| `commit_attribution` | `false` (the hook enforces) | `false` — git hygiene is lane-independent; the repair summary says how to turn it off |
| `attribution_patterns` | `["co-authored-by", "generated with claude", "🤖", "claude-session"]` | same |
| `commit_conventions` | `null` | `null` |
| `shell` | from `$SHELL` (`zsh` / `bash`) | same |
| `models` | `{"default": "inherit"}` | same |
| `standing_brief_lines` | `{"all": []}` | same |
| `content_guard` | `null` | `null` |

**Absent keys read as the classic preset** — one rule for every reader.

**`epics.json`:** `milestones: {}` and `milestone_order: []` (C29 schema, spec C29 (d) point 1); epic entries gain
optional `lane`, `batch: {n, items, stage, gate_run, gated_sha}` (created at a batch cut or when the batch end starts;
`items: null` = the whole epic; `stage` ∈ `triage | main_in | batch_fix | gate | fix_loop | books | delivery`), `milestone`,
`continued_by`, `base_branch`, `carries: [{epic, sha}]`, `delivers_after: []`. An item gets its own `milestone` only in
the uncut exception. (Deviation: the spec's `batches[]` array became the single `batch` object — the PM needs the live
batch's members and `gated_sha`; history lives in the log.)

**Statuses:** none added. The fast story machine is a subset of the classic one; epic gains the edges
`deployed → done` by decision line and `deployed → in_progress` after a cut batch; milestone machine
`planned → in_progress → delivered → demoed`.

**PM-only documents (on `main`):** `docs/reviews/{EPIC-ID}-notes.md`; `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md`;
`docs/reports/demo-slice-{N}.md`; `docs/reports/milestone-{N}-recut.md`. Follow-ups stay per epic with project-wide
`FU-{n}` numbers.

**Log:** Appendix G's vocabulary in `sdlc-state` §7 (`dispatch: {Role} ({mode})`, `report: … ; PM verified the diff`,
`decision: user`, `recut`, `correction`, the fixed fast-lane notes); a line's `item` may be a milestone ID.

**Init repair** (no `process` key): add the classic preset and ask once whether to switch the default to `fast`;
`followup` counter = the highest `FU-n` across existing follow-ups files; `note: 0`, `milestone: 0`; empty
`milestones` / `milestone_order`; copy the new templates.

## 4. Story in the fast lane (C1–C5, C10)

- **Quality-gate seed** rewritten to the spec's §4.1 skeleton (Step 0, path-to-command table, whole-tree checks,
  §Per story, §Review and merge, §Batch end, Enforcement). The Architect fills §Per story and the whole-tree table in
  Design Mode; init still refuses placeholders. Classic uses the path-to-command table only.
- **Developer:** red first → targeted set with a reason per selected path in EVIDENCE
  (`targeted: {cmd} — selected because {reason}: {counts, exit}`) → static checks on changed files only; never the full
  suite. Bugs: the same, with a regression test named after the bug.
- **Reviewer:** one round; re-runs the targeted set once, independently; judges the selection (an omitted consumer or
  whole-tree check is MANDATORY); a NOTE never blocks; writes the review to `REPORT FILE`.
- **PM after the review:** saves `docs/reviews/{ID}-1.md`, NOTEs → notes file as `N-{n}` lines, follow-ups →
  `followups.md`. APPROVED → `ready_for_merge` (decision `QA skipped: fast lane`). REJECTED → `review_rejected`,
  `returns: 1` → fix pass (F2) by a fresh `developer-{ID}-fix` → the PM reads `git diff {prior head}..{head}` against the
  named findings only → closed: `ready_for_merge`; not closed: parked → budget gate (Q2a).
- **Merge:** story contains the feature tip → PM fast-forward (`merge --ff-only` in `{EPIC}-merge`, plain push if a remote
  exists, log line, story worktree removed, → `done`). Otherwise Deploy real merge (F4): combination only, generated
  files regenerated, whole static analysis on the merged tree + the story's modules + consumers + changed scanners.
  Green → push the feature, → `done` (decision `regression QA skipped: fast lane`). Red → merge pushed to
  `fix/{ID}-merge`, VERIFICATION_FAILED → merge-fix Developer (F10) → PM diff check → PM fast-forward → `done`.
  MERGE_FAILED → the merge-fix variant where the Developer merges the feature into the story branch. **Never a bug for
  a merge failure.** Exclusivity per `deploy_exclusivity`.

## 5. Batch end and delivery (C3 resolution, C6–C9, C26) — `references/batch-end.md`

Starts when every item of the batch is `done`; `epic.batch.stage` tracks the step
(`triage → main_in → batch_fix → gate ⇄ fix_loop → books → delivery`).

**Refinement made during implementation:** the notes and follow-ups work is split in two. **Triage** (stage `triage`,
before the main-in): the PM chooses which NOTEs and which small gate-breaking/correctness follow-ups the batch fix
takes, and registers a hygiene bug for larger ones (the batch waits for it) — so nothing found at triage lands after
the gate. **Books** (stage `books`, after the gate is green): every N-line gets its resolution, follow-up outcomes are
written, then the delivery. Step 6 below is the `books` stage.

1. **Main-in (F5)** in `{EPIC}-merge`: a CONFLICTED docs/rules file takes `main`'s side (main holds the final form of
   every ruling) and `docs/state` always equals `main`; non-conflicting feature docs and rules (story files, a new
   whole-tree-check row) are kept and ship; generated files regenerated, code combined, anything else → abort.
   (Correction during implementation: restoring all of `docs/` from `main` would have wiped the feature's own stories.) Green → push the feature;
   red → push to `fix/{EPIC}-main-in`, VERIFICATION_FAILED.
2. **Batch fix (F9)** on `fix/{EPIC}-batch`: meeting defects, notes chosen for the batch, cross-cutting obligations;
   PM diff check + fast-forward. Skipped when the main-in was green and no note was chosen (Default, decision line).
   Rule-gap notes go to an Architect ruling in parallel.
3. **Full gate (F7):** QA batch-gate mode (runner slot if enabled); every run's report saved as `docs/reports/{EPIC}-batch{n}-gate-run{N}.md`;
   `gated_sha`, `gate_run` recorded.
4. **Fix loop (F11)** on `fix/{EPIC}-gate-run{N}`: PM diff check + fast-forward, QA re-runs from the failed step. No bug,
   no review. **Addition (not in the spec):** after the 3rd red run, a user gate — "one more run" / "park the epic" —
   because every loop is bounded (the v1.6 round-economy principle); `--no-human` parks and narrates.
5. **Re-gate** when `main` gained code since the main-in (count excluding `docs_only_paths`): main-in + gate again;
   every run's report is `docs/reports/{EPIC}-batch{n}-gate-run{N}.md` (no separate `-regate` name).
6. **Notes and follow-ups:** every N-line gets one resolution (fixed in the batch / → FU / dropped with a reason /
   carried); the default per category comes from a Default signal table. Follow-ups per `followups_gate` (`triage`:
   carry by ID, move to the hardening epic, drop, or one small hygiene bug for gate-breaking items; `hygiene_bug`: 1.6.1).
7. **Delivery (F6):** epic → `ready_for_deploy`; Deploy in a temporary detached worktree from `origin/main`, one
   `--no-ff {gated_sha}`. **Deploy composes the commit message** from `templates/delivery-commit-template.md` using the
   gate report, the batch's items, the notes file and the diff — the brief carries paths, not the text (deviation: the
   spec's F6 put the filled message into the brief, which breaks the brief cap). Code equality with the gated SHA = 0;
   plain push; the PM holds only its own pushes to `main`.
8. **`deployed`** → `main_regression`: `always` → QA regression; `if_main_gained_code` → the C26 count test; `never` →
   skip. A decision line either way; the PM may dispatch QA anyway on a named reason. Then `done` + archive sweep, or —
   a cut batch with items left — back to `in_progress`, `batch.n + 1`.
9. Refinement unless a milestone plan is the live refinement; demo per `demo_gate`.

**Cut batch (C7):** a PM action — decision line naming the members and the reason; `batch.items = [...]`; items outside
are not dispatched until the delivery. **Classic** keeps the 1.6.1 "Deploy flow" text, reading `main_regression`,
`followups_gate` and `demo_gate` from `process` (the classic preset reproduces 1.6.1 exactly).

## 6. Cross-epic, rulings, milestones, planning (C11–C13, C23, C29)

- **Cross-epic (`references/cross-epic.md`):** `base_branch` for a feature cut from a feature; `carries` +
  `delivers_after` + decision `delivery order: X before Y` (batch-end step 7 refuses to deliver before the carried epic
  is `done`); Deploy feature-in mode (F5 variant) → parallel gates; cherry-picked meeting fixes (`-x`); carried notes.
- **Rulings (`references/rulings.md`; Ruling mode in `architecture-design`; F8):** triggers (BLOCKED on design, a note a
  later story builds on, pre-ruling, ordering); `.worktrees/ARCH-{topic}` on `architect/{ITEM}-{topic}` from `main`,
  docs/rules/ADRs only, report ≈ 1,200 characters; the PM merges `--no-ff` into `main`; the Developer cherry-picks the
  ruling commit only; new scope → the PM reserves an ID and a System Analyst cuts one story. `sdlc-dispatch` §3b
  `Rule gap:` row: "rule now if a later story builds on it; otherwise keep for Design Mode".
- **Milestones (`references/milestones.md`):** created in dialogue in `/start` (the PM asks name, goal/demo, target — one
  at a time) or via **`/agent-sdlc:milestone new|edit|list`** — `new`/`edit` run the same dialogue and write
  `docs/directives/active/{date}-milestone.md` (never state: single writer); `list` reads `epics.json`. Product Manager
  milestone mode (`brd-writing`) → slice document (`templates/demo-slice-template.md`), epics, recut data, `MILESTONE`
  block; System Analyst milestone-slice mode → prerequisite verdicts + final count (`planned_count`). The PM applies
  the recut (remainder = new epic, `continued_by`). Recut check before `planned → in_progress`. Transitions per the
  spec's C29 (d) point 2; `demoed` only on the user's word.
- **Views:** `/status` Milestones block above Epics (spec C29 (d) point 5); every epic line names its milestone and
  batch stage. Tracker: `#/milestones` view (card per milestone, two progress bars, its epic cards), milestone and
  batch-stage chips on roadmap cards, group-by-milestone. `server.py` adds only `milestone_progress` to `api_state`
  (uncut-exception items can sit in the archive, which the client never receives).
- **Planning (C13.5, C23):** `planning_depth: just_in_time` (break down and design only the next epic while the current
  one runs); System Analyst amendment pass after Design Mode changes stories; stackless dispatches while stacks are busy.

## 7. Shared discipline, both lanes (C18–C22, C25)

- **Evidence (C19):** `references/evidence-and-shell.md` — evidence = a counter, an exit code or a diff; a run that
  selected nothing is red; quote the last run that passed; only the gate's own targets are evidence; "not present yet"
  is red; the shell rules (zsh block when `process.shell: zsh`).
- **Attribution hook (C25):** `hooks/scripts/guard-commit.sh`, second `PreToolUse` hook on `Bash`, exactly per the spec's
  C25 (d): scope = walk up from `.cwd` / `-C` to `docs/state/project.json` (silent in this plugin repo); switch
  `commit_attribution`; patterns `attribution_patterns` (no `[by `, Q17); checks `git commit` in every form,
  `git merge -m`, `gh pr create|edit`, and the files named by `-F` / `--body-file`; optional prefix check from
  `commit_conventions`; deny reason says the project rule overrides the harness's commit template. Init writes the
  project's `.claude/settings.json` attribution settings (exact key verified against current Claude Code docs at
  implementation time). The PM's trailer check stays as the second line.
- **Git (C20):** the main checkout stays on `main`; state committed by path (`git commit -m … -- docs/state {files}`);
  planning roles work in `.worktrees/{ROLE}-{topic}` and the PM merges their branches; stray state commits per C20; the
  PM's permitted plumbing is a closed list: `merge --ff-only`, plain push, trailer amend on an unpushed agent commit,
  `--no-ff` merge of a planning or ruling branch into `main`, worktree removal (Q5).
- **Records (C21):** Reviewer and QA write documents to the `REPORT FILE` the brief names — `{worktree_dir}/.reports/`
  (git-ignored with the worktree dir; a PM scratchpad would be another session's private directory); the PM copies
  them into `docs/reviews/` and `docs/reports/` (Appendix A); `note` / `followup` counters.
- **Briefs and reports (C18, C22, Q3):** the brief cap becomes slots — WHY (≤ 2 sentences), KIND/TIER/ROUND, WORKTREE
  (base SHA + what the tree has), CARRIED IN (≤ ~600 characters), INPUTS, SELECTION/CHECKS, STACK, DISCIPLINE,
  DELIVERABLE, VERIFICATION, REPORT; only WHY and CARRIED IN are free text; `{standing lines}` from
  `process.standing_brief_lines` is exempt from the cap. Final message ≤ `report_max_chars`. Agents never re-read rules
  already in context, read large files by section through their own worktree path, send tool output to files, commit
  per task, one file per Write/Edit. `rule-authoring.md` gains a rules-budget section.

## 8. Resources, recovery, models, project guards (C14–C17, C24)

- **Stack budget (C15):** ≤ `max_local_stacks` agents hold a local stack (counted from worktree `stack: "local"`);
  stackless agents and runner slots don't count; stack-bound work queues and pairs with stackless work, narrated.
  `STACK: none | local | runner {NN} slot {x}` in briefs.
- **Runners (C14):** `references/runners.md` — the contract the project's tooling must satisfy (identical runners by
  fingerprint, no secrets, SHA-only slots, `start`/`wait` exit codes {own, 3, 124}, start tokens, `.pending` markers,
  `--expect` / `--allow-empty`, `runner-sync --pull`, sync-cache reset after a merge or cherry-pick, slot reset, known
  gaps, calibration). A reference `tooling/runners/run-step.sh` (start/wait, tokens, pending markers, 3/124,
  `--expect`, `--allow-empty`; transport via `RUNNER_SSH`, default `ssh`); tests use a local stub transport. QA
  batch-gate mode: a two-phase remote procedure.
- **Recovery (C16):** `references/recovery.md` — the ten-row situation table and the F12 messages; SendMessage resume
  ONLY for interrupted work (limit reset, dropped connection) and truncated-report tails — rework is always a fresh
  teammate (Q16); a thrashing teammate is replaced by a fresh one with a narrow brief; planned hand-off
  (`BLOCKED` + `CONTINUE: next task = …`); `start.md`: never a silent fallback to subagents.
- **Models (C17):** `process.models` = `{"default": "inherit"}` + optional per role/mode keys (`"Deploy": "sonnet"`,
  `"QA:batch_gate": "sonnet"`); the PM passes `model` to the Agent tool; a non-inherited model's report that fails the
  evidence check is re-dispatched once on the inherited model, logged. Judgement roles never below the top tier
  (Default). README: an explicit model may mean a smaller context window than the inherited session. (Deviation: the
  spec's default put Deploy and the QA gate on Sonnet — below the Opus 4.8 floor this plugin is authored for; Sonnet is
  opt-in, and Deploy/QA gate briefs are written to be Sonnet-executable.)
- **Project guards (C24, Q15):** `content_guard: {command, pre_commit}` → Step 0 of the gate when declared + a
  verification row; `pre_commit: true` → init installs a `.git/hooks/pre-commit` wrapper (opt-in). A
  `.claude/rules/reference-protocol.md` (if the project declares one) + a standing line; the Reviewer flags a decision
  made on a guess where the protocol was not consulted. Designer reference screens: a standing line. QA and Developer:
  "an infrastructure outage is BLOCKED, not FAILED; never run a destructive reset".

## Spec recommendations adopted as-is

Q2 (a) budget gate · Q3 slots · Q4 explicit exception to the presence check, worded "replaces a second review round;
not a fourth verification layer" · Q5 plumbing list · Q6 · Q7 project-wide counters · Q8 fix branches log-only · Q9 (see
§8) · Q10 / Q18 `docs_only_paths` shared, compared against the gated SHA, PM override as a decision line · Q11 · Q12
`on_request` · Q13 `per_target_branch` with `per_epic` kept · Q14 · Q15 · Q16 · Q17 (b), `[by {Role}]` kept · Q19:
`milestones` in `epics.json`, `{PREFIX}-MS-{n}`, closed milestones stay, no `frozen`/`dropped`, the uncut `stories`
exception allowed · Q1 (fast default for new projects; see §2 for existing ones).

**Recorded deviations from the spec's values:** Q17's default pattern is `generated with claude`, not `generated with`
(the bare phrase denied tool output such as "lockfile generated with npm"); Q10's `docs_only_paths` default drops
`docs/state/` (already covered by `docs/`); the spec's `batch_default` key is dropped (the batch is the epic unless the
PM cuts it — sdlc-state §4 Epic); "parked" became an explicit `parked` field (a formula could not tell an item owed its
last rework from an exhausted one — a 1.6 defect that a budget of 1 made universal); a red classic epic merge and a
failed main regression now have rows (one bug, epic back to `in_progress`) where 1.6 had none.

## Traceability (change → files)

| Change | Files |
|---|---|
| C1 targeted set | `templates/rules/quality-gate.md`; `story-implementation`; `story-review`; `agents/developer.md`, `agents/reviewer.md`; `briefs/developer.md`, `briefs/reviewer.md` |
| C2 one round, fix pass | `sdlc-state` §4/§5; `story-review` §4; `sdlc-dispatch` §3; `start.md` budget gate; `briefs/developer.md` (F2) |
| C3 notes file | `sdlc-state` §1/§4/§6; `sdlc-dispatch` §3b; `story-review` §5; `batch-end.md`; `templates/notes-file-template.md` |
| C4 fast machine, no per-story QA | `sdlc-state` §4/§5; `start.md` dispatch map; `story-qa`; `agents/qa.md`; README; `init.md` CLAUDE.md block; `session-start.sh` |
| C5 whole-tree checks | quality-gate seed; `story-review`; `story-merge` |
| C6 batch end | `batch-end.md`; `start.md`; `story-qa` batch-gate mode; `story-merge` main-in mode; `briefs/{deploy,qa,developer}.md` (F5, F7, F9, F11); `templates/batch-gate-report-template.md` |
| C7 batch cuts | `sdlc-state` epic schema/machine; `batch-end.md`; `start.md` |
| C8 follow-up triage | `sdlc-state` §4 Follow-ups/Epic; `batch-end.md`; `start.md` |
| C9 delivery | `story-merge` delivery mode; `briefs/deploy.md` (F6); `batch-end.md`; `templates/delivery-commit-template.md` |
| C10 merge mechanics | `story-merge`; `sdlc-dispatch` §2/§3b; `start.md` merge flow; `agents/deploy.md`; `briefs/{deploy,developer}.md` (F4, F10) |
| C11 cross-epic | `cross-epic.md`; `sdlc-state` epic fields; `story-merge` feature-in; `start.md` |
| C12 rulings | `rulings.md`; `architecture-design` Ruling mode; `agents/architect.md`; `briefs/planning.md` (F8); `sdlc-dispatch` §3b |
| C13 milestones (practice) | `milestones.md`; `brd-writing` recut mode; `story-breakdown` slice mode; `templates/demo-slice-template.md`; `start.md` demo gate |
| C14 runners | `runners.md`; `tooling/runners/run-step.sh`; `tests/runners/`; `story-qa`; `story-implementation`; briefs STACK slot; `init.md` |
| C15 stack budget | `sdlc-dispatch` §2; `sdlc-state` §6 worktree `stack`; briefs STACK slot |
| C16 recovery | `recovery.md`; `sdlc-dispatch` §4; `start.md` execution modes; `story-implementation` hand-off; `sdlc-state` §3 `CONTINUE:` |
| C17 models | `sdlc-dispatch` §1; `start.md`; README; `init.md` |
| C18 brief hygiene | `sdlc-dispatch` §1 slots; `sdlc-state` §3 `REPORT FILE:` + cap; `story-implementation` §0; `story-review` §1/§5; `story-qa`; `rule-authoring.md` |
| C19 evidence | `evidence-and-shell.md`; `sdlc-state` §3; every agent skill's evidence section |
| C20 PM git | `sdlc-state` §1/§7; `start.md` Git policy + planning dispatches; `agents/pm.md`; `sdlc-dispatch` §3 trailer row + MUST NOT |
| C21 records | `sdlc-state` §6/§7; `story-review` §5–6; `story-qa`; Appendix A in `sdlc-dispatch` §3b |
| C22 standing lines | `sdlc-dispatch` §1; every template's DISCIPLINE `{standing lines}`; `init.md` |
| C23 planning cadence | `start.md` planning phase; `story-breakdown` amendment pass |
| C24 project guards | quality-gate seed Step 0; `init.md` (`content_guard`, pre-commit wrapper); `story-review`; `story-qa`; `story-implementation`; `ui-design` (standing line) |
| C25 attribution hook | `hooks/scripts/guard-commit.sh`; `hooks/hooks.json`; `tests/hooks/`; `init.md`; `sdlc-dispatch` §3; briefs |
| C26 main regression | `sdlc-state` §4/§5; `batch-end.md`; `start.md` classic Deploy flow; `init.md` |
| C29 milestones (entity) | `sdlc-state` §2/§4–§7; `milestones.md`; `commands/milestone.md`; `start.md` Step 2; `status.md`; `tracker/server.py`, `tracker/static/app.js`, `style.css`; `brd-writing`; `init.md` |
| Version | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` → 2.0.0; README; `docs/extending-sdlc.md` |

## Testing

- `tests/hooks/guard-commit.test.sh` — fixture projects: `-m` with a trailer, a heredoc, `-F file`, `git -C path commit`,
  `merge -m`, `gh pr create --body-file`; a non-commit command; outside a project; a nested worktree;
  `commit_attribution: true` → no-op; the prefix check.
- `tests/runners/run-step.test.sh` — a local stub transport: the step's own exit code; empty log → 3; `--allow-empty`;
  `--expect` mismatch → 3; still running → 124; a failed start leaves `.pending` → `wait` 3; token mismatch → 3; an old
  `.done` is never read as this run's pass.
- Tracker — an isolated fixture (`AGENT_SDLC_TRACKER_BASE_PORT=4700`, a fake HOME) with milestones and a batch stage:
  `milestone_progress` in `/api/state`; the Milestones view and chips checked by screenshot.
- `tests/lint/check-content.sh` — every JSON block in skills/templates parses; every "Load when" path and every brief
  template referenced exists; no references to the removed `briefs.md`; the quality-gate seed has its 9 sections; hook
  scripts are executable; both manifests carry the same version.
- A cold-executor dry run: a fresh subagent gets the new `start.md` + skills + a fixture state and walks a scenario
  (story rejected → fix pass → PM diff check; red real merge → merge fix; batch end with a red run 1 → fix loop;
  delivery → `main_regression`; a milestone via the command) and reports every point where it had to guess.
- An independent code-review pass over the whole diff against the spec.
- Not testable here: a live pipeline run — the user's first real project on 2.0.

## Compatibility

Existing projects: no `process` block → classic preset, epics without a `lane` stamp → classic; `/agent-sdlc:init`
repair adds the block and asks about switching new epics to `fast`. No item migration (absent fields default).
Classic keeps every 1.6.1 behaviour except lane-independent hygiene: the attribution hook (on by default, one key to
turn off), evidence-and-shell, report files, brief slots, recovery. Version 2.0.0: the default lane of new projects
changes the pipeline's shape.
