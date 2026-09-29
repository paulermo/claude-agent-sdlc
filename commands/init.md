---
name: "agent-sdlc:init"
description: "Initialize SDLC agent pipeline in the current project"
---

Initialize (or migrate) the SDLC agent pipeline for this project. Idempotent: safe to re-run on an already-initialized project — it repairs the registry, migrates legacy layouts, and never overwrites existing state.

## Phase 0: Prerequisites

0.1. **Git repository:**
```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```
If not a repo: `git init && git add -A && git commit -m "Initial commit"`.

0.2. **OpenSpec (optional):**
```bash
openspec --version 2>/dev/null
```
- Not installed → inform (don't block): "OpenSpec not installed. The Developer will use the built-in spec-lite workflow. For OpenSpec: `npm install -g @fission-ai/openspec@latest`."
- Installed but `openspec/` missing → `openspec init --tools claude`.

0.3. **Existing installation check:** if `docs/state/project.json` exists, this is a MIGRATION run — skip Phase 1 questions (keep existing config), run Phases 2-4 only for the pieces that are missing or legacy (they are all idempotent). A project without a `process` key in `project.json` also gets the v2.0 repair (2.5c).

## Phase 1: Project configuration (new installs only)

Ask via AskUserQuestion, one at a time:
1. Project prefix (2-5 uppercase letters, e.g. KRT). Validate; re-ask if invalid.
2. Project name.
3. Product description (text, or a file path to read).
4. Environments (comma-separated, e.g. `dev,staging,prod`).
5. Lane for new epics: "fast (Recommended) — one targeted proof per story, the full gate once per batch" / "classic — the full gate on every story and merge". Suggest `classic` when the user says the project's full gate runs in under ~2 minutes. Default `fast`. (What a lane is: `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-state/SKILL.md` section 4, Lanes.)
6. Shell the agents run in — default from `basename "$SHELL"` (anything but `zsh` → `bash`); accept `zsh` or `bash`.
7. Content guard (optional): "Does the project have a command that scans for banned terms or content (run on every change)?" → its exact command, and whether to install it as a git pre-commit hook; "no" → `null`.
8. Remote stack runners (optional): "Will tests run on remote runner machines?" → yes sets `integrations.runners.enabled: true` (the runner inventory and tooling dir are filled later by the user; protocol: `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/runners.md`).

## Phase 2: Structure & state

2.1. **Directories** (create only what's missing):

```
.worktrees/
docs/project.md                    ← the product description (new installs)
docs/directives/active/  docs/directives/archive/
docs/templates/                    ← document templates
docs/requirements/  docs/requirements/content-plan/
docs/issues/  docs/reviews/  docs/reports/
docs/state/  docs/state/archive/
content/
.claude/rules/                     ← project rules (auto-loaded by Claude Code, inherited by agents)
```

2.2. **Copy document templates** from the plugin: `${CLAUDE_PLUGIN_ROOT}/templates/*.md` → `docs/templates/` (brd, epic, story, use-case, bug, content-plan, content-task, notes-file, batch-gate-report, delivery-commit, demo-slice). Do not overwrite existing files (migration runs add the missing ones — notably `bug-template.md` and the four 2.0 templates).

2.3. **Seed base rules** from `${CLAUDE_PLUGIN_ROOT}/templates/rules/` → `.claude/rules/`, preserving subdirectories (`api/`, `backend/`, `frontend/`, `infra/`, `cross-cutting/`, `authoring/`, `product/`, and root files). Do not overwrite existing files. These are strong generic defaults — **the Architect customizes them for the stack during planning** (that is a pipeline step, not an init step).

2.4. **Legacy migration** — if `docs/rules/` exists (pre-1.2 layout):
- `git mv docs/rules/templates/* docs/templates/` (document templates)
- `git mv` everything else from `docs/rules/` into `.claude/rules/`, preserving subdirectories; on name collision keep the `.claude/rules/` version and report the skipped file.
- Remove the now-empty `docs/rules/`.

2.5. **State files** (create ONLY if missing — never overwrite):

`docs/state/project.json`:
```json
{
  "prefix": "{USER_PREFIX}",
  "name": "{PROJECT_NAME}",
  "state_version": 2,
  "phase": "not_started",
  "_note_phase": "Cached pipeline phase: not_started | planning | implementation | done. Recomputed by start/status; agent registry 'stage' labels below are a different, informational grouping.",
  "max_parallel_teammates": 4,
  "_note_parallelism": "Target 3-5 parallel agents when independent items allow; this is the cap on WORKING teammates — user-adjustable. Local Docker stacks have their own cap: process.max_local_stacks.",
  "worktree_dir": ".worktrees",
  "worktrees": {},
  "counters": { "brd": 0, "uc": 0, "epic": 0, "story": 0, "bug": 0, "note": 0, "followup": 0, "milestone": 0, "cp": 0, "cepic": 0, "ctask": 0 },
  "process": {
    "lane": "{fast | classic — answer 5}",
    "main_regression": "if_main_gained_code",
    "docs_only_paths": ["docs/", ".claude/"],
    "followups_gate": "triage",
    "demo_gate": "on_request",
    "planning_depth": "just_in_time",
    "deploy_push": "on_green",
    "deploy_exclusivity": "per_target_branch",
    "max_local_stacks": 2,
    "report_max_chars": 3500,
    "attribution_patterns": [],
    "commit_conventions": null,
    "shell": "{zsh | bash — answer 6}",
    "models": { "default": "inherit" },
    "standing_brief_lines": { "all": [] },
    "content_guard": null
  },
  "agents": {
    "pm":                 { "file": "pm.md",                 "stage": "all",            "type": "lead" },
    "product":            { "file": "product.md",            "stage": "planning",       "type": "subagent" },
    "analyst":            { "file": "analyst.md",            "stage": "planning",       "type": "subagent" },
    "architect":          { "file": "architect.md",          "stage": "planning",       "type": "subagent" },
    "designer":           { "file": "designer.md",           "stage": "on_demand",      "type": "subagent" },
    "cloud-architect":    { "file": "cloud-architect.md",    "stage": "infrastructure", "type": "subagent" },
    "devops-engineer":    { "file": "devops-engineer.md",    "stage": "infrastructure", "type": "subagent" },
    "developer":          { "file": "developer.md",          "stage": "implementation", "type": "teammate" },
    "reviewer":           { "file": "reviewer.md",           "stage": "implementation", "type": "teammate" },
    "qa":                 { "file": "qa.md",                 "stage": "implementation", "type": "teammate" },
    "deploy":             { "file": "deploy.md",             "stage": "implementation", "type": "subagent" },
    "content-creator":    { "file": "content-creator.md",    "stage": "content",        "type": "teammate" },
    "content-reviewer":   { "file": "content-reviewer.md",   "stage": "content",        "type": "teammate" },
    "content-integrator": { "file": "content-integrator.md", "stage": "content",        "type": "teammate" }
  },
  "integrations": { "notifications": null, "issue_tracker": null, "ci_cd": null, "runners": { "enabled": false, "tooling_dir": null, "inventory": null } }
}
```
(The `process` block above is the **fast preset** of sdlc-state section 6 — keep every value except `lane` and `shell`, which come from answers 5 and 6. If the user chose `classic` in answer 5, write the **classic preset** instead — the JSON of step 2.5c.5 below, verbatim — so no fast-lane-only value (`if_main_gained_code`, `triage`, `on_request`, `just_in_time`, `on_green`, `per_target_branch`) runs on a classic project. `content_guard` from answer 7: `{"command": "{cmd}", "pre_commit": true | false}` or `null`. `integrations.runners.enabled` from answer 8.)

(Migration runs: merge missing agent entries into the existing registry — notably `deploy` —, add missing counters — notably `"bug": 0` —, and rename the legacy `phase` key of registry entries to `stage`. Leave everything else untouched. Item entries need no migration: absent `kind` / `tier` / `returns` read as `story` / `standard` / `0` per sdlc-state. The `process` block and the 2.0 counters are added by 2.5c, never by this template.)

`docs/state/epics.json`: `{ "priority_order": [], "epics": {}, "milestones": {}, "milestone_order": [] }` · `active.json`: `{ "stories": {}, "content_tasks": {} }` · `backlog.json`: `{ "stories": {}, "content_tasks": {} }` · `log.jsonl`: empty file (`touch`) · `.secrets.json`: `{}`
`docs/state/environments.json` from the user's list: `{ "environments": { "{env}": { "url": null, "configured": false } } }`
(Environments are managed by `/agent-sdlc:env`; QA uses a configured env's URL for E2E against deployed targets.)

2.5b. **State migration v1 → v2** — run when `docs/state/stories.json` or `docs/state/content-tasks.json` exists, or `project.json` lacks `"state_version": 2`. Order is fixed (destination first at every step):

1. Create the v2 files from 2.5 that are missing (`active.json`, `backlog.json`, `log.jsonl`, `archive/`).
2. **Histories → log.jsonl.** Emit one line per history entry from all three legacy sources, sorted by `.at`, and append:
   ```bash
   { jq -r 'to_entries[] | .key as $id | .value.history[]? | {item:$id} + .|@json' docs/state/stories.json 2>/dev/null;
     jq -r 'to_entries[] | .key as $id | .value.history[]? | {item:$id} + .|@json' docs/state/content-tasks.json 2>/dev/null;
     jq -r '.epics|to_entries[] | .key as $id | .value.history[]? | {item:$id} + .|@json' docs/state/epics.json 2>/dev/null;
   } | jq -s 'sort_by(.at)[] | @json' -r >> docs/state/log.jsonl
   ```
   (If a history entry has extra fields like `note`, keep them — log lines tolerate extra keys.)
3. **Feedback texts → files.** For every entry whose `review_feedback`/`qa_feedback`/`regression_feedback` is non-null and does not start with `docs/`: write the text to `docs/reports/{ITEM-ID}-migrated-{field}.md`, replace the field with that path.
4. **Bucket the entries** per the sdlc-state bucket law (the epic's status decides): items of `planning`/`ready`/`frozen` epics → `backlog.json`, items of in-flight epics → `active.json`, `done` epics + their items → `archive/done-{current YYYY-MM}.json`. **Promotion exception:** if a `ready` epic has ANY item whose status is not `todo`, the epic was in flight all along (v1 histories never set epics `in_progress`) — set its status to `in_progress` in `epics.json`, log that transition line, and bucket its items into `active.json`. Strip the `history` key from every migrated entry and from epic entries; drop archived epics from `epics.json` and `priority_order`.
5. Delete `docs/state/stories.json` and `docs/state/content-tasks.json`; set `"state_version": 2` in `project.json`.
6. Verify: every ID from the legacy files appears in exactly one v2 file (`jq` count comparison); only then commit — `{PREFIX}: Migrate state to sharded layout (state v2) [by PM]`.

2.5c. **Repair to v2.0** — run when `project.json` has no `process` key (a project initialized before 2.0). Order is fixed; every edit is additive:

1. Counters: add `"note": 0`, `"milestone": 0`, and `"followup"` = the highest follow-up number already used in the project, so new `FU-{n}` numbers never collide with per-epic ones:
   ```bash
   find docs/issues -name followups.md -exec cat {} + 2>/dev/null | grep -oE 'FU-[0-9]+' | sed 's/FU-//' | sort -n | tail -1
   ```
   Empty output → `0`.
2. `integrations.runners`: add `{"enabled": false, "tooling_dir": null, "inventory": null}` if missing.
3. `epics.json`: add `"milestones": {}` and `"milestone_order": []` if missing. Epic entries are NOT touched — an epic without a `lane` stamp is `classic` (sdlc-state section 4, Lanes).
4. Parked items: 1.x marked parking by a formula; 2.0 needs the explicit field (sdlc-state section 4). For every entry in `active.json` / `backlog.json` `stories` and `content_tasks` with status `review_rejected` or `qa_rejected` and `returns` ≥ its 1.x budget (bugs 1; light 1, standard 2, critical 3 — absent tier = standard), add `"parked": true` — conservative: the budget gate's "one more round" frees one that was only owed its last rework. List them in the repair summary.
5. Write the `process` block LAST — only after steps 1–4 succeeded — so a run interrupted earlier repeats every step next time (each step adds only what is missing). The classic preset, verbatim (`shell` from `basename "$SHELL"`; anything but `zsh` → `bash`):
   ```json
   "process": {
     "lane": "classic",
     "main_regression": "always",
     "docs_only_paths": ["docs/", ".claude/"],
     "followups_gate": "hygiene_bug",
     "demo_gate": "blocking",
     "planning_depth": "all",
     "deploy_push": "never",
     "deploy_exclusivity": "per_epic",
     "max_local_stacks": 2,
     "report_max_chars": 3500,
     "attribution_patterns": [],
     "commit_conventions": null,
     "shell": "{zsh | bash}",
     "models": { "default": "inherit" },
     "standing_brief_lines": { "all": [] },
     "content_guard": null
   }
   ```
   With it, every epic behaves exactly as under 1.6.
6. Verify every file you edited parses (`jq empty docs/state/project.json docs/state/epics.json docs/state/active.json docs/state/backlog.json`), then ask once:

   > ## agent-sdlc 2.0 — lanes
   > This project now runs on the **classic lane** — exactly the 1.6 pipeline. The **fast lane** proves each story with a targeted set of checks and one review round, and runs the full gate once per batch (usually an epic) before delivering to `main`. Epics already in flight always finish on classic.
   > Switch NEW epics to the fast lane? ("fast" / "classic")

   **>>> GATE: user response required. Make NO tool calls in the same message as this question. <<<**
   Acceptable answers: "fast", "classic". Anything else is a question — answer it and gate again. On "fast": set `process.lane` to `fast` and tell the user that the project's `.claude/rules/quality-gate.md` needs the fast-lane sections (§Whole-tree checks, §Per story, §Review and merge, §Batch end — see `${CLAUDE_PLUGIN_ROOT}/templates/rules/quality-gate.md`) before the first fast epic starts; `/agent-sdlc:start` dispatches the Architect for that automatically. The other keys of the classic preset stay — the user may change any of them in `project.json` later.
7. Commit: `git add -- docs/state && git commit -m "{PREFIX}: Repair state for agent-sdlc 2.0 [by PM]" -- docs/state`.

2.6. **Verify the quality gate seed** — after step 2.3, confirm `.claude/rules/quality-gate.md` exists (it ships in the base rules as a placeholder table the Architect fills during planning). If it is missing, copy it explicitly from `${CLAUDE_PLUGIN_ROOT}/templates/rules/quality-gate.md`.

2.7. **`.gitignore`** — append if missing:
```
docs/state/.secrets.json
.worktrees/
```

2.7b. **Attribution settings** — always (the ban is mandatory in every agent-sdlc project, sdlc-state section 6): merge into the project's `.claude/settings.json` (create it with `{}` if absent; never overwrite other keys):
```json
{ "attribution": { "commit": "", "pr": "" } }
```
Merge with `f=.claude/settings.json; [ -f "$f" ] || echo '{}' > "$f"; jq '.attribution = ((.attribution // {}) + {"commit": "", "pr": ""})' "$f" > "$f.tmp" && mv "$f.tmp" "$f"`. Empty strings turn off Claude Code's own commit trailer and PR attribution line (`includeCoAuthoredBy` is the deprecated spelling — do not add it). This is the first line of defence; the plugin's `guard-commit.sh` hook denies any trailer that still appears, and the PM's verification checks agent commits (sdlc-dispatch section 3).

2.7c. **Content-guard pre-commit hook** — only when `process.content_guard.pre_commit` is `true`: if `.git/hooks/pre-commit` does not exist, write it and `chmod +x` it:
```bash
#!/bin/sh
# agent-sdlc: run the project's content guard on every commit (process.content_guard)
{content_guard.command}
```
If a pre-commit hook already exists, do NOT overwrite it — show the user the one line to add to it. Worktrees share `.git/hooks`, so every agent's commits run it too.

2.8. **CLAUDE.md managed block** — create `CLAUDE.md` if absent; then insert or replace the block between the markers (idempotent — replace existing block content on re-run):

```markdown
<!-- agent-sdlc:begin -->
## SDLC pipeline (agent-sdlc)

This project is driven by the agent-sdlc pipeline.

- **State** lives in `docs/state/` and is written ONLY by the PM orchestrator
  (`/agent-sdlc:start`). Dispatched agents never edit state — they end with a report
  envelope and the PM applies transitions. Do not hand-edit state; use directives
  (`docs/directives/active/`) to request changes.
- **Rules** in `.claude/rules/` are law for all code work; `quality-gate.md` defines
  the exact verification commands every agent runs.
- **The orchestrator never writes code** — every change goes through the owning agent
  (Developer/Content roles). Fast lane: then one Reviewer round, then Deploy; the full
  gate runs once per batch before delivery to `main`. Classic lane: then Reviewer, then
  QA, then Deploy.
- **No attribution trailers** in commits or PRs — ever; a hook denies them and
  there is no switch to turn it off.
- **Documents**: templates in `docs/templates/`, requirements in `docs/requirements/`,
  epics/stories/bugs/follow-ups in `docs/issues/`, reviews in `docs/reviews/`, QA reports in `docs/reports/`.
- `/agent-sdlc:status` — where things stand; `/agent-sdlc:start` — continue the pipeline;
  `/agent-sdlc:milestone` — define or list milestones (writes a directive, never state).
<!-- agent-sdlc:end -->
```

2.9. **Commit** (by path — sdlc-state section 1): `git add -A -- docs content .claude/rules .claude/settings.json .gitignore CLAUDE.md` then `git commit -m "{PREFIX}: Initialize SDLC project structure [by PM]" -- docs content .claude/rules .claude/settings.json .gitignore CLAUDE.md` (never `.claude/settings.local.json` — it is the user's machine-local file) (migration runs: `"{PREFIX}: Migrate SDLC layout [by PM]"`; the state v2 migration from 2.5b commits separately per its step 6).

## Phase 3: Rules session with the Architect (interactive)

3.1. Ask via AskUserQuestion: "Configure the project rules now, together with the Architect (recommended), or skip — the Architect will then customize them autonomously during planning?" Options: "Configure now (Recommended)" / "Skip".

3.2. If **Configure now**: dispatch `agent-sdlc:Architect` as a FOREGROUND subagent (the user talks to it directly) with the "Architect — Init Rules Session" brief from `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/briefs/planning.md`. The Architect follows its skill's Init Rules Session procedure: present the full picture (stack, rule customizations, quality-gate commands, open questions) → "What would you adjust?" gate → apply agreed changes → commit. Verify its report (RULES_CONFIGURED) and that the commit exists.

3.3. If **Skip**: note it for the summary — rules stay as seeded; the Architect customizes them in Design Mode during planning.

## Phase 4: Push & summary

4.1. Push if a remote exists (`git remote -v`); otherwise say: "No git remote configured. Add one with `git remote add origin <url>` and push when ready."

4.2. Output summary:

> SDLC initialized for {NAME} ({PREFIX}).
>
> - docs/project.md — product description
> - docs/state/ — pipeline state (single writer: the PM orchestrator)
> - .claude/rules/ — project rules, auto-loaded and inherited by every agent; quality-gate.md seeded for the Architect to fill
> - docs/templates/ — document templates (BRD, UC, epic, story, bug, content, notes file, batch-gate report, delivery commit, demo slice)
> - CLAUDE.md — SDLC block installed
> - Hooks active: state-file JSON validation, git discipline guard, attribution guard (mandatory — `process.attribution_patterns` can only add patterns), session state summary
> - Lane for new epics: {fast | classic} — `process` in `docs/state/project.json` holds every pipeline setting
>
> 14 agents registered. Rules: {configured with you in the Architect session | seeded — the Architect will customize them during planning}.
> Next: `/agent-sdlc:start` to begin (planning runs Product Manager → System Analyst → Architect).
