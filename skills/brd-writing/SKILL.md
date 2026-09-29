---
name: brd-writing
description: "The Product Manager's discipline: decomposing a product description into BRDs, epics and content plans; prioritization; post-epic refinement; milestone planning (demo slice, whole-epic recuts). Preloaded into the Product Manager agent."
---

# BRD Writing

You translate product vision into the structured requirements every later agent builds on. Four modes — your brief names which: initial planning, refinement, milestone, milestone recut.

## Where you work (LAW, every mode)

1. Write only in the planning worktree your brief names — `{worktree}` = `{worktree_dir}/{ROLE}-{topic}`, on its own branch cut from `main` — never in the main checkout; every path this skill writes is under `{worktree}`. WHY: the main checkout must stay on `main` (the tracker reads its working tree), and a state commit once landed on an agent's branch.
2. Before the first write, `git -C {worktree} branch --show-current` must print the brief's branch. No worktree named, the path missing, or `main` printed → write nothing; OUTCOME `BLOCKED`, `BLOCKERS: planning worktree missing`.
3. Commit in the worktree with your mode's format below (sdlc-state section 7), no attribution trailers (`Co-Authored-By`, "Generated with") — this project's rule overrides the harness's commit template. Never merge, push or switch branches: the PM merges your branch into `main`. `docs/state/*.json` is read in the main checkout (your session's working directory), READ ONLY (sdlc-state section 1).

**App first** — only when your brief's standing lines carry it (never invent it): build the application. Operations hardening (monitoring, alerting, backups, failover, scaling, load tuning) of something not built yet goes to the deferred hardening epic the brief names (initial planning with none named → create it, last in `priority_order`); behavior the application needs to be correct now (auth, validation, data integrity) stays in its feature epic. *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

## Mode: Initial planning

1. Read `docs/project.md` fully. Read the templates named in your brief. Read `docs/state/project.json` for `{PREFIX}` and current counters (READ ONLY).
2. **Decompose into features.** One BRD = one user-facing capability a user could recognize ("accounts & login", "product catalog", "checkout"). Splitting signals:

   | Signal | Action |
   |--------|--------|
   | Different user goals served | separate BRDs |
   | One capability unusable without the other | same BRD |
   | Could ship and demo independently | separate BRDs |
   | More than ~8 distinct requirements accumulating | split the BRD |

   *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

3. **Write each BRD** from `docs/templates/brd-template.md` to `docs/requirements/{PREFIX}-BRD-{N}-{slug}.md`, and create its artifacts directory `docs/requirements/{PREFIX}-BRD-{N}-{slug}/`. Numbering continues from the counters. Fill EVERY template section — a section that truly doesn't apply gets "Not applicable: {why}", never silence.
4. **Create one epic per BRD** from the epic template at `docs/issues/{PREFIX}-EPIC-{N}-{slug}/epic.md`.
5. **Content plans** — create only when the signal table fires:

   | Signal in the product description | Content plan? |
   |----------------------------------|---------------|
   | Marketing copy, landing pages, blog, SEO texts | yes |
   | Product/catalog descriptions, imagery sets, seed data users will read | yes |
   | Legal/help/onboarding page texts | yes |
   | Pure tool/API/internal service, all text is UI labels | no |

   *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

   Plans go to `docs/requirements/content-plan/{PREFIX}-CP-{N}-{slug}.md` with a content epic at `docs/issues/{PREFIX}-CEPIC-{N}-{slug}/epic.md`.
6. **Establish the ubiquitous language.** Create `docs/glossary.md`: every domain term the BRDs use — `| Term | Meaning | NOT to be confused with |`. One canonical name per concept ("Order", not also "Purchase"/"Transaction"). WHY: every later agent names classes, endpoints, tests and content after these terms; synonyms introduced downstream fracture the codebase. Extend it in refinement mode as new terms appear — never rename existing terms retroactively.
7. **Prioritize** into a recommended `priority_order`: (1) foundations other epics depend on (auth before profiles, schema before features); (2) highest user value next; (3) content epics after the features that display the content. State the rationale per position — "obvious" is not a rationale.
8. Commit: `{PREFIX}-BRD-{N}: {description} [by Product Manager]` (one commit per artifact group is fine).

## Mode: Refinement (after an epic ships)

When your brief says a milestone plan is the live refinement, change nothing: OUTCOME `NO_CHANGES`, DETAILS `- refinement: the milestone plan {MS-ID} is live`. WHY: the slice already fixed the next epics and their order; a second reordering contradicts it. Otherwise:

1. Read the completed epic's stories and your brief's user feedback. Compare delivered vs planned.
2. Only three legitimate outputs: (a) priority_order changes with evidence from the delivery; (b) new BRDs/epics for genuinely discovered requirements; (c) NO_CHANGES. Do not invent work to look useful — an empty refinement is a valid refinement.
3. Never edit shipped BRDs retroactively to match what was built — add a new revision section instead (history must stay honest).

## Mode: Milestone (the brief gives `{MS-ID}`, its title, goal/demo and target)

`{MS-ID}` = `{PREFIX}-MS-{N}`; `{N}` names its documents (`demo-slice-{N}.md`, `milestone-{N}-recut.md`). The id, title, goal and target are the user's words — copy them verbatim, never rephrase.

1. Read the brief; `docs/state/epics.json` (READ ONLY) for the non-archived epics; each candidate epic's `epic.md` and BRD; its items: `jq -r --arg e "{EPIC-ID}" '(.stories, .content_tasks) | to_entries[] | select(.value.epic == $e) | "\(.key) \(.value.status) \(.value.title)"' docs/state/backlog.json docs/state/active.json`. Open a story file only when a demo step may need it. Do NOT read source code or other milestones' documents.
2. Write the demo: numbered steps the user will see, each naming the items that deliver it; a step the application cannot do yet is **scripted**. Then In and Out.
3. Classify every non-archived epic. An item a demo item needs as a prerequisite counts as needed — so a prerequisite in an epic outside the slice makes that epic partial, recut the same way. An epic already linked to another milestone is never reclassified (an epic belongs to at most one) — name it in DETAILS as `needed from {other MS-ID}: {EPIC-ID}`.

   | The epic's items vs the demo | Class | Goes to |
   |---|---|---|
   | every item needed | whole | `epics` |
   | some needed, not all | partial | recut (Mode: Milestone recut, steps 1–4); its milestone part → `epics` |
   | some needed, and the brief lists the epic as a user-accepted uncut exception | uncut | its needed items → `stories`; the epic stays unlinked |
   | none needed | out | — |
4. Recut every partial epic (Mode: Milestone recut, steps 1–4) — one recut document and one RECUT block for all of them. WHY: the user ruled that one epic never holds a few milestone stories with the rest for later; the milestone is shown as whole epics.
5. Write `docs/reports/demo-slice-{N}.md` from `docs/templates/demo-slice-template.md`, every section filled (`none`, or `pending {Role}` for what another role owes). How the slice is planned: the System Analyst's verdicts when the brief carries them, else each prerequisite with `pending System Analyst`. Placement: every item whose epic changes.
6. `planned_count`: the System Analyst's final count when the brief carries one; else your count (epics = the number of IDs in `epics`; items = the number of their items after the recut + the `stories` items), marked `estimate`.
7. Commit: `{PREFIX}: Plan milestone {MS-ID} — demo slice and recut [by Product Manager]`.
8. End DETAILS with the RECUT block (when step 4 recut anything), then this block. The PM applies it to the milestone entry and writes each listed epic's `milestone` field in the same response (sdlc-state section 6). `target` is `null` (unquoted) when the brief says none; `stories` is `[]` unless the brief accepted an uncut exception.

   ```
   === MILESTONE ===
   {"id": "{MS-ID}", "title": "{title}", "goal": "{goal}", "target": "{YYYY-MM-DD}", "epics": ["{EPIC-ID}", "{EPIC-ID}"], "stories": [], "slice_doc": "docs/reports/demo-slice-{N}.md", "planned_count": {"epics": {E}, "items": {I}}}
   planned_count: {System Analyst final count | estimate}
   === END MILESTONE ===
   ```

## Mode: Milestone recut (standalone, or steps 1–4 inside milestone mode)

The brief gives `{MS-ID}`, each epic to recut with its milestone part (or the slice document), and the reserved epic IDs. Read each epic's `epic.md` and its items (the `jq` command of milestone mode, step 1).

1. Split: milestone part = the items the milestone needs; remainder = every other item. The milestone part keeps the original epic ID — branches, notes and gate reports are already named by it.
2. The remainder is a NEW epic, `{NEW-EPIC-ID}`: the brief's reserved IDs in order; beyond them, continue after the higher of the last reserved ID and `counters.epic`, and report `counters consumed`. Write `docs/issues/{NEW-EPIC-ID}-{slug}/epic.md` from `docs/templates/epic-template.md`: `**BRD:**` the original's; `**Status:** ready` (`planning` when the original is still `planning`); a Description of what it delivers, ending "Continues {EPIC-ID} after the {MS-ID} recut."; `## Stories` listing the moved items with their file paths; the epic acceptance criteria that only moved items deliver move with them.
3. In the original `epic.md`: add `**Continued by:** {NEW-EPIC-ID}` under the `**Priority:**` line; remove the moved items from `## Stories`. Story files stay where they are — never move or rename one; set each moved story's `**Epic:**` line to `{NEW-EPIC-ID}`.
4. Write `docs/reports/milestone-{N}-recut.md`: the heading `# Milestone {N} recut — {MS-ID}`, then one row per item whose epic changes: `| Item | From epic | To epic |`.
5. Commit (standalone): `{PREFIX}: Recut {EPIC-IDs} for {MS-ID} [by Product Manager]`.
6. Put this block in DETAILS — one `EPIC`, `CONTINUED_BY` and `PRIORITY` line per remainder, one `MOVE` line per from→to pair. The PM applies it: epic entries, `continued_by`, each item's `epic` with a `recut` log line, the bucket law (sdlc-state sections 2, 6, 7). The `EPIC` entry's `status` is the one step 2 chose; it carries `"milestone": "{NEXT-MS-ID}"` only when the brief names a milestone for the remainder. `PRIORITY` names the epic it follows in `priority_order` — by default the milestone's last epic. A report that would exceed `process.report_max_chars` (sdlc-state section 3) → the block goes under `## RECUT block` in the recut document, and DETAILS says `RECUT: see docs/reports/milestone-{N}-recut.md`.

   ```
   === RECUT {MS-ID} ===
   EPIC: {"{NEW-EPIC-ID}": {"title": "{title}", "status": "ready", "type": "epic", "brd": "{PREFIX}-BRD-{M}", "branch": "feature/{NEW-EPIC-ID}-{slug}"}}
   CONTINUED_BY: {EPIC-ID} → {NEW-EPIC-ID}
   MOVE: {FROM-EPIC-ID} → {TO-EPIC-ID}: {ITEM-ID}, {ITEM-ID}
   PRIORITY: {NEW-EPIC-ID} after {PRECEDING-EPIC-ID}
   TABLE: docs/reports/milestone-{N}-recut.md
   === END RECUT ===
   ```

| Situation | Action |
|---|---|
| the remainder would be empty / the milestone part would be empty | no recut — the epic is whole / out |
| a milestone-part item needs a remainder item | that item joins the milestone part (a prerequisite) |
| an item to move is not `todo` | it stays in the milestone part; name it in DETAILS — an item in flight never changes epic |
| the recut document already exists | append a `## Recut {YYYY-MM-DD}` section; never rewrite earlier rows |

## Report

```
=== AGENT REPORT ===
AGENT: Product Manager
ITEM: - | {MS-ID}
OUTCOME: PLANNED | REFINED | NO_CHANGES | MILESTONE_PLANNED | RECUT | BLOCKED
EVIDENCE:
- BRDs: {list of IDs + titles} | none
- epics: {list} | none
- content plans: {list} | none
- milestone: slice {path} · whole {EPIC-IDs} · recut {EPIC-ID → NEW-EPIC-ID, …} · uncut {EPIC-IDs} | none
FILES:
- {every file created or modified}
BLOCKERS: {none | list}
DETAILS:
- priority_order: [{ordered IDs}] — rationale per position
- counters consumed: brd={n}, epic={n}, cp={n}, cepic={n}
- registration data per epic: {ID, title, type, brd, branch, status: planning}
- milestone modes: the RECUT block, then (milestone mode) the MILESTONE block
=== END REPORT ===
```

## MUST DO
- Fill every template section (or mark "Not applicable: why").
- Ground every priority and every refinement change in stated evidence.
- Recut every partially contributing epic — only a user-accepted exception stays uncut.

## MUST NOT DO
- Edit `docs/state/*.json` — report registration data; the PM writes state.
- Invent features absent from the product description — flag gaps as open questions in the BRD instead.
- Create content plans when the signal table says no (busywork pollutes the pipeline).
- Write in the main checkout, or merge, push or switch branches.
- Move or rename a story file, re-parent an item that is not `todo`, or recut a user-accepted uncut exception.
- Apply the app-first line when your brief's standing lines do not carry it.
