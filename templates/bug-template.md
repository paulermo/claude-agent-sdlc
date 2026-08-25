# {PREFIX}-BUG-{N}: {Title — the symptom in one clause}

**Epic:** {PREFIX}-EPIC-{N}
**Kind:** bug
**Tier:** {light | standard | critical}   <!-- inherited from the origin item, else the tier table (story-breakdown skill); decides review/QA stages -->
**Origin:** {docs/reports/{ID}-regression-{n}.md | docs/reviews/{ID}-{n}.md | docs/reports/{ID}-qa-{n}.md | directive: {filename} | followups}
**Origin item:** {PREFIX}-STORY-{N} | -
**Status:** todo

## Symptom
<!-- What is observed — exact output, error text, failing command. Quote the origin report; never paraphrase into something it did not say. -->

## Reproduction
<!-- Exact steps or command that shows the symptom. A defect without reproduction is not registrable as a bug — it goes back as a follow-up line. -->
1.

## Expected
<!-- The behavior that should hold, in one or two sentences. Name the AC or rule it comes from, if any. -->

## Acceptance
- [ ] A regression test named after this bug reproduces the symptom on the pre-fix code and passes after the fix
- [ ] The full quality gate is green

## Scope hints
<!-- Files / classes / modules named in the origin report, one per line. The Developer stays inside them unless the cause is provably elsewhere. One class of defect per bug — list every instance here. -->
-

## Follow-ups closed by this bug
<!-- Hygiene bugs only: the FU-ids from followups.md this bug is expected to close. Otherwise "-". -->
-
