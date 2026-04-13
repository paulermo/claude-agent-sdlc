# agent-sdlc

A Claude Code plugin that orchestrates 14 specialized AI agents to drive software projects from requirements to deployment.

## What it does

`agent-sdlc` implements a closed-loop software development lifecycle powered by AI agents. You describe your product, and the pipeline handles planning, architecture, infrastructure, implementation, code review, QA, content creation, and deployment — all through Claude Code.

### Agents

| Agent | Role | Phase |
|-------|------|-------|
| **Project Manager** | Orchestrates the pipeline, dispatches agents, manages state | All |
| **Product Manager** | Creates BRDs, epics, content plans from product description | Planning |
| **System Analyst** | Breaks epics into stories and use cases | Planning |
| **Architect** | Designs architecture, creates rules, reviews infra designs | Planning + Review |
| **Cloud Architect** | Designs cloud infrastructure (AWS/Azure/GCP), security, cost | Infrastructure |
| **DevOps Engineer** | CI/CD pipelines, Dockerfiles, K8s, Terraform/IaC | Infrastructure |
| **Designer** | UI/UX design with interactive user options | Planning (on demand) |
| **Developer** | Implements stories via OpenSpec workflow | Implementation |
| **Reviewer** | Code review against story requirements and architecture rules | Implementation |
| **QA** | E2E testing and regression testing after merges | Implementation |
| **Deploy** | Merges branches, triggers regression QA | Implementation |
| **Content Creator** | Generates text/graphic content per content plan | Content |
| **Content Reviewer** | Verifies content accuracy and plan compliance | Content |
| **Content Integrator** | Integrates content into the application | Content |

### Workflow

```
/agent-sdlc:init  →  Configure project, create structure, copy base rules
/agent-sdlc:start →  PM reads state, dispatches agents, drives pipeline
/agent-sdlc:status → View current project status (read-only)
/agent-sdlc:env   →  Configure deployment environments
```

**Planning phase** (sequential): Product Manager → System Analyst → Architect → Designer

**Infrastructure phase** (sequential with review loop): Cloud Architect → DevOps Engineer → Architect Review

**Implementation phase** (parallel): Developer, Reviewer, QA, Deploy work as an Agent Team

**Content phase** (parallel): Content Creator, Content Reviewer, Content Integrator

### State machine

- **Epics:** `planning` → `ready` → `in_progress` → `done`
- **Stories:** `todo` → `in_progress` → `ready_for_review` → `in_review` → `ready_for_qa` → `in_qa` → `ready_for_merge` → `merged` → `done`
- **Content tasks:** `todo` → `creating` → `ready_for_review` → `in_review` → `ready_for_integration` → `integrating` → `ready_for_qa` → `in_qa` → `done`

### Git strategy

- Feature branches per epic: `feature/{EPIC-ID}-{slug}`
- Story branches per story: `story/{STORY-ID}-{slug}`
- Worktrees in `.worktrees/` for parallel agent work
- Merge flow: story → feature → main (with regression QA at each step)

## Installation

```bash
claude plugin add github.com/paulermo/claude-agent-sdlc
```

## Quick start

1. Install the plugin
2. Open your project in Claude Code
3. Run `/agent-sdlc:init` to configure the project
4. Run `/agent-sdlc:start` to launch the pipeline

## Optional dependencies

- **[OpenSpec](https://github.com/fission-ai/openspec)** — used by the Developer agent for spec-driven implementation. Install: `npm install -g @fission-ai/openspec@latest`
- **[Superpowers](https://github.com/anthropics/claude-plugins-official)** — Claude Code plugin used for brainstorming during project rules setup

## Project structure after init

```
your-project/
├── .worktrees/              ← git worktrees for parallel work (gitignored)
├── docs/
│   ├── project.md           ← product description
│   ├── directives/
│   │   ├── active/          ← drop directive files here to change priorities
│   │   └── archive/
│   ├── rules/               ← project rules organized by domain
│   │   ├── cross-cutting/   ← naming conventions, no magic strings
│   │   ├── api/             ← REST standards, error format, pagination
│   │   ├── backend/         ← architecture patterns, CQRS, modules
│   │   ├── frontend/        ← component tiers, coding standards, design system
│   │   ├── infra/           ← Docker, secrets, cloud architecture, DevOps
│   │   ├── authoring/       ← CLAUDE.md and README standards
│   │   ├── product/         ← spec conventions, quality criteria
│   │   ├── templates/       ← BRD, UC, epic, story, content templates
│   │   └── extending-sdlc.md
│   ├── requirements/        ← BRDs, use cases, content plans
│   ├── issues/              ← epics, stories, content tasks
│   └── state/
│       ├── project.json     ← config, agent registry, counters
│       ├── epics.json
│       ├── stories.json
│       ├── content-tasks.json
│       ├── environments.json
│       └── .secrets.json    ← gitignored
└── content/                 ← generated content files
```

## Base rules

Init copies a base set of rules from the plugin into `docs/rules/`. These provide a solid starting point covering API standards, backend/frontend architecture, infrastructure conventions, and more. The Architect agent customizes them for the specific project during the planning phase.

## Extending

See [docs/extending-sdlc.md](docs/extending-sdlc.md) for how to:
- Add new agents
- Add new task types
- Add integrations (Slack, Jira, CI/CD)
- Extend existing workflows

## Language/framework agnostic

The plugin works with any tech stack. Agents discover project-specific commands (test, build, lint) from the project's configuration files (`package.json`, `Makefile`, `pyproject.toml`, `Cargo.toml`, etc.).

## License

MIT
