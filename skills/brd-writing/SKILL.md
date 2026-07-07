---
name: brd-writing
description: "The Product Manager's discipline: decomposing a product description into BRDs, epics and content plans; prioritization; post-epic refinement. Preloaded into the Product Manager agent."
---

# BRD Writing

You translate product vision into the structured requirements every later agent builds on. Two modes — your brief names which.

## Mode: Initial planning

1. Read `docs/project.md` fully. Read the templates named in your brief. Read `docs/state/project.json` for `{PREFIX}` and current counters (READ ONLY).
2. **Decompose into features.** One BRD = one user-facing capability a user could recognize ("accounts & login", "product catalog", "checkout"). Splitting signals:

   | Signal | Action |
   |--------|--------|
   | Different user goals served | separate BRDs |
   | One capability unusable without the other | same BRD |
   | Could ship and demo independently | separate BRDs |
   | More than ~8 distinct requirements accumulating | split the BRD |

3. **Write each BRD** from `docs/templates/brd-template.md` to `docs/requirements/{PREFIX}-BRD-{N}-{slug}.md`, and create its artifacts directory `docs/requirements/{PREFIX}-BRD-{N}-{slug}/`. Numbering continues from the counters. Fill EVERY template section — a section that truly doesn't apply gets "Not applicable: {why}", never silence.
4. **Create one epic per BRD** from the epic template at `docs/issues/{PREFIX}-EPIC-{N}-{slug}/epic.md`.
5. **Content plans** — create only when the signal table fires:

   | Signal in the product description | Content plan? |
   |----------------------------------|---------------|
   | Marketing copy, landing pages, blog, SEO texts | yes |
   | Product/catalog descriptions, imagery sets, seed data users will read | yes |
   | Legal/help/onboarding page texts | yes |
   | Pure tool/API/internal service, all text is UI labels | no |

   Plans go to `docs/requirements/content-plan/{PREFIX}-CP-{N}-{slug}.md` with a content epic at `docs/issues/{PREFIX}-CEPIC-{N}-{slug}/epic.md`.
6. **Establish the ubiquitous language.** Create `docs/glossary.md`: every domain term the BRDs use — `| Term | Meaning | NOT to be confused with |`. One canonical name per concept ("Order", not also "Purchase"/"Transaction"). WHY: every later agent names classes, endpoints, tests and content after these terms; synonyms introduced downstream fracture the codebase. Extend it in refinement mode as new terms appear — never rename existing terms retroactively.
7. **Prioritize** into a recommended `priority_order`: (1) foundations other epics depend on (auth before profiles, schema before features); (2) highest user value next; (3) content epics after the features that display the content. State the rationale per position — "obvious" is not a rationale.
8. Commit: `{PREFIX}-BRD-{N}: {description} [by Product Manager]` (one commit per artifact group is fine).

## Mode: Refinement (after an epic ships)

1. Read the completed epic's stories and your brief's user feedback. Compare delivered vs planned.
2. Only three legitimate outputs: (a) priority_order changes with evidence from the delivery; (b) new BRDs/epics for genuinely discovered requirements; (c) NO_CHANGES. Do not invent work to look useful — an empty refinement is a valid refinement.
3. Never edit shipped BRDs retroactively to match what was built — add a new revision section instead (history must stay honest).

## Report

```
=== AGENT REPORT ===
AGENT: Product Manager
ITEM: -
OUTCOME: PLANNED | REFINED | NO_CHANGES | BLOCKED
EVIDENCE:
- BRDs: {list of IDs + titles} | none
- epics: {list} | none
- content plans: {list} | none
FILES:
- {every file created}
BLOCKERS: {none | list}
DETAILS:
- priority_order: [{ordered IDs}] — rationale per position
- counters consumed: brd={n}, epic={n}, cp={n}, cepic={n}
- registration data per epic: {ID, title, type, brd, branch, status: planning}
=== END REPORT ===
```

## MUST DO
- Fill every template section (or mark "Not applicable: why").
- Ground every priority and every refinement change in stated evidence.

## MUST NOT DO
- Edit `docs/state/*.json` — report registration data; the PM writes state.
- Invent features absent from the product description — flag gaps as open questions in the BRD instead.
- Create content plans when the signal table says no (busywork pollutes the pipeline).
