# CLAUDE.md Authoring Rules

## Purpose

`CLAUDE.md` is the entry point for Claude Code. It tells Claude what this project is, how to work in it, and where to find deeper guidance.

## Structure

### Info Block (required at top)

Every `CLAUDE.md` starts with an Info Block — a quick-reference table that Claude reads first:

| Field | Required | Content |
|-------|----------|---------|
| **What** | Yes | One sentence: capability + key constraint |
| **When** | Yes | Names a file, hook, error, or action that triggers reading this |
| **Preconditions** | Yes | Env vars, flags, services, or explicit `—` |
| **Tools** | No | Special tools, commands, or MCPs needed |
| **Deep dive** | No | Path to detailed docs (`.claude/rules/...`, external docs) |

### Sections

Add a section when three or more conditions apply:
- Claude has made the same mistake twice
- A convention is not obvious from the code
- A workflow requires specific steps

### Section Patterns

Use the lightest format that fits:
- **Flow**: numbered steps for sequential workflows
- **Rules**: bullet list for constraints and conventions
- **Table**: rows for mapping (env → value, command → purpose)
- **Code**: fenced block for exact commands or templates
- **Prose**: short paragraph for context that doesn't fit other patterns

## Size Limits

- Target: under 500 lines total
- If a section body exceeds 20 lines, extract to `.claude/rules/{topic}.md` and link from CLAUDE.md
- CLAUDE.md is an index with brief guidance, not a comprehensive manual

## Maintenance Triggers

Update CLAUDE.md when:
- A new service, tool, or integration is added
- Environment variables or feature flags change
- Build/test/deploy commands change
- Claude makes a repeated mistake (add the correction as a rule)

Do NOT update for:
- Test-only changes
- Pure refactors with no behavior change
- Dependency bumps with no visible impact

## Anti-patterns

- Wall of text with no structure
- Duplicating content that's already in code comments or README
- Stale instructions that no longer match the codebase
- Instructions for humans (that belongs in README.md, not CLAUDE.md)
