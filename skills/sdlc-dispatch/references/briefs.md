# Dispatch Brief Templates

Copy the template for the agent you are dispatching, fill every `{placeholder}`, send as the agent's task prompt. Write `none` rather than deleting a section.

Placeholder legend: `{ITEM-ID}` = story/bug/task ID; `{worktree}` = path from `project.json` worktrees; `{feedback-file}` = the PATH stored in the state feedback field (e.g. `docs/reviews/{STORY-ID}-2.md`) — the agent reads that file; never paste the feedback text into the brief; `{PREFIX}` = project prefix from `project.json`; `{tier}` / `{returns}` / `{kind}` = from the item's entry (absent = `standard` / `0` / `story`); `{budget}` = the tier's return budget (sdlc-state section 4); `{record path}` = the bug entry's `record` field.

**Brief cap (LAW, sdlc-dispatch section 1):** the filled template and nothing else — `WHY` is the only free text (≤ 2 sentences). If an agent needs more, it is in a file the brief points to.

Teammate note: when the agent runs as a **team teammate** (not a subagent), its `skills:` frontmatter is NOT applied — the "preloaded" skill is absent. The agent's own definition tells it to load the skill via the Skill tool in that case; the DISCIPLINE section's skill name is what it loads. Do not strip DISCIPLINE from any brief.

Every template ends with the same REPORT contract — the agent's skill defines the OUTCOME values; you (PM) parse the envelope and apply the transition per the sdlc-state skill.

---

## Product Manager — initial planning

```
Plan the product into business requirements.

WHY: The project has no BRDs yet. Your BRDs and epics become the backbone every later agent builds on.

INPUTS (read in this order):
- docs/project.md — the product description
- docs/state/project.json — prefix and counters (READ ONLY — report new counter values, do not write)
- docs/templates/brd-template.md, epic-template.md, content-plan-template.md
Do NOT read: source code, docs/state/active.json or backlog.json (nothing is registered yet).

DISCIPLINE: Your workflow is the preloaded brd-writing skill — follow it exactly. Never edit docs/state/*.json; report what should be registered and I will write state.

DELIVERABLE: BRD files + epic files (+ content plans if the product needs content) + docs/glossary.md (the ubiquitous language) committed per your skill's conventions, and the report below.

VERIFICATION: I will check every FILES entry exists, docs/glossary.md is present, epics reference real BRDs, and priority rationale is stated.

End your final message with the report envelope (=== AGENT REPORT ===) from your skill, OUTCOME: PLANNED | BLOCKED. In DETAILS list: each BRD/epic/content-plan ID + title + priority order + new counter values.
```

## Product Manager — refinement (after epic completion)

```
Refine the backlog after completing {EPIC-ID}.

WHY: {EPIC-ID} ({title}) just shipped. Delivered scope may change priorities or reveal new requirements.

INPUTS: docs/issues/{EPIC-ID}-{slug}/epic.md (+ story list), docs/state/epics.json (READ ONLY), docs/requirements/ BRDs, user feedback: {feedback-or-none}.

DISCIPLINE: preloaded brd-writing skill, refinement mode. Never edit docs/state/*.json.

DELIVERABLE: updated/new BRDs and epics (if warranted) committed; recommended priority_order; report.

VERIFICATION: every recommendation must name evidence from the delivered epic.

Report envelope, OUTCOME: REFINED | NO_CHANGES | BLOCKED. In DETAILS: recommended priority_order and any new IDs with rationale.
```

## System Analyst

```
Break epic {EPIC-ID} into stories and use cases.

WHY: {one sentence from the epic — what the feature delivers}.

INPUTS: docs/requirements/{BRD-ID}-{slug}.md, docs/issues/{EPIC-ID}-{slug}/epic.md, docs/templates/use-case-template.md + story-template.md (+ content-task-template.md for content epics), docs/state/project.json for prefix/counters (READ ONLY).
Do NOT read: other epics' stories.

DISCIPLINE: preloaded story-breakdown skill. Never edit docs/state/*.json — report the entries to register and I will write them.

DELIVERABLE: use-case files + story files committed (each story with a **Tier:** line from your skill's tier table), and in DETAILS the exact JSON entry per story (schema from your skill — kind, tier, returns included) for me to register.

VERIFICATION: each story maps to ≥1 use case, has testable acceptance criteria, has a tier, and passes your skill's sizing signals.

Report envelope, OUTCOME: BROKEN_DOWN | NEEDS_PRODUCT_INPUT | BLOCKED. NEEDS_PRODUCT_INPUT must name the ambiguity — I will re-dispatch Product Manager.
```

## Architect — Design Mode

```
Design the architecture for {EPIC-ID} and codify the project rules.

WHY: Developers implement exactly what your rules and technical notes say; gaps become guesses.

INPUTS: docs/project.md, docs/requirements/ (BRDs + use cases for this epic), docs/issues/{EPIC-ID}-{slug}/ (epic + stories), existing rules in .claude/rules/, existing specs (openspec spec list, if OpenSpec is installed).

DISCIPLINE: preloaded architecture-design skill, Design Mode. Rules you write go to .claude/rules/ (NOT docs/rules/). Never edit docs/state/*.json.

DELIVERABLE: (1) .claude/rules/architecture.md + .claude/rules/quality-gate.md with EXACT project commands — both MANDATORY; (2) domain rules customized for the stack; (3) ## Technical Notes in every story of the epic, and a corrected **Tier:** line where your design reveals a critical signal the Analyst missed (list every tier change in DETAILS — I update state); (4) ## Architecture Notes in epic.md. All committed.

VERIFICATION: I will check architecture.md and quality-gate.md exist and quality-gate.md contains runnable commands (no {placeholders} left), and that every story has Technical Notes.

Report envelope, OUTCOME: DESIGNED | NEEDS_REQUIREMENTS_FIX | BLOCKED. NEEDS_REQUIREMENTS_FIX names the BRD/story defects — I will loop Product Manager/Analyst and re-dispatch you.
```

## Architect — Init Rules Session (interactive, dispatched from /agent-sdlc:init)

```
Co-shape the project rules with the user before the pipeline starts.

WHY: rules agreed with the user up front save rejection loops later; the user knows constraints no file states yet.

INPUTS: docs/project.md, the seeded .claude/rules/ (all files), existing code/config if any (detect the stack).

DISCIPLINE: preloaded architecture-design skill, Init Rules Session mode — its gate procedure is mandatory: full picture in one message, "What would you adjust?", no tool calls in the gate response, full re-presentation after corrections. The user is present — talk to them. Never edit docs/state/*.json.

DELIVERABLE: agreed customizations applied to .claude/rules/ (+ quality-gate.md filled if the stack is known), committed as {PREFIX}: Customize project rules with user [by Architect].

VERIFICATION: I will check the commit exists and quality-gate.md's state matches your report.

Report envelope, OUTCOME: RULES_CONFIGURED | BLOCKED. In DETAILS: decisions made, rules changed/deleted/added, remaining placeholders.
```

## Architect — Review Mode

```
Review {scope: infrastructure designs | implementation} against the architecture rules.

WHY: {what is being gated, e.g. "Cloud/DevOps output must comply with the rules before implementation starts"}.

INPUTS: {artifact paths to review}, .claude/rules/ (all).

DISCIPLINE: preloaded architecture-design skill, Review Mode. Read-only on the reviewed artifacts. Never edit docs/state/*.json.

DELIVERABLE: verdict per your skill's severity discipline.

Report envelope, OUTCOME: APPROVED | REJECTED. If REJECTED, DETAILS carries the findings list (file, what, which rule, fix) — I will store it and re-dispatch the author.
```

## Cloud Architect

```
Design the cloud infrastructure for {project | EPIC-ID}.

WHY: {deployment goal, e.g. "the product deploys to {env list} and DevOps implements from your design"}.

INPUTS: docs/project.md, .claude/rules/ (root + infra/), docs/issues/{EPIC-ID}-{slug}/epic.md architecture notes, docs/state/environments.json (target environments).

DISCIPLINE: preloaded cloud-design skill. Never edit docs/state/*.json.

DELIVERABLE: .claude/rules/infra/cloud-architecture.md (design + service selection rationale + security + cost model), committed.

VERIFICATION: the rule file exists, names concrete services, and states cost assumptions.

Report envelope, OUTCOME: DESIGNED | BLOCKED.
```

## DevOps Engineer

```
Implement CI/CD and infrastructure for {project | EPIC-ID}.

WHY: implements the Cloud Architect's design so deployments are reproducible.

INPUTS: .claude/rules/infra/ (including cloud-architecture.md), .claude/rules/quality-gate.md, docs/state/environments.json, project configuration files.

DISCIPLINE: preloaded infra-implementation skill. Never edit docs/state/*.json.

DELIVERABLE: Dockerfiles / CI pipelines / IaC per the design, committed; quality-gate commands runnable in CI.

VERIFICATION: I will check the FILES exist and EVIDENCE shows validation output (builds, terraform validate, etc.).

Report envelope, OUTCOME: IMPLEMENTED | NEEDS_DESIGN_FIX | BLOCKED.
```

## Designer

```
Design the UI/UX for {EPIC-ID}: {stories list}.

WHY: {user-facing goal of the epic}.

INPUTS: docs/issues/{EPIC-ID}-{slug}/ stories + use cases, BRD {BRD-ID}, .claude/rules/frontend/ (design system rules if present).
MODE: {interactive — user available | autonomous — --no-human, decide per your skill's defaults and record decisions}.

DISCIPLINE: preloaded ui-design skill — its gates are mandatory in interactive mode. Never edit docs/state/*.json.

DELIVERABLE: design notes in stories (## Design section), design-system rule updates if needed, committed.

Report envelope, OUTCOME: DESIGNED | BLOCKED. In DETAILS: decisions made (autonomous mode) or user-approved options (interactive).
```

## Developer — story (first dispatch)

```
Implement story {STORY-ID}: {title}.

WHY: {one sentence: what this story delivers to the user}.

KIND: story · TIER: {tier}
WORKTREE: {worktree} on branch {branch}. Work ONLY there.
FOLLOW-UPS: {docs/issues/{EPIC-ID}-{slug}/followups.md | none} — close open entries whose instances are in files you modify anyway; never open other files for them.

INPUTS (read in this order):
1. docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md — the story (your checklist lives here)
2. The use case it references
3. docs/issues/{EPIC-ID}-{slug}/epic.md — ## Architecture Notes
4. .claude/rules/quality-gate.md — the EXACT verification commands
Do NOT read: other stories, other epics.

DISCIPLINE: your workflow is the preloaded story-implementation skill — follow its path selection (OpenSpec vs spec-lite) exactly. Rules in .claude/rules/ are law — load your domain's before coding. Never edit docs/state/*.json, the follow-ups file, or bug records. Commit as {STORY-ID}: {description} [by Developer].

DELIVERABLE: implementation + tests, all quality-gate commands green, story checkboxes ticked, committed and pushed if remote exists.

VERIFICATION: I will check commits exist, EVIDENCE contains actual test/lint output summaries, and story checkboxes match reality.

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED. EVIDENCE must include each quality-gate command with its result; DETAILS carries an OUT OF SCOPE line per defect you noticed but did not fix.
```

## Developer — rework (after review_rejected / qa_rejected)

```
Rework {ITEM-ID}: {title} — return {returns} of {budget}.

WHY: {one clause: the top blocking finding}.

KIND: {kind} · TIER: {tier}
WORKTREE: {worktree} on branch {branch}. Work ONLY there; your prior work is already committed here.
FEEDBACK: {feedback-file} — read it FIRST; fix every Mandatory and Important-blocking finding; Follow-ups only in files you change anyway.
FOLLOW-UPS: {path | none}

INPUTS: the feedback file, the files it names, .claude/rules/quality-gate.md, and ONLY the rules the findings cite.
Do NOT re-read: the use case, the epic notes, the full rules tree, other stories — you followed them once; the findings are the reading list.

DISCIPLINE: preloaded story-implementation skill, section 2b (Rework): no refactoring beyond the findings; a finding you believe is wrong gets a DISPUTED line in DETAILS, never silence. Never edit docs/state/*.json.

DELIVERABLE: every finding FIXED (or DISPUTED with grounds), full quality gate green, committed and pushed if remote exists.

VERIFICATION: I will check new commits exist and EVIDENCE lists each quality-gate command's result and each finding's outcome.

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED.
```

## Developer — bug

```
Fix bug {BUG-ID}: {title}.

WHY: {one clause: what is broken and for whom}.

KIND: bug · TIER: {tier} · BUDGET: 1 return
WORKTREE: {worktree} on branch {branch}. Work ONLY there.
RECORD: {record path} — symptom, reproduction, expected, acceptance, scope hints. It is the whole specification: there is no story and no use case.
FOLLOW-UPS: {path | none}

INPUTS: the bug record, .claude/rules/quality-gate.md, the rules for the domains the scope hints name.
Do NOT read: stories, use cases, epic notes, other bugs.

DISCIPLINE: preloaded story-implementation skill, Bug path (section 1b): reproduce with a failing test named after {BUG-ID}, fix the cause, full gate green. No design.md / tasks.md / OpenSpec. Never edit docs/state/*.json or the record. Commit as {BUG-ID}: Fix {what} [by Developer].

DELIVERABLE: the reproducing test + the fix, quality gate green, committed and pushed if remote exists.

VERIFICATION: I will check the test exists and names {BUG-ID}, EVIDENCE shows it failing before and passing after, and each quality-gate command's result.

Report envelope, OUTCOME: IMPLEMENTED | BLOCKED (cannot reproduce → BLOCKED with what you tried).
```

## Reviewer

```
Review {ITEM-ID}: {title}.

WHY: gate before {QA | merge} — story compliance and rules compliance at the item's tier.

KIND: {kind} · TIER: {tier} · ROUND: {returns + 1}
{Round ≥ 2:} PRIOR REVIEW: {feedback-file} · PRIOR HEAD: {the Head sha from that file} — scope = prior findings + the delta since PRIOR HEAD (re-review scope law).
WORKTREE: {worktree} (Developer's, read-only for you).

INPUTS: {story: the story file + its use case, epic architecture notes | bug: the bug record {record path}}, .claude/rules/ (all domains touched by the diff), the diff: {round 1: git -C {worktree} diff {feature-branch}...HEAD | round ≥ 2: git -C {worktree} diff {PRIOR HEAD}..HEAD}

DISCIPLINE: preloaded story-review skill — lenses by tier, severity mechanical, verdict by round, one finding per class with its instances. You are read-only: no source edits, no state edits.

DELIVERABLE: the full review document (format from your skill, Head sha included) in DETAILS — you are read-only, so I will save it to docs/reviews/{ITEM-ID}-{round}.md and commit it.

Report envelope, OUTCOME: APPROVED | REJECTED. REJECTED requires ≥1 MANDATORY or ≥1 blocking IMPORTANT per your verdict table; other IMPORTANTs go to ## Follow-ups and do not block; NOTE-only reviews are APPROVED.
```

## QA — standard mode

```
Test {ITEM-ID}: {title}.

WHY: verify the item's acceptance criteria end-to-end before merge.

KIND: {kind} · TIER: {tier} {if light story / light-or-standard bug: "— normally not QA'd; dispatched because: {one clause}"}
WORKTREE: {worktree}. Ports for parallel Docker: COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} (from project.json worktrees).
{If re-test:} PRIOR QA FEEDBACK: read {feedback-file} — verify every item in it is fixed; re-test the delta and the flows it touches.

INPUTS: {story file (acceptance criteria) + use case (flows) | bug record {record path}}, .claude/rules/quality-gate.md, docs/state/environments.json if E2E against a deployed env is configured.

DISCIPLINE: preloaded story-qa skill, standard mode, depth by tier. You may write test files only — never application source, never docs/state/*.json. Defects outside this item's ACs go under ## Out-of-scope defects — never into the verdict, never as story proposals.

DELIVERABLE: E2E tests per the tier's coverage law, committed; execution evidence.

Report envelope, OUTCOME: PASSED | FAILED. FAILED requires reproduction steps per failure in DETAILS.
```

## QA — regression mode

```
Regression-test {STORY-ID after merge to {feature-branch} | EPIC-ID on main}.

WHY: prove the merge broke nothing before advancing.

WORKING DIR: {merge worktree path for feature-branch regression | main working copy for epic regression} — NOT a story worktree.

INPUTS: .claude/rules/quality-gate.md (FULL suite commands), the merged story's acceptance criteria (spot-check list), for epics: all epic stories.

DISCIPLINE: preloaded story-qa skill, regression mode.

Report envelope, OUTCOME: PASSED | FAILED. EVIDENCE: full-suite results + spot-check outcomes + merge-artifact scan (<<<<<<< markers). A FAILED becomes a bug I register — DETAILS must carry the failing command and reproduction.
```

## Deploy — story merge

```
Merge {ITEM-ID} ({kind}, branch {branch}) into {feature-branch}.

WHY: {QA passed | review passed (standard bug) | gate passed (light item)}; integrate before regression.

WORKING DIR: {worktree_dir}/{EPIC-ID}-merge (I created it on {feature-branch}). Work ONLY there.

INPUTS: .claude/rules/quality-gate.md, docs/state/active.json (READ ONLY — for branch names).

DISCIPLINE: preloaded story-merge skill — its conflict-resolution table is law (NEVER -X theirs/ours). Never edit docs/state/*.json; if state files conflict, keep the {feature-branch} side.

Report envelope, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED. EVIDENCE: quality-gate results after merge; conflicts resolved (files + strategy). A VERIFICATION_FAILED becomes a bug I register — DETAILS must carry the failing output.
```

## Deploy — epic merge to main

```
Merge {feature-branch} into main for {EPIC-ID}.

WHY: every story and bug done, follow-ups closed; ship the epic.

WORKING DIR: the main working copy (I am pausing all other dispatches until you finish). Confirm `git status` is clean and branch is main before starting; abort with OUTCOME: MERGE_FAILED if not.

INPUTS/DISCIPLINE: as story merge. Do NOT push — I push after main regression passes.

Report envelope, OUTCOME: MERGED | MERGE_FAILED | VERIFICATION_FAILED.
```

## Content Creator

```
Create content for {CTASK-ID}: {title}.

WHY: {what this content serves in the product}.

WORKTREE: {worktree} on {branch}.
{If rework:} PRIOR FEEDBACK: read {feedback-file} and fix ALL of it.

INPUTS: docs/issues/{CEPIC-ID}-{slug}/{CTASK-ID}-{slug}.md, the content plan docs/requirements/content-plan/{CP-ID}-{slug}.md, content/ conventions from your skill.

DISCIPLINE: preloaded content-production skill, Creator role. Never edit docs/state/*.json.

Report envelope, OUTCOME: CREATED | BLOCKED. FILES: every content file produced.
```

## Content Reviewer

```
Review content for {CTASK-ID}: {title}.

WORKTREE: {worktree} (Creator's, read-only for you).
INPUTS: the content task file, the content plan, produced files under content/.
DISCIPLINE: preloaded content-production skill, Reviewer role. Read-only — findings go in DETAILS, I store feedback.

Report envelope, OUTCOME: APPROVED | REJECTED (REJECTED requires specific per-file findings).
```

## Content Integrator

```
Integrate content for {CTASK-ID}: {title}.

WORKTREE: {worktree}.
{If rework:} PRIOR FEEDBACK (rejection_reason was "integration"): read {feedback-file} and fix ALL of it.
INPUTS: approved content files under content/, the content task file (target locations), .claude/rules/quality-gate.md.
DISCIPLINE: preloaded content-production skill, Integrator role. Migrations/seeds/static resources only — never application logic. Never edit docs/state/*.json.

Report envelope, OUTCOME: INTEGRATED | BLOCKED. EVIDENCE: quality-gate result after integration.
```
