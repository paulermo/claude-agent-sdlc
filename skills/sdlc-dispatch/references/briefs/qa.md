# Brief templates — QA

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as QA's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). Slots run in one order — `WHY` · `KIND / TIER / ROUND` (always with `LANE`; an epic-level brief puts `EPIC: {EPIC-ID}` beside it) · `WORKTREE` (path, SHA, what the tree has) · `CARRIED IN` · `INPUTS` · `SELECTION / CHECKS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters) are free text; every other value is a path, an ID, a SHA, a tier, a number, a command copied from `.claude/rules/quality-gate.md`, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["QA"]`, one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. `{worktree}`, `{app}`, `{db}` and the stack come from the `project.json` worktrees entry of the tree QA works in; `{kind}` / `{tier}` from the item's state entry (absent: `story` / `standard`); `LANE` = the epic's stamp (`jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`). `STACK` = `none` | `local — COMPOSE_PROJECT_NAME={name} APP_PORT={app} DB_PORT={db}` | `runner {NN} slot {x}, set to {sha}` — the value the worktree entry's `stack` gets at this dispatch (sdlc-dispatch section 2, stack budget). PM-only documents (`docs/reports/`, bug records) are read at their main-checkout path. `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| QA — batch gate (F7) | fast | batch end, stage `gate` (batch-end reference, step 4): a first run, a re-run after a fix loop, or a re-gate |
| QA — standard mode (classic lane) | classic | a story (standard / critical), a critical bug or a content task in `ready_for_qa` |
| QA — regression mode | classic (feature branch); both (on `main`) | classic: an item `merged` into its feature branch; both lanes: an epic `deployed`, when `process.main_regression` dispatches it — in the temporary detached worktree `{worktree_dir}/{EPIC-ID}-main-regression` you create at main's tip first |

---

## QA — batch gate (F7)

```text
Batch gate: the full gate for {EPIC-ID} batch {n} on {feature-branch} at {sha}, run {N} (`.claude/rules/quality-gate.md` §Batch end, step 2).

WHY: Every item of batch {n} is done ({ITEM-IDs}); main is merged in at {main-in sha}{, the batch fix is on top at {batch-fix sha}}. Nothing reaches main without the full gate.

KIND: batch gate · EPIC: {EPIC-ID} · LANE: fast · RUN: {N}
RE-RUN: {restart from the failed step {step} of run {N-1}; previous report: docs/reports/{EPIC-ID}-batch{n}-gate-run{N-1}.md | none — a first run or a re-gate: every step}
WORKTREE: {worktree_dir}/{EPIC-ID}-merge at {sha}, clean — not a story worktree; the main checkout stays on main. You write no code, no tests, no commits.
REPORTS: {reports} — your logs and the REPORT FILE go here, outside every worktree.
CARRIED IN: LESSONS: {defect classes seen in recent gates, e.g. "tests from main still calling a changed signature", "a flaky counter test" | none}.

INPUTS: `.claude/rules/quality-gate.md` (§How the full gate runs, Step 0, the path-to-command table, §Whole-tree checks, §Batch end); docs/templates/batch-gate-report-template.md; the precedent report: {docs/reports/{EPIC-ID}-batch{m}-gate-run{k}.md — an earlier PASSED run, of this epic or another | none}.
Do NOT read: story files, use cases, reviews, the notes file.

SELECTION / CHECKS:
- THE ROWS: `git diff --name-only origin/main...HEAD` holds {per-directory counts} → Step 0 + {the matching sections' rows}. Not applicable: {row — `{evidence command}` → `{output}` | none}. Confirm the rows yourself and state them.
- EXTRA, not a gate step: {a suite whose subject changed | none} — quote its exit code, labelled extra.
- LAYOUT: phase 1, no stack: {content guard | none}; {stackless rows | none}; the merge-artefact scan. Phase 2, with the stack: {precondition | none}, then {the remaining rows, in table order}.
- Pre-test cleanups: {each cleanup, confirmed by a listing or a count | none}. Spot-checks: {areas | none requested}.
STACK: {none — no selected row needs a stack | local — COMPOSE_PROJECT_NAME={epic-id-lower}-merge APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {sha} — leave the stack {up | down}}.

DISCIPLINE:
- Your workflow is the preloaded story-qa skill, Batch gate mode — one step at a time, each exit code on its own line, counts quoted; an engine-dependent test skipped after the stack is up is red.
- On a red step, fix nothing: stop and report FAILED with the failing command, its output lines and its reproduction. An infrastructure outage is BLOCKED, never FAILED; never a destructive reset.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

DELIVERABLE: the gate report in the batch-gate report template's format, written to the REPORT FILE. I save it as docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md — every run, PASSED or FAILED.

VERIFICATION: I will check the REPORT FILE is present and non-empty; its run is on {sha}; EVIDENCE: the `rows:` and `tree:` lines, then one line per step in order, each with its count or exit code ("not run" after a red step); runner steps read through `run-step wait`, naming the slot, when STACK names one.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: PASSED | FAILED | BLOCKED, REPORT FILE: {reports}/{EPIC-ID}-batch{n}-gate-run{N}.md, the whole message under {cap} characters.
```

## QA — standard mode (classic lane)

```text
Test {ITEM-ID}: {title}.

WHY: verify the item's acceptance criteria end-to-end before merge.

KIND: {kind} · TIER: {tier} · LANE: classic{ — normally not QA'd; dispatched because: {one clause} (a light story, a light or standard bug)}
PRIOR QA FEEDBACK: {re-test: read {feedback-file} — verify every item in it is fixed; re-test the delta and the flows it touches | none}
WORKTREE: {worktree}, head {head sha}.
REPORTS: {reports} — your logs go here, outside the worktree.

INPUTS: {story: {worktree}/docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md (acceptance criteria) + its use case (flows) | bug: the bug record {record path}}, .claude/rules/quality-gate.md, docs/state/environments.json if E2E against a deployed env is configured.

STACK: {local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} (from project.json worktrees) | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-qa skill, standard mode, depth by tier. You may write test files only — never application source. Defects outside this item's ACs go under ## Out-of-scope defects — never into the verdict, never as story proposals.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID}: Add e2e tests for {feature} [by QA]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: E2E tests per the tier's coverage law, committed; execution evidence.

VERIFICATION: I will check your test commits exist (attribution-trailer count 0), no `docs/state/` path in your diff, and EVIDENCE carries each command's actual result and one AC-coverage line per acceptance criterion.

REPORT: the envelope from your skill, OUTCOME: PASSED | FAILED | BLOCKED (an infrastructure outage), under {cap} characters. FAILED requires reproduction steps per failure in DETAILS.
```

## QA — regression mode

```text
Regression-test {ITEM-ID after its merge to {feature-branch} | EPIC-ID on main}.

WHY: prove the merge broke nothing before advancing.

KIND: {regression (story) · TIER: {tier} · LANE: classic | regression (epic, on main) · EPIC: {EPIC-ID} · LANE: {fast | classic}{ — dispatched per process.main_regression: {value}, {count} code paths{; override: {reason}}}}
WORKTREE: {story: the merge worktree {worktree_dir}/{EPIC-ID}-merge at {sha} | epic: {worktree_dir}/{EPIC-ID}-main-regression, detached at main's tip {main sha} — a temporary worktree I created; never the main working copy} — NOT a story worktree.
REPORTS: {reports} — your logs go here, outside every worktree.

INPUTS: .claude/rules/quality-gate.md (FULL suite commands), the merged item's acceptance criteria (spot-check list): {story file | bug record {record path}}; for an epic: every story file and bug record under docs/issues/{EPIC-ID}-{slug}/.

STACK: {none | local — COMPOSE_PROJECT_NAME={name} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {sha}}{; epic: bring the stack down when done}.

DISCIPLINE:
- Your workflow is the preloaded story-qa skill, regression mode. You write nothing except, optionally, a failing-test reproduction; never fix what you find.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

VERIFICATION: I will check EVIDENCE: every full-suite command with its counts and exit code, the spot-check outcomes, the merge-artifact scan; epic: `git -C {worktree} status --porcelain | wc -l` and the stack brought down; FILES: none, or the one reproduction. I remove the temporary worktree after verifying.

REPORT: the envelope from your skill, OUTCOME: PASSED | FAILED | BLOCKED (an infrastructure outage), under {cap} characters. EVIDENCE: full-suite results + spot-check outcomes + merge-artifact scan (<<<<<<< markers). A FAILED becomes a bug I register — DETAILS must carry the failing command and reproduction.
```
