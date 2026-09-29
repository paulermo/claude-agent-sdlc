# Brief templates — Deploy

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as Deploy's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). The first line names the MODE (`Story merge (fast lane)`, `Main-in`, `Feature-in`, `Delivery`, `Story merge (classic lane)`, `Epic merge (classic lane)`); the story-merge skill refuses a brief with no mode, or with a mode of the other lane. Slots run in one order — `WHY` · `KIND / TIER / ROUND` (always with `LANE`; an epic-level brief puts `EPIC: {EPIC-ID}` beside it) · `WORKTREE` (path, SHAs, what the tree has) · `CARRIED IN` · `INPUTS` · `SELECTION / CHECKS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters) are free text; every other value is a path, an ID, a SHA, a tier, a number, a command copied from `.claude/rules/quality-gate.md`, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["Deploy"]`, one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. `{feature-branch}` = the epic's `branch`; `{feature sha}` = its tip now; `{kind}` / `{tier}` from the item's state entry (absent: `story` / `standard`); `LANE` = the epic's stamp (`jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`); `{deploy_push}` = `process.deploy_push` (absent: `never`). `STACK` = `none` | `local — COMPOSE_PROJECT_NAME={epic-id-lower}-merge APP_PORT={app} DB_PORT={db}` | `runner {NN} slot {x}, set to {sha}`, from the merge worktree's `project.json` entry (sdlc-dispatch section 2, stack budget). `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| Deploy — story merge (F4) | fast | an item in `ready_for_merge` whose branch does not contain the feature tip (a branch that does is fast-forwarded by the PM, never by Deploy) |
| Deploy — story merge (classic lane) | classic | an item in `ready_for_merge` |
| Deploy — main-in / feature-in (F5) | fast | batch end, stage `main_in` (batch-end reference, step 2); feature-in: another epic's feature must be in before both gates (cross-epic reference) |
| Deploy — delivery (F6) | fast | batch end, stage `delivery`: the epic `ready_for_deploy` with a `batch.gated_sha` (batch-end reference, step 7) |
| Deploy — epic merge to main (classic lane) | classic | an epic in `ready_for_deploy` |

---

## Deploy — story merge (F4)

```text
Story merge (fast lane): {ITEM-ID} ({kind}, {branch} at {item sha}) into {feature-branch} at {feature sha}.

WHY: {ITEM-ID} is reviewed{ and its fix pass verified} (docs/reviews/{ITEM-ID}-1.md); since its cut at {base sha} the feature gained {ITEM-IDs}, so this is a real merge, not a fast-forward.

KIND: {kind} · TIER: {tier} · LANE: fast
WORKTREE: {worktree_dir}/{EPIC-ID}-merge, on {feature-branch} at {feature sha}, clean. Work ONLY there; the main checkout stays on main.
REPORTS: {reports} — your logs go here, outside every worktree.
CARRIED IN: {the trial-merge result; what both sides touched that must be proven on the merged tree | none}.

INPUTS: `.claude/rules/quality-gate.md` §Review and merge, §Per story, §Whole-tree checks; docs/state/active.json (READ ONLY — branch names).

SELECTION / CHECKS — merge per your skill's fast-lane protocol, verify per its Step 4a:
- Generated files to regenerate: {file — generator command | none}.
- Combination checks: {registries and service definitions that must hold both sides' entries; migration order with the latest as head | none}.
- Tests: {the §Per story commands for the item's modules and the consumers of shared code both sides changed | none — your skill's default selection}.
- Whole static analysis: {the §Review and merge command}. Changed whole-tree scanners: {checks | none}. Replay: {command | none}. Content guard: {command | none}.
- Push per process.deploy_push = {deploy_push}. Red: the merge goes to fix/{ITEM-ID}-merge, or the next free `-{k}` (your skill's Red procedure), never to the feature; do not patch code.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-merge APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to the merge}.

DISCIPLINE:
- Your workflow is the preloaded story-merge skill, story merge mode (fast lane) — combination only, NEVER -X theirs/ours; generated files regenerated, never hand-merged.
- Never paste container names, compose project names or absolute paths into committed documents.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit the merge as `{PREFIX}: Merge {ITEM-ID} into {EPIC-ID} [by Deploy]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: the merge commit — on {feature-branch} when green, on fix/{ITEM-ID}-merge (or the next free `-{k}`) when red — and the report.

VERIFICATION: I will check the merge commit where your report puts it (`git ls-remote origin {ref}`; no remote: the local ref), its message, attribution-trailer count 0; EVIDENCE: the tree-identity line, ancestry both ways (each exit code on its own line), static-analysis lines, test counts, the marker count, the `stack:` line when STACK names a runner.

REPORT: the envelope from your skill, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED | BLOCKED, the whole message under {cap} characters. VERIFICATION_FAILED: DETAILS carries every failure grouped by cause and the fix branch at its SHA — the merge-fix Developer's brief is built from it.
```

## Deploy — story merge (classic lane)

```text
Story merge (classic lane): {ITEM-ID} ({kind}, branch {branch}) into {feature-branch}.

WHY: {QA passed | review passed (standard bug) | gate passed (light item)}; integrate before regression.

KIND: {kind} · TIER: {tier} · LANE: classic
WORKTREE: {worktree_dir}/{EPIC-ID}-merge (I created it on {feature-branch}, at {feature sha}). Work ONLY there.
REPORTS: {reports} — your logs go here, outside every worktree.

INPUTS: .claude/rules/quality-gate.md, docs/state/active.json (READ ONLY — for branch names).

SELECTION / CHECKS: the full quality gate after the merge — every section of the path-to-command table whose glob matches the merged diff.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-merge APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to the merge}.

DISCIPLINE:
- Your workflow is the preloaded story-merge skill — its conflict-resolution table is law (NEVER -X theirs/ours). If state files conflict, keep the {feature-branch} side.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID}: Merge to feature branch [by Deploy]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never force-push, never skip hooks. Do NOT push — I push after regression.
{standing lines}

VERIFICATION: I will check the merge commit exists on {feature-branch} (attribution-trailer count 0) and EVIDENCE carries each quality-gate command's result after the merge.

REPORT: the envelope from your skill, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED | BLOCKED (a dirty or moved target: `not started: {why}` in BLOCKERS — never MERGE_FAILED), under {cap} characters. EVIDENCE: quality-gate results after merge; conflicts resolved (files + strategy). A VERIFICATION_FAILED becomes a bug I register — DETAILS must carry the failing output.
```

## Deploy — main-in / feature-in (F5)

```text
{Main-in | Feature-in}: {origin/main | {OTHER-EPIC-ID}'s {other feature-branch} at {other sha}} into {feature-branch} at {feature sha}, for {EPIC-ID} batch {n} (`.claude/rules/quality-gate.md` §Batch end, step 1).

WHY: {Every item of batch {n} is done, and since {EPIC-ID} last took main, main gained {EPIC-IDs, ruling commits} — the full gate must prove what will ship, so main goes in first | {EPIC-ID} delivers after {OTHER-EPIC-ID}; its gate must prove the tree it ships once {OTHER-EPIC-ID} reaches main}.

KIND: {main-in | feature-in} · EPIC: {EPIC-ID} · LANE: fast
WORKTREE: {worktree_dir}/{EPIC-ID}-merge, on {feature-branch} at {feature sha}, clean. Work ONLY there; the main checkout stays on main.
REPORTS: {reports} — your logs go here, outside every worktree.
CARRIED IN: {the trial merge: {k} conflicts — file → what to combine; a ruling to respect in a combination | none}.

INPUTS: `.claude/rules/quality-gate.md` §Batch end, §Review and merge, §Per story, §Whole-tree checks.

SELECTION / CHECKS — merge per your skill's fast-lane protocol, verify per its Step 4b:
- Generated files to regenerate: {file — generator command | none}. Combination checks: {registries, service definitions, migration order | none}.
- Tests: {the §Per story commands over the modules both sides touched | none — your skill's default selection}.
- Whole static analysis: {the §Review and merge command}. Replay: {command | none}. Contract and drift rows: {commands | none}. Content guard: {command | none}.
- Push per process.deploy_push = {deploy_push}. Red: the merge goes to {fix/{EPIC-ID}-main-in | fix/{EPIC-ID}-{OTHER-EPIC-ID}-in}, or the next free `-{k}` (your skill's Red procedure), never to the feature; do not patch code.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-merge APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to the merge}.

DISCIPLINE:
- Your workflow is the preloaded story-merge skill, {main-in | feature-in} mode — combination only, NEVER -X theirs/ours; generated files regenerated, never hand-merged; docs/state always from main.
- Never paste container names, compose project names or absolute paths into committed documents.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit the merge as {`{PREFIX}: Merge main into {EPIC-ID} for the batch end [by Deploy]` | `{PREFIX}: Merge {OTHER-EPIC-ID} into {EPIC-ID} [by Deploy]`}. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: the merge commit — on {feature-branch} when green, on the fix branch when red — and the report.

VERIFICATION: I will check the merge commit where your report puts it (`git ls-remote origin {ref}`; no remote: the local ref), its message, attribution-trailer count 0; EVIDENCE: ancestry both ways, the `docs/state` diff count 0, the conflicted-docs lines, the marker count 0, static-analysis lines, test counts with failures by cause, the `stack:` line when STACK names a runner.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED | BLOCKED, the whole message under {cap} characters. VERIFICATION_FAILED: DETAILS carries the failures grouped by cause and the fix branch at its SHA — the batch-fix Developer's brief is built from it.
```

## Deploy — delivery (F6)

```text
Delivery: {feature-branch} at {gated sha} into main, for {EPIC-ID} batch {n}{ — milestone {MS-ID}}.

WHY: The batch's full gate passed run {N} on {gated sha}, with main merged in (docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md); since then main gained {only documents and state | nothing}.

KIND: delivery · EPIC: {EPIC-ID} · BATCH: {n} · LANE: fast
WORKTREE: none yet — create the temporary detached worktree {worktree_dir}/{EPIC-ID}-delivery from a fresh origin/main (your skill's Delivery, step 1); never the main checkout. I hold my own pushes to main while you work.
REPORTS: {reports} — the message file and your logs go here, outside every worktree.
- Keep {worktree_dir}/{EPIC-ID}-merge after MERGED: {yes — items of the epic remain for batch {n + 1} | no}.

INPUTS — the message sources; read them, never edit them, never add text they do not hold:
1. docs/templates/delivery-commit-template.md — the format, and how each part is filled
2. the gate report of the run whose SHA is {gated sha}: docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md — the test-plan numbers, copied, never re-measured
3. the batch's items: {ITEM-IDs} — their story files and bug records under docs/issues/{EPIC-ID}-{slug}/
4. docs/reviews/{EPIC-ID}-notes.md — the lines resolved "→ fixed in the batch" | none
5. docs/issues/{EPIC-ID}-{slug}/followups.md — the open FU IDs, IDs only | none
6. Milestone: {MS-ID | none}. Already on main: {ITEM-IDs delivered with another epic | none}.

SELECTION / CHECKS — your skill's Delivery steps 1–7:
- Compose the message from the template and write it to {reports}/{EPIC-ID}-delivery-message.txt (`grep -c '<!--'` → 0); merge {gated sha} with `-F` that file — the one SHA you may deliver.
- A conflict outside process.docs_only_paths and docs/state is code: `git merge --abort`, MERGE_FAILED.
- Verify per Step 4c — ancestry both ways, per-directory counts, code equality to {gated sha} (count 0); content guard: {command | none}.
- Push per process.deploy_push = {deploy_push}; a refused push follows your skill's refusal loop, never a force.
STACK: none.

DISCIPLINE:
- Your workflow is the preloaded story-merge skill, Delivery mode (fast lane).
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit with the message file, its first line in the template's format. A hook denies attribution trailers — it reads `-F` files too; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: one `--no-ff` merge of {gated sha} into main with the composed message, pushed per process.deploy_push; the temporary worktree removed.

VERIFICATION: I will check origin/main (or `delivery/{EPIC-ID}-{n}` when process.deploy_push is `never`) at your merge SHA; the message file present, its first line in the template's format, attribution-trailer count 0; EVIDENCE: the ancestry exit codes, the per-directory counts, the code-equality count 0, the removed worktrees.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: MERGED | MERGE_FAILED | BLOCKED, REPORT FILE: {reports}/{EPIC-ID}-delivery-message.txt, the whole message under {cap} characters.
```

## Deploy — epic merge to main (classic lane)

```text
Epic merge (classic lane): {feature-branch} into main for {EPIC-ID}.

WHY: every story and bug done, follow-ups handled per process.followups_gate; ship the epic.

KIND: epic merge · EPIC: {EPIC-ID} · LANE: classic
WORKTREE: the main working copy (I am pausing all other dispatches until you finish). Confirm `git status` is clean and branch is main before starting; if not, touch nothing: OUTCOME: BLOCKED with `not started: {the actual output}` in BLOCKERS — never MERGE_FAILED.
REPORTS: {reports} — your logs go here, outside every worktree.

INPUTS: .claude/rules/quality-gate.md, docs/state/active.json (READ ONLY — for branch names).

SELECTION / CHECKS: the full quality gate after the merge — every section of the path-to-command table whose glob matches the merged diff.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-main APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to the merge}.

DISCIPLINE:
- Your workflow is the preloaded story-merge skill, epic merge (classic lane) — its conflict-resolution table is law (NEVER -X theirs/ours). If state files conflict, keep main's side.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Deploy {EPIC-ID} ({title}) to main [by Deploy]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never force-push, never skip hooks. Do NOT push — I push after main regression passes.
{standing lines}

VERIFICATION: I will check the merge commit on main (attribution-trailer count 0) and EVIDENCE carries each quality-gate command's result after the merge.

REPORT: the envelope from your skill, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED | BLOCKED, under {cap} characters.
```
