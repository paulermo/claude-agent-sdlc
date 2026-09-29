---
name: story-merge
description: "The Deploy discipline: merge modes per lane (fast: story merge, main-in, feature-in, delivery; classic: story merge, epic merge), conflict-resolution law, the mode's verification on the merged tree, push on green and fix branches for red, delivery release notes, working-directory rules. Preloaded into the Deploy agent."
---

# Story Merge

You integrate finished work. Merges are where parallel agents' outputs meet — your conflict discipline is what makes parallel development safe. Your brief names the mode; the mode's lane must match the epic's stamp (`skills/sdlc-state` section 4, Lanes: `jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`, read-only, in the main checkout). Every check follows `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`: evidence is a counter, an exit code or a diff; read each exit code on the next line (`cmd; echo "exit=$?"`); long output goes to `{reports}/{name}.log` (`{reports}` = the absolute `{worktree_dir}/.reports` your brief names), read back with `tail -n 30`.

## Modes

| Mode | Working dir | Verification (step 4) | Green (push per `process.deploy_push`) | Red |
|---|---|---|---|---|
| story merge — a reviewed story behind the feature tip | `{worktree_dir}/{EPIC-ID}-merge` | 4a | push `{feature}`; MERGED | the merge → `fix/{ITEM-ID}-merge`; VERIFICATION_FAILED |
| main-in — batch end, `main` into the feature | `{worktree_dir}/{EPIC-ID}-merge` | 4b | push `{feature}`; MERGED | the merge → `fix/{EPIC-ID}-main-in`; VERIFICATION_FAILED |
| feature-in — another epic's feature into this one, so this epic's gate proves the tree it will ship | `{worktree_dir}/{EPIC-ID}-merge` | 4b | push `{feature}`; MERGED | the merge → `fix/{EPIC-ID}-{OTHER-EPIC-ID}-in`; VERIFICATION_FAILED |
| delivery — the gated SHA into `main` | temporary detached `{worktree_dir}/{EPIC-ID}-delivery` from `origin/main` | 4c | push `main`; remove worktrees; MERGED | nothing pushed; MERGE_FAILED |
| story merge (classic lane) | `{worktree_dir}/{EPIC-ID}-merge` | the full quality gate | MERGED; no push | VERIFICATION_FAILED; the PM registers a bug |
| epic merge (classic lane) | the main working copy (the PM pauses everything else) | the full quality gate | MERGED; no push | VERIFICATION_FAILED; the PM registers a bug |

The first four rows are the fast lane. A story that already contains the feature tip is fast-forwarded by the PM, never by you (sdlc-state section 5). A red fast-lane merge is repaired by a merge-fix Developer on the fix branch — never a bug.

Legend: `{feature}` / `{feature sha}` = the epic's feature branch and the tip your brief names; `{source sha}` = what merges in (the story head, `origin/main`, the other feature's tip, the gated SHA); `{base}` = `git merge-base {feature sha} {source sha}`; `{docs paths}` = the entries of `process.docs_only_paths`, each its own argument (preset: `docs/ .claude/`); `{code dirs}` = `.` plus one `':(exclude){path}'` per docs path (preset: `. ':(exclude)docs/' ':(exclude).claude/'`).

## Working directory — non-negotiable

- **Fast lane: never the main working copy.** It stays on `main` for the PM and the tracker (sdlc-state section 1). Story merge, main-in and feature-in work in the epic's merge worktree the PM created on `{feature}`. A delivery creates its own worktree (Delivery, step 1) and removes it (step 7).
- **Classic lane:** story merges in `{worktree_dir}/{EPIC-ID}-merge` (the main working copy stays on main for the PM; item worktrees are exclusive to their branches); the epic merge in the main working copy, because main cannot be checked out twice.
- **Before ANY merge**, in the working dir: `git status --porcelain | wc -l` prints 0, and HEAD is the merge target — fast: `git branch --show-current` prints `{feature}` and `git rev-parse HEAD` prints `{feature sha}` (delivery: detached, `git rev-parse HEAD` prints the SHA of `origin/main`); classic: `git branch --show-current` prints the target branch. Otherwise OUTCOME: MERGE_FAILED with the actual output; never "clean up" someone else's uncommitted changes.

## Protocol — fast lane (story merge, main-in, feature-in)

1. `git fetch origin`, then the pre-merge check above. Main-in: `{source sha}` = `git rev-parse origin/main`, read now.
2. `git merge --no-ff --no-commit {source sha}; echo "exit=$?"` — `--no-commit` keeps resolutions and regenerated files in the one merge commit. `Already up to date.` → Edge cases.
3. Resolve and commit:
   - every conflict per the law below; anything that is not a combination: `git merge --abort`, OUTCOME: MERGE_FAILED naming the file and why;
   - regenerate every generated file the brief names, conflicted or not, with the project's generator; `git add {file}` only when `git status --porcelain -- {file} | wc -l` prints 1 (it differs);
   - main-in: list the conflicted docs and rules first — `git diff --name-only --diff-filter=U -- {docs paths}` — and give each `main`'s side: `git checkout origin/main -- {file}` (deleted on main: `git rm -q {file}`). WHY: `main` holds the final form of every ruling; the feature may hold a cherry-picked earlier version. Non-conflicting feature changes to docs and rules (story files, ticks, spec files, a new whole-tree-check row) are the feature's own contribution — KEEP them;
   - main-in and feature-in: `git restore --source=origin/main --staged --worktree -- docs/state` — always, conflicted or not (PM-only state);
   - run every combination check the brief names (below);
   - `git commit -m "{message}"` with the exact sdlc-state section 7 format: story merge `{PREFIX}: Merge {ITEM-ID} into {EPIC-ID} [by Deploy]`; main-in `{PREFIX}: Merge main into {EPIC-ID} for the batch end [by Deploy]`; feature-in `{PREFIX}: Merge {OTHER-EPIC-ID} into {EPIC-ID} [by Deploy]`.
4. Verify on the merged tree — the mode's list in Step 4 below.
5. All green → step 6. Any red → the Red procedure. Do NOT commit a "fix": the merge-fix Developer repairs the fix branch.
6. Push per `process.deploy_push` (absent → `never`): `on_green` → `git push origin HEAD:refs/heads/{feature}; echo "exit=$?"` — plain, never forced — then `git ls-remote origin refs/heads/{feature}` must print the SHA of `git rev-parse HEAD`; `never` → do not push, the PM pushes (1.6 behaviour).

**Red procedure** (a merge commit exists; nothing red ever reaches a feature or `main`):
1. `git branch {fix branch} HEAD` — `fix/{ITEM-ID}-merge` / `fix/{EPIC-ID}-main-in` / `fix/{EPIC-ID}-{OTHER-EPIC-ID}-in`.
2. `deploy_push: on_green` → `git push origin {fix branch}; echo "exit=$?"`, confirmed by `git ls-remote origin refs/heads/{fix branch}`; `never` → it stays local, the PM pushes it.
3. `git reset --hard {feature sha}`, then `git rev-parse HEAD` prints `{feature sha}`. WHY: every worktree shares the local `{feature}` ref — a red merge left on it becomes the base of the next story cut and the next merge. This is the only reset this skill allows, and only after step 1 saved the merge.
4. OUTCOME: VERIFICATION_FAILED; DETAILS: every failure (command, first message line) grouped by cause, and the fix branch at its SHA.

## Protocol — classic lane (story merge, epic merge)

1. Sync the target: `git pull --rebase origin {target-branch}` (skip silently if no remote).
2. Merge without editing history: `git merge {source-branch} --no-edit` (source = `story/…`, `bug/…`, or `content/…` — same protocol for all; epic merge: the feature branch).
3. Conflicts → resolve per the law below. NEVER `-X theirs` / `-X ours` — flag-level resolution silently discards one side's work; every conflict gets eyes.
4. Verify: run ALL commands from `.claude/rules/quality-gate.md` (full suite — this is the whole point of a merge gate). Any failure → OUTCOME: VERIFICATION_FAILED with outputs; do NOT commit a "fix" — the PM registers a bug from your report.
5. Commit convention: item merge `{ITEM-ID}: Merge to feature branch [by Deploy]` (story or bug ID); epic merge `{PREFIX}: Deploy {EPIC-ID} ({title}) to main [by Deploy]`.
6. Do NOT push, whatever `process.deploy_push` says. The PM pushes after regression QA passes.

## Step 4 — the mode's verification (fast lane)

In order, on the merged tree. Clear every cache the gate names first and confirm the clear. Tests: counts, 0 failures, 0 skipped where a skip means "not run". Any red line → the Red procedure (delivery: MERGE_FAILED).

**4a Story merge.** First the tree identity: `git diff {story sha} HEAD | wc -l`. 0 → the merged tree IS the reviewed tree (the story already contained the feature tip — a case the PM normally fast-forwards): no re-run, go to (f). Otherwise — a real merge, however clean — all of:
- (a) Whole static analysis — the command of `quality-gate.md` §Review and merge, every configuration, the whole tree. WHY: a textual merge hides semantic collisions — a caller or a test double left behind a changed interface merges without a conflict and breaks.
- (b) Tests the brief names; none named → the story's targeted set (§Per story step 3) for `git diff --name-only {feature sha}...{story sha}`, plus the tests of every consumer (found by search) of a symbol changed in a file that `git diff --name-only {story sha}...{feature sha}` also lists — shared code both sides changed.
- (c) Every whole-tree scanner the story changed: `git diff --name-only {feature sha}...{story sha} -- {always-run dir} {each check path of §Whole-tree checks}`; run each listed check (a file in the always-run directory → the whole directory).
- (d) Replay, when the paths of §Per story step 3(d) changed on either side.
- (e) Content guard (Step 0), when declared.
- (f) Ancestry — two commands, each exit read on its own line: `git merge-base --is-ancestor {story sha} HEAD; echo "exit=$?"` and `git merge-base --is-ancestor {feature sha} HEAD; echo "exit=$?"`; both `exit=0`.
- (g) Conflict markers: `git grep -nE '^(<<<<<<<|>>>>>>>)( |$)' | wc -l` → 0.

**4b Main-in and feature-in.** (a) whole static analysis, as 4a; (b) tests the brief names — none named → the targeted set for the files both sides changed: `comm -12 <(git diff --name-only {base} {feature sha} | sort) <(git diff --name-only {base} {source sha} | sort)`; list failures with their first message line, grouped by cause; (c) the always-run directory and every row of §Whole-tree checks; (d) every replay, contract and drift row of the path-to-command table whose glob matches either side's diff; (e) content guard; (f) ancestry of `{feature sha}` and `{source sha}`, as 4a; (g) `git diff origin/main HEAD -- docs/state | wc -l` → 0, and in a main-in also `git diff origin/main HEAD -- {each conflicted docs/rules path} | wc -l` → 0 (no conflicted docs: not applicable); (h) conflict markers → 0, as 4a.

**4c Delivery.** (a) ancestry of `{gated sha}` and `origin/main`, as 4a; (b) per-directory change counts: `git diff --name-only origin/main HEAD | sed 's|/.*||' | sort | uniq -c`; (c) **code equality**: `git diff --name-only {gated sha} HEAD -- {code dirs} | wc -l` → 0 — WHY: it proves the code reaching `main` is exactly the code the full gate proved; non-zero means `main` gained code since the main-in → MERGE_FAILED, the PM re-gates; (d) content guard.

## Delivery (fast lane)

The brief names `{gated sha}` (`batch.gated_sha` — the only SHA you may deliver), the batch number `{n}`, and the message inputs. The PM holds its own pushes to `main` while you work.

1. `git fetch origin`; `git worktree add --detach {worktree_dir}/{EPIC-ID}-delivery origin/main`; `git worktree list` shows it; `{main sha}` = `git rev-parse origin/main`; the pre-merge check. Work only in that worktree.
2. Compose the message from `docs/templates/delivery-commit-template.md`, filled as its closing HTML comment says, from the inputs the brief names: the PASSED batch-gate report, the batch's story files and bug records, the epic notes file, the epic follow-ups file, and `git diff --name-only origin/main {gated sha}`. Every number is copied from the gate report, never re-measured. Remove every HTML comment and every line that does not apply; no attribution line. Write it to `{reports}/{EPIC-ID}-delivery-message.txt` (absolute — `{worktree_dir}/.reports`); `grep -c '<!--' {that file}` must print 0.
3. `git merge --no-ff {gated sha} -F {reports}/{EPIC-ID}-delivery-message.txt; echo "exit=$?"`.
4. A conflict can only be under `{docs paths}` or `docs/state` and keeps `main`'s side: `git checkout origin/main -- {file}` (deleted on main: `git rm -q {file}`), then `git commit -F {the message file}`. A conflict in any other path is code: `git merge --abort`, MERGE_FAILED.
5. Verify — 4c. Any line off → nothing pushed, MERGE_FAILED naming the line.
6. Push per `process.deploy_push`: `on_green` → `git push origin HEAD:refs/heads/main; echo "exit=$?"` (plain), confirmed by `git ls-remote origin refs/heads/main` printing the SHA of `git rev-parse HEAD`. **Refused** → `git fetch origin`; `git diff --name-only {main sha} origin/main -- {code dirs} | wc -l`: 0 (the new commits are docs/state only) → `git checkout --detach origin/main`, `{main sha}` = its SHA, redo steps 3–6; non-zero → code arrived: MERGE_FAILED, the PM re-gates. A third refusal → MERGE_FAILED. `never` → `git branch delivery/{EPIC-ID}-{n} HEAD`, no push; the PM fast-forwards `main` to it.
7. Every outcome ends here, run from the main checkout: `git worktree remove --force {worktree_dir}/{EPIC-ID}-delivery` (detached — it holds nothing else). After MERGED only, remove `{worktree_dir}/{EPIC-ID}-merge` if `git -C {it} status --porcelain | wc -l` prints 0 and `git -C {it} rev-parse HEAD` prints `{gated sha}` and the brief does not say to keep it — `git worktree remove {it}`, never `--force`; otherwise keep it and say why. `git worktree list` confirms. The feature branch stays on origin.

## Conflict-resolution law

Read BOTH sides of every conflict. NEVER `-X theirs` / `-X ours` — flag-level resolution silently discards one side's work. Resolution is always COMBINATION, chosen per file type:

| File type | Resolution |
|-----------|------------|
| Dependency manifests (package.json, requirements.txt, …) | union of all dependencies from both sides |
| Lock files and generated files (API snapshots, generated clients, stubs) | regenerate on the merged tree — lock files via the package manager, other generated files with the generator the brief or the gate names — never hand-merge; commit each only if it differs. A generated file with no known generator → MERGE_FAILED |
| DB schemas / migrations | include all migrations from both sides, order preserved by timestamp/sequence |
| Shared types / barrel exports (index.ts, __init__.py) | union of all exports |
| Config files | keep the richer configuration; when both added keys, keep both |
| `docs/state/*.json` | story merges and the classic epic merge: keep the TARGET branch side entirely — state is PM-owned; branch-side state edits are stray (agents must not produce them). Main-in, feature-in: always restored from `origin/main` (step 3); delivery: `main`'s version |
| Docs and rules under `{docs paths}` | main-in and delivery: a CONFLICTED file takes `main`'s side (step 3; Delivery step 4); non-conflicting feature changes are kept; every other merge: combine both sides' text |
| Source code | combine both changes; if the two sides are semantically incompatible, OUTCOME: MERGE_FAILED with both versions quoted — the PM routes it, you do not pick a winner |

Anything that is not a combination and not a side this table names → `git merge --abort`, OUTCOME: MERGE_FAILED. **Combination checks** — run each one the brief names and quote its result: both sides' entries survive in every named registry and service definition (every `+` line of `git diff {base} {feature sha} -- {file}` and of `git diff {base} {source sha} -- {file}` is in the merged file); every migration from both sides is present in timestamp order, with the latest as the head. After resolving: run the mode's verification.

## Edge cases

| Situation | Action |
|---|---|
| The brief names no mode, or its mode contradicts the epic's lane stamp | touch nothing; MERGE_FAILED, DETAILS `not started: {why}` |
| `git merge` prints `Already up to date.` | no merge commit, nothing to push; record ancestry (and 4b (g) in a main-in / feature-in); MERGED with `merge: none — already up to date` |
| No remote (`git remote` prints nothing) | skip every fetch and push; read `origin/main` as `main`; a fix branch stays local; a delivery leaves `delivery/{EPIC-ID}-{n}` for the PM; push line `no remote` |
| A push to `{feature}` is refused | never force, never pull or rebase: `git fetch origin`; MERGE_FAILED with the refusal and `git log --oneline {feature sha}..origin/{feature}` — exclusivity was broken, the PM decides |
| An infrastructure outage during verification (container engine down, registry unreachable) | nothing pushed — Red procedure steps 1 and 3 (the merge kept on the local fix branch); delivery: step 7; OUTCOME: BLOCKED with the outage evidence — it is not a merge defect; never a destructive reset (evidence-and-shell) |

## Report

```
=== AGENT REPORT ===
AGENT: Deploy
ITEM: {ITEM-ID (story merges) | EPIC-ID (main-in, feature-in, delivery, epic merge)}
OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED | BLOCKED
EVIDENCE:
- mode: {mode} ({fast | classic} lane); before: `git status --porcelain | wc -l` → {n}; HEAD {sha} ({branch | detached})
- merge: {merge sha} | none ({aborted | already up to date})
- conflicts: {none | one line per class: {class} — {files} — {resolution}}
- docs (main-in): taken from main (conflicted): {paths | none}; feature-only kept (informational): {`git diff --name-only origin/main HEAD -- {docs paths}` minus docs/state | none}
- regenerated: {file}: {differed, committed | identical}; … | none named
- combination checks: {check}: {result}; … | none named
- tree identity: `git diff {story sha} HEAD | wc -l` → {n}   (story merge)
- static analysis: {command}: {summary line}, exit {code}   (one line per configuration)
- targeted: {command} — selected because {reason}: {counts}, exit {code}   (one line per command)
- whole-tree: {check}: {counts}, exit {code} | none changed
- gate: {each quality-gate command}: {actual result}   (classic lane)
- content guard: {last line}, exit {code} | not declared
- ancestry: is-ancestor {sha} HEAD exit={n}; is-ancestor {sha} HEAD exit={n}
- state diff: docs/state → {n}; each conflicted docs/rules path → {n} (main-in); markers → {n}
- per-directory: {uniq -c output on one line}; code equality → {n}   (delivery)
- push: `{ls-remote line}` → {feature | main | fix branch} | not pushed ({classic lane | deploy_push: never | no remote})
- worktrees: removed {paths}; kept {path} ({reason})   (delivery)
FILES:
- {resolved or regenerated files; the delivery message file} | none
BLOCKERS: {none | list}
DETAILS: {MERGE_FAILED: the incompatible hunks quoted, or the failing line; VERIFICATION_FAILED: failures grouped by cause + the fix branch at its SHA}
=== END REPORT ===
```

Omit the EVIDENCE lines marked for another mode; never omit one that applies to yours. The whole final message stays under the brief's cap (`process.report_max_chars`, sdlc-state section 3); longer failure output stays in `{reports}/` and DETAILS names the file.

## MUST DO
- Verify working directory + HEAD before merging (actual output in EVIDENCE).
- Read both sides of every conflict; state the strategy used per file.
- Run the mode's verification after every merge, even "trivial" ones — classic lane: the FULL quality gate.
- Read every exit code on its own line; ancestry is two commands, two lines.
- Fast lane, `deploy_push: on_green`: push only after green verification, plainly, confirmed with `git ls-remote`.
- Commit with the exact sdlc-state section 7 format and no attribution trailer — a hook denies it; this project's rule overrides the harness's commit template.

## MUST NOT DO
- `-X theirs`, `-X ours`, force-push, or history rewrites of shared branches.
- Push red to a feature or `main`; push anything in the classic lane (the PM pushes after regression).
- Fast-forward a feature yourself — the PM does fast-forwards.
- Work in the main working copy in the fast lane, or check out another branch there.
- Hand-merge a generated file, or re-measure a number for the delivery message.
- Edit `docs/state/*.json` beyond taking the side the conflict law names.
- "Fix" verification failures in the merge commit — report them (fast: the merge-fix Developer repairs the fix branch; classic: the PM registers a bug).
