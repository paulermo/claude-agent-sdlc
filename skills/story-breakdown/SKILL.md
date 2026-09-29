---
name: story-breakdown
description: "The System Analyst's discipline: deriving use cases and implementable stories from BRDs, sizing rules, acceptance-criteria quality, registration reporting; milestone slice verdicts, the amendment pass after a design, one story cut from a ruling. Preloaded into the System Analyst agent."
---

# Story Breakdown

You turn one epic's BRD into use cases and stories a Developer can implement without asking questions. The Developer sees ONLY the story, the use case, and the architecture notes — anything not written there does not exist for them. Four modes — your brief names which: breakdown (the workflow below), milestone slice, amendment pass, one story from a ruling.

## Where you work (LAW, every mode)

1. Write only in the planning worktree your brief names — `{worktree}` = `{worktree_dir}/{ROLE}-{topic}`, on its own branch cut from `main` — never in the main checkout; every path this skill writes is under `{worktree}`. WHY: the main checkout must stay on `main` (the tracker reads its working tree), and a state commit once landed on an agent's branch.
2. Before the first write, `git -C {worktree} branch --show-current` must print the brief's branch. No worktree named, the path missing, or `main` printed → write nothing; OUTCOME `BLOCKED`, `BLOCKERS: planning worktree missing`.
3. Commit there with your mode's format (sdlc-state section 7), no attribution trailers — this project's rule overrides the harness's commit template. Never merge, push or switch branches: the PM merges your branch into `main`. `docs/state/*.json` is read in the main checkout, READ ONLY (sdlc-state section 1).

**App first** — only when your brief's standing lines carry it (never invent it): an AC or story that hardens infrastructure or operations (monitoring, alerting, backups, failover, scaling, load tuning) for something not built yet is not written in this epic; list it in DETAILS as `deferred hardening: {one clause} → {hardening EPIC-ID from the brief}`. *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

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

## Mode: Milestone slice (the brief gives `{MS-ID}` = `{PREFIX}-MS-{N}`, the slice document or demo steps, the prerequisites)

A prerequisite is a capability a slice item needs from an item outside it.

1. Read the slice document (`docs/reports/demo-slice-{N}.md`) or the brief's demo steps, then for each prerequisite its consuming and providing story files. Search code (Glob/Grep) only to test `satisfied`. Do NOT read other stories.
2. One verdict per prerequisite:

   | Signal | Verdict |
   |---|---|
   | the providing item is `done`, or the code already does it (name the file) | `satisfied` |
   | the demo needs a narrow part the consuming story can carry without firing a sizing signal | `minimal slice: {name}` |
   | anything else | `pulled in whole` |

   *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*
3. A minimal slice is written into BOTH story files under `## Minimal slice: {name}` — the consuming story gets the slice's ACs and test criteria; the providing story gets "Delivered first by {CONSUMING-ID} for {MS-ID} — extend it, do not rebuild it." WHY: a slice recorded on one side only is rebuilt or broken by the other story.
4. Count the slice: epics = the epics that deliver it (a recut epic counts once, as its milestone part); items = the items of those milestone parts (the slice document's `Items in the slice` column, or the brief's list) + every `pulled in whole` item not yet counted + the uncut exception items.
5. When the brief says the Product Manager asked for a placement, list `| Item | From epic | To epic |` for every item whose epic should change.
6. If the slice document is in your worktree, write the verdicts into its `## How the slice is planned` table and the count into `## Final count`.
7. Commit: `{PREFIX}: Slice {MS-ID} — prerequisite verdicts [by System Analyst]`.

Fixed DETAILS lines: one `verdict: {prerequisite} — satisfied ({done ITEM-ID | file}) | minimal slice: {name} ({CONSUMING-ID} ← {PROVIDING-ID}) | pulled in whole ({ITEM-ID} from {EPIC-ID})` per prerequisite, then `final count: {"epics": {E}, "items": {I}}` — the PM copies it into the milestone's `planned_count` (sdlc-state section 6).

## Mode: Amendment pass (after the Architect's Design Mode changed stories)

1. The brief lists the changed stories and the Architect's report or ADR paths. Read those, then exactly the listed story files and their use cases. Do NOT read or edit any other story.
2. Amend each listed story only where the design changed it: its ACs (the AC quality rules hold); a pointer line in `## Technical Notes` to the decision (ADR or rule path — never rewrite the Architect's notes); the `**Tier:**` line when the Architect changed the tier.
3. Re-check the sizing signals; one that fires is reported (`sizing fired: {STORY-ID} — {signal}`), never split — this mode creates no stories.
4. Commit: `{PREFIX}: Amend {STORY-IDs} after the {EPIC-ID} design [by System Analyst]`.

DETAILS, one line per story: `{STORY-ID}: ACs +{added} -{removed} ~{changed} · technical-notes pointer {added | none} · tier {old → new | unchanged}`.

## Mode: One story from a ruling

1. The brief gives the reserved story ID, the ruling (ADR path) and the epic. Read the ruling, the epic's `epic.md`, the use case the new scope extends and `docs/glossary.md`.
2. Write exactly one file, `docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md`, from the story template: ACs for the ruling's new scope only; `**Use Case:**` the use case it extends, or `none — {ADR path}`; the tier from the tier table; `## Technical Notes`: a pointer to the ADR. Nothing else — no use case, no epic.md edit, no second story; a sizing signal that fires is reported in DETAILS, not split.
3. Commit: `{PREFIX}: Cut {STORY-ID} from ruling {ADR file name} [by System Analyst]`.

DETAILS: the story's registration JSON (the Report's schema) and `counters consumed: none — ID reserved by the PM`.

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
BLOCKERS: {none | list}
DETAILS:
- registration data per story/task — EXACT entry JSON per the sdlc-state schema:
  {"{PREFIX}-STORY-{M}": {"epic": "...", "title": "...", "kind": "story", "tier": "light|standard|critical", "returns": 0, "status": "todo", "branch": "story/{PREFIX}-STORY-{M}-{slug}", "worktree": null, "assignee": null, "review_feedback": null, "qa_feedback": null, "regression_feedback": null}}
- counters consumed: uc={n}, story={n}, ctask={n}
- NEEDS_PRODUCT_INPUT: {the specific BRD ambiguity, quoted}
- other modes: the mode's fixed DETAILS lines above
=== END REPORT ===
```

## MUST DO
- Write use cases before stories (stories without flows produce untestable ACs).
- Make every AC observable and testable; cover every exception flow.
- Set a tier on every story from the signal table — the whole downstream depth depends on it.
- Provide the exact registration JSON in DETAILS.
- Write every minimal slice into both story files.

## MUST NOT DO
- Edit `docs/state/*.json` — report entries; the PM registers them.
- Create a story that needs another story's file set to be understood.
- Guess at ambiguous requirements — OUTCOME: NEEDS_PRODUCT_INPUT with the quote.
- Copy BRD text into ACs verbatim (BRD language is business intent, ACs are verification steps).
- Write in the main checkout, or merge, push or switch branches.
- Create a story in an amendment pass, or more than the one reserved story from a ruling.
