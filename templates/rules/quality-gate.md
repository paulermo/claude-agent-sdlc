# Quality Gate

Proof comes at two levels. A **story** or bug proves itself with the **targeted set** (§Per story). A **batch** — the
items merged into one feature branch between two deliveries to `main`, by default one epic — proves itself once with
the **full gate** (§Batch end), on the feature branch after `main` has been merged into it. Nothing reaches `main`
without the full gate, and no story runs the full gate on its own.

> SEEDED PLACEHOLDER — the Architect MUST replace every `{placeholder}` with the project's exact commands during
> planning. Agents refuse to run while a `{placeholder}` remains. `<angle-bracket>` values are filled at run time by
> the agent (a branch name, a path) — they are not placeholders.

## Lanes

The lane of an item is its epic's (`skills/sdlc-state` section 4, Lanes). **Classic lane:** every change runs the
path-to-command table in full, and §Per story, §Review and merge and §Batch end do not apply. **Fast lane:** every
section applies. A project whose `process.lane` is `classic` and that has no fast-lane epics may delete §Whole-tree
checks, §Per story, §Review and merge and §Batch end instead of filling them.

## How the full gate runs

- `{precondition, e.g. make up — or "none"}` once; it is a precondition, not a step.
- Sequentially, one step at a time, never in parallel.
- Only the commands below count as gate evidence; anything else is a diagnostic.
- Evidence is a counter, an exit code or a diff — never silence. A run that selected or evaluated nothing is red.
- An exit code is read from the command itself, on the next line (the plugin's `evidence-and-shell.md` reference).
- A component "not present yet" is red, not a skip.
- After a fix, re-run from the step that failed — and re-run `{formatter}` and `{static analysis}` first if code
  changed after they passed.

## Step 0 — every change

| Check | Command | Green means |
|---|---|---|
| {content guard — only if `process.content_guard` is declared; otherwise delete this row and write "none"} | {command} | {exit 0 + its last line} |

## Path-to-command table (the full gate)

Run Step 0, then every section below whose glob matches `git diff --name-only main...<feature-branch>`, in order.

### `{glob, e.g. src/**}`

| # | Check | Command | Green means |
|---|---|---|---|
| 1 | Format | {exact command} | {e.g. exit 0, 0 files changed} |
| 2 | Lint | {exact command} | {exit 0} |
| 3 | Types / static analysis | {exact command, or "not applicable"} | {exit 0, 0 errors} |
| 4 | Tests | {exact command} | {counts, 0 failures, 0 skipped where a skip means "not run"} |
| 5 | {replay / build / drift — or delete the row} | {exact command} | {…} |

## Whole-tree checks

Checks that state what the whole tree must contain (a table a migration creates, a registration map, a route set). A
story can invalidate one by *adding a fact*, without touching the check or anything near it. The always-run directory
`{always-run test dir, e.g. tests/Architecture — or "none"}` needs no row; every whole-tree check outside it is listed
here and is selected by the fact it encodes:

| Check | What it encodes | Selected by a change that |
|---|---|---|
| {test path or command} | {the fact} | {adds / renames / removes …} |

The list is closed: a story that builds a new whole-tree check outside the always-run directory adds its row in the
same change. WHY: a story that added a table and a queue activity once left two whole-tree checks red on the feature
branch and on `main` until a later story's Developer stumbled on them.

## Per story: the targeted set

1. Red first: write the test for the new or fixed behavior, see it fail, quote the failure.
2. Step 0.
3. Targeted tests, never the whole suite, as one test-runner invocation covering: (a) the tests mirroring every touched
   source path; (b) the tests of every consumer of a changed symbol, **found by search, never from memory** (callers,
   wiring, routes, event consumers, shared fixtures and every test that uses them); (c) the always-run directory plus
   every whole-tree check the change adds a fact to; (d) {replay} when {workflow paths} changed.

   | Changed | Run |
   |---|---|
   | `{glob}` | {targeted command pattern, e.g. `{test runner} <paths>`} |

4. Static checks on the changed files only: {formatter in intersection mode, with its config}; {static analyser on the
   changed source and test files}; {type check project-wide with a forced rebuild where types cross files — or "none"}.
5. The report lists each command, the reason each path was selected, and its counts. The Reviewer judges the selection:
   a consumer or whole-tree check left out is a blocking finding.

Never per story: {full test command}, {whole-tree lint / type runs beyond step 4}, {client build / ci:check}, a QA
dispatch. A fix pass re-runs only what the fix touches. {Timing-sensitive test groups, e.g. concurrency — or "none"}
belong to the batch-end gate when the host is loaded.

## Review and merge (per story)

- One review round. Blocking findings get one fix pass; the fix pass re-runs what it touches; the PM verifies it by
  reading its diff against the findings. A story returns to the Developer at most once.
- NOTEs (Minor findings, and prose findings where the behavior is right) never return a story; they go to
  `docs/reviews/<EPIC-ID>-notes.md` and are resolved at the batch end.
- A reviewed story merges into the feature branch at once. A story→feature merge re-runs nothing, except: a real
  (non-fast-forward) merge runs {whole static analysis — every configuration, the whole tree} on the merged tree, and a
  story that changed a whole-tree scanner has Deploy re-run that scanner on the merged tree.

## Batch end: the full gate

1. Merge `main` into the feature branch first.
2. Run the full gate: Step 0, then every section whose glob matches `git diff --name-only main...<feature-branch>`.
3. Fix a red step on the feature branch (a fix loop, not a review-and-QA cycle); re-run from the failed step.
4. Resolve the notes file: each NOTE fixed in the batch, recorded as a follow-up, dropped with a reason, or carried.
5. One delivery merge to `main`, its commit message carrying: what changed (by behavior area, with IDs); the order of
   application; before merge / deploy; follow-ups by existing IDs; the test plan with real numbers.

## Enforcement

- **Developer:** fast — the targeted set before IMPLEMENTED; classic — the full table.
- **Reviewer:** fast — one round, re-runs the targeted set once, judges the selection; classic — re-runs the full table.
- **PM:** fast — verifies a fix pass by its diff, keeps the notes file, closes the batch.
- **QA:** fast — no per-story QA, runs the full gate at the batch end; classic — the full suite in regression.
- **Deploy:** fast — merges a reviewed story at once, re-runs changed whole-tree scanners on the merged tree, merges
  `main` in first at the batch end and delivers to `main` only after the full gate is green; classic — the full table
  after every merge.

<!-- Monorepos: give each component its own `### {glob}` section in the path-to-command table and its own rows in the
     §Per story "Changed → Run" table, so a change runs only the gates for what it touched. The batch-end full gate
     (and classic regression QA) always runs every section whose glob matches the batch's diff. -->
