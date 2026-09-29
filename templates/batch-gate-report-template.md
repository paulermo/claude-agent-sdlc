# {EPIC-ID} batch {n} — full gate, batch-end report (runs 1..{N})

**Verdict: PASSED | FAILED on run {N}.** Run {N} is on `{sha}` (tree `{tree hash}`).
{One line per earlier run: where it went red, what fixed it (commit, files, whether anything under the source dirs
changed), which step the re-run started from.}

Branch `{feature-branch}`. Items in the batch: {IDs}; batch fix and run fixes on top.

## Row selection

{N} files in `git diff --name-only origin/main...HEAD`: {counts per top-level directory}.
Paths of rows NOT matched: {list} (count → `0`).
Rows run: {Step 0, …}. Not applicable: {row} — `{evidence command}` → `{output}`.
`origin/main` at `{sha}`; {is it an ancestor of HEAD; if not: `git diff --name-only {main-parent of the merge} origin/main -- {code dirs} | wc -l` → `0` (documents only)}.

## Sync check ({runner} slot {x})   <!-- runners only; delete the section otherwise -->

Slot HEAD `{sha}`, `HEAD^{tree}` `{hash}` on the slot and in the merge worktree; `git status --porcelain | wc -l` → `0`
on both. {Whether `up` was re-run, and why not if not.} Every runner step went through `run-step start` then `wait`;
each `wait` exit read on its own line.

## Steps — run {N} (tree `{sha}`)

| Step | Where | Exit | Evidence |
|---|---|---|---|
| {content guard} | {local \| runner} | 0 | `{its last line}` |
| merge-artefact scan | local | 0 | {count in scope; a control with a known hit, so the scan is shown live} |
| {up} | {local \| runner} | 0 | {healthy services count; one-shot jobs exited 0} |
| {format} | … | 0 | `{counter line}` |
| {static analysis} | … | 0 | `{per configuration: files, result}` |
| {pre-test cleanups} | … | 0 | {leftover containers 0; cache clear confirmed} |
| {tests} | … | 0 | `{tests} tests, {assertions} assertions`, {time}; skipped / risky / incomplete all `0` |
| {replay} | … | 0 | {one line per type}; `{total} histories replayed` |
| {client checks} | … | 0 | {type check, lint, tests N passed, build} |
| {generated-client drift} | … | 0 | {regenerated count; diff 0; porcelain 0} |
| **extra, not a gate step:** {suite} | … | 0 | {last line} |

## Run {N−1} — tree `{sha}` (FAILED, kept for the record)

{The same table up to the red step; then "the rest: not run, stopped at the first red step".}
Cause: {one paragraph — which change met which, the commits, why the textual merge did not flag it}.

## Regression spot-checks (diagnostics, not gate steps)

{The fix's own area on the merged tree: counts; the shared files that should hold both sides' contributions.}

## Out-of-scope defects

{class · instances · reproduction · size: small | larger — or "None found"}. Flaky tests: {none observed | test, run counts}.

## State left behind

{worktree or slot, tree, stack up or down, free disk; "the slot is not released — the PM decides"}
