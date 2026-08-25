---
name: sdlc-dispatch
description: "The PM's dispatching discipline: how to brief agents, run them in parallel, and verify their work. Read by the /agent-sdlc:start orchestrator before any dispatch."
---

# Dispatching Agents

Agents start with zero context from your session. The dispatch brief is their entire briefing — skip something and they guess, and guessing degrades output. Brief them like a smart colleague who just walked into the room.

## 1. How to dispatch

Dispatch by the agent's **registered name** — never by file path:

| Role | subagent_type |
|------|---------------|
| Product Manager | `agent-sdlc:Product Manager` |
| System Analyst | `agent-sdlc:System Analyst` |
| Architect | `agent-sdlc:Architect` |
| Cloud Architect | `agent-sdlc:Cloud Architect` |
| DevOps Engineer | `agent-sdlc:DevOps Engineer` |
| Designer | `agent-sdlc:Designer` |
| Developer | `agent-sdlc:Developer` |
| Reviewer | `agent-sdlc:Reviewer` |
| QA | `agent-sdlc:QA` |
| Deploy | `agent-sdlc:Deploy` |
| Content Creator | `agent-sdlc:Content Creator` |
| Content Reviewer | `agent-sdlc:Content Reviewer` |
| Content Integrator | `agent-sdlc:Content Integrator` |

**Never write briefs freehand.** Copy the matching template from `${CLAUDE_SKILL_DIR}/references/briefs.md` and fill every `{placeholder}`. If a placeholder has no value, write `none` — do not delete the section (a missing section reads as "not applicable" to you but as "unknown" to the agent).

Every brief carries five mandatory sections (already built into the templates):

1. **WHY** — what this item delivers and why it matters now (one-two sentences from the story/epic).
2. **INPUTS** — exact file paths to read, and what NOT to read.
3. **DISCIPLINE** — your workflow skill is preloaded; rules location; "never edit `docs/state/*.json`".
4. **DELIVERABLE** — the concrete artifact + the report envelope with role-specific OUTCOME values.
5. **VERIFICATION** — what you (PM) will check before accepting the report.

**Brief cap (LAW):** a brief is the filled template and nothing else. `WHY` is the only free-text placeholder (≤ 2 sentences); every other placeholder is a path, an ID, a tier, a round number, or `none`. Hard cap: the template's length + 5 lines. Context the agent needs beyond that lives in a file the brief already points to — the story, the bug record, the feedback file, the follow-ups file, the rules. If you are typing a paragraph of context or a "quality bar" into a brief, stop: the tier sets the bar, and the file is where the context belongs. WHY: in CBS epic 1 the PM re-typed 100-200 lines of story context into every dispatch — the largest PM-side token sink of the day.

## 2. Parallelism rules

- Parallel-safe: agents whose **file sets don't overlap** (different stories in different worktrees; content tasks in different worktrees). One item = one worktree = one agent at a time.
- Respect `max_parallel_teammates` from `project.json`.
- Planning agents (Product Manager → System Analyst → Architect) are **sequential** — each consumes the previous one's artifacts.
- Same-role parallelism is fine (three Developers on three stories); the constraint is file ownership, not role uniqueness.
- Deploy is **exclusive**: never run two merges at once, and never run a merge while any agent is working on a branch of the same epic.

## 3. Verify after every completion — never trust, always verify

When an agent finishes, BEFORE applying any transition:

| Check | How |
|-------|-----|
| Report envelope present | final message contains `=== AGENT REPORT ===` block with all sections |
| Evidence is real | EVIDENCE lines contain actual results (counts, exit codes, paths) — not adjectives |
| Artifacts exist | spot-check 1-2 FILES entries with Read/Glob (in the agent's worktree if applicable) |
| Work is committed | `git -C {worktree} log --oneline -3` shows the agent's commits with the `[by {Role}]` convention |
| State untouched by agent | `git -C {worktree} diff --name-only {base-branch}` does NOT list `docs/state/` files |

| Situation | Action |
|-----------|--------|
| Report missing or evidence-free | re-dispatch the same agent: "Your report lacked the required envelope/evidence — provide it. Do not redo completed work." |
| Agent claims done but artifacts absent | re-dispatch with the discrepancy named |
| Agent edited `docs/state/*.json` in its worktree | instruct agent (or do it yourself in the worktree via `git checkout -- docs/state` before merge) to drop the change; apply the transition yourself from the report |
| BLOCKERS non-empty | do NOT transition; resolve the blocker (answer, re-dispatch prerequisite agent, or surface to user) |
| Agent went silent / died | item keeps its working status; on next `/agent-sdlc:start` the stale-worktree check re-dispatches it |

**Verification is a presence check — the table above and nothing more (LAW).** You MUST NOT re-run the quality gate, re-read the diff, re-execute tests, re-judge a Reviewer's findings, or dispatch a second Reviewer/QA for a second opinion. WHY: the pipeline already verifies three times (the Developer runs the gate, the Reviewer re-runs it and reviews, QA executes); a fourth layer found nothing in CBS epic 1 and cost a large share of its budget. Exceptions: a report with non-empty BLOCKERS (you resolve the blocker), or the user asking you a specific question about the work.

## 3b. Route what a verified report contains

After the transition (sdlc-state section 5), mine every report ONCE for the items below. One class of finding = one record, never one per instance.

| Report content | You do |
|----------------|--------|
| Reviewer `## Follow-ups` entries (any verdict) | append each as one `- [ ] FU-{n} · …` line to `docs/issues/{EPIC-ID}-{slug}/followups.md` (create it with its heading if missing — format in sdlc-state section 4); commit with the state |
| Developer `follow-ups closed: FU-…` | tick those lines (`- [x]`) in followups.md |
| Developer `OUT OF SCOPE` / QA `## Out-of-scope defects`, size small (≤ 5 lines, 1 file) | one follow-up line |
| same, size larger | register ONE bug (sdlc-state section 4 — Bug; procedure in start.md) with the report path as `origin`; record from `docs/templates/bug-template.md` |
| QA regression FAILED, Deploy MERGE_FAILED / VERIFICATION_FAILED | register ONE bug from the report (tier = the failed item's tier) |
| Reviewer `Rule gap:` proposal | keep it for the Architect's next Design Mode brief — do not act on it yourself |
| REJECTED / FAILED verdict | the returns rule (sdlc-state section 4 — Return budget and parking): re-dispatch within budget, park at budget |

Never route a defect into a *story* — stories come from the System Analyst; defects are bugs or follow-ups.

## 4. Release the agent after acceptance

Which mode are you in? If you dispatched via teammates (agent teams enabled), the release step below is mandatory. If teammate spawning is unavailable and you dispatched background/foreground subagents via the Agent tool, there is NO release step — a subagent ends with its final message and holds no session, pane, or slot. Everything else in this skill is identical in both modes.

**Teams mode:** a teammate that "finished" is idle, not gone — its session stays alive (process, panel row, pane) until you stop it. Idle teammates cost no tokens, but they accumulate without bound and invite accidental reuse. The moment the verification table passes and the transition is committed, release the teammate:

```
TaskStop {task_id: "{role}-{ITEM-ID}"}
```

TaskStop takes the bare teammate name and stops the session one-sidedly — safe here because the work is committed and the report accepted, so nothing is in flight. A `No task found` error means the teammate is already gone — continue. (TaskOutput does NOT know teammates; its `No task found` proves nothing about TaskStop.)

| Situation | Action |
|-----------|--------|
| Report verified, transition committed | teams: release immediately, before narrating and dispatching the next batch · fallback: nothing to do |
| Report failed verification (envelope/evidence/artifacts missing) | do NOT release — message the SAME agent by name (SendMessage resumes a finished agent from its transcript, in both modes) to fix its report; teams: release after acceptance |
| Item rejected later (`review_rejected`, `qa_rejected`) | released stays released — rework is a FRESH dispatch with the feedback brief, in both modes |

Shutdown is asynchronous (the teammate finishes its current tool call first) — do not wait for confirmation; continue your loop.

Count only WORKING agents against `max_parallel_teammates`; an idle teammate awaiting release occupies no slot. Resuming a finished agent by name is ONLY for report fixes — never for rework.

## MUST NOT DO

- Dispatch with a freehand brief — templates only. WHY: brief variance is the single biggest source of output variance.
- Dispatch two agents whose scopes touch the same files.
- Apply a transition without the verification table above.
- Leave a verified teammate idle instead of releasing it, or send rework to an old agent session (teams or fallback). WHY: idle sessions pile up across an epic, and a stale session carries its prior conclusions into rework instead of following the rejection brief.
- Release via SendMessage `shutdown_request`. WHY: shutdown is a two-way protocol — the process ends only when the teammate answers with a structured `shutdown_response` through its own SendMessage tool, which the SDLC agents' toolsets do not include; the teammate can only echo "confirmed" as plain text and stays alive, and even when the protocol works the round-trip burns a full teammate turn. TaskStop needs no cooperation and no tokens.
- Implement, review, or fix anything yourself — you are the orchestrator; even a "one-line fix" goes through a Developer dispatch. WHY: PM edits bypass review/QA and corrupt the pipeline's audit trail.
- Pad a brief beyond its template, or restate the story/rules inside it — point at files (brief cap law).
- Re-verify what the pipeline already verified, review a review, or dispatch a second opinion — the verification table is a presence check.
- Dispatch a parked item, turn a defect into a story, or register one item per instance of a finding class.
