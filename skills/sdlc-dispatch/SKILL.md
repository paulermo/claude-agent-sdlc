---
name: sdlc-dispatch
description: "The PM's dispatching discipline: how to brief agents (slot templates per role, standing lines, report cap, models), run them in parallel (teammate cap, stack budget, Deploy exclusivity), verify their work (presence check + the fast-lane diff-read exception), route what reports contain, and release or recover teammates. Read by the /agent-sdlc:start orchestrator before any dispatch."
---

# Dispatching Agents

Agents start with zero context from your session. The dispatch brief is their entire briefing — skip something and they guess, and guessing degrades output. Brief them like a smart colleague who just walked into the room.

## 0. References — load on demand

| Topic | Reference | Load when |
|-------|-----------|-----------|
| Evidence and shell discipline | ${CLAUDE_SKILL_DIR}/references/evidence-and-shell.md | before verifying the first report of the session; every brief cites it |
| Brief templates, per role | ${CLAUDE_SKILL_DIR}/references/briefs/{planning,developer,reviewer,qa,deploy,content}.md | before dispatching that role — read only that role's file |
| Batch end (fast lane) | ${CLAUDE_SKILL_DIR}/references/batch-end.md | every item of a fast-lane batch is `done`, or an epic's `batch.stage` is set |
| Cross-epic integration | ${CLAUDE_SKILL_DIR}/references/cross-epic.md | an item or a feature needs another epic's code, or two epics must deliver in order |
| Mid-flight rulings | ${CLAUDE_SKILL_DIR}/references/rulings.md | a Developer is BLOCKED on a design question; a `Rule gap:` or NOTE a later item builds on; a known open decision before a dispatch |
| Milestones | ${CLAUDE_SKILL_DIR}/references/milestones.md | the user names a milestone; a milestone directive; linking epics; a delivery of a linked epic; a demo |
| Teammate recovery | ${CLAUDE_SKILL_DIR}/references/recovery.md | a spawn fails; a usage limit or dropped connection; a truncated report; a teammate thrashing on context; a `CONTINUE:` line |
| Remote stack runners | ${CLAUDE_SKILL_DIR}/references/runners.md | `integrations.runners.enabled` is true and a dispatch needs a stack |

## 1. How to dispatch

Dispatch by the agent's **registered name** — never by file path — with the model `process.models` names (below):

| Role | subagent_type | Brief file | Model key(s) |
|------|---------------|------------|--------------|
| Product Manager | `agent-sdlc:Product Manager` | `briefs/planning.md` | `Product Manager` |
| System Analyst | `agent-sdlc:System Analyst` | `briefs/planning.md` | `System Analyst` |
| Architect | `agent-sdlc:Architect` | `briefs/planning.md` | `Architect`, `Architect:ruling` |
| Cloud Architect | `agent-sdlc:Cloud Architect` | `briefs/planning.md` | `Cloud Architect` |
| DevOps Engineer | `agent-sdlc:DevOps Engineer` | `briefs/planning.md` | `DevOps Engineer` |
| Designer | `agent-sdlc:Designer` | `briefs/planning.md` | `Designer` |
| Developer | `agent-sdlc:Developer` | `briefs/developer.md` | `Developer`, `Developer:{fix_pass \| merge_fix \| batch_fix \| fix_loop}` |
| Reviewer | `agent-sdlc:Reviewer` | `briefs/reviewer.md` | `Reviewer` |
| QA | `agent-sdlc:QA` | `briefs/qa.md` | `QA`, `QA:{standard \| regression \| batch_gate}` |
| Deploy | `agent-sdlc:Deploy` | `briefs/deploy.md` | `Deploy`, `Deploy:{story_merge \| main_in \| feature_in \| delivery}` |
| Content Creator | `agent-sdlc:Content Creator` | `briefs/content.md` | `Content Creator` |
| Content Reviewer | `agent-sdlc:Content Reviewer` | `briefs/content.md` | `Content Reviewer` |
| Content Integrator | `agent-sdlc:Content Integrator` | `briefs/content.md` | `Content Integrator` |

**Model per dispatch:** look up `process.models["{Role}:{mode}"]`, else `process.models["{Role}"]`, else `process.models.default` (absent: `"inherit"`). `"inherit"` → pass no `model` to the Agent tool (the agent inherits your session's model and its context window); any other value → pass it as the Agent tool's `model`. LAW: never the smallest tier (`haiku`) for a Developer, Reviewer, QA or Deploy dispatch — gate evidence is exactly what a weak model misreads; if the config names it, dispatch with `"inherit"` and narrate why. A report from a non-inherited model that fails the verification table is re-dispatched ONCE with `"inherit"`, with a decision line. *Default, not law: judgement roles (Architect, Developer, System Analyst, Reviewer, Product Manager) run on the inherited top-tier model; deviate only when the user configured it.* WHY: an explicit model can mean a smaller context window than the inherited session — two Developers once died of context thrashing on a large always-loaded rule set after being pinned to one.

**Never write briefs freehand.** Copy the matching template from the role's brief file and fill every `{placeholder}`. If a placeholder has no value, write `none` — do not delete the slot (a missing slot reads as "not applicable" to you but as "unknown" to the agent).

**Brief slots and the cap (LAW).** Every template uses the same slots, in this order: `WHY` · `KIND / TIER / ROUND / LANE` (item briefs; `LANE` = the epic's stamp) · `WORKTREE` (followed by a `REPORTS: {reports}` line — the absolute reports directory, sdlc-state section 1) · `CARRIED IN` · `INPUTS` · `SELECTION / CHECKS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` (a template omits slots that never apply to its role).

- Free text is allowed in exactly two slots: `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters — facts from sibling items or reviews this item must respect). Every other value is a path, an ID, a SHA, a tier, a number, a command copied from `.claude/rules/quality-gate.md`, or `none`.
- `{standing lines}` at the end of `DISCIPLINE` = the lines of `process.standing_brief_lines.all` followed by `process.standing_brief_lines["{Role}"]`, one per line (absent: nothing). They do not count toward the cap.
- `{cap}` in `REPORT` = `process.report_max_chars` (absent: 3500).
- Hard cap: the template's length + 5 lines, standing lines excluded. Context beyond that lives in a file the brief points to — the story, the bug record, the feedback file, the notes or follow-ups file, the rules. If you are typing a paragraph of context or a "quality bar" into a brief, stop: the tier sets the bar, and the file is where the context belongs. WHY: in CBS epic 1 the PM re-typed 100-200 lines of story context into every dispatch — the largest PM-side token sink of the day; slots give the per-item facts that DO belong in a brief (base SHA, what the tree has, the selection) a bounded place.

## 2. Parallelism rules

- Parallel-safe: agents whose **file sets don't overlap** (different items in different worktrees). One item = one worktree = one agent at a time.
- **Teammate cap:** `max_parallel_teammates` counts WORKING agents (idle ones awaiting release occupy no slot).
- **Stack budget:** at most `process.max_local_stacks` (absent: 2) agents may hold a running Docker stack on this machine at once. Count: `jq '[.worktrees[] | select(.stack == "local")] | length' docs/state/project.json`. Set a worktree's `stack` when you dispatch an agent that brings a stack up (`"local"`, or `"runner {NN} slot {x}"` — runner slots do not count against the local budget), clear it at release. Stackless agents (planning roles, a Reviewer whose brief has `STACK: none`) never count. When the budget is full, queue the stack-bound dispatch, pair it with stackless work (planning, an Architect pre-ruling), and narrate the wait. The two caps are independent. WHY: six agents each bringing up a ten-container stack once thrashed a laptop until the container VM killed services and none of the six finished.
- Planning agents (Product Manager → System Analyst → Architect) are **sequential** within one epic's planning chain — each consumes the previous one's artifacts. Each works in its own worktree (`{worktree_dir}/{ROLE}-{topic}`), never in the main checkout.
- Same-role parallelism is fine (three Developers on three items); the constraint is file ownership, not role uniqueness.
- **Deploy exclusivity** per `process.deploy_exclusivity` (absent: `per_epic`):

  | Value | Rule |
  |---|---|
  | `per_target_branch` | one merge INTO a given branch at a time; later merges into it queue (decision `merge queued behind {ITEM-ID}'s`). Merges into different branches may run together (a delivery to `main` beside a main-in into another feature), and Developers/Reviewers on other branches keep working |
  | `per_epic` (1.6) | never two merges at once, and never a merge while any agent works on a branch of the same epic |

## 3. Verify after every completion — never trust, always verify

When an agent finishes, BEFORE applying any transition (evidence rules: `references/evidence-and-shell.md`):

| Check | How |
|-------|-----|
| Report envelope present | final message contains `=== AGENT REPORT ===` block with all mandatory sections (sdlc-state section 3) |
| Evidence is real | EVIDENCE lines contain actual results (counts, exit codes, paths) — not adjectives; fast lane: every targeted command carries its `selected because` reason |
| Artifacts exist | spot-check 1-2 FILES entries with Read/Glob (in the agent's worktree if applicable) |
| Report file present | when the brief named a `REPORT FILE`: `test -s {path}; echo "exit=$?"` → `exit=0` |
| Work is committed | `git -C {worktree} log --oneline -3` shows the agent's commits with the `[by {Role}]` convention |
| No attribution trailers | `git -C {worktree} log --format=%B {base}..HEAD \| grep -ciE 'co-authored\|generated with claude\|claude-session'` → `0` (a count — read it, not the exit status). Non-zero on a commit not yet pushed: amend it yourself (permitted plumbing); already pushed: re-dispatch the agent to amend + surface to the user |
| State untouched by agent | `git -C {worktree} diff --name-only {base-branch}` does NOT list `docs/state/` files |
| Runner evidence | when `STACK` named a runner slot: every runner step in EVIDENCE came through `run-step wait` with its exit read on its own line, and names the slot (runners reference) |

| Situation | Action |
|-----------|--------|
| Report missing or evidence-free | message the SAME agent (section 4): "Your report lacked the required envelope/evidence — provide it. Do not redo completed work." |
| Report truncated mid-DETAILS | ask the same agent for the rest only (recovery reference) |
| Agent claims done but artifacts absent | re-dispatch with the discrepancy named |
| Agent edited `docs/state/*.json` in its worktree | instruct agent (or do it yourself in the worktree via `git checkout -- docs/state` before merge) to drop the change; apply the transition yourself from the report |
| BLOCKERS non-empty | do NOT transition; resolve the blocker (answer, re-dispatch prerequisite agent, a ruling, or surface to user) |
| OUTCOME BLOCKED with a `CONTINUE:` line | a planned hand-off, not a failure: dispatch the continuation at once (recovery reference) |
| Agent went silent / died | item keeps its working status; on next `/agent-sdlc:start` the stale-worktree check re-dispatches it |

**Verification is a presence check — the tables above and nothing more (LAW).** You MUST NOT re-run the quality gate, re-execute tests, re-judge a Reviewer's findings, or dispatch a second Reviewer/QA for a second opinion. WHY: the pipeline already verifies (the Developer proves, the Reviewer re-runs and reviews, QA executes where the lane runs it); a fourth layer found nothing in CBS epic 1 and cost a large share of its budget. Exceptions: a report with non-empty BLOCKERS (you resolve the blocker), the user asking you a specific question about the work, and the fast-lane diff read below.

**The fast-lane exception (LAW):** A fix pass, batch fix, fix loop or merge fix is verified by reading its diff against the findings it was given — only those. This replaces a second review round and is not a fourth verification layer. Procedure: `git -C {worktree} diff {head before the dispatch}..{reported head}` → for each finding or defect the brief named, one verdict — `closed` (the diff changes what the finding names, and the brief's required test is there) or `open`; a `DISPUTED:` line in the report counts as `open` (the budget gate lets the user decide; you never settle a dispute); an evidence-only finding (missing evidence, a selection omission) is `closed` by the report's EVIDENCE line for it — the command, its `selected because` reason, counts, exit 0 — with no code diff required; nothing else in the diff is judged; no command is re-run. All closed → the transition in sdlc-state section 5 with the decision note `fix pass verified by the PM reading {a}..{b} against {finding ids}` (or the merge-fix / batch-fix report line). Any open → the fix pass row "finding still open" (parked, budget gate) — or, for a batch fix / fix loop / merge fix, re-dispatch once with the open finding named.

## 3b. Route what a verified report contains

After the transition (sdlc-state section 5), mine every report ONCE for the items below. One class of finding = one record, never one per instance.

| Report content | Lane | You do |
|----------------|------|--------|
| Reviewer / QA `REPORT FILE` | both | copy it to `docs/reviews/{ITEM-ID}-{round}.md` (review) or `docs/reports/{EPIC-ID}-batch{n}-gate-run{N}.md` (batch gate, every run — sdlc-state section 6); store the review path in `review_feedback`; commit with the state (by path) |
| Reviewer `## Follow-ups` entries (any verdict) | both | append each as one `- [ ] FU-{n} · …` line to `docs/issues/{EPIC-ID}-{slug}/followups.md` (`n` = `counters.followup` + 1; create the file with its heading if missing — format in sdlc-state section 4); commit with the state |
| Reviewer `## Notes` entries (any verdict) | fast | append each as one `- [ ] N-{n} · {category} · …` line under a heading for the review in `docs/reviews/{EPIC-ID}-notes.md` (`n` = `counters.note` + 1; create from `docs/templates/notes-file-template.md` if missing); commit with the state |
| Developer `follow-ups closed: FU-…` | both | tick those lines with `— **closed by {ITEM-ID}:** {how}` |
| Developer `REFERENCE CHECK:` lines | both | quote them in the Reviewer brief's `CARRIED IN` (write `none` when there are none); longer than ~600 characters → save them to `{reports}/{ITEM-ID}-reference-checks.md` and `CARRIED IN` names that path |
| Developer `OUT OF SCOPE` / QA `## Out-of-scope defects`, size small (≤ 5 lines, 1 file) | both | one follow-up line |
| same, size larger | both | register ONE bug (sdlc-state section 4 — Bug; procedure in start.md) with the report path as `origin`; record from `docs/templates/bug-template.md` |
| QA regression FAILED (feature branch), Deploy MERGE_FAILED / VERIFICATION_FAILED | classic | register ONE bug from the report (tier = the failed item's tier) |
| Deploy VERIFICATION_FAILED / MERGE_FAILED (story merge) | fast | dispatch a merge-fix Developer on `fix/{ITEM-ID}-merge` (briefs/developer.md) — **no bug** |
| QA batch gate FAILED | fast | the fix loop (batch-end reference) — **no bug** |
| QA regression on `main` FAILED | both | ONE bug in the epic; epic → `in_progress` (sdlc-state section 5) |
| Reviewer `Rule gap:` proposal | both | a later item builds on it → a ruling now (rulings reference); otherwise keep it for the Architect's next Design Mode brief |
| Developer BLOCKED on a design question | both | a ruling (rulings reference) |
| Developer `CONTINUE:` | both | a continuation dispatch (recovery reference) |
| REJECTED / FAILED verdict | both | the returns rule (sdlc-state section 4 — Return budget and parking): re-dispatch within budget, park at budget |

Never route a defect into a *story* — stories come from the System Analyst; defects are bugs, follow-ups, merge fixes or fix loops.

## 4. Release the agent after acceptance

Which mode are you in? If you dispatched via teammates (agent teams enabled), the release step below is mandatory. If teammate spawning is unavailable and you dispatched background/foreground subagents via the Agent tool, there is NO release step — a subagent ends with its final message and holds no session, pane, or slot. Everything else in this skill is identical in both modes. Never fall back to subagents silently: if a teammate spawn fails, say so in the same turn and follow the recovery reference.

**Teams mode:** a teammate that "finished" is idle, not gone — its session stays alive (process, panel row, pane) until you stop it. Idle teammates cost no tokens, but they accumulate without bound, invite accidental reuse, and use up window room so new panes fail to open. The moment the verification table passes and the transition is committed, release the teammate:

```
TaskStop {task_id: "{role}-{ITEM-ID}"}
```

TaskStop takes the bare teammate name and stops the session one-sidedly — safe here because the work is committed and the report accepted, so nothing is in flight. A `No task found` error means the teammate is already gone — continue. (TaskOutput does NOT know teammates; its `No task found` proves nothing about TaskStop.) Clear the worktree's `stack` field in the same step.

| Situation | Action |
|-----------|--------|
| Report verified, transition committed | teams: release immediately, before narrating and dispatching the next batch · fallback: nothing to do |
| Report failed verification (envelope/evidence/artifacts missing, report truncated) | do NOT release — message the SAME agent by name (SendMessage resumes a finished agent from its transcript, in both modes) to fix or complete its report; teams: release after acceptance |
| Work interrupted, not finished (usage-limit reset, dropped connection, a BLOCKED report whose blocker is now resolved) | message the SAME agent to continue — the recovery reference has the exact messages |
| Item rejected later (`review_rejected`, `qa_rejected`) | released stays released — rework is a FRESH dispatch (`{role}-{ITEM-ID}-fix` in the fast lane) with the feedback brief, in both modes |

Shutdown is asynchronous (the teammate finishes its current tool call first) — do not wait for confirmation; continue your loop.

Resuming an agent by name is ONLY for report fixes, a truncated report's tail, and interrupted work — never for rework.

## MUST NOT DO

- Dispatch with a freehand brief — templates only. WHY: brief variance is the single biggest source of output variance.
- Dispatch two agents whose scopes touch the same files, or a stack-bound agent past the stack budget.
- Apply a transition without the verification table above.
- Leave a verified teammate idle instead of releasing it, or send rework to an old agent session (teams or fallback). WHY: idle sessions pile up across an epic, and a stale session carries its prior conclusions into rework instead of following the rejection brief.
- Release via SendMessage `shutdown_request`. WHY: shutdown is a two-way protocol — the process ends only when the teammate answers with a structured `shutdown_response` through its own SendMessage tool, which the SDLC agents' toolsets do not include; the teammate can only echo "confirmed" as plain text and stays alive, and even when the protocol works the round-trip burns a full teammate turn. TaskStop needs no cooperation and no tokens.
- Implement, review, or fix anything yourself — you are the orchestrator; even a "one-line fix" goes through a Developer dispatch. WHY: PM edits bypass review and corrupt the pipeline's audit trail. (The git plumbing listed in start.md's Git policy — fast-forwards, plain pushes, trailer amends on unpushed agent commits, merging planning and ruling branches, worktree removal — is not implementation.)
- Pad a brief beyond its slots, or restate the story/rules inside it — point at files (brief cap law).
- Re-verify what the pipeline already verified, review a review, or dispatch a second opinion — the verification table is a presence check; the fast-lane diff read judges only the named findings.
- Dispatch a parked item, turn a defect into a story, or register one item per instance of a finding class.
- Register a bug for a fast-lane merge failure or a red batch-gate step.
