# System Analyst modes — milestone slice, amendment pass, one story from a ruling

Loaded when your brief's MODE is one of these three. The SKILL's "Where you work" law governs every step: each path below means `{worktree}/{path}` except `docs/state/*.json` (main checkout, READ ONLY), and you commit with the SKILL's commands. The SKILL's AC-quality rules, sizing signals and tier table still apply.

**Never edit the story file of an item that is not `todo`** — a Developer owns it in its own worktree; your edit would conflict with its branch or be lost. An item's status (main checkout, READ ONLY) — it prints the status; it prints nothing and the ID is named in the slice document or the brief → the item is archived, i.e. `done`; it prints nothing for any other ID → the ID is wrong: BLOCKED naming it:

```bash
jq -r --arg i "{ITEM-ID}" '(.stories // {})[$i].status // empty' docs/state/active.json docs/state/backlog.json
```

## Mode: Milestone slice (the brief gives `{MS-ID}` = `{PREFIX}-MS-{K}`, the slice document or demo steps, the prerequisites)

A prerequisite is a capability a slice item needs from an item outside it.

1. Read the slice document (`docs/reports/demo-slice-{K}.md`) or the brief's demo steps, then for each prerequisite its consuming and providing story files. Search code (Glob/Grep under `{worktree}`) only to test `satisfied`. Do NOT read other stories.
2. Run the status command for both items of each prerequisite, then give one verdict:

   | Signal | Verdict |
   |---|---|
   | the providing item's status is `done` or prints nothing (archived), or the code already does it (name the file) | `satisfied` |
   | the demo needs a narrow part the consuming story can carry without firing a sizing signal, and BOTH items are `todo` | `minimal slice: {name}` |
   | anything else | `pulled in whole` |

   The status check and the both-`todo` condition are LAW. The rest of the table: *Default, not law: deviate only on concrete grounds, and record the rationale in your report DETAILS.*
3. A minimal slice is written into BOTH story files under `## Minimal slice: {name}` — the consuming story gets the slice's ACs and test criteria; the providing story gets "Delivered first by {CONSUMING-ID} for {MS-ID} — extend it, do not rebuild it." WHY: a slice recorded on one side only is rebuilt or broken by the other story.
4. Count the slice. Epics = the epics that deliver it (a recut epic counts once, as its milestone part) + the epic of each `pulled in whole` item that is not among them (it will be recut; its milestone part counts once). Items = the items of those milestone parts (the slice document's `Items in the slice` column, or the brief's list) + every `pulled in whole` item not yet counted + the uncut exception items.
5. If the slice document is in your worktree, write the verdicts into its `## How the slice is planned` table and the count into `## Final count`.
6. Commit: `{PREFIX}: Slice {MS-ID} — prerequisite verdicts [by System Analyst]`.

Fixed DETAILS lines: one `verdict: {prerequisite} — satisfied ({done ITEM-ID | file}) | minimal slice: {name} ({CONSUMING-ID} ← {PROVIDING-ID}) | pulled in whole ({ITEM-ID} from {EPIC-ID})` per prerequisite, then `final count: {"epics": {E}, "items": {I}}` — the PM copies it into the milestone's `planned_count` (sdlc-state section 6).

## Mode: Amendment pass (after the Architect's Design Mode changed stories)

1. The brief lists the changed stories, the Architect's tier changes and the design's diff or ADR paths. Read those, then exactly the listed story files and their use cases. Do NOT read or edit any other story. A listed story whose item is not `todo` is not edited: DETAILS `not amended: {STORY-ID} ({status})`.
2. Amend each listed story only where the design changed it: its ACs (the AC quality rules hold) and a pointer line in `## Technical Notes` to the decision (ADR or rule path — never rewrite the Architect's notes).
3. Check each `**Tier:**` line against the Architect's tier changes — never edit it (a tier change is the Architect's, in Design Mode). A line that disagrees is reported, not fixed.
4. Re-check the sizing signals; one that fires is reported (`sizing fired: {STORY-ID} — {signal}`), never split — this mode creates no stories.
5. Commit: `{PREFIX}: Amend {STORY-IDs} after the {EPIC-ID} design [by System Analyst]`.

DETAILS, one line per story: `{STORY-ID}: ACs +{added} -{removed} ~{changed} · technical-notes pointer {added | none} · tier {matches | mismatch: line {tier}, Architect {tier}}`.

## Mode: One story from a ruling (dispatch mode `story cut`)

1. The brief gives the reserved story ID, the ruling (ADR path) and the epic. Read the ruling, the epic's `epic.md`, the use case the new scope extends and `docs/glossary.md`.
2. Write exactly one file, `docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md`, from the story template: ACs for the ruling's new scope only; `**Use Case:**` the use case it extends, or `none — {ADR path}`; the tier from the tier table; `## Technical Notes`: a pointer to the ADR. Nothing else — no use case, no epic.md edit, no second story; a sizing signal that fires is reported in DETAILS, not split. WHY: the PM reserved exactly one ID and verifies that your branch's diff lists exactly one file; anything more is scope nobody registered or reviews.
3. Commit: `{PREFIX}: Cut {STORY-ID} from ruling {ADR file name} [by System Analyst]`.

DETAILS: the story's registration JSON (the SKILL's Report schema) and `counters consumed: none — ID reserved by the PM`.
