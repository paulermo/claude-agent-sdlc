# agent-sdlc

A Claude Code plugin that orchestrates 14 specialized AI agents to drive software projects from requirements to deployment.

## What it does

`agent-sdlc` implements a closed-loop software development lifecycle powered by AI agents. You describe your product, and the pipeline handles planning, architecture, infrastructure, implementation, code review, QA, content creation, and deployment — all through Claude Code.

The plugin is built as three knowledge layers plus an enforcement layer, so results stay consistent across models (it is written to run as well on Opus-class executors as on stronger ones):

| Layer | Where | What it holds |
|-------|-------|---------------|
| **Agents** (who) | `agents/` | compact personas: identity, scope, collaboration, non-negotiables, report contract |
| **Skills** (how) | `skills/` | the workflows — preloaded into each agent via `skills:` frontmatter, with references loaded on demand |
| **Rules** (law) | `.claude/rules/` in your project | project standards, seeded at init, customized by the Architect; auto-loaded and inherited by every agent |
| **Hooks** (enforcement) | `hooks/` | state-file JSON validation after every edit, git discipline guard (no force-push, no `-X theirs`), attribution guard (no `Co-Authored-By`/session trailers in commits and PRs), session state summary |

### Agents

| Agent | Role | Stage |
|-------|------|-------|
| **Project Manager** | Orchestrates: dispatches agents by template briefs, verifies reports, single writer of all state | All |
| **Product Manager** | BRDs, epics, content plans, prioritization | Planning |
| **System Analyst** | Use cases and stories with testable acceptance criteria | Planning |
| **Architect** | Architecture + project rules (incl. the quality gate); reviews infra designs | Planning + Review |
| **Cloud Architect** | Cloud design: services, availability, security, cost | Infrastructure |
| **DevOps Engineer** | CI/CD, Dockerfiles, K8s, Terraform/IaC | Infrastructure |
| **Designer** | UI/UX options with HTML previews and user approval gates | Planning (on demand) |
| **Developer** | Implements stories and bugs (OpenSpec or built-in spec-lite); fast lane: targeted proof, one fix pass, merge fixes, batch fixes, fix loops | Implementation |
| **Reviewer** | Code review with tier-scaled lenses and a round-bounded verdict law (read-only) | Implementation |
| **QA** | Fast lane: the full gate once per batch (locally or on a remote runner); classic lane: E2E by tier + regression after merges | Implementation |
| **Deploy** | Story merges, main-in, feature-in and delivery to `main` with release notes; combination-only conflict resolution; pushes on green | Implementation |
| **Content Creator / Reviewer / Integrator** | Content production pipeline | Content |

### Workflow

```
/agent-sdlc:init   →  Configure project, seed .claude/rules/, install CLAUDE.md block
/agent-sdlc:start  →  PM orchestrator: reads state, dispatches agents, verifies, drives pipeline
/agent-sdlc:status →  Read-only status projection
/agent-sdlc:env    →  Configure deployment environments (consumed by QA and the infra phase)
/agent-sdlc:tracker → Live progress dashboard in the browser (roadmap, milestones, board, backlog, activity)
/agent-sdlc:milestone → Define, edit or list milestones (writes a directive; the PM applies it)
```

**Planning** (sequential): Product Manager → System Analyst → Architect → Designer (if UI signals) → infra phase (if deployment signals): Cloud Architect → DevOps → Architect review loop.

**Implementation** (parallel teammates in git worktrees), on one of two **lanes**, stamped per epic when it starts:

- **Fast lane** (the default for new projects): a story proves itself with a **targeted set** — red test first, the tests of every touched path and every consumer of a changed symbol (found by search), the whole-tree checks the change feeds, static checks on the changed files. It gets **one review round** and at most **one fix pass**, which the PM checks by reading its diff; NOTE-level findings never return a story (they collect in an epic notes file). No per-story QA, no regression per merge. A **batch** (by default the epic) proves itself **once** with the full gate at its **batch end**: `main` merged in first, a batch fix for meeting defects, the full gate (on a remote runner if you have one), a bounded fix loop for red steps, then **one delivery merge** to `main` carrying release notes.
- **Classic lane** (1.x behaviour): Developer → Reviewer → QA → Deploy → regression QA per story, full gate at every step.

Choose with `process.lane` in `docs/state/project.json`; epics already in flight keep their lane.

**Content** (parallel): Creator → Content Reviewer → Integrator → QA.

### How state works (single-writer protocol)

State lives in `docs/state/` and is written **only by the PM orchestrator** on the main working copy. Dispatched agents never touch state — each ends with a structured report envelope (`=== AGENT REPORT ===` with OUTCOME + EVIDENCE); the PM verifies the evidence, applies the transition, appends a line to the transition log, and commits. This is what makes parallel worktree execution safe: state can't fork across branches.

State is sharded so it never outgrows the PM's context (state v2): `epics.json` is a small index, `active.json` holds only the items of epics in flight, `backlog.json` holds not-yet-started work, completed epics move wholesale to `archive/done-YYYY-MM.json`, and per-item history lives in an append-only `log.jsonl` that orchestration writes (via shell append) but never reads. Review/QA feedback is stored as file paths (`docs/reviews/`, `docs/reports/`), not inline text. A normal PM session reads three small files: `project.json`, `epics.json`, `active.json`. Existing projects migrate automatically on `/agent-sdlc:init`.

### State machines

- **Epics:** `planning → ready → in_progress → ready_for_deploy → deployed → done` (+ `frozen` via directive)
- **Stories, classic lane:** `todo → in_progress → ready_for_review → in_review → ready_for_qa → in_qa → ready_for_merge → merged → done`, with `review_rejected` / `qa_rejected` looping back to the Developer and `regression_failed` spawning a bug
- **Stories, fast lane:** `todo → in_progress → ready_for_review → in_review → ready_for_merge → done`, with one `review_rejected` → fix pass → PM diff check
- **Milestones:** `planned → in_progress → delivered → demoed` — a demo the user decides, linked to whole epics; progress shows in `/agent-sdlc:status` and the tracker
- **Bugs:** the same statuses with fewer stages — classic lane by tier (`light`: Developer → merge → regression; `standard`: + one delta review; `critical`: + QA); fast lane: `light` Developer → merge, `standard`/`critical` one review round → merge. A bug has no story file or use case: its record (`docs/issues/{EPIC}/bugs/`) is the spec and a regression test is the acceptance criterion
- **Content tasks:** `todo → creating → ready_for_review → in_review → ready_for_integration → integrating → ready_for_qa → in_qa → ready_for_merge → merged → done`, with rejections routed by `rejection_reason` (content vs integration)

The authoritative definition (transition table, entry schemas, report envelope) is `skills/sdlc-state/SKILL.md`.

### Round economy (tiers, budgets, follow-ups)

Every story carries a **tier** (`light` / `standard` / `critical`, set by the System Analyst from a signal table) that scales the whole downstream: review lenses, whether QA runs at all (light stories skip it), and the **return budget** — how many rework rounds an item may consume (classic 1 / 2 / 3, bugs 1; fast lane 1 at every tier). At the budget the item is parked and the user decides (one more round, accept, park) instead of the pipeline looping. Non-blocking review findings become **follow-ups** (one file per epic, one line per finding class) that Developers close in passing and, at the epic's (fast: the batch's) end, are either swept by one hygiene bug or triaged — carried by ID, dropped, or folded into the batch fix — per `process.followups_gate`; defects reported by QA or Developers become follow-ups or bugs — never stories. Briefs are capped at their template slots, and the PM's verification is a presence check, not a fourth review (the fast lane's diff read of a fix pass replaces a second review round). Design records: `docs/plans/2026-08-25-round-economy-design.md`, `docs/plans/2026-09-29-fast-lane-design.md`.

### Git strategy

- Feature branch per epic (`feature/{EPIC-ID}-{slug}`), story branch per story, worktrees under `.worktrees/` for parallel work, a dedicated `{EPIC-ID}-merge` worktree for merges and feature-branch regression.
- Fast lane: a story that already contains the feature tip is fast-forwarded by the PM; otherwise Deploy merges it and runs whole static analysis on the merged tree. A red merge goes to a `fix/{ITEM}-merge` branch for a merge-fix Developer — never onto the feature, never a bug. At the batch end `main` is merged into the feature, the full gate runs, and one `--no-ff` delivery merge (release notes as the commit message) goes to `main`. Main regression runs per `process.main_regression` (by default only when `main` gained code since the gated merge).
- Classic lane: story → feature → main, full quality gate + regression QA at each step.
- The main checkout always stays on `main` (the tracker reads it); planning agents work in their own worktrees.
- Conflict law: combination only — `-X theirs`/`-X ours` and force pushes are blocked by a hook; attribution trailers are blocked by another, always (no switch; `process.attribution_patterns` only adds patterns).

### Progress tracker

`/agent-sdlc:tracker` opens a local, read-only web dashboard: roadmap with per-epic progress, a kanban board of the work in flight, backlog, a live activity feed from the transition log, and drill-down into any epic/story/task document (reviews and QA reports included). Data refreshes every 2 seconds straight from `docs/state/` — no restarts when the pipeline moves. One server (Python 3 stdlib, port 4680+) serves every registered project on the machine with a project switcher; re-running the command after a plugin update restarts it on the new code automatically. Requires `python3`; stops via `curl -X POST http://127.0.0.1:4680/api/shutdown`.

## Installation

```bash
claude plugin add github.com/paulermo/claude-agent-sdlc
```

## Quick start

1. Install the plugin
2. Open your project in Claude Code
3. `/agent-sdlc:init` — configure the project
4. `/agent-sdlc:start` — launch the pipeline

**Model choice:** agents inherit your session's model by default. Run the session on the model you want the pipeline to use — the harness is written so weaker executors follow the same tracks as stronger ones (template briefs, mechanical severity rules, evidence gates). To save cost on procedural work you may route roles or modes to another model in `process.models`, e.g. `{"default": "inherit", "Deploy": "sonnet", "QA:batch_gate": "sonnet"}`; the smallest tier is never used for roles that quote gate evidence. Caveat: an explicitly named model may run with a smaller context window than your inherited session — keep judgement roles (Architect, Developer, Reviewer, System Analyst, Product Manager) on `inherit`.

**Parallel execution (recommended):** the PM targets 3-5 parallel agents. For full agent-team mode (parallel teammate sessions with a shared panel), enable the experimental Claude Code feature:

```json
// settings.json
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

Two caveats from the Claude Code docs: (1) teammates do NOT inherit the lead's `/model` selection by default — set **Default teammate model** to "leader's model" in `/config` so the whole pipeline runs on your chosen model; (2) a teammate ignores the agent definition's `skills:` preload — the agents handle this themselves by loading their workflow skill via the Skill tool. Without the flag, the PM automatically falls back to background subagents — same briefs, same discipline, no shared panel.

## Upgrading from 1.x

Run `/agent-sdlc:init` once. It adds a `process` block with the **classic preset** (your pipeline behaves exactly as in 1.6), the new counters and an empty milestones list, then asks one question: switch NEW epics to the fast lane? Epics already in flight always finish on their lane. Before the first fast epic starts, the PM has the Architect add the fast-lane sections (§Lanes, §Whole-tree checks, §Per story, §Review and merge, §Batch end) to your `.claude/rules/quality-gate.md`. The attribution ban is mandatory: the hook is active from the plugin upgrade on and cannot be turned off (a `commit_attribution` key in an older `project.json` is ignored); init also writes `.claude/settings.json` attribution settings. Two classic-lane gaps of 1.6 are now defined: a failed main regression and a red epic merge each register one bug and send the epic back to `in_progress` (a red epic merge is reset off local `main` first).

## Optional dependencies

- **[OpenSpec](https://github.com/fission-ai/openspec)** — spec-driven Developer workflow. Without it, the Developer uses the built-in spec-lite path (same rigor, no tooling). Install: `npm install -g @fission-ai/openspec@latest`
- **Remote stack runners** — machines that run heavy test stacks for the batch gate and agents' stacks. The plugin ships the protocol (`skills/sdlc-dispatch/references/runners.md`) and a reference `tooling/runners/run-step.sh`; enable with `integrations.runners` in `project.json`.

## Project structure after init

```
your-project/
├── CLAUDE.md                ← managed agent-sdlc block (routing + state law)
├── .claude/rules/           ← project rules: seeded at init, customized by Architect
│   ├── quality-gate.md      ← the exact verify commands every agent runs
│   ├── architecture.md      ← written by the Architect during planning
│   └── {api,backend,frontend,infra,cross-cutting,authoring,product}/
├── .worktrees/              ← git worktrees for parallel work (gitignored)
├── docs/
│   ├── project.md           ← product description
│   ├── templates/           ← BRD, UC, epic, story, bug, content, notes-file, batch-gate report, delivery commit, demo slice
│   ├── directives/          ← drop files in active/ to steer the PM
│   ├── requirements/        ← BRDs, use cases, content plans
│   ├── issues/              ← epics, stories, content tasks; per epic: bugs/ and followups.md
│   ├── reviews/             ← saved review documents; per epic: {EPIC}-notes.md (fast lane)
│   ├── reports/             ← QA, regression and batch-gate reports; demo slices
│   └── state/               ← pipeline state (PM-only writes)
└── content/                 ← produced content files
```

Re-running `/agent-sdlc:init` on a pre-1.2 project migrates `docs/rules/` → `.claude/rules/`, moves templates to `docs/templates/`, repairs the agent registry, and installs the CLAUDE.md block — state files are never overwritten (the 2.0 repair only adds missing keys and the explicit `parked` marker, see Upgrading from 1.x).

## Extending

See [docs/extending-sdlc.md](docs/extending-sdlc.md) for adding agents (agent + skill + brief template + dispatch mapping), task types, statuses, and integrations. Authoring style for all plugin content is defined in [docs/authoring-standards.md](docs/authoring-standards.md).

## Language/framework agnostic

Works with any tech stack: the Architect writes the project's exact commands into `.claude/rules/quality-gate.md` during planning, and every agent runs those — nothing is hardcoded to a stack.

## License

MIT
