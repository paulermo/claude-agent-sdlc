# Cross-epic integration

Epics run in parallel; delivery to `main` stays linear. This reference is how an epic takes another in-flight epic's code before `main` has it, and how that fixes the delivery order. Epic fields `base_branch`, `carries`, `delivers_after`: sdlc-state §6; fixed notes `delivery order: {EPIC-ID} before {EPIC-ID}` and `carries {EPIC-ID} at {sha}`: sdlc-state §7. LAW, except the table marked *Default*.

**Legend.** `{X}` the epic whose code is taken · `{Y}` the epic taking it · `{X-feature}` / `{Y-feature}` their `branch` · `{X-ref}` = `origin/{X-feature}` after `git fetch origin` when a remote exists, else `{X-feature}` · `{Y-merge}` = `{worktree_dir}/{Y}-merge` · `(remote only)`: as in `batch-end.md`.

## When — Default table

| Signal | Route |
|---|---|
| Y starts while X is in flight, and Y's first items need X's code (`main` has none of it) | 1 — cut Y's feature from X's |
| an item of Y about to be dispatched needs X's code | 2 — feature-in X, then dispatch the item |
| Y's batch end runs while X is in flight, and both change the same modules | 2 — feature-in, so the two gates run in parallel |
| an item needs one commit that is on `main` (a ruling, a story file) | 4 — cherry-pick; not a carry |
| otherwise | nothing — the epics meet at Y's next main-in |

*Default, not law: deviate only on concrete grounds, and record the rationale in a decision line on {Y}.*

## The carry record (LAW)

Every route that brings X's code into Y writes it, in the same response as the git step that brought the code:

1. Cycle check: `jq -r '.epics["{X}"].delivers_after // [] | index("{Y}")' docs/state/epics.json` prints `null`. A number → X already waits for Y: write nothing, surface to the user — two epics that each wait for the other never deliver.
2. On {Y}: `carries` += `{"epic": "{X}", "sha": "{X sha taken}"}`; `delivers_after` += `"{X}"` (once).
3. Two decision lines on {Y} (batch-end, "Every stage change" shape): `delivery order: {X} before {Y}`, then `carries {X} at {sha}`. Commit by path (sdlc-state §1).

Batch-end step 7 then holds Y's delivery until X is `done`. WHY: Y delivered first would put X's code on `main` before X's full gate proved it.

## 1. A feature cut from another feature (`base_branch`)

At Y's worktree creation (start.md), instead of cutting `{Y-feature}` from `main`:

```bash
git fetch origin                                   # (remote only)
git branch {Y-feature} {X-ref}; echo "exit=$?"
git push origin {Y-feature}; echo "exit=$?"        # (remote only) plain
```

Write `"base_branch": "{X-feature}"` and the carry record with `sha` = `git rev-parse {Y-feature}`. Y's items branch from `{Y-feature}` as usual; Y's batch-end main-in later brings `main`, which by then holds X's delivered form.

## 2. Feature-in — X's feature merged into Y's

1. `{sha}` = X at a settled point: after X's batch fix when X is at its batch end, else `git rev-parse {X-ref}`. Deploy exclusivity for target `{Y-feature}` (sdlc-dispatch §2); `{Y-merge}` exists (batch-end step 2.1).
2. Dispatch Deploy — `briefs/deploy.md` "Deploy — main-in / feature-in (F5)", feature-in variant, naming `{X-feature}` at `{sha}`; teammate `deploy-{Y}`; model key `Deploy:feature_in`; dispatch line `dispatch: Deploy ({X} in)`.
3. Verified report:

| OUTCOME | Then |
|---|---|
| MERGED | `push:` says not pushed and a remote exists → `git -C {Y-merge} push origin {Y-feature}; echo "exit=$?"`; the carry record |
| VERIFICATION_FAILED | the merge is on the fix branch the report names (`fix/{Y}-{X}-in`, or `…-{k}` — use the reported name, never the pattern): `git worktree add {worktree_dir}/{Y}-merge-fix {fix branch}; echo "exit=$?"`, register `"{Y}-merge-fix"` (sdlc-state §6); a Developer — `briefs/developer.md` "Developer — merge fix (F10)" with ITEM = `{Y}`, on that worktree; the diff read (sdlc-dispatch §3); the PM fast-forwards `{Y-feature}` to its head, removes the worktree (and its entry) and deletes the branch (batch-end step 3.4 commands, with that worktree and branch); then the carry record |
| MERGE_FAILED | as a main-in MERGE_FAILED (batch-end step 2): a design question — offer an Architect ruling |
| BLOCKED — an outage, or `not started: {why}` | no transition; resolve the blocker (sdlc-dispatch §3), then re-dispatch |

4. At Y's batch end the feature-in runs right after the main-in, still in stage `main_in`, before the batch fix. X's and Y's gates may then run in parallel (stack budget permitting): Y's gate proves the tree Y ships after X reaches `main`, and once X delivers the SHA Y carries, Y's re-gate check counts nothing new (batch-end step 5b, count B).
5. An item of Y already in flight takes X's code only through `{Y-feature}` — a merge-fix Developer, variant "bring the feature into the story branch" (F10) — never by merging `{X-feature}` into an item branch. WHY: one audited merge per carry, one carry record.

## 3. Cherry-picked meeting fixes

A meeting defect is a collision a textual merge does not flag (a caller left on a changed signature, a test double missing a new method). When X's batch fix or fix loop already fixed a class that Y's main-in or feature-in also shows (same files, same class):

- Y's batch-fix brief (F9 PART 1) names the commit: `git cherry-pick -x {sha}` — both lines then carry the same change and merge cleanly later; if it does not apply, the Developer makes the same change by hand and says so.
- A batch fix waits for the other epic's fix rather than redo it: X's batch fix for the class is dispatched and not yet verified → hold Y's batch fix and narrate "{Y} batch fix waits for {X}'s fix of {class}". Whichever epic's batch fix is dispatched first fixes; the other cherry-picks.

WHY: two epics fixing one collision separately produce two different fixes, which conflict at the next merge.

## 4. Single-commit prerequisites

A ruling commit, a story file or a rule change that one branch needs → that commit only, `git cherry-pick -x {sha}`, by the agent working on that branch; its brief's CARRIED IN says "cherry-pick {sha} first — only that commit, never a full main merge". Never `git merge origin/main` into an item branch or a feature outside the batch-end main-in. WHY: a full main merge once dragged hundreds of commits and eleven conflicts into one story branch. No carry record — the commit is already on `main`; the main-in later reconciles it (a conflicting doc or rule takes `main`'s side — story-merge skill).

## 5. Carried notes

A NOTE `for the {X} merge` — or `Architect ruling before {ITEM-ID}` whose item belongs to X and has no ruling yet — is resolved at Y's books (batch-end step 6): a new N-line in `docs/reviews/{X}-notes.md` under `## Carried from {Y}` as `… (was {Y} N-{n})`, and Y's line → `→ carried to {X} as N-{k} ({its next merge of main | before {ITEM-ID}})`. X's batch end triages it like its own notes.

## Situation | Action

| Situation | Action |
|---|---|
| X is frozen, or stalls, while Y carries it | Y waits at batch-end step 7; surface to the user (unfreeze X, or a directive deciding Y's scope) |
| X is already `done` when Y wants its code | not a carry — Y's next main-in brings it |
| X delivers a SHA other than the one Y carries (an X fix loop after the feature-in) | Y's re-gate check counts X's later code, and Y re-gates — expected |
| Y's delivery reports MERGE_FAILED after X delivered | batch-end step 7: re-merge, re-gate |
| A carried note's target epic is already `done` | resolve it `→ FU-{m}` instead, owner = the epic that next touches its files |
| Each epic needs the other's code | one feature-in only, toward the epic that delivers later by `priority_order`; surface to the user if that does not settle it |
| A cherry-pick does not apply | the Developer makes the same change by hand and says so in DETAILS |

## MUST NOT DO

- Write `carries` without `delivers_after` and both decision lines, in the same response as the merge.
- Merge `main` into an item branch or a feature outside the batch-end main-in, or merge another epic's feature into an item branch.
- Deliver Y before every epic in its `delivers_after` is `done`, or write a carry that closes a cycle.
- Redo a meeting fix another epic's batch fix is already making — wait and cherry-pick.
