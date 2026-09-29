# Demo slice {N} — {milestone title} ({PREFIX}-MS-{K})

**Decided by:** {the user}, {YYYY-MM-DD} · **Cut by:** {Product Manager / System Analyst}, {YYYY-MM-DD}
**Goal:** {the milestone goal, one or two sentences} · **Target:** {YYYY-MM-DD | none}

## The demo

Numbered steps the user will see. Each step names the items that deliver it; a step the application cannot do yet is
marked **scripted** (done by a helper, not by the application).

1. {what the user does and sees} — {ITEM-IDs}
2. {…} — **scripted**: {why, and what stands in}

## In and out

- **In:** {capabilities in this slice}
- **Out, and staying out until the demo runs:** {capabilities deliberately excluded}

## How the slice is planned

| Prerequisite | System Analyst verdict | Detail |
|---|---|---|
| {capability or item} | already satisfied \| minimal slice \| pulled in whole | {for a minimal slice: its name, written into both story files} |

- Architect design pass owed: {what, before which item | none}.
- Product Manager placement: {how the items were placed into epics, one line}.

## The slice by epic

| Epic | Items in the slice | Items left for later | Recut? |
|---|---|---|---|
| {EPIC-ID} {title} | {count} | {count} | {no \| yes → remainder {EPIC-ID}} |

## Placement

| Item | From epic | To epic |
|---|---|---|
| {ITEM-ID} | {EPIC-ID} | {EPIC-ID} |

## Design owed

- {design decision needed, owner (Architect / Designer), before which item}

## Build order

| Lane | Items in order | Waits for |
|---|---|---|
| {1} | {ITEM-IDs} | {nothing \| item or ruling} |

## The demo's local configuration

{Environment, seed data created through the system's own paths, helper scripts kept outside the repository.}

## Final count

**{E} epics, {I} items** — this becomes the milestone's `planned_count` (sdlc-state section 6).
