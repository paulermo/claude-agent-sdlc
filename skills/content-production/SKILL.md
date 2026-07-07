---
name: content-production
description: "The content pipeline discipline shared by Content Creator, Content Reviewer and Content Integrator: file conventions, quality bars, per-role workflows and reports. Preloaded into all three content agents."
---

# Content Production

Three roles share this pipeline; your brief names yours. Common law for all three: content lives under `content/` exactly where the task file's output spec says; the content plan defines tone/style/format; facts are never invented.

## Role: Creator

1. Read the content task file, its content plan (tone, style, audience), the BRD for business context, and `.claude/rules/` content/style rules if present.
2. Produce the content in the task's specified format and path under `content/`:
   - Text → Markdown/JSON per spec, structured exactly as the task defines.
   - Data sets (decks, quizzes, catalogs) → JSON validating against the structure in the task; every record complete.
   - Images → SVG (or the task's specified pipeline); include alt-text metadata.
3. **Self-review before reporting** — the checklist the Reviewer will use (below). Catching your own miss is one loop cheaper.
4. Commit: `{CTASK-ID}: Generate {content description} [by Content Creator]`.

Quality bars: no invented facts, dates, figures, names — every factual claim traceable to the BRD/plan/common knowledge; educational content's answers must be correct and unambiguous; localized content follows each language's conventions (no machine-translation artifacts).

## Role: Reviewer (read-only)

Check, in order:

| # | Check | Reject when |
|---|-------|-------------|
| 1 | Plan compliance | wrong type/format/path, missing items from the task's scope |
| 2 | Factual accuracy | any invented or wrong fact/figure/date; wrong answers in educational content |
| 3 | Tone & style | contradicts the plan's Tone & Style section |
| 4 | Completeness | placeholder text, truncated records, empty required fields |

Every rejection finding: file, what's wrong, what correct looks like. Ambiguous style guidance is a NOTE to the PM, not a rejection. Do not invent problems — complete, accurate, on-tone content is APPROVED.

## Role: Integrator

1. Read the task's Integration Notes and the approved files under `content/`. Read `.claude/rules/` for how the app handles content, and `.claude/rules/quality-gate.md`.
2. Integrate by the method the notes prescribe: DB content → migration files; initial data → seeds/fixtures; assets → the app's static pipeline; registries/manifests → updated.
3. Verify locally with the worktree ports from your brief (`COMPOSE_PROJECT_NAME={id} APP_PORT={app} DB_PORT={db} docker compose up -d`, run migrations, confirm the content renders where users will see it).
4. Write integration tests proving the content loads. Run the quality gate.
5. Commit: `{CTASK-ID}: Integrate {content description} into app [by Content Integrator]`.

Boundary: migrations, seeds, static resources, registry wiring ONLY. Application logic changes are a Developer's story — if integration requires one, report BLOCKED naming exactly what's missing.

## Report (all roles)

```
=== AGENT REPORT ===
AGENT: Content {Creator|Reviewer|Integrator}
ITEM: {CTASK-ID}
OUTCOME: CREATED | APPROVED | REJECTED | INTEGRATED | BLOCKED
EVIDENCE:
- {Creator: self-review checklist results; Reviewer: checks 1-4 each pass/fail; Integrator: quality-gate + render verification results}
FILES:
- {produced/modified} | none (Reviewer)
BLOCKERS: {none | list}
DETAILS: {Reviewer REJECTED: findings per file; Integrator: method used per content unit}
=== END REPORT ===
```

## MUST NOT DO (all roles)
- Edit `docs/state/*.json` — the PM writes state from your report.
- Reviewer: modify any file (read-only role — the toolset enforces it).
- Creator: leave placeholders or partial records "to fill later".
- Integrator: touch application logic, or skip the local render verification.
