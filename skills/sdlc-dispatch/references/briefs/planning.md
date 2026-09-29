# Brief templates — planning roles

Copy the template for the dispatch, fill every `{placeholder}`, and send the result as the agent's task prompt — never a freehand brief (sdlc-dispatch section 1, brief slots and the cap). Slots run in one order — `WHY` · `MODE` (in the KIND / TIER / ROUND position) · `WORKTREE` · `CARRIED IN` · `INPUTS` · `DISCIPLINE` · `DELIVERABLE` · `VERIFICATION` · `REPORT` — and a slot a template lacks does not apply to it. Only `WHY` (≤ 2 sentences) and `CARRIED IN` (≤ ~600 characters: the user's words, options or defects the work must respect) are free text; every other value is a path, an ID, a SHA, a number, a command, or `none` — write `none` rather than deleting a line, and keep the one alternative of each `{a | b}` that applies. `{cap}` = `process.report_max_chars` (absent: 3500). `{standing lines}` = the lines of `process.standing_brief_lines.all`, then of `process.standing_brief_lines["{Role}"]`, one per line, or nothing — outside the brief cap. `{reports}` = the ABSOLUTE path of `{worktree_dir}/.reports` in the main checkout. **Planning worktrees:** every planning role writes only in `{worktree_dir}/{ROLE}-{topic}` on the branch its template names (`{ROLE}` = `PRODUCT`, `ANALYST`, `ARCHITECT`, `DESIGNER`, `CLOUD`, `DEVOPS`; `ARCH` for a ruling), which you create from `main` before the dispatch (`git worktree add -b {branch} {path} main`, `{base sha}` = the `main` it was cut from) and, after verifying the report, merge into `main` with `--no-ff` from the main checkout and remove (start.md planning phase; rulings reference) — planning roles never work in the main checkout. The one exception is the Init Rules Session, which runs where /agent-sdlc:init started it. Agents read `docs/state/` and PM-only documents at their main-checkout path, everything else through their worktree. `{K}` = the number in `{MS-ID}` = `{PREFIX}-MS-{K}`; it names `docs/reports/demo-slice-{K}.md` and `docs/reports/milestone-{K}-recut.md`, which the Product Manager writes in its planning worktree and which reach `main` with your merge. `DISCIPLINE` names the skill a teammate loads with the Skill tool when its `skills:` frontmatter is not applied — never strip it.

| Template | Lane | Use when |
|---|---|---|
| Product Manager — initial planning | both | no BRDs exist |
| Product Manager — refinement (after epic completion) | both | an epic went `done` and no milestone plan is live (batch-end reference, step 10; classic Deploy flow) |
| Product Manager — milestone | both | a `planned` milestone with `slice_doc: null` (milestones reference, section 3, step 1) |
| Product Manager — milestone recut | both | a recut check failed, or a `pulled in whole` verdict names an epic no block recut (milestones reference, sections 3–4) |
| System Analyst | both | an epic in `planning` — its breakdown |
| System Analyst — milestone slice | both | after Product Manager — milestone (milestones reference, section 3, step 2) |
| System Analyst — amendment pass | both | the Architect's Design Mode report lists stories its design changed |
| System Analyst — one story from a ruling | both | a ruling's "Builds it" says `needs a new story` — ID reserved first (rulings reference, New scope) |
| Architect — Design Mode | both | an epic's design during planning; a slice's `## Design owed` |
| Architect — Design Mode, gate upgrade | fast | the project switches `process.lane` to `fast` and `.claude/rules/quality-gate.md` lacks any of §Whole-tree checks, §Per story, §Review and merge, §Batch end (start.md epic start counts them) |
| Architect — Init Rules Session (interactive, dispatched from /agent-sdlc:init) | — | /agent-sdlc:init, Phase 3 |
| Architect — Review Mode | both | Cloud Architect / DevOps Engineer output to gate |
| Architect — ruling (F8) | both | a trigger of the rulings reference's When table |
| Architect — batch-end notes triage | fast | batch end, notes routed to the Architect (batch-end reference, step 2b) |
| Cloud Architect | both | the infrastructure phase (start.md planning phase, step 5a) |
| DevOps Engineer | both | the infrastructure phase, after the Cloud Architect (step 5b) |
| Designer | both | an epic whose stories imply user-facing surfaces (start.md planning phase, step 4) |

---

## Product Manager — initial planning

```text
Plan the product into business requirements.

WHY: The project has no BRDs yet. Your BRDs and epics become the backbone every later agent builds on.

MODE: Initial planning
WORKTREE: {worktree_dir}/PRODUCT-initial, branch product/initial, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS (read in this order):
1. docs/project.md — the product description
2. docs/state/project.json — prefix and counters (main checkout, READ ONLY — report new counter values, do not write)
3. docs/templates/brd-template.md, epic-template.md, content-plan-template.md
Do NOT read: source code, docs/state/active.json or backlog.json (nothing is registered yet).

DISCIPLINE:
- Your workflow is the preloaded brd-writing skill, Initial planning mode — follow it exactly, its "Where you work" law included.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record; report what should be registered and I will write state.
- Commit as `{PREFIX}-BRD-{N}: {description} [by Product Manager]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: BRD files + epic files (+ content plans if the product needs content) + docs/glossary.md (the ubiquitous language), committed on product/initial, and the report below.

VERIFICATION: I will check every FILES entry exists on product/initial, docs/glossary.md is present, epics reference real BRDs, priority rationale is stated; no `docs/state/` path in `git diff --name-only main...product/initial`; attribution-trailer count 0 in your commits.

REPORT: the envelope from your skill, OUTCOME: PLANNED | BLOCKED, under {cap} characters. DETAILS: each BRD/epic/content-plan ID + title + priority order + new counter values.
```

## Product Manager — refinement (after epic completion)

```text
Refine the backlog after completing {EPIC-ID}.

WHY: {EPIC-ID} ({title}) just shipped. Delivered scope may change priorities or reveal new requirements.

MODE: Refinement
WORKTREE: {worktree_dir}/PRODUCT-{EPIC-ID}-refine, branch product/{EPIC-ID}-refine, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.
CARRIED IN: {user feedback or the Architect's NEEDS_REQUIREMENTS_FIX defects, quoted | none}.

INPUTS: docs/issues/{EPIC-ID}-{slug}/epic.md (+ story list), docs/state/epics.json (main checkout, READ ONLY), docs/requirements/ BRDs.

DISCIPLINE:
- Your workflow is the preloaded brd-writing skill, Refinement mode.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: {description} [by Product Manager]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: updated/new BRDs and epics (if warranted) committed on your branch; recommended priority_order; report.

VERIFICATION: every recommendation must name evidence from the delivered epic; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: REFINED | NO_CHANGES | BLOCKED, under {cap} characters. In DETAILS: recommended priority_order and any new IDs with rationale.
```

## Product Manager — milestone

```text
Plan milestone {MS-ID}: the demo slice, the epics that deliver it, the recuts.

WHY: The user defined {MS-ID}; its demo must be planned as whole epics before its first item starts.

MODE: Milestone
WORKTREE: {worktree_dir}/PRODUCT-{MS-ID}, branch product/{MS-ID}, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.
CARRIED IN: the user's words, verbatim — title: {title}; goal / demo: {goal}; target: {YYYY-MM-DD | none}.

INPUTS:
- docs/state/epics.json, backlog.json, active.json (main checkout, READ ONLY — your skill's reads); docs/templates/demo-slice-template.md, epic-template.md; the epic.md and BRD of each candidate epic; docs/project.md.
- Accepted uncut exceptions: {ITEM-IDs the user accepted uncut — exactly these, never widened | none}.
- Reserved epic IDs for remainders: {{PREFIX}-EPIC-{c+1} … {PREFIX}-EPIC-{c+n} — milestones reference, section 3, step 1}.
- System Analyst verdicts and final count: {the SLICED report's verdict and final-count lines — in docs/reports/demo-slice-{K}.md | none yet}.
- Deferred hardening epic: {EPIC-ID | none}.
Do NOT read: source code, other milestones' documents, docs/state/archive/.

DISCIPLINE:
- Your workflow is the preloaded brd-writing skill, Milestone mode — every partially contributing epic recut (its Milestone recut steps 1–4); the RECUT and MILESTONE blocks verbatim.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Plan milestone {MS-ID} — demo slice and recut [by Product Manager]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE, committed on product/{MS-ID}: docs/reports/demo-slice-{K}.md from the template, every section filled; docs/reports/milestone-{K}-recut.md when anything was recut; each remainder's epic.md and the `**Continued by:**` lines.

VERIFICATION: I will check docs/reports/demo-slice-{K}.md on your branch with a Final count; every partial epic recut or listed as an accepted exception; the RECUT and MILESTONE blocks present, their JSON parsing with jq; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill (ITEM: {MS-ID}), OUTCOME: MILESTONE_PLANNED | BLOCKED, under {cap} characters. DETAILS ends with the RECUT block (when anything was recut), then the MILESTONE block.
```

## Product Manager — milestone recut

```text
Recut {EPIC-IDs} for {MS-ID}: each milestone part keeps its epic's ID; each remainder becomes a new epic.

WHY: {EPIC-IDs} give {MS-ID} some but not all of their items; a milestone is delivered and shown as whole epics.

MODE: Milestone recut
WORKTREE: {worktree_dir}/PRODUCT-{MS-ID}-recut, branch product/{MS-ID}-recut, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS:
- The milestone part per epic: {docs/reports/demo-slice-{K}.md, `## Placement` | {EPIC-ID}: {ITEM-IDs}; …}.
- Reserved epic IDs: {{PREFIX}-EPIC-{…} …}. 
- Each epic's epic.md and its items (your skill's read of docs/state/backlog.json and active.json, main checkout, READ ONLY); docs/templates/epic-template.md.
Do NOT read: source code; story files beyond the moved items' `**Epic:**` lines.

DISCIPLINE:
- Your workflow is the preloaded brd-writing skill, Milestone recut mode — an item not `todo` never moves.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Recut {EPIC-IDs} for {MS-ID} [by Product Manager]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE, committed on product/{MS-ID}-recut: one remainder epic.md per recut epic, `**Continued by:**` on each original, the moved stories' `**Epic:**` lines, docs/reports/milestone-{K}-recut.md.

VERIFICATION: I will check the recut document and each remainder epic.md on your branch; the RECUT block's EPIC JSON parses with jq; every MOVE item is `todo`; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill (ITEM: {MS-ID}), OUTCOME: RECUT | BLOCKED, under {cap} characters. DETAILS: the RECUT block — or `RECUT: see docs/reports/milestone-{K}-recut.md` when it would pass the cap.
```

## System Analyst

```text
Break epic {EPIC-ID} into stories and use cases.

WHY: {one sentence from the epic — what the feature delivers}.

MODE: Breakdown
WORKTREE: {worktree_dir}/ANALYST-{EPIC-ID}, branch analyst/{EPIC-ID}, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: docs/requirements/{BRD-ID}-{slug}.md, docs/issues/{EPIC-ID}-{slug}/epic.md, docs/templates/use-case-template.md + story-template.md (+ content-task-template.md for content epics), docs/state/project.json for prefix/counters (main checkout, READ ONLY).
Do NOT read: other epics' stories.

DISCIPLINE:
- Your workflow is the preloaded story-breakdown skill, breakdown workflow.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record — report the entries to register and I will write them.
- Commit as `{EPIC-ID}: Break down into stories and use cases [by System Analyst]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: use-case files + story files committed (each story with a **Tier:** line from your skill's tier table), and in DETAILS the exact JSON entry per story (schema from your skill — kind, tier, returns included) for me to register.

VERIFICATION: each story maps to ≥1 use case, has testable acceptance criteria, has a tier, and passes your skill's sizing signals; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: BROKEN_DOWN | NEEDS_PRODUCT_INPUT | BLOCKED, under {cap} characters — registration entries that would pass the cap go to REPORT FILE {reports}/{EPIC-ID}-registration.json (one JSON object), named in the envelope. NEEDS_PRODUCT_INPUT must name the ambiguity — I will re-dispatch Product Manager.
```

## System Analyst — milestone slice

```text
Slice {MS-ID}: one verdict per prerequisite, and the final count.

WHY: {MS-ID}'s demo items need capabilities from items outside the slice; each must be settled before the first item starts, and your count becomes the milestone's planned_count.

MODE: Milestone slice
WORKTREE: {worktree_dir}/ANALYST-{MS-ID}, branch analyst/{MS-ID}, cut from main at {base sha} — it holds docs/reports/demo-slice-{K}.md: {yes | no}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.
CARRIED IN: {the demo steps, when no slice document exists yet | none}.

INPUTS: {docs/reports/demo-slice-{K}.md | the demo steps above}; prerequisites: {prerequisite — consuming {ITEM-ID} ← providing {ITEM-ID}; … | those the slice document lists}; their story files; docs/glossary.md.
Do NOT read: other stories.

DISCIPLINE:
- Your workflow is the preloaded story-breakdown skill, Milestone slice mode — a minimal slice is written into BOTH story files.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Slice {MS-ID} — prerequisite verdicts [by System Analyst]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: one verdict per prerequisite; every minimal slice in both story files; the verdicts and the count in the slice document when your worktree holds it — committed on your branch.

VERIFICATION: I will check one `verdict:` line per named prerequisite and the `final count:` JSON (parses with jq); both story files of every minimal slice in your branch's diff; no `docs/state/` path; attribution-trailer count 0.

REPORT: the envelope from your skill (ITEM: {MS-ID}), OUTCOME: SLICED | NEEDS_PRODUCT_INPUT | BLOCKED, under {cap} characters. DETAILS: your mode's fixed lines — `verdict:` per prerequisite, then `final count: {"epics": {E}, "items": {I}}`.
```

## System Analyst — amendment pass

```text
Amendment pass for {EPIC-ID}: amend {STORY-IDs} where the Architect's design changed them.

WHY: Design Mode for {EPIC-ID} changed these stories; a story that disagrees with the design becomes a guess in implementation.

MODE: Amendment pass
WORKTREE: {worktree_dir}/ANALYST-{EPIC-ID}-amend, branch analyst/{EPIC-ID}-amend, cut from main at {base sha} (the design merged at {design merge sha}). Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.
CARRIED IN: {the Architect's DETAILS lines naming story and tier changes | none}.

INPUTS: the listed stories: {story file paths}; the use cases they reference; the design's changes: `git diff {design merge sha}^1 {design merge sha} -- docs/issues/{EPIC-ID}-{slug}/`; {ADR paths | none}.
Do NOT read or edit: any other story.

DISCIPLINE:
- Your workflow is the preloaded story-breakdown skill, Amendment pass mode — it creates no stories.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Amend {STORY-IDs} after the {EPIC-ID} design [by System Analyst]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: each listed story amended where the design changed it (ACs, a Technical Notes pointer, the Tier line), committed on your branch.

VERIFICATION: I will check `git diff --name-only main...analyst/{EPIC-ID}-amend` lists only the named stories and their use cases; one DETAILS line per story; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: AMENDED | NEEDS_PRODUCT_INPUT | BLOCKED, under {cap} characters. DETAILS: your mode's line per story; any tier change (I update state).
```

## System Analyst — one story from a ruling

```text
Cut story {STORY-ID} (ID reserved) into {EPIC-ID} from the ruling {ADR path}.

WHY: The Architect's ruling on {question id} needs new scope that no existing story holds.

MODE: One story from a ruling
WORKTREE: {worktree_dir}/ANALYST-{STORY-ID}, branch analyst/{STORY-ID}, cut from main at {base sha} (the ruling merged at {ruling merge sha}). Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: the ruling {ADR path}; docs/issues/{EPIC-ID}-{slug}/epic.md; the use case the new scope extends: {path | none}; docs/templates/story-template.md; docs/glossary.md.
Do NOT read: other stories, other epics.

DISCIPLINE:
- Your workflow is the preloaded story-breakdown skill, One story from a ruling mode — exactly one file.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Cut {STORY-ID} from ruling {ADR file name} [by System Analyst]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: docs/issues/{EPIC-ID}-{slug}/{STORY-ID}-{slug}.md from the story template, committed on your branch; its registration JSON in DETAILS.

VERIFICATION: I will check `git diff --name-only main...analyst/{STORY-ID}` lists exactly that one file; the JSON parses with jq and carries {STORY-ID}; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: STORY_CUT | NEEDS_PRODUCT_INPUT | BLOCKED, under {cap} characters. DETAILS: the registration JSON; `counters consumed: none — ID reserved by the PM`.
```

## Architect — Design Mode

```text
Design the architecture for {EPIC-ID} and codify the project rules.

WHY: Developers implement exactly what your rules and technical notes say; gaps become guesses.

MODE: Design Mode · project lane: {process.lane: fast | classic}
WORKTREE: {worktree_dir}/ARCHITECT-{EPIC-ID}, branch architect/{EPIC-ID}, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: docs/project.md, docs/requirements/ (BRDs + use cases for this epic), docs/issues/{EPIC-ID}-{slug}/ (epic + stories), existing rules in .claude/rules/, existing specs (openspec spec list, if OpenSpec is installed); the quality-gate seed `${CLAUDE_PLUGIN_ROOT}/templates/rules/quality-gate.md` (structure only).

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Design Mode. Rules you write go to .claude/rules/ (NOT docs/rules/).
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID}: Define architecture for {feature} [by Architect]` / `{PREFIX}: Update architecture rules [by Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: (1) .claude/rules/architecture.md + .claude/rules/quality-gate.md with EXACT project commands — both MANDATORY — in every section, §Whole-tree checks and §Per story included, in every project (quality-gate.md §Lanes); (2) domain rules customized for the stack; (3) ## Technical Notes in every story of the epic, and a corrected **Tier:** line where your design reveals a critical signal the Analyst missed (list every tier change in DETAILS — I update state); (4) ## Architecture Notes in epic.md; (5) in DETAILS, `stories changed: {story IDs whose file you edited (tier, ACs, notes pointers) | none}` — they get an amendment pass. All committed on your branch.

VERIFICATION: I will check architecture.md and quality-gate.md exist on your branch, quality-gate.md contains runnable commands (no {placeholders} left) in every section, §Per story and §Whole-tree checks included, and every story has Technical Notes; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: DESIGNED | NEEDS_REQUIREMENTS_FIX | BLOCKED, under {cap} characters. NEEDS_REQUIREMENTS_FIX names the BRD/story defects — I will loop Product Manager/Analyst and re-dispatch you.
```

## Architect — Design Mode, gate upgrade

```text
Upgrade .claude/rules/quality-gate.md for the fast lane: add and fill §Whole-tree checks, §Per story and the other fast-lane sections.

WHY: The project switches process.lane to fast; a fast epic cannot start while quality-gate.md lacks its fast-lane sections.

MODE: Design Mode — gate upgrade{ (with {EPIC-ID}'s design) | (no epic)}
WORKTREE: {worktree_dir}/ARCHITECT-gate-upgrade, branch architect/gate-upgrade, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: .claude/rules/quality-gate.md; the seed `${CLAUDE_PLUGIN_ROOT}/templates/rules/quality-gate.md` (its sections); .claude/rules/architecture.md; the test roots: {test directories}.
Do NOT read: stories, epics (unless an epic is named above).

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Design Mode, Gate upgrade — the existing commands move unchanged, never weakened; the placeholder check.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Update architecture rules [by Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: quality-gate.md with the seed's §Lanes, §Whole-tree checks, §Per story, §Review and merge, §Batch end and §Enforcement, every command exact, committed on your branch.

VERIFICATION: on your branch, `grep -c '^## Per story' .claude/rules/quality-gate.md` → 1, the placeholder grep prints nothing (or only literal braces named in DETAILS), and EVIDENCE shows the missing-command check printed nothing; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: DESIGNED | BLOCKED, under {cap} characters. EVIDENCE: the placeholder-grep count; `gate upgrade: missing-command check printed nothing` (your skill's command-loss check); the rules budget.
```

## Architect — Init Rules Session (interactive, dispatched from /agent-sdlc:init)

```text
Co-shape the project rules with the user before the pipeline starts.

WHY: rules agreed with the user up front save rejection loops later; the user knows constraints no file states yet.

MODE: Init Rules Session (interactive)
WORKTREE: none — you run where /agent-sdlc:init started you, before any pipeline runs (your skill's "Before any work", step 1).

INPUTS: docs/project.md, the seeded .claude/rules/ (all files), existing code/config if any (detect the stack).

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Init Rules Session mode — its gate procedure is mandatory: full picture in one message, "What would you adjust?", no tool calls in the gate response, full re-presentation after corrections. The user is present — talk to them.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{PREFIX}: Customize project rules with user [by Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never force-push, never skip hooks.
{standing lines}

DELIVERABLE: agreed customizations applied to .claude/rules/ (+ quality-gate.md filled if the stack is known), committed.

VERIFICATION: I will check the commit exists (attribution-trailer count 0) and quality-gate.md's state matches your report.

REPORT: the envelope from your skill, OUTCOME: RULES_CONFIGURED | BLOCKED, under {cap} characters. In DETAILS: decisions made, rules changed/deleted/added, remaining placeholders.
```

## Architect — Review Mode

```text
Review {scope: infrastructure designs | implementation} against the architecture rules.

WHY: {what is being gated, e.g. "Cloud/DevOps output must comply with the rules before implementation starts"}.

MODE: Review Mode
WORKTREE: {the author's planning worktree, e.g. {worktree_dir}/DEVOPS-{topic}, branch devops/{topic}} — read-only for you; you write nothing.

INPUTS: {artifact paths to review}, .claude/rules/ (all).

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Review Mode. Read-only on the reviewed artifacts.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
{standing lines}

DELIVERABLE: verdict per your skill's severity discipline.

VERIFICATION: I will check EVIDENCE names the rules the artifacts were checked against; every finding cites a rule file; FILES: none.

REPORT: the envelope from your skill, OUTCOME: APPROVED | REJECTED | BLOCKED, under {cap} characters. If REJECTED, DETAILS carries the findings list (file, what, which rule, fix) — I will store it and re-dispatch the author.
```

## Architect — ruling (F8)

```text
Rule on {question id: N-{n} | FU-{n} | {ITEM-ID} BLOCKED | ordering}: {the question, one sentence}.

WHY: {how the question arose — a review note, a Developer's BLOCKED report — and what builds on it or waits for it}.

MODE: Ruling — {{ITEM-ID} is BLOCKED | before {ITEM-ID} is dispatched | pre-ruling before {ITEM-ID} | ordering: {ITEM-IDs}}
WORKTREE: {worktree_dir}/ARCH-{topic}, branch architect/{ITEM-ID}-{topic}, cut from main at {base sha}. Docs, rules and ADRs only — never code. I merge the branch into main with `--no-ff`.
REPORTS: {reports} — logs and report files go here, outside every worktree.
CARRIED IN: {BLOCKED: the Developer's BLOCKERS line, verbatim | —} THE OPTIONS — (a) {…}; (b) {…}; (c) something better. WEIGH AGAINST: {ADR ids, rule files, size, what the system already refuses}.

INPUTS: {the saved review and its note: docs/reviews/{ITEM-ID}-{n}.md, N-{n} | the Developer's BLOCKERS in CARRIED IN}; {ADR paths | none}; {rule files, by section}; code read-only via `git show origin/{branch}:{path}` — never check a branch out. ADR directory: {path | none — your skill's default}; the ADR to amend: {path | none — a new ADR}. Rule files to change: {paths}.
Do NOT read: the full rules tree, other epics.

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Ruling mode — a concrete verdict for every option, then exactly one decision; "Builds it" and "Meanwhile".
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Content guard: {command from quality-gate.md Step 0 | not declared} — exit 0 on every file you touched, before the commit.
- Commit exactly one ruling commit as `{PREFIX}: {description} [by Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE, one commit on your branch, pushed: 1. the ruling as a new ADR or an amendment, every section; 2. the rule text in the rule files named above; 3. Builds it: {an existing ITEM-ID | needs a new story | none — rule only}, and Meanwhile: what {the waiting item} does until then.

VERIFICATION: I will check `git diff --name-only main...architect/{ITEM-ID}-{topic}` lists docs, rules and ADRs only (count of other paths 0); the ruling commit SHA; attribution-trailer count 0; the content-guard line.

REPORT: the envelope from your skill (ITEM: {ITEM-ID}), OUTCOME: DESIGNED | NEEDS_REQUIREMENTS_FIX | BLOCKED, near 1,200 characters: the ruling in two sentences; files changed; the commit SHA; Builds it; Meanwhile.
```

## Architect — batch-end notes triage

```text
Triage the rule notes of {EPIC-ID} batch {n}: rule on each, or say why it is not a rule.

WHY: The batch end resolves every note; rule-gap and rule-text notes need the Architect, and you run beside the batch-fix Developer.

MODE: Ruling — Notes triage (batch end)
WORKTREE: {worktree_dir}/ARCH-{EPIC-ID}-notes, branch architect/{EPIC-ID}-notes, cut from main at {base sha}. Docs, rules and ADRs only — never code. I merge the branch into main with `--no-ff`.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: docs/reviews/{EPIC-ID}-notes.md (main checkout; never edit it) — lines {N-ids | none named: your skill's grep for the open `rule gap` / `rule text` lines}; the saved reviews those lines cite; the rule files they name, by section.
Do NOT read: the other notes, stories; source beyond `git show origin/{feature-branch}:{path}` for a file a note names.

DISCIPLINE:
- Your workflow is the preloaded architecture-design skill, Ruling mode — Notes triage: one outcome per note.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Content guard: {command from quality-gate.md Step 0 | not declared} — exit 0 on every file you touched, before the commit.
- Commit (only when something was ruled) as `{PREFIX}: Rule {EPIC-ID} batch notes [by Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Push plainly; never force-push, never skip hooks.
{standing lines}

DELIVERABLE: one outcome per note; the rule text of every ruled note in one commit on your branch, pushed.

VERIFICATION: I will check one DETAILS line per named N-id; `git diff --name-only main...architect/{EPIC-ID}-notes` lists docs, rules and ADRs only; attribution-trailer count 0; the content-guard line.

REPORT: the envelope from your skill (ITEM: {EPIC-ID}), OUTCOME: DESIGNED | NEEDS_REQUIREMENTS_FIX | BLOCKED, near 1,200 characters. DETAILS: one line per note — `N-{n}: ruled — {rule file} ({sha})` | `N-{n}: not a rule — {why}`.
```

## Cloud Architect

```text
Design the cloud infrastructure for {project | EPIC-ID}.

WHY: {deployment goal, e.g. "the product deploys to {env list} and DevOps implements from your design"}.

WORKTREE: {worktree_dir}/CLOUD-{EPIC-ID | project}, branch cloud/{EPIC-ID | project}, cut from main at {base sha}. Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: docs/project.md, .claude/rules/ (root + infra/), docs/issues/{EPIC-ID}-{slug}/epic.md architecture notes, docs/state/environments.json (target environments; main checkout, READ ONLY).

DISCIPLINE:
- Your workflow is the preloaded cloud-design skill.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID | PREFIX}: Define cloud architecture for {feature} [by Cloud Architect]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: .claude/rules/infra/cloud-architecture.md (design + service selection rationale + security + cost model), committed on your branch.

VERIFICATION: the rule file exists on your branch, names concrete services, and states cost assumptions; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: DESIGNED | NEEDS_ARCHITECTURE_FIX | BLOCKED, under {cap} characters.
```

## DevOps Engineer

```text
Implement CI/CD and infrastructure for {project | EPIC-ID}.

WHY: implements the Cloud Architect's design so deployments are reproducible.

WORKTREE: {worktree_dir}/DEVOPS-{EPIC-ID | project}, branch devops/{EPIC-ID | project}, cut from main at {base sha} (the cloud design merged at {sha}). Write ONLY there; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: .claude/rules/infra/ (including cloud-architecture.md), .claude/rules/quality-gate.md, docs/state/environments.json (main checkout, READ ONLY), project configuration files.

DISCIPLINE:
- Your workflow is the preloaded infra-implementation skill.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID | PREFIX}: Implement infrastructure for {feature} [by DevOps Engineer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: Dockerfiles / CI pipelines / IaC per the design, committed on your branch; quality-gate commands runnable in CI.

VERIFICATION: I will check the FILES exist on your branch and EVIDENCE shows validation output (builds, IaC validation — counts and exit codes); no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: IMPLEMENTED | NEEDS_DESIGN_FIX | BLOCKED, under {cap} characters.
```

## Designer

```text
Design the UI/UX for {EPIC-ID}: {STORY-IDs}.

WHY: {user-facing goal of the epic}.

MODE: {interactive — user available | autonomous — --no-human, decide per your skill's defaults and record decisions}
WORKTREE: {worktree_dir}/DESIGNER-{EPIC-ID}, branch designer/{EPIC-ID}, cut from main at {base sha}. Write ONLY there — previews included; I merge the branch into main.
REPORTS: {reports} — logs and report files go here, outside every worktree.

INPUTS: docs/issues/{EPIC-ID}-{slug}/ stories + use cases, BRD {BRD-ID}, .claude/rules/frontend/ (design system rules if present).

DISCIPLINE:
- Your workflow is the preloaded ui-design skill — its gates are mandatory in interactive mode.
- Do not re-read rule files already in your context; read large files by section. Evidence per `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- Never edit `docs/state/*.json`, a notes file, a follow-ups file or a bug record.
- Commit as `{EPIC-ID}: Create UI/UX designs for {feature} [by Designer]`. A hook denies attribution trailers; this project's rule overrides the harness's commit template. Never skip hooks; do not push or merge — I merge your branch.
{standing lines}

DELIVERABLE: design notes in stories (## Design section), design-system rule updates if needed, committed on your branch.

VERIFICATION: I will check every listed story has a ## Design section on your branch; no `docs/state/` path in your branch's diff; attribution-trailer count 0.

REPORT: the envelope from your skill, OUTCOME: DESIGNED | BLOCKED, under {cap} characters. In DETAILS: decisions made (autonomous mode) or user-approved options (interactive).
```
