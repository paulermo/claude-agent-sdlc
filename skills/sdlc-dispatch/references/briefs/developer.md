# Brief templates — Developer

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as the Developer's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). Slots run in one order — `WHY` · `KIND / TIER / ROUND` (always with `LANE`) · `WORKTREE` (path, branch, base SHA, what the tree has) · `CARRIED IN` · `INPUTS` · `SELECTION / CHECKS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters: facts from sibling items, reviews or reports this work must respect) are free text; every other value is a path, an ID, a SHA, a tier, a number, a command copied from `.claude/rules/quality-gate.md`, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["Developer"]`, one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. `{worktree}`, `{branch}`, `{app}`, `{db}` and the stack come from the item's `project.json` worktrees entry; `{kind}` / `{tier}` / `{returns}` from its state entry (absent: `story` / `standard` / `0`); `LANE` = the epic's stamp (`jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`). `STACK` = `none` | `local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db}` | `runner {NN} slot {x}, set to {sha}` — the value the worktree entry's `stack` gets at this dispatch (sdlc-dispatch section 2, stack budget). Paths prefixed `{worktree}/` are read through the agent's worktree; PM-only documents (reviews, the notes and follow-ups files, bug records, `docs/reports/`) and `docs/state/` are read at their main-checkout path. `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| Developer — story (first dispatch) (F1) | fast | a story in `todo`, or a lost session's story re-dispatched (recovery reference) |
| Developer — story (first dispatch) (classic lane) | classic | a story in `todo`, or a lost session's story re-dispatched |
| Developer — fix pass (F2) | fast | a story or bug in `review_rejected` with `returns` 1, not parked; teammate `developer-{ITEM-ID}-fix` |
| Developer — rework (after review_rejected / qa_rejected) (classic lane) | classic | `review_rejected` / `qa_rejected` within the return budget |
| Developer — bug | both | a bug in `todo` |
| Developer — merge fix (F10) | fast | Deploy reported VERIFICATION_FAILED or MERGE_FAILED on a story merge |
| Developer — batch fix (F9) | fast | batch end, stage `batch_fix` (batch-end reference, step 3) |
| Developer — fix loop (F11) | fast | a batch-gate run FAILED, stage `fix_loop` (batch-end reference, step 5a) |
| Developer — continuation | both | a Developer report with OUTCOME BLOCKED and a `CONTINUE:` line, or a Developer replaced for thrashing on its context (recovery reference, sections 5–6); teammate `developer-{ITEM-ID}-c{n}` |
| Developer — demo preparation | — | only when the user asks for a prepared demo (milestones reference, section 7); inherited model |

---

## Developer — story (first dispatch) (F1)

```text
Implement story {STORY-ID}: {title}.

WHY: {≤ 2 sentences: what it delivers, where it sits on the critical path, what it hands to which next item}.

KIND: story · TIER: {tier} · LANE: fast
WORKTREE: {worktree}, branch {branch}, cut from {feature-branch} at {base sha}. Work ONLY there.
- On the tree: {ITEM-IDs merged into the feature that this story builds on | none}.
- Not on the tree: {ITEM-IDs this story meets at the merge — read, never build: `git show origin/{their branch} -- {path}` | none}.
- Prior work: {a lost session's commits {a}..{b} and uncommitted {files} — inspect before you continue | none}.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the ruling line, when one applies: cherry-pick the ruling {sha} first — only that commit, never a full main merge: `git cherry-pick -x {sha}`} {facts from sibling items and reviews this story must respect — shared modules to meet, returned-for patterns | none}.

INPUTS (in order):
1. {worktree}/docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md — the story; your checklist lives here
2. the use case it references
3. {worktree}/docs/issues/{EPIC-ID}-{slug}/epic.md — `## Architecture Notes` only
4. {ADR paths | none}; {rule files, by section | none}
5. FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none} — close open entries whose instances are in files you modify anyway; never open other files for them
Do NOT read: other stories, other epics.

SELECTION / CHECKS: the targeted set of `.claude/rules/quality-gate.md` §Per story — red first; Step 0; ONE targeted run over (a) the tests mirroring touched paths, (b) the tests of every consumer of a changed symbol, found by search, (c) {always-run dir} + the whole-tree checks this story adds a fact to: {§Whole-tree checks rows | none known}, (d) {replay row | none}; then the static checks on changed files. Commands: {the §Per story "Changed → Run" commands for this story's paths}. Never: {the §Per story "Never per story" list}.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {base sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill — its path selection (OpenSpec vs spec-lite) and the fast lane's targeted set, exactly. Rules in .claude/rules/ are law.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Tool output to files under {reports}; read back `tail -n 30` or a grep. One file per Write/Edit call; commit after every task.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{STORY-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: implementation + tests, the targeted set green, story checkboxes ticked, committed and pushed (if a remote exists).

VERIFICATION: I will check your commits on origin/{branch} (`[by Developer]`, attribution-trailer count 0 over {base sha}..HEAD); no `docs/state/` path in your diff; EVIDENCE: the red run, then a count and an exit code for every targeted command with its `selected because` reason; checkboxes against reality; the `stack:` line (runner steps read through `run-step wait`, naming the slot).

REPORT: the envelope from your skill (sdlc-state section 3), OUTCOME: IMPLEMENTED | BLOCKED, the whole message under {cap} characters. DETAILS: one OUT OF SCOPE line per defect noticed but not fixed. After 5 tasks, or a compacted context: commit, push, OUTCOME: BLOCKED with `CONTINUE: next task = …` (skill section 3b).
```

## Developer — story (first dispatch) (classic lane)

```text
Implement story {STORY-ID}: {title}.

WHY: {one sentence: what this story delivers to the user}.

KIND: story · TIER: {tier} · LANE: classic
WORKTREE: {worktree}, branch {branch}, cut from {feature-branch} at {base sha}. Work ONLY there.
- Prior work: {a lost session's commits {a}..{b} and uncommitted {files} — inspect before you continue | none}.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the ruling line, when one applies: cherry-pick the ruling {sha} first — only that commit, never a full main merge: `git cherry-pick -x {sha}`} {facts from sibling items and reviews this story must respect | none}.

INPUTS (read in this order):
1. {worktree}/docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md — the story (your checklist lives here)
2. The use case it references
3. {worktree}/docs/issues/{EPIC-ID}-{slug}/epic.md — ## Architecture Notes
4. .claude/rules/quality-gate.md — the EXACT verification commands
5. FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none} — close open entries whose instances are in files you modify anyway; never open other files for them
Do NOT read: other stories, other epics.

SELECTION / CHECKS: the full quality gate — every section of the path-to-command table whose glob matches your diff.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {base sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill — follow its path selection (OpenSpec vs spec-lite) exactly. Rules in .claude/rules/ are law — load your domain's before coding.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{STORY-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: implementation + tests, all quality-gate commands green, story checkboxes ticked, committed and pushed if a remote exists.

VERIFICATION: I will check commits exist (attribution-trailer count 0 over {base sha}..HEAD), no `docs/state/` path in your diff, EVIDENCE contains actual test/lint output summaries, and story checkboxes match reality.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters. EVIDENCE must include each quality-gate command with its result; DETAILS carries an OUT OF SCOPE line per defect you noticed but did not fix. Planned hand-off: OUTCOME: BLOCKED with `CONTINUE: next task = …`.
```

## Developer — fix pass (F2)

```text
Fix pass for {ITEM-ID}: {title} — the one return the fast lane allows. No second review follows: I verify your diff against the named findings.

WHY: {one clause: the top blocking finding}.

KIND: {kind} · TIER: {tier} · LANE: fast · RETURNS: 1 of 1
WORKTREE: {worktree}, branch {branch}, PRIOR HEAD {head sha} (pushed). Work ONLY there. Do not merge the feature in — my merge handles that.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the ruling line, when a finding waits on one: cherry-pick the ruling {sha} first — only that commit, never a full main merge: `git cherry-pick -x {sha}` | none}.

INPUTS:
1. docs/reviews/{ITEM-ID}-1.md — findings {M1, I1, …}, read in full FIRST: they are your whole scope.
2. Optional: {N-{n} in docs/reviews/{EPIC-ID}-notes.md — fix it only if it falls out of the fix, and say whether you did | none}. Do NOT act on any other note.
3. The files the findings name; ONLY the rules the findings cite.
4. FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none} — close entries in files you change anyway.
Do NOT re-read: the use case, epic.md, the full rules tree, other stories — the findings are the reading list.

SELECTION / CHECKS: red first — a test per behavior-changing finding that fails before the fix (an evidence-only finding: run its one command, no code change). Then only what the fix touches — the §Per story selection over `git diff --name-only {head sha}`: {the §Per story "Changed → Run" commands for the files the findings name}. Quote each count and exit code.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, section 2b — fix pass: exactly the named findings, nothing else. A finding you believe is wrong gets a `DISPUTED:` line in DETAILS — it stays open in my diff check.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID}: {description} [by Developer]`, one commit per finding. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: every named finding fixed (or DISPUTED with grounds), the checks green, committed and pushed.

VERIFICATION: I read `git diff {head sha}..{your head}` against {M1, I1, …} only — each closed there, with its required test; your commits on origin/{branch}, attribution-trailer count 0; no `docs/state/` path; EVIDENCE: the red runs, each check's counts and exit code.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | BLOCKED, the whole message under {cap} characters. EVIDENCE: `- finding {id}: {what changed} ({sha})` per finding; the red runs; each check's counts and exit code. DETAILS: whether the optional note was fixed; DISPUTED lines.
```

## Developer — rework (after review_rejected / qa_rejected) (classic lane)

```text
Rework {ITEM-ID}: {title} — return {returns} of {budget}.

WHY: {one clause: the top blocking finding}.

KIND: {kind} · TIER: {tier} · LANE: classic
WORKTREE: {worktree}, branch {branch}, head {head sha}. Work ONLY there; your prior work is already committed here.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.

INPUTS:
1. FEEDBACK: {feedback-file} — read it FIRST; fix every Mandatory and Important-blocking finding; Follow-ups only in files you change anyway.
2. The files it names, .claude/rules/quality-gate.md, and ONLY the rules the findings cite.
3. FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none}
Do NOT re-read: the use case, the epic notes, the full rules tree, other stories — you followed them once; the findings are the reading list.

SELECTION / CHECKS: the full quality gate — every section of the path-to-command table whose glob matches your diff.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, section 2b (Rework): no refactoring beyond the findings; a finding you believe is wrong gets a DISPUTED line in DETAILS, never silence.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: every finding FIXED (or DISPUTED with grounds), full quality gate green, committed and pushed if a remote exists.

VERIFICATION: I will check new commits exist (attribution-trailer count 0 over {head sha}..HEAD), no `docs/state/` path in your diff, and EVIDENCE lists each quality-gate command's result and each finding's outcome.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters.
```

## Developer — bug

```text
Fix bug {BUG-ID}: {title}.

WHY: {one clause: what is broken and for whom}.

KIND: bug · TIER: {tier} · LANE: {fast | classic} · BUDGET: 1 return
WORKTREE: {worktree}, branch {branch}, cut from {feature-branch} at {base sha}. Work ONLY there.
- Prior work: {a lost session's commits {a}..{b} and uncommitted {files} — inspect before you continue | none}.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the ruling line, when one applies: cherry-pick the ruling {sha} first — only that commit, never a full main merge: `git cherry-pick -x {sha}` | none}.

INPUTS:
1. RECORD: {record path} — symptom, reproduction, expected, acceptance, scope hints. It is the whole specification: there is no story and no use case.
2. .claude/rules/quality-gate.md; the rules for the domains the scope hints name.
3. FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none} — close entries in files you modify anyway (a hygiene bug: the FU-ids its record lists).
Do NOT read: stories, use cases, epic notes, other bugs.

SELECTION / CHECKS — keep the line of LANE, delete the other:
- fast: the reproducing test is the red run; then the targeted set of §Per story for the files the fix touches: {the §Per story "Changed → Run" commands}; static checks on changed files. Never: {the §Per story "Never per story" list}.
- classic: the full quality gate — every section of the path-to-command table whose glob matches your diff.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {base sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, Bug path (section 1b): reproduce with a failing test named after {BUG-ID}, fix the cause, the lane's proof green. No design.md / tasks.md / OpenSpec.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{BUG-ID}: Fix {what} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: the reproducing test + the fix, the lane's proof green, committed and pushed if a remote exists.

VERIFICATION: I will check the test exists and names {BUG-ID}; EVIDENCE shows it failing before and passing after, and each command's result (fast: with its `selected because` reason); commits with attribution-trailer count 0 over {base sha}..HEAD; no `docs/state/` path in your diff.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | BLOCKED (cannot reproduce → BLOCKED with what you tried), under {cap} characters.
```

## Developer — merge fix (F10)

```text
Merge fix for {ITEM-ID} against {EPIC-ID}'s feature — not a story, not a bug: {make the red merge green | merge the feature into the story branch and adapt what moved}.

WHY: {what Deploy's merge showed — the collision, e.g. a caller left on a changed signature, a test double missing a new method}.

KIND: {kind} · TIER: {tier} · LANE: fast
WORKTREE: {{worktree_dir}/{ITEM-ID}-merge-fix, branch {fix branch} — exactly as Deploy's report names it (fix/{ITEM-ID}-merge or fix/{ITEM-ID}-merge-{k}) — at {resolved merge sha} | {worktree}, branch {branch} at {head sha} — merge `origin/{feature-branch}` at {feature sha} into it first}. Work ONLY there.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {Deploy's failures, grouped by cause: failing command → first message line; the files each side changed}.

INPUTS: {the failure log Deploy's DETAILS names under {reports}/ | none}; `.claude/rules/quality-gate.md` §Per story and §Review and merge; the files the failures name; the rules they touch, by section. Grep large files; never cat generated clients or API snapshots.
Do NOT read: stories, reviews, other epics.

SELECTION / CHECKS: red first — {the failing command from CARRIED IN} on your tree, quoted. Fix with the smallest change; search for other instances of the class (other callers of the changed signature, other doubles of the changed interface) and report the search. Then: the item's targeted set, unfiltered: {the §Per story commands}; whole static analysis: {the §Review and merge command}; {whole-tree checks | none}; {drift checks | none}; {content guard | none}. Summary lines and exit codes only.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to your base — clear the slot's sync cache after the merge}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, section 2c (merge fix). Merging the feature in: combination only, never `-X theirs` / `-X ours`; generated files regenerated with {generator command | the quality-gate.md command}, never hand-merged.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks. Push your branch only — never the feature: I fast-forward it after reading your diff.
{standing lines}

DELIVERABLE: the collision fixed on your branch, every instance of its class the search found fixed, the checks green, pushed.

VERIFICATION: I read `git diff {resolved merge sha | head sha}..{your head}` against the collision only; commits on origin/{your branch}, attribution-trailer count 0; no `docs/state/` path; EVIDENCE: the red run, the class search, each check's summary line and exit code.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters. EVIDENCE: the merge SHA and your head; conflicts and how each was resolved; adapted files; the class search; each check's summary line and exit code.
```

## Developer — batch fix (F9)

```text
Batch fix for {EPIC-ID} batch {n}, before its full gate — not a story: the meeting defects the main-in surfaced, {a merge decision to confirm | nothing else}, and the notes and follow-ups chosen for the batch.

WHY: Every item of batch {n} is merged and main is merged in at {main-in sha}; {the main-in verification was red on {causes} | the main-in was green}.

KIND: batch fix · EPIC: {EPIC-ID} · LANE: fast
WORKTREE: {worktree_dir}/{EPIC-ID}-batch-fix, branch fix/{EPIC-ID}-batch at {main-in sha} — your base; the feature stays at {feature sha} until you are green. Work ONLY there.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: PART 1 — {Deploy's failures by cause: failing command → first message line | none}; {another epic's fix for the same meeting defect: cherry-pick it first, `git cherry-pick -x {sha}`; if it does not apply cleanly, make the same change by hand: {what} | no cherry-pick}. PART 2 — {the merge decision to confirm | none}.

INPUTS:
1. PART 1 — {the failure log the main-in report's DETAILS names under {reports}/ | none}.
2. PART 3 — docs/reviews/{EPIC-ID}-notes.md, lines {N-ids} only; do NOT act on any other line.
3. Follow-ups chosen at triage: {FU-ids in docs/issues/{EPIC-ID}-{slug}/followups.md | none}.
4. `.claude/rules/quality-gate.md` §Per story and §Review and merge; the rules the defects and notes cite, by section.

SELECTION / CHECKS: red first — the PART 1 failures on your base, then each new test before its fix. Search the tree for other instances of each defect class. Then: whole static analysis {the §Review and merge command}; tests over the modules both sides touched and the whole-tree checks: {the §Per story commands}; {replay | none}; the formatter on touched files; {drift checks | none}; {content guard | none}. Never {the full test command} — the full gate follows.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-batch APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {main-in sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, section 2c (batch fix): one commit per defect, note or follow-up.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID}: {description} [by Developer]` (a cherry-pick keeps its message, with -x). A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks. Push your branch only — never the feature: I fast-forward it after reading your diff.
{standing lines}

DELIVERABLE: every PART 1 defect, named note and named follow-up fixed on fix/{EPIC-ID}-batch, the checks green, pushed.

VERIFICATION: I read `git diff {main-in sha}..{your head}` against PART 1–3 and the FU-ids only; commits attribution-trailer count 0; no `docs/state/`, notes or follow-ups path in the diff; EVIDENCE: the red runs, the class searches, the counts.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters. EVIDENCE: `follow-ups closed:` the FU-ids. DETAILS: one line per defect, note and FU — `N-{n} → {what changed} ({sha})`; OUT OF SCOPE lines.
```

## Developer — fix loop (F11)

```text
Fix loop for {EPIC-ID} batch {n}, full-gate run {N}: step {step} went red at {run sha} — not a story, not a bug, no review.

WHY: {the red step's command and its first failure line}.

KIND: fix loop · EPIC: {EPIC-ID} · BATCH: {n} · LANE: fast · RUN: {N}
WORKTREE: {worktree_dir}/{EPIC-ID}-gate-run{N}, branch fix/{EPIC-ID}-gate-run{N} from {run sha}. Work ONLY there.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the constraint on the fix, e.g. "make the test deterministic; prove it stable across repeated runs" | none}.

INPUTS: docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md — the failing step, its output lines, the reproduction; `.claude/rules/quality-gate.md` §Batch end; the rules the failure touches, by section.
Do NOT read: stories, reviews, the notes file.

SELECTION / CHECKS: red first — {the failing command, narrowed to the failing test(s)} on your tree, quoted. Search for other instances of the class. Then: {the failing test(s) and their area: the §Per story commands}; whole static analysis if code changed: {the §Review and merge command}. Never the full suite — QA re-runs the gate from the failed step.
STACK: {none | local — COMPOSE_PROJECT_NAME={epic-id-lower}-gate APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {run sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-implementation skill, section 2c (fix loop).
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks. Push your branch only — never the feature: I fast-forward it after reading your diff.
{standing lines}

DELIVERABLE: the red step's cause fixed on fix/{EPIC-ID}-gate-run{N}, with every instance of its class; the checks green; pushed.

VERIFICATION: I read `git diff {run sha}..{your head}` against the failure only; commits attribution-trailer count 0; no `docs/state/` path; EVIDENCE: the red run, the class search, the counts.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters: the commit, the red run, the counts.
```

## Developer — continuation

```text
Continue {ITEM-ID | EPIC-ID}: {title} — a continuation of the {story | fix pass | bug | merge fix | batch fix | fix loop} dispatch after {a planned hand-off | a session that ran out of context}.

WHY: {The previous session stopped at a task boundary and named the next task | The previous session was replaced: it ran out of context}; its commits on {branch} and the checklist hold its progress.

KIND: {kind | batch fix | fix loop} · TIER: {tier | none} · LANE: {fast | classic}
CONTINUE: {the previous report's CONTINUE line, verbatim | none — replaced session: the first open task of the checklist}
WORKTREE: {worktree}, branch {branch}, head {head sha}. Uncommitted edits left by the previous session: {files | none}. Work ONLY there.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {planned hand-off: the previous report's BLOCKERS / DETAILS lines this session must respect, or none | replaced session, verbatim: The previous session ran out of context; UNCOMMITTED edits exist in {files}: read `git diff` of those first; keep what is sound, revert what is not. Never cat large or generated files — grep and tail them.}

INPUTS: {the INPUTS slot of the original brief, copied — NARROW: only the files the remaining tasks need}.

SELECTION / CHECKS: {the SELECTION / CHECKS slot of the original brief, copied}.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- FIRST, before any new work (story-implementation section 3b, step 5): `git -C {worktree} status --porcelain`; inspect modified files (`git diff --stat`, then per file) and read each untracked (`??`) file by section; keep what belongs to a named task and passes the changed-files static checks of §Per story step 4 (no §Per story: the Format and Lint rows); drop the rest — `git restore -- {path}` (modified) or `rm -- {path}` (untracked), each listed in DETAILS; commit the kept files as `{ITEM-ID or EPIC-ID}: Checkpoint of the previous session's work [by Developer]` and push. Never `git reset --hard`, `git clean` or `git stash`.
- Then resume at the CONTINUE task; the rest of your workflow is the preloaded story-implementation skill, {the original dispatch's path or section}.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{ITEM-ID or EPIC-ID}: {description} [by Developer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: {the DELIVERABLE slot of the original brief, copied}.

VERIFICATION: {the VERIFICATION slot of the original brief, copied}; plus the checkpoint commit, or `tree clean`, in EVIDENCE.

REPORT: {the REPORT slot of the original brief, copied} — the whole message under {cap} characters. EVIDENCE adds `- checkpoint: {sha | tree clean}`.
```

## Developer — demo preparation

```text
Demo preparation for {MS-ID | EPIC-ID}: {title}, on main at {main sha} — not a story: you change no code and commit nothing.

WHY: The user asked for a prepared demo of {MS-ID | EPIC-ID}; the environment, the data and a runbook must let the user run it without help.

KIND: demo preparation · {MILESTONE: {MS-ID} | EPIC: {EPIC-ID}}
WORKTREE: {worktree_dir}/{MS-ID | EPIC-ID}-demo, detached at {main sha} (I created it). Read-only for code: no source edits, no commits.
REPORTS: {reports} — tool output, logs and report files go here, outside every worktree.
CARRIED IN: {the demo steps as the user stated them, when no slice document holds them | none}.

INPUTS: {docs/reports/demo-slice-{K}.md — `## The demo` and `## The demo's local configuration` | the epic's story files: {paths}}; `.claude/rules/quality-gate.md` §How the full gate runs (the stack precondition).
Do NOT read: reviews, the notes and follow-ups files; source beyond what a demo step needs.

SELECTION / CHECKS: each demo step run once, end to end, through the system's own paths (its UI, API or import) — never direct database writes; each step's observed result quoted.
STACK: {local — COMPOSE_PROJECT_NAME={id-lower}-demo APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {main sha}}.

DISCIPLINE:
- The preloaded story-implementation skill governs evidence, context and the stack (sections 0 and 3b); there is no spec path — this brief is the task list.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- The helper script(s) and the runbook go to {demo dir} = `{parent of the repository}/{repository name}-demo-{MS-ID | EPIC-ID}/` — OUTSIDE the repository, never committed.
{standing lines}

DELIVERABLE: the stack running at {main sha}; the demo data created through the system; {demo dir}/runbook.md (numbered steps, each with what the user sees) and the helper script(s).

VERIFICATION: EVIDENCE: the stack up (service count, exit 0), one line per demo step with its observed result, the runbook path; `git -C {worktree} status --porcelain | wc -l` → 0; the `stack:` line.

REPORT: the envelope from your skill (ITEM: {MS-ID | EPIC-ID}), OUTCOME: READY | BLOCKED, under {cap} characters. DETAILS: `demo READY — runbook: {demo dir}/runbook.md`, then the runbook's numbered steps, one line each.
```
