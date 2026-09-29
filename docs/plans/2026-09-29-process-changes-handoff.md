# agent-sdlc: process changes proven on one project, handed off for the plugin

**Audience.** An engineer or agent who will edit the agent-sdlc plugin (skills, agents, briefs, templates, hooks) and
who knows the plugin but not the project it was run on.
**Goal.** Make these changes the plugin's defaults, or configurable options with sensible defaults, so they stop being
one project's local practice.
**Baseline.** agent-sdlc **1.6.1**. Plugin paths below are relative to the plugin root, and line numbers are 1.6.1's.
**Project.** A large modular-monolith backend with three clients, protobuf contracts and Terraform, run by the pipeline
for about three weeks. It has about 74 epics, 900 stories, 50 bugs and a 4,600-line transition log. It is called "EMI"
below. EMI examples are labelled **Example (EMI)**. They make a rule concrete; they are not part of the rule.

**Provenance labels** (on every change, so you can tell law from habit):

| Label | Meaning |
|---|---|
| **[RULE]** | Written into the project's own rules: `.claude/rules/quality-gate.md` and the project's `run-checks` skill. |
| **[USER]** | A user correction recorded in the PM's memory, with the user's stated reason. |
| **[PRACTICE]** | Observed in the transition log or in the dispatched briefs, but not written as a rule anywhere. |
| **[PROJECT]** | Specific to this project or host. The plugin should support it generically, not ship it. |
| **[GATE]** | Exists in the sibling plugin **agent-sdlc-gate** (0.3.1, the newest version in the plugin cache), a multi-repository, Jira-based, pull-request-centred fork of agent-sdlc. It was read in full for C25–C28. Its paths are relative to its own plugin root, with 0.3.1's line numbers. |

Where a source does not confirm something, this document says **not observed** instead of guessing. For the sibling
plugin the phrase is **not observed in agent-sdlc-gate**.

---

## 1. Summary

**This revision adds C25–C29.** Four are taken from the sibling plugin agent-sdlc-gate and labelled **[GATE]**; the
fifth is the user's request:

- **C25**: its hook that denies attribution trailers on commits, ported as a default-on, configurable hook;
- **C26**: its optional main regression, merged with EMI's skip rule into one policy, `process.main_regression`;
- **C27**: its per-repository test-stack lock, set against EMI's several stacks on runners;
- **C28**: its Jira tracker backend, as a choice between local files and Jira so that several people can work on one
  project;
- **C29** [USER]: milestones as a first-class tracker object: defined in dialogue, linked to epics, with progress per
  milestone in `/agent-sdlc:status` and the tracker.

C25, C26 and C29 are ready to implement; C29's mapping onto Jira waits for C28. C27 and C28 are design problems for the
plugin's Architect; §5.1 and §5.2 state them as the two headline open questions.

**What the plugin does today.** Every story passes through a fixed chain:

1. The Developer runs the full quality gate.
2. The Reviewer re-runs the full gate. Rework is bounded by a per-tier return budget of 1, 2 or 3, and a parking gate
   stops the item at the budget.
3. QA runs E2E tests per acceptance criterion. It is skipped for the light tier.
4. Deploy merges the story into the feature branch, runs the full gate again, and never pushes.
5. Regression QA runs on the feature branch after every merge.

A red merge or regression registers a bug. An epic reaches `main` only when every item is done and no follow-up is
open (else a hygiene bug is registered). Deploy merges in the main working copy while everything else is paused. A
regression QA run on `main` follows, then a blocking demo gate.

**What EMI does instead.** EMI replaced that chain with a **two-level "fast lane"**:

- **A story** proves itself with a *targeted set*:
  - a red test first;
  - the touched area and every consumer of what changed;
  - the whole-tree checks the change feeds;
  - static checks on the changed files only.

  A story gets **one review round** and at most **one fix pass**, which the PM verifies by reading its diff. NOTE-level
  findings never return a story; they collect in an epic notes file. There is no per-story QA. A reviewed story merges
  at once, and nothing re-runs after the merge except the whole-tree scanners it changed.
- **A batch** (by default an epic) proves itself **once**, with the full gate, at batch end:
  1. `main` is merged into the feature branch.
  2. A pre-gate "batch fix" repairs cross-epic *meeting defects* and chosen notes.
  3. QA runs the full gate, usually on a remote Compose-stack runner.
  4. A fix loop repairs any red step, and the gate re-runs from the failed step.
  5. One delivery merge to `main` follows, carrying release notes in its commit message.
  6. Main regression is skipped when `main` gained only documents since the gated merge.

Around this grew:

- merge mechanics that never push a red merge to a feature branch (`fix/…` branches and "merge fix" Developers instead
  of bugs);
- cross-epic integration: feature merged into feature, cherry-picked meeting fixes;
- mid-flight Architect rulings on `architect/…` branches;
- milestone planning, where milestones are made of whole epics and the demo never blocks the pipeline;
- remote stack runners with start tokens;
- a local stack budget, teammate recovery procedures, model tiering, and brief hygiene against context overflow;
- a strict evidence discipline for exit codes on a zsh host.

**The three biggest plugin edits** (details in §4):

1. **Two-level verification.** Add a lane switch (`process.lane: fast | classic`, default `fast`). Rewrite the
   quality-gate seed into §Per story (targeted set), §Review and merge and §Batch end (full gate). Then rewire the
   Developer, Reviewer, QA and Deploy skills and the dispatch map to it.
2. **Review economy.** One review round, and one fix pass verified by the PM's diff read. Add an explicit exception to
   the "presence check only" law. A NOTE never returns a story; it goes to the notes file.
3. **The batch end as a first-class, ordered PM procedure.** Main-in, batch fix, full gate, fix loop, re-gate if `main`
   gained code, notes and follow-up triage, then a delivery merge with release notes. It replaces "Deploy flow: epic →
   main". Merge failures go to `fix/…` branches and a merge-fix Developer, never to bugs.

---

## 2. All changes at a glance

| ID | Change | Plugin area | Impact |
|---|---|---|---|
| C1 | Fast lane: the targeted set per story | quality-gate seed, story-implementation, story-review, briefs | **High**: the main cost driver |
| C2 | One review round; one fix pass verified by the PM's diff read (return budget 1) | sdlc-state §4/§5, story-review §4, sdlc-dispatch §3, start.md budget gate | **High** |
| C3 | NOTEs never return a story; the epic notes file | story-review, sdlc-dispatch §3b, sdlc-state §1/§4 | Medium |
| C4 | No per-story QA and no per-merge regression; the fast-lane state machine | sdlc-state §4/§5, start.md dispatch map, story-qa | **High** |
| C5 | Whole-tree checks: selected by the fact they encode, re-run on the merged tree | quality-gate seed, story-merge, story-review | Medium |
| C6 | The batch end: main-in, batch fix, full gate, fix loop, re-gate | start.md (replaces "Deploy flow"), story-qa, story-merge, briefs | **High** |
| C7 | Batches and batch cuts inside an epic | sdlc-state epic machine, start.md | Low–Medium |
| C8 | Follow-up triage replaces the hygiene-bug gate | sdlc-state §4 Follow-ups/Epic, start.md | Medium |
| C9 | Delivery merge with release notes; main regression skip; archive | story-merge, briefs, start.md, sdlc-state | **High** |
| C10 | Merge mechanics: PM fast-forward, whole static analysis on the merged tree, `fix/` branches, merge-fix Developer, exclusivity per target branch, push on green | story-merge, sdlc-dispatch §2, start.md, agents/deploy.md | **High** |
| C11 | Cross-epic integration: feature into feature, delivery order, parallel gates, cherry-picked meeting fixes | start.md (new section), sdlc-state epic fields | Medium |
| C12 | Mid-flight Architect rulings (`architect/…` branch, cherry-pick of the ruling only) | architecture-design (new Ruling mode), briefs, start.md, sdlc-dispatch §3b | Medium |
| C13 | Milestones: demo slices, whole-epic recuts, demo on the user's word, progress per milestone | start.md demo gate, brd-writing/story-breakdown, templates, status | Medium |
| C14 | Remote Compose-stack runners: slots, sync, start tokens, pending markers, reset | new optional integration; story-qa, story-implementation | Medium (**High** where the host is small) |
| C15 | A local stack budget, separate from the teammate cap | sdlc-dispatch §2, project.json | Medium |
| C16 | Teammate lifecycle and recovery (panes, release, fresh fix pass, resume after limits or connection loss, replace a thrashing teammate, report tail, planned hand-off) | start.md, sdlc-dispatch §3/§4, story-implementation | Medium |
| C17 | Model tiering per role | sdlc-dispatch §1, README, project.json | Medium |
| C18 | Brief hygiene against context overflow; reports to files; report size caps; a rules budget | story-implementation §0, sdlc-dispatch §1, report envelope, rule-authoring | **High** on large rule sets |
| C19 | Evidence, not silence; shell exit-code discipline (zsh) | new shared reference, sdlc-state §3, all agent skills | **High** |
| C20 | PM working copy and commits: main checkout stays on `main`, state committed by path, planning agents in worktrees, held pushes, no attribution | sdlc-state §1/§7, start.md Git policy, hooks | Medium |
| C21 | PM record-keeping: review and gate reports saved from files, N-/FU- numbering, log vocabulary; narration (already in the plugin) | sdlc-state §6/§7, story-review §5/§6 | Low–Medium |
| C22 | Standing brief lines a project declares (reference check for ambiguity, app first, content guard, no attribution) | briefs.md DISCIPLINE, project.json | Medium |
| C23 | Planning cadence: just-in-time depth, amendment passes, stackless pre-rulings | start.md planning phase | Low |
| C24 | Project- and host-specific items: content guard, clean room, host recovery, designer reference screens | optional config only | Low |
| C25 | The no-attribution hook: a `PreToolUse` deny on attribution trailers, default on, configurable [GATE] | `hooks/`, init.md, project.json schema, sdlc-dispatch §3, briefs | Medium |
| C26 | Main regression after delivery as one policy: `always`, `never`, or only when `main` gained code [GATE] | start.md, sdlc-state §4, init.md, project.json schema | Low–Medium |
| C27 | Test stacks: the gate's per-repo lock versus a pool of stack leases — **design open, §5.1** [GATE] | sdlc-dispatch §2, briefs, sdlc-state §6, start.md, init.md, status | **High** where stacks are heavy |
| C28 | The tracker backend: local files or Jira, for teams — **design open, §5.2** [GATE] | sdlc-state (new §0), start.md, init.md, status, a new tracker skill | **High** for teams |
| C29 | Milestones as a first-class tracker object: schema, transitions, created from dialogue, progress per milestone [USER] | sdlc-state §2/§4–§7, start.md, status.md and the tracker, brd-writing, init.md | Medium |

**The sibling plugin `agent-sdlc-gate` (0.3.1)** is described where it bears on a change, under **[GATE]**: its
attribution hook in C25, its main regression in C26, its test-stack lock in C27 and its Jira backend in C28. It also
fans review out over parallel read-only lenses, has a gate-only QA mode with per-criterion evidence, and delivers through
pull requests; this document does not take those up. It has none of EMI's fast lane, batch-end gate, notes file, `fix/`
branches, cross-epic integration, runners or milestone recuts.

---

## 3. The changes

Every section has four parts:

- **(a)** what the plugin does today;
- **(b)** what EMI does instead, written as rules the plugin could adopt;
- **(c)** why;
- **(d)** which plugin files to change, and how.

In C25–C28, **(b)** describes what agent-sdlc-gate does, with EMI's practice beside it where the two differ. For C27
and C28, **(d)** lists only the files a design will touch; the design itself is §5.1 and §5.2.

### C1 — Fast lane: the targeted set per story

**(a) Plugin today.**
- `templates/rules/quality-gate.md` L3: "Every change MUST pass all commands below before it can be reported done."
  L17–18 (Enforcement): Developer, Reviewer, QA (full suite in regression) and Deploy (after every merge). The comment
  at L20–22 allows a changed-path mapping for monorepos, but "Regression QA always runs the full set".
- `skills/story-implementation/SKILL.md`:
  - §2 L70: "Run the **full** quality-gate command set";
  - §1b step 3 L62 (bugs): "Run the FULL quality gate";
  - §2b L76 (rework): "Re-run the full gate";
  - MUST DO L123.
- `skills/story-review/SKILL.md` §2, Quality lens L27: "run the quality-gate commands … yourself". MUST DO L128.
- `agents/developer.md` L34 and `agents/reviewer.md` L16.
- `skills/sdlc-dispatch/references/briefs.md`:
  - Developer story L199: "all quality-gate commands green";
  - rework L223: "full quality gate green";
  - bug L247.

**(b) What EMI does** [RULE quality-gate.md §Per story; USER fast-lane]. Every story and bug runs this set before
IMPLEMENTED, whatever its tier:

1. **Red first.** Write the test for the new or fixed behaviour. See it fail and quote the failure before writing the
   implementation.
2. **The content guard (Step 0)**, always. It is cheap and covers the whole tree ([PROJECT]: a banned-terms scan; see
   C24).
3. **Targeted tests, never the whole suite.** Run them as one test-runner invocation covering:
   - **(a)** the tests that mirror every touched source path;
   - **(b)** the tests of every consumer of a changed symbol, **found by search, never from memory**: a port's callers,
     service and DI wiring, routes and controllers, event transformers and consumers, and shared fixtures and helpers
     together with every test that uses them;
   - **(c)** the whole-tree checks: the architecture-test directory always, plus every whole-tree check outside it that
     the change gives a new fact to (a closed list, C5);
   - **(d)** workflow replay when a workflow, an activity or the replay corpus changed, and every container-level suite
     whose subject changed.
4. **Static checks on the changed files only.** These are:
   - the formatter, in intersection mode with an explicit config;
   - the static analyser, over the changed source files and the changed test files;
   - the client linter, over the changed files.

   The TypeScript type check is the exception: it runs project-wide with a forced rebuild (`tsc -b --noEmit --force`),
   because types cross files, and `tsc -b` without `--force` finds its projects up to date, checks nothing and exits 0.
5. **Forbidden per story:**
   - the full test suite;
   - whole-tree lint or type runs beyond the rule above;
   - a client `ci:check` or build;
   - a QA dispatch.
6. **The report shows the selection.** Each command is listed with the reason each path was selected (touched, consumer
   of X, whole-tree scanner, or the whole-tree check a new fact selects) and its counts. **The Reviewer judges the
   selection as well as the result; a consumer or whole-tree check left out is a blocking finding.**
7. **The Reviewer re-runs the story's targeted set once, independently**, and never trusts the Developer's quote.
8. **A fix pass re-runs only what the fix touches.**
9. **Timing-sensitive test groups** (concurrency, workflow-engine) belong to the batch-end gate when the host is loaded.
   The story says so instead of retrying them [USER].
10. **Stale compiled caches.** Clear any cache whose staleness makes a check pass or fail wrongly, and confirm the
    clear. An unconfirmed clear is an un-run check, not a failure. Warm the container a static analyser reads
    immediately before the targeted run [PROJECT specifics; generic lesson].

**(c) Why** [USER]:
- "The user's token and time budget can't afford several full-gate runs per story, or 8 laps through the SDLC loop over
  imprecise spec prose."
- The first epic's eight bugs were mostly integration regressions found only after a merge, each costing a full bug
  cycle.
- **Example (EMI):** the full test step took 1 h 52 min on the loaded laptop and 21 min on a runner.
- **Drift to watch** [USER, repeated]: "targeted" keeps creeping back toward the whole suite. One fix pass ran 4,345
  tests, and a Reviewer re-ran everything. Every brief now says: select by path, name each path's reason, never the full
  suite.

**(d) Plugin edits.**
- `templates/rules/quality-gate.md`: rewrite the seed into two levels (proposed text in §4.1).
- `skills/story-implementation/SKILL.md`:
  - §2, replace L70 with: "Run the targeted set of `quality-gate.md` §Per story, red test first. Run the full set only
    when the project's quality gate defines no targeted set (classic lane)";
  - add a report EVIDENCE line: `- targeted: {command} — selected because {reason}: {counts, exit}`;
  - §1b step 3 and §2b: the same substitution. A fix pass re-runs only what it touches.
- `skills/story-review/SKILL.md`:
  - §2 Quality lens: "re-run the story's targeted set once, independently";
  - add a **Selection** check: "every consumer of a changed symbol and every whole-tree check the change feeds is
    selected; an omission is MANDATORY".
- `agents/developer.md` L34 and `agents/reviewer.md` L16: point at the targeted set.
- `briefs.md`: add a `SELECTION:` / `CHECKS:` slot to the Developer, fix-pass and Reviewer templates (Appendix F).

### C2 — One review round; one fix pass verified by the PM's diff read (return budget 1)

**(a) Plugin today.**
- `skills/sdlc-state/SKILL.md` §4, tier table L105–113: story return budgets are 1, 2 and 3 by tier.
- `skills/sdlc-state/SKILL.md` §4, "Return budget and parking" L153–162: parked at the budget.
- `commands/start.md` L188–196: the budget gate ("one more round", "accept", "park").
- `skills/story-review/SKILL.md` §4 L50–68: the verdict by round, and the re-review scope law for round 2 and later.
- `briefs.md` Reviewer L262: round 2 and later carry PRIOR REVIEW and PRIOR HEAD.
- `skills/sdlc-dispatch/SKILL.md` §3 L70: "You MUST NOT … re-read the diff … or dispatch a second Reviewer."

**(b) What EMI does** [RULE quality-gate.md §Review and merge; PRACTICE].
- **Exactly one review round, at every tier.** The tier still decides the lenses, and whether an IMPORTANT finding
  blocks in round 1. **Example (EMI):** a critical-tier Reviewer brief says "an Important finding in round 1 blocks; a
  review with only NOTEs is APPROVED".
- **Blocking findings get one fix pass**, done by a **fresh** Developer named `developer-{ID}-fix`:
  - its brief names each blocking finding, the fix expected and the red tests;
  - it names which notes **not** to act on, and says "do not merge the feature in; the PM's merge handles that";
  - the fix pass re-runs only what the fix touches and quotes the counts.
- **The PM verifies the fix pass by reading its diff against the findings.** This is not a re-review. The PM records a
  decision or report line: "fix pass verified by the PM reading `<sha range>` against I1 (and N-x) — no second review
  round". The item then goes straight to `ready_for_merge`.
- **A story returns to the Developer at most once.** Under the fast lane the return budget is 1 at every tier. `returns`
  is still incremented; for example, a critical story ends with `returns: 1`.
- **Evidence-only fix pass.** When the only finding is missing evidence, the pass runs the one command and quotes its
  counts, with no code change [PRACTICE].
- **Prose never blocks.** A finding about story, use-case or spec prose, when the implemented behaviour is right, is a
  NOTE, never a return (C3) [RULE].
- **A fix pass that does not fix the finding: not observed.** The rule allows no second return. The plugin's parking
  gate is the natural outlet (open question Q2).

**(c) Why.**
- Every return costs a fresh Developer plus a fresh Reviewer, which is two full context loads. In EMI each agent
  carries about 400 KB of always-loaded rules (C18).
- The user named "8 laps over imprecise spec prose" as the thing to stop.
- The fix pass is scoped to named findings, so reading its diff is cheap. The sources show no gate red traced to a
  story fix pass. One *batch* fix, verified the same way, did introduce a flaky test, which the full gate caught (C6).
  The other gate reds came from cross-epic merges (C6, C10).

**(d) Plugin edits.**
- `sdlc-state` §4 tier table: add a lane override row: fast lane, 1 review round, 1 return at every tier, fix pass
  verified by the PM's diff.
- `sdlc-state` §5: new rows (§4.3).
- `sdlc-dispatch` §3 L70: add the exception text (§4.3).
- `story-review` §4: "under the fast lane there is no round ≥ 2; the re-review scope law applies to the classic lane
  only".
- `briefs.md`: a new **Developer — fix pass** template (Appendix F2).
- `start.md` budget gate: in the fast lane, fire it when the PM's diff check finds a blocking finding still open. This is
  proposed, not observed.

### C3 — NOTEs never return a story: the epic notes file

**(a) Plugin today.**
- `story-review` §3 L38: a NOTE is a "have you considered" with zero obligation.
- The review document has a `## Notes` section (L97).
- `sdlc-dispatch` §3b L76–84 routes Follow-ups, OUT OF SCOPE lines and `Rule gap:` proposals, but nothing routes
  NOTEs. They die in the saved review.

**(b) What EMI does** [RULE quality-gate.md §Review and merge, §Batch end step 4; PRACTICE for the format].

1. **What a NOTE is.** A NOTE is either of:
   - a Minor finding;
   - a finding about the prose of a story, use case or spec when the implemented behaviour is right.

   **A NOTE never returns a story.**
2. **Where NOTEs go.** The PM appends every NOTE of every review to `docs/reviews/{EPIC-ID}-notes.md`. The file is
   PM-only and lives on main, like the follow-ups file. The PM groups NOTEs under a heading per review and writes one
   line per NOTE (format in Appendix B), each with:
   - a **project-wide number** `N-{n}`;
   - a **category**;
   - the text.

   Categories seen: test, prose, prose (System Analyst), style, docblock, contract, named arguments, selection,
   performance (later), rule gap (Architect), rule text (Architect), planning (for {stories}), "for the {EPIC} merge",
   "Architect ruling before {STORY}".
3. **One resolution per NOTE at batch end.** Every NOTE gets exactly one of:
   - **→ fixed in the batch ({sha})**, by the pre-gate batch fix (C6);
   - **→ FU-{n}**, a follow-up under a new or existing ID;
   - **dropped: {one-line reason}**;
   - **→ carried to {EPIC} as N-{m}**, when it belongs to another epic's next merge or story.
4. **Architect decisions.** A NOTE that needs one is ruled mid-flight, before the dependent story, when a later story
   builds on it (C12). Otherwise an Architect triages the rule-gap notes at batch end, in parallel with the batch-fix
   Developer [PRACTICE].

**(c) Why.** NOTE-level and prose findings used to cost full rounds. Kept in a file, the cheap ones land in one pass on
the merged tree, and rule gaps stay visible to the Architect instead of vanishing into saved reviews.

**(d) Plugin edits.**
- `sdlc-state` §1 L27: add the notes file to the PM-only documents.
- `sdlc-state` §4: a new **Notes** subsection with the line format and the four resolutions.
- `sdlc-state`: a new counter `note`.
- `sdlc-dispatch` §3b: a new row, "Reviewer `## Notes` (any verdict) → append one `N-{n}` line per note to the notes
  file".
- `start.md` batch end: a "resolve the notes file" step.
- `story-review` §5: keep NOTEs in the document, and state that they never affect the verdict.

### C4 — No per-story QA, no per-merge regression: the fast-lane state machine

**(a) Plugin today.**
- `sdlc-state` §4 Story L89–99: `… in_review → ready_for_qa → in_qa → ready_for_merge → merged → done`, with `merged →
  done` only after regression QA.
- The tier table's QA row.
- `start.md` dispatch map L164–169: `ready_for_qa` goes to QA, `merged` to QA regression on the feature branch, and
  epic `deployed` to QA regression on main.
- `start.md` Merge flow L198–200.
- `skills/story-qa/SKILL.md`: standard and regression modes.
- README L47 and L73.
- The CLAUDE.md managed block in `commands/init.md` L137: "then Reviewer, then QA, then Deploy".

**(b) What EMI does** [RULE quality-gate.md §Enforcement: "QA does no QA per story, at any tier"; §Review and merge:
"There is no regression QA after a story merge"; PRACTICE: the transitions below are traced from the log].

The story machine as actually run:
```
todo → in_progress → ready_for_review → in_review ──APPROVED──→ ready_for_merge ──Deploy MERGED / PM fast-forward──→ done
                                            └─REJECTED→ review_rejected → in_progress (fix pass) ──PM diff check──→ ready_for_merge
```
- `ready_for_qa`, `in_qa`, `qa_rejected`, `merged` and `regression_failed` are unused.
- The skipped stages leave decision lines: `"QA skipped: fast lane"` and `"regression QA skipped: fast lane"`.

The epic machine as actually run:
```
ready → in_progress ──batch full gate PASSED──→ ready_for_deploy ──delivery MERGED──→ deployed ──decision: main regression skipped──→ done
```
- QA's only job is the batch-end full gate (C6).

**(c) Why.**
- Per-story QA and per-merge regression each re-ran the whole suite per story. The batch gate, on the merged tree with
  `main` in it, is the regression.
- A story merge that runs no gate can run beside other agents of the same epic [PRACTICE: the decision adopting the
  fast lane].

**(d) Plugin edits.**
- `sdlc-state` §4/§5: a lane-dependent machine (§4.3).
- `start.md` dispatch map: rows conditional on `process.lane`.
- `story-qa`: a new **Mode: batch gate** (full gate plus a report file, Appendix D and F7). Standard and regression
  modes stay for the classic lane.
- `agents/qa.md`: update the description.
- README L47 and L73, and the CLAUDE.md managed block in `init.md` L137: lane-aware wording.

### C5 — Whole-tree checks: selected by the fact they encode, re-run on the merged tree

**(a) Plugin today.** There is no concept of a whole-tree check. Deploy runs the full gate after every merge
(`story-merge` protocol step 4, L24), which the fast lane removes.

**(b) What EMI does.** Two halves of one hazard. They stay separate because they fire on different events.

1. **The Developer's half** [RULE quality-gate.md §Per story, "A whole-tree check is selected by the fact it encodes"].
   Some checks state what the whole tree must contain. **Example (EMI):**
   - the tables the migrations create, and the migration head;
   - the task-queue and workflow registration map;
   - the route set of each deployment role;
   - the published API header parameters;
   - that no inter-module port imports a domain type.

   A story invalidates such a check by *adding a fact*, without touching the check or anything near it. So the quality
   gate keeps a **closed list** of such checks that live outside the always-run architecture-test directory, each with a
   "selected by a change that …" column. A story that builds a new whole-tree check outside that directory adds its row
   in the same change. The better home is the always-run directory, which needs no row.
2. **Deploy's half** [RULE quality-gate.md §Review and merge, "A changed whole-tree scanner runs again on the merged
   tree"]. When a story **changes a scanner** (the architecture tests, the dependency-seam rules, a repository guard
   script, a suite that reads every other suite), Deploy re-runs that scanner on the merged tree after the merge and
   quotes its counts. A red result is VERIFICATION_FAILED.
3. **A pure fast-forward needs no re-run.** The merged tree is byte-identical to the reviewed tree; the PM checks that
   `git diff {story} HEAD` is empty [PRACTICE].
4. [PRACTICE, stronger than the rule] A real merge (not a fast-forward) always gets **whole** static analysis on the
   merged tree (C10).

**(c) Why.** **Example (EMI):** one story added a table and an every-queue workflow activity. Two whole-tree checks went
stale and stayed red on the feature branch and on `main` until a later story's Developer found them. That case wrote
the rule.

**(d) Plugin edits.**
- The quality-gate seed: a "Whole-tree checks" subsection with the closed-list table (§4.1).
- `story-review`: the selection judgement includes these checks.
- `story-merge`: "re-run every whole-tree scanner the merged story changed; a pure fast-forward needs none (prove the
  tree identity)".

### C6 — The batch end: the full gate once per batch

**(a) Plugin today.** `start.md` "Deploy flow: epic → main" (L204–222), run when every item is done and no follow-up is
open:

1. Deploy merges the epic into `main` in the main working copy, with every other dispatch paused (briefs L326–338;
   `story-merge` working-directory table).
2. QA runs regression on `main`.
3. The PM pushes.
4. The PM archives the epic.
5. A refinement dispatch follows.
6. A blocking demo gate ends the flow.

**(b) What EMI does** [RULE quality-gate.md §Batch end steps 1–5 and the `run-checks` skill; PRACTICE for the
ordering, branch names and hand-offs, traced over four epics on one day]. The numbering below is this document's.

1. **The batch is complete.** Every story of the batch is merged into the feature branch.
2. **Main-in** (RULE step 1). Deploy merges `main` into the feature in the epic's merge worktree. Resolution by class:
   - **docs and rules take `main`'s side**, because `main` holds the final form of every ruling, while the feature may
     hold cherry-picked earlier versions. Afterwards `git diff origin/main HEAD -- .claude docs/adr` must print nothing;
   - **generated files are regenerated, never hand-merged**;
   - **config, tests and code are combined**;
   - **anything that is not a combination** means `git merge --abort` and MERGE_FAILED.

   Verification on the merged tree:
   - whole static analysis in every configuration;
   - a broad selection of the modules both sides touched;
   - the whole-tree checks and replay;
   - the client drift checks;
   - the content guard;
   - both ancestry checks, a zero-line state diff against `main`, and the conflict-marker scan.

   **Green** → Deploy pushes the feature. **Red** → Deploy pushes the merge to `fix/{EPIC}-main-in`, leaves the feature
   untouched, and reports VERIFICATION_FAILED with the failures grouped by cause.
3. **Batch fix, before the gate** [PRACTICE]. A Developer works on `fix/{EPIC}-batch` (or `…-batch-notes`), branched
   from the main-in merge. It fixes:
   - **(i) meeting defects**: silent collisions between epics that a textual merge does not flag. Seen classes: callers
     left on a changed signature (tests from `main` calling a function the feature changed); test doubles missing a
     method added to an interface; tests asserting the pre-change error envelope; message-catalogue keys missing for a
     new code; fixtures missing a new prerequisite (sign-up now requires a published legal text); a configuration map
     entry added on one side only;
   - **(ii) the notes the PM chose to fix in the batch** (C3);
   - **(iii) cross-cutting follow-up obligations that now apply to the merged tree.**

   It runs a targeted set, never the full suite. The PM verifies the diff and fast-forwards the feature to the fix head.
4. **Full gate** (RULE step 2). QA runs it in batch-gate mode, on a cheaper model (C17), usually on a runner (C14):
   - Step 0, then every row of the path-to-command table whose glob matches `git diff --name-only main...{feature}`,
     sequentially and in order;
   - **phase 1** runs on the laptop without a stack: the content guard, the stackless rows and the conflict-marker scan;
   - **phase 2** runs on the runner: `up`, then the core row, then the client rows;
   - QA first proves that the slot holds exactly the gated tree: HEAD, tree hash and a clean status, on both sides.

   QA writes a report file in the precedent's table format (Appendix D). The PM saves it as
   `docs/reports/{EPIC}-batch-gate.md`, and a failed run as `…-gate-run{N}.md`.
5. **Fix loop** (RULE step 3). On a red step QA fixes nothing: it reports the failing command, its output and the
   reproduction. Then:
   - a Developer ("fix loop") works on `fix/{EPIC}-gate-run{N}` from the gated sha;
   - it runs a targeted set, and the PM checks the diff and fast-forwards;
   - QA re-runs from the failed step, and re-runs the formatter and static analysis first if code changed after they
     passed.

   This is a fix loop, not a review-and-QA cycle, and never a bug.
6. **Re-merge and re-gate when `main` gained code during the gate** [PRACTICE]. **Example (EMI):** one epic's run 2
   passed, but `main` had meanwhile received another epic's delivery. Deploy ran a second main-in, and QA ran run 3 on
   the merged tree. When `main` gained only docs, state or rules, no re-gate is needed; the delivery merge takes main's
   side for those files.
7. **Notes and follow-ups** (RULE step 4). Every NOTE is resolved (C3), and the open follow-ups are triaged (C8).
8. **Delivery** (RULE step 5; C9).

**(c) Why.**
- Nothing reaches `main` without the full gate, and merging `main` in first means the gate proves what will ship.
- **Example (EMI), all on one day:**
  - one epic's run 1 went red in static analysis, on three tests from `main` still calling a signature a story had
    changed;
  - another epic's run 1 went red on a flaky counter test introduced by its own batch fix;
  - main-in merges on three epics surfaced meeting defects, four of them on one epic. That epic's fix commits were
    cherry-picked into the other two epics' batch fixes (C11).
- The fix loop replaced "one bug per red step", which had cost a full pipeline cycle each.

**(d) Plugin edits.**
- `start.md`: replace "Deploy flow: epic → main" with a **Batch end** section (§4.2).
- `sdlc-state` epic transitions (§4.3).
- New brief templates: Deploy main-in (F5), Developer batch fix (F9), QA batch gate (F7), Developer fix loop (F11).
- `story-qa`: batch-gate mode.
- `story-merge`: main-in mode.

### C7 — Batches and batch cuts inside an epic

**(a) Plugin today.** The epic is the unit of delivery. `ready_for_deploy` requires every item done (`sdlc-state` §4
Epic L181; `start.md` L206).

**(b) What EMI does.**
- [RULE] "A batch is the stories merged into one feature branch between two deliveries to `main`, by default one epic."
  The PM may cut a batch early.
- [PRACTICE] A cut is recorded as a decision line naming the batch's members and the reason. Items outside the batch are
  not dispatched. The batch delivers through the full batch end ("batch delivery"), and **the epic stays `in_progress`**
  for its later batches.
- **Example (EMI):** an epic's first four stories were delivered early, because three other epics built on its
  permission catalogue.
- For milestones, cutting batches inside epics was later replaced by recutting epics whole (C13) [USER].

**(c) Why.** Unblock downstream epics without waiting for a large epic to finish.

**(d) Plugin edits.**
- `sdlc-state` epic machine: after a batch delivery the epic returns to `in_progress` when items remain.
- An optional epic field `batches: [{items, delivered_at, merge_sha}]`, or a decision-line convention.
- `start.md`: a "cut a batch" PM action with its log line.

### C8 — Follow-up triage replaces the hygiene-bug gate

**(a) Plugin today.**
- `sdlc-state` §4 Follow-ups (L138–151) and the Epic definition (L181): `ready_for_deploy` needs zero open follow-ups.
- `start.md` L206: open follow-ups mean one hygiene bug, and the epic waits for it.

**(b) What EMI does.**
- **Triage at the batch end** [USER decision on the first epic, "batch-end follow-ups by triage"]. Each open follow-up
  gets one of:
  - infrastructure or operations hardening → the deferred hardening epic;
  - stale or documentation-only → dropped, with a reason;
  - everything else → **carried forward by ID** to the epic that will touch its files;
  - gate-breaking or correctness items only → **one small** hygiene bug.
- **Delivery does not wait for zero open follow-ups.** The release notes list follow-ups by existing IDs only [RULE].
- **Line conventions** [PRACTICE]:
  - numbers come from one project-wide sequence;
  - a line may carry `owner: {STORY or BUG ID}`;
  - a closed line gets `— closed by {ID}: {how}`;
  - `origin:` may name a review note (`docs/reviews/{ID}-1.md N5`).

**(c) Why.**
- A hygiene bug holding every follow-up blocked delivery on unrelated work.
- Many follow-ups belong to files a later epic will touch anyway (the plugin's own "close in passing" idea, applied
  across epics).

**(d) Plugin edits.**
- `sdlc-state` §4 Follow-ups: add `owner:`, the closure text and the triage outcomes; change the Epic `ready_for_deploy`
  condition.
- `start.md` L206.
- A config key `process.followups_gate: triage | hygiene_bug`, default `triage`.

### C9 — Delivery merge with release notes; main regression skip; archive

**(a) Plugin today.**
- briefs Deploy epic merge L326–338: the main working copy, the PM pauses all dispatches, Deploy does not push.
- `story-merge` L25: the commit is `{PREFIX}: Deploy {EPIC-ID} ({title}) to main [by Deploy]`.
- `start.md` L206–222: QA regression on main, push, archive sweep, refinement, demo gate.

**(b) What EMI does** [RULE quality-gate.md §Batch end step 5 for the message; PRACTICE for the mechanics].
1. **Where.** Deploy works in a **temporary detached worktree from a freshly fetched `origin/main`**, never in the main
   checkout: the PM keeps writing state there, and the tracker reads it (C20).
2. **No global pause.** The PM holds only **its own pushes to `main`** until Deploy reports. If `main` moves anyway,
   Deploy redoes the merge.
3. **The merge.** One `git merge --no-ff {gated sha} -F {message}` with the release notes as the commit message
   (Appendix E):
   - **What changed**, by behaviour area with story and bug IDs, the batch fixes with their N-IDs, and an "Already on
     `main`" list;
   - **Order of application** (for example, migrations before any role, infrastructure roots before the image);
   - **Before merge / deploy**: migrations, configuration, secrets, IaC applies and operator steps, with explicit
     "no new …" lines;
   - **Follow-ups**, by existing IDs only;
   - **Test plan**, with the real numbers from the gate: tests and assertions, histories replayed, client test counts,
     drift results, and rows not applicable with their evidence.
4. **Conflicts.** A conflict can only be in docs or state, and keeps `main`'s side. A code conflict means `git merge
   --abort` and MERGE_FAILED.
5. **Verification:**
   - both ancestry checks, each exit code read on its own line;
   - per-directory change counts;
   - **code equality to the gated sha**: `git diff --name-only {gated sha} HEAD -- {code dirs} | wc -l` must print 0;
   - the content guard.
6. **Push.** A plain push, never forced. If it is refused: fetch, confirm the new commits are docs or state only, redo
   the merge and the verification, and push again. Confirm with `ls-remote`. Remove the temporary worktree, and the
   epic's merge worktree when it is clean and at the gated sha.
7. **Main regression is skipped** when `main` gained only docs, state or rules since the gated merge. The decision line:
   "main regression QA skipped: the full gate ran on the delivered code and main added only documents and state since
   (fast lane)". Then the epic goes `done`, with the archive sweep in the same PM step. `main` never gains unproven code
   here, because code arriving during the gate forces a re-gate (C6 step 6).
8. **Refinement** is not dispatched automatically when a milestone plan is the live refinement [PRACTICE].
9. **No demo gate** (C13).

**(c) Why.**
- The tracker reads the main checkout.
- Pausing the whole pipeline for a merge wasted parallel capacity.
- The release notes are what an operator needs for a real deployment.
- Main regression would re-run an identical code tree.

**(d) Plugin edits.**
- `story-merge`: a new **Mode: delivery**.
- `briefs.md`: the Deploy delivery template (F6).
- `start.md`: the Deploy flow.
- `sdlc-state`: epic `deployed → done` by a decision line.
- The config key `process.main_regression` of C26 (`always | if_main_gained_code | never`), with
  `process.docs_only_paths`, the list of the paths that count as docs.

### C10 — Merge mechanics

**(a) Plugin today.**
- `story-merge` protocol L19–26:
  - the full gate after every merge;
  - VERIFICATION_FAILED means "do NOT commit a fix — the PM registers a bug";
  - L26: "Do NOT push".
- `sdlc-dispatch` §2 L48: Deploy is exclusive; never two merges at once, and never while any agent works on a branch of
  the same epic.
- `start.md` Merge flow L198–200: MERGE_FAILED or VERIFICATION_FAILED keeps `ready_for_merge` and registers a bug.
- `start.md` Git policy L226: the PM pushes feature branches after story merges.
- `agents/deploy.md` L20: Deploy does not own pushing.

**(b) What EMI does** [PRACTICE unless marked].
1. **PM fast-forward.** When the approved story branch contains the feature tip (`git merge-base --is-ancestor {feature}
   {story}`), the PM fast-forwards the feature itself with a plain push:
   - no Deploy dispatch, and no re-run, because the tree is the reviewed tree;
   - the log line reads `fast-forward: {feature} {a}..{b}; worktree removed`, and names any in-flight story that "will
     need a real merge".
2. **Deploy's real merge**, when the story is behind the feature:
   - `git merge --no-ff` in the epic's merge worktree;
   - combination-only resolution (the plugin's law, kept);
   - **generated files are regenerated, never hand-merged**: the API document snapshot, the generated clients, the
     catalogue snapshots and the generated stubs. Each is committed only if it differs;
   - the brief names the **combination checks**: both sides' entries survive in registries and service definitions, and
     every migration is present in timestamp order with the latest as the head.
3. **Whole static analysis on the merged tree.** Every static-analysis configuration runs over the **whole** tree, not
   the changed files. Add the story's module tests, the consumers of changed shared code, the whole-tree checks and
   replay. The reason: a textual merge hides semantic collisions. **Example (EMI):** two story merges went red on a
   caller or a test double left behind a changed interface.
4. **A red verification is pushed to `fix/{ITEM}-merge`, never to the feature.** Deploy reports VERIFICATION_FAILED, and
   no bug is registered.
5. **The merge-fix Developer:**
   - it commits on top of the resolved merge on that fix branch: the smallest change, red first, plus **a search for
     other instances of the collision class**;
   - it runs the targeted set and whole static analysis;
   - the PM verifies the diff and **fast-forwards the feature** to the fix head, and the item goes `done`. The log reads
     "report: Developer (merge fix); PM verified the diff".

   Two variants:
   - **The Developer merges the feature into the story branch** and adapts callers that moved meanwhile, when a plain
     merge would break a check; the PM then fast-forwards;
   - **a reconciling merge before review**, when two stories dispatched in parallel built overlapping ground. The one
     merged second takes the merged one's versions.
6. **Deploy is exclusive per target branch.** One merge into a given branch at a time; later merges queue ("merge queued
   behind {ID}'s"). Deploys into *different* target branches may run at the same time, for example a delivery to `main`
   beside a main-in into another feature. Developers and Reviewers on other branches keep working beside a merge.
   [PRACTICE: the decision "dropped the generic Deploy-exclusive-over-the-epic hold … The binding constraint is the
   user's stack cap, not epic exclusivity"]
7. **Push is part of the merge** [USER]:
   - a green story merge or main-in pushes the feature with a plain push, never forced, and confirms with `ls-remote`;
   - the brief says so explicitly, because Deploy's skill defaults to "never push";
   - if Deploy did not push, the PM verifies (the commit exists, the push is a fast-forward, the merged tree equals the
     reviewed trees) and pushes itself.
8. **Worktree removal.** The story worktree is removed as soon as the item is `done` (disk hygiene).

**(c) Why.**
- Registering a bug for every merge failure cost a full cycle each.
- A red merge pushed to the feature poisons every story that branches next.
- Semantic collisions are invisible to git.
- Epic-wide Deploy exclusivity serialised all work in a large epic.
- A merge left unpushed made the next story branch from a stale tip.

**(d) Plugin edits.**
- `story-merge`: rewrite with modes (story merge, main-in, feature-in, delivery), whole static analysis, red → `fix/`
  branch, and push on green (§4.4).
- `sdlc-dispatch` §2 L48: the exclusivity text.
- `start.md` Merge flow: VERIFICATION_FAILED dispatches a merge-fix Developer on `fix/{ITEM}-merge` instead of
  registering a bug; add PM fast-forward.
- `agents/deploy.md` scope.
- A config key `process.deploy_push: on_green | never`.

### C11 — Cross-epic integration

**(a) Plugin today.** Feature branches are cut from `main` (`start.md` L177), and epics meet only through `main`. There
is nothing about dependencies between epics.

**(b) What EMI does** [PRACTICE; USER decisions].
1. **A feature cut from another feature.** An epic runs in parallel with the one before it while delivery stays linear.
   **Example (EMI), paraphrased from a user decision:** EPIC-2 ran in parallel with EPIC-1's delivery, its feature cut
   from EPIC-1's feature because `main` had no application code yet, and `main` merged in at EPIC-2's batch end [USER].
2. **A story or feature merges another epic's feature** when it needs that code. **This fixes the delivery order**: the
   carrying epic delivers after the carried one. Recorded as a decision line, "delivery order: X before Y". The
   fast-forward lines note "(carries EPIC-X at {sha})".
3. **Feature into feature before both gates.** Deploy merges feature A into feature B ("EPIC-A in"), so B's gate proves
   the tree B will ship after A reaches `main`. **The two gates then run in parallel**, and B's later main-in brings no
   new code.
4. **Cherry-picked meeting fixes.** One epic's meeting-fix commits are cherry-picked (`git cherry-pick -x`) into another
   epic's batch fix, so the two lines carry identical changes and merge cleanly later. A batch fix waits for the other
   epic's fix rather than redo it.
5. **Single-commit prerequisites** (an Architect ruling, a story file) are cherry-picked, never pulled in through a full
   `main` merge (C12).
6. **Carried notes.** A NOTE "for the {EPIC} merge" moves to the other epic's notes file as that file's N-line.

**(c) Why.**
- Milestones span epics, so throughput needs epics in parallel.
- The second delivery's main-in would otherwise re-surface the same meeting defects.
- Keeping delivery linear avoids diverging lines.

**(d) Plugin edits.**
- `start.md`: a new section, "Cross-epic integration".
- Optional epic fields `base_branch`, `carries: [{epic, sha}]` and `delivers_after`.
- A Deploy "feature-in" mode.
- A log convention for delivery-order decisions.

### C12 — Mid-flight Architect rulings

**(a) Plugin today.**
- The Developer reports BLOCKED on a design gap (`agents/developer.md` L28).
- The PM "resolves the blocker" (`sdlc-dispatch` §3 L67).
- A Reviewer's `Rule gap:` is kept "for the Architect's next Design Mode brief — do not act on it yourself" (§3b L83).
- The Architect works per epic in planning, in Design or Review mode.

**(b) What EMI does** [PRACTICE; USER on worktrees].
1. **Triggers:**
   - a Developer BLOCKED on a design question;
   - a review NOTE or rule gap that a later story would build on, ruled **before the next dependent story is
     dispatched**;
   - a **pre-ruling**, dispatched stackless before a story when an open decision is already known, so the Developer
     neither blocks nor guesses;
   - an ordering question.
2. **Where the Architect works.** In its own worktree, on `architect/{ITEM}-{topic}` cut from `main`, editing **docs,
   rules and ADRs only, never code**.
3. **The brief** (F8) poses options (a), (b), (c), asks for "a concrete verdict for each alternative", and names the
   constraints to weigh. It asks for:
   - the ADR or amendment, with every section;
   - the rule text;
   - which story builds it (an existing one, or a new one);
   - what the blocked or next story does meanwhile;
   - the content guard on every touched file.

   The report stays small, about 1,200 characters.
4. **The PM merges the ruling branch into `main` with `--no-ff`.** The merge carries docs and rules only.
5. **The blocked Developer cherry-picks only the ruling commit**, never a full `main` merge. **Example (EMI):** one
   Developer rightly aborted a 302-commit, 11-conflict main merge and applied the ruling commit alone. New dispatches
   from the feature say "cherry-pick the ruling {sha} first". At the feature's main-in, docs and rules take `main`'s side
   (the ruling's final form).
6. **When a ruling needs new scope**, the PM reserves the next story ID and a System Analyst cuts **one** new story into
   the epic.
7. **At batch end**, an Architect triages the rule-gap notes on a planning branch, in parallel with the batch-notes
   Developer.

**(c) Why.**
- A guess costs a full rework, and waiting for the next Design Mode stalls the epic.
- Pulling all of `main` into a story branch drags in other epics' code and conflicts.

**(d) Plugin edits.**
- `skills/architecture-design/SKILL.md`: a new **Ruling mode**.
- `briefs.md`: the Architect ruling template (F8).
- `sdlc-dispatch` §3b: the `Rule gap:` row becomes "dispatch a ruling now if a later story builds on it; otherwise keep
  it for Design Mode".
- `start.md`: when to dispatch a ruling, the branch naming, `--no-ff` into `main`, and cherry-picking by the Developer.

### C13 — Milestones: demo slices, whole-epic recuts, the demo on the user's word

**(a) Plugin today.**
- Epics run in `priority_order`.
- A **blocking demo gate** follows every epic (`start.md` L211–221), skipped only with `--no-human`.
- There is no notion of a milestone.

**(b) What EMI does.**
1. **A milestone is a demo the user decides.** It is planned in a **demo-slice document**, `docs/reports/demo-slice-{N}.md`,
   a template candidate [PRACTICE; structure from four such documents]:
   - who decided it, and when; who cut it;
   - **The demo**: numbered steps, each naming the stories that deliver it, and each step the application cannot do yet
     named as scripted;
   - **In and out**: "Out, and staying out until the demo runs";
   - **How the slice is planned**: a System Analyst verdict per prerequisite (already satisfied; a named minimal slice
     written into both story files; or pulled in whole), the Architect design pass owed, and the Product Manager's
     placement;
   - **The slice by epic**, with counts;
   - **Placement**: a table of story, from-epic and to-epic;
   - **Design owed**;
   - **Build order**: runner lanes in order, each with "waits for";
   - **The demo's local configuration**;
   - **The final count**.
2. **Milestone epics are cut whole** [USER]. Every epic that gives a milestone some but not all of its stories is split
   before the milestone's first story starts:
   - the milestone part **keeps the original epic ID**, because branches, notes and gate reports are already named by
     it;
   - the remainder becomes a **new epic** with status `ready` and its own `epic.md`, and the original gets a
     `**Continued by:**` line;
   - the Product Manager does the recut; the PM re-parents the items in state and moves the remainder to
     `backlog.json`; story files stay where they are;
   - the log carries `recut` lines;
   - prerequisites pulled into a milestone from another epic are handled the same way.
3. **Demo only on the user's word** [USER]. It is never a gate. After a delivery the PM keeps going: it plans the next
   epic the user named, continues the in-flight epics, and runs overnight. The PM:
   - records a decision line;
   - offers the demo when the user returns;
   - never cuts a batch early to reach a demo.

   Demo preparation, when asked for, is dispatched to a top-tier agent: a runner slot at `main`'s tip, demo data created
   through the system's own paths, and a helper script and runbook in a local folder **outside** the repository. It
   reports "demo READY".
4. **Progress against milestones** [PRACTICE; only this much is confirmed]:
   - each delivery's decision line names the milestone and the running count, for example "milestone 4's fifth
     delivered epic" or "milestone 3 complete ({epics} delivered)";
   - the slice document's final count is the reference.
5. **Just-in-time planning depth** [USER-confirmed decision]. Only the next epic by priority is broken down and designed
   while the current one implements. Milestone planning is the slice, the recut and the design pass.

**(c) Why.**
- The user wants the tracker to show a milestone as whole epics. The user, correcting the PM (translated): "one epic
  cannot hold a couple of milestone-3 stories with the rest for later — it must be cut into two epics".
- The user wants continuous work, overnight included, with demos at a time they choose.

**(d) Plugin edits.**
- The `start.md` demo gate becomes configurable: `process.demo_gate: on_request | blocking | off`, default
  `on_request`.
- A new `templates/demo-slice-template.md`.
- `brd-writing` (Product Manager): a "milestone recut" mode.
- `story-breakdown` (System Analyst): a "milestone slice" mode.
- Optional epic fields `milestone` and `continued_by`; C29 makes the milestone a state entity of its own.
- `commands/status.md`, and optionally the tracker: progress grouped by milestone; C29 specifies it.
- A config key `process.planning_depth: just_in_time | all`.

### C14 — Remote Compose-stack runners

**(a) Plugin today.**
- Every stack runs locally. Ports are allocated per worktree (`sdlc-state` §6 L330).
- QA runs `docker compose up` in the worktree (`story-qa` L29–31).

**(b) What EMI does** [PRACTICE; tooling kept outside the repository, next to it; described generically here]:
- **Identical runners.**
  - The runners are rented VMs provisioned by one idempotent script, with pinned tool versions, that ends by printing a
    fingerprint.
  - A check script re-runs the provisioner on every runner and diffs the fingerprints; it exits 1 on drift.
  - Runners are never configured by hand, and are added one at a time: two concurrent adds once corrupted the shared SSH
    config.
- **No secrets on a runner.**
  - A runner holds a bare repository that the laptop pushes to, and holds **no source-host credential**.
  - Each stack's secrets are generated on the runner by the stack's own `up`, into an ignored env file.
  - Only SSH comes in.
  - Reference material never goes to a runner.
- **Slots.**
  - A runner has slots `a`–`d`. A slot is one work tree plus one Compose project, with its own host-port block bound to
    localhost.
  - A runner below a size threshold takes one slot. Measured: the full gate peaks near 3.3 GB of RAM, so a 2 vCPU / 4 GB
    runner is tight but works.
  - On a small runner the gate runs in two phases: the stackless rows first with the stack down, then `up` and the core
    row, then `down`.
- **`runner-slot {NN} {slot} {sha}`** — **a SHA, never a moving branch**. It:
  - pushes the commit to the slot's branch;
  - creates the slot's work tree or moves it to that commit (the tree must be clean; `RESET=1` discards local changes);
  - writes the slot's env file, keeping the secrets `up` generated;
  - installs dependencies when a lock file changed.

  It starts nothing.
- **`run-step start|wait {NN} {slot} {name} …`**, which runs one step detached:
  - the command travels to the runner as a file, so there is no nested quoting;
  - the output goes to `{name}.log`, and `{name}.done` holds the exit code and seconds, written at the end;
  - `wait` polls for at most about 540 s, under one tool call.

  `wait` exits with:

  | Exit | When |
  |---|---|
  | the step's own code | the step finished |
  | **3** | the step exited 0 but the log is **empty** (unless `--allow-empty`, for steps whose green is silence, such as a breaking-change check or a drift check) |
  | **3** | the log does not match `--expect {regex}` |
  | **124** | the step is still running; call `wait` again |

  The exit code is read on its own line.
- **Start tokens and pending markers.**
  - `start` removes the local token and writes a local **`.pending` marker**. It writes a fresh token beside the step's
    files on the runner, and writes the local token **only after the launch succeeded**, then drops the marker.
  - `wait` refuses (exit 3) when the marker says the last start failed, or when the runner's token differs from the
    local one, meaning the result belongs to another start.
  - **Why:** a failed `start` once left the previous run's `.done` in place, and `wait` read its old exit 0 as this
    run's pass. A story found it.
- **`runner-sync {NN} {slot} {worktree} [--pull {paths}]`**, for a Developer's or Reviewer's stack on a runner:
  - the worktree stays on the laptop; what is pushed is git-visible content (tracked plus untracked-not-ignored),
    incrementally by tar in about 1.5 s, deletions included; ignored paths (dependency trees, caches, the env file) are
    never touched;
  - `--pull` brings back files a remote tool wrote (a formatter fix, an API dump, a client generation, stub generation)
    **before the commit**;
  - **clear the sync cache after a merge or cherry-pick in the worktree**, so the next sync is full: an incremental sync
    lost a file that had been in conflict during a merge;
  - a service that bind-mounts a single file keeps the old inode after a sync; recreate that service.
- **Resetting a slot.** `make down VOLUMES=1`, then `RESET=1 runner-slot …` hands the slot to the next item. The worktree
  entry in `project.json` records its runner, as `"runner": "{runner} slot {x}"`.
- **Use:**
  - batch gates first: a gate is a pure function of a pushed commit, and the QA brief names the runner and slot;
  - then Developer and Reviewer stacks: the PM or the agent sets up the slot at the base sha and starts `up`;
  - reviews re-run on the story's own slot.
- **Known gaps:**
  - **no Playwright browser** on the runners, so E2E specs stay on the laptop;
  - **runners run as root**, which breaks one permission-sensitive test (red only as root; it is excluded there and
    shown green on the laptop);
  - calibrate every new runner against a known gate run (same test count).
- **Measured:** the full test step took 21 min on a 4 vCPU / 8 GB runner against 1 h 52 min on the loaded laptop. The
  whole gate takes 29–41 min end to end.

**(c) Why.**
- The laptop's stack budget (C15).
- A failing local container engine (C24).
- False passes from hand-quoted `ssh … nohup …` lines. One such line reported a pass for a step that ran nothing.

**(d) Plugin edits.**
- An **optional** runner integration: config `integrations.runners: {enabled, tooling_dir, inventory}`.
- A `runner` field on worktree entries.
- A `STACK:` slot in the Developer, Reviewer, Deploy and QA briefs.
- `story-qa` batch-gate mode: a "remote gate" procedure.
- The evidence reference (C19): exit codes 3 and 124, start tokens, `--expect`, and why an empty log is red.
- Ship at most a generic reference implementation of `run-step` (start/wait/tokens) and `runner-sync`, never hosts.

### C15 — A local stack budget, separate from the teammate cap

**(a) Plugin today.**
- `max_parallel_teammates` (default 4, `init.md` L68) counts working agents.
- Ports are allocated per worktree.
- There is no limit on concurrent stacks. The sibling plugin's per-repository `gate_concurrency` lock is the nearest
  thing (C27).

**(b) What EMI does** [USER, including a correction of the PM].
- **At most 2 agents may hold a running Compose stack on the laptop.** An agent that only reads code, writes documents
  or plans does not count. **The cap is on stacks, not on agents:** the PM was corrected for leaving teammate slots idle.
- **Runner slots come on top** of the two.
- The PM queues stack-bound work, pairs it with stackless work (planning, an Architect pass), and says so in the
  narration when a dispatch waits.
- Under load, one test process per agent.
- When disk is tight, the worktrees of done items are removed ahead of the epic-end sweep.
- The teammate cap was raised from 4 to 6 by the user.

**(c) Why.** Six agents each brought up a stack of about ten containers. The machine thrashed: the container VM
OOM-killed a workflow engine and a broker, one run died with "disk full", and one image rebuild took 35 minutes. None of
the six finished.

**(d) Plugin edits.**
- A config key `max_local_stacks`, default 2.
- `sdlc-dispatch` §2: a "stack budget" rule beside the teammate cap.
- A brief slot `STACK: none | local | runner {NN} slot {x}`.

### C16 — Teammate lifecycle and recovery

**(a) Plugin today.**
- `start.md` L59–63: teammates by default, fallback to subagents.
- `sdlc-dispatch` §4 L88–108:
  - TaskStop release after verification;
  - rework to a fresh agent;
  - "Resuming a finished agent by name is ONLY for report fixes";
  - count only working agents.
- `sdlc-dispatch` §3 L68: an agent that died is re-dispatched on the next `/start` (stale-worktree check, `start.md`
  L107–111).

**(b) What EMI does.**

| # | Situation | Practice | Label |
|---|---|---|---|
| 1 | Dispatching | Named teammates, each in its own terminal pane. **Never a silent fallback to background subagents.** If spawning fails, say so in the same turn and name the fallback. First try the cheap fixes: release dead panes, close them, keep the window maximised, lower the parallelism. | USER |
| 2 | Cap | Count working teammates only (kept from the plugin). The stack budget (C15) is a second, independent cap. | kept + USER |
| 3 | Release | TaskStop immediately after verification (kept). Reason added: lingering panes use up window room, so new panes fail to open. | kept + USER |
| 4 | Rework | A fresh teammate, named `{role}-{ID}-fix` for the fix pass (kept). | kept |
| 5 | Account session or usage limit | Every teammate stops at once. After the reset the PM sends each one a message: "continue from where you stopped; read your runner step through the start tokens, never an old log as a pass". A decision line records the stop and the resume. | PRACTICE |
| 6 | Connection dropped mid-response | Message: "check `git status` and the log for what is written and committed; commit what is complete; carry on as briefed; send the envelope". | PRACTICE |
| 7 | A teammate thrashing on context | Replace it with a **fresh** teammate and a **narrow** brief: only the named files, grep and tail, never cat large or generated files. It inspects the dead session's uncommitted diff first, and keeps what is sound. | PRACTICE |
| 8 | Planned hand-off | After about 4–5 tasks, or when the context is heavy, the agent stops at a task boundary, commits, pushes and reports `BLOCKED` with `CONTINUE: next task = …`. The PM dispatches a continuation at once. A continuation first commits the dead session's tree as a checkpoint. | USER |
| 9 | Truncated report | The PM sends a message asking the same teammate to "resend only the rest of DETAILS from '{last words}' to the end; no new work". | PRACTICE |
| 10 | Session lost (older practice) | Re-dispatch on the existing worktree, telling the agent that work may already exist; a decision line records the commits found. | PRACTICE |

**(c) Why.**
- The user wants to watch the pipeline in panes. A silent fallback left eleven agents with three stale panes, and the
  user had to ask what was happening.
- Limits hit every agent at once.
- A restart from scratch loses work.
- The transport truncates reports near 5,000 characters.

**(d) Plugin edits.**
- `sdlc-dispatch` §4:
  - allow a SendMessage resume for *interrupted* work (limits, connection), still never for *rework*;
  - add the recovery table above.
- `start.md` execution modes: "never a silent fallback".
- `story-implementation`: the planned hand-off rule, and a `CONTINUE:` field in BLOCKED reports.

### C17 — Model tiering per role

**(a) Plugin today.**
- No agent pins a model.
- README L93: "agents inherit your session's model".
- README L102: set "Default teammate model" to the leader's model.

**(b) What EMI does** [USER; PRACTICE].
- **Judgement roles never go below the top tier.** These are the Architect, Developer, System Analyst, Reviewer and
  Product Manager.
  - Omit `model`, so they inherit the PM session's **large-context** model.
  - An explicit `model: "opus"` gave a 200K window, and two Developers died of thrashing on about 400 KB of
    always-loaded rules. The window explanation is the PM's hypothesis, recorded as unconfirmed.
  - When the PM session runs another model, set the top tier explicitly for the Developer, Reviewer and Architect.
  - Use a different model only where the user asks for it (so far, planning).
- **Procedural roles run on a mid tier (Sonnet):** Deploy in every merge mode, and QA in gate or regression mode.
- **Never the smallest tier on anything that quotes gate evidence**: the exit-code traps and the counts-not-silence rule
  are exactly what a weak model misreads.
- A mid-tier report that fails the evidence check is re-dispatched once on the top tier, and noted.
- Log notes name the model ("Sonnet; FULL GATE …").

**(c) Why.** Cost and throughput for procedural work; judgement quality for design and code; the context window for
large rule sets.

**(d) Plugin edits.**
- A config key `models: {default: "inherit", Deploy: "sonnet", "QA:gate": "sonnet", …}`.
- `sdlc-dispatch` §1 table: a Model column.
- README: the inheritance caveat, with the large-context note.

### C18 — Brief hygiene and report size (context overflow)

**(a) Plugin today.**
- `sdlc-dispatch` §1 L40: the brief-cap law, "the template's length + 5 lines".
- `story-implementation` §0 step 2: "Glob `.claude/rules/**/*.md` and read every file matching your domains plus every
  root-level rule". The Reviewer does the same (`story-review` §1).
- `story-review` §5–6: the review document goes "verbatim into DETAILS".

**(b) What EMI does** [USER; PRACTICE]. Every Developer, Reviewer and QA brief says:
- **Do not re-read rule files already in your context.** The root rules are injected as project instructions. Read
  `epic.md` by its `## Architecture Notes` section only, and any other rule file by the sections the story cites (`grep
  -n`, then `sed -n`).
- **Read files through your worktree's path only.** Reading through the main checkout's path loads the whole rule set a
  second time.
- **Send every tool run to a file**, and read back `tail -n 30` or a grep. Never print generated files, API snapshots or
  whole diffs.
- **Commit after every task**, so a crash loses nothing. **One file per Write/Edit call.**
- **Report caps:**
  - the final message stays under **3,500 characters**; per-brief caps run from 1,200 to 3,000;
  - the Reviewer writes the review document to a scratchpad file named in the brief, and reports its path;
  - QA writes the gate report to a file.
- **A rules budget** [PRACTICE: an Architect "rule diet" pass]. Detail goes into path-scoped rule files, and only
  pointers stay in the always-loaded ones. **Example (EMI):** a file under one module path loaded about 1.09 MB of rules
  (about 270K tokens) before the agent read anything.
- **Briefs in practice are far longer than the plugin's cap**: 3–6 KB, carrying:
  - the base sha and what the tree has;
  - the facts carried in from sibling stories;
  - the selection with its reasons;
  - the runner slot and its commands;
  - the standing lines (C22);
  - the report caps.

  See open question Q3.

**(c) Why.**
- Nine Developer sessions died of "autocompact thrashing" or "prompt is too long" in two days, two of them with nothing
  committed.
- A 15 KB review was truncated three times by the teammate channel before it was delivered through a file.

**(d) Plugin edits.**
- `story-implementation` §0 step 2 and `story-review` §1 step 1: "rules already in your context are not re-read; read
  large files by section".
- The report envelope in `sdlc-state` §3: optional `REPORT FILE:`, and a size cap from `process.report_max_chars`
  (default 3,500).
- `sdlc-dispatch` §1: rethink the brief cap as **template slots** (Q3).
- `architecture-design/references/rule-authoring.md`: a "rules budget" section.

### C19 — Evidence, not silence; shell exit-code discipline

**(a) Plugin today.**
- `sdlc-state` §3 L83: evidence means results, not adjectives.
- `sdlc-dispatch` §3: "Evidence is real".

**(b) What EMI does** [RULE quality-gate.md §How the full gate runs; USER; the `run-checks` skill].
- **Evidence is a counter, an exit code or a diff.** Silence is not evidence: "ok: true", empty output and "the run
  passed" prove nothing until the check is shown to have run.
- **A run that selected or evaluated nothing is red** until shown otherwise: a filter matching 0 tests, a policy script
  evaluating 0 fixtures, a test command executing 0 runs.
- **Quote the last run that actually passed**, never an earlier one.
- **Only the gate's own targets are gate evidence.** Direct tool calls are diagnostics.
- **A component "not present yet" is a red gate, not a skip.**
- **Detached steps** use start tokens and `--expect`, and an empty log with exit 0 is red (C14).
- **Shell rules**, applying equally to the PM's own Bash:
  - Read `$?` on the next line, from the command itself: never after a pipe, never after an `&&` or `||` list, and never
    from `PIPESTATUS` (zsh spells it `pipestatus`, indexed from 1).
  - Never run a command held in an unquoted variable. zsh does not word-split, so `for x in $list` and `set -- $pair`
    take the whole string. Use arrays (`"${arr[@]}"`), `read -r a b <<< "$pair"`, or one command per item.
  - Brace a variable followed by a colon (`"${REF}:path"`); otherwise zsh reads a history modifier.
  - `grep -c` exits 1 when it counts zero. Read the count, not the exit.
  - `git grep` with `\|` alternation returned nothing on this host. Use `-E` with `|`.
  - Check what actually runs with `type {tool}`. An alias once shadowed a gate tool, so that `buf` ran `brew upgrade`
    ([PROJECT] host).
  - Never place a destructive command after `;` behind an `&&` chain.
  - Guard globs that may not match (`(N)` or `null_glob`).
  - Verify a loop's effects with a listing, never with the loop's own echo.
- **Commit trailers are part of the evidence check** (C20).

**(c) Why.**
- Six agent readings of an exit code were false; the worst looked like a pass for a check that never ran.
- One guard exited 0 while never evaluating the thing it guarded.
- A PM loop created worktrees whose paths held spaces and a branch name.
- The user called this "the rule that cost the most to learn".

**(d) Plugin edits.**
- A new shared reference, `skills/sdlc-dispatch/references/evidence-and-shell.md`, cited by every agent skill's evidence
  section.
- `sdlc-state` §3: tighten the envelope.
- A config key `shell: zsh | bash`; the zsh-specific lines apply when it is `zsh`.

### C20 — PM working copy and commit discipline

**(a) Plugin today.**
- `sdlc-state` §1: the PM writes state from the main working copy.
- `start.md` Git policy L224–228.
- The epic merge runs in the main working copy.
- Commits follow `{ITEM}: … [by Role]` (`sdlc-state` §7).
- There is no attribution rule; the sibling plugin enforces one with its `guard-commit` hook (C25).

**(b) What EMI does** [USER; PRACTICE].
- **The main checkout stays on `main`.** The tracker reads `docs/state/` from the main checkout's *working tree*, not
  from the ref. Never park it on another branch, and never move the PM's writes to another worktree.
- **State is committed by path**: `git commit -m "…" -- docs/state {exact review, notes and follow-up files}`. Never
  `git add` followed by a bare `git commit`: one bare commit swept in an agent's 15 staged renames.
- **Every planning agent works in its own worktree.** The Product Manager, System Analyst, Architect and Designer each
  get `.worktrees/{ROLE}-{topic}` on a branch from `main`, never the main checkout. The PM merges their branches.
- **A stray state commit on an agent's branch**, if it is a direct child of `main`: move `main` to it (`git branch -f main
  {sha}`) and push. Never rewrite a branch an agent is working on.
- **The PM holds its own pushes to `main`** while a delivery Deploy pushes.
- **No attribution trailers** (`Co-Authored-By`, session links) in any commit or PR, from the PM or any agent:
  - the brief states it **as an override of the harness reminder**, because a Developer followed the harness over a
    brief that merely stated the rule;
  - the PM checks every agent commit (`git log -1 --format=%B {sha} | grep -ciE 'co-authored|claude-session'` → 0, read
    as a count);
  - the PM amends an unpushed story-branch commit itself, as history hygiene;
  - settings: `includeCoAuthoredBy: false` and an empty attribution;
  - rewriting published history needs the user's explicit go-ahead (a force push).
- **The PM does git plumbing itself, never code**: fast-forwards, plain pushes, trailer amends and worktree removal.

**(c) Why.**
- The board froze for about an hour while the pipeline ran on.
- A state commit landed on an Architect's branch.
- 449 of 738 commits carried the trailer before the rule.

**(d) Plugin edits.**
- `sdlc-state` §1 and §7: commit by path, and keep the main checkout on `main`.
- `start.md` Git policy and planning dispatches: worktrees for planning roles.
- `hooks/`: the attribution hook of C25, on by default (`process.commit_attribution: false`).
- `sdlc-dispatch` §3 verification table: a trailer-check row.
- `sdlc-dispatch` MUST NOT: an exception listing the PM's permitted git plumbing.

### C21 — PM record-keeping

**(a) Plugin today.**
- `sdlc-state` §6: feedback files `docs/reviews/{ID}-{n}.md`.
- `sdlc-state` §4: follow-ups, `FU-{n}` in a per-epic example.
- `sdlc-state` §7: the log line schema.
- `start.md` narration law L22–46, including "Narrate in the user's language" — **already in the plugin**.

**(b) What EMI does** [PRACTICE].
- **Narration in the user's language** (kept). **Example (EMI):** the narration is Russian, the artefacts English.
- **Saving a review.** The Reviewer writes to a scratchpad path named in its brief. The PM then:
  - copies the review to `docs/reviews/{ID}-{round}.md`;
  - appends its NOTEs to the notes file as N-lines;
  - appends its follow-ups to `followups.md`;
  - stores the path in `review_feedback`.
- **Saving a gate report.** QA writes to scratchpad. The PM saves it as `docs/reports/{EPIC}-batch-gate.md`, with
  `-run{N}` for a failed run and `-regate` for a repeat.
- **Numbering.** N-{n} and FU-{n} each run in **one project-wide sequence**; at the time of writing they reach about 780
  and 620. Neither has a counter in `project.json`; how the next number is found is not confirmed. The PM reserves story
  IDs before a System Analyst cuts a story.
- **Log vocabulary** (Appendix G):
  - `dispatch: {Role} ({mode})` lines change no status, and carry the base sha, runner slot and model;
  - `report: {Role} {OUTCOME}` and `…; PM verified the diff` lines;
  - `decision` lines record every deviation;
  - `recut` lines;
  - `correction` lines void earlier malformed lines instead of editing them (append-only is kept);
  - `decision: user` lines record user steering.

**(d) Plugin edits.**
- `sdlc-state` §6: add `docs/reports/{EPIC}-batch-gate[-run{N}].md`.
- `sdlc-state` §7: trigger vocabulary with modes.
- `sdlc-state`: counters `note` and `followup`.
- `story-review` §5–6 and `story-qa`: file output.

### C22 — Standing brief lines a project declares

**(a) Plugin today.** Each template's DISCIPLINE section is fixed. A project cannot add lines without breaking the brief
cap.

**(b) What EMI does.** Every brief of the named roles carries these lines [USER, each one a repeated correction]:

| Line | Roles |
|---|---|
| **No attribution**, worded as an override of the harness reminder | all |
| Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record | all |
| **Reference check for ambiguity** [PROJECT; generic mechanism]: where a dossier, story or rule is silent, ambiguous or self-contradicting, check how the older system being reproduced did it, under the clean-room protocol (read, understand, close, write anew; never copy or name), and report each check and each difference in DETAILS. Never a conservative guess. | **every** Developer brief (story, fix pass, bug) and **every** Architect brief; Reviewers flag a decision made on a guess |
| **App first, no premature hardening**: build the application; cut infrastructure and operations hardening for things that do not exist yet into a deferred hardening epic | every System Analyst and Architect brief |
| Content guard: avoid the patterns it bans, and run it on every touched file [PROJECT] | all |
| Never paste local tool-generated names (container names with replica index, Compose project names, absolute checkout paths) into committed documents | Deploy, QA |
| Host quirks, for example "`buf` is an alias here; use `command buf`" [PROJECT] | Deploy, QA |

**(c) Why.** Each line exists because a brief without it failed.

**(d) Plugin edits.**
- A config key `standing_brief_lines: {all: [...], Developer: [...], Architect: [...], ...}`.
- A `{standing lines}` placeholder in every template's DISCIPLINE section, exempt from the brief cap.

### C23 — Planning cadence

**(b) What EMI does** [PRACTICE; one USER-confirmed decision].
- **Just-in-time depth** (C13).
- **Planning in batches.** A Product Manager, System Analyst and Architect pass covers several epics. A System Analyst
  **amendment pass** follows when the Architect's design changes stories.
- **Stackless dispatches while stacks are busy**: Architect pre-rulings, and Product Manager "product input" dispatches
  for open product questions.
- **User steering as directives**, archived, for example the "app first, defer infrastructure" directive.

**(d) Plugin edits.**
- `start.md` planning phase: `process.planning_depth`, and an "amendment pass" dispatch for the System Analyst after
  Design Mode changes stories.

### C24 — Project- and host-specific items

These should become generic hooks in the plugin, not shipped content.
- **Content guard** [PROJECT].
  - The project bans names of outside systems, organisations and people through a pattern list and a guard script.
  - The guard runs as Step 0 of every gate, in every planning artefact's done-check, in a pre-commit hook (on staged
    content and on the git identity), and in CI.
  - A hit is resolved by renaming, **never** by narrowing the list, excluding a path, or git-ignoring it.
  - Quoted tool output is described, not pasted.
  - **Plugin:** a key `content_guard: {command, pre_commit: true}`. The quality-gate seed's Step 0 becomes "the content
    guard, if declared". The verification table gains a row.
- **Clean room for reference implementations** [PROJECT]. The rule is "read, understand, close, write anew"; never copy
  or name; only named roles may read, and each role may read only the one kind of reference allowed to it.
  **Plugin:** support a `reference_protocol` rule file and the standing brief line of C22.
- **Designer reference screens** [PROJECT]: predecessor mock-ups are used for structure and flows only, never for names,
  brand, palette or copy; never copied into the repository; never cited. **Plugin:** a standing line for Designer
  briefs.
- **Host recovery for the local container engine** [PROJECT/host]:
  - never choose "reset to factory defaults";
  - terminate and relaunch the engine instead: its images and volumes survive;
  - check the daemon by its server version, because `docker info` exits 0 with no server;
  - while registry pulls hang, reuse local images and copied dependency trees;
  - probe a build before trusting the host again;
  - move stacks to runners.

  **Plugin:** at most a note in the QA and Developer skills, "infrastructure outage is BLOCKED, not FAILED; never run a
  destructive reset".
- **Test-cache and container-cache specifics** (clear the compiled test container with the right identity and confirm
  the clear; warm the analyser's container) [PROJECT]. **Plugin:** only the generic lesson, in C1 point 10.

### C25 — The no-attribution hook

Labels: [GATE] for the mechanism; [USER] for the rule, which EMI already follows by other means (C20).

**(a) Plugin today.**
- `hooks/hooks.json` registers one `PreToolUse` hook on `Bash`, `guard-git.sh` (no force push, no `-X ours/theirs`).
  Nothing inspects a commit message.
- `sdlc-state` §7 L347–353 prescribes a `[by {Role}]` suffix on every commit. No rule bans attribution trailers.
- EMI enforces "no attribution" with a brief line worded as an override of the harness, a PM check of every agent
  commit, and project settings (C20, C22). None of these acts at the moment of the commit.

**(b) What agent-sdlc-gate does** [GATE].
- **Event and registration.** `hooks/hooks.json` L28–46: a second command hook in the same `PreToolUse` entry with the
  `Bash` matcher, after `guard-git.sh`: `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/guard-commit.sh`, timeout 10 s, status
  message "Checking commit conventions...".
- **What it reads.** The tool-input JSON on stdin: `.tool_input.command` and `.cwd`. A command that is not a commit
  exits 0 at once. The match (`guard-commit.sh` L11–12) accepts `git commit`, `git -C {path} commit` and
  `git {flags} commit`, so `--amend` is included.
- **Scope** (L14–30). It walks up from `.cwd`, or from the `-C` path, to the gate's hub: a directory that holds both
  `repos.json` and a `docs/state/project.json` with `"workspace": true`. Outside a hub it is a silent no-op, so it never
  fires in an agent-sdlc project on the same machine.
- **Check 1, attribution** (L39–42). A case-insensitive search of the **whole command text** for `co-authored-by`,
  `generated with`, the robot emoji and `[by ` (agent-sdlc's role suffix). A hit denies the call. Because the search
  runs over the command line, it catches `-m` messages and a message passed as a heredoc inside the command, the
  usual form for a multi-line message.
- **Check 2, prefix** (L44–57). Only for a single-line `-m "…"` or `-m '…'` that it can extract: the message must
  start with `{KEY}-{n}: `, `sdlc: `, `Merge`, `Revert`, `fixup!` or `squash!`. Commits in the plugin's own working
  copy are exempt.
- **How it blocks** (L32–35). It prints `{"hookSpecificOutput": {"hookEventName": "PreToolUse",
  "permissionDecision": "deny", "permissionDecisionReason": "…"}}` and exits 0. The command never runs; the model
  reads the reason ("Rewrite the message plainly") and retries.
- **Configuration.** None. No key turns it off, the patterns and the prefix are written into the script, and the hub
  test is the only switch.
- **What it does not see.** These follow from the script; nothing else covers them in agent-sdlc-gate:
  - a message in a file (`git commit -F {file}`) or written in an editor: the attribution search reads only the command
    line, and the prefix check skips anything but `-m`;
  - pull-request titles and bodies: its delivery skill writes the body to a temporary file and runs `gh pr create
    --body-file` (`story-delivery` L52, L65–66), which is not a commit. Pull requests are covered only by prose: the
    workspace git-conventions template and the "no pipeline traces on external surfaces" law;
  - a merge commit made with `git merge -m`.
- The rule is also repeated in prose wherever a commit is made: `agents/developer.md` L34, `agents/qa.md` L27,
  `story-implementation` L79, the PM's verification row in `sdlc-dispatch` L60, and
  `templates/rules/workspace/git-conventions.md` L14–18.

**(c) Why port it.**
- A brief line loses to the harness's own commit template. An EMI Developer followed the harness over a brief that stated
  the rule, and 449 of 738 commits carried a trailer before the rule (C20).
- A deny at the moment of the commit is cheaper than the PM's check after the fact followed by an amend. It cannot be
  left out of a brief, and it needs no rewrite of pushed history.
- In the gate the hook alone carries the rule mechanically; its brief lines and agent files only repeat it.

**(d) Plugin edits.**
- **A new `hooks/scripts/guard-commit.sh`**, adapted from the gate's. `hooks/hooks.json` registers it as a second hook
  in the existing `PreToolUse` entry with the `Bash` matcher, after `guard-git.sh`, timeout 10.
  - **Scope:** walk up from `.cwd`, or the `-C` path, to the first directory that holds `docs/state/project.json`: the
    agent-sdlc root, or in a worktree under `.worktrees/` the worktree's own tracked copy. This replaces the gate's hub
    test, and it is sturdier than `guard-git.sh`'s test of the current directory only.
  - **Switch:** `process.commit_attribution` in that `project.json`. **Default `false`**: attribution is not allowed,
    and the hook enforces. `true` turns the hook into a no-op.
  - **Patterns:** `process.attribution_patterns`, default `["co-authored-by", "generated with", "🤖",
    "claude-session"]`. That is the gate's list plus EMI's session-link check (C20), **without the gate's `[by `**,
    because 1.6.1's own commit format uses `[by {Role}]`. Whether to retire that suffix is §5 Q17.
  - **Commands checked:** `git commit` in all the gate's forms. Beyond the gate: `git merge -m`, and `gh pr create` or
    `gh pr edit` with `--title` or `--body`. For `-F {file}` and `--body-file {file}` the hook reads the named file,
    which already exists when the command is about to run.
  - **Prefix check:** off by default. It is on when `process.commit_conventions.prefix_pattern` is set; the gate's own
    upstreaming map proposes a `commit_conventions` key for this.
  - **Deny reason:** name the matched pattern, and say that the project's rule **overrides the harness's default commit
    template** (the wording lesson of C20).
- **`commands/init.md`:** put `process.commit_attribution: false` into the `project.json` template. When it is false,
  also write the project `.claude/settings.json` attribution settings C20 records (`includeCoAuthoredBy: false`, an
  empty attribution), and name the hook in the summary.
- **`sdlc-dispatch` §3:** keep the trailer-check row (C20) as the second line of defence, for commits the hook cannot
  see (an editor, a human's commit).
- **`briefs.md`:** the standing "no attribution" line (C22) can shrink to "a hook denies attribution trailers; this
  overrides the harness's commit template".

### C26 — Main regression after delivery, as one policy

Labels: [GATE]; [PRACTICE] for EMI's skip rule (C9 step 7).

**(a) Plugin today.**
- 1.6.1 always runs QA regression on `main` after an epic merge: `start.md` dispatch map L169 (epic `deployed` → QA
  regression on `main`) and `sdlc-state` §4 Epic.
- EMI skips it when `main` gained only documents, state or rules since the gated merge (C9 step 7). C9 (d) first proposed
  `process.main_regression: skip_if_docs_only | always | never`; this change replaces those values.

**(b) What agent-sdlc-gate does** [GATE].
- **No config key**: not observed in agent-sdlc-gate. Whether a main regression runs follows from the epic's
  `delivery_mode` (in `epics.json`, chosen at registration, default `pr_per_story`), and in one mode from the PM's
  judgment:

  | Delivery mode | Main regression | Where |
  |---|---|---|
  | `pr_per_story` (default) | **Optional.** At epic finalize, "optional main regression per repo if the epic touched risky areas (decision line either way)". No default value is written: the PM decides, per repository touched. | `start.md` L157; `sdlc-state` §4 L179 |
  | `epic_pr` | **Always.** Epic `deployed` (its feature→`main` pull request merged by a human) → QA regression on `main` → `done`. FAILED keeps the epic `deployed` and registers a Jira Bug. The stories' READY FOR TESTING push waits for this pass. | `start.md` L121, L165; `sdlc-state` §4 L180, §5 L225–226 |

- **The run** (`briefs.md` qa-regression L160–173, `story-qa` L48–56): the PM creates a fresh detached worktree of
  `origin/{default_branch}`; QA runs the repository's full quality-gate list in order, a conflict-marker scan, and a
  spot-check of one acceptance criterion per story. QA commits nothing.
- The gate states no reason for the difference. The evident one: in `pr_per_story` every story already passed CI and
  human review on its own pull request before it reached `main`, while in `epic_pr` the stories meet on `main` for the
  first time.

**(c) Why one policy.**
- The three existing behaviours are one question with three answers: 1.6.1 and the gate's `epic_pr` always run it; the
  gate's `pr_per_story` leaves it to the PM; EMI runs it only if the tree changed since the gate.
- In the fast lane, a regression on `main` after a clean delivery re-runs an identical code tree (C9 (c)).
- A project whose `main` also receives direct commits (hotfixes, other teams) needs `always`, and a project whose
  gate runs on every pull request in CI may choose `never`.

**(d) Plugin edits.**
- **The key `process.main_regression`**, with three values:

  | Value | QA regression on `main` after a delivery | Matches |
  |---|---|---|
  | `always` | every delivery | 1.6.1; the gate's `epic_pr` |
  | `if_main_gained_code` | only when the delivered `main` head's code differs from the gated tree | EMI's rule (C9 step 7) |
  | `never` | never; the batch gate (or CI) is the last proof | the gate's `pr_per_story` when the PM judges nothing risky |

- **Default:** `if_main_gained_code` in the fast lane, and `always` in the classic lane, so `process.lane: classic`
  keeps 1.6.1's behaviour.
- **The test for `if_main_gained_code`**, run by the PM after the delivery merge:
  `git diff --name-only {gated sha} {delivered main sha}`, with the paths in `process.docs_only_paths` removed. The
  number of remaining paths is printed and read as a count (C19): 0 → skip; 1 or more → dispatch QA. In the fast lane
  this is a safety net, because code that reaches `main` during the gate already forces a re-gate (C6 step 6), so the
  count is normally 0.
- **Every outcome writes a decision line**, as the gate does ("decision line either way"): the value, the count, and
  "skipped" or "dispatched".
- **The PM may run it anyway**, on a decision line that names the reason, whatever the value. This keeps the gate's "risky
  areas" judgment as an override rather than a fourth value.
- The gate's per-repository scope needs a multi-repository workspace; agent-sdlc has one repository, so a run is the
  whole gate.
- Files: `commands/start.md` (the batch end's step 8 and the classic epic flow), `sdlc-state` §4 Epic and §5
  (`deployed → done` by QA PASSED or by the decision line), `commands/init.md` and the `project.json` schema. `story-qa`
  regression mode and the qa-regression brief stay as they are.

### C27 — Test stacks: the gate's per-repository lock versus a pool of stack leases

Labels: [GATE]; [USER] for EMI's local stack budget (C15); [PRACTICE] for EMI's runners (C14). **Not decided here:
the design is for the plugin's Architect (§5.1).**

**(a) Plugin today.**
- `max_parallel_teammates` caps working agents (`sdlc-dispatch` §2 L45). Ports are allocated per worktree (`sdlc-state`
  §6 L326–330). Nothing limits how many Compose stacks run at once, or on which host.
- EMI added a local stack budget (C15) and remote runner slots (C14) by practice. Neither is a plugin mechanism.

**(b) What exists.**
- **agent-sdlc-gate: one quality-gate run per repository at a time** [GATE].
  - **Configuration:** `repos.json` → `repos.{repo}.gate_concurrency`, written by `init` (L36) beside `quality_gate[]`
    and `gate_sequential`. The workspace quality-gate template sets `1` for a Docker-heavy repository: "one gate run per
    repo at a time across worktrees" (`templates/rules/workspace/quality-gate.md` L7). A value above 1 has no mechanism:
    not observed in agent-sdlc-gate.
  - **Where the lock lives:** a directory in the hub, `docs/state/.gate-lock-{repo}`, created with `mkdir`, which
    either creates it or fails, atomically. One directory is one slot (`start.md` L137).
  - **Who takes it:** the PM, before it dispatches any agent whose brief includes running that repository's quality
    gate. By that test: the Developer, QA in every mode, and Deploy in local-merge mode, whose report carries post-merge
    full-gate results. If the lock is held, the
    item waits in its current status for this round (`start.md` L137, `sdlc-dispatch` L45).
  - **Who releases it:** the PM, with `rmdir`, once that agent's report is verified (`start.md` L137).
  - **On a crash:** not observed in agent-sdlc-gate. The lock records no holder, no time and no expiry, and no step
    sweeps stale locks. The stale-worktree check (`start.md` L87) re-dispatches a dead agent's item but does not mention
    the lock. So a lock taken by a session that died stays until someone removes the directory. An empty directory is
    never committed, so the lock exists only in the hub's working tree, not in git (an inference from git's behaviour).
  - **Isolation, not limits, beside the lock:** per-worktree ports and, for a repository with
    `worktree_env.compose_project_prefix`, a Compose project name per item (`sdlc-state` §6 L332).
  - Reviewers run no gate, partly so that parallel lenses do not collide on the lock (`story-review` L16).
  - The lock is **per repository, not per host**: gates of two repositories run at once on one machine.
- **EMI: several stacks at once, allocated by the PM** [USER (C15); PRACTICE (C14)].
  - At most two agents hold a Compose stack on the local machine. Stackless agents do not count.
  - Runner slots come on top: one work tree plus one Compose project per slot, one to four slots per runner by size.
  - The PM allocates:
    - the worktree entry in `project.json` records `"runner": "{runner} slot {x}"`;
    - the QA, Developer and Reviewer briefs name the runner and slot;
    - a slot is set up at a SHA, never a branch;
    - each step's result is bound to a start token;
    - a slot is reset (`down` with volumes, then a `RESET=1` slot set-up) before the next item gets it.
  - The batch gates of two epics ran in parallel (C11).

**(c) Why it is a design problem.**
- In a single-repository project, the gate's lock means one stack for the whole project at a time. That serializes the
  work the runners exist to parallelize: EMI's full test step takes 21 minutes on a runner, the batch ends of several
  epics fell on one day (C6), and two epics' gates ran in parallel (C11).
- EMI's practice has no mechanical guard. The local budget lives in the PM's judgment and the runner in a free-text
  field of `project.json`. There is no atomic take, no expiry and no crash recovery. A stale `.done` file once read as a
  pass (C14); a stale allocation could do the same for a whole slot.
- Neither design alone gives "several stacks, never two agents on one".

**(d) Plugin edits.** The Architect designs first: the requirement, the options and the questions are in §5.1. Whatever
the design, it touches:
- `skills/sdlc-dispatch/SKILL.md` §2: the lease model beside the teammate cap, replacing C15's bare budget rule;
- `skills/sdlc-dispatch/references/briefs.md`: the `STACK:` slot (C15) carries the lease;
- `skills/sdlc-state/SKILL.md` §6: where a lease is recorded; §7: lease log lines;
- `commands/start.md`: take the lease with the dispatch, release it after verification, and recover stale leases in the
  stale-worktree check;
- `commands/init.md` and the `project.json` schema: the pool configuration;
- `commands/status.md` and the tracker: the leases in use.

### C28 — The tracker backend: local files or Jira, for teams

Labels: [GATE]. The choice of backend is the user's request for this hand-off; EMI never ran with more than one PM.
**Not decided here: the design is for the plugin's Architect (§5.2).**

**(a) Plugin today.**
- All tracking is local and in git: `docs/state/*.json`, sharded by bucket; `log.jsonl`; stories and bugs as Markdown
  under `docs/issues/`; reviews in `docs/reviews/`; reports in `docs/reports/` (`sdlc-state` §1–§2, §6–§7).
- One writer: the PM session, from the main working copy (`sdlc-state` §1 L10–28). Agents end with a report envelope.
- IDs come from local counters: `{PREFIX}-EPIC-{n}`, `{PREFIX}-STORY-{n}`.
- `/agent-sdlc:status` and the tracker read the same files.
- Several people cannot drive one project unless they share one PM session or merge each other's state commits. This is
  not supported, and EMI never tried it.

**(b) What agent-sdlc-gate does** [GATE]. It is a hybrid: "Jira is canonical for WHAT exists and its business status;
local state is canonical for HOW the pipeline is executing it" (`sdlc-state` §0 L12).

- **What lives in Jira.**
  - Epics, which pre-exist (the user's roadmap), Stories (one per use case), Sub-tasks (one per repository or surface of
    a story that spans several), and Bugs. The Jira key **is** the item ID; there is no local ID scheme for them. Local
    counters remain only for what Jira does not track (content tasks).
  - The acceptance criteria, in the story's description. Use cases, BRDs and design documents are wiki pages linked to
    the issues.
  - A coarse status per item, pushed only when a local transition crosses a mapped boundary (`sdlc-state` §0 L21–28):

    | Local status | Jira: Story, Bug | Jira: Sub-task |
    |---|---|---|
    | `todo` | TO DO | TO DO |
    | `in_progress` … `in_qa`, `ready_for_pr`, `pr_opening`, `pr_fixing` | In Progress | In Progress |
    | `pr_open`, `pr_changes_requested` | IN REVIEW | IN REVIEW, or In Progress if the workflow lacks it |
    | `merged`, `done` | READY FOR TESTING; in `epic_pr`, deferred until the epic's main regression passes | Done |
    | rejections, `regression_failed` | no push | — |

  - One comment per item: an "Implementation Summary" with the pull-request link, written at READY FOR TESTING, in the
    user's own voice.
- **What stays local**, in the hub's git repository: the fine-grained status; worktrees, branches, pull-request numbers
  and poll times; `depends_on` (not observed as Jira issue links); `owner`; feedback file paths; the review files, one
  per lens; the QA reports; the transition log; directives; the push retry queue.
- **How it reads** (`skills/jira-sync` §1). At session start and before every dispatch round, one JQL snapshot per
  active epic (`parent = {EPIC} ORDER BY rank ASC`; fields summary, status, assignee, issue type, sub-tasks), plus one
  for all their sub-tasks. That is at most two calls per epic per round, skipped when the last sync (`jira_synced_at`)
  is under 60 s old. A reconcile table decides:
  - Jira wins **composition**: new or removed items, titles, assignees;
  - Jira never overwrites a pipeline item's local status. A status a human moved is surfaced as an anomaly; Jira showing
    Done while the item is locally before merge **parks** it until the user decides;
  - an item gone from Jira keeps its state entry, for history, and is flagged.

  One state commit per sync round.
- **How it writes** (`skills/jira-sync` §2–§3):
  - **only from the PM session, through background agents**, so the loop never waits on the tracker. Teammates get no
    Atlassian tools or credentials; briefs carry the acceptance criteria;
  - a transition is looked up by name every time (`getTransitionsForJiraIssue`), never by a stored ID;
  - a failed write goes to `project.json.jira_push_queue` and is retried at the start of the next round: "Jira being
    down never blocks dispatching code work";
  - stories, sub-tasks and bugs are **created by the System Analyst**, run as a foreground subagent in the PM session
    because subagents inherit the session's MCP and teammates do not. It uses `createJiraIssue` with the current user,
    from `atlassianUserInfo`, as assignee. The PM registers the items from its report.
- **The human tail** (a law there). The pipeline never moves a Story, Bug or Epic to Done and never changes an assignee.
  After READY FOR TESTING the user verifies by hand. An epic gets one push, In Progress.
- **External-surface hygiene** (a law there). Nothing written to Jira, the wiki or a pull request may carry pipeline
  vocabulary: roles, agents, lenses, dispatches. A follow-up becomes a real Jira issue, never a meta-comment.
- **Several humans** (`sdlc-state` §0 L17; `jira-sync` §1):
  - ownership is the Jira **assignee**. An item may be `owner: "pipeline"` only if it matches `jira_scope_jql` (default
    `assignee = currentUser()`). Every other item of the epic is registered as `owner: "human"`: shown in the tracker,
    never dispatched, never transitioned, its branches and pull requests untouched;
  - an issue reassigned away from the user flips a pipeline item to `human`, and its worktree stays on disk. An issue
    assigned to the user flips a foreign `todo` item to `pipeline`;
  - the claim is therefore the assignee, which humans set in Jira. The pipeline never writes it.
- **Several PM sessions:** not observed in agent-sdlc-gate. The default scope query (`assignee = currentUser()`) makes
  a hub drive the issues of the user whose Atlassian session it runs in. The hub pulls with `git pull --rebase` at start
  and pushes after its commits when a remote exists (`start.md` L69, L169), but no rule covers two PM sessions writing
  one hub's state.
- **Transitions, parking and the log stay local.** `log.jsonl` gets `"trigger": "jira-sync"` on pulled registrations.
  Parking is the local `pr_open` status (Jira: IN REVIEW), polled from the Git host every round.
- **MCP and API.** The Atlassian MCP server, in the PM session only: `searchJiraIssuesUsingJql`, `getJiraIssue`,
  `createJiraIssue`, `getTransitionsForJiraIssue` with a transition and a comment, `atlassianUserInfo`, and the wiki
  page tools. One operation bypasses MCP: a wiki page is linked into the issue's wiki-items panel through Jira's REST
  `remotelink` endpoint with `curl`, using credentials from environment variables. The site, cloud ID, project key and
  issue types come from a configuration file in the hub, and the browse URL from `repos.json`.
- **The tracker view.** `/agent-sdlc-gate:status` and its tracker read local state only. They mark foreign items, link
  each key to Jira through the browse URL, and run on their own home directory and port range so they do not collide
  with agent-sdlc's tracker. Live Jira reads by `status`: not observed in agent-sdlc-gate.
- **Migration:** none. The gate's state is born at version 3, and its `init` stops if an agent-sdlc state layout
  exists in the same directory: "the two plugins must not share a root" (`init.md` L28).
- **Its own upstreaming map** (`docs/UPSTREAMING.md` seams 2, 4 and 8) proposes a generic shape:
  `integrations.issue_tracker: {type: jira | linear | local, mapping}`, with `local` as today's behaviour; a
  pull/reconcile/push contract as one skill per adapter; ownership travelling with it; and a "documents live in the
  corporate wiki" adapter beside it.

**(c) Why it is a design problem.**
- A single writer is what keeps agent-sdlc's state sound. A shared tracker has many writers by definition: humans, other
  PM sessions, the tracker's own automation.
- The gate solves "several humans" with ownership by assignee. It does not solve "several PM sessions on one project",
  and it keeps the fine status, the reviews and the log private to one hub.
- The fast lane (C4) has statuses and epic-level steps (main-in, batch fix, gate runs, delivery) that no default Jira
  workflow has.
- Nothing here is proven for teams: EMI ran one PM, and the gate runs one PM per hub, scoped to its user's issues.

**(d) Plugin edits.** The Architect designs first: §5.2. Whatever the design, it touches:
- `skills/sdlc-state/SKILL.md`: a new §0, "Tracker backend", that defines the interface, with the §4–§7 rules restated
  as its operations;
- `commands/start.md`: Step 1 selects the backend; a sync step runs before each round when the backend is remote; the
  dispatch loop calls the interface instead of editing files;
- `commands/init.md` and the `project.json` schema: the backend choice and its settings;
- `commands/status.md` and the tracker: reading per backend;
- one new `skills/tracker-{backend}/SKILL.md` per remote backend, as the gate's `jira-sync`.

### C29 — Milestones as a first-class tracker object

Labels: [USER] for the request; [PRACTICE] for what EMI does today (C13).

**(a) Plugin today.**
- No milestone entity exists: no field, file, status or view. Not observed in agent-sdlc 1.6.1, and not observed in
  agent-sdlc-gate.
- `epics.json` holds `priority_order` and the epic map. The epic machine ends at `done` (`sdlc-state` §4 Epic
  L173–183), and a `done` epic moves to the archive.
- `/agent-sdlc:status` lists epics with `{done}/{total}` stories (`status.md` step 6).
- The tracker (`/agent-sdlc:tracker`; `tracker/server.py`, `tracker/static/app.js`) has roadmap, board, backlog,
  activity and archive views. The roadmap lists epics in `priority_order`, each with its progress (`epic_progress`,
  server L134).
- C13 proposed only optional epic fields (`milestone`, `continued_by`) and "progress grouped by milestone".

**(b) What EMI does today** [PRACTICE]. Milestones live in prose only:
- **membership:** one demo-slice document per milestone (`docs/reports/demo-slice-{N}.md`, C13), recut reports
  (`docs/reports/milestone-{N}-recut.md`), and lines in `epic.md` files ("Milestone-4 part cut out as: …",
  "Continued by: …");
- **state:** none. No epic entry in EMI's `epics.json` carries a milestone field; the entries have `title`, `status`,
  `type`, `brd` and `branch` only;
- **the log:** `recut` lines whose note names the milestone and the recut report (about 200 of them), and delivery
  decision lines with a running count ("milestone 4's fifth delivered epic");
- **names:** a milestone epic's batch-gate report is saved as `{EPIC}-milestone-batch-gate.md`;
- **progress:** the PM reports it in chat, counted by hand from the slice document's final count and the decision lines.
  The tracker shows none of it.

**(c) Why.** The user asks for three things [USER]:
1. The user defines milestones in dialogue with the PM or the Product Manager: a name, a goal or demo, and optionally a
   target date.
2. A milestone links to epics, and to stories where an epic is not cut whole, though C13's rule prefers whole epics.
3. The tracker shows each milestone's progress (items done / total, epics delivered / total, what is in flight, what
   blocks) and the links between epics and milestones.

Besides:
- C13's recut-whole rule exists so that "the tracker shows a milestone as whole epics", and the tracker has no milestone
  to show.
- Progress reported in chat is lost between sessions and recounted by hand each time.
- Membership kept in prose drifts: every recut changes the epics, and the slice document's count goes stale.

**(d) Plugin edits.**

1. **Schema.** Proposed: a `milestones` map in `epics.json` (the alternative, a new `milestones.json`, is §5.3 Q19).

   ```json
   "milestones": {
     "{PREFIX}-MS-3": {
       "id": "{PREFIX}-MS-3",
       "title": "{short name}",
       "goal": "{the goal or the demo, one or two sentences}",
       "target": "{YYYY-MM-DD, or null}",
       "status": "planned",
       "epics": ["{PREFIX}-EPIC-15", "{PREFIX}-EPIC-16"],
       "stories": [],
       "slice_doc": "docs/reports/demo-slice-3.md",
       "planned_count": { "epics": 9, "items": 160 },
       "created_at": "{ISO-8601 UTC}",
       "delivered_at": null,
       "demoed_at": null,
       "closed_at": null
     }
   },
   "milestone_order": ["{PREFIX}-MS-3", "{PREFIX}-MS-4"]
   ```

   - Every epic entry carries `"milestone": "{PREFIX}-MS-{n}"` or `null`. An epic belongs to at most one milestone,
     which C13's recut-whole rule guarantees.
   - `stories` lists only the items of an epic that is **not** cut whole, the exception. Each such item carries its own
     `milestone` field.
   - The milestone's `epics` and the epic's `milestone` are written in the same PM response, as the bucket-move law
     pairs its two writes.
   - A counter `milestone` in `project.json`, and IDs `{PREFIX}-MS-{n}` (a new row in the product-conventions ID table).
   - A milestone stays in `epics.json` after its epics are archived; an archived epic keeps its `milestone` field, and
     the tracker already returns archived epics (`archived_epics`).
   - `planned_count` is the slice document's final count, kept to show drift against the live count.

2. **Transitions.** Only the PM applies them, each with a log line whose `item` is the milestone ID:

   | From | Event | To | Also |
   |---|---|---|---|
   | — | the user defines it, in dialogue or by directive | `planned` | `from: null`, trigger `decision: user` |
   | `planned` | the first item of a linked epic, or a linked story, is dispatched | `in_progress` | in the same response as that epic's `ready → in_progress` |
   | `in_progress` | the last linked epic is `done` on `main` (C9, C26), and every linked story's batch is delivered | `delivered` | `delivered_at`; the delivery's decision line names the milestone and the count |
   | `delivered` | the user says the demo ran | `demoed` | `demoed_at`, `closed_at`; a `decision: user` line |
   | `delivered` | an epic or a story is linked to it | `in_progress` | a line naming the addition |

   - `demoed` is the only transition on the user's word (C13 point 3). `delivered` is where the pipeline stops; no
     dispatch ever waits for `demoed`, and the PM offers the demo when the user returns (`process.demo_gate:
     on_request`).
   - Freezing or dropping a milestone by directive is open (Q19).

3. **Created and edited from dialogue.**
   - **In the PM session.** The user names a milestone ("the next demo is X, by date Y"). The PM asks for what is missing
     (name, goal or demo, target), one question at a time, writes the entry as `planned` with no epics yet, logs it with
     `decision: user`, and commits.
   - **A command**, `/agent-sdlc:milestone [new | edit {ID} | list]`, runs the same procedure outside a `/start` loop.
     Whether a command may write state, or must leave a directive for the PM, is Q19.
   - **A directive**, `docs/directives/active/{date}-milestone.md`, with fixed fields (name, goal, target, epics,
     stories), is the asynchronous path; Step 2 applies it.
   - **The epics.** The PM dispatches the Product Manager in a milestone mode of `brd-writing`, which extends C13's
     "milestone recut" mode. Its input is the goal and the demo. Its DETAILS carry the slice document, the epics that
     deliver it, the recut data, and a `MILESTONE` registration block the PM applies. In 1.6.1 the Product Manager has no
     tool to ask the user questions, so the dialogue stays with the PM; giving the Product Manager one for a foreground
     interview is Q19.
   - **Edits** (rename, retarget, link or unlink epics) take the same paths, each with a log line.

4. **C13's slice and recut write into the schema.**
   - **Slice** (System Analyst "milestone slice" mode, Product Manager placement): `slice_doc`; `planned_count` from the
     document's final count; the epics wholly in the slice go into `epics`, and each gets its `milestone`.
   - **Recut** (Product Manager "milestone recut" mode): the milestone part keeps its epic ID and goes into `epics`. The
     remainder epic is registered with `milestone: null`, or with the next milestone the user names, and the original
     gets `continued_by`. Every re-parented item gets a `recut` log line naming the milestone, as today.
   - **A prerequisite pulled in from another epic** is recut whole (C13) and its milestone part joins `epics`. Only
     where the user accepts an uncut epic does the item go into `stories`, with its own `milestone`.
   - **The check before `planned → in_progress`:** every epic that gives the milestone some but not all of its stories
     is either recut or recorded as an accepted exception in `stories`. Otherwise the PM narrates the blocker and does
     not start the milestone.

5. **`/agent-sdlc:status`** gains a Milestones block above Epics, and each epic line names its milestone:

   ```
   Milestones:
     {PREFIX}-MS-3 {title}  [in_progress]  target {date}
       epics delivered 5/9 (1 awaiting main regression) · items done 112/160 (slice planned 160)
       in flight: {EPIC} batch gate run 2; {EPIC} 3 in review, 2 in progress
       blocked: {ITEM} parked (budget gate); {EPIC} frozen
     {PREFIX}-MS-4 {title}  [planned]  epics 0/6 · items 0/85
   Epics:
     {PREFIX}-EPIC-15 {title}  [MS-3]  [{done}/{total} stories done]  [{status}]
   ```

   - **Epics delivered:** linked epics `done`; a `deployed` epic is shown as awaiting main regression.
   - **Items done:** the items of the linked epics plus the linked stories, with status `done`. In the fast lane that
     means merged into the feature branch, not yet on `main`.
   - **In flight:** linked items in a working status, and each linked epic's batch-end stage (§4.14).
   - **Blocks:** parked items, items waiting on a ruling, a red gate run, a frozen epic, and a `depends_on` on an item
     outside the milestone.
   - **Drift:** the live total against `planned_count`.

6. **The tracker.**
   - A **Milestones** view (route `#/milestones`): a card per milestone in `milestone_order` with its status, target, two
     progress bars (epics, items), and its epics as the roadmap's epic cards, archived ones included.
   - The roadmap marks each epic with a milestone chip and can group by milestone; the item view names the milestone.
   - Server: nothing new if milestones sit in `epics.json`, because `api_state` returns that file whole and
     `epic_progress` already counts every bucket, the archive included. A separate `milestones.json` needs one more read
     in `api_state` and in the change stamp.

7. **The Jira backend of C28:** how a milestone maps onto Jira is open (§5.2).

---

## 4. Proposed plugin changes, file by file

Design principle: **one switch, `process.lane`, default `fast`.** Keep the 1.6.1 behaviour as `classic`, so existing
projects can opt back in. Where a change below says "fast lane", it applies only when `process.lane == "fast"`.

### 4.1 `templates/rules/quality-gate.md` — the seed

Replace the single table with this skeleton. The Architect still fills every `{placeholder}`, and init still refuses
placeholders.

```markdown
# Quality Gate

Proof comes at two levels. A **story** or bug proves itself with the **targeted set** (§Per story). A **batch** — the
stories merged into one feature branch between two deliveries to `main`, by default one epic — proves itself once with
the **full gate** (§Batch end), on the feature branch after `main` has been merged into it. Nothing reaches `main`
without the full gate, and no story runs the full gate on its own.

## How the full gate runs
- {precondition, e.g. `make up`} once; it is a precondition, not a step.
- Sequentially, one step at a time, never in parallel.
- Only the commands below count as gate evidence; anything else is a diagnostic.
- Evidence is a counter, an exit code or a diff — never silence. A run that selected or evaluated nothing is red.
- An exit code is read from the command itself, on the next line (see the plugin's evidence-and-shell reference).
- A component "not present yet" is red, not a skip.
- After a fix, re-run from the step that failed (re-run {formatter} and {static analysis} too if code changed after
  they passed).

## Step 0 — every change
| Check | Command | Green means |
|---|---|---|
| {content guard, if the project declares one} | {command} | {exit 0 + last line} |

## Path-to-command table (the full gate)
### `{glob}`
| # | Check | Command | Green means |
|---|---|---|---|
| 1 | Format | {command} | {…} |
| 2 | Lint | {command} | {…} |
| 3 | Types / static analysis | {command} | {…} |
| 4 | Tests | {command} | {counts, 0 failures, 0 skipped where a skip means "not run"} |
| 5 | {replay / build / drift} | {command} | {…} |

## Whole-tree checks
Checks that state what the whole tree must contain. The always-run directory `{dir}` needs no row; any other one is
listed here and is selected by the fact it encodes:
| Check | What it encodes | Selected by a change that |
|---|---|---|
| {path} | {fact} | {adds / renames / removes …} |
The list is closed: a story that builds a new such check outside `{dir}` adds its row in the same change.

## Per story: the targeted set
1. Red first: write the test, see it fail, quote the failure.
2. Step 0.
3. Targeted tests, never the whole suite: (a) the tests mirroring every touched path; (b) the tests of every consumer
   of a changed symbol, found by search; (c) `{always-run dir}` plus every whole-tree check the change adds a fact to;
   (d) {replay} when {workflow paths} changed.
   | Changed | Run |
   |---|---|
   | `{glob}` | {targeted command pattern} |
4. Static checks on the changed files only: {formatter in intersection mode}, {analyser on changed files};
   {type check project-wide with a forced rebuild, where types cross files}.
5. The report lists each command, the reason each path was selected, and its counts. The Reviewer judges the
   selection; a consumer or whole-tree check left out is a blocking finding.
Never per story: {full test command}, {whole-tree lint/types}, {client build / ci:check}, a QA dispatch.

## Review and merge (per story)
- One review round. Blocking findings get one fix pass; the fix pass re-runs what it touches; the PM verifies it by
  reading its diff against the findings. A story returns to the Developer at most once.
- NOTEs (Minor findings, and prose findings where the behavior is right) never return a story; they go to
  `docs/reviews/{EPIC-ID}-notes.md` and are resolved at batch end.
- A reviewed story merges into the feature branch at once. A story→feature merge re-runs nothing, except: a real
  (non-fast-forward) merge runs {whole static analysis} on the merged tree, and a story that changed a whole-tree
  scanner has Deploy re-run that scanner on the merged tree.

## Batch end: the full gate
1. Merge `main` into the feature branch first.
2. Run the full gate: Step 0, then every row whose glob matches `git diff --name-only main...{feature}`.
3. Fix a red step on the feature branch (a fix loop, not a review-and-QA cycle); re-run from the failed step.
4. Resolve the notes file: each NOTE fixed in the batch, recorded as a follow-up, dropped with a reason, or carried.
5. One delivery merge to `main`, its commit message carrying: what changed (by behavior area, with IDs); the order of
   application; before merge / deploy; follow-ups by existing IDs; the test plan with real numbers.

## Enforcement
Developer: the targeted set before IMPLEMENTED. Reviewer: one round; re-runs the targeted set once; judges the
selection. PM: verifies a fix pass by its diff; keeps the notes file; closes the batch. QA: no per-story QA; runs the
full gate at batch end. Deploy: merges a reviewed story at once; re-runs changed whole-tree scanners on the merged
tree; at batch end merges `main` in first and merges to `main` only after the full gate is green.
```

### 4.2 `commands/start.md`

1. **Execution modes (L48–63).**
   - Add: "Never fall back to background subagents silently. If a named spawn fails, narrate the fallback in the same
     turn; first release and close dead panes, maximise the window, or lower the parallelism."
   - Add the **stack budget** (C15) beside the teammate cap.
2. **Step 1.** Read `process.*` from `project.json`, and the runner integration if one is enabled.
3. **Dispatch map (L154–171)**, when `process.lane == fast`:

   | Status | Item | Dispatch | On dispatch, set |
   |---|---|---|---|
   | `todo` | story / bug | Developer: first dispatch | `in_progress` |
   | `review_rejected` (returns 0) | story / bug | Developer: **fix pass** (fresh teammate `developer-{ID}-fix`) | `in_progress` |
   | `review_rejected` (returns ≥ 1) | story / bug | nobody: the **budget gate** (Q2) | — |
   | `ready_for_review` | story / bug | Reviewer: the one round | `in_review` |
   | `ready_for_merge`, story contains the feature tip | story / bug | **PM fast-forward** (no agent) | → `done` |
   | `ready_for_merge`, story behind the feature | story / bug | Deploy: story merge (queue per target branch) | — |
   | `ready_for_merge` after Deploy VERIFICATION_FAILED | story / bug | Developer: **merge fix** on `fix/{ID}-merge` | — |
   | epic: every batch item `done` | epic | **Batch end** (below) | — |

   Rows for `ready_for_qa`, `merged` and epic `deployed → QA regression` apply to the classic lane only.
4. **Replace "Merge flow: story → feature branch" (L198–202).** The new text covers:
   - PM fast-forward, with its ancestry check, plain push, log line and worktree removal;
   - the Deploy real merge;
   - VERIFICATION_FAILED → `fix/{ID}-merge` → merge-fix Developer → PM diff check → PM fast-forward → `done`;
   - "no bug is registered for a merge failure".
5. **Replace "Deploy flow: epic → main" (L204–222)** with **Batch end**, written as a numbered procedure (C6 steps 1–8
   and C9):
   ```
   ### Batch end (fast lane)
   A batch closes when its last item is done (default: the epic's last item; the PM may cut a batch earlier — decision
   line naming the members and the reason).
   1. Main-in: dispatch Deploy (main-in brief) in the epic's merge worktree. Green → feature pushed. Red → merge pushed
      to fix/{EPIC}-main-in; go to 2 with that sha as the base.
   2. Batch fix: dispatch a Developer (batch-fix brief) on fix/{EPIC}-batch from the main-in merge: meeting defects,
      the notes chosen for the batch, cross-cutting obligations. Verify by diff; fast-forward the feature.
      (Proposed, not observed: skip when the main-in was green and no note is chosen for fixing.)
   3. Full gate: dispatch QA (batch-gate brief) — a runner slot if runners are enabled. Save the report to
      docs/reports/{EPIC}-batch-gate.md (a failed run as -run{N}).
   4. Red → fix loop: a Developer on fix/{EPIC}-gate-run{N}; verify by diff; fast-forward; QA re-runs from the failed
      step. No bug, no review.
   5. If main gained code since step 1: Deploy main-in again, then QA again (from the start of the core row).
   6. Resolve the notes file; triage the open follow-ups (process.followups_gate).
   7. Epic (or batch) → ready_for_deploy. Dispatch Deploy (delivery brief): temporary detached worktree from
      origin/main, one --no-ff merge with the release notes, code-equality check, plain push. The PM holds its own
      pushes to main meanwhile.
   8. MERGED → deployed. Apply process.main_regression (C26; fast-lane default if_main_gained_code): no code path
      differs from the gated sha → decision line, epic → done, archive sweep, in one step. Otherwise QA regression
      on main.
   9. If items remain (a cut batch): epic back to in_progress. Otherwise archive sweep, worktree removal.
   10. Refinement: dispatch only if no milestone plan is the live refinement.
   11. Demo: per process.demo_gate (default on_request: decision line, continue; offer the demo when the user returns).
   ```
6. **Budget gate (L188–196).** In the fast lane it fires when a fix pass leaves a blocking finding open by the PM's diff
   check. This trigger is proposed, not observed.
7. **New section, "Cross-epic integration"** (C11): feature cut from a feature, feature-in merges, delivery-order
   decision lines, parallel gates, cherry-picked meeting fixes.
8. **New section, "Mid-flight rulings"** (C12).
9. **New section, "Milestones"** (C13, C29): the slice document, the recut before the milestone starts, progress in
   delivery decision lines. From C29:
   - the dialogue procedure that creates or edits a milestone (§3 C29 (d) point 3), and milestone directives in Step 2;
   - the milestone transitions: `planned → in_progress` with the first dispatch of a linked item, after the recut check;
     `→ delivered` after the last linked epic is `done`; `→ demoed` only on the user's word;
   - the delivery decision line names the milestone and its count from state, not from the slice document.
10. **Git policy (L224–228).**
    - The main checkout stays on `main`.
    - State is committed by path.
    - Planning agents work in their own worktrees.
    - Deploy pushes on green (`process.deploy_push`).
    - The PM holds its own `main` pushes during a delivery.
    - No attribution trailers.
    - The PM's permitted git plumbing: fast-forward, plain push, trailer amend on an unpushed agent commit, worktree
      removal.
11. **PM constraints (L230–246).**
    - Keep "never writes code".
    - Add the fast-lane exception: "reads a fix pass's or batch fix's diff against the named findings; this replaces a
      second review round".
    - Add: "never reads an old runner log as a pass; resumes interrupted teammates via SendMessage after limits or a
      dropped connection".
12. **Main regression (C26).** The batch end's step 8 and the classic epic flow (the `deployed` row, L169) apply
    `process.main_regression`: `always` dispatches QA; `if_main_gained_code` runs the count test of C26 (d) first;
    `never` skips. Each writes a decision line; the PM may dispatch QA anyway on a decision line naming the reason.
13. **Stack leases (C27; design in §5.1).** Take the lease in the same step as the dispatch and its working status;
    release it after the report is verified; in the stale-worktree check (L107–111), find stale leases, reset their slots
    and release them with a decision line. The narration names a dispatch that waits for a lease.
14. **Tracker backend (C28; design in §5.2).**
    - Step 1 reads the backend from `project.json`.
    - When the backend is remote: a sync step at session start and before each dispatch round (pull and reconcile;
      retry the push queue).
    - The dispatch loop registers, transitions and logs through the backend interface of `sdlc-state` §0 instead of
      editing files.

### 4.3 `skills/sdlc-state/SKILL.md`

- **§0 (new), Tracker backend (C28; design in §5.2):** the interface every other section is written against: read
  items, register, transition, log, follow-ups, notes, reviews and reports, claim and release, sync. The local-files
  implementation (today's §1–§7) comes first. A Jira implementation adds its status mapping, ownership rule, push queue
  and, if adopted, the gate's human-tail and external-surface laws.
- **§1 (L27), PM-only documents:** add `docs/reviews/{EPIC-ID}-notes.md` and `docs/reports/{EPIC}-batch-gate*.md`.
  Add: "The main checkout stays on `main`, because the tracker reads its working tree. Commit state by path."
- **§2:** no change to the buckets. After a batch delivery, an epic with remaining items returns to `in_progress`.
- **§3 envelope:**
  - optional lines `REPORT FILE: {path}` (review documents, gate reports) and `CONTINUE: {next task}` (planned
    hand-off);
  - EVIDENCE lines for the targeted set carry `selected because {reason}`;
  - a size cap from `process.report_max_chars`.
- **§4, lane table** (insert before the tier table):

  | | `classic` (1.6.1) | `fast` (default) |
  |---|---|---|
  | Developer and bug proof | full gate | targeted set (quality-gate.md §Per story) |
  | Review rounds | by return budget | **1** |
  | Return budget | tier: 1 / 2 / 3 | **1** at every tier |
  | Rework verification | re-review (scope law) | **PM reads the fix pass's diff against the findings** |
  | QA per story | by tier | **none** |
  | Regression after a story merge | yes | **none**; whole static analysis on real merges, changed scanners re-run |
  | Full gate | every merge | **once per batch**, after main-in |
  | Merge failure | bug | `fix/{ID}-merge` + merge-fix Developer |
  | Epic done | main regression passed | main regression passed, or skipped when main gained only docs |

  The tier still decides the reviewer lenses and whether an IMPORTANT blocks in round 1.
- **§4 Story machine (fast):**
  ```
  todo → in_progress → ready_for_review → in_review → ready_for_merge → done
                               review_rejected ←┘   ↑
                                     └→ in_progress (fix pass) ─┘ (PM diff check)
  ```
- **§4 Notes (new):** the file, the line format, the four resolutions (Appendix B), and counter `note`.
- **§4 Follow-ups:** a project-wide `FU-{n}` sequence (counter `followup`), plus `owner:`, `— closed by {ID}: {how}`,
  and triage at batch end (C8).
- **§4 Epic:** `ready_for_deploy` = the batch's full gate PASSED, with notes resolved and follow-ups triaged.
  `deployed → done` also by the decision line "main regression skipped (docs only since the gated merge)", per
  `process.main_regression` (C26).
- **§5, transition rows to add (fast):**

  | From | Event | To | Also |
  |---|---|---|---|
  | in_review | Reviewer APPROVED | ready_for_merge | decision line "QA skipped: fast lane"; NOTEs → notes file |
  | in_review | Reviewer REJECTED (returns 0) | review_rejected | `returns` + 1; review saved; NOTEs → notes file |
  | review_rejected | PM dispatches the fix pass | in_progress | fresh teammate `{role}-{ID}-fix` |
  | in_progress | Developer IMPLEMENTED (fix pass) + PM diff check passes | ready_for_merge | log "report: Developer (fix pass); PM verified the diff" |
  | ready_for_merge | PM fast-forward (story contains the feature tip) | done | decision line `fast-forward: {feature} {a}..{b}` |
  | ready_for_merge | Deploy MERGED | done | decision line "regression QA skipped: fast lane" |
  | ready_for_merge | Deploy VERIFICATION_FAILED | ready_for_merge | dispatch a merge-fix Developer on `fix/{ID}-merge`; **no bug** |
  | ready_for_merge | Developer IMPLEMENTED (merge fix) + PM diff check | done | the PM fast-forwards the feature |
  | epic in_progress | QA (batch gate) PASSED | ready_for_deploy | report saved |
  | epic in_progress | QA (batch gate) FAILED | (unchanged) | dispatch a fix-loop Developer; no bug |
  | epic ready_for_deploy | Deploy (delivery) MERGED | deployed | — |
  | epic deployed | decision: main regression skipped | done | archive sweep |
  | epic deployed (cut batch, items left) | decision | in_progress | — |

- **§6 schemas:**
  - `project.json.process` (§5 of this document); counters `note` and `followup`;
  - a worktree entry gains an optional `"runner": "{runner} slot {x}"`, which a lease record replaces once C27 is
    designed (§5.1: holder item and agent, host and slot, base SHA, taken at, state);
  - optional epic fields `milestone`, `continued_by`, `base_branch`, `carries`, `batches`;
  - the new `project.json` keys of C25, C26 and C28 (§4.13).
- **§7 log:** the trigger vocabulary of Appendix G. Decision-line notes are fixed for the fast-lane mechanics: "QA
  skipped: fast lane", "regression QA skipped: fast lane", "fix pass verified by the PM reading {range} against
  {findings}", `fast-forward: …`, "main regression QA skipped: …". `correction` lines void earlier lines instead of
  editing them.
- **Milestones (C29), across the sections:**
  - §2: milestones live in `epics.json` (or `milestones.json`, Q19) and are never moved by the bucket law; an archived
    epic keeps its `milestone` field;
  - §4: a Milestone machine, `planned → in_progress → delivered → demoed`, `demoed` on the user's word only;
  - §5: the four rows of C29 (d) point 2, plus the recut check before `planned → in_progress`;
  - §6: the milestone entry, `milestone_order`, the epic's `milestone` field (no longer optional prose), an item's
    `milestone` field for the uncut exception, and the counter `milestone`; the two sides of a link written in one
    response;
  - §7: a log line's `item` may be a milestone ID; `recut` lines keep naming the milestone.

### 4.4 `skills/story-merge/SKILL.md` (Deploy)

Rewrite it with four modes. The conflict-resolution law stays, with these additions:
- **Generated files**: regenerate them with the project's generator, never hand-merge; commit each only if it differs.
- **Docs and rules in a main-in**: take `main`'s side, then prove nothing of the feature's own was lost with `git diff
  origin/main HEAD -- {docs paths}` empty.

| Mode | Working dir | Verification | Green | Red |
|---|---|---|---|---|
| story merge | `{EPIC}-merge` worktree | changed whole-tree scanners; on a real merge, whole static analysis + the story's modules + consumers of changed shared code + replay if workflows changed; content guard; ancestry | plain push of the feature; ls-remote | push the merge to `fix/{ID}-merge`; VERIFICATION_FAILED |
| main-in (batch end) | `{EPIC}-merge` | whole static analysis + the modules both sides touched + whole-tree checks + replay + client drifts + content guard + ancestry + zero-line state diff + marker scan | push the feature | push to `fix/{EPIC}-main-in` |
| feature-in (cross-epic) | `{EPIC}-merge` | as main-in | push the feature | push to `fix/{EPIC}-{OTHER}-in` |
| delivery | temporary detached worktree from `origin/main` | ancestry both ways; per-directory counts; **code-equality to the gated sha = 0**; content guard | plain push to `main`; remove worktrees | a code conflict → MERGE_FAILED |

Other edits:
- **Protocol step 4:** replace "run ALL commands" with the mode's verification.
- **Step 6 "Do NOT push":** becomes "push on green per `process.deploy_push`; never push red to a feature or `main`".
- **MUST NOT "'Fix' verification failures":** keep. Deploy still never patches code; the merge-fix Developer does.
- **Report EVIDENCE:** the merge sha, the conflict classes, each regenerated file and whether it differed, the static
  analysis lines, the test counts, the ancestry lines and the `ls-remote` line.
- **`agents/deploy.md`:** move pushing into Owns (on green); update the description.

### 4.5 `skills/sdlc-dispatch/SKILL.md`

- **§1:**
  - add a Model column (`process.models`);
  - rewrite the brief-cap law as slots: WHY, KIND/TIER/ROUND, WORKTREE (base sha and what the tree has), CARRIED IN
    (optional), INPUTS, SELECTION/CHECKS, STACK, DISCIPLINE (with `{standing lines}`), DELIVERABLE, VERIFICATION,
    REPORT (cap). Free text is allowed only in WHY and CARRIED IN, with a character cap (Q3).
- **§2:**
  - "Deploy is exclusive **per target branch**: one merge into a branch at a time; merges into different branches may
    run together; other agents keep working";
  - add the **stack budget**: at most `max_local_stacks` agents with a local stack; stackless agents and runner slots
    do not count;
  - **the lease model (C27; design in §5.1)**, which replaces the bare budget rule once designed: never two agents on
    one stack; a bounded pool per host (local slots plus runner slots); a lease taken with the dispatch and released
    after verification; stale-lease recovery. With one local slot and no runners it is the sibling plugin's per-repo
    lock.
- **§3:**
  - add verification rows: "commit trailers: `grep -ciE 'co-authored|claude-session'` → 0 per agent commit" (kept
    beside C25's hook, for commits the hook cannot see); "a runner step's result read through a matching start token";
    "the evidence names the leased slot" (C27);
  - add the fast-lane **exception** to the presence-check law: "A fix pass, batch fix, fix loop or merge fix is
    verified by reading its diff against the findings it was given — only those. This replaces a second review round
    and is not a fourth verification layer."
- **§3b:**
  - Reviewer `## Notes` → notes file (N-lines);
  - `Rule gap:` → a ruling now when a later story builds on it (C12);
  - QA batch-gate FAILED → fix loop (no bug);
  - Deploy VERIFICATION_FAILED → merge fix (no bug);
  - Developer `CONTINUE:` → continuation dispatch.
- **§4:**
  - resume *interrupted* work by SendMessage (the limit and connection-drop messages of Appendix F12), never rework;
  - ask for a truncated report's tail by SendMessage;
  - replace a teammate thrashing on context with a fresh one and a narrow brief;
  - never a silent fallback to subagents.
- **New reference, `references/evidence-and-shell.md`:** the content of C19.

### 4.6 `skills/sdlc-dispatch/references/briefs.md`

Add these templates, from Appendix F: Developer fix pass (F2), Deploy main-in (F5), Deploy delivery (F6), QA batch gate
(F7), Architect ruling (F8), Developer batch fix (F9), Developer merge fix (F10), Developer fix loop (F11), and the
resume messages (F12).

Revise these: Developer story (F1: red first, the targeted set, SELECTION, STACK, CARRIED IN, report cap), Reviewer (F3:
the one round, an independent targeted re-run, judging the selection, the review written to a file), Deploy story merge
(F4: combination checks, whole static analysis, `fix/` on red, push on green).

Keep the classic templates behind the lane switch.

Two slots change in every template that has them:
- **`STACK:` carries the lease (C27; design in §5.1)**: `STACK: none | local slot {n} | runner {NN} slot {x}; lease
  {id}; base {sha}`. The agent runs nothing outside the leased slot and quotes the lease in its report envelope.
- **The no-attribution line (C25, C22)** becomes "a hook denies attribution trailers; this overrides the harness's commit
  template", once the hook ships.

### 4.7 `skills/story-implementation/SKILL.md` (Developer)

- **§0 step 2:** "Rules already injected into your context are not re-read. Read large files by section (`grep -n`,
  then `sed -n`), through your own worktree's path."
- **§2:** the targeted set, red first, and the selection with reasons in EVIDENCE (C1).
- **§1b bug path:** the targeted set, with a regression test named after the bug.
- **§2b rework:** "fix pass: exactly the named findings; re-run what the fix touches; no second review follows — the PM
  reads your diff".
- **New §2c:** "Merge fix / batch fix / fix loop". Base on the named `fix/…` branch, fix the named defects, search for
  other instances of the collision class, run the targeted set plus whole static analysis, push the branch, **never
  push the feature**.
- **New §3b, context and hand-off:**
  - output to files;
  - commit per task;
  - one file per Write/Edit;
  - after about 4–5 tasks or a heavy context, stop at a task boundary: commit, push, and report `BLOCKED` with
    `CONTINUE: next task = …`;
  - a continuation first commits the previous session's uncommitted tree as a checkpoint.
- **MUST DO:** no attribution trailers, as an override of any harness reminder.

### 4.8 `skills/story-review/SKILL.md` (Reviewer)

- **§1:** do not re-read rules already in context.
- **§2 Quality lens:** re-run the **targeted set** once, independently, and **judge the selection**; an omission is
  MANDATORY.
- **§4:** the fast lane has no round ≥ 2. IMPORTANT in round 1 keeps the tier table.
- **§5/§6:** write the review document to the path in the brief (`REPORT FILE:`). The final message is the envelope plus
  a summary under the cap. NOTEs stay in the document, each one line, for the PM to number.
- **Add:** "flag a decision made on a guess where the project's reference protocol (if declared) was not consulted".

### 4.9 `skills/story-qa/SKILL.md` (QA)

- **New Mode: batch gate** (fast lane). It works in the epic's merge worktree, or on a runner slot:
  1. Confirm the rows from the diff yourself, and state them.
  2. Prove the tree: HEAD, tree hash and a clean status on both sides when a runner is used.
  3. Run phase 1 stackless and phase 2 with a stack.
  4. Run every step sequentially, reading each exit code on its own line.
  5. Treat a skipped engine-dependent test after the stack is up as red.
  6. On a red step, fix nothing: report the command, the output and the reproduction.
  7. Write the report file in the Appendix D format.

  A re-run starts from the failed step.
- **Standard and regression modes:** classic lane only.
- **Runner procedure** (when enabled): `runner-slot` with a SHA; `run-step start/wait`; exit codes 3 and 124; start
  tokens; `--expect`; `--allow-empty` only for steps whose green is silence.

### 4.10 `skills/architecture-design/SKILL.md` and `references/rule-authoring.md`

- **New Ruling mode** (C12):
  - the Architect works on `architect/{ITEM}-{topic}` from `main`, in its own worktree;
  - it edits docs, rules and ADRs only;
  - it gives a verdict on every option;
  - it answers "which story builds it" and "what the waiting story does meanwhile";
  - it runs the content guard on every touched file;
  - it keeps the report short.
- **Batch-end notes triage:** rule-gap notes are ruled on a planning branch, in parallel with the batch-fix Developer.
- **rule-authoring.md, a "rules budget" section:** always-loaded files hold pointers; detail lives in path-scoped files.
  Measure the bytes loaded for a typical module path.
- **Design Mode deliverable:** `quality-gate.md` now also needs §Per story and the whole-tree-check table filled.

### 4.11 `skills/brd-writing/SKILL.md` and `skills/story-breakdown/SKILL.md`

- **Product Manager, "milestone recut" mode.** Split every contributing epic into a milestone epic (which keeps its ID)
  and a remainder epic (new ID, `ready`, own `epic.md`, `**Continued by:**` on the original). Report the re-parenting
  for the PM to apply.
- **System Analyst, "milestone slice" mode.** Give a verdict per prerequisite: satisfied, a named minimal slice written
  into both story files, or pulled in whole. Cut one new story from a ruling when asked. Run an "amendment pass" after
  the Architect's design changes stories.
- **Both:** the app-first cut line as a standing brief line (C22).
- **Product Manager, milestone mode (C29)**, extending the recut mode: from the goal and demo in the brief, produce the
  slice placement, the epics that deliver the milestone, the recut data and a `MILESTONE` registration block in DETAILS
  (id, title, goal, target, epics, stories, `slice_doc`, `planned_count`). The PM applies it. The dialogue with the user
  stays in the PM session unless Q19 gives the Product Manager a question tool.
- **System Analyst, milestone slice mode (C29):** its report carries the slice's final count, which becomes
  `planned_count`.

### 4.12 `agents/*.md`

| File | Change |
|---|---|
| `developer.md` | L34: the targeted set, not "every quality-gate command"; add the planned hand-off; no attribution (override). |
| `reviewer.md` | L16: re-run the targeted set; judge the selection; the review goes to a file. |
| `qa.md` | description: "runs the batch-end full gate (fast lane); E2E and regression in the classic lane". |
| `deploy.md` | description and Scope: pushes on green, red to `fix/…`, modes story / main-in / feature-in / delivery; exclusive per target branch. |
| `architect.md` | add Ruling mode to the description and OUTCOME values. |
| `pm.md` | the fast-lane exception to "presence check"; permitted git plumbing; the main checkout stays on `main`. |

### 4.13 `commands/init.md`

- **The project.json template (L60–91):**
  - add `process` (§5) and `max_local_stacks`;
  - add counters `note: 0` and `followup: 0`, and `milestone: 0` (C29);
  - make `max_parallel_teammates` user-adjustable (EMI runs 6);
  - **the keys of C25–C28**, in the template and in the `sdlc-state` §6 schema:

    | Key | Default | Change |
    |---|---|---|
    | `process.commit_attribution` | `false` (the hook enforces) | C25 |
    | `process.attribution_patterns` | `["co-authored-by", "generated with", "🤖", "claude-session"]` | C25 |
    | `process.commit_conventions` | `null` (no prefix check) | C25 |
    | `process.main_regression` | `if_main_gained_code` (fast lane); `always` (classic lane) | C26 |
    | `process.docs_only_paths` | `["docs/", ".claude/", "docs/state/"]` (as in §5.3) | C26, Q10 |
    | the stack pool | to be designed; until then `max_local_stacks: 2` | C27, §5.1 |
    | `tracker` | `{"backend": "local"}` | C28, §5.2 |
- **The CLAUDE.md managed block (L122–142):** replace "then Reviewer, then QA, then Deploy" with lane-aware wording, for
  example "then one Reviewer round, then Deploy; the full gate runs once per batch (fast lane)".
- **`.gitignore`:** nothing new. The notes and report files are committed.
- **Phase 1:** ask for the lane (default fast), the shell (zsh/bash), whether a content guard exists, and whether runners
  are available. Ask for the tracker backend (default local; C28) once §5.2 is settled.
- **Settings (C25):** when `process.commit_attribution` is false, write the project `.claude/settings.json` attribution
  settings C20 records, and list the attribution hook among the active hooks in the summary.
- **`epics.json` template (L94) (C29):** `{ "priority_order": [], "epics": {}, "milestones": {}, "milestone_order": []
  }`. A repair run adds the two empty keys to an existing file. With the command option of Q19, `init` also lists
  `/agent-sdlc:milestone` in the CLAUDE.md managed block.

### 4.14 `commands/status.md` and the tracker

- **Status:**
  - show each epic's batch-end step (main-in, batch fix, gate run N, delivery);
  - show open `fix/…` branches;
  - show the notes-file count and the open follow-ups;
  - show progress per milestone: the Milestones block of C29 (d) point 5, above Epics, with each epic line naming its
    milestone.
- **Tracker (optional):** show the batch-end stage. For milestones (C29 (d) point 6): a Milestones view with a card per
  milestone (status, target, epic and item progress bars, its epic cards, archived ones included), a milestone chip on
  every roadmap epic card, and grouping of the roadmap by milestone. `app.js` renders it; `server.py` needs a change
  only if milestones get their own file.
- **Leases (C27):** show every stack lease in use (host and slot, holder, base SHA, age) and flag stale ones.
- **Per backend (C28):** local, as today. Remote: the local mirror, with the last sync time, the push-queue length,
  the drift anomalies and a link per item, as the sibling plugin does; whether `status` also queries the tracker live
  is open (§5.2).

### 4.15 `hooks/`

- Keep `guard-git.sh` (no force push, no `-X ours/theirs`); EMI relied on it.
- Add **`hooks/scripts/guard-commit.sh`** as C25 (d) specifies. In `hooks/hooks.json` it is a second command hook in the
  existing `PreToolUse` entry with the `Bash` matcher, after `guard-git.sh`, timeout 10:
  - scope: walk up from `.cwd` or the `-C` path to `docs/state/project.json`;
  - switch: `process.commit_attribution` (default `false`, the hook enforces);
  - patterns: `process.attribution_patterns`, without the sibling plugin's `[by `;
  - commands: `git commit` in every form, `git merge -m`, `gh pr create|edit` with a title or body, and the files named
    by `-F` and `--body-file`;
  - optional prefix check from `process.commit_conventions`;
  - output: a `permissionDecision: "deny"` naming the matched pattern, with the override wording of C20.
- Optional: a content-guard pre-commit hook, when `content_guard.pre_commit` is set.

### 4.16 `templates/` (new files)

- `demo-slice-template.md`: the C13 structure.
- `notes-file-template.md`: the header plus the line format (Appendix B).
- `batch-gate-report-template.md`: Appendix D.
- `delivery-commit-template.md`: Appendix E.

### 4.17 `README.md` and `docs/`

- **README Workflow (L45–49):** the two-level verification.
- **README Git strategy (L70–74):** the fast lane, `fix/` branches, delivery with release notes.
- **README Model choice (L93):** tiering and the large-context caveat.
- **New design record `docs/plans/{date}-fast-lane-design.md`**, mirroring the 1.6.0 round-economy record: the
  problem, the measurements, the mechanisms.

---

## 5. Open questions and choices for the plugin author

Two headline questions come first. Each is a design problem for the plugin's Architect, with the requirement, the options
and the questions to settle; this document decides neither. The `process` block and the smaller questions follow in
§5.3.

### 5.1 Headline open question A — test stacks: a lock, or a pool of leases? (C27)

**The requirement.** EMI's practice (C14, C15), stated as rules:
1. **Never two agents on one stack.** A stack is one Compose project on one host, bound to one worktree or one agent.
2. **A bounded number of stacks per host.** The local machine has a cap (EMI: two); each runner has a slot count set by
   its size.
3. **Stacks are a pool of leases**: local slots plus remote runner slots. A lease binds one slot to one holder (an item
   and the agent working it) and to one base SHA.
4. **Release on report, and on crash.** A verified report releases the lease. A holder that died does not keep its slot:
   a stale lease is found, its slot is reset, and only then is the slot leased again.
5. **The PM allocates, and the brief carries the lease.** The agent knows where its stack is and runs nothing elsewhere.
6. **The local-only case degrades to the sibling plugin's lock**: a pool of one local slot and no runners.

**The two designs it must reconcile.** The sibling plugin serializes: a `mkdir` lock per repository in the hub, taken
and released by the PM, with no holder, expiry or crash rule (C27 (b)). EMI parallelizes: two local stacks plus runner
slots, allocated by the PM in `project.json` (`worktrees[*].runner`), with SHA-only slot set-up, start tokens and
resets, but no mechanical guard.

**Options.**

| # | Option | For | Against |
|---|---|---|---|
| L1 | **The sibling plugin's `mkdir` lock, made counting**: one directory per slot and host (for example `.stack-lock-{host}-{n}`), taken by the PM with `mkdir` and released with `rmdir` | atomic with no service; proven code; the one-slot case is exactly the sibling plugin | records no holder, SHA or time; a crash leaves it held; invisible to status and the log; says nothing about remote hosts |
| L2 | **A lease table in project state** (for example `project.json.stacks`), written only by the PM, committed, logged like a transition: per slot the host, holder item, agent, base SHA, time taken and state | fits the single-writer law; visible in status, the tracker and the log; survives a PM restart; recovery is a state rule | needs no atomic primitive only while there is one PM; with several PM sessions sharing runners (C28) it becomes a shared-write problem |
| L3 | **A lease file on the host**, beside the slot (a runner's slot directory, a local lock directory), holding the holder and a token | the truth sits where the stack is; several PM sessions or people sharing runners see the same lease | a remote round trip per allocation; state and host can disagree; needs its own crash rules |
| L4 | **Hybrid**: the PM's state holds the allocation (L2), and the host holds a fencing token (L3), the same start token C14 already binds step results to; the PM reconciles both on `/start` | a stale holder cannot act on a slot it lost, because its token no longer matches; the table stays readable | the most moving parts; two places to repair |

**Stale-lease recovery, whichever option.**
- Where: in `/start`'s stale-worktree check. A lease is stale when its holder item is not in a working status, or its
  named teammate is gone.
- How to decide liveness: an expiry (time taken plus a maximum per mode, for example twice a gate's measured length), or
  a probe (the holder's last step file on the runner; the Compose project's containers on the slot).
- What recovery does: always reset the slot (down with volumes, clean tree) before leasing it again, and write a
  decision line.

**Allocation and briefs.**
- The PM takes the lease in the same step as the working-status transition, before the dispatch; a failed dispatch
  releases it.
- The brief's `STACK:` slot (C15) becomes `STACK: none | local slot {n} | runner {NN} slot {x}; lease {id}; base
  {sha}`. The agent quotes the lease in its report, so the PM can check that the evidence came from the leased slot.
- A Reviewer's re-run on the story's own slot (C14) is a lease **transfer** from the Developer, not a second lease.

**Degrading to the sibling plugin.** A pool of `[{host: "local", slots: 1}]` with no runners behaves as its lock. A
multi-repository workspace could keep its per-repository cap (`gate_concurrency`) as an extra constraint on top of the
per-host pool.

**Questions to settle.**
- Is the unit a stack held for a whole story (hours; EMI's Developer stacks) or a gate run (minutes; the sibling
  plugin's lock covers one dispatch)?
- Is the local cap a configured number (`max_local_stacks`, C15) or measured from memory and CPU?
- Who resets a slot: the releasing agent, the PM, or the next holder's set-up (EMI: `RESET=1` at the next set-up)?
- Does a stackless agent ever need a lease, for example for a client build that starts containers? In EMI, no.
- Where does the runner inventory live (C14's `integrations.runners.inventory`), and does the pool read it or copy it?
- With several PM sessions (C28), is the pool per session, per person, or shared?
- Should the plugin ship L1 as the default and L2 or L4 behind `integrations.runners`?

### 5.2 Headline open question B — the tracker backend: local files or Jira (C28)

**The requirement.** A project chooses where its items and statuses live, the local files of today or Jira, so that
several people can work on one project. Nothing is proven for more than one PM per project (C28 (c)).

**A backend interface** that the PM and the skills call instead of editing files:

| Operation | Local files (today) | Jira (the sibling plugin's hybrid) |
|---|---|---|
| read items (scope, bucket) | `epics.json`, `active.json`; `jq` counts elsewhere | one JQL snapshot per active epic, reconciled into a local mirror |
| register (epic, story, bug; the ID) | a counter in `project.json`; an entry in the bucket file | a planning agent in the PM session creates the issue; its key is the ID; the PM registers it from the report |
| transition (from, to, evidence) | edit the entry; append to `log.jsonl`; commit | local status as today; the mapped Jira status pushed in the background; queued on failure |
| log (transition, decision and dispatch lines) | `log.jsonl` | local `log.jsonl`; nothing mirrored (open: selected lines as comments?) |
| follow-ups | `followups.md` per epic, `FU-{n}` | stay in git, or become Jira issues (the sibling plugin: real issues, never meta-comments) |
| notes (C3) | the notes file per epic | stay in git (open) |
| reviews and reports | files; paths in state | files in git (the sibling plugin keeps them local) |
| claim and release an item | implicit: one PM | the assignee, for a human; a session holder (open) |
| sync | none | pull at session start and before each round; the push queue retried each round |

**Configuration** in `project.json`: a `tracker` block, for example `{"backend": "local"}` or `{"backend": "jira",
"jira": {site, project key, issue types, status map, scope query}}`, or the sibling plugin's proposed
`integrations.issue_tracker: {type, mapping}`. Which name to use, and whether credentials live in a git-ignored file or
only in the MCP server's configuration, is open.

**Options.**

| # | Backend | For | Against |
|---|---|---|---|
| T1 | **Local files only** (today) | proven; one writer; everything in git | one PM per project; no view for people outside the repository |
| T2 | **Jira for composition, local files for execution** (the sibling plugin) | proven there; people see stories and statuses in Jira; the pipeline's fine status and evidence stay fast and private | several PM sessions not covered; two sources reconciled every round; reviews and the log invisible in Jira |
| T3 | **Jira as the full canon**: every pipeline status is a Jira workflow status; local state is a cache | one truth for every person and session; Jira's transition rules refuse a transition from a status that has moved on, which acts as a compare-and-set | a custom Jira workflow per project; a network call per transition; no natural place for the fast lane's epic-level steps; Jira down stops the pipeline |
| T4 | **Shared git state**: today's files on a shared remote, one PM per epic | no new service; small teams without Jira | merge conflicts on JSON state; no view for people outside the repository beyond the tracker |

**Questions to settle.**
- **What stays in git whatever the backend.** Candidates: the story body and its acceptance criteria (agents read the
  `.md` in their worktree today; the sibling plugin pastes them into briefs instead), reviews, reports, the notes file,
  the follow-ups file, the transition log, directives. The sibling plugin keeps reviews, reports and the log local.
- **Concurrency and ownership.**
  - Several PM sessions: one per project (a PM lease held in the tracker), one per epic (the epic records its PM
    session), one per person (the sibling plugin's assignee scope, with private execution state), or optimistic writes
    with conflict detection?
  - Claiming an item: the Jira assignee for the human, plus a session holder with an expiry? In which field?
  - Conflicts: what happens when a human moves an issue the pipeline owns (the sibling plugin: an anomaly, never
    overwritten; Done before merge parks the item), and when two sessions transition one item.
- **Identity.** Which human holds an item (the assignee); which PM session and which agent (a label, a custom field, or
  local state only). The sibling plugin bans pipeline vocabulary from Jira: does agent-sdlc adopt that for every remote
  backend?
- **IDs.** Tracker keys as IDs (the sibling plugin), or local IDs with the key as an attribute; and what branch,
  worktree and teammate names use.
- **Migration from local to Jira.** Create issues for the open epics, stories and bugs; keep the old ID on the issue (a
  label or a field) and a mapping file in git; leave `done` items and the archive local. What happens to log lines and
  documents that cite old IDs?
- **The fast-lane statuses of C4 on a Jira workflow.**
  - A story is `done` when it is merged into the feature branch, but reaches `main` only at the batch delivery. Is
    READY FOR TESTING (or its equivalent) pushed at delivery, as the sibling plugin defers it in `epic_pr`, or at the
    story merge?
  - Where do the epic's batch-end steps (main-in, batch fix, gate run N, fix loop, delivery) show: in the epic's status,
    as one comment per step, or nowhere?
  - Do the fix branches stay log-only (Q8)?
- **The tracker view.** Local: today's `/agent-sdlc:status` and tracker over the files. Jira: `status` reads the local
  mirror plus the last sync time and the push queue (the sibling plugin), or queries Jira live; the tracker shows drift
  anomalies and other people's items.
- **Tools and credentials.** MCP in the PM session only (teammates do not inherit it, which is why the sibling plugin
  runs its planning agents as foreground subagents), or REST with a token. The call budget per round (the sibling
  plugin: at most two JQL calls per epic per round).
- **The human tail.** Does the plugin adopt "never Done, never reassign" as the default for a remote backend?
- **Milestones on Jira (C29).** Not observed in agent-sdlc-gate, which has no milestones. Options:
  - **a fix version (release) per milestone**: the release date is the target, and "released" means `delivered` or
    `demoed`; Jira's own version views then show progress. But a version counts the issues that carry it, so every story
    needs the fix version, not only its epic; and people may already use versions for real releases;
  - **a label** per milestone: cheap, but no date, no status, no view of its own;
  - **a custom field** on epics and stories: exact, but set up per Jira site;
  - **an issue type above Epic**, where the Jira plan offers one: the milestone becomes the epics' parent, which is
    exactly C29's link, at the cost of a hierarchy change the pipeline does not own;
  - **local only**: milestones stay in state, and the tracker links their epics to Jira.

  And which side wins: the milestone the user defined in dialogue, or Jira's composition, which wins in the sibling
  plugin?

### 5.3 The `process` block and the smaller questions

A proposed `project.json.process` block, with defaults. Each key corresponds to a trade-off EMI made one way.

```json
"process": {
  "lane": "fast",                              // "fast" | "classic" (1.6.1 behaviour)
  "review_rounds": 1,                          // fast lane: 1
  "fix_pass_verification": "pm_diff",          // "pm_diff" | "re_review"
  "per_story_qa": false,
  "per_merge_regression": false,
  "batch_default": "epic",                     // PM may cut earlier
  "main_regression": "if_main_gained_code",    // "always" | "if_main_gained_code" | "never" (C26); classic: "always"
  "docs_only_paths": ["docs/", ".claude/", "docs/state/"],
  "followups_gate": "triage",                  // "triage" | "hygiene_bug" (1.6.1)
  "demo_gate": "on_request",                   // "on_request" | "blocking" (1.6.1) | "off"
  "planning_depth": "just_in_time",            // "just_in_time" | "all"
  "deploy_push": "on_green",                   // "on_green" | "never" (1.6.1)
  "deploy_exclusivity": "per_target_branch",   // "per_target_branch" | "per_epic" (1.6.1)
  "max_local_stacks": 2,                       // C15; C27 may replace it with a lease pool (§5.1)
  "report_max_chars": 3500,
  "commit_attribution": false,                 // false: the C25 hook denies attribution trailers
  "attribution_patterns": ["co-authored-by", "generated with", "🤖", "claude-session"],   // C25
  "commit_conventions": null,                  // C25, e.g. {"prefix_pattern": "^{PREFIX}: "}
  "shell": "zsh",                              // "zsh" | "bash" — selects the shell rules
  "models": { "default": "inherit", "Deploy": "sonnet", "QA:batch_gate": "sonnet" },
  "standing_brief_lines": { "all": [], "Developer": [], "Architect": [], "System Analyst": [] },
  "content_guard": null                        // e.g. {"command": "make banned-terms", "pre_commit": true}
},
"integrations": { "runners": { "enabled": false, "tooling_dir": null, "inventory": null } },
"tracker": { "backend": "local" }              // C28: "local" | "jira"; design open (§5.2)
```

**Questions and trade-offs:**

- **Q1 — Default lane.** EMI's evidence favours `fast` for any project whose full gate takes more than a few minutes or
  needs containers. A tiny project gains little. Proposal: `fast` by default; `init` may suggest `classic` for projects
  with a gate under about 2 minutes.
- **Q2 — A fix pass that does not fix its finding. Not observed in EMI.** The rule allows no second return. Options:
  - (a) park and run the budget gate (one more round / accept / park), which is consistent with 1.6.1;
  - (b) a second fix pass without review.

  Recommend (a).
- **Q3 — The brief cap versus long briefs.** EMI briefs run 3–6 KB and carry per-item facts the templates have no slot
  for: the base sha and what the tree has, facts carried in from sibling stories, the selection with its reasons, and
  the runner commands. 1.6.1's cap exists for a real reason (CBS epic 1's 100–200-line briefs). Proposal: keep the cap,
  but define structured slots with their own caps, and count only WHY and CARRIED IN as free text.
- **Q4 — PM diff reads versus "verification is a presence check".** This is a deliberate, scoped exception (fix pass,
  batch fix, fix loop, merge fix). Make it explicit, or reviewers of the plugin will see a contradiction.
- **Q5 — PM git plumbing versus "the PM never writes code".** Fast-forwards, plain pushes, trailer amends and worktree
  removal were done by the PM. The alternative is a Deploy dispatch for each fast-forward, which costs an agent per
  merge. Recommend listing the permitted plumbing explicitly.
- **Q6 — The tier's role in the fast lane.** EMI keeps tiers for reviewer lenses and IMPORTANT blocking, but the return
  budget collapses to 1. Decide whether the tier still scales anything else, for example the whole-static-analysis
  requirement on merges.
- **Q7 — Numbering.** EMI's N-{n} and FU-{n} run project-wide, which makes carrying items between epics trivial.
  1.6.1's example is per-epic. Recommend project-wide counters in `project.json`.
- **Q8 — Fix-branch work in state.** Batch fixes, fix loops and merge fixes are **not** state items in EMI. They are
  log lines on the epic or story, with no status. Keep them log-only, or add `kind: fix` entries? Log-only is simpler
  and was sufficient.
- **Q9 — Runners.** Ship only the protocol (slots, SHA-only, start/wait exit codes, start tokens, pending markers,
  sync-cache reset after a merge), or also a generic reference script? The host specifics (addresses, SSH config,
  provider) must stay out either way.
- **Q10 — Which paths count as "docs only"** for the main-regression skip and the delivery conflict rule. Make it a
  list; EMI used documents, state and rules.
- **Q11 — Batch definition.** Epic by default, a PM cut allowed, and for milestones the recut-whole rule. Whether the
  plugin models milestones at all is answered by the user's request: yes, as C29 specifies; its open choices are Q19.
- **Q12 — Demo gate default.** EMI ran `on_request`, with overnight work. `--no-human` already skips demos, but a
  sometimes-present user needed a third value.
- **Q13 — Deploy exclusivity.** Per target branch worked in EMI, and the binding constraint was machine load. Keep
  per-epic available for small hosts?
- **Q14 — Model names in config.** Tie them to role and mode, and keep `inherit` the default. Document that an explicit
  top-tier model may mean a smaller context window than the inherited session.
- **Q15 — Project-specific guards.** The content guard, the clean-room reference protocol and the designer reference
  rules should be declared by the project (`content_guard`, standing brief lines, a `reference_protocol` rule file),
  never shipped with content.
- **Q16 — Rework on a fresh teammate versus resuming.** 1.6.1 forbids resuming for rework (kept). EMI added resuming for
  *interrupted* work. Make that distinction explicit in `sdlc-dispatch` §4.
- **Q17 — How far the attribution hook reaches (C25).** Options:
  - (a) the command text only, as the sibling plugin does;
  - (b) also the files named by `-F` and `--body-file`, `git merge -m`, and `gh pr create|edit`, as proposed;
  - (c) (b) plus a git `commit-msg` hook installed by `init`, which also sees editor commits and humans' commits.

  Recommend (b): (c) reaches commits people make by hand, which a pipeline plugin should not police by default.
  Separately: retire 1.6.1's `[by {Role}]` suffix, as the sibling plugin did and its upstreaming map suggests, or keep
  it and leave `[by ` out of the patterns (proposed)? The sibling plugin's map gives its reason: the suffix "violates
  common team policies".
- **Q18 — The main-regression test (C26).** Compare the delivered `main` head against the gated SHA (proposed) or
  against the main-in SHA? Share `docs_only_paths` with the delivery conflict rule (Q10)? Add a fourth value for the
  sibling plugin's "PM judgment", or keep that as a decision-line override of any value (proposed)?
- **Q19 — The milestone's shape (C29).**
  - **Where it lives.** A `milestones` map in `epics.json` (proposed: the tracker gets it with no server change, and one
    file holds both sides of every link), or a new `milestones.json` (a cleaner read discipline, one more file for the
    server and the change stamp).
  - **IDs.** `{PREFIX}-MS-{n}` from a counter (proposed), or the user's own names ("milestone 3").
  - **Closed milestones.** Keep them in `epics.json` (proposed; they are few), or move a `demoed` one to the archive
    month file with its epics.
  - **More statuses.** `frozen` and `dropped` by directive, as epics have `frozen`?
  - **How the user defines one.** Dialogue in the PM session plus a directive (proposed), a dedicated
    `/agent-sdlc:milestone` command that writes state (a second writer beside `/start`, unless it only drafts a
    directive), or a foreground Product Manager interview, which needs a question tool the 1.6.1 Product Manager does not
    have.
  - **The uncut exception.** Allow `stories` at all, or make the recut mandatory? C13's rule prefers the recut; the
    user's request keeps the exception.

---

## Appendix — templates extracted from practice

Placeholders use `{…}`. `{scratchpad}` is the PM session's scratch directory, which it names in the brief. `{runner}`
and `{slot}` apply only when runners are enabled. Replace `{targeted …}` and `{full-gate …}` with the project's own
commands from `quality-gate.md`. None of these templates carries a project name, a host address or a secret.

### A. Review-save convention

1. The Reviewer's brief names `REPORT FILE: {scratchpad}/{ITEM-ID}-{round}.md`. The Reviewer writes the full document
   there with Bash, in `story-review` §5's format, with the Head sha. Its final message is the envelope plus a summary
   under the cap.
2. The PM copies the file to `docs/reviews/{ITEM-ID}-{round}.md`, which is round 1 in the fast lane.
3. The PM appends each NOTE as an N-line to `docs/reviews/{EPIC-ID}-notes.md` (Appendix B), under a heading for the
   review.
4. The PM appends each non-blocking IMPORTANT, and each OUT OF SCOPE line of size small, as an FU-line to
   `docs/issues/{EPIC-ID}-{slug}/followups.md` (Appendix C).
5. The PM stores `review_feedback: "docs/reviews/{ITEM-ID}-{round}.md"` and commits by path: `git commit -m "{PREFIX}:
   {ITEM-ID} review saved; … [by PM]" -- docs/state docs/reviews/{ITEM-ID}-{round}.md docs/reviews/{EPIC-ID}-notes.md
   {followups path}`.
6. Gate reports follow the same route: `{scratchpad}/{EPIC}-batch-gate.md` becomes `docs/reports/{EPIC}-batch-gate.md`,
   and a failed run is kept as `…-gate-run{N}.md`.

### B. The notes file

```markdown
# Review notes — {EPIC-ID}

NOTE-level findings from story reviews, resolved at the batch end (quality-gate.md §Review and merge).

## {ITEM-ID} (review round 1, docs/reviews/{ITEM-ID}-1.md)

- [ ] N-{n} · {category} · {finding, with file:line where it applies}
- [x] N-{n} · {category} · {finding} · **→ fixed in the batch ({sha})**
- [x] N-{n} · {category} · {finding} · **→ FU-{m}**
- [x] N-{n} · {category} · {finding} · **dropped: {one-line reason}**
- [x] N-{n} · {category} · {finding} · **→ carried to {EPIC-ID} as N-{k} ({when: its next merge of main | before STORY-x})**
```

- **Categories**: test · prose · prose ({role}) · style · docblock · contract · named arguments · selection ·
  performance (later) · rule gap (Architect) · rule text (Architect) · planning (for {items}) · for the {EPIC} merge ·
  Architect ruling before {ITEM}.
- `{n}` runs in one project-wide sequence (counter `note`).

### C. The follow-up line

```markdown
# Follow-ups — {EPIC-ID}

- [ ] FU-{n} · {class, one clause} · instances: {file:line, …} · origin: {docs/reviews/{ID}-1.md N{k} | {EPIC} N-{k} | report path} · owner: {ITEM-ID | EPIC-ID} · size: small | larger
- [x] FU-{n} · {class} · … · size: {…} — **closed by {ITEM-ID}:** {how}
```

- `{n}` runs in one project-wide sequence (counter `followup`).
- `owner:` is optional. It names the item or epic that will touch the files.
- At batch end each open line is **triaged**: carried (it stays open, with an owner in a later epic), moved to the
  deferred hardening epic, dropped with a reason, or put into the one hygiene bug.

### D. Batch-gate report (QA → `docs/reports/{EPIC}-batch-gate.md`)

```markdown
# {EPIC-ID} batch — full gate, batch-end report (runs {1..N})

**Verdict: PASSED | FAILED on run {N}.** Run {N} is on `{sha}` (tree `{tree hash}`). {One line per earlier run:
where it went red, what fixed it (commit, files, nothing under src/ or not), which step the re-run started from.}

Branch `{feature}`. Items in the batch: {IDs}; batch fix and run fixes on top.

## Row selection
{N} files in `git diff --name-only origin/main...HEAD`: {per top-level directory counts}.
Paths of rows NOT matched: {list} (count → `0`).
Rows run: {Step 0, …}. Not applicable: {row} — `{evidence command}` → `{output}`.
`origin/main` at `{sha}`; {is it an ancestor; if not, `git diff --name-only {merge main-parent} origin/main -- {code dirs} | wc -l` → `0` (docs only)}.

## Sync check ({runner} slot {x})   [runners only]
Slot HEAD `{sha}`, `HEAD^{tree}` `{hash}` on the slot and in the merge worktree; `git status --porcelain | wc -l` → `0`
on both. {Whether `up` was re-run, and why not if not.} Every runner step went through `run-step start` then `wait`;
each `wait` exit read on its own line.

## Steps — run {N} (tree `{sha}`)
| Step | Where | Exit | Evidence |
|---|---|---|---|
| {content guard} | laptop | 0 | `{last line}` |
| merge-artefact scan | laptop | 0 in scope | {counts; a control with a known hit, so the scan is shown live} |
| {up} | runner | 0 | {services healthy count; one-shot jobs exited 0} |
| {format fix} / {format check} | runner | 0 / 0 | `{counter line}` |
| {static analysis} | runner | 0 | `{per configuration: files, [OK]}` |
| pre-test cleanups | runner | 0 | {leftover containers 0; stale workers 0; cache clear confirmed} |
| {tests} | runner | 0 | `OK ({tests}, {assertions})`, time; counts of skipped / risky / warnings / incomplete all `0` |
| {replay} | runner | 0 | {one line per type}; `{total} histories replayed` |
| {client check} | runner | 0 | {type check, lint, tests N passed, build} |
| {generated-client drift} | runner | 0 | {regenerated count; diff 0; porcelain 0} |
| **extra, not a gate step:** {suite} | runner | 0 | {last line} |

## Run {N−1} — tree `{sha}` (FAILED, kept for the record)
{the same table up to the red step; then "the rest: not run, stopped at the first red step"}
Cause: {one paragraph: which change met which, the commits, why the textual merge did not flag it}.

## Regression spot-checks (diagnostics, not gate steps)
{the fix's own area on the merged tree: counts; the shared files that should hold both sides' contributions}

## Out-of-scope defects
{class · instances · reproduction · size — or "None found"}. Flaky tests: {none observed | test, run counts}.

## State left on the runner
{slot, tree, stack up or down, free disk; "the slot is not released — the PM decides"}
```

### E. Delivery commit message

```text
{PREFIX}: Deliver {EPIC-ID}{ ({milestone}) | batch {n}} — {one-line behavior summary} [by Deploy]

What changed
- {behavior, in user terms}: `{method} {route}` … ({ITEM-ID}).
- …
- Batch fixes:
  - {what} (N-{n});
  - …
- Already on `main`: {ITEM-ID} ({what}), delivered with {EPIC-ID}.

Order of application
1. {e.g. migrations before any role starts: {names}}.
2. {e.g. then the pool that serves the new routes}.

Before merge / deploy
- Migrations: {list | none}.
- Configuration: {files and what they carry}.
- Secrets: {new secret names | none}. IaC applies: {roots | none}. Operator steps: {… | none}.
- No new {secret, role, queue, topic, event family change} — {state each explicitly}.

Follow-ups (existing IDs): FU-{n}, FU-{m}, ….

Test plan (full gate at {sha} with main merged in, on {runner | the laptop}; run {N} after {fixes / re-merges})
- {content guard}: clean
- {formatter}: 0 of {files} files
- {static analysis}: [OK] No errors ({files} files per configuration)
- {tests}: OK ({tests} tests, {assertions} assertions), no skips
- {replay}: {N} histories replayed over {T} types, 0 mismatches
- {client checks}: {counts}; generated-client drift none ({files} files)
- {rows not applicable}: {row}: not applicable ({evidence}); {row}: not matched
```

### F. Brief skeletons

Every brief ends with the plugin's report-envelope contract. Standing lines (C22) go where `{standing lines}` appears.

#### F1. Developer — story, first dispatch (fast lane)

```text
Implement story {ITEM-ID}: {title}.

WHY: {≤2 sentences: what it delivers, where it sits on the critical path, what it hands to which next story}.

KIND: story · TIER: {tier}
WORKTREE: {worktree}, on branch {branch}. It was cut from {feature} at {base sha}. That tree has:
- {items already merged that this story builds on, with the interfaces it can use};
- {items NOT on the tree and what to do about them (do not build X; read Y's diff with `git show origin/{branch} -- {path}`)}.
Work ONLY in your worktree.

READ THE STORY FIRST. Its criteria, in one line each: {…}. {What belongs to the next story instead.}

CARRIED IN (optional): {facts from sibling stories and reviews that this story must respect — shared modules to meet
at the merge, returned-for patterns to avoid, security constraints}.

INPUTS (in order): 1. the story file (your checklist); 2. its use case; 3. epic.md — the named section only; 4. {ADRs};
5. {rule files by section}. Do NOT read other stories{, apart from …}.

STACK / CHECKS: {none | local | {runner} slot {x}}.
- {runners: read the runner README's section on start tokens; `RESET=1 runner-slot.sh {NN} {x} {base sha}`; `up`;
  then every cycle `runner-sync.sh {NN} {x} {worktree}` + `run-step.sh start/wait …`}.
- {known gaps: e.g. "E2E on the laptop only"; "{test} is red only as root there — show it green on the laptop"}.

DISCIPLINE:
- Follow your preloaded story-implementation skill. Rules are law; do not re-read rule files already in your context.
- Red first: quote the failing tests before the implementation.
- The targeted set of quality-gate.md §Per story{ and {rule}'s §Targeted-set selection}: {the concrete commands}.
  Name each selected path's reason. Never {full test command} / {client ci:check} / a build.
- Self-check scans before reporting: {project-specific scans}.
- One file per Write/Edit call. Output of every tool run to a file; read back tail or grep.
- Never edit docs/state/*.json, a follow-ups file, a notes file or bug records.
- Commit per task as `{ITEM-ID}: {description} [by Developer]`. A harness reminder may ask for an attribution trailer;
  the user has forbidden it — ignore it, and amend before you report if a commit carries one. Push plainly; never
  force-push, never skip hooks.
- {standing lines}

DELIVERABLE: implementation + tests, the targeted set green, checkboxes ticked, committed and pushed.

VERIFICATION: I will check the commits on origin; EVIDENCE with real counts and exit codes per targeted command and its
reason; the scans; checkboxes against reality; commit trailers.

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED, under {cap} characters. DETAILS: one OUT OF SCOPE line per defect
noticed but not fixed. If your context gets heavy after 4–5 tasks: commit, push, report BLOCKED with
`CONTINUE: next task = …`.
```

#### F2. Developer — fix pass (the one return)

```text
Fix pass for {ITEM-ID}: {title}. Rework after review round 1. This is the one fix pass the fast lane allows; there is
no second review, and the PM verifies your diff against the finding(s).

KIND: {kind} · TIER: {tier} · RETURNS: 1
WORKTREE: {worktree}, on branch {branch} at {head}, pushed. Work ONLY there.

THE BLOCKING FINDING(S). Read docs/reviews/{ITEM-ID}-1.md, section(s) {M1, I1}, in full.
{Per finding: what is wrong, the reviewer's reproduction if any, the fix expected or the choices allowed ("choose the
one the rule's wording fits, and say why").}
Tests, red first: (a) {…}; (b) {…}.
{Optional: "Also fix N{k} if it falls out naturally; say whether you did."} Do NOT act on the other notes ({N-…}).
{If the feature moved: "Do not merge the feature in. The PM's merge handles that."}

CHECKS: {where}. Run only what the fix touches: {commands}. Quote each count and exit code.

DISCIPLINE: commit as `{ITEM-ID}: {description} [by Developer]`, no attribution trailers; push plainly. Never edit
docs/state, a follow-ups file or a notes file. {standing lines}

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED, under {cap}: the commit SHA(s), the approach and why, the red runs,
each check's counts and exit codes{, whether N{k} was fixed}.
```

#### F3. Reviewer — the one round

```text
Review {ITEM-ID}: {title}.

WHY: this is the one review round before the merge. {Why it matters: critical path, security relevance.}

KIND: {kind} · TIER: {tier} · ROUND: 1
WORKTREE: {worktree} (read-only for you). Head {sha}, pushed; base {sha} ({feature} with {…} merged).
{What merged into the feature since the cut, and how the Developer prepared the meeting (e.g. files copied byte for
byte from a sibling — check with `git diff {sibling sha} HEAD -- {paths}`).}

INPUTS: the story file ({sections}) and its use case; epic.md {section}; {ADRs}; {rule files by section} and
review/*.md; the diff `git -C {worktree} diff {base}...HEAD`; the Developer's design.md and tasks.md.

Judge in particular:
- The criteria: {one line each}.
- {Security or invariant points to probe}.
- {Choices the Technical Notes leave open, each with the question to grade: "Is X allowed without an ADR? Is it the
  right owner? If it needs an Architect ruling, say so."}
- {The meeting with sibling stories.}

INDEPENDENT RE-RUN (fast lane): re-run the story's targeted set once, independently, on {where}: {commands}. Judge the
selection: a consumer or whole-tree check the change feeds but the Developer left out is a blocking finding.

DISCIPLINE: follow your preloaded story-review skill — lenses by tier, mechanical severity, one finding per class;
read-only; do not re-read rule files already in your context. {standing lines}

DELIVERABLE: write the full review document (your skill's format, Head sha) to {scratchpad}/{ITEM-ID}-1.md with Bash.
Your final message is the envelope only, with a summary under {cap} characters.

Report envelope, OUTCOME: APPROVED | REJECTED. {Tier rule: e.g. "Critical tier: an Important finding in round 1
blocks."} A review with only NOTEs is APPROVED.
```

#### F4. Deploy — story merge (real merge; a fast-forward is done by the PM)

```text
Story merge: {story branch} ({sha}) into {feature} ({feature sha}).

WHY: {ITEM-ID} is reviewed{, and its one fix pass is verified (docs/reviews/{ITEM-ID}-1.md)}. It was cut at {sha};
since then the feature has gained {items}. {Trial-merge result.} {What both sides touched that must be proven on the
merged tree.} Push is part of this merge.

WORKING DIR: {worktree_dir}/{EPIC}-merge (on the feature at {sha}, clean). Work ONLY there. The main checkout stays on main.

INPUTS: quality-gate.md; {runner README: start tokens — after a failed start, `wait` exits 3}.

STEPS
1. `git fetch origin`; confirm the worktree is clean at origin's {sha}.
2. `git merge --no-ff {sha} -m "{PREFIX}: Merge {ITEM-ID} into {EPIC-ID} [by Deploy]"`. No trailers; never skip hooks.
3. A conflict: resolve by combination. Regenerate {generated files} and commit each only if it differs. Check the
   combination: {registries, migration order with the latest as head, service definitions}. Anything that is not a
   combination: `git merge --abort`, MERGE_FAILED.
4. Verify on the merged tree ({where}): {clear sync cache after the merge; full sync; migrate}; {cache clears,
   confirmed}; whole static analysis over every configuration after {warm-up}; {tests: the story's modules, consumers of
   changed shared code, whole-tree checks — counts, 0 failures, 0 skipped}; {replay}; {content guard}; ancestry
   `--is-ancestor {story sha} HEAD` and `--is-ancestor {feature sha} HEAD`, each on its own line; marker scan 0.
5. Green: `git push origin HEAD:refs/heads/{feature}` (plain, never forced), MERGED. Red: do NOT push the feature;
   push the merge to `refs/heads/fix/{ITEM-ID}-merge`, VERIFICATION_FAILED with every failure; do not patch code.
   Confirm with `git ls-remote`. {Leave the slot's stack up.}

DISCIPLINE: your preloaded story-merge skill; combination only; regenerate generated files; never edit
docs/state/*.json; never paste container names, project names or absolute paths into documents. {standing lines}

Report envelope, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED, under {cap}. EVIDENCE: merge SHA; combination
checks; regenerated files and whether each differed; static-analysis lines; test counts; replay lines; guard line;
ancestry lines; ls-remote line.
```

#### F5. Deploy — main-in (batch end step 1); also feature-in

```text
Merge `main` into {feature} for {EPIC-ID}'s batch end (quality-gate.md §Batch end, step 1).
{feature-in variant: "Merge {other feature} at {sha} into {feature}, so {EPIC}'s gate proves the tree it ships after
{OTHER} reaches main."}

WHY: all {n} items of the batch are done: {IDs}. Since {EPIC} last took main, main has gained {epics, rulings}. The
full gate must prove what will ship, so main goes in first.

WORKING DIR: {worktree_dir}/{EPIC}-merge (on the feature at {sha}, clean). The main checkout stays on main.

STEPS
1. `git fetch origin`; clean at origin's {sha}.
2. `git merge --no-ff origin/main -m "{PREFIX}: Merge main into {EPIC-ID} for the batch end [by Deploy]"`.
3. {Trial merge: N conflicts.} Resolve:
   - Docs and rules: take main's side ({files}); then `git diff origin/main HEAD -- {docs paths}` must print nothing.
   - Generated files: regenerate, never hand-merge ({list}).
   - Combine: {file → what to combine}.
   - Anything else: `git merge --abort`, MERGE_FAILED naming the file and why.
4. Verify on the merged tree ({where}; {full sync after clearing the sync cache; up; migrate}):
   whole static analysis over every configuration; tests over {the modules both sides touched + whole-tree checks},
   failures listed with their first message line; {replay}; {proto/contract rows}; {client drifts with a forced type
   check}; {content guard}; ancestry both ways; `git diff origin/main HEAD -- docs/state | wc -l` → 0; marker scan 0.
5. Green: push the feature (plain), MERGED. Red: do NOT push the feature; push to `refs/heads/fix/{EPIC-ID}-main-in`,
   VERIFICATION_FAILED with the failures grouped by cause; do not patch code. Confirm with ls-remote.

DISCIPLINE: as F4; take main's side for docs and rules. {standing lines}

Report envelope, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED, under {cap}. EVIDENCE: merge SHA; one line per
conflict class; regenerated files; static-analysis lines; test counts with failures by cause; replay total; contract and
drift results; guard line; ancestry and state-diff counts; ls-remote line.
```

#### F6. Deploy — delivery merge to main

```text
Delivery merge: {feature} ({gated sha}) into `main`, for {EPIC-ID}{'s batch {n} | milestone part}: {summary}.

WHY: the batch's full gate passed run {N} on {gated sha}, with main merged in (docs/reports/{EPIC}-batch-gate.md).
Since that merge, main has gained only {docs and state}. quality-gate.md §Batch end step 5 allows one delivery merge,
with the release notes in the commit message.

INPUTS: the feature at {gated sha} on origin; fetch origin/main fresh. Do NOT use the main checkout: work in
`git worktree add --detach {worktree_dir}/{EPIC}-delivery origin/main`. The PM holds its own pushes to main while you
work; if main moves anyway, redo the merge.

STEPS
1. `git merge --no-ff {gated sha} -F {message file}` with the message below. No trailers; never skip hooks.
2. A conflict can only be in docs or state: keep main's side. A conflict in code: `git merge --abort`, MERGE_FAILED.
3. Verify: `git merge-base --is-ancestor {gated sha} HEAD` and `--is-ancestor origin/main HEAD`, each exit code on its
   own line; `git diff --name-only origin/main HEAD | sed 's|/.*||' | sort | uniq -c`;
   `git diff --name-only {gated sha} HEAD -- {code dirs} | wc -l` → must print 0; {content guard}.
4. `git push origin HEAD:refs/heads/main`, plain. Refused: fetch, check the new commits are docs or state only, redo the
   merge and the verification, push again. Confirm with ls-remote.
5. Remove the temporary worktree; remove {worktree_dir}/{EPIC}-merge only if it is clean and at {gated sha}. Leave the
   feature branch on origin.

THE COMMIT MESSAGE: {Appendix E, filled}

Report envelope, OUTCOME: MERGED | MERGE_FAILED, under {cap}. EVIDENCE: merge SHA; ancestry exit codes; per-directory
counts; the code-equality count (0); guard line; ls-remote line; removed worktrees.
```

#### F7. QA — batch-end full gate

```text
Full gate for {EPIC-ID}'s batch end on {feature} at {sha} (quality-gate.md §Batch end, step 2).

WHY: all {n} items are done: {IDs}. main is merged in ({sha}); the batch fix is on top ({sha}). Nothing reaches main
without the full gate.

WORKING DIR: {worktree_dir}/{EPIC}-merge (at {sha}). Not a story worktree; the main checkout stays on main.

INPUTS: quality-gate.md; the run-checks procedure; the precedent report format: {path of a previous gate report}.

THE ROWS: `git diff --name-only origin/main...HEAD` holds {directory counts}. So run: {Step 0; rows}. Not applicable:
{row} — quote `{evidence command}` → `{output}`. Confirm the rows from the diff yourself and state them.
EXTRA, not a gate step: {suite whose subject changed} — quote its exit code, labelled extra.

LESSONS FROM RECENT GATES: {classes seen recently, e.g. "tests from main still calling a changed signature"; "a flaky
counter test"}. If you meet one, report the call sites or the test, and the commit.

LAYOUT:
- Phase 1, the laptop, no stack: {content guard}; {stackless rows}; the merge-artefact scan.
- Phase 2, {runner} slot {x}: read the runner README (start tokens: after a failed start, `wait` exits 3; never read an
  old log as a pass); bring the slot to {sha} and confirm HEAD, tree hash and a clean status on both sides; every step
  through `run-step start/wait`; {up}, then the core row in order; before {tests}: {cleanups}, cache clear confirmed;
  then {client rows}. A {engine-dependent} test skipped after {up} is red.

Read every exit code from the command itself, on its own line. Quote the counts. On a red step, fix nothing: stop and
report FAILED with the failing command, its output and its reproduction.

DISCIPLINE: story-qa, batch-gate mode. Write no source and no docs/state. Do not re-read rule files already in your
context. {standing lines}

DELIVERABLE: the gate report (Appendix D format) written to {scratchpad}/{EPIC}-batch-gate.md, and the envelope, under
{cap}.

Report envelope, OUTCOME: PASSED | FAILED. EVIDENCE: one line per step, with its count or exit code.
```

#### F8. Architect — mid-flight ruling

```text
MODE: Ruling (Design Mode, small) — {before {ITEM} merges | before {ITEM} is dispatched | {ITEM} is BLOCKED}.

Rule on {FU-/N-/question id}: {the question in one sentence}.

WHY: {how the question arose (a review note, a Developer's BLOCKED report), what builds on it, what waits}.

WORKTREE: {worktree_dir}/ARCH-{topic}, on branch architect/{ITEM}-{topic}, cut from main. Edit docs and rules only,
never code.

THE QUESTION: choose one, and give each alternative a concrete verdict.
- (a) {…}
- (b) {…}
- (c) Something better.
Weigh against: {ADRs, rules, cross-client agreement, size, what the server already refuses}.

INPUTS: {the review file and note}; {ADRs}; {rule files}; {code read-only via `git show origin/{branch}:{path}`}. Do not
re-read rule files already in your context.

DELIVERABLE, committed on your branch (`{PREFIX}: {description} [by Architect]`, no attribution trailers), pushed
plainly:
1. The ruling, as a new ADR or an amendment, with every section.
2. The rule text in {rule files}.
3. If it needs code: which story builds it (existing, or "needs a new one"), and what {waiting item} does meanwhile.
4. {content guard} exit 0 on every file you touched.
{standing lines}

Report envelope, OUTCOME: DESIGNED | NEEDS_REQUIREMENTS_FIX, under ~1,200 characters: the ruling in two sentences; files
changed; commit SHA; what {waiting item} does.
```

After the report the PM merges `architect/…` into main with `--no-ff`. Waiting or next Developers cherry-pick **only**
the ruling commit.

#### F9. Developer — batch fix (pre-gate)

```text
Batch fix for {EPIC-ID} before its full gate: fix the meeting defect(s) the main-in surfaced, check {merge decision},
and fix the notes the PM chose for the batch. This is not a story.

WHY: all {n} items are merged. Deploy merged main into the feature ({what main brought}); that merge is {sha}, your
branch's base; the feature stays at {sha} until you are green. Verification was red on {causes}.

WORKTREE: {worktree_dir}/{EPIC}-batch-fix, on branch fix/{EPIC-ID}-batch, at {main-in sha}. Work ONLY there.

PART 1 — THE MEETING DEFECT(S). {Failing tests, first message line, cause.} {If another epic already fixed the same
files: "Cherry-pick it (`git cherry-pick -x {sha}`) so both lines carry the same change; if it does not apply cleanly,
make the same change by hand: {…}".} Search the tree for other instances of the same class.
PART 2 — CHECK A MERGE DECISION (optional). {What Deploy decided; confirm each carried entry; fix if not.}
PART 3 — THE NOTES FOR THE BATCH (docs/reviews/{EPIC}-notes.md): {N-id: what to do, test to add}, one per line.

STACK: {where; sync-cache clear; migrate; run-step; cleanups}.

VERIFICATION (quote counts and exit codes): red first (the failures before Part 1; each new test before its fix); whole
static analysis over every configuration; tests over {modules both sides touched + whole-tree checks}; {replay};
formatter with explicit config on the touched files; {drifts}; {content guard}. Never run {full test command}; the full
gate follows.

DISCIPLINE: commit per note or defect (`{EPIC-ID}: {description} [by Developer]`, or keep a cherry-pick's message with
-x); no attribution trailers; push the branch plainly. Do not push to the feature — the PM fast-forwards it. Never edit
docs/state, a follow-ups file or a notes file. {standing lines}

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED, under {cap}. DETAILS: one line per part and per note (→ what changed,
the commit); the red runs; the counts; OUT OF SCOPE lines.
```

#### F10. Developer — merge fix

```text
Merge fix for {ITEM-ID} ({approved}) against {EPIC-ID}'s feature. This is not a story: {make the red merge green |
bring the feature into the story branch and adapt the caller that moved meanwhile}.

WHY: {what Deploy's merge showed: the collision — a caller left on a changed signature, a double missing a new method —
or: "{sibling} merged after {ITEM}'s cut and calls {function} with the old argument; a plain merge would break the type
check"}.

WORKTREE / BRANCH: {fix/{ITEM-ID}-merge at {resolved-merge sha} | the story's worktree at {head}}. Keep your context
small: grep large files, never cat generated clients or API snapshots.

DO:
1. {Either: work on top of the resolved merge; or: `git fetch origin`, `git merge --no-ff origin/{feature}`, resolving
   by combination: {file → rule}; regenerate generated files from the merged tree, never hand-merge.}
2. Fix the collision with the smallest change, red first; search for other instances of the class (other doubles of
   the changed interface, other callers of the changed signature) and report what the search found.
3. Commit (`{ITEM-ID}: {description} [by Developer]`), no attribution trailers; push the branch plainly. Never push the
   feature — the PM fast-forwards it after reading your diff.

STACK: {where}; clear the slot's sync cache after the merge; full sync.

CHECKS (summary lines and exit codes only): {the story's selection, unfiltered}; whole static analysis over every
configuration; {whole-tree checks}; {client checks and drifts}; {content guard}.

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED, under {cap}: merge SHA and head; conflicts and how each was resolved;
adapted files; each check's summary line and exit code.
```

#### F11. Developer — fix loop (a red gate step)

```text
Fix loop for {EPIC-ID}'s full gate, run {N}: {step} went red at {sha}. This is a fix loop (quality-gate.md §Batch end
step 3), not a story, not a bug, no review.

THE FAILURE: {command; output lines; the report path docs/reports/{EPIC}-batch-gate-run{N}.md}.
BRANCH: fix/{EPIC-ID}-gate-run{N} from {gated sha}, in {worktree}.
DO: {the fix expected, or the constraint (e.g. "make the test deterministic; prove it stable across repeated runs")};
search for other instances of the class; red first.
CHECKS: {the failing test(s) + the area; whole static analysis if code changed}. Never the full suite — the gate re-runs
from the failed step.
DISCIPLINE: as F9. The PM fast-forwards the feature after reading your diff.
Report envelope, OUTCOME: IMPLEMENTED | BLOCKED, under {cap}: commit, red run, counts.
```

#### F12. Resume and recovery messages (SendMessage to the same teammate)

- **After an account session or usage limit reset:**
  "The session limit has reset. Continue {work} on {sha} from where you stopped. The runner step may have finished while
  you were paused: read its result with `run-step wait`; the start tokens tell you whether that log is this run's. If
  the step was interrupted, restart it; never read an old log as a pass. Then finish the remaining steps and send the
  envelope as briefed."
- **After a dropped connection:**
  "The connection dropped mid-response{ while you were on {X}}. Continue {ITEM-ID} from where you stopped. 1. Check `git
  -C {worktree} status` and the log to see what is already written and committed. 2. Commit what is complete. 3. Carry
  on as briefed and send the envelope."
- **A truncated report:**
  "Your report was cut off at '{last words}'. Please resend only the rest of DETAILS from that line to the end: {what
  is missing}. Nothing else, and no new work."
- **A blocker resolved mid-flight:**
  "{ITEM-ID} is unblocked. {The decision or ruling, and its commit to cherry-pick.} {Numbered steps.} {Stack.}"
- **Replacing a thrashing teammate** (a fresh dispatch, not a message): the narrow brief names only the files to read.
  It says "the previous session ran out of context; UNCOMMITTED edits exist in {files}: read `git diff` of those first;
  keep what is sound, revert what is not", and forbids catting large or generated files.

### G. Log vocabulary (the `trigger` field and fixed notes)

| Trigger | Status change | Note carries |
|---|---|---|
| `dispatch: {Role}` / `dispatch: {Role} ({mode})` | none, or the working status | the base sha, the runner and slot, the model, the parallel items; modes: fix pass, merge fix, batch fix, fix loop, batch-end notes, main in, main in (batch end), {EPIC} in, delivery, batch delivery, full gate, ruling, pre-ruling, amendment pass, continuation, resumed |
| `report: {Role} {OUTCOME}` | as the transition table says | the head sha and counts |
| `report: Developer ({mode}); PM verified the diff` | e.g. `in_progress → ready_for_merge`, or `ready_for_merge → done` | the sha range, each finding → fixed, the counts |
| `decision` | none | fixed notes: `QA skipped: fast lane`; `regression QA skipped: fast lane`; `fast-forward: {feature} {a}..{b}; worktree removed[; {ITEM} will need a real merge]`; `main regression QA skipped: the full gate ran on the delivered code and main added only documents and state since (fast lane)`; `delivery order: {X} before {Y}`; `batch cut: …`; the stop and resume of teammates after a limit; `merge queued behind {ID}'s` |
| `decision: user` | none | a user ruling, quoted or paraphrased |
| `recut` | epic re-parenting of an item | from-epic → to-epic, the milestone |
| `correction` | none | the lines it voids, and why (append-only is kept) |
| `QA` / `report: QA PASSED (full gate run {N})` | epic `in_progress → ready_for_deploy` on PASSED | the model; one clause per step with counts |
