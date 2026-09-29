# Mid-flight rulings

A ruling is one small Architect decision made mid-flight — docs, `.claude/rules/` and ADRs only, never code — so a Developer neither blocks until the next Design Mode nor guesses: a guess costs a full rework. The Architect's side: `architecture-design`, Ruling mode; the brief: `briefs/planning.md` "Architect — ruling (F8)". LAW, except the table marked *Default*.

**Legend.** `{ITEM-ID}` the item that waits for or builds on the ruling (the `{EPIC-ID}` for an ordering question between epics) · `{topic}` a kebab-case slug of ≤ 4 words · `{branch}` = `architect/{ITEM-ID}-{topic}` · `{wt}` = `{worktree_dir}/ARCH-{topic}` · `{reports}`, `{excludes}`, `(remote only)`: as in `batch-end.md`.

## When — Default table

| Signal | Dispatch | Timing |
|---|---|---|
| a Developer BLOCKED whose BLOCKERS name a design decision no rule or ADR makes | ruling | now; the item keeps its status and worktree, its teammate is not released |
| a NOTE `rule gap (Architect)`, `rule text (Architect)` or `Architect ruling before {ITEM-ID}`, or a Reviewer `Rule gap:`, that a later item builds on — a `todo` item's story file or bug record names the rule, module or file it concerns: `grep -rlF '{that name}' docs/issues/{EPIC-ID}-{slug}/` | ruling | before that item is dispatched — it waits (not the `held` field) |
| a known open decision (the story, use case or design leaves a choice open) for an item not yet dispatched | pre-ruling — stackless, so it may run while the stack budget is full | before that item is dispatched |
| an ordering question: which item or epic builds a shared piece first, and `delivers_after` does not settle it | ruling | before the next dispatch it orders |
| a rule gap nothing builds on soon | none — keep it: fast lane, an open `rule gap (Architect)` N-line (batch-end step 2b triages it); classic lane, in the saved review for the Architect's next Design Mode brief (sdlc-dispatch §3b) | — |

*Default, not law: deviate only on concrete grounds, and record the rationale in the dispatch line's note.*

## The PM's steps (LAW)

1. Reserve nothing — unless the report asks for new scope (below).
2. Worktree and branch from `main`: `git worktree add -b {branch} {wt} main; echo "exit=$?"`; then `git worktree list | grep -cF '/ARCH-{topic} '` → `1`.
3. Dispatch line on `{ITEM-ID}`: `"trigger":"dispatch: Architect (ruling)"` — or `(pre-ruling)` — `"note":"{N-, FU- or question id}, base {main sha}, stack none"`. Dispatch F8 with options (a), (b), (c) filled; teammate `architect-{ITEM-ID}`; model key `Architect:ruling`; stackless (sdlc-dispatch §2).
4. Verify (sdlc-dispatch §3), then prove the branch carries docs and rules only — a count, `0` required:

   ```bash
   git diff --name-only HEAD...{branch} -- . {excludes} > {reports}/ARCH-{topic}.paths; echo "exit=$?"
   wc -l < {reports}/ARCH-{topic}.paths
   ```

5. Merge into `main` from the main checkout, your state committed first (`git status --porcelain | wc -l` → `0`): `git merge --no-ff {branch} -m "{PREFIX}: Merge Architect {topic} [by PM]"; echo "exit=$?"`. No ruling commit on the branch — `git rev-list --count main..{branch}` prints `0` (nothing ruled) → skip to step 7.
6. Push: `git push origin main; echo "exit=$?"` (remote only; plain) — while a delivery Deploy works, hold it until Deploy reports (batch-end step 7).
7. Remove the worktree, then delete the branch — WHY: a branch name like `architect/{EPIC-ID}-notes` recurs every batch: `git worktree remove {wt}; echo "exit=$?"`; `git worktree list | grep -cF '/ARCH-{topic} '` → `0`; `git branch -d {branch}; echo "exit=$?"` (merged into `main`, or holding no commit of its own); `git push origin --delete {branch}; echo "exit=$?"` (remote only; skip when never pushed).
8. Completion line on `{ITEM-ID}` (`"trigger":"Architect"`, `"note":"DESIGNED: {the ruling, one clause}; ruling {sha(s)}; merged {merge sha}"`); commit state by path; narrate the decision in two bullets of substance (start.md Narration).

WHY `--no-ff` into `main` at once: `main` holds the final form of every ruling; features take it at their main-in, where a conflicting doc or rule takes `main`'s side (story-merge skill).

## What the waiting Developer receives

The ruling commit(s) = the SHA(s) in the Architect's report, oldest first — never the `--no-ff` merge commit. One line, the same wherever it goes: `cherry-pick the ruling {sha} first — only that commit, never a full main merge: git cherry-pick -x {sha}`.

- A BLOCKED teammate not released → the blocker-resolved message (recovery reference §4) carrying that line and the report's "Meanwhile"; log `dispatch: Developer (resumed)`, note `unblocked: ruling {sha}`.
- Released, or an item the report names as building on it → its next brief's CARRIED IN carries the line.
- Every later dispatch of that epic the report names, until the epic's next main-in, carries it too.

WHY: pulling all of `main` into an item branch drags in other epics' code and conflicts — a Developer once rightly aborted a 302-commit, eleven-conflict main merge and applied the ruling commit alone.

## New scope

The report's "Builds it" says `needs a new story: {scope}`:

1. Reserve the ID: `counters.story` + 1 in `project.json`; commit by path.
2. Dispatch the System Analyst — `briefs/planning.md` "System Analyst — one story from a ruling" (story-breakdown, that mode) — with the reserved ID, the ruling's ADR and the epic, in a planning worktree merged as start.md's planning phase says.
3. Register the story (sdlc-state §6) into the bucket the epic's status dictates (sdlc-state §2); log `"from": null`, `"trigger": "System Analyst"`; commit by path. The epic's batch end is already running → cut the batch to its current members first (batch-end, Cut a batch: set `batch.items` only, never reset its stage or counters), so the new story waits for the next batch.

## Situation | Action

| Situation | Action |
|---|---|
| NEEDS_REQUIREMENTS_FIX | a requirements gap, not a design one: Product Manager / System Analyst refinement (start.md planning phase), or surface to the user; the waiting item keeps waiting; remove the worktree (step 7) |
| step 4 count > 0 (the branch touches code) | do not merge; a fresh Architect on the same worktree, naming the paths — docs, rules and ADRs only |
| step 5 merge conflicts | `git merge --abort; echo "exit=$?"`; re-dispatch the Architect on the same worktree to merge `main` into its branch and resolve its own files; then step 4 again |
| the Architect reports BLOCKED (e.g. the content guard red on a line it did not write) | surface the line to the user; the waiting item keeps waiting |
| a Design Mode Architect is in flight on the same rule files | hold the ruling, or name the question in that dispatch |
| two rulings on one topic | one at a time; the second's brief names the first's commit |
| the cherry-pick conflicts in the Developer's branch | the Developer applies the same docs/rules change by hand and says so in DETAILS |
| the ruling changes an acceptance criterion | a dispatched item: the report's "Meanwhile" carries it (the Architect never edits a dispatched item's file); a `todo` item: System Analyst amendment pass before its dispatch |

## MUST NOT DO

- Merge a ruling branch that touches code, or merge it any way but `--no-ff` from the main checkout.
- Tell a Developer to merge `main` — the ruling commit only, by `git cherry-pick -x`.
- Dispatch the item waiting for a ruling before the ruling is merged.
- Write a story for a ruling's new scope yourself — reserve the ID; the System Analyst cuts it.
