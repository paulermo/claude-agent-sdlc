# Design: Adopting the paysera-marketplace harness patterns

**Date:** 2026-07-07
**Status:** implemented (v1.2.0)
**Goal:** Raise output quality and cross-model consistency of the agent-sdlc pipeline by adopting proven patterns from the paysera-marketplace Claude Code harness, and by fixing mechanical defects found during the audit. The pipeline must produce the same quality when driven by Opus-class models as by Fable-class models.

---

## 1. Study findings — what the marketplace harness does better

### 1.1 Four-layer knowledge architecture

`CLAUDE.md (index/router) → agents (personas, WHO) → skills (capabilities, HOW) → rules (constraints, LAW)`, with hooks providing hard gates.

| Layer | Size discipline | Content |
|-------|-----------------|---------|
| CLAUDE.md | thin router | dispatch contract, routing table, subsystem index pointing at rules/skills/agents |
| Agent | ~25-60 body lines | identity → "How to operate" (invoke skill, glob rules) → scope (Owns / Does not own) → collaboration (@peer handoffs) → behavioral discipline → output contract |
| Skill | lean SKILL.md + `references/` | workflow steps + `Topic / Reference / Load When` table for lazy depth |
| Rule | one topic per file | title → rule statement → Where applies / Where does NOT apply → Bad/Good examples → anti-patterns → enforcement |

Agent frontmatter is a fixed 4-field schema (`name`, `description`, `model`, `tools`). Descriptions follow: `{verb-led capability}. Invoke when {gerund triggers}[; scope caveat]. [Do NOT invoke for {anti-triggers}].`

Naming law (`agent-skill-naming.md`): agent = persona ("who would a team hire"), skill = discipline ("what activity"); names MUST differ. Many-to-many allowed.

Delegation carried by three verbatim phrases: "Invoke the `X` skill … it defines your workflow and loads references on demand"; "**Before any code change**, load all project rules for your domain: Glob `.claude/rules/{domain}/**/*.md` — read every matched file"; "**The rules files are the single source of truth** … don't invent your own."

### 1.2 Deterministic dispatch (craft-magic)

- Copy-paste dispatch prompt templates with **mandatory context sections**: task WHY, discovery findings, rules-adherence instruction, concrete deliverable, plan-file reference. "The dispatch prompt is their entire briefing… Skipping context = agents guessing = degraded outcomes."
- Task files on disk as durable state: `- [ ] [P0]` priorities, `[BLOCKED: reason]`, one file = one agent (file ownership, no write conflicts).
- Dependency-graph dispatch: bottleneck → fan-out; the layer-split sequential chain is a named anti-pattern.
- "Re-read ALL task files before reporting completion. No silent omissions."

### 1.3 Gates — two kinds

- **Conversational gates** (spec-gates.md): present understanding → literal "What would you adjust?" → `>>> STOP <<<` — **"Do NOT make any tool calls in the same response as the gate presentation."** Correction loop re-presents the FULL updated picture, never a delta. Anti-patterns tied to incident IDs.
- **Automated gates** (quality-gate.md): one rule file defines the exact command (`pnpm validate` in Docker); skill, agent, PR workflow and CI all cite that one definition. **Redundant enforcement across layers, single source of truth.**

### 1.4 Enforcement via hooks

Soft guidance = rules; hard guarantees = hooks. SessionStart injects context + knowledge-verification rules; UserPromptSubmit re-injects "re-read CLAUDE.md"; PreToolUse blocks rule-violating Bash (host package managers) with a teaching message and blocks `git push` on failed validation script.

### 1.5 Weak-model-proofing techniques (observed systematically)

Signal tables instead of judgment · exact commands · verbatim output templates · `>>> GATE/STOP <<<` markers · MUST DO / MUST NOT DO closing every skill · edge-case `Situation | Action` tables · mechanical severity mapping (MANDATORY = rule says MUST/NEVER; IMPORTANT = prefer/avoid; NOTE = no violation) · anti-invention guards ("Do not invent problems to look thorough", "Notes are not issues") · clean-code recognition template · named anti-patterns with examples · do-NOT-read lists for context economy.

### 1.6 Claude Code facts verified (against docs)

- `.claude/rules/` is native (v2.1.198+), auto-loaded, `paths:` frontmatter scopes loading; **subagents inherit CLAUDE.md and rules**.
- Plugin agents preload skills via `skills:` frontmatter (bare directory names, no namespace); full SKILL.md body injected; references NOT auto-injected — reference them as `${CLAUDE_SKILL_DIR}/references/…` for on-demand Read.
- `${CLAUDE_PLUGIN_ROOT}` expands in all plugin component content (commands, agents, hooks).
- Plugin `hooks/hooks.json` schema = settings.json `hooks` section. SessionStart: stdout or `hookSpecificOutput.additionalContext`. PreToolUse deny: `hookSpecificOutput.permissionDecision: "deny"` + reason (legacy `{"decision":"block"}` deprecated — do not copy from marketplace).
- Agent `model:` omitted = `inherit` (parent session model) — correct default for a generic plugin.

## 2. Audit findings — defects to fix (ranked)

1. **State ownership self-contradictory and lossy.** Developer/QA/Content agents write `docs/state/*.json` inside worktrees (their branches); Reviewer reports and PM writes; Deploy resolves state conflicts by discarding the branch side. Transitions silently vanish. → **Single-writer protocol** (D4).
2. **Dispatch by file path** ("Spawn subagent from agents/product.md") instead of real subagent names. → exact-name dispatch templates (D5).
3. **No enforcement layer** — all discipline is honor-system prose. → hooks + preloaded skills + CLAUDE.md block (D2, D3, D7).
4. **Deploy missing from init's agent registry** (13 entries, "14 total" claimed).
5. **OpenSpec hard-required by developer/analyst/architect, optional at init, no fallback.** → dual-path workflow with detection criteria.
6. **init Phase 3 brainstorming contradicts Phase 2** (would create flat rule files conflicting with the domain-organized base rules). → step replaced.
7. **README state machines ≠ implemented ones** (missing ready_for_deploy/deployed/frozen, content ready_for_merge/merged).
8. **State-entry JSON schemas never defined** — each run reinvents entry shapes. → verbatim schemas in `sdlc-state` skill.
9. **Feature-branch/regression working directory unspecified** — checkout collisions with worktree exclusivity. → designated merge worktrees (D6).
10. **Boilerplate duplicated across 4-6 agents** (rules-are-law, no-temp-solutions, glob blocks) — drift risk. → shared skill preamble, agents point.

Runners-up fixed too: environments.json written-never-read; content-reviewer granted write tools despite report-only role; `docs/rules/architecture.md` referenced but never guaranteed; pm.md stale path `commands/sdlc/start.md`; designer's macOS-only `open`; 8/14 agents missing `tools:`; phase enum drift (registry declares infrastructure/content phases that status/start never compute); orphaned `{PREFIX}-FEATURE-{N}` scheme in product/conventions template.

**Invariants preserved** (verified list from audit): command names `agent-sdlc:{init,start,status,env}`; plugin/marketplace identity; state file names/locations; init-produced layout; ID conventions `{PREFIX}-{BRD|EPIC|STORY|UC|CP|CEPIC|CTASK}-{N}`; branch conventions; commit convention `{PREFIX}: {desc} [by {Role}]`; gitignore entries; templates/rules content (best asset); Reviewer's report-only pattern (extended to all agents); Deploy's conflict-resolution philosophy; QA 3-mode concept; directive system + stale-worktree recovery; status.md as read-only projection.

## 3. Decisions

**D1. Three-layer restructure.** 14 agents become compact personas (marketplace anatomy, fixed section vocabulary). Workflows move to 13 plugin skills with `references/` for depth. Rules stay the constraints layer, relocated (D2).

**D2. Rules move to `.claude/rules/` in target projects.** Init copies base rules there (auto-migrating `docs/rules/` if found). Document templates are not rules — they move to `docs/templates/` (out of the rules tree, so unconditional-rule loading isn't polluted by scaffolds). Native auto-load + subagent inheritance = rules reach every agent without model discipline. Agents keep explicit "Glob + read" as belt-and-suspenders. Architect authors rules per `references/rule-authoring.md` (adapted cc-rule-magic + marketplace rule skeleton), including the mandatory root `architecture.md` and `quality-gate.md`.

**D3. Skill preloading via `skills:` frontmatter** (deterministic — nothing for the model to forget) + one body line pointing at `${CLAUDE_PLUGIN_ROOT}/skills/{name}/SKILL.md` as fallback. References cited as `${CLAUDE_SKILL_DIR}/references/…`.

**D4. Single-writer state protocol.** Only the PM session writes `docs/state/*.json`, on the main working copy, with history entries. Agents NEVER touch state files (their skills say so in MUST NOT). Every agent ends with a **fixed-format structured report** (per-agent template in its skill + dispatch brief); PM parses the report, applies the transition, commits. Agent progress inside a worktree lives in the story/task .md file (single owner — merges cleanly). PM sets `in_progress`/`in_review`/`in_qa`/`integrating` at dispatch time.

**D5. Template-driven dispatch.** `sdlc-dispatch/references/briefs.md` holds one copy-paste brief per agent role with mandatory sections: WHY (story/epic context) · exact input paths · preloaded-skill reminder + rules instruction · concrete deliverable + report format · what PM will verify. start.md's dispatch instructions name agents by exact registered name and forbid freehand briefs.

**D6. Designated working directories.** Story/content work: item worktrees (as now). Story→feature merge + feature regression QA: dedicated worktree `{worktree_dir}/{EPIC-ID}-merge` on the feature branch. Feature→main merge + main regression: PM's main working copy (PM stays on main, dispatches Deploy synchronously, verifies clean tree after). Codified in `story-merge` and `story-qa` skills.

**D7. Hooks (plugin hooks/hooks.json), all no-ops outside SDLC projects:**
- **SessionStart** → `session-start.sh`: if `docs/state/project.json` exists, inject state summary (phase, per-status counts, active worktrees, pending directives) + pointer to /agent-sdlc:status and the single-writer rule.
- **PostToolUse** (Write|Edit) → `validate-state.sh`: if the edited file is `docs/state/*.json`, `jq empty` it; on parse failure exit 2 with a fix-it message (feeds back to the model immediately).
- **PreToolUse** (Bash) → `guard-git.sh`: in SDLC projects deny `git push --force`/`-f` and `git merge -X theirs|ours` with teaching messages (modern `hookSpecificOutput.permissionDecision` format).

**D8. init writes a managed block into the target project's CLAUDE.md** (`<!-- agent-sdlc:begin/end -->`, idempotent): state locations + "state is PM-managed — agents never edit it", routing table (status → agent), rules location + "rules are law", "the orchestrator never writes code". CLAUDE.md is inherited by every subagent — the guaranteed ambient-context channel.

**D9. Quality gate as a project rule.** Init seeds `.claude/rules/quality-gate.md` with `{placeholders}`; Architect MUST fill exact commands during planning. Developer, Reviewer, QA, Deploy all cite this one file instead of "discover the project's test commands" (currently duplicated 4×, vaguely).

**D10. Review severity discipline** (story-review skill): MANDATORY / IMPORTANT / NOTE with mechanical mapping to rule language; verdicts PASS / PASS WITH NOTES / NEEDS WORK / BLOCKED (REJECTED iff mandatory or important findings); anti-invention guard + clean-code recognition; review file written to `docs/reviews/{STORY-ID}-{n}.md`.

**D11. Skill map** (names differ from agent names per naming law):

| Skill | Preloaded by | Core content |
|-------|-------------|--------------|
| sdlc-state | (read by start.md; referenced by all) | status machines, transition table (who sets what), verbatim entry JSON schemas, history format, commit conventions, single-writer protocol |
| sdlc-dispatch | (read by start.md) | brief templates per agent, parallelism rules, verify-after-completion table, teammate mechanics |
| brd-writing | Product Manager | BRD/epic/content-plan workflow, prioritization criteria, refinement mode |
| story-breakdown | System Analyst | use-case + story derivation, sizing signals, INVEST checks, state registration reporting |
| architecture-design | Architect | design mode, review mode, rule-authoring reference, mandatory root rules (architecture.md, quality-gate.md) |
| ui-design | Designer | option-based interactive flow, gate discipline (no tool calls in gate responses), autonomous mode |
| story-implementation | Developer | dual-path (OpenSpec / spec-lite) with detection table, testing requirements, checkbox discipline |
| story-review | Reviewer | severity discipline, review checklist, review file format |
| story-qa | QA | standard/regression modes, working dirs, evidence discipline |
| story-merge | Deploy | merge protocol, conflict-resolution table, working dirs, verification via quality-gate |
| content-production | Content Creator/Reviewer/Integrator | shared conventions + per-role workflows |
| cloud-design | Cloud Architect | methodology extracted from agent |
| infra-implementation | DevOps Engineer | methodology extracted from agent |

**D12. Deliberately NOT adopted:** plan-mode integration (pipeline has its own state machine); craft-magic itself (ad-hoc orchestration — we adopt its mechanics, not the skill); `paths:` frontmatter on *base* rules (stack unknown at plugin authoring time — Architect adds scoping per project); marketplace-specific skills (digest, zed, screebug…); marketplace's legacy hook output format and its documented drift (stale Info Block references, duplicate CLAUDE.md budgets — single source of truth in our authoring standard instead).

## 4. Weak-model-proofing standard (docs/authoring-standards.md, applied to every file)

1. Numbered steps, exact commands, `{placeholders}` with legend.
2. Signal tables for every classification decision; explicit criteria for every "if".
3. MUST DO / MUST NOT DO close every skill; hard stops as `>>> GATE: … <<<` + "no tool calls in the same response as a gate presentation".
4. Output formats quoted verbatim; agents fill templates, never invent structure.
5. Evidence before claims: "done" requires the named check's actual output in the report.
6. Every constraint carries its WHY in one clause.
7. Edge cases as `Situation | Action` tables.
8. Anti-rationalization guards at known corner-cutting points.
9. Do-NOT-read / do-NOT-do lists for context economy.
10. One source of truth per fact; cross-reference by exact path/name.

## 5. Rollout

v1.2.0, single release (agents reference skills — atomic). Existing projects: re-run `/agent-sdlc:init` → migrates `docs/rules/` → `.claude/rules/`, adds CLAUDE.md block, repairs registry (adds deploy), leaves state files untouched. State machine unchanged except: agents stop writing state (PM-only), `in_review`/`in_qa`/`integrating` now actually set by PM.
