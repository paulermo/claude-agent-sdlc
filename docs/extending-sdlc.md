# Extending the SDLC Agent Pipeline

This guide explains how to extend the SDLC system with new agents, task types, and integrations.

## Adding a New Agent

1. **Create agent file:** `.claude/agents/{agent-name}.md` with YAML frontmatter:
   ```yaml
   ---
   name: "{Agent Name}"
   description: "{What this agent does}"
   ---
   ```
   Follow the prompt with: role description, inputs it expects, outputs it produces, tools it uses, files it reads/writes.

2. **Register in project.json:** Add entry to `agents` in `docs/state/project.json`:
   ```json
   "{agent-name}": {
     "file": "{agent-name}.md",
     "phase": "planning | implementation | content | on_demand",
     "type": "subagent | teammate"
   }
   ```
   - `subagent`: called sequentially by PM via Agent tool (planning phase)
   - `teammate`: spawned as Agent Team member for parallel work (implementation phase)

3. **Update PM prompt:** Add to the PM agent's dispatch logic when and how to invoke the new agent.

## Adding a New Task Type

1. **Choose a prefix** for IDs (e.g., `DOCS` for documentation tasks → `{PREFIX}-DOCS-001`)

2. **Create state file:** `docs/state/{type}-tasks.json` with the structure:
   ```json
   {
     "{PREFIX}-{TYPE}-001": {
       "epic": "{EPIC-ID}",
       "title": "...",
       "status": "todo",
       "branch": "{type}/{PREFIX}-{TYPE}-001-slug",
       "worktree": null,
       "assignee": null,
       "history": []
     }
   }
   ```

3. **Define workflow statuses:** Document the status transitions, e.g.:
   ```
   todo → in_progress → ready_for_review → in_review → done
   ```

4. **Add dispatch rules:** Map each status to the agent that handles it:
   | Status | Agent |
   |--------|-------|
   | `todo` | {creating agent} |
   | `ready_for_review` | {reviewing agent} |
   | ... | ... |

5. **Update PM:** Add the new dispatch rules to the PM's orchestration logic.

## Adding an Integration

1. **Add to project.json:**
   ```json
   "integrations": {
     "your_integration": {
       "type": "notifications | issue_tracker | ci_cd | custom",
       "config": { ... }
     }
   }
   ```

2. **PM reads integrations on startup.** It checks `integrations` in `project.json` and uses available ones. To add behavior, update the PM agent prompt.

3. **Possible integrations:**
   - Slack/Telegram notifications on status changes
   - Jira/Linear bidirectional sync
   - CI/CD pipeline triggers after merges
   - MCP servers for external tools (Figma, analytics)

## Extending Existing Workflows

To add statuses to an existing workflow (e.g., add `in_design` before `todo` for stories):

1. Update the workflow diagram in the spec
2. Add the status handling to the PM dispatch table
3. Update the relevant agent prompts to produce/consume the new status
4. Update the JSON state file to include the new status options
