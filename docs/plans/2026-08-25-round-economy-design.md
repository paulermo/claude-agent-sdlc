# Round Economy — tiers, return budgets, follow-ups, bug items (v1.6.0)

**Status:** approved 2026-08-25 (user: "bugs by tier" + all seven mechanisms)
**Problem:** the first epic of a real project (CBS, 18 stories) consumed ~60% of a weekly token budget in 1.5 days and shipped two thirds of its scope. Measured: 50 dispatches, 27 of them returns; 23 bug-stories created during the day (14 never started); CBS-STORY-18 (a README) took 7 rounds, CBS-STORY-5 7 rounds, CBS-STORY-15 5 rounds.

## Where the cost was structural

| Cause (from the retrospective) | Where the plugin encoded it |
|---|---|
| One quality bar for everything | no notion of risk anywhere: story sizing is by AC count only; the Reviewer applies three lenses to every story; QA standard mode boots the app and writes E2E per AC — for a README too |
| Returns ratchet | `story-review` §4: ≥1 IMPORTANT = REJECTED with no round limit; a fresh Reviewer on round n+1 could add new IMPORTANTs on unchanged code; every return = fresh Developer + fresh Reviewer = two full context loads |
| Findings became stories | regression/merge failures spawned a *story* titled `fix:` through the full Dev→Review→QA→Deploy→regression pipeline; the Developer's out-of-scope rule ended in "PM will create a story"; no lighter item kind existed |
| 100-200-line briefs | templates are ~20 lines, but nothing capped a brief and the "quality bar" the PM wanted had no slot, so it was typed in freehand |
| A fourth verification layer | the verification table is a presence check, but nothing forbade re-running gates or re-judging findings |
| Reviews of reviews | no rule against second opinions; round-2 reviewers re-litigated round-1 findings |
| One story per instance | the review format is one finding = one file line; twelve instances of one pattern became twelve items |

**Cost unit:** a *return* — a fresh Developer (rules glob + story + use case + notes + feedback + code + gate) plus a fresh Reviewer (rules + story + diff + gate), sometimes QA too. Rework on a fresh agent stays (user decision 2026-07-08); this design makes returns rare and bounded rather than cheap.

## 1. Tier

`light | standard | critical`, assigned per story by the System Analyst from a signal table (DEFAULT tier — recorded deviations allowed), written into the story header (`**Tier:**`) and the state entry (`"tier"`). The Architect may change it in Design Mode (reports it; the PM updates state). Bugs inherit the origin story's tier; directive bugs get it from the same table. **Absent field = `standard`** — existing projects need no migration.

| Signal (any fires) | Tier |
|---|---|
| money movement, balances, pricing; auth/authz/sessions; PII or secrets; data migrations or deletes; irreversible external effects (emails, webhooks, payments) | critical |
| only docs/README/comments; config, tooling, CI, scripts; tests only; formatting; dependency bump without API change; scaffolding with no behavior | light |
| everything else; any mix with standard work | standard (any mix with critical → critical) |

What the tier decides (one table, cited everywhere — `sdlc-state` §4a):

| | light | standard | critical |
|---|---|---|---|
| Review lenses | story + rules (gate run stays) | all three | all three + adversarial pass |
| IMPORTANT in round 1 | follow-up | follow-up (Reviewer may promote with a stated downstream cost) | blocks |
| QA standard mode | not dispatched — gate + post-merge regression cover it | E2E per AC | E2E per AC + every exception flow + negative tests |
| Return budget | 1 | 2 | 3 |
| Bug path | Dev → merge → regression | Dev → delta review → merge → regression | Dev → review → QA → merge → regression |

## 2. Return budget (LAW)

`"returns"` counter on the entry (absent = 0), incremented by the PM on every `review_rejected` / `qa_rejected` transition. When a REJECTED/FAILED report arrives and `returns == budget(tier)`, the item is **parked** instead of re-dispatched: interactive sessions get a gate ("one more round" / "accept" — findings become follow-ups and the item proceeds / "park"); `--no-human` parks automatically with a decision line. Parked = rejected status with `returns >= budget`; not dispatchable until the gate or a directive says otherwise. Content tasks fall under the same law via the `standard` default. No status is added — parked is derivable from state.

## 3. Verdict law (story-review)

| Finding | Round 1 | Round ≥ 2 |
|---|---|---|
| MANDATORY (MUST/NEVER rule, security, AC not met, tests fail) | REJECTED | REJECTED |
| IMPORTANT | critical: REJECTED · standard/light: follow-up, promotable once with `Blocks: yes — {what a later story builds on this}` | follow-up, any tier |
| NOTE | never | never |

**Re-review scope law:** round n+1 reads the prior review, `git diff {prior-head}..HEAD` and the files prior findings name. Prior findings get FIXED / STILL OPEN / WITHDRAWN (a Developer `DISPUTED:` line is resolved by quoting the rule text — no rule, withdrawn); a settled finding's merit is never re-judged. Outside the delta the Reviewer re-runs the gate and re-checks AC coverage; it does not re-read unchanged files hunting for new IMPORTANT/NOTE findings. Provenance: CBS-STORY-18. **Class rule:** one finding per class with an instances list — twelve instances of one pattern are one finding. Provenance: twelve "instance of own name" stories.

The review document gains `**Tier:**`, `**Round:**`, `**Head:** {sha}` and a `## Follow-ups` section.

## 4. Follow-ups

`docs/issues/{EPIC-ID}-{slug}/followups.md` — PM-only, written on main like `docs/reviews/`, so branches never touch it and merges never conflict. One line per **class**: `- [ ] FU-{n} · {class} · instances: {file:line…} · origin: {report path} · size: small | larger`. Sources: review Follow-ups sections, QA `## Out-of-scope defects`, Developer `OUT OF SCOPE` lines — when the fix is ≤ 5 lines in one file. Every Developer brief points at the file: close open entries whose instances lie in files you modify anyway, never open other files for them, report `FOLLOW-UPS CLOSED:`; the PM ticks them. At epic end, open entries become ONE hygiene bug; `ready_for_deploy` requires it done (the presence check over active.json stays).

## 5. Bugs

A new item kind, stored in the `stories` map with `"kind": "bug"` so `/status`, the tracker and the bucket law keep working unchanged. ID `{PREFIX}-BUG-{N}` (counter `bug`), branch `bug/{PREFIX}-BUG-{N}-{slug}`, record `docs/issues/{EPIC-ID}-{slug}/bugs/{BUG-ID}-{slug}.md` from `templates/bug-template.md` — the PM writes it from the report or directive (a tracking document, like a saved review). No story file, use case or spec-lite artifacts; the acceptance criterion is a regression test that reproduces the symptom and passes after the fix, plus a green gate.

```
todo → in_progress → [ready_for_review → in_review →] [ready_for_qa → in_qa →] ready_for_merge → merged → done
       light: neither bracket · standard: review only · critical: both
```

Return budget 1 for every tier. Sources (the PM registers, single-writer): regression FAILED, MERGE_FAILED / VERIFICATION_FAILED, out-of-scope defects larger than a follow-up (from QA or Developer reports), a user directive `bug-*.md`, the epic-end hygiene bug. QA never proposes stories — its DETAILS carry failures (AC-linked, with reproduction) and `## Out-of-scope defects` (class, instances, reproduction, size); scope belongs to the Analyst.

## 6. PM economy laws

- **Brief = filled template.** WHY is the only free text (≤ 2 sentences); hard cap = template + 5 lines; anything more lives in a file the brief points to.
- **Verification is a presence check.** MUST NOT re-run the gate, re-read diffs, re-execute tests, re-judge findings, or dispatch a second Reviewer/QA for a second opinion; exceptions: BLOCKERS non-empty, or the user asks.
- **Findings routing table** in `start.md`: blocking → rework within budget; follow-ups → followups.md; out-of-scope ≤ 5 lines/1 file → follow-up, larger → bug; regression/merge failures → bug; N instances of one class → one record.
- **Never review a review.**

## 7. Rework economy

Rework briefs list minimal INPUTS (feedback file + files it names + quality-gate.md + the rules the findings cite; no full rules glob, no use case re-read). Re-review briefs carry `ROUND`, `PRIOR REVIEW` and `PRIOR HEAD` so the Reviewer diffs the delta only.

## Compatibility

No state migration: absent `kind`/`tier`/`returns` default to `story`/`standard`/`0`. `/agent-sdlc:init` adds the `bug` counter on migration runs and copies `bug-template.md`. Tracker: kind/tier/returns shown on cards and item view; bugs land in the board columns by status as before. Version 1.6.0 (new item kind + new laws).

## Expected effect (estimate, not a promise)

Returns per story from ~2.5 to ≤ 1.3 (budgets + verdict law + re-review scope); 23 bug-stories would have been ~5 bugs + 1 hygiene bug; light-tier stories (README, config) skip QA entirely; PM-side tokens per dispatch drop with the brief cap and the presence-only verification.
