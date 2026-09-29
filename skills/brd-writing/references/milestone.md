# Milestone modes — Product Manager

Loaded when your brief's MODE is Milestone or Milestone recut. The SKILL's "Where you work" law governs every step: each path below means `{worktree}/{path}` except `docs/state/*.json` (main checkout, READ ONLY), and you commit with the SKILL's commands. `{MS-ID}` = `{PREFIX}-MS-{K}`; `{K}` names its documents (`docs/reports/demo-slice-{K}.md`, `docs/reports/milestone-{K}-recut.md`). The milestone's id, title, goal and target are the user's words — copy them verbatim, never rephrase.

An epic's items, one line each (`{ID} {status} {title}`):

```bash
jq -r --arg e "{EPIC-ID}" '(.stories // {}), (.content_tasks // {}) | to_entries[] | select(.value.epic == $e) | "\(.key) \(.value.status) \(.value.title)"' docs/state/backlog.json docs/state/active.json
```

## Mode: Milestone (the brief gives `{MS-ID}`, its title, goal/demo and target)

1. Read the brief; `docs/state/epics.json` for the non-archived epics; each candidate epic's `epic.md` and BRD; its items (the command above). Open a story file only when a demo step may need it. Do NOT read source code, `docs/state/archive/` or other milestones' documents.
2. Write the demo: numbered steps the user will see, each naming the items that deliver it; a step the application cannot do yet is **scripted**. Then In and Out.
3. Classify every non-archived epic. An item a demo item needs as a prerequisite counts as needed — so a prerequisite in an epic outside the slice makes that epic partial, recut the same way. An epic already linked to another milestone is never reclassified (an epic belongs to at most one) — name it in DETAILS as `needed from {other MS-ID}: {EPIC-ID}`.

   | The epic vs the demo | Class | Goes to |
   |---|---|---|
   | every item needed | whole | `epics` |
   | some items needed, not all | partial | recut (Mode: Milestone recut, steps 1–4); its milestone part → `epics` |
   | the brief lists ITEM-IDs of this epic as user-accepted uncut exceptions | uncut | `stories` = exactly those ITEM-IDs; each other needed item → DETAILS `exception short: {ITEM-ID}`; the epic stays unlinked |
   | no items yet (not broken down — `planning_depth: just_in_time`) | by its BRD requirements | DETAILS `breakdown owed: {EPIC-ID} ({whole \| partial})`; whole → `epics`; partial → neither linked nor recut until its breakdown |
   | nothing needed | out | — |

   Never widen an uncut exception beyond the ITEM-IDs the user named. WHY: the exception is the user's ruling against the recut-whole rule; a silently widened one leaves a partial epic unrecut.
4. Recut every partial epic (Mode: Milestone recut, steps 1–4) — one recut document and one RECUT block for all of them. WHY: the user ruled that one epic never holds a few milestone stories with the rest for later; the milestone is shown as whole epics.
5. Write `docs/reports/demo-slice-{K}.md` from `docs/templates/demo-slice-template.md`, every section filled (`none`, or `pending {Role}` for what another role owes). How the slice is planned: the System Analyst's verdicts when the brief carries them, else each prerequisite with `pending System Analyst`. Placement: every item whose epic changes.
6. `planned_count`: the System Analyst's final count when the brief carries one; else your count (epics = the number of IDs in `epics`; items = the number of their items after the recut + the `stories` items), marked `estimate`.
7. Commit: `{PREFIX}: Plan milestone {MS-ID} — demo slice and recut [by Product Manager]`.
8. End DETAILS with the `breakdown owed:`, `exception short:` and `needed from` lines, the RECUT block (when step 4 recut anything), then this block. The PM applies it to the milestone entry and writes both sides of every link — the milestone's `epics` / `stories` and each epic's or item's `milestone` field — in the same response (sdlc-state section 6). `target` is `null` (unquoted) when the brief says none; `stories` is `[]` unless the brief accepted uncut items.

   ```
   === MILESTONE ===
   {"id": "{MS-ID}", "title": "{title}", "goal": "{goal}", "target": "{YYYY-MM-DD}", "epics": ["{EPIC-ID}", "{EPIC-ID}"], "stories": [], "slice_doc": "docs/reports/demo-slice-{K}.md", "planned_count": {"epics": {E}, "items": {I}}}
   planned_count: {System Analyst final count | estimate}
   === END MILESTONE ===
   ```

## Mode: Milestone recut (standalone, or steps 1–4 inside milestone mode)

The brief gives `{MS-ID}`, each epic to recut with its milestone part (or the slice document), and the reserved epic IDs. Read each epic's `epic.md` and its items (the command above).

1. Split: milestone part = the items the milestone needs; remainder = every other item. The milestone part keeps the original epic ID — branches, notes and gate reports are already named by it.
2. The remainder is a NEW epic, `{NEW-EPIC-ID}`: the brief's reserved IDs in order; beyond them, continue after the higher of the last reserved ID and `counters.epic` (a content epic's remainder: the next `{PREFIX}-CEPIC-{n}` after `counters.cepic`), and report `counters consumed`. Write `docs/issues/{NEW-EPIC-ID}-{slug}/epic.md` from `docs/templates/epic-template.md`: `**BRD:**` the original's (a content epic: its content plan ID); `**Status:** ready` (`planning` when the original is still `planning`); a Description of what it delivers, ending "Continues {EPIC-ID} after the {MS-ID} recut."; `## Stories` listing the moved items with their file paths; the epic acceptance criteria that only moved items deliver move with them.
3. In the original `epic.md`: add `**Continued by:** {NEW-EPIC-ID}` under the `**Priority:**` line; remove the moved items from `## Stories`. Item files stay where they are — never move or rename one; set each moved story's `**Epic:**` line (a content task's `**Content Epic:**` line) to `{NEW-EPIC-ID}`; bug records are PM-only — never edit one. WHY: reviews, notes, specs and branches cite an item file by its path; a moved file breaks every such reference and conflicts with any branch that touches it.
4. Write `docs/reports/milestone-{K}-recut.md`: the heading `# Milestone {K} recut — {MS-ID}`, then one row per item whose epic changes: `| Item | From epic | To epic |`.
5. Commit (standalone): `{PREFIX}: Recut {EPIC-IDs} for {MS-ID} [by Product Manager]`.
6. Put this block in DETAILS — one `EPIC`, `CONTINUED_BY` and `PRIORITY` line per remainder, one `MOVE` line per from→to pair. The PM applies it: epic entries, `continued_by`, each item's `epic` with a `recut` log line, the bucket law (sdlc-state sections 2, 6, 7). The `EPIC` entry's `status` is the one step 2 chose, and it never carries a `milestone` field — a link is made only through a MILESTONE block, both sides of which the PM writes. `PRIORITY` names the milestone's epic that comes last in `priority_order`. A report that would exceed `process.report_max_chars` (sdlc-state section 3) → the block goes under `## RECUT block` in the recut document, and DETAILS says `RECUT: see docs/reports/milestone-{K}-recut.md`.

   ```
   === RECUT {MS-ID} ===
   EPIC: {"{NEW-EPIC-ID}": {"title": "{title}", "status": "ready", "type": "epic", "brd": "{PREFIX}-BRD-{M}", "branch": "feature/{NEW-EPIC-ID}-{slug}"}}
   CONTINUED_BY: {EPIC-ID} → {NEW-EPIC-ID}
   MOVE: {FROM-EPIC-ID} → {TO-EPIC-ID}: {ITEM-ID}, {ITEM-ID}
   PRIORITY: {NEW-EPIC-ID} after {PRECEDING-EPIC-ID}
   TABLE: docs/reports/milestone-{K}-recut.md
   === END RECUT ===
   ```

   A content epic's remainder uses this `EPIC` line instead: `EPIC: {"{NEW-EPIC-ID}": {"title": "{title}", "status": "ready", "type": "cepic", "brd": "{PREFIX}-CP-{M}", "branch": "content/{NEW-EPIC-ID}-{slug}"}}`.

| Situation | Action |
|---|---|
| the remainder would be empty / the milestone part would be empty | no recut — the epic is whole / out |
| a milestone-part item needs a remainder item | that item joins the milestone part (a prerequisite) |
| an item to move is not `todo` | it stays in the milestone part; name it in DETAILS — an item in flight never changes epic |
| the epic has no items yet | no recut; DETAILS `breakdown owed: {EPIC-ID}` — its breakdown comes first, then a recut |
| the recut document already exists | append a `## Recut {YYYY-MM-DD}` section; never rewrite earlier rows |

## Report

The SKILL's envelope with ITEM `{MS-ID}`, OUTCOME `MILESTONE_PLANNED` (milestone mode) or `RECUT` (standalone recut), and its EVIDENCE `milestone:` line filled; DETAILS as step 8 (milestone mode) or step 6 (recut) says.
