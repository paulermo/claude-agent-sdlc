# Authoring Standards for Plugin Content

Every agent, skill, command, rule, and template in this plugin is executed by an LLM — possibly a weaker one than the model it was written with. These standards make instructions produce the same result regardless of executor. Apply them to every file you write or edit in this plugin, and to rules the Architect writes into target projects.

**The test for every instruction:** could two different models, reading this cold, do exactly the same thing? If not, rewrite it.

## The rules

1. **Numbered steps, exact commands.** Never "run the tests" — always the exact command, or a pointer to the one file that defines it (`.claude/rules/quality-gate.md`). Placeholders in `{braces}`; if a placeholder isn't self-evident, add a legend.

2. **Signal tables instead of judgment.** Every classification decision ("does this epic need a Designer?") gets a table of concrete signals → outcome. Every "if" gets criteria a model can check mechanically. "Evaluate whether…" without criteria is a coin-flip on a weaker model.

3. **MUST DO / MUST NOT DO lists close every skill.** Hard stops are marked:

   ```
   >>> GATE: {condition to satisfy} <<<
   ```

   A gate presentation and tool calls never share a response — a model that keeps working past a gate has skipped it.

4. **Output formats quoted verbatim.** Reports, review files, state entries, commit messages: give the full template, the agent fills placeholders. An agent should never invent structure.

5. **Evidence before claims.** "Done" requires the named check's actual output in the report (test counts, exit status, file list). "Tests look correct" is not "tests pass". Reports without evidence are treated as not done.

6. **State the WHY in one clause.** Models follow motivated constraints more reliably: "NEVER `-X theirs` — it silently discards one side's changes." The why also survives paraphrase when content is compressed.

7. **Edge cases as `Situation | Action` tables.** Enumerate the known failure modes; don't leave recovery to improvisation.

8. **Anti-rationalization guards at known corner-cutting points.** Where models predictably cheat, name the temptation and forbid it: inventing review findings to look thorough, marking tests passed without running them, silently narrowing scope, "for now" workarounds.

9. **Do-NOT-read / do-NOT-do lists.** Context economy is explicit: tell the agent what NOT to load ("Do NOT read other stories' files") and what is out of scope. Unbounded reading burns the context that discipline depends on.

10. **One source of truth per fact.** A status machine, a command, a schema lives in exactly one file; everything else cites it by exact path. When a slice must be repeated in place (an agent's own entry/exit statuses), keep it to the minimal slice and name the authoritative file.

## Frontmatter conventions

**Agents** (`agents/*.md`) — fixed schema:

```yaml
---
name: "Developer"
description: "{Verb-led capability}. Invoke when {triggers}. [Do NOT invoke for {anti-triggers}.]"
tools: Read, Write, Edit, Glob, Grep, Bash   # explicit, minimal (see recipe)
skills:
  - story-implementation                      # bare skill dir name — preloads SKILL.md into the agent
---
```

Tools recipe: start `Read, Glob, Grep`; add `Write, Edit` for file producers; add `Bash` for anyone running commands; add `WebFetch` for external-doc needs. Report-only agents get NO write tools — the toolset enforces the discipline. `model:` is omitted → the agent inherits the session model; the user picks the pipeline's model by picking their session model.

**Skills** (`skills/{name}/SKILL.md`):

```yaml
---
name: {skill-dir-name}
description: "{What discipline this defines}. Used by the {Agent} agent[s]."
---
```

Depth goes to `references/*.md`, loaded on demand via a table:

```
| Topic | Reference | Load when |
|-------|-----------|-----------|
| {topic} | ${CLAUDE_SKILL_DIR}/references/{file}.md | {situation} |
```

## Naming law

Agent = persona ("who would a team hire?" → `Developer`). Skill = discipline ("what activity?" → `story-implementation`). The names MUST differ. Agents may share a skill; an agent may use several.

## Structure of a rule file (what the Architect writes into projects)

```markdown
# {Constraint as a title}

{One-two line rule statement — no preamble.}

## Where this applies
## Where this does NOT apply
## Examples            ← paired Bad / Good blocks
## Enforcement         ← which agent/skill/gate checks this
```

Root-level rules in `.claude/rules/` load unconditionally; rules with `paths:` YAML frontmatter load only when a matching file is read. Directory placement is human organization only — `paths:` is what controls loading.
