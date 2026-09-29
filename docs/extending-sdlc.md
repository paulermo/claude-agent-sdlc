# Extending the SDLC Agent Pipeline

How to extend the pipeline with new agents, task types, statuses, and integrations. Write everything you add in the style of [authoring-standards.md](authoring-standards.md) — the pipeline's consistency across models depends on it.

## The three-layer contract

Every capability in the pipeline is split across:

1. **Agent** (`agents/{name}.md`) — the persona: identity, scope (owns / does not own), non-negotiables, report OUTCOME values. Compact; no workflows here.
2. **Skill** (`skills/{skill-name}/SKILL.md`) — the workflow: numbered steps, exact commands, decision tables, report envelope, MUST/MUST NOT. Depth goes to `references/*.md`.
3. **Wiring** — the PM must know when to dispatch it and what to say: a row in `commands/start.md`'s dispatch map + a brief template in the role's file under `skills/sdlc-dispatch/references/briefs/` (one file per role; a new role gets its own file and a row in sdlc-dispatch section 1).

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
4. **Wire the PM**: add the dispatch-map row(s) in `commands/start.md` (lane → status → agent → status-to-set), the agent name + brief file + model key row in `skills/sdlc-dispatch/SKILL.md` section 1, and a brief template in `skills/sdlc-dispatch/references/briefs/{role}.md` using the slot order of sdlc-dispatch section 1 (WHY · KIND/TIER/ROUND with `LANE:` · WORKTREE · CARRIED IN · INPUTS · SELECTION/CHECKS · STACK · DISCIPLINE ending in `{standing lines}` · DELIVERABLE · VERIFICATION · REPORT with `{cap}`).

## Adding a new task type

A kind that shares the story machine — like `bug` — is NOT a new task type: it is a `kind` value on entries in the `stories` map, plus its rows in the tier table and the transition table of `skills/sdlc-state/SKILL.md`, a brief template, and dispatch-map rows. Reach for a new type only when the status machine itself differs.

1. Choose an ID scheme: `{PREFIX}-{TYPE}-{N}`, a counter in `project.json.counters`, a branch convention `{type}/{ID}-{slug}`.
2. Create `docs/state/{type}-tasks.json` (seed `{}` in init.md) and define the entry schema in `skills/sdlc-state/SKILL.md` §5 — that file is the single source of truth for shapes.
3. Define the status machine in `skills/sdlc-state/SKILL.md` §3 and its transitions in §4 (who dispatches, which OUTCOME moves it where).
4. Add dispatch-map rows in `commands/start.md` and brief templates for the handling agents.

## Adding a lane-dependent rule

The fast and classic lanes differ in exactly the rows of the lane table in `skills/sdlc-state/SKILL.md` section 4 (Lanes). A new behaviour that depends on the lane is a new row there first; then a `Lane` value on the affected transition rows (section 5) and dispatch-map rows (`commands/start.md`); then the skills cite the lane table instead of restating the condition. A behaviour that should be configurable independently of the lane is a `process` key instead: add it to the schema table in sdlc-state section 6 with its fast-preset and classic-preset values (absent keys read as the classic preset), to `commands/init.md`'s template, and to its readers.

## Adding a procedure the PM runs occasionally

Long, situational PM procedures (the batch end, rulings, milestones, recovery) live in `skills/sdlc-dispatch/references/{name}.md` and are listed in sdlc-dispatch section 0's "Load when" table — never inline in `commands/start.md`, which the PM carries in every session. `start.md` keeps a one-paragraph pointer.

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
