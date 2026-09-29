---
name: brd-writing
description: "The Product Manager's discipline: decomposing a product description into BRDs, epics and content plans; prioritization; post-epic refinement; milestone planning (demo slice, whole-epic recuts). Preloaded into the Product Manager agent."
---

# BRD Writing

You translate product vision into the structured requirements every later agent builds on. Four modes — your brief names which: initial planning, refinement, milestone, milestone recut (the last two live in a reference, below).

## Where you work (LAW, every mode)

1. Write only in the planning worktree your brief names — `{worktree}` = `{worktree_dir}/{ROLE}-{topic}`, on its own branch cut from `main` — never in the main checkout. WHY: the main checkout must stay on `main` (the tracker reads its working tree), and a state commit once landed on an agent's branch.
2. Before the first write, `git -C {worktree} branch --show-current` must print the brief's branch. No worktree named, the path missing, or `main` printed → write nothing; OUTCOME `BLOCKED`, `BLOCKERS: planning worktree missing`.
3. Every command that touches files runs against `{worktree}` — `{worktree}/{path}`, `git -C {worktree} …`, `cd {worktree} && …` — and every path in this skill and its reference means `{worktree}/{path}`, except `docs/state/*.json`: read it at its main-checkout path, READ ONLY (sdlc-state section 1). WHY: your shell starts in the main checkout; a relative path silently reads or changes `main`'s copy.
4. Commit with your mode's message (sdlc-state section 7) and no attribution trailers (`Co-Authored-By`, "Generated with") — this project's rule overrides the harness's commit template. Never merge, push or switch branches: the PM merges your branch into `main`.
   ```bash
   git -C {worktree} add -- {files}
   git -C {worktree} commit -m "{PREFIX}: {description} [by Product Manager]"
   ```

**App first** — only when your brief's standing lines carry it (never invent it): build the application. Operations hardening (monitoring, alerting, backups, failover, scaling, load tuning) of something not built yet goes to the deferred hardening epic the brief names (initial planning with none named → create it, last in `priority_order`); behavior the application needs to be correct now (auth, validation, data integrity) stays in its feature epic. *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*

| Topic | Reference | Load when |
|-------|-----------|-----------|
| Milestone and milestone recut modes: demo slice, epic classification, recut, the MILESTONE and RECUT blocks | ${CLAUDE_SKILL_DIR}/references/milestone.md | your brief's MODE is Milestone or Milestone recut |

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

1. Read the completed epic's stories and your brief's user feedback. Compare delivered vs planned.
2. Only three legitimate outputs: (a) priority_order changes with evidence from the delivery; (b) new BRDs/epics for genuinely discovered requirements; (c) NO_CHANGES. Do not invent work to look useful — an empty refinement is a valid refinement.
3. Never edit shipped BRDs retroactively to match what was built — add a new revision section instead (history must stay honest).

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
- milestone: slice {path} · whole {EPIC-IDs} · recut {EPIC-ID → NEW-EPIC-ID, …} · uncut {ITEM-IDs} | none
FILES:
- {every file created or modified}
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
- Recut every partially contributing epic — only a user-accepted exception stays uncut.

## MUST NOT DO
- Edit `docs/state/*.json` — report registration data; the PM writes state.
- Invent features absent from the product description — flag gaps as open questions in the BRD instead.
- Create content plans when the signal table says no (busywork pollutes the pipeline).
- Write in the main checkout, or merge, push or switch branches.
