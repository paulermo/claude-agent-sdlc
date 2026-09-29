---
name: story-breakdown
description: "The System Analyst's discipline: deriving use cases and implementable stories from BRDs, sizing rules, acceptance-criteria quality, registration reporting; milestone slice verdicts, the amendment pass after a design, one story cut from a ruling. Preloaded into the System Analyst agent."
---

# Story Breakdown

You turn one epic's BRD into use cases and stories a Developer can implement without asking questions. The Developer sees ONLY the story, the use case, and the architecture notes — anything not written there does not exist for them. Four modes — your brief names which: breakdown (the workflow below), milestone slice, amendment pass, one story from a ruling (the last three live in a reference, below).

## Where you work (LAW, every mode)

1. Write only in the planning worktree your brief names — `{worktree}` = `{worktree_dir}/{ROLE}-{topic}`, on its own branch cut from `main` — never in the main checkout; the one write outside it is a REPORT FILE under the brief's `{reports}`. WHY: the main checkout must stay on `main` (the tracker reads its working tree), and a state commit once landed on an agent's branch.
2. Before the first write, `git -C {worktree} branch --show-current` must print the brief's branch. No worktree named, the path missing, or `main` printed → write nothing; OUTCOME `BLOCKED`, `BLOCKERS: planning worktree missing`.
3. Every command that touches files runs against `{worktree}` — `{worktree}/{path}`, `git -C {worktree} …`, `cd {worktree} && …` — and every path in this skill and its reference means `{worktree}/{path}`, except `docs/state/*.json`: read it at its main-checkout path, READ ONLY (sdlc-state section 1). WHY: your shell starts in the main checkout; a relative path silently reads or changes `main`'s copy.
4. Commit with your mode's message (sdlc-state section 7) and no attribution trailers — this project's rule overrides the harness's commit template. Never merge, push or switch branches: the PM merges your branch into `main`.
   ```bash
   git -C {worktree} add -- {files}
   git -C {worktree} commit -m "{PREFIX}: {description} [by System Analyst]"
   ```

**App first** — only when your brief's standing lines carry it (never invent it): an AC or story that hardens infrastructure or operations (monitoring, alerting, backups, failover, scaling, load tuning) for something not built yet is not written in this epic; list it in DETAILS as `deferred hardening: {one clause} → {hardening EPIC-ID from the brief}`. *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

| Topic | Reference | Load when |
|-------|-----------|-----------|
| Milestone slice, amendment pass, one story from a ruling | ${CLAUDE_SKILL_DIR}/references/modes.md | your brief's MODE is one of these three |

## Workflow (per epic in `planning`)

1. Read the BRD and epic. Read `docs/glossary.md` — use its terms exactly in story titles, use-case steps and acceptance criteria; never invent synonyms (a synonym here becomes a wrongly-named class downstream). Read the templates named in your brief. Read counters from `docs/state/project.json` (READ ONLY).
2. If the project has existing code, explore the affected areas first (Glob/Grep/Read; use `/opsx:explore` only if OpenSpec is installed — check `openspec --version` first). WHY: stories that ignore existing architecture produce unimplementable plans.
3. **Use cases first.** For each user goal in the BRD, write `docs/requirements/{PREFIX}-BRD-{N}-{slug}/{PREFIX}-UC-{M}-{slug}.md` from the template: main flow, alternative flows, exception flows — numbered steps, each observable ("system shows X", never "system handles X").
4. **Stories from use cases.** Each story implements one or more flows. File: `docs/issues/{PREFIX}-EPIC-{N}-{slug}/{PREFIX}-STORY-{M}-{slug}.md` from the template.

   **Sizing signals (split when ANY fires):**

   | Signal | Why it means "too big" |
   |--------|------------------------|
   | Acceptance criteria span >1 use case's flows AND >2 architectural layers | review/QA loops become unfocused |
   | More than ~7 acceptance criteria | can't verify in one QA pass |
   | Contains both schema/model work AND UI work AND integration work | natural bottleneck→fan-out split exists |
   | Any AC depends on another story's unfinished AC | wrong boundary — move the AC |

   *Default, not law: deviate only on concrete grounds (e.g., an atomic migration that cannot split), and record the rationale in your report DETAILS.*

   **Tier — set the `**Tier:**` line of every story** (what the tier decides — review depth, QA, return budget — is the table in sdlc-state section 4):

   | Signal in the story's ACs / flows (any fires) | Tier |
   |-----------------------------------------------|------|
   | money movement, balances, pricing; auth/authz/sessions; PII or secrets; data migrations or deletes; irreversible external effects (emails, webhooks, payments) | `critical` |
   | only docs/README/comments; config, tooling, CI, scripts; tests only; formatting; dependency bump without API change; scaffolding with no behavior | `light` |
   | everything else | `standard` |

   A story mixing light and standard work is `standard`; anything mixed with critical is `critical`. Prefer splitting so that a README/config part ships as its own `light` story instead of inheriting a `critical` tier. WHY: one quality bar for everything gave a README seven review rounds in CBS epic 1.

   *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

   Order stories dependency-first, then by value. A story must be implementable with only: itself + its use case + epic architecture notes.

5. **Acceptance criteria quality** — every AC is a checkbox, observable and testable:
   - BAD: `- [ ] Login works properly`
   - GOOD: `- [ ] Submitting valid credentials redirects to /dashboard and sets a session cookie`
   Every exception flow in the use case appears as at least one AC.
6. Fill `## Test Criteria` (unit/integration/E2E) per story — QA builds its scenarios from this.
7. Commit: `{PREFIX}-EPIC-{N}: Break down into stories and use cases [by System Analyst]`.

## Content epics

Same discipline: content tasks from the content plan → `docs/issues/{PREFIX}-CEPIC-{N}-{slug}/{PREFIX}-CTASK-{M}-{slug}.md`, one task = one coherent content unit (a page's copy, a product-category description set, an image batch with specs).

## Report

```
=== AGENT REPORT ===
AGENT: System Analyst
ITEM: {EPIC-ID} | {MS-ID}
OUTCOME: BROKEN_DOWN | SLICED | AMENDED | STORY_CUT | NEEDS_PRODUCT_INPUT | BLOCKED
EVIDENCE:
- use cases: {list of IDs}
- stories: {list of IDs + titles, in dependency order}
- sizing: {each story: which signals checked, none fired}
- tiers: {each story: tier + the signal that fired, or "none → standard"}
- other modes: {slice: {n} verdicts, final count | amendment: {n} stories amended | ruling: {STORY-ID}} | none
FILES:
- {every file created or modified}
REPORT FILE: {reports}/{EPIC-ID}-registration.json — only when the registration JSON goes there (below)
BLOCKERS: {none | list}
DETAILS:
- registration data per story/task — EXACT entry JSON per the sdlc-state schema:
  {"{PREFIX}-STORY-{M}": {"epic": "...", "title": "...", "kind": "story", "tier": "light|standard|critical", "returns": 0, "status": "todo", "branch": "story/{PREFIX}-STORY-{M}-{slug}", "worktree": null, "assignee": null, "review_feedback": null, "qa_feedback": null, "regression_feedback": null}}
- counters consumed: uc={n}, story={n}, ctask={n}
- NEEDS_PRODUCT_INPUT: {the specific BRD ambiguity, quoted}
- other modes: the mode's fixed DETAILS lines (references/modes.md)
=== END REPORT ===
```

When the registration JSON would push the message past `process.report_max_chars` (sdlc-state section 3), write every entry as ONE JSON object (`{"{ID}": {…}, "{ID}": {…}}`) to `{reports}/{EPIC-ID}-registration.json`, check it with `jq length {reports}/{EPIC-ID}-registration.json` (prints the entry count), add the `REPORT FILE:` line, and in DETAILS write `- registration data: {n} entries in the REPORT FILE` instead of the entries. WHY: a truncated report loses entries silently; the file arrives whole.

## MUST DO
- Write use cases before stories (stories without flows produce untestable ACs).
- Make every AC observable and testable; cover every exception flow.
- Set a tier on every story from the signal table — the whole downstream depth depends on it.
- Provide the exact registration JSON — in DETAILS, or in the REPORT FILE when it would pass the cap.
- Write every minimal slice into both story files.

## MUST NOT DO
- Edit `docs/state/*.json` — report entries; the PM registers them.
- Create a story that needs another story's file set to be understood.
- Guess at ambiguous requirements — OUTCOME: NEEDS_PRODUCT_INPUT with the quote.
- Copy BRD text into ACs verbatim (BRD language is business intent, ACs are verification steps).
- Write in the main checkout, or merge, push or switch branches.
- Create a story in an amendment pass, or more than the one reserved story from a ruling.
- Edit the story file of an item that is not `todo` — a Developer owns it in its worktree.
