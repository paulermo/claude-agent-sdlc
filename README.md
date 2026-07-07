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
| **Hooks** (enforcement) | `hooks/` | state-file JSON validation after every edit, git discipline guard (no force-push, no `-X theirs`), session state summary |

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
| **Developer** | Implements stories (OpenSpec or built-in spec-lite workflow) | Implementation |
| **Reviewer** | Code review with mechanical severity discipline (read-only) | Implementation |
| **QA** | E2E testing + full-suite regression after merges | Implementation |
| **Deploy** | Merges with combination-only conflict resolution | Implementation |
| **Content Creator / Reviewer / Integrator** | Content production pipeline | Content |

### Workflow

```
/agent-sdlc:init   →  Configure project, seed .claude/rules/, install CLAUDE.md block
/agent-sdlc:start  →  PM orchestrator: reads state, dispatches agents, verifies, drives pipeline
/agent-sdlc:status →  Read-only status projection
/agent-sdlc:env    →  Configure deployment environments (consumed by QA and the infra phase)
```

**Planning** (sequential): Product Manager → System Analyst → Architect → Designer (if UI signals) → infra phase (if deployment signals): Cloud Architect → DevOps → Architect review loop.

**Implementation** (parallel teammates in git worktrees): Developer → Reviewer → QA → Deploy → regression QA, driven by a status dispatch map.

**Content** (parallel): Creator → Content Reviewer → Integrator → QA.

### How state works (single-writer protocol)

State lives in `docs/state/*.json` and is written **only by the PM orchestrator** on the main working copy. Dispatched agents never touch state — each ends with a structured report envelope (`=== AGENT REPORT ===` with OUTCOME + EVIDENCE); the PM verifies the evidence, applies the transition with a history entry, and commits. This is what makes parallel worktree execution safe: state can't fork across branches.

### State machines

- **Epics:** `planning → ready → in_progress → ready_for_deploy → deployed → done` (+ `frozen` via directive)
- **Stories:** `todo → in_progress → ready_for_review → in_review → ready_for_qa → in_qa → ready_for_merge → merged → done`, with `review_rejected` / `qa_rejected` looping back to the Developer and `regression_failed` spawning a bug-story
- **Content tasks:** `todo → creating → ready_for_review → in_review → ready_for_integration → integrating → ready_for_qa → in_qa → ready_for_merge → merged → done`, with rejections routed by `rejection_reason` (content vs integration)

The authoritative definition (transition table, entry schemas, report envelope) is `skills/sdlc-state/SKILL.md`.

### Git strategy

- Feature branch per epic (`feature/{EPIC-ID}-{slug}`), story branch per story, worktrees under `.worktrees/` for parallel work, a dedicated `{EPIC-ID}-merge` worktree for merges and feature-branch regression.
- Merge flow: story → feature → main, full quality gate + regression QA at each step.
- Conflict law: combination only — `-X theirs`/`-X ours` and force pushes are blocked by a hook.

## Installation

```bash
claude plugin add github.com/paulermo/claude-agent-sdlc
```

## Quick start

1. Install the plugin
2. Open your project in Claude Code
3. `/agent-sdlc:init` — configure the project
4. `/agent-sdlc:start` — launch the pipeline

**Model choice:** agents inherit your session's model. Run the session on the model you want the pipeline to use — the harness is written so weaker executors follow the same tracks as stronger ones (template briefs, mechanical severity rules, evidence gates).

## Optional dependencies

- **[OpenSpec](https://github.com/fission-ai/openspec)** — spec-driven Developer workflow. Without it, the Developer uses the built-in spec-lite path (same rigor, no tooling). Install: `npm install -g @fission-ai/openspec@latest`

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
│   ├── templates/           ← BRD, UC, epic, story, content templates
│   ├── directives/          ← drop files in active/ to steer the PM
│   ├── requirements/        ← BRDs, use cases, content plans
│   ├── issues/              ← epics, stories, content tasks
│   ├── reviews/             ← saved review documents
│   └── state/               ← pipeline state (PM-only writes)
└── content/                 ← produced content files
```

Re-running `/agent-sdlc:init` on a pre-1.2 project migrates `docs/rules/` → `.claude/rules/`, moves templates to `docs/templates/`, repairs the agent registry, and installs the CLAUDE.md block — state files are never touched.

## Extending

See [docs/extending-sdlc.md](docs/extending-sdlc.md) for adding agents (agent + skill + brief template + dispatch mapping), task types, statuses, and integrations. Authoring style for all plugin content is defined in [docs/authoring-standards.md](docs/authoring-standards.md).

## Language/framework agnostic

Works with any tech stack: the Architect writes the project's exact commands into `.claude/rules/quality-gate.md` during planning, and every agent runs those — nothing is hardcoded to a stack.

## License

MIT
