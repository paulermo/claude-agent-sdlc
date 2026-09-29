# Rule Authoring

How to write rules into a target project's `.claude/rules/`. Rules are context Claude loads — specific, concrete rules are followed reliably; vague ones are not.

## How loading works

- **Unconditional rule** — no frontmatter. Loads every session. Use for always-on constraints: architecture, security, the quality gate — and pointers to detail (Rules budget below).
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

`grep -ri "{keyword}" {worktree}/.claude/rules/` — if the topic is covered, update the existing rule. Two rules on one topic make agents pick arbitrarily.

## The two mandatory root rules

**`.claude/rules/architecture.md`** — components + boundaries + allowed-dependency direction + where each kind of code lives. This is the file the Reviewer's Placement lens and the infra agents' designs hang off.

**`.claude/rules/quality-gate.md`** — the project's exact verification commands, in the structure of the seed `${CLAUDE_PLUGIN_ROOT}/templates/rules/quality-gate.md` (§Lanes, §How the full gate runs, Step 0, the path-to-command table, §Whole-tree checks, §Per story, §Review and merge, §Batch end, §Enforcement). The seed is the one definition of that structure; what Design Mode must fill, the placeholder check and the gate upgrade are in SKILL.md Design Mode step 4.

Redundant enforcement is the point: four agents cite ONE definition — update it here and everyone's gate changes together.

## Rules budget

Every always-loaded rule is paid for by every agent session before it reads a single file; a path-scoped rule by every session that reads a matching file. WHY: on one project a single module path loaded ~1 MB of rules (~270K tokens) before an agent read anything, and nine Developer sessions died of context overflow in two days.

- **Always-loaded** (root-level, no `paths:`) holds only pointers ("API error format: `.claude/rules/api/errors.md`") and the few rules every agent needs in every session — `architecture.md`, `quality-gate.md`, security never-do lines.
- **Detail** — examples, per-layer conventions, long tables — lives once, in a `paths:`-scoped file whose globs match only the code it governs. A glob matching nearly every file (`**`, `**/*`, `src/**` in a one-module repo) is always-loaded in effect: narrow it.
- One glob per list line, no `{a,b}` braces and no inline `paths: [...]` — the measuring command below cannot expand them.

Measure at the end of every Design Mode run and Init Rules Session, and after any change that adds text to an always-loaded file. Run it in your worktree (`cd {worktree} &&` — your shell starts in the main checkout); the sample is a tracked source file in the module a typical story touches (`git -C {worktree} ls-files --error-unmatch {path}` exits 0):

```bash
cd {worktree} && bash -s -- '{sample path}' <<'EOF'
sample=$1; always=0; scoped=0
while IFS= read -r f; do
  size=$(wc -c < "$f"); fm=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1' "$f")
  if ! printf '%s\n' "$fm" | grep -q '^paths:'; then always=$((always+size)); echo "always      $size $f"; continue; fi
  printf '%s\n' "$fm" | grep -qE '^paths:[[:space:]]*[^[:space:]]' && echo "check by hand (inline paths:) $f"
  globs=$(printf '%s\n' "$fm" | sed -n 's/^[[:space:]]*-[[:space:]]*//p' | tr -d "\"'")
  printf '%s\n' "$globs" | grep -qF '{' && echo "check by hand (brace glob) $f"
  hit=no
  while IFS= read -r g; do [ -n "$g" ] && git ls-files -- ":(glob)$g" | grep -qxF "$sample" && hit=yes; done <<< "$globs"
  if [ "$hit" = yes ]; then scoped=$((scoped+size)); echo "scoped      $size $f"; else echo "not loaded  $size $f"; fi
done < <(find -L .claude/rules -name '*.md' | sort)
echo "always-loaded: $always bytes; with $sample: $((always+scoped)) bytes"
EOF
```

The last line is the result (report it as EVIDENCE `rules budget:`); the lines above name each file, whether it loads for the sample, and its bytes. A `check by hand` line: decide by reading that file's `paths:` whether it loads for the sample, and add its bytes yourself. Keep the always-loaded total under ~60,000 bytes. *Default, not law: deviate only on concrete grounds, and record the rationale in the report's DETAILS.* Over it → move detail out of always-loaded files into `paths:`-scoped ones, leave a pointer, measure again.

## ADR skeleton (Ruling mode)

Every section, in this order; fill every brace. Location, numbering and amendments: SKILL.md Ruling mode step 3a.

```markdown
# ADR-{NNNN}: {the decision, as a title}
Status: accepted {YYYY-MM-DD} — ruling for {ITEM-ID}
## Context
{the question in one sentence; how it arose (a review note, a BLOCKED report); what builds on it}
## Options
- ({letter}) {option, one line per option posed, plus yours} — {accept | reject}: {the rule, ADR or constraint it meets or breaks; its cost}
## Decision
({letter}) {the ruling in two sentences}
## Consequences
- Rules: {rule files changed}
- Builds it: {ITEM-ID | needs a new story: {scope, one line} | none — rule only}
- Meanwhile: {what the waiting item does}
```
