---
name: "SDLC: Init"
description: "Initialize SDLC agent pipeline in the current project"
---

Initialize the SDLC agent pipeline for this project.

**Steps:**

## Phase 0: Prerequisites

0.1. **Check git repository:**
   ```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   ```
   If not a git repo, initialize:
   ```bash
   git init
   git add -A
   git commit -m "Initial commit"
   ```

0.2. **Check OpenSpec is installed (optional):**
   ```bash
   openspec --version 2>/dev/null
   ```
   If not found, inform but don't block:
   > "OpenSpec is not installed. The Developer agent uses it for spec-driven workflow. Install via `npm install -g @fission-ai/openspec@latest` if needed."

   If OpenSpec IS found and not initialized in the project (`openspec/` directory does not exist):
   ```bash
   openspec init --tools claude
   ```

0.3. **Check Superpowers skills are available:**
   Verify the `superpowers:brainstorming` skill exists by checking if the Skill tool can find it.
   If not available, inform the user:
   > "Superpowers plugin is not installed. Install it via Claude Code settings for full SDLC capabilities (brainstorming during init)."

## Phase 1: Project Configuration

1. **Ask for project prefix** using AskUserQuestion:
   > "What project prefix should be used for IDs? (e.g., KRT, PRJ, APP — 2-5 uppercase letters)"

   Validate: 2-5 uppercase letters.

2. **Ask for project name** using AskUserQuestion:
   > "What is the project name?"

3. **Ask for product description** using AskUserQuestion:
   > "Provide a product description (or path to a file with description):"

   If user provides a file path, read it. Otherwise use the text directly.

4. **Ask for environments** using AskUserQuestion:
   > "Which environments to set up? (comma-separated, e.g., dev,staging,prod)"

## Phase 2: Structure & State

5. **Create directory structure:**
   ```
   .worktrees/                        ← create empty dir (for git worktrees)
   docs/project.md                    ← write product description here
   docs/directives/active/            ← create empty dir
   docs/directives/archive/           ← create empty dir
   docs/rules/                        ← create dir
   docs/rules/templates/              ← copy templates from plugin
   docs/requirements/                 ← create empty dir
   docs/requirements/content-plan/    ← create empty dir
   docs/issues/                       ← create empty dir
   docs/state/                        ← create dir
   content/                           ← create empty dir
   ```

6. **Copy templates from plugin:**
   Copy all template files from the plugin's `templates/` directory to `docs/rules/templates/` in the project.
   Copy `docs/extending-sdlc.md` from the plugin to `docs/rules/extending-sdlc.md`.

7. **Create JSON state files:**

   `docs/state/project.json`:
   ```json
   {
     "prefix": "{USER_PREFIX}",
     "name": "{PROJECT_NAME}",
     "phase": "not_started",
     "_note_phase": "Phase is computed by /sdlc:status from state, but stored here as a cache for quick access. PM updates it on transitions.",
     "max_parallel_teammates": 3,
     "worktree_dir": ".worktrees",
     "worktrees": {},
     "counters": {
       "brd": 0,
       "uc": 0,
       "epic": 0,
       "story": 0,
       "cp": 0,
       "cepic": 0,
       "ctask": 0
     },
     "agents": {
       "pm": { "file": "pm.md", "phase": "all", "type": "lead" },
       "product": { "file": "product.md", "phase": "planning", "type": "subagent" },
       "analyst": { "file": "analyst.md", "phase": "planning", "type": "subagent" },
       "architect": { "file": "architect.md", "phase": "planning", "type": "subagent" },
       "designer": { "file": "designer.md", "phase": "on_demand", "type": "subagent" },
       "developer": { "file": "developer.md", "phase": "implementation", "type": "teammate" },
       "reviewer": { "file": "reviewer.md", "phase": "implementation", "type": "teammate" },
       "qa": { "file": "qa.md", "phase": "implementation", "type": "teammate" },
       "content-creator": { "file": "content-creator.md", "phase": "content", "type": "teammate" },
       "content-reviewer": { "file": "content-reviewer.md", "phase": "content", "type": "teammate" },
       "content-integrator": { "file": "content-integrator.md", "phase": "content", "type": "teammate" }
     },
     "integrations": {
       "notifications": null,
       "issue_tracker": null,
       "ci_cd": null
     }
   }
   ```

   `docs/state/epics.json`:
   ```json
   {
     "priority_order": [],
     "epics": {}
   }
   ```

   `docs/state/stories.json`:
   ```json
   {}
   ```

   `docs/state/content-tasks.json`:
   ```json
   {}
   ```

   `docs/state/environments.json` — build from user's environment list:
   ```json
   {
     "environments": {
       "dev": { "url": null, "configured": false },
       ...
     }
   }
   ```

   `docs/state/.secrets.json`:
   ```json
   {}
   ```

8. **Add to `.gitignore`** if not already there:
   ```
   docs/state/.secrets.json
   .worktrees/
   ```

9. **Commit structure and state:**
   ```bash
   git add docs/ content/ .gitignore .worktrees/
   git commit -m "{PREFIX}: Initialize SDLC project structure [by PM]"
   ```

## Phase 3: Project Rules & Standards

10. **Check if project rules exist:**
    Check `docs/rules/` for files like `architecture.md`, `coding-standards.md`, `api-conventions.md`.

    If NO rules files exist (beyond templates/ and extending-sdlc.md), launch an interactive brainstorming session with the user to establish project rules:

    Invoke `superpowers:brainstorming` with the following context:
    > "We need to establish project rules and standards for {PROJECT_NAME}. The product description is in docs/project.md. We need to define:
    >
    > 1. **Technology stack** — what frameworks, languages, databases, and tools will be used
    > 2. **Architecture principles** — architectural style (monolith, microservices, serverless), patterns (MVC, CQRS, etc.)
    > 3. **Coding standards** — naming conventions, file structure, linting rules, formatting
    > 4. **API conventions** — REST/gRPC/GraphQL, naming, versioning, error handling
    > 5. **Testing strategy** — what to test, coverage requirements, testing frameworks
    > 6. **Quality gates** — what must pass before a story can be reviewed, QA'd, and merged
    > 7. **Content guidelines** — tone, style, localization requirements (if applicable)
    >
    > Output: create rule files in docs/rules/ (architecture.md, coding-standards.md, api-conventions.md, testing-strategy.md, quality-gates.md, and optionally content-style.md)"

    After brainstorming completes, commit the rules:
    ```bash
    git add docs/rules/
    git commit -m "{PREFIX}: Define project rules and standards [by PM]"
    ```

    If rules files ALREADY exist, skip this step and inform:
    > "Project rules already defined in docs/rules/. Skipping brainstorming."

## Phase 4: Finalize & Push

11. **Push to remote (if configured):**
    ```bash
    git remote -v 2>/dev/null
    ```
    If a remote exists, push:
    ```bash
    git push
    ```
    If no remote, inform:
    > "No git remote configured. Remember to add one with `git remote add origin <url>` and push when ready."

12. **Output summary:**
    > SDLC initialized for project {NAME} ({PREFIX}).
    >
    > Created:
    > - docs/project.md — product description
    > - docs/state/ — JSON state files (project, epics, stories, content-tasks, environments)
    > - docs/rules/ — project rules and standards
    > - docs/rules/templates/ — document templates (BRD, UC, epic, story, content)
    > - docs/rules/extending-sdlc.md — extension guide
    > - docs/directives/ — directive system (active + archive)
    > - .worktrees/ — git worktree directory (gitignored)
    >
    > Next: Run `/sdlc:start` to begin the SDLC pipeline.
