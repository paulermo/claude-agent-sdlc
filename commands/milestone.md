---
name: "agent-sdlc:milestone"
description: "Define, edit or list milestones (writes a directive; the PM applies it)"
---

Define, edit or list milestones outside a `/agent-sdlc:start` loop. `new` and `edit` run the milestone dialogue and leave a **directive** for the PM; `list` shows each milestone's progress. The milestone machine, schema and transitions are law in `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-state/SKILL.md` (sections 4–7); the dialogue, the directive format and the progress computation live in `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/milestones.md`.

**LAW — this command never writes `docs/state/`** — not an entry, not a counter, not a log line, not "just the milestone". The one file it writes is the directive; the PM applies it at the next `/agent-sdlc:start` (Step 2). WHY: only the PM session writes state (single writer, sdlc-state section 1) — a second writer races its commits and skips its log line and both-sides link rule.

**Argument:** `$ARGUMENTS` — `new` | `edit {PREFIX}-MS-{K}` | `list`. Empty → `list`. Anything else → print `Usage: /agent-sdlc:milestone [new | edit {PREFIX}-MS-{K} | list]` and stop.

## Step 1: Preconditions

| Check | Command | Pass | On failure |
|-------|---------|------|------------|
| Project initialized | `test -f docs/state/project.json; echo "exit=$?"` | `exit=0` | "SDLC not initialized. Run `/agent-sdlc:init` first." — stop |
| State knows milestones (2.0) | `jq -r 'has("milestones")' docs/state/epics.json 2>/dev/null` | `true` | "This project's state predates agent-sdlc 2.0 (no milestones in `docs/state/epics.json`). Run `/agent-sdlc:init` to repair it, then retry." — stop |
| `new` / `edit` only: the main checkout (not a linked worktree) | `[ "$(git rev-parse --git-dir)" = "$(git rev-parse --git-common-dir)" ]; echo "exit=$?"` | `exit=0` | "Run this in the project's main checkout, on `main` — the PM reads directives there; a directive written in a worktree never reaches it." — stop |
| `new` / `edit` only: on `main` | `git branch --show-current` | `main` | the same message — stop |

## Step 2: `list` (also the default)

Read-only: no file is written, nothing is committed.

1. IDs: `jq -r '.milestone_order[]' docs/state/epics.json`. Nothing printed → output `No milestones yet. Define one: /agent-sdlc:milestone new`, then step 5's pending line, and stop.
2. Read `docs/state/epics.json` (titles, targets, `planned_count`, each linked epic's `batch`, `held`).
3. Read `${CLAUDE_PLUGIN_ROOT}/commands/status.md` and apply ONLY: its step 4 (the progress command of the milestones reference section 6, run once per ID in `milestone_order`; the two held commands) and, from its step 8, the Milestones lines of the output template, **The Milestones block** rules, and the `{batch stage}` label table. The format is defined there once — this command prints the same block, computed the same way. Never compute progress by hand.
4. Each in-flight item's epic (status.md's `in flight` rule needs it) — instead of reading `active.json`:
   `jq -r '[(.stories // {}), (.content_tasks // {}) | to_entries[] | select(.value.status | IN("in_progress","creating","in_review","in_qa","integrating")) | "\(.key) \(.value.epic)"] | .[]' docs/state/active.json`
5. Pending milestone directives (written but not yet applied): `find docs/directives/active -name '*-milestone-*.md' 2>/dev/null | sort`.
6. Output exactly:

   ```
   Milestones:
     {one entry per milestone, in milestone_order — status.md's Milestones block, line for line}
   Pending milestone directives (applied at the next /agent-sdlc:start): {file name}, {file name} | none
   ```

## Step 3: `new` and `edit {MS-ID}` — the dialogue

1. **Load the dialogue** — the questions, the entry presentation, the gate with its acceptance tokens, and the directive format:
   `sed -n '/^## 1\. Create or edit in dialogue/,/^## 3\. Planning a milestone/p' ${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/milestones.md` (prints nothing → Read that file's sections 1 and 2). Its "On acceptance — PM session" steps are the PM's and write state — NEVER run them; your acceptance is Step 4 below.
2. **Facts** (read-only, before the first question):
   - `{PREFIX}`: `jq -r '.prefix' docs/state/project.json`
   - `new`: `{K}` = `counters.milestone` + 1 + the pending `new` directives — `jq -r '.counters.milestone // 0' docs/state/project.json` and `find docs/directives/active -name '*-milestone-*.md' -exec cat {} + 2>/dev/null | grep -c '^milestone: new'` (read the printed count, never the exit status). `{K}` is a forecast: the PM assigns the ID when it applies the directive.
   - `edit`: the milestone — `jq -r --arg id '{MS-ID}' '.milestones[$id] // "MISSING" | if type == "object" then "\(.status) | \(.title) | \(.goal) | \(.target // "none") | epics: \(if (.epics | length) == 0 then "none" else (.epics | join(", ")) end) | stories: \(if (.stories | length) == 0 then "none" else (.stories | join(", ")) end)" else . end' docs/state/epics.json`. `MISSING` → output "Unknown milestone {MS-ID}. Defined: {milestone_order, comma-separated | none}. A milestone defined by a directive gets its ID only when the PM applies it." and stop. Linked epics' titles: `jq -r --arg id '{MS-ID}' '. as $ix | .milestones[$id].epics[] | "\(.) \($ix.epics[.].title // "(done, archived)")"' docs/state/epics.json`.
   - `edit`: a pending directive for the same milestone — `find docs/directives/active -name '*-milestone-*.md' -exec grep -l '^milestone: edit {MS-ID}$' {} + 2>/dev/null`. A file name printed → output "A directive for {MS-ID} is still pending: {file}. The PM applies it at the next `/agent-sdlc:start`; edit again after that, or delete that file first." and stop. WHY: `epics:` and `stories:` carry the complete list, so a second edit built from state would silently undo the first one's links.
3. **Ask** — one question per message, each message ends with the question and makes no tool calls:
   - `new`: the reference's three questions (name → goal/demo → target), asking ONLY for what the user has not already given (in the arguments or the conversation).
   - `edit`: one message showing the current values, then the reference's edit question:

     > ## Milestone {MS-ID} — {title} (current, {status})
     > **Goal / demo:** {goal}
     > **Target:** {YYYY-MM-DD | none}
     > **Epics:** {EPIC-ID title, … | none}
     > **Stories (uncut exception):** {ITEM-IDs | none}
     >
     > What should change for {MS-ID}: the title, the goal, the target, or the linked epics / stories?

     An answer that names a field without its new value → ask for that value (one question). Apply the answer to a draft of the entry.
4. **Check every epic or story ID the user names** (read-only) before presenting it:
   - Epic → `jq -r --arg e '{EPIC-ID}' '.epics[$e] | if . == null then "ABSENT" else "\(.status) \(.milestone // "none") \(.title)" end' docs/state/epics.json` prints `{status} {milestone | none} {title}` or `ABSENT`.
   - Story (uncut exception) → `cat docs/state/active.json docs/state/backlog.json | jq -rs --arg s '{ITEM-ID}' '(map((.stories // {})[$s], (.content_tasks // {})[$s]) | map(select(. != null)) | first) as $x | if $x then "\($x.epic) \($x.status) \($x.milestone // "none")" else "ABSENT" end'` prints `{EPIC-ID} {status} {milestone | none}` or `ABSENT`; then run the epic check on its `{EPIC-ID}`.

   | Output | Action on the draft | Note for the presentation |
   |--------|---------------------|---------------------------|
   | epic `ABSENT` | drop it | `{EPIC-ID}: done (archived) or unknown — only epics not yet done can join a milestone` |
   | epic linked to another milestone | keep it | `{EPIC-ID}: the PM unlinks it from {other MS-ID} first — an epic belongs to one milestone` |
   | story `ABSENT` | drop it | `{ITEM-ID}: unknown or already delivered` |
   | story already in another milestone's `stories` (its `{milestone}` is another MS-ID) | keep it | `{ITEM-ID}: the PM unlinks it from {other MS-ID} first — an item belongs to one milestone` |
   | story whose epic has a milestone (any) | drop it | `{ITEM-ID}: its epic {EPIC-ID} is linked whole — the uncut exception is only for items of an epic not linked whole` |

5. **Present and gate** — the reference's entry presentation, FULL entry (never a delta), with `({new | edit})` and `{Create | Apply} it?`; `new` without named epics shows its "none yet" wording. When step 4 produced notes, add them as ONE line right above the closing question: `**Notes:** {note}; {note}`.

   **>>> GATE: user response required. Make NO tool calls in the same message as this question. <<<**
   Acceptable answers: the reference's tokens — "yes", "go", "create", "apply". "cancel" or "stop" → write nothing, output `No directive written.`, stop. Anything else is an edit: apply it to the draft, re-run step 4 for any new ID, re-present the FULL entry, gate again.

## Step 4: Write and commit the directive (after an acceptance token only)

1. `{date}`: `date -u +%Y-%m-%d`. `{slug}`: the title after the change in kebab-case — lowercase ASCII letters and digits, every other run of characters → one `-`, no leading or trailing `-`, at most 40 characters (cut at a `-`); transliterate a non-Latin title first (`Демо оплаты` → `demo-oplaty`); still empty → `milestone`.
2. Path `docs/directives/active/{date}-milestone-{slug}.md`. Taken (`test -e {path}; echo "exit=$?"` prints `exit=0`) → insert `-2`, then `-3`, … before `.md` until it is free. `mkdir -p docs/directives/active` first.
3. Write the file: exactly the six lines of the reference's section 2 format, nothing else —
   - `milestone: new` or `milestone: edit {MS-ID}`;
   - `new`: every field filled, never `unchanged`; no epics / stories → `none`; no target → `none`;
   - `edit`: an unchanged field → `unchanged`; a changed `epics:` / `stories:` → the COMPLETE list after the change (current list plus additions, minus removals; emptied → `none`), IDs joined with `, `.
   An `edit` whose six lines would all be `unchanged` → write nothing, output `Nothing changed — no directive written.`, stop.
4. Commit that one file by path, with exactly this message and no attribution trailer (`hooks/scripts/guard-commit.sh` denies trailers while `process.commit_attribution` is `false`; this project rule overrides the harness's default commit template):
   `git add -- {path} && git commit -m "{PREFIX}: Milestone directive {slug} [by user]" -- {path}`
   Evidence: `git log -1 --format='%h %s' -- {path}` prints `{sha} {PREFIX}: Milestone directive {slug} [by user]`.
5. Output exactly (the last line only for `new`):

   > Directive written: `docs/directives/active/{file}` (commit {sha}).
   > The PM applies it at the next `/agent-sdlc:start` (Step 2).
   > The milestone gets its ID then — expected {PREFIX}-MS-{K}.

## Situations

| Situation | Action |
|-----------|--------|
| The commit is denied by a hook (attribution or message prefix) | correct the message to the exact format of Step 4 and retry once; still denied → leave the file uncommitted, show the hook's reason, tell the user the PM still reads it from `docs/directives/active/` |
| `git` reports `index.lock` (another session is committing) | retry the commit once; still locked → leave the file uncommitted and tell the user (the PM reads the working tree) |
| The user asks to mark a milestone demoed | not this command's: `demoed` is set only on the user's word inside `/agent-sdlc:start` (milestones reference section 5) — tell the user to say it there, or write a free-text directive |
| The user asks to delete or drop a milestone | not supported — a milestone has no `dropped` status (sdlc-state section 4); offer an edit that unlinks its epics and stories |
| The user asks for `delivered` or `in_progress` | refuse: the PM computes those transitions (sdlc-state section 5) |

## MUST DO

- Refuse on a missing `docs/state/project.json`, a pre-2.0 `epics.json`, or (for `new` / `edit`) a checkout that is not `main`.
- Ask one question per message; end every question and the gate with no tool call.
- Write exactly the six directive lines, then commit only that path.

## MUST NOT DO

- Write, `jq`-edit or `git add` anything under `docs/state/` — not even the milestone counter; the tempting "I'll just add the entry, it's faster" is a second writer (the LAW above).
- Run the reference's "On acceptance — PM session" steps.
- Stage or commit anything but the directive (`git add -A`, `git add .`, a bare `git commit` sweep in other changes).
- Put an ID, or `unchanged`, into a `new` directive; put a partial list into `epics:` / `stories:` of an `edit`.
- Compute `list` progress by hand or with your own formula — status.md step 4 runs the reference's command.
