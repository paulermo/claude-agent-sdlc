# Brief templates — Reviewer

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as the Reviewer's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). Slots run in one order — `WHY` · `KIND / TIER / ROUND` (always with `LANE`) · `WORKTREE` (path, head and base SHA, what the tree has) · `CARRIED IN` · `INPUTS` · `SELECTION / CHECKS` · `STACK` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters) are free text; every other value is a path, an ID, a SHA, a tier, a number, a command copied from `.claude/rules/quality-gate.md` or from the Developer's report EVIDENCE, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `CARRIED IN` always quotes the Developer's `REFERENCE CHECK:` lines from its report DETAILS, verbatim — or, when they are longer than ~600 characters, the path `{reports}/{ITEM-ID}-reference-checks.md` into which you copied them (`none` when it has none) — the Reviewer flags a decision made on a guess only where no check is recorded. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["Reviewer"]`, one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. `{worktree}` and the stack come from the item's `project.json` worktrees entry; `{kind}` / `{tier}` / `{returns}` from its state entry (absent: `story` / `standard` / `0`); `LANE` = the epic's stamp (`jq -r '.epics["{EPIC-ID}"].lane // "classic"' docs/state/epics.json`). `STACK` = `none` | `local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db}` | `runner {NN} slot {x}, set to {head sha}`. Paths prefixed `{worktree}/` are read through the item's worktree; PM-only documents (saved reviews, bug records) are read at their main-checkout path. `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| Reviewer — the one round (F3) | fast | a story, or a standard / critical bug, in `ready_for_review` — always round 1 |
| Reviewer (classic lane) | classic | a story, or a standard / critical bug, in `ready_for_review` — ROUND = `returns` + 1 |

---

## Reviewer — the one round (F3)

```text
Review {ITEM-ID}: {title} — the one review round before the merge.

WHY: {≤ 2 sentences: why it matters — critical path, security relevance, what builds on it}.

KIND: {kind} · TIER: {tier} · ROUND: 1 · LANE: fast
WORKTREE: {worktree}, the Developer's — read-only for you. Head {head sha}, pushed; base {base sha} on {feature-branch}; merged into the feature since the cut: {ITEM-IDs | none}.
REPORTS: {reports} — the REPORT FILE and your logs go here, outside every worktree.
CARRIED IN: REFERENCE CHECKS: {the Developer's `REFERENCE CHECK:` lines, verbatim | when longer than ~600 characters: in {reports}/{ITEM-ID}-reference-checks.md, which I wrote | none}. JUDGE: {invariants or security points to probe; choices the Technical Notes leave open (allowed without an ADR? the right owner? needs an Architect ruling?); the meeting with sibling items — `git diff {sibling sha} HEAD -- {paths}` | none}.

INPUTS: {story: {worktree}/docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md + its use case + epic.md `## Architecture Notes` | bug: the bug record {record path}}; {ADR paths | none}; the rules for the domains the diff touches, by section; the Developer's design.md and tasks.md: {paths | none}; the diff: `git -C {worktree} diff {base sha}...HEAD`.
Do NOT read: other stories, other epics.

SELECTION / CHECKS: re-run the item's targeted set once, yourself, on Head — the Developer's commands with their reasons, copied from its `targeted:` EVIDENCE lines: {command — selected because {reason}; …}. Each of your EVIDENCE lines carries `selected because {the Developer's reason | Reviewer-built}`. Then judge the selection by search: a consumer of a changed symbol, or a whole-tree check the change feeds, left out → MANDATORY.
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-review skill — lenses by tier, severity mechanical, one finding per class with its instances; the round-1 verdict column at tier {tier}. A NOTE never blocks; a review with only NOTEs is APPROVED.
- You are read-only: the files you write are the REPORT FILE and your `{reports}/{ITEM-ID}-*.log` logs — no source, test or state edits; no checkout, commit, stash, merge or push.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

DELIVERABLE: the full review document (your skill's format, Head included), written with Bash to the REPORT FILE; I save it as docs/reviews/{ITEM-ID}-1.md.

VERIFICATION: I will check the REPORT FILE is present and non-empty, and names Head {head sha}; EVIDENCE: a count and an exit code for every re-run command with its `selected because` reason, and the `selection:` line; FILES: the REPORT FILE (created); the `stack:` line when STACK names a runner.

REPORT: the envelope from your skill, OUTCOME: APPROVED | REJECTED | BLOCKED (BLOCKED only with BLOCKERS — the review file is still written), REPORT FILE: {reports}/{ITEM-ID}-1.md, the whole message under {cap} characters. DETAILS: the summary, the counts, one line per MANDATORY and blocking IMPORTANT.
```

## Reviewer (classic lane)

```text
Review {ITEM-ID}: {title}.

WHY: gate before {QA | merge} — story compliance and rules compliance at the item's tier.

KIND: {kind} · TIER: {tier} · ROUND: {returns + 1} · LANE: classic
PRIOR REVIEW: {round ≥ 2: {feedback-file} · PRIOR HEAD: {the Head sha from that file} — scope = prior findings + the delta since PRIOR HEAD (re-review scope law) | round 1: none}
WORKTREE: {worktree} (the Developer's, read-only for you). Head {head sha}.
REPORTS: {reports} — the REPORT FILE and your logs go here, outside every worktree.
CARRIED IN: REFERENCE CHECKS: {the Developer's `REFERENCE CHECK:` lines, verbatim | when longer than ~600 characters: in {reports}/{ITEM-ID}-reference-checks.md, which I wrote | none}.

INPUTS: {story: {worktree}/docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md + its use case, epic architecture notes | bug: the bug record {record path}}, .claude/rules/ (all domains touched by the diff), the diff: {round 1: `git -C {worktree} diff {feature-branch}...HEAD` | round ≥ 2: `git -C {worktree} diff {PRIOR HEAD}..HEAD`}.

SELECTION / CHECKS: the quality gate, run by you — every section of the path-to-command table whose glob matches the diff (a pre-2.0 quality-gate.md without that table: every command it lists).
STACK: {none | local — COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} | runner {NN} slot {x}, set to {head sha}}.

DISCIPLINE:
- Your workflow is the preloaded story-review skill — lenses by tier, severity mechanical, verdict by round, one finding per class with its instances. You are read-only: no source edits, no state edits; the files you write are the REPORT FILE and your `{reports}/{ITEM-ID}-*.log` logs.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

DELIVERABLE: the full review document (format from your skill, Head sha included), written with Bash to the REPORT FILE — I save it to docs/reviews/{ITEM-ID}-{round}.md and commit it.

VERIFICATION: I will check the REPORT FILE is present and non-empty, and names Head {head sha}; EVIDENCE: each quality-gate command with its actual result; FILES: the REPORT FILE (created).

REPORT: the envelope from your skill, OUTCOME: APPROVED | REJECTED | BLOCKED (BLOCKED only with BLOCKERS — the review file is still written), REPORT FILE: {reports}/{ITEM-ID}-{round}.md, under {cap} characters. REJECTED requires ≥1 MANDATORY or ≥1 blocking IMPORTANT per your verdict table; other IMPORTANTs go to ## Follow-ups and do not block; NOTE-only reviews are APPROVED.
```
