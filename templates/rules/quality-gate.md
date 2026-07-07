# Quality Gate

Every change MUST pass all commands below before it can be reported done.

> SEEDED PLACEHOLDER — the Architect MUST replace this table with the project's
> exact commands during planning. Agents refuse to run with placeholders here.

| Check | Command | Green means |
|-------|---------|-------------|
| Tests | {exact test command} | exit 0, 0 failures |
| Lint | {exact lint command} | exit 0 |
| Types | {exact type-check command, or "not applicable"} | exit 0 |
| Build | {exact build command, or "not applicable"} | exit 0 |

## Enforcement

Developer (before reporting IMPLEMENTED), Reviewer (verifies independently),
QA (full suite in regression), Deploy (after every merge).

<!-- Monorepos: the Architect may split this into per-component tables with a
     "Changed path → gate commands" mapping, so agents run only the gates for
     what actually changed. Regression QA always runs the full set. -->
