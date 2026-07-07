# Rule Authoring

How to write rules into a target project's `.claude/rules/`. Rules are context Claude loads — specific, concrete rules are followed reliably; vague ones are not.

## How loading works

- **Unconditional rule** — no frontmatter. Loads every session. Use for always-on constraints: architecture, security, cross-cutting standards, the quality gate.
- **Path-scoped rule** — `paths:` YAML frontmatter; loads only when a file matching a glob is read:

  ```markdown
  ---
  paths:
    - "src/api/**/*.ts"
    - "tests/api/**"
  ---
  # Rule title
  ```

- Directory placement is human organization ONLY — it has zero effect on loading. A stack-specific rule sitting in a subdirectory WITHOUT `paths:` still loads for everyone; always add `paths:` to stack-specific rules.
- Subagents inherit the project's rules automatically — what you write here reaches every pipeline agent.

## Is a rule the right tool?

| Need | Right tool |
|------|-----------|
| Always-on constraint | unconditional rule |
| Constraint tied to file type/directory | path-scoped rule |
| Multi-step workflow | that's a skill/agent concern — not a rule |
| Something a linter/formatter can enforce | configure the tool; write a rule only for what tooling can't express |

## File skeleton (follow it — agents parse structure, not prose)

```markdown
# {Constraint as a title, e.g. "API errors use RFC 7807"}

{One-two line rule statement. No preamble.}

## Where this applies
- {concrete locations/situations}

## Where this does NOT apply
- {the boundary, by exclusion — prevents overreach}

## Examples

{Bad block}
{Good block}
(one pair per language the project uses)

## Enforcement
{Which agent/gate checks this: "Reviewer — MANDATORY", "quality-gate lint step", …}
```

Naming: lowercase, hyphenated, topic-first — `timestamp-standards.md`, not `for-backend.md`. One topic per file; a rule covering unrelated topics gets split.

## Before creating a file

`grep -ri "{keyword}" .claude/rules/` — if the topic is covered, update the existing rule. Two rules on one topic make agents pick arbitrarily.

## The two mandatory root rules

**`.claude/rules/architecture.md`** — components + boundaries + allowed-dependency direction + where each kind of code lives. This is the file the Reviewer's Placement lens and the infra agents' designs hang off.

**`.claude/rules/quality-gate.md`** — the project's exact verification commands:

```markdown
# Quality Gate

Every change MUST pass all commands below before it can be reported done.
Run from {repo root | package dir}.

| Check | Command | Green means |
|-------|---------|-------------|
| Tests | {exact command} | exit 0, 0 failures |
| Lint | {exact command} | exit 0 |
| Types | {exact command} | exit 0 |
| Build | {exact command} | exit 0 |

## Enforcement
Developer (before reporting IMPLEMENTED), Reviewer (verifies independently),
QA (full suite in regression), Deploy (after every merge).
```

Redundant enforcement is the point: four agents cite ONE definition — update it here and everyone's gate changes together.
