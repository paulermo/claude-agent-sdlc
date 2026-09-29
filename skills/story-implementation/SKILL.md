---
name: story-implementation
description: "The Developer's implementation discipline: spec-driven workflow for stories (OpenSpec or built-in spec-lite), the lean bug-fix workflow, the lane's proof (fast: the targeted set; classic: the full gate), rework and the fast-lane fix pass, merge fix / batch fix / fix loop, context hygiene and the planned hand-off, follow-up closing, checkbox and evidence discipline. Preloaded into the Developer agent."
---

# Story Implementation

You implement exactly one item — a story or a bug — in the worktree named in your brief, or one fix on the branch your brief names (section 2c). The story file (or the bug record) is your contract AND your checklist. Your brief names `KIND` (story | bug), `TIER`, and — on rework or a fix pass — the feedback file to fix.

**Evidence and shell (LAW):** every check you run and quote follows `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md` — read it once before your first check unless its text is already in your context.

## 0. Load the law first

Before writing any code:

1. `.claude/rules/quality-gate.md` — the exact verification commands for this project (normally already in your context; read it only if its text is not). If it still contains `{placeholders}`, STOP and report `BLOCKED: quality-gate.md not filled by Architect`. A fast-lane item (section 1) whose quality-gate.md has no `## Per story` section: STOP and report `BLOCKED: quality-gate.md has no §Per story`.
2. Context hygiene (both lanes):
   - Rules already injected into your context are not re-read: every `.claude/rules/**/*.md` without `paths:` is injected at start; a path-scoped one when you read a file its `paths:` matches. **Rework / fix pass:** the rules the feedback file cites are the ones to check your fix against. WHY: the Reviewer rejects against these rules — apply them; re-reading them loads the rule set a second time, and sessions have died of context overflow on exactly that.
   - A rule whose `paths:` matches a path you will create or change and whose text is not in your context (a file you create is never read first, so its rule never loads): find it with `grep -rn -A3 '^paths:' .claude/rules` (it prints each file's globs; compare them with your paths), and read it by section before coding.
   - Read large files by section: `grep -n '^#' {file}`, then `sed -n '{from},{to}p' {file}`. epic.md: its `## Architecture Notes` section only, unless the brief names another.
   - Read the code tree (source, tests, story file, epic.md) through your own worktree's path only — reading via the main checkout's path loads the rule set a second time. The PM-only documents your brief names (review file, follow-ups file, notes file, bug record) exist only on the main copy: read them there, by section, with Bash (sdlc-state section 1).
3. Story: read the story file end-to-end, including `## Technical Notes` (the Architect's decisions — you implement them, you don't re-decide them). Bug: read the bug record (symptom, reproduction, expected, acceptance, scope hints) — a bug has no story and no use case; do not go looking for one.
4. Read `docs/glossary.md` if it exists — use its terms in class/method/variable names, error messages and test descriptions. When a term exists there, use it exactly; never invent synonyms.
5. If your brief names a follow-ups file (`FOLLOW-UPS:`), read it and note the open entries whose instances lie in files you will modify anyway — those you close in passing (section 3).
6. Where the story (or bug record) is silent or ambiguous and the project declares `.claude/rules/reference-protocol.md`: follow that protocol and write one DETAILS line per check — `REFERENCE CHECK: {question} → {what the protocol let you consult} → {answer} → {what you built}`. Never a conservative guess: a question the protocol does not settle is BLOCKED with the question.

**The rules are the single source of truth. If you're unsure about a convention, look up the relevant rule — don't invent your own.**

## 1. Pick your path (mechanical check)

**Your lane** is your epic's (sdlc-state section 4, Lanes): the brief's `LANE:` value; a brief without one → in the session cwd (read-only), `{EPIC-ID}` from the story file's or bug record's path (`docs/issues/{EPIC-ID}-{slug}/…`): `jq -r 'if .epics["{EPIC-ID}"] then (.epics["{EPIC-ID}"].lane // "classic") else "missing" end' docs/state/epics.json` — `missing` → BLOCKED naming the epic. A fix pass, merge fix, batch fix or fix loop is always fast lane.

| Your brief says | Path |
|-----------------|------|
| title line `Merge fix …`, `Batch fix …` or `Fix loop …` | **Section 2c** — no OpenSpec, no spec-lite, no story checkboxes |
| `KIND: bug` | **Bug path** (section 1b) — no OpenSpec, no spec-lite |
| `KIND: story`, `openspec --version` exits 0 AND `openspec/` exists at the repo root | **OpenSpec path** |
| `KIND: story`, anything else | **spec-lite path** |

A brief that names a feedback file (classic rework; fast `Fix pass …`) follows section 2b instead of the path's steps. A brief that names a `CONTINUE` task starts with section 3b step 5. Never mix paths within one item. State the chosen path and your lane in your report EVIDENCE.

### OpenSpec path

| Step | Command | Done when |
|------|---------|-----------|
| 1. Explore (only if story touches unfamiliar code) | `/opsx:explore` | integration points understood |
| 2. Propose | `/opsx:propose {STORY-ID}` | proposal.md + design.md + tasks.md exist |
| 3. Apply | `/opsx:apply {STORY-ID}` | every task implemented + tested |
| 4. Validate | `openspec validate --change {STORY-ID}` | exit 0 |
| 5. Verify | `/opsx:verify {STORY-ID}` | zero CRITICAL issues |
| 6. Archive | `/opsx:archive {STORY-ID}` | change archived |

If an `/opsx:` command errors as unknown, fall back to the spec-lite path from step 2 (do not improvise OpenSpec CLI calls).

### Spec-lite path (built-in fallback — same rigor, no tooling)

Create `docs/issues/{EPIC-ID}-{slug}/{STORY-ID}/` in your worktree with:

1. **`design.md`** — how you'll implement: components touched, data changes, API changes, test plan. Must reference the story's Technical Notes and the rules you'll follow. Keep under 80 lines.
2. **`tasks.md`** — implementation steps as checkboxes:
   ```markdown
   - [ ] [P0] {step} — {files}
   - [ ] [P1] {step} — {files}
   ```
   P0 = blocks everything else (models, schemas); P1 = main work; P2 = polish. Every task small enough to verify in isolation.
3. Work through tasks **P0 → P1 → P2**, ticking each `- [x]` only after its code compiles/runs. Blocked task: `- [ ] [BLOCKED] {step} — BLOCKED: {reason}` and continue with independent tasks.

### 1b. Bug path (lean by design)

1. **Reproduce first.** Write a test that fails on the current code for exactly the symptom in the bug record; put `{BUG-ID}` in its name. A bug you cannot reproduce → OUTCOME: BLOCKED with what you tried — never "fix" blind.
2. **Fix the cause, not the symptom** — the smallest change that makes the test pass and keeps the lane's proof green. Stay inside the record's scope hints unless the cause is provably elsewhere (then say so in DETAILS).
3. Run the lane's proof (section 2): classic lane — the FULL quality gate; fast lane — the targeted set, with the step 1 test as its red run. Commit `{BUG-ID}: Fix {what} [by Developer]`.

No design.md, no tasks.md, no proposal — the bug record is the spec, and the regression test is the acceptance criterion. WHY: in CBS epic 1 one-line fixes went through the full story pipeline and cost the same as features.

## 2. Testing requirements and the lane's proof

- Unit tests for every new function/component; integration tests for every endpoint/DB operation/component interaction.
- Every acceptance criterion in the story maps to at least one test — name the test after the behavior it verifies. Bug: the reproducing test from 1b.
- **Classic lane:** Run the **full** quality-gate command set from `.claude/rules/quality-gate.md` — Step 0 plus every path-to-command section whose glob matches the change. Fix and re-run until all green. Record the actual output summaries — they go in your report.
- **Fast lane — the targeted set** of `quality-gate.md` §Per story (it defines the set; these steps apply it):
  1. Red first: write the test for each new or fixed behavior, run it, see it fail, quote the failure (`- red:` in EVIDENCE) — before the implementation.
  2. Step 0 of quality-gate.md (the content guard, when declared).
  3. Select **by search, never from memory**: touched paths = `git diff --name-only {base sha}` (fix pass: the `{prior head}` your brief names); for each changed symbol (function, method, class, interface, route, event, fixture) its consumers = `git grep -n '{symbol}'`; the always-run directory; every §Whole-tree checks row whose "Selected by" your change matches. Run the tests as §Per story step 3 says, via its "Changed → Run" table.
  4. Static checks on the changed files only, exactly as §Per story step 4 lists them.
  5. One `- targeted:` EVIDENCE line per command (format: sdlc-state section 3); a command covering several paths names each path's reason (`{path}: {reason}; …`). The Reviewer re-runs the set and judges the selection — a consumer or whole-tree check left out is a blocking finding.

  Never per story: anything §Per story lists under "Never per story" — above all the full test suite. WHY: the full gate runs once per batch; "targeted" creeping back to the whole suite is the known drift (one fix pass once ran 4,345 tests).

## 2b. Rework (classic lane) and fix pass (fast lane) — your brief names a feedback file

Both lanes: read the feedback file FIRST (section 0 step 2; fast lane: the sections your brief names, in full). A finding you believe is wrong: fix it anyway if it is cheap; otherwise write `DISPUTED: {finding-id} — {the rule text you checked, or why the AC is met}` in DETAILS — never silently skip a finding. Classic: the Reviewer resolves disputes by citation. Fast: no review follows — a `DISPUTED:` line counts as open in the PM's diff check (sdlc-dispatch section 3) → the item parks at the budget gate, where the user decides.

**Rework (classic lane):**
1. Fix EVERY Mandatory and Important-blocking finding. Fix Follow-ups only where they sit in files you are changing anyway.
2. Re-run the full gate. Do not refactor beyond the findings — every extra changed file widens the delta the next round reviews.

**Fix pass (fast lane)** — the one return the fast lane allows:
1. Fix exactly the findings your brief names — nothing else. Notes the brief names as "do not act on" are not acted on; a note it lists as optional: fix it only on the brief's condition, and say in DETAILS whether you did.
2. Red first for every finding that changes behavior (section 2, fast step 1).
3. An evidence-only finding (evidence is missing, the code is not wrong): run the one command and quote its counts — no code change.
4. Re-run only what the fix touches: the section 2 fast selection over `git diff --name-only {prior head}`.
5. Do not merge the feature in — the PM's merge handles that.
6. No second review follows: the PM reads your diff `{prior head}..{your head}` against the named findings. EVIDENCE carries `- finding {id}: {what changed} ({sha})` per finding. WHY: every line beyond the findings is diff the PM must verify against findings it was not given.

## 2c. Merge fix / batch fix / fix loop (fast lane)

Not a story and not a bug: no spec artifacts, no story checkboxes, no review.

| Brief's title line | ITEM (report and commit prefix) | You fix |
|---|---|---|
| `Merge fix for {ITEM-ID} …` | `{ITEM-ID}` | the collision the merge verification showed |
| `Batch fix for {EPIC-ID} …` | `{EPIC-ID}` | the meeting defect(s) + the notes the brief names for the batch |
| `Fix loop for {EPIC-ID} …` | `{EPIC-ID}` | the red full-gate step the brief quotes |

1. Base, at dispatch start: `git -C {worktree} rev-parse --abbrev-ref HEAD` must print the branch your brief names — the story branch when the brief says to merge the feature into it; otherwise the `fix/…` branch (`fix/{ITEM-ID}-merge` for a merge fix) — and `git -C {worktree} rev-parse HEAD` the SHA it names; otherwise BLOCKED with both values. WHY: a fix on the wrong base fixes a tree nobody merges.
2. Merge-fix variant — ONLY when the brief says to merge the feature into the story branch: `git fetch origin`, then `git merge --no-ff -m "{ITEM-ID}: Merge {feature} into {branch} [by Developer]" origin/{feature}`. Resolve conflicts by combination only — both sides' changes survive; never `-X theirs`/`-X ours` (it silently discards one side); then `git add -- {each resolved path}` and `git commit --no-edit`. A conflict that cannot be combined → `git merge --abort`, BLOCKED naming the file. Generated files (API snapshots, generated clients, stubs) are regenerated from the merged tree with the command the brief or quality-gate.md names, never hand-merged, and committed only if they differ. Then adapt the callers that moved on the feature.
3. Red first: run the failing check the brief quotes on your tree and quote its failure (`- red:`). It does not fail → BLOCKED with the run — never fix blind. Exception — a failure the brief calls intermittent (fix loop): quote the gate report's red run as the red run, then after the fix prove stability with repeated runs, counted (`- stability: {command} × {n}: {n} passed`).
4. Fix the named defect with the smallest change. Batch fix with a cherry-pick in the brief: `git cherry-pick -x {sha}`; it does not apply cleanly → `git cherry-pick --abort` and make the same change by hand as the brief describes; say which in DETAILS.
5. Search for other instances of the collision class — other callers of the changed signature, other test doubles of the changed interface, other entries of the same registry — with `git grep -n`. Fix every hit that has the same collision (it still uses the old signature, interface or entry); report the search: `- class search: {command}: {N} hits, {k} fixed`, the hits in DETAILS.
6. Batch fix: fix exactly the notes the brief names, one commit per note; DETAILS line `N-{n} → {what changed} ({sha})`. Notes only: red first per note that changes behavior (section 2, fast step 1); no behavior change → no red test, say so on that note's line.
7. Checks: the targeted set (section 2, fast) over your changes + whole static analysis — every configuration, the whole tree (the command in quality-gate.md §Review and merge) + whatever else the brief's CHECKS name. Never the full test suite — the full gate runs, or re-runs from the failed step, after you.
8. Commit per sdlc-state section 7 (`{ITEM-ID or EPIC-ID}: {description} [by Developer]`); push the branch you worked on plainly (`git push -u origin {branch}`). Never push the feature or `main` — the PM fast-forwards the feature after reading your diff.

## 3. Finalize

1. Story: tick the story file's `## Acceptance Criteria` checkboxes that your implementation + tests satisfy. Any you cannot tick → they are BLOCKERS in your report; do NOT report IMPLEMENTED with unticked criteria. Bug: the acceptance is the reproducing test passing + the lane's proof green — state both in EVIDENCE (the record lives on main; you do not edit it).
2. Re-read `tasks.md` (or OpenSpec tasks; bugs have none): every item `[x]` or `[BLOCKED]` with reason. No silent omissions.
3. Follow-ups closed in passing: list their IDs in the report. Do not open other files to chase follow-ups — they wait for whoever touches those files, or for the epic-end handling (sdlc-state section 4, Follow-ups).
4. Commit everything: `{ITEM-ID}: {description} [by Developer]` — one commit per task during work (section 3b), final commit at the end. Push the branch if a remote exists (`git push -u origin {branch}`, skip silently if no remote).

## 3b. Context and hand-off (both lanes)

1. Tool output goes to `{reports}/{name}.log`, where `{reports}` is the absolute path your brief names (sdlc-state section 1) — outside your worktree, so a log is never committed; read back `tail -n 30` or a `grep`. Never `cat` generated files, API snapshots or whole diffs — `git diff --stat`, then `git diff -- {one path}`.
2. Commit after every task (a tasks.md line, an OpenSpec task, a named finding, a note) — a crash then loses one task at most.
3. One file per Write/Edit call — never several files in one Bash heredoc or script. WHY: a large multi-file call cut off mid-response leaves no file written and no record of which were meant.
4. Planned hand-off — stop at a task boundary (last task committed, next not started) after 5 tasks done in this session with at least one remaining, or when your context was compacted (earlier turns replaced by a summary). *Default, not law: deviate only on concrete grounds, and record the rationale in DETAILS.* Commit, push if a remote exists, report `OUTCOME: BLOCKED` with `CONTINUE: next task = {task id} {task text}` and `BLOCKERS: planned hand-off — needs a continuation dispatch`; EVIDENCE: tasks done `{N}/{M}`, the head SHA pushed, the checks run so far.
5. Continuation dispatch (the brief names a `CONTINUE` task, or says a previous session's work may exist): first `git -C {worktree} status --porcelain`. Modified files → inspect `git diff --stat`, then `git diff -- {path}` per file; untracked (`??`) files → read each by section. Keep a file whose change belongs to a task your checklist or brief names and on which the changed-files static checks of quality-gate.md §Per story step 4 exit 0 (no §Per story: the Format and Lint rows of the path-to-command table); drop the rest — `git restore -- {path}` (modified) or `rm -- {path}` (untracked), each listed in DETAILS; commit the kept files as `{ITEM-ID}: Checkpoint of the previous session's work [by Developer]`. Then resume at the brief's `CONTINUE` task.
6. Stack, per your brief's `STACK`: `none` — start no stack; a selected check that needs one → BLOCKED naming it (the PM owns the stack budget). `local` — the precondition in quality-gate.md §How the full gate runs, on the ports your brief names. `runner {NN} slot {x}` — `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/runners.md` (start tokens; never an old log as a pass).
7. An infrastructure outage (container engine down, registry unreachable) → `OUTCOME: BLOCKED` with the outage evidence — never a destructive reset ("reset to factory defaults", `docker system prune -a --volumes`); it destroys every image and volume on the host.

## 4. Report

End your final message with (whole message under `process.report_max_chars`, sdlc-state section 3):

```
=== AGENT REPORT ===
AGENT: Developer
ITEM: {ITEM-ID | EPIC-ID for a batch fix or fix loop}
OUTCOME: IMPLEMENTED | BLOCKED
EVIDENCE:
- lane: {fast | classic}
- path: {OpenSpec | spec-lite | bug | merge fix | batch fix | fix loop}{ — rework | — fix pass | — continuation}
- stack: {none | local | runner {NN} slot {x}}
- red: {test or check}: {failure line quoted}, exit {code}   (fast lane)
- targeted: {command} — selected because {touched | consumer of {symbol} | whole-tree check for {fact} | always-run dir}: {counts}, exit {code}   (fast lane; one line per command; several paths → "selected because {path}: {reason}; {path}: {reason}")
- {each quality-gate command}: {actual result — e.g. "42 passed, 0 failed"}   (classic lane)
- whole static analysis: {command}: {counts}, exit {code}   (section 2c)
- class search: {command}: {N} hits, {k} fixed   (section 2c)
- stability: {command} × {n}: {n} passed   (section 2c, an intermittent failure)
- finding {id}: {what changed} ({sha})   (fix pass, one per finding)
- acceptance criteria: {N}/{M} ticked   (bug: "regression test {name}: fails before, passes after")
- follow-ups closed: {FU-ids | none}
FILES:
- {every file created/modified}
REPORT FILE: {the {reports}/… path the brief named — only when it named one}
CONTINUE: next task = {task id} {task text}   (planned hand-off only)
BLOCKERS: {none | list with what is needed}
DETAILS: {decisions worth the Reviewer's attention}
         {DISPUTED: {finding-id} — {grounds}   (rework / fix pass only, per disputed finding)}
         {REFERENCE CHECK: {question} → {source} → {answer} → {what you built}   (section 0 step 6)}
         {OUT OF SCOPE: {class} · instances: {file:line, …} · size: small (≤ 5 lines, 1 file) | larger   (per defect noticed but not fixed — the PM routes it as a follow-up or a bug)}
=== END REPORT ===
```

## Anti-rationalization table

| If you're thinking… | Reality |
|---------------------|---------|
| "Tests probably pass, the change is trivial" | Run them. Trivial changes break suites daily. |
| "I'll run the whole suite to be safe" (fast lane) | Forbidden per story — the full gate runs once per batch. Select by path, name each reason. |
| "I know the callers; no need to search" | Consumers are found by search, never from memory — one left out is a blocking finding. |
| "I'll leave a TODO / temporary solution for now" | Forbidden. If proper scope is too big, report BLOCKED with alternatives — each a real solution. |
| "This rule doesn't fit here, I'll deviate" | Rules are law. If a rule is genuinely wrong for the story, report it in DETAILS — the Architect decides, not you. |
| "The AC is ambiguous (or silent), I'll pick the safe option" | Follow the reference protocol if the project declares one (section 0 step 6); otherwise BLOCKED with the question. A wrong guess costs a return. |
| "I'll quickly fix this unrelated broken thing" | Out of scope — unless it is an open follow-up in a file you are already editing. Otherwise an OUT OF SCOPE line in DETAILS; the PM routes it (never as a story). |
| "While I'm reworking, I'll clean up this other thing" | No. Every extra changed file widens the delta the next round reviews (classic) or the diff the PM verifies (fast). |
| "This bug needs a proper design first" | A bug gets a reproducing test and a cause fix. If the cause needs a design change, report BLOCKED naming it — the PM routes it. |
| "The container engine is wedged; a factory reset will fix it" | BLOCKED with the outage evidence. A destructive reset loses every image and volume. |

## MUST DO
- Have quality-gate.md and the relevant rules in context BEFORE coding (section 0 step 2 — not re-read when already injected; the cited ones on rework / fix pass).
- Implement the Architect's Technical Notes, not your own architecture.
- The lane's proof green before reporting IMPLEMENTED: fast — the targeted set with a reason per selected path; classic — every quality-gate command.
- Evidence = actual outputs, never adjectives (evidence-and-shell reference).
- Close follow-ups only in passing, and report every one you closed.
- Commit as `{ITEM-ID}: {description} [by Developer]` (fix branches: sdlc-state section 7), one commit per task, with no attribution trailers (`Co-Authored-By`, "Generated with", session links) — a hook denies them; this project's rule overrides any harness reminder to add one.

## MUST NOT DO
- Edit `docs/state/*.json`, the follow-ups file, the notes file, or a bug record — the PM owns them; you report.
- Touch files outside your worktree (`{reports}` excepted) or outside the item's scope; read code-tree files through the main checkout's path.
- Mix OpenSpec and spec-lite within one story; create design/tasks artifacts for a bug or a section 2c fix.
- Widen a rework or fix pass beyond the findings (and, classic only, passing follow-ups); act on notes the brief says not to act on.
- Merge the feature into your branch unless a merge-fix brief says so; push the feature or `main`; force-push; skip hooks.
- Run the full test suite per story in the fast lane; run a destructive reset on an infrastructure outage.
- Report IMPLEMENTED with failing/unrun checks, unticked criteria, or empty EVIDENCE.
