# Extending the SDLC Agent Pipeline

How to extend the pipeline with new agents, task types, statuses, and integrations. Write everything you add in the style of [authoring-standards.md](authoring-standards.md) — the pipeline's consistency across models depends on it.

## The three-layer contract

Every capability in the pipeline is split across:

1. **Agent** (`agents/{name}.md`) — the persona: identity, scope (owns / does not own), non-negotiables, report OUTCOME values. Compact; no workflows here.
2. **Skill** (`skills/{skill-name}/SKILL.md`) — the workflow: numbered steps, exact commands, decision tables, report envelope, MUST/MUST NOT. Depth goes to `references/*.md`.
3. **Wiring** — the PM must know when to dispatch it and what to say: a row in `commands/start.md`'s dispatch map + a brief template in `skills/sdlc-dispatch/references/briefs.md`.

Naming law: agent = persona (`Developer`), skill = discipline (`story-implementation`); the names MUST differ.

## Adding a new agent

1. **Create the skill** `skills/{discipline}/SKILL.md` with: frontmatter (`name`, `description`), the workflow, the report envelope with role-specific OUTCOME values, MUST DO / MUST NOT DO (always including "Never edit `docs/state/*.json`").
2. **Create the agent** `agents/{name}.md`:
   ```yaml
   ---
   name: "{Agent Name}"
   description: "{Verb-led capability}. Invoke when {triggers}. Do NOT invoke for {anti-triggers}."
   tools: Read, Glob, Grep[, Write, Edit][, Bash][, WebFetch]   # minimal set; report-only agents get no Write/Edit
   skills:
     - {discipline}
   ---
   ```
   Body: identity (2-3 lines) → How to operate (skill pointer + brief + rules glob) → Scope → Non-negotiables → Output (report envelope pointer).
3. **Register** in `commands/init.md`'s project.json registry template (`"{agent-key}": { "file": "...", "stage": "...", "type": "subagent|teammate" }`) — and tell existing projects to re-run `/agent-sdlc:init` (it merges missing registry entries).
4. **Wire the PM**: add the dispatch-map row(s) in `commands/start.md` (status → agent → status-to-set), the agent name row in `skills/sdlc-dispatch/SKILL.md`, and a brief template in `skills/sdlc-dispatch/references/briefs.md` with the five mandatory sections (WHY / INPUTS / DISCIPLINE / DELIVERABLE / VERIFICATION).

## Adding a new task type

1. Choose an ID scheme: `{PREFIX}-{TYPE}-{N}`, a counter in `project.json.counters`, a branch convention `{type}/{ID}-{slug}`.
2. Create `docs/state/{type}-tasks.json` (seed `{}` in init.md) and define the entry schema in `skills/sdlc-state/SKILL.md` §5 — that file is the single source of truth for shapes.
3. Define the status machine in `skills/sdlc-state/SKILL.md` §3 and its transitions in §4 (who dispatches, which OUTCOME moves it where).
4. Add dispatch-map rows in `commands/start.md` and brief templates for the handling agents.

## Adding or changing statuses

All status/state changes happen in ONE file first: `skills/sdlc-state/SKILL.md` (machine, transition table, schema). Then propagate: the dispatch map in `commands/start.md`, the next-action map in `commands/status.md`, the affected agents' skills (their entry/exit slice), and the README state-machine section. Grep for the old status name across the repo before finishing — a stale status string in any file will desynchronize a weaker executor.

## Adding an integration

1. Add config under `project.json.integrations`:
   ```json
   "integrations": { "your_integration": { "type": "notifications | issue_tracker | ci_cd | custom", "config": {} } }
   ```
2. Give the behavior a home: PM-side behaviors (notify on transition, sync tickets) go into `commands/start.md` as an explicit step with exact conditions; agent-side behaviors go into the relevant skill.
3. Typical integrations: Slack/Telegram notifications on transitions, Jira/Linear sync, CI/CD triggers after merges, MCP servers for external tools.

## Rules and templates

- Base rules seeded into projects live in `templates/rules/` (plugin) → `.claude/rules/` (project). Follow the rule skeleton from `skills/architecture-design/references/rule-authoring.md`.
- Document templates live in `templates/` (plugin) → `docs/templates/` (project).
