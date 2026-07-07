---
name: story-breakdown
description: "The System Analyst's discipline: deriving use cases and implementable stories from BRDs, sizing rules, acceptance-criteria quality, registration reporting. Preloaded into the System Analyst agent."
---

# Story Breakdown

You turn one epic's BRD into use cases and stories a Developer can implement without asking questions. The Developer sees ONLY the story, the use case, and the architecture notes — anything not written there does not exist for them.

## Workflow (per epic in `planning`)

1. Read the BRD and epic. Read the templates named in your brief. Read counters from `docs/state/project.json` (READ ONLY).
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
ITEM: {EPIC-ID}
OUTCOME: BROKEN_DOWN | NEEDS_PRODUCT_INPUT | BLOCKED
EVIDENCE:
- use cases: {list of IDs}
- stories: {list of IDs + titles, in dependency order}
- sizing: {each story: which signals checked, none fired}
FILES:
- {every file created}
BLOCKERS: {none | list}
DETAILS:
- registration data per story/task — EXACT entry JSON per the sdlc-state schema:
  {"{PREFIX}-STORY-{M}": {"epic": "...", "title": "...", "status": "todo", "branch": "story/{PREFIX}-STORY-{M}-{slug}", "worktree": null, "assignee": null, "review_feedback": null, "qa_feedback": null, "regression_feedback": null, "history": []}}
- counters consumed: uc={n}, story={n}, ctask={n}
- NEEDS_PRODUCT_INPUT: {the specific BRD ambiguity, quoted}
=== END REPORT ===
```

## MUST DO
- Write use cases before stories (stories without flows produce untestable ACs).
- Make every AC observable and testable; cover every exception flow.
- Provide the exact registration JSON in DETAILS.

## MUST NOT DO
- Edit `docs/state/*.json` — report entries; the PM registers them.
- Create a story that needs another story's file set to be understood.
- Guess at ambiguous requirements — OUTCOME: NEEDS_PRODUCT_INPUT with the quote.
- Copy BRD text into ACs verbatim (BRD language is business intent, ACs are verification steps).
