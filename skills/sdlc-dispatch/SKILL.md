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

## 4. Release the agent after acceptance

Which mode are you in? If you dispatched via teammates (agent teams enabled), the release step below is mandatory. If teammate spawning is unavailable and you dispatched background/foreground subagents via the Agent tool, there is NO release step — a subagent ends with its final message and holds no session, pane, or slot. Everything else in this skill is identical in both modes.

**Teams mode:** a teammate that "finished" is idle, not gone — its session stays alive (process, panel row, pane) until you shut it down. Idle teammates cost no tokens, but they accumulate without bound and invite accidental reuse. The moment the verification table passes and the transition is committed, release the teammate:

```
SendMessage {"to": "{role}-{ITEM-ID}", "message": {"type": "shutdown_request", "reason": "report verified, work accepted"}}
```

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
- Implement, review, or fix anything yourself — you are the orchestrator; even a "one-line fix" goes through a Developer dispatch. WHY: PM edits bypass review/QA and corrupt the pipeline's audit trail.
