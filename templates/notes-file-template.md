# Review notes — {EPIC-ID}

NOTE-level findings from story reviews, resolved at the batch end (`.claude/rules/quality-gate.md` §Review and merge).
Written by the PM only; agents read this file and never edit it. One project-wide `N-{n}` sequence (counter `note`).

<!-- Line format (sdlc-state section 4, Notes). One heading per saved review; one line per NOTE.
     Open:      - [ ] N-{n} · {category} · {finding, with file:line where it applies}
     Resolved:  - [x] N-{n} · {category} · {finding} · **→ fixed in the batch ({sha})**
                - [x] N-{n} · {category} · {finding} · **→ FU-{m}**
                - [x] N-{n} · {category} · {finding} · **dropped: {one-line reason}**
                - [x] N-{n} · {category} · {finding} · **→ carried to {EPIC-ID} as N-{k} ({its next merge of main | before {ITEM-ID}})**
                - [x] N-{n} · {category} · {finding} · **→ ruled ({sha})**
     Carried in from another epic (under a heading `## Carried from {EPIC-ID}`):
                - [ ] N-{k} · {category} · {finding} (was {EPIC-ID} N-{n})
     Categories: test · prose · prose ({role}) · style · docblock · contract · named arguments · selection ·
     performance (later) · rule gap (Architect) · rule text (Architect) · planning (for {items}) ·
     for the {EPIC-ID} merge · Architect ruling before {ITEM-ID} -->

## {ITEM-ID} (review round 1, docs/reviews/{ITEM-ID}-1.md)

- [ ] N-{n} · {category} · {finding, with file:line where it applies}
