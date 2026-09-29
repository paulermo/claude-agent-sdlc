# Brief templates — content roles

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as the agent's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). Content epics always follow the classic lane (sdlc-state section 4, Lanes), so these templates carry no lane variants. Slots run in one order — `WHY` · `KIND / TIER / ROUND` · `WORKTREE` · `INPUTS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) is free text; every other value is a path, an ID, a SHA, a number, a command copied from `.claude/rules/quality-gate.md`, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["{Role}"]` (`Content Creator`, `Content Reviewer`, `Content Integrator`), one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. `{worktree}`, `{branch}`, `{app}`, `{db}` and the stack come from the task's `project.json` worktrees entry; `{feedback-file}` = the path in the task's feedback field — the agent reads it, never paste its text. `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| Content Creator | classic | a content task in `todo`, `review_rejected`, or `qa_rejected` with `rejection_reason: content` |
| Content Reviewer | classic | a content task in `ready_for_review` |
| Content Integrator | classic | a content task in `ready_for_integration`, or `qa_rejected` with `rejection_reason: integration` |

---

## Content Creator

```text
Create content for {CTASK-ID}: {title}.

WHY: {what this content serves in the product}.

KIND: content task · ROUND: {returns + 1}
PRIOR FEEDBACK: {rework: read {feedback-file} and fix ALL of it | none}
WORKTREE: {worktree}, branch {branch}. Work ONLY there.
REPORTS: {reports} — your logs go here, outside every worktree.

INPUTS: {worktree}/docs/issues/{CEPIC-ID}-{slug}/{CTASK-ID}-{slug}.md, the content plan docs/requirements/content-plan/{CP-ID}-{slug}.md, content/ conventions from your skill.

DISCIPLINE:
- Your workflow is the preloaded content-production skill, Creator role.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{CTASK-ID}: Generate {content description} [by Content Creator]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: every content file the task's output spec names, under content/, self-reviewed, committed.

VERIFICATION: I will check your commits exist (attribution-trailer count 0), every FILES entry exists, and EVIDENCE carries the self-review checklist results.

REPORT: the envelope from your skill, OUTCOME: CREATED | BLOCKED, under {cap} characters. FILES: every content file produced.
```

## Content Reviewer

```text
Review content for {CTASK-ID}: {title}.

WHY: {what this content serves in the product} — gate before integration.

KIND: content task · ROUND: {returns + 1}
WORKTREE: {worktree} (the Creator's, read-only for you).

INPUTS: the content task file, the content plan, the produced files under content/.

DISCIPLINE:
- Your workflow is the preloaded content-production skill, Reviewer role. Read-only — findings go in DETAILS; I store the feedback.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

VERIFICATION: I will check EVIDENCE carries checks 1–4 of your skill, each pass or fail; FILES: none.

REPORT: the envelope from your skill, OUTCOME: APPROVED | REJECTED (REJECTED requires specific per-file findings), under {cap} characters.
```

## Content Integrator

```text
Integrate content for {CTASK-ID}: {title}.

WHY: {what this content serves in the product} — users see it only once it is wired in.

KIND: content task · ROUND: {returns + 1}
PRIOR FEEDBACK (rejection_reason was "integration"): {rework: read {feedback-file} and fix ALL of it | none}
WORKTREE: {worktree}, branch {branch}. Work ONLY there.
REPORTS: {reports} — your logs go here, outside every worktree.

INPUTS: approved content files under content/, the content task file (target locations), .claude/rules/quality-gate.md.

STACK: {local — COMPOSE_PROJECT_NAME={ctask-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded content-production skill, Integrator role. Migrations/seeds/static resources only — never application logic.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{CTASK-ID}: Integrate {content description} into app [by Content Integrator]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: the content integrated by the method the task's Integration Notes prescribe, integration tests, the quality gate green, committed.

VERIFICATION: I will check your commits exist (attribution-trailer count 0), no `docs/state/` path in your diff, and EVIDENCE carries the quality-gate results and the local render check.

REPORT: the envelope from your skill, OUTCOME: INTEGRATED | BLOCKED, under {cap} characters. EVIDENCE: quality-gate result after integration.
```
