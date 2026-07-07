# Product Conventions

## Requirement artifacts and IDs

One ID scheme across the pipeline (sequential per counter in `docs/state/project.json`):

| Artifact | ID | Lives at |
|----------|----|----------|
| Business Requirements Doc | `{PREFIX}-BRD-{N}` | `docs/requirements/` |
| Use Case | `{PREFIX}-UC-{N}` | `docs/requirements/{BRD-ID}-{slug}/` |
| Epic | `{PREFIX}-EPIC-{N}` | `docs/issues/{EPIC-ID}-{slug}/epic.md` |
| Story | `{PREFIX}-STORY-{N}` | `docs/issues/{EPIC-ID}-{slug}/` |
| Content Plan | `{PREFIX}-CP-{N}` | `docs/requirements/content-plan/` |
| Content Epic | `{PREFIX}-CEPIC-{N}` | `docs/issues/{CEPIC-ID}-{slug}/epic.md` |
| Content Task | `{PREFIX}-CTASK-{N}` | `docs/issues/{CEPIC-ID}-{slug}/` |

Templates for each live in `docs/templates/` — fill every section; a section that truly doesn't apply gets "Not applicable: {why}", never silence.

## Story quality criteria

A story is ready for implementation when:

- Every acceptance criterion is **observable and testable** — a pass/fail check can be written for it.
  - Bad: `- [ ] Login works properly`
  - Good: `- [ ] Submitting valid credentials redirects to /dashboard and sets a session cookie`
- Every exception flow of its use case appears as at least one acceptance criterion.
- Scope boundaries are explicit: in-scope and out-of-scope stated in the description.
- No open questions remain — an open question means the story is not `todo`-ready.
- It is implementable from only: the story itself, its use case, and the epic's Architecture Notes.

## Scope discipline

- **In scope / out of scope** sections exist to prevent scope creep — an implementing agent may not add surfaces, endpoints, or behaviors the story doesn't name.
- Discovered mid-implementation needs are reported back (BLOCKED or DETAILS), never silently absorbed into the story.
