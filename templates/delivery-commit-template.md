{PREFIX}: Deliver {EPIC-ID}{ ({milestone ID}) | batch {n}} — {one-line behavior summary} [by Deploy]

What changed
- {behavior, in user terms}: {e.g. `{method} {route}`, a screen, a job} ({ITEM-ID}).
- {…}
- Batch fixes:
  - {what} (N-{n});
  - {…}
- Already on `main`: {ITEM-ID} ({what}), delivered with {EPIC-ID}.   <!-- or delete the line -->

Order of application
1. {e.g. migrations before any role starts: {names}}.
2. {e.g. then the service that serves the new routes}.

Before merge / deploy
- Migrations: {list | none}.
- Configuration: {files and what they carry | none}.
- Secrets: {new secret names | none}. Infrastructure applies: {roots | none}. Operator steps: {… | none}.
- No new {secret, role, queue, topic, event family} — {state each "no new …" explicitly}.

Follow-ups (existing IDs): FU-{n}, FU-{m}, …   <!-- or "none" -->

Test plan (full gate at {gated sha} with main merged in, on {runner {NN} slot {x} | this machine}; run {N} after {fixes / re-merges})
- {content guard}: clean
- {formatter}: 0 of {files} files changed
- {static analysis}: no errors ({files} files per configuration)
- {tests}: {tests} tests, {assertions} assertions, 0 failures, no skips
- {replay}: {N} histories replayed over {T} types, 0 mismatches
- {client checks}: {counts}; generated-client drift none ({files} files)
- {rows not applicable}: {row}: not applicable ({evidence}); {row}: not matched

<!-- How Deploy fills this (story-merge skill, delivery mode):
     - First line: `({milestone ID})` when the epic is linked to a milestone; `batch {n}` when the delivered batch is a
       cut batch (`batch.items` was a list); both apply → `({milestone ID}, batch {n})`; neither → nothing between the
       epic ID and the dash.
     - What changed: from the batch's story files and bug records (titles + acceptance criteria), grouped by behavior area;
       batch fixes from the notes file lines resolved "→ fixed in the batch".
     - Order / Before merge: from `git diff --name-only {main sha} {gated sha}` (`{main sha}` as read once at the start of the delivery) (migrations, config, infra, secrets names).
     - Follow-ups: the open FU IDs of the epic's followups.md — IDs only, never new text.
     - Test plan: the numbers of the PASSED batch-gate report, copied, never re-measured.
     Remove every HTML comment and every line that does not apply before committing.
     No attribution trailers — a hook denies them. -->
