# Fast Lane (v2.0.0) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement C1–C26 and C29 of the hand-off spec as agent-sdlc 2.0.0, per the approved design record.

**Architecture:** Law stays in `skills/sdlc-state/SKILL.md` (one lane table, machines, schemas); `commands/start.md`
keeps the loop and dispatch map; epic-level procedures and per-role briefs move to on-demand references under
`skills/sdlc-dispatch/references/`. Two executable pieces ship with tests: the attribution hook and the runner
`run-step.sh`. The tracker gains a milestones view.

**Tech Stack:** Markdown plugin content (Claude Code skills/agents/commands), bash + jq (hooks, tooling, tests),
Python 3 stdlib (tracker server), vanilla JS/CSS (tracker UI).

**Read before any task:**
- `docs/plans/2026-09-29-fast-lane-design.md` — the design record (decisions override the spec where they differ).
- `docs/plans/2026-09-29-process-changes-handoff.md` — the spec (C1…C29, §4.x, Q1…Q19, Appendix A–G, F1–F12).
- `docs/authoring-standards.md` — how every plugin file is written (LAW vs DEFAULT, signal tables, verbatim output
  formats, MUST/MUST NOT, WHY clauses, one source of truth).

**Global rules for every task:**
1. Work only in `/Users/employee/paulermo/claude-agent-sdlc/.worktrees/v2.0-fast-lane`.
2. One source of truth: statuses, schemas, transitions and the lane table live ONLY in `skills/sdlc-state/SKILL.md`.
   Other files cite `sdlc-state` section numbers — never restate the machine.
3. Lane wording: "fast lane" / "classic lane"; the epic's `lane` stamp decides; absent = classic.
4. Keep classic behaviour byte-for-byte where the design says "unchanged": when a section gains a fast variant, keep
   the classic text and label it `(classic lane)`.
5. EMI project specifics never appear in plugin content: no "EMI", no host names, no provider names. Spec examples may
   be used only as generic WHY provenance ("a stale `.done` once read as a pass").
6. No emoji in plugin content except the literal default pattern `"🤖"` in `attribution_patterns`.
7. Commit after each task: `git add {files} && git commit -m "{message}"` with the trailer
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never `git add -A`.

---

## Wave 1 — the law and the foundations (sequential; the orchestrator writes these)

### Task 1: `skills/sdlc-state/SKILL.md` — the law

**Files:** Modify `skills/sdlc-state/SKILL.md` (whole file; today 366 lines).

**Sources:** design record §2, §3, §4, §5, §6, §7; spec §4.3, C3, C4, C7, C8, C21, C26, C29 (d) 1–2, Appendix B, C, G.

**Must contain (in this order of sections, keeping 1.6.1 numbering 1–7):**
- §1: PM-only documents list adds `docs/reviews/{EPIC-ID}-notes.md`, `docs/reports/{EPIC-ID}-batch-gate*.md`,
  `docs/reports/demo-slice-{N}.md`, `docs/reports/milestone-{N}-recut.md`. New LAW lines: the main checkout stays on
  `main` (the tracker reads its working tree); state is committed by path (`git commit -m "…" -- docs/state {files}`,
  never `git add` + bare commit — WHY: a bare commit once swept in an agent's 15 staged renames).
- §2: milestones live in `epics.json` and are never moved by the bucket law; an archived epic keeps its `milestone`;
  after a cut batch's delivery the epic returns to `in_progress` (items stay in active.json — no move).
- §3 envelope: optional `REPORT FILE: {path}` and `CONTINUE: {next task}` lines; targeted-set EVIDENCE lines carry
  `selected because {reason}`; the final message ≤ `process.report_max_chars` (absent: 3500); evidence rules cite
  `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`.
- §4: new first subsection **Lanes** — the lane table from the design record §2 verbatim (10 rows) + the stamp rule
  (stamped at `ready → in_progress`; absent = classic) + "the tier still decides lenses and IMPORTANT blocking".
  Story machine: keep the classic diagram labelled `(classic lane)`, add the fast diagram
  (`todo → in_progress → ready_for_review → in_review → ready_for_merge → done`, `review_rejected → in_progress (fix
  pass) → ready_for_merge (PM diff check)`). Kinds/tiers table: add a `Return budget (fast lane)` row = 1 at every tier
  and a `Bug path (fast lane)` row. Return budget and parking: the fast-lane trigger — a fix pass whose PM diff check
  finds a blocking finding still open is a REJECTED at budget → parked → budget gate. New subsection **Notes** (the
  file, what a NOTE is, Appendix B line format, the four resolutions, counter `note`, project-wide `N-{n}`).
  Follow-ups: project-wide `FU-{n}` from counter `followup`; optional `owner:`; closure text `— closed by {ID}: {how}`;
  the two `followups_gate` behaviours (`triage` table from C8 / `hygiene_bug` = 1.6.1). Epic: `ready_for_deploy` per
  lane (classic: 1.6.1 text; fast: the batch's full gate PASSED, notes resolved, follow-ups triaged); `deployed → done`
  by QA PASSED or by the `main_regression` decision line; `deployed → in_progress` after a cut batch with items left;
  the `batch` object semantics. New subsection **Milestone** machine (`planned → in_progress → delivered → demoed`,
  `delivered → in_progress` when a link is added; `demoed` only on the user's word).
- §5: keep every 1.6.1 row, add a `Lane` column (`both` / `classic` / `fast`). Add the fast rows from spec §4.3 (13
  rows) with these corrections: fast bug of tier light: `in_progress → ready_for_merge` (decision `review skipped: light
  bug`); fix-loop and merge-fix rows per design record §4–§5; batch-end rows keyed on `epic.batch.stage`; milestone rows
  (spec C29 (d) point 2) including the recut check before `planned → in_progress`; the fix-loop bound (after the 3rd red
  gate run: user gate "one more run" / "park the epic"; `--no-human` parks).
- §6 schemas: `process` block (every key of the design record §3 table, with the two presets as a table and the rule
  "absent keys read as the classic preset"); `integrations.runners`; counters `note`, `followup`, `milestone`;
  worktree entry gains `"stack": null` (values `null | "local" | "runner {NN} slot {x}"`); epic entry optional fields
  (`lane`, `batch`, `milestone`, `continued_by`, `base_branch`, `carries`, `delivers_after`) with an example; the
  milestone entry + `milestone_order` (spec C29 (d) point 1 JSON, valid JSON); an item's `milestone` field for the uncut
  exception; both sides of a milestone link written in the same response. Feedback table: add the batch-gate report and
  the notes file. Fix the invalid JSON in the worktree example (`{port}` → a number placeholder in a string or a
  legend) so the lint in Task 8 passes.
- §7: log vocabulary table (Appendix G) + fixed decision notes (`QA skipped: fast lane`, `regression QA skipped: fast
  lane`, `fix pass verified by the PM reading {range} against {findings}`, `fast-forward: {feature} {a}..{b}; worktree
  removed[; {ITEM} will need a real merge]`, `main regression QA skipped: …`, `main regression: {value}, {count} code
  paths → dispatched|skipped`, `delivery order: {X} before {Y}`, `batch cut: {members} — {reason}`, `merge queued
  behind {ID}'s`, `gate run {N} red: {step}`, `fix loop bound: {answer}`); `dispatch:` lines carry base sha, stack,
  model; `correction` lines; `decision: user`; `recut`; `item` may be a milestone ID. Commit conventions table adds:
  fix-branch commits (`{ITEM-ID}: {description} [by Developer]`), delivery merge
  (`{PREFIX}: Deliver {EPIC-ID}{ (…)} — {summary} [by Deploy]`), main-in (`{PREFIX}: Merge main into {EPIC-ID} for the
  batch end [by Deploy]`), and the rule "no attribution trailers — a hook enforces it when
  `process.commit_attribution` is false (C25)".
- MUST NOT: add "reading a runner log whose start token does not match as a pass", "registering a bug for a fast-lane
  merge failure or a red gate step", "moving milestones between files".

**Steps:**
1. Edit section by section in the order above.
2. Run: `awk '/^```json/{f=1;next}/^```/{if(f){print "---"};f=0}f' skills/sdlc-state/SKILL.md > /tmp/blocks.txt` and
   eyeball that every JSON block is valid JSON (Task 8's lint enforces it later).
3. Run: `grep -n 'Lane\|lane' skills/sdlc-state/SKILL.md | head -40` — the lane table appears once.
4. Commit: `sdlc-state: lane table, fast machines, notes, milestones, process schema (v2.0)`.

### Task 2: `templates/rules/quality-gate.md` — the two-level seed

**Files:** Modify `templates/rules/quality-gate.md`.

**Must contain:** the spec's §4.1 skeleton verbatim in structure (sections: intro, `## How the full gate runs`,
`## Step 0 — every change`, `## Path-to-command table (the full gate)`, `## Whole-tree checks`,
`## Per story: the targeted set`, `## Review and merge (per story)`, `## Batch end: the full gate`, `## Enforcement`),
keeping the SEEDED PLACEHOLDER blockquote, plus one line under the intro: "Classic lane (sdlc-state §4 Lanes): every
change runs the path-to-command table in full; §Per story, §Review and merge and §Batch end apply to the fast lane."
Step 0 row: "the content guard, if `process.content_guard` is declared". Keep the monorepo comment, rewritten for rows.
The "How the full gate runs" evidence bullet cites the evidence-and-shell reference by name.

**Steps:** write; `grep -c '^## ' templates/rules/quality-gate.md` → 9; commit
`quality-gate seed: two-level proof (targeted set per story, full gate per batch)`.

### Task 3: `skills/sdlc-dispatch/references/evidence-and-shell.md`

**Files:** Create it.

**Must contain:** spec C19 (b) as LAW: evidence definition; "a run that selected or evaluated nothing is red"; "quote
the last run that actually passed"; "only the gate's own targets are evidence"; "not present yet is red"; detached
steps (start tokens, `--expect`, empty log with exit 0 is red → `references/runners.md`); commit trailers are part of
the evidence check. A `## Shell rules (every shell)` section (read `$?` on the next line from the command itself —
never after a pipe/`&&`/`||`; `grep -c` exits 1 on a zero count — read the count; `type {tool}` before trusting a
gate tool; never a destructive command after `;` behind an `&&` chain; verify a loop's effects with a listing) and a
`## zsh additions (process.shell: zsh)` section (`pipestatus` indexed from 1; no word-splitting — arrays,
`read -r a b <<< "$pair"`; `"${REF}:path"`; `(N)` / `null_glob`; `git grep -E`). Each rule with a one-clause WHY. An
`Situation | Action` edge table (empty output, 0 tests selected, tool alias, stale cache). ≤ 90 lines.

**Steps:** write; commit `evidence-and-shell reference (C19)`.

### Task 4: New templates

**Files:** Create `templates/notes-file-template.md` (Appendix B), `templates/batch-gate-report-template.md`
(Appendix D), `templates/delivery-commit-template.md` (Appendix E), `templates/demo-slice-template.md` (spec C13 (b)
point 1 structure as headed sections with `{placeholders}`).

**Rules:** placeholders in `{braces}`; no project names; the delivery template's first line is
`{PREFIX}: Deliver {EPIC-ID}{ ({milestone}) | batch {n}} — {one-line behavior summary} [by Deploy]`.

**Steps:** write the four files; commit `templates: notes file, batch-gate report, delivery commit, demo slice`.

### Task 5: `commands/init.md`

**Files:** Modify `commands/init.md`.

**Must contain:**
- Phase 1 questions add: lane for new epics (default `fast`; suggest `classic` when the user says the full gate runs
  under ~2 minutes), shell (default from `basename "$SHELL"`), content guard command (optional), runners available
  (optional → `integrations.runners.enabled`).
- `project.json` template (2.5): the `process` block with the **fast preset** values (design record §3), counters
  `note`, `followup`, `milestone`, `integrations.runners: {"enabled": false, "tooling_dir": null, "inventory": null}`,
  `max_parallel_teammates` note "user-adjustable". Valid JSON.
- `epics.json` template: `{ "priority_order": [], "epics": {}, "milestones": {}, "milestone_order": [] }`.
- A new **2.5c Repair to v2.0** step (runs when `project.json` has no `process` key): add the classic preset; set
  `counters.followup` to the highest FU number found (`grep -rhoE 'FU-[0-9]+' docs/issues/*/followups.md 2>/dev/null |
  sed 's/FU-//' | sort -n | tail -1`, empty → 0); add `note: 0`, `milestone: 0`; add empty `milestones` /
  `milestone_order`; then ONE gate question: "New epics run on the classic lane (1.6 behaviour). Switch new epics to the
  fast lane?" with acceptance tokens; epics already in flight keep classic (no stamp = classic).
- 2.2 template copy list adds the four new templates.
- **Attribution settings** (when `commit_attribution` is false): write the project `.claude/settings.json` keys that
  disable Claude Code's commit/PR attribution — the orchestrator verifies the exact current key names
  (`attribution` / `includeCoAuthoredBy`) with the claude-code-guide agent before this task and passes them in.
  Merge, never overwrite existing settings.
- **Content guard pre-commit** (when `content_guard.pre_commit` is true): install `.git/hooks/pre-commit` that runs
  `content_guard.command` and exits with its code; never overwrite an existing hook without asking.
- CLAUDE.md managed block: lane-aware pipeline sentence ("…then one Reviewer round, then Deploy; the full gate runs once
  per batch (fast lane)"), and `/agent-sdlc:milestone` in the commands list.
- The summary names the active hooks (git guard, attribution guard, state validation) and how to turn the attribution
  hook off.

**Steps:** edit; `jq` every JSON block you changed (copy to a temp file); commit `init: process presets, v2.0 repair,
attribution settings, content-guard hook`.

---

## Wave 2 — executable pieces (parallel: Tasks 6, 7, 8 own disjoint files)

### Task 6: Attribution hook `guard-commit.sh` (TDD)

**Files:**
- Create: `hooks/scripts/guard-commit.sh` (executable)
- Create: `tests/hooks/guard-commit.test.sh` (executable)
- Modify: `hooks/hooks.json` (second hook in the existing `PreToolUse` `Bash` entry, after `guard-git.sh`, timeout 10,
  `statusMessage: "Checking commit conventions..."`)

**Behaviour (spec C25 (d), design record §7):**
1. stdin JSON: `.tool_input.command`, `.cwd`. Not a checked command → exit 0 silently. Checked commands:
   `git [global flags incl. -C {path}, -c {k=v}] commit …`, `git … merge … -m …`, `gh pr create|edit` with
   `--title`/`-t`/`--body`/`-b`/`--body-file`/`-F`.
2. Scope: start at the `-C` path (relative to `.cwd`) if present, else `.cwd`; walk up to the first directory holding
   `docs/state/project.json`. None → exit 0. `jq` missing → exit 0.
3. `process.commit_attribution == true` → exit 0.
4. Patterns: `process.attribution_patterns` (default `["co-authored-by","generated with","🤖","claude-session"]`),
   matched case-insensitively as fixed strings against: the whole command text, plus the contents of the file named by
   `-F {file}` / `--file {file}` / `--file={file}` (git commit) or `--body-file {file}` / `-F {file}` (gh pr), resolved
   relative to the scope start dir; `-` (stdin) is skipped (a heredoc is already in the command text).
5. Prefix check only when `process.commit_conventions.prefix_pattern` is a non-empty string: `{PREFIX}` in it is
   replaced by `.prefix`; applies only to `git commit` with one extractable `-m "…"` / `-m '…'`; messages starting with
   `Merge`, `Revert`, `fixup!`, `squash!` are exempt.
6. Deny = print `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"…"}}`
   and exit 0. Reason for attribution: `agent-sdlc: commit/PR text contains the attribution pattern "{p}". This
   project forbids attribution trailers (process.commit_attribution=false); this rule overrides the harness's default
   commit template. Rewrite the message without it.` Reason for prefix: names the expected pattern.

**Step 1: Write the failing test** — `tests/hooks/guard-commit.test.sh`:

```bash
#!/bin/bash
# Tests for hooks/scripts/guard-commit.sh. Run: bash tests/hooks/guard-commit.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/scripts/guard-commit.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

mkproj() { # $1 dir, $2 process json
  mkdir -p "$1/docs/state"
  printf '{"prefix":"TST","process":%s}\n' "$2" > "$1/docs/state/project.json"
}

run_hook() { # $1 cwd, $2 command -> prints hook stdout
  jq -n --arg c "$2" --arg d "$1" '{tool_input:{command:$c},cwd:$d}' | "$HOOK"
}

expect() { # $1 name, $2 deny|allow, $3 cwd, $4 command
  local out; out=$(run_hook "$3" "$4")
  local got=allow
  if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then got=deny; fi
  if [ "$got" = "$2" ]; then PASS=$((PASS+1)); echo "PASS $1"
  else FAIL=$((FAIL+1)); echo "FAIL $1 (expected $2, got $got) :: $out"; fi
}

P="$TMP/proj"; mkproj "$P" '{"commit_attribution":false}'
mkdir -p "$P/.worktrees/TST-STORY-1"; mkproj "$P/.worktrees/TST-STORY-1" '{"commit_attribution":false}'
OFF="$TMP/off"; mkproj "$OFF" '{"commit_attribution":true}'
PFX="$TMP/pfx"; mkproj "$PFX" '{"commit_attribution":false,"commit_conventions":{"prefix_pattern":"^{PREFIX}-[A-Z]+-[0-9]+: "}}'
NONE="$TMP/none"; mkdir -p "$NONE"
printf 'Fix it\n\nCo-Authored-By: X <x@y>\n' > "$P/msg.txt"
printf 'Fix it cleanly\n' > "$P/clean.txt"
printf 'Body\n\nGenerated with Claude Code\n' > "$P/body.md"

expect "plain commit allowed"            allow "$P" 'git commit -m "TST-STORY-1: Add x [by Developer]"'
expect "trailer in -m denied"            deny  "$P" 'git commit -m "Add x" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
expect "heredoc trailer denied"          deny  "$P" "git commit -F - <<'EOF'
Add x

Co-Authored-By: Claude <noreply@anthropic.com>
EOF"
expect "-F file trailer denied"          deny  "$P" 'git commit -F msg.txt'
expect "-F clean file allowed"           allow "$P" 'git commit -F clean.txt'
expect "git -C path commit denied"       deny  "$TMP" "git -C $P commit -m 'x' -m 'co-authored-by: a'"
expect "amend denied"                    deny  "$P" 'git commit --amend -m "x 🤖"'
expect "merge -m denied"                 deny  "$P" 'git merge --no-ff feat -m "Merge feat claude-session abc"'
expect "gh pr body-file denied"          deny  "$P" 'gh pr create --title "x" --body-file body.md'
expect "gh pr title denied"              deny  "$P" 'gh pr edit 3 --title "x generated with y"'
expect "non-commit ignored"              allow "$P" 'echo "Co-Authored-By: me"'
expect "outside project ignored"         allow "$NONE" 'git commit -m "x" -m "Co-Authored-By: a"'
expect "nested worktree scoped"          deny  "$P/.worktrees/TST-STORY-1" 'git commit -m "Co-Authored-By: a"'
expect "switch true is a no-op"          allow "$OFF" 'git commit -m "Co-Authored-By: a"'
expect "prefix ok"                       allow "$PFX" 'git commit -m "TST-STORY-2: Add y [by Developer]"'
expect "prefix wrong denied"             deny  "$PFX" 'git commit -m "Add y"'
expect "prefix exempt Merge"             allow "$PFX" 'git commit -m "Merge branch x"'
expect "prefix skipped without -m"       allow "$PFX" 'git commit -F clean.txt'

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
```

**Step 2:** `chmod +x tests/hooks/guard-commit.test.sh && bash tests/hooks/guard-commit.test.sh` → FAIL (hook
missing). Read the exit code on its own line: `echo $?` → non-zero.

**Step 3:** Write `hooks/scripts/guard-commit.sh` (header comment in the style of `guard-git.sh`: what it denies, why,
silent no-op elsewhere). Use `jq` for all JSON reading/writing. `chmod +x`.

**Step 4:** `bash tests/hooks/guard-commit.test.sh` → `passed=18 failed=0`, exit 0.

**Step 5:** Register in `hooks/hooks.json`; `jq empty hooks/hooks.json`.

**Step 6:** Commit `guard-commit hook: deny attribution trailers in agent-sdlc projects (C25)`.

### Task 7: Reference runner tool `run-step.sh` (TDD)

**Files:**
- Create: `tooling/runners/run-step.sh` (executable), `tooling/runners/README.md` (≤ 60 lines: what it is, the
  contract it implements — cite `skills/sdlc-dispatch/references/runners.md` —, env vars, exit codes, "a reference
  implementation: adapt, don't depend on it").
- Create: `tests/runners/run-step.test.sh`, `tests/runners/stub-ssh.sh` (both executable).

**Interface:**
```
run-step.sh start {host} {slot} {name} -- {command…}
run-step.sh wait  {host} {slot} {name} [--expect {ERE}] [--allow-empty] [--timeout {secs}]
```
Env: `RUNNER_SSH` (transport, default `ssh`; invoked as `$RUNNER_SSH {host} {remote-command-string}`), `RUNNER_ROOT`
(remote root, default `slots`, relative to the remote home), `RUN_STEP_STATE` (local state dir, default `.run-step`),
`RUN_STEP_POLL` (seconds between polls, default 10). Remote layout: work tree `{RUNNER_ROOT}/{slot}`, step files
`{RUNNER_ROOT}/.steps/{slot}/{name}.{cmd,log,done,token}` (outside the work tree, so the tree stays clean). Local:
`{RUN_STEP_STATE}/{host}-{slot}-{name}.{token,pending}`.

**start:** remove the local token; write the local `.pending` marker; generate a token; ship the command as a file
(stdin → `cat >`); remotely remove `{name}.done` and `{name}.log`, write the token, launch detached
(`nohup bash -c '…; echo "$rc $secs" > done.tmp && mv done.tmp done' &`) in the work tree. Only when the launch exits
0: write the local token, remove `.pending`, exit 0. Otherwise leave `.pending`, exit with the transport's code.

**wait:** `.pending` present → exit 3 ("the last start failed"). No local token → exit 3. Poll until `--timeout`
(default 540): remote token ≠ local → exit 3 ("result belongs to another start"); `done` present → rc, secs. rc ≠ 0 →
exit rc. rc = 0 and empty log and no `--allow-empty` → exit 3. rc = 0 and `--expect` does not match the log → exit 3.
Else 0. Timeout → exit 124 ("still running; call wait again"). Always print one summary line
`run-step: {name} exit {code} ({reason}); {secs}s; log {bytes} bytes` then `tail -n 20` of the log.

**Step 1: stub transport** — `tests/runners/stub-ssh.sh`:
```bash
#!/bin/bash
# Test transport: behaves like `ssh {host} {command}` but runs locally.
shift
exec bash -c "$*"
```

**Step 2: failing test** — `tests/runners/run-step.test.sh`:
```bash
#!/bin/bash
# Tests for tooling/runners/run-step.sh. Run: bash tests/runners/run-step.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RS="$ROOT/tooling/runners/run-step.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export RUNNER_SSH="$ROOT/tests/runners/stub-ssh.sh" RUNNER_ROOT="$TMP/remote" RUN_STEP_STATE="$TMP/local" RUN_STEP_POLL=0.2
mkdir -p "$RUNNER_ROOT/a"
PASS=0; FAIL=0
check() { # $1 name, $2 expected exit, $3 actual exit
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS $1"; else FAIL=$((FAIL+1)); echo "FAIL $1 (expected $2, got $3)"; fi
}

"$RS" start h a ok -- 'echo hello' >/dev/null; "$RS" wait h a ok >/dev/null; rc=$?
check "green step" 0 "$rc"

"$RS" start h a own -- 'echo boom; exit 7' >/dev/null; "$RS" wait h a own >/dev/null; rc=$?
check "own exit code" 7 "$rc"

"$RS" start h a empty -- 'true' >/dev/null; "$RS" wait h a empty >/dev/null; rc=$?
check "empty log is red" 3 "$rc"
"$RS" wait h a empty --allow-empty >/dev/null; rc=$?
check "allow-empty" 0 "$rc"

"$RS" start h a exp -- 'echo foo' >/dev/null; "$RS" wait h a exp --expect 'bar' >/dev/null; rc=$?
check "expect mismatch" 3 "$rc"
"$RS" wait h a exp --expect 'fo+' >/dev/null; rc=$?
check "expect match" 0 "$rc"

"$RS" start h a slow -- 'sleep 2; echo done' >/dev/null; "$RS" wait h a slow --timeout 0.5 >/dev/null; rc=$?
check "still running" 124 "$rc"
"$RS" wait h a slow --timeout 10 >/dev/null; rc=$?
check "then finishes" 0 "$rc"

"$RS" start h a quote -- "printf '%s\n' \"a 'b' c\"" >/dev/null; "$RS" wait h a quote --expect "a 'b' c" >/dev/null; rc=$?
check "quoting survives" 0 "$rc"

# a failed start must never let wait read the previous run's result
"$RS" start h a re -- 'echo first' >/dev/null; "$RS" wait h a re >/dev/null
RUNNER_SSH=false "$RS" start h a re -- 'echo second' >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && srt=nonzero || srt=zero
check "failed start reports failure" nonzero "$srt"
"$RS" wait h a re >/dev/null; rc=$?
check "pending marker refuses old result" 3 "$rc"

# a result from another start is refused
"$RS" start h a tok -- 'echo x' >/dev/null; "$RS" wait h a tok >/dev/null
echo "someone-else" > "$RUNNER_ROOT/.steps/a/tok.token"
"$RS" wait h a tok >/dev/null; rc=$?
check "token mismatch refused" 3 "$rc"

# the work tree stays clean: no step files inside it
[ -z "$(ls -A "$RUNNER_ROOT/a")" ] && clean=yes || clean=no
check "work tree untouched" yes "$clean"

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
```

**Step 3:** `bash tests/runners/run-step.test.sh` → fails (script missing).

**Step 4:** Implement `run-step.sh` (bash, `set -u`, no `set -e` — exit codes are read explicitly). Quote every remote
path with `printf '%q'`. Pass `--expect` to the remote side safely (`printf '%q'`) or copy the log back and grep
locally.

**Step 5:** `bash tests/runners/run-step.test.sh` → `passed=13 failed=0`.

**Step 6:** Commit `tooling: reference run-step.sh for remote stack runners, with tests (C14)`.

### Task 8: Content lint `tests/lint/check-content.sh`

**Files:** Create `tests/lint/check-content.sh` (executable), `tests/run-all.sh` (runs every `tests/**/*.test.sh` and
the lint; prints a summary; exits non-zero on any failure).

**Checks (each prints `PASS`/`FAIL {detail}`):**
1. Every ```` ```json ```` block in `skills/**/*.md`, `commands/*.md`, `templates/**/*.md`, `agents/*.md` parses with
   `jq` (```` ```jsonc ```` blocks are skipped — use that tag for commented examples).
2. Every `${CLAUDE_PLUGIN_ROOT}/…` and `${CLAUDE_SKILL_DIR}/…` path cited in `agents/`, `skills/`, `commands/` exists
   (`${CLAUDE_SKILL_DIR}` resolves to the citing skill's directory).
3. Every `references/…md` path in a "Load when" table exists.
4. No stale references: `references/briefs.md` appears nowhere; `quality-gate.md` seed has the 9 `## ` sections.
5. `hooks/hooks.json` scripts exist and are executable.
6. `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` carry the same version.

**Steps:** write it; run it now (expect some FAILs until later waves — record them); commit
`tests: content lint and run-all`. It must be fully green at Task 23.

---

## Wave 3 — agent skills (parallel: each task owns its files)

Every task in this wave: follow `docs/authoring-standards.md`; cite `sdlc-state` for statuses/lanes (never restate);
add an evidence line citing `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/evidence-and-shell.md`; keep the
classic text labelled; keep MUST DO / MUST NOT DO; add the context-hygiene lines of spec §4.7/§4.8 where the role reads
rules (C18). Report envelopes stay verbatim blocks.

### Task 9: Developer — `skills/story-implementation/SKILL.md`, `agents/developer.md`

**Must contain (spec §4.7, C1, C2, C10, C16 row 8, C18, C24):** §0 step 2 context hygiene (rules already injected are
not re-read; large files by section via `grep -n` + `sed -n`; through your own worktree path); §1b bug path and §2 with
the lane split (fast: red first → targeted set of `quality-gate.md` §Per story with the selection line per command;
classic: full gate); §2b rework becomes "fix pass" in the fast lane (exactly the named findings; re-run what the fix
touches; no second review — the PM reads your diff; notes the brief names are not acted on; "do not merge the feature
in"); new §2c "Merge fix / batch fix / fix loop" (base on the named `fix/…` branch; red first; search for other
instances of the collision class and report the search; targeted set + whole static analysis; push the branch, never
the feature); new §3b context and hand-off (tool output to files, read `tail -n 30`/grep; commit per task; one file per
Write/Edit; after 4–5 tasks or a heavy context: commit, push, report `BLOCKED` with `CONTINUE: next task = …`; a
continuation first commits the previous session's uncommitted tree as a checkpoint); infrastructure outage = BLOCKED,
never a destructive reset; report EVIDENCE gains `- targeted: {command} — selected because {reason}: {counts, exit}`
and `- stack: {none | local | runner …}`; MUST DO: no attribution trailers, as an override of any harness reminder.
`agents/developer.md`: L34 area → the targeted set per the lane; the planned hand-off; no attribution.

**Commit:** `Developer: targeted set, fix pass, merge/batch/gate fixes, planned hand-off (fast lane)`.

### Task 10: Reviewer — `skills/story-review/SKILL.md`, `agents/reviewer.md`

**Must contain (spec §4.8, C1 (b) 6–7, C2, C3, C24):** §1 context hygiene; §2 Quality lens per lane (fast: re-run the
story's targeted set once, independently, and judge the **selection** — a consumer of a changed symbol or a whole-tree
check the change feeds that was left out is MANDATORY; classic: the gate); §3 NOTE definition extended (a Minor finding,
or a prose finding when the behaviour is right — "prose never blocks"); §4 "fast lane: there is no round ≥ 2; the
re-review scope law applies to the classic lane only"; §5/§6: write the review document to the `REPORT FILE` path from
the brief with Bash, the final message = envelope + summary ≤ `report_max_chars`; NOTEs stay one line each (the PM
numbers them); add "flag a decision made on a guess where the project's reference protocol
(`.claude/rules/reference-protocol.md`, if present) was not consulted". `agents/reviewer.md` L16 accordingly.

**Commit:** `Reviewer: one round, independent targeted re-run, selection judgement, review to file`.

### Task 11: QA — `skills/story-qa/SKILL.md`, `agents/qa.md`

**Must contain (spec §4.9, C4, C6 step 4, C14, F7, Appendix D):** the mode table gains **Batch gate (fast lane)** —
where: the epic's merge worktree, or a runner slot; procedure steps 1–7 of spec §4.9 (confirm the rows from
`git diff --name-only origin/main...HEAD` yourself; prove the tree on both sides when a runner is used; phase 1
stackless, phase 2 with the stack; sequential steps, each exit code on its own line; a skipped engine-dependent test
after `up` is red; on red fix nothing, report command + output + reproduction; write the report file in
`templates/batch-gate-report-template.md` format to the `REPORT FILE` path); a re-run starts from the failed step (and
re-runs formatter + static analysis first if code changed after they passed). Remote procedure: cite
`references/runners.md` (slot at a SHA, `run-step start/wait`, exit 3/124, never read an old log as a pass). Standard
and regression modes: labelled classic lane (regression-on-main also runs in the fast lane when `main_regression`
dispatches it). Infrastructure outage = BLOCKED. Report EVIDENCE for batch gate: one line per step with count/exit,
`rows:`, `tree:`. `agents/qa.md` description: "runs the batch-end full gate (fast lane); E2E and regression in the
classic lane".

**Commit:** `QA: batch-gate mode with remote runner procedure (fast lane)`.

### Task 12: Deploy — `skills/story-merge/SKILL.md`, `agents/deploy.md`

**Must contain (spec §4.4, C5, C9, C10, C11, F4–F6):** the four-mode table (story merge, main-in, feature-in, delivery)
exactly as spec §4.4 plus a `classic` row set (1.6.1 story merge + epic merge text, labelled). Conflict law additions:
generated files regenerated, never hand-merged, committed only if they differ; docs and rules in a main-in take
`main`'s side then `git diff origin/main HEAD -- {docs paths}` prints nothing. Protocol step 4 → the mode's
verification (whole static analysis over every configuration on a real merge — WHY: a textual merge hides semantic
collisions); changed whole-tree scanners re-run; a pure fast-forward needs no re-run (tree identity). Step 6 → "push on
green per `process.deploy_push`; never push red to a feature or `main`; red goes to `fix/{ID}-merge` /
`fix/{EPIC}-main-in` / `fix/{EPIC}-{OTHER}-in`"; confirm with `git ls-remote`. Delivery mode: temporary detached
worktree from `origin/main`; compose the commit message from `templates/delivery-commit-template.md` using the gate
report, the batch's items (story/bug files), the notes file and the diff; `git merge --no-ff {gated sha} -F {file}`;
code-equality count = 0; push refusal loop. MUST NOT "fix" verification failures (kept). Report EVIDENCE per spec §4.4.
`agents/deploy.md`: pushing moves into Owns (on green), modes listed, exclusive per target branch.

**Commit:** `Deploy: story/main-in/feature-in/delivery modes, fix branches, push on green`.

### Task 13: Architect — `skills/architecture-design/SKILL.md`, `references/rule-authoring.md`, `agents/architect.md`

**Must contain (spec §4.10, C12, C3 point 4, C18, C20):** a **Ruling mode** (triggers; own worktree
`.worktrees/ARCH-{topic}` on `architect/{ITEM}-{topic}` from `main`; docs/rules/ADRs only, never code; a concrete verdict
per option; which story builds it and what the waiting story does meanwhile; content guard on every touched file when
declared; report ≈ 1,200 characters; OUTCOME `DESIGNED | NEEDS_REQUIREMENTS_FIX`); batch-end notes triage (rule-gap
notes on a planning branch, in parallel with the batch-fix Developer); Design Mode deliverable: `quality-gate.md` also
needs §Per story and the whole-tree-check table filled; planning work happens in `.worktrees/ARCHITECT-{topic}` and the
PM merges the branch (C20). `rule-authoring.md`: a "Rules budget" section (always-loaded files hold pointers, detail
in `paths:`-scoped files; measure bytes loaded for a typical module path with a given command; WHY: a module path once
loaded ~1 MB of rules before the agent read anything). `agents/architect.md`: Ruling mode in description + OUTCOMEs.

**Commit:** `Architect: Ruling mode, notes triage, gate §Per story, rules budget`.

### Task 14: Planning roles — `brd-writing`, `story-breakdown`, `ui-design`, `agents/product.md`, `agents/analyst.md`, `agents/designer.md`

**Must contain (spec §4.11, C13, C23, C29 (d) 3–4, C20, C22):** Product Manager: **milestone mode** (input: the goal and
demo from the brief; output DETAILS: the slice document path (from `templates/demo-slice-template.md`), the delivering
epics, the recut data, a verbatim `MILESTONE` registration block — id, title, goal, target, epics, stories,
`slice_doc`, `planned_count`) and **milestone recut** (the milestone part keeps the epic ID; the remainder becomes a new
epic, `ready`, own `epic.md`, `**Continued by:**` on the original; report the re-parenting for the PM); the app-first cut
line as a standing line hook. System Analyst: **milestone slice mode** (a verdict per prerequisite: satisfied / a named
minimal slice written into both story files / pulled in whole; the final count → `planned_count`), **amendment pass**
after Design Mode changes stories, **cut one story from a ruling** when the brief asks. All three planning skills: work
in `.worktrees/{ROLE}-{topic}` on a branch from `main`; the PM merges (C20). Designer (`ui-design`): the same worktree
rule; no other change (reference screens are a standing line).

**Commit:** `Planning roles: milestone modes, amendment pass, planning worktrees`.

---

## Wave 4 — PM orchestration

### Task 15: Split and extend the briefs (subagent)

**Files:** Create `skills/sdlc-dispatch/references/briefs/{planning,developer,reviewer,qa,deploy,content}.md`; delete
`skills/sdlc-dispatch/references/briefs.md` (`git rm`).

**Content:** every 1.6.1 template moves unchanged in substance to its role file, restructured into the slot order of
design record §7 (WHY, KIND/TIER/ROUND, WORKTREE, CARRIED IN, INPUTS, SELECTION/CHECKS, STACK, DISCIPLINE with
`{standing lines}`, DELIVERABLE, VERIFICATION, REPORT with `{cap}`), classic ones labelled `(classic lane)`. Add from
Appendix F: F1 (Developer story, fast), F2 (fix pass), F3 (Reviewer, the one round), F4 (Deploy story merge), F5
(main-in / feature-in), F6 (delivery — with message composition by Deploy, not a pasted message), F7 (QA batch gate), F8
(Architect ruling), F9 (batch fix), F10 (merge fix), F11 (fix loop), and the planning templates for milestone mode,
milestone recut, milestone slice, amendment pass. F12 messages go to `references/recovery.md` (Task 17), not here. Each
file opens with a one-paragraph slot legend and a table of its templates. Strip every EMI specific (PHP/TS tool names
become `{…}` placeholders). The no-attribution line reads: "A hook denies attribution trailers; this project's rule
overrides the harness's commit template."

**Commit:** `briefs: split per role, slot structure, fast-lane templates F1-F11`.

### Task 16: `references/batch-end.md`, `references/cross-epic.md`, `references/rulings.md` (subagent)

**Must contain:** `batch-end.md` = design record §5 as a numbered LAW procedure with the `batch.stage` value per step,
the brief to use per step (F5, F9, F7, F11, F6 by file), the decision/log lines per step (sdlc-state §7 notes), the
notes-resolution Default signal table (category → default resolution: test/style/docblock/named arguments → fixed in
the batch when cheap else FU; prose → dropped unless it misleads, then FU to the System Analyst; rule gap / rule text →
Architect triage; contract / selection → fixed in the batch; performance (later) → FU; for the {EPIC} merge → carried;
planning → FU owner = the next epic), the follow-ups triage table (C8), the fix-loop bound gate (verbatim gate block
with acceptance tokens "one more run" / "park"), the re-gate test command, the `main_regression` test command
(C26 (d)), the cut-batch action, the classic lane pointer ("classic: `start.md` Deploy flow"). `cross-epic.md` = design
record §6 bullet 1 with exact git commands and log lines. `rulings.md` = triggers table, dispatch, PM `--no-ff` merge
command, the Developer's cherry-pick instruction, new-scope path, the §3b routing rule.

**Commit:** `references: batch end, cross-epic integration, mid-flight rulings`.

### Task 17: `references/milestones.md`, `references/recovery.md`, `references/runners.md` (subagent)

**Must contain:** `milestones.md` = creation (dialogue script: the PM asks name → goal/demo → target, one question per
message, acceptance tokens; the directive format `docs/directives/active/{date}-milestone.md` with fixed fields), the
Product Manager / System Analyst dispatches, recut application steps (state re-parenting, `recut` log lines, bucket law
for the remainder epic), the recut check, the transitions (cite sdlc-state), progress computation (as `/status` shows
it), demo handling per `demo_gate` (`on_request` / `blocking` / `off`), `planning_depth`. `recovery.md` = the C16 table
(10 rows) + F12 messages verbatim + the law "SendMessage only for interrupted work and report tails; rework is always a
fresh teammate". `runners.md` = design record §8 runners bullet expanded: the contract (identical runners, fingerprint
check, no secrets, slots, SHA-only set-up, `start`/`wait` exit table, tokens, `.pending`, `--expect`/`--allow-empty`,
`runner-sync` with `--pull` and the sync-cache reset after a merge or cherry-pick, single-file bind mounts need a
service recreate, slot reset, known gaps, calibration), the worktree `stack` field, pointer to
`tooling/runners/run-step.sh` as the reference implementation.

**Commit:** `references: milestones, recovery, runners`.

### Task 18: `skills/sdlc-dispatch/SKILL.md` (orchestrator)

**Must contain (spec §4.5, design record §7–§8):** §1 dispatch table gains a Model column note (`process.models`,
default inherit; per role/mode keys; re-dispatch once on the inherited model when a non-inherited model's report fails
the evidence check); brief discipline = slots (free text only in WHY ≤ 2 sentences and CARRIED IN ≤ ~600 chars;
`{standing lines}` from `process.standing_brief_lines` exempt; `{cap}` = `process.report_max_chars`); the brief
template table points to `references/briefs/{role}.md`; a "Load when" table for every reference file. §2: Deploy
exclusivity per `process.deploy_exclusivity`; the stack budget (≤ `max_local_stacks` worktrees with `stack: "local"`;
stackless agents and runner slots don't count; queue + pair + narrate). §3: verification rows — commit trailers
(`git log -1 --format=%B {sha} | grep -ciE 'co-authored|claude-session'` read as a count → 0), runner evidence through a
matching start token, report file present when the brief named one; the fast-lane **exception** to the presence-check
law, verbatim: "A fix pass, batch fix, fix loop or merge fix is verified by reading its diff against the findings it was
given — only those. This replaces a second review round and is not a fourth verification layer." §3b routing rows:
Reviewer `## Notes` → notes file N-lines (fast lane); `Rule gap:` → a ruling now if a later story builds on it, else
Design Mode; QA batch-gate FAILED → fix loop (no bug); Deploy VERIFICATION_FAILED / MERGE_FAILED (fast) → merge fix (no
bug); Developer `CONTINUE:` → continuation dispatch; review/gate reports saved per Appendix A. §4: SendMessage resume
for interrupted work and report tails (cite `recovery.md`); never rework; never a silent fallback. MUST NOT additions.

**Commit:** `sdlc-dispatch: slots, models, stack budget, fast-lane verification and routing`.

### Task 19: `commands/start.md` (orchestrator)

**Must contain (spec §4.2, design record):** Step 0 loads the two skills + names the on-demand references; Execution
modes: never a silent fallback, stack budget beside the teammate cap, model per dispatch; Step 1 reads `process.*`
(absent → classic preset) and `integrations.runners`; Step 2 handles milestone directives; Step 2.5 stale check also
releases stale `stack`/runner allocations with a decision line; Planning phase: planning agents in worktrees + PM
merges, `planning_depth`, amendment pass, milestone planning pointer; Implementation: the lane stamp at
`ready → in_progress`; the dispatch map with a `Lane` column (fast rows of spec §4.2 item 3; classic rows unchanged);
worktree creation sets `stack`; Merge flow split (fast: PM fast-forward with exact commands, Deploy real merge, merge
fix path, "no bug for a merge failure"; classic: unchanged); the budget gate's fast-lane trigger; **Batch end (fast
lane)** = a short section that says when it starts and points to `references/batch-end.md` (no procedure copy);
**Deploy flow: epic → main (classic lane)** keeps the 1.6.1 text but reads `main_regression`, `followups_gate`,
`demo_gate`; Cross-epic, Rulings, Milestones: one short pointer section each; Git policy per spec §4.2 item 10 (main
checkout on main, commit by path, planning worktrees, push per `deploy_push`, PM holds main pushes during delivery,
no attribution, the closed plumbing list); PM constraints: the fast-lane diff-read exception and the plumbing
exception, "never reads an old runner log as a pass". Size target: ≤ 330 lines.

**Commit:** `start: lane-aware loop, fast-lane merge flow, batch end, milestones, git policy`.

### Task 20: `commands/milestone.md`, `commands/status.md`, `agents/pm.md`, `hooks/scripts/session-start.sh` (subagent)

**Must contain:** `milestone.md` — frontmatter `name: "agent-sdlc:milestone"`; `new` / `edit {ID}` run the dialogue of
`references/milestones.md` and write a directive file (never state; LAW: single writer); `list` prints milestones from
`epics.json` with progress computed like `/status`; refuses when state is not initialized. `status.md` — the Milestones
block (spec C29 (d) point 5 format, verbatim), epic lines with `[MS-n]` and the batch-end stage, open `fix/…` branches
(`git branch --list 'fix/*'`), notes-file open count, open follow-ups, local stacks in use. `agents/pm.md` — the
fast-lane presence-check exception, the permitted plumbing, main checkout on main, references table. `session-start.sh`
— add `Lane: {process.lane // "classic"}` and a milestones count line; keep it a silent no-op outside projects;
`bash -n` passes.

**Commit:** `milestone command, status milestones block, PM contract, session summary`.

---

## Wave 5 — tracker (subagent)

### Task 21: Milestones in the tracker (test first)

**Files:** Modify `tracker/server.py` (`api_state` adds `milestone_progress`), `tracker/static/app.js`
(`#/milestones` route + nav link; milestone and batch-stage chips on roadmap epic cards; roadmap group-by-milestone
toggle; item view names the milestone), `tracker/static/style.css`, `tracker/static/index.html` (nav). Create
`tests/tracker/api-state.test.sh` + a fixture builder inside it (mktemp; never committed state).

**`milestone_progress` shape:** `{ "{MS-ID}": { "epics_total", "epics_done", "items_total", "items_done",
"in_flight": [item ids in a working status], "planned_items": planned_count.items or null } }` — epics from
`milestones[id].epics` (active + archived), items = every item whose epic is linked plus every item in
`milestones[id].stories`, searched across active, backlog and archive.

**Test:** build a fixture (2 milestones; one epic archived `done`, one `in_progress` with 3 items of which 1 done and 1
`in_review`; an uncut-exception story in the archive); start the server exactly as `commands/tracker.md` does but with
`HOME=$TMP/home AGENT_SDLC_TRACKER_BASE_PORT=4700`; register the fixture project the same way; `curl` `/api/state`;
assert with `jq` the numbers above; kill the server. First run → FAIL (no `milestone_progress`), then implement, then
PASS. UI: run the fixture, open `http://127.0.0.1:{port}/#/milestones` in Chrome (claude-in-chrome), screenshot light
and dark, check the chips on `#/roadmap`. Colors: reuse the existing stage tokens (see memory: review yellow, qa
violet — never swap).

**Commit:** `tracker: milestones view, milestone and batch-stage chips (C29)`.

---

## Wave 6 — docs and version

### Task 22: README, extending guide, version

**Files:** `README.md` (Workflow: two-level verification; Git strategy: fast lane, `fix/` branches, delivery with
release notes; Model choice: `process.models`, inherit by default, the context-window caveat; commands list adds
`/agent-sdlc:milestone`; a "Upgrading from 1.x" paragraph: classic stays until you switch), `docs/extending-sdlc.md`
(adding a lane-dependent rule = a lane-table row in sdlc-state; adding a brief = a role file), `.claude-plugin/plugin.json`
and `.claude-plugin/marketplace.json` → `2.0.0` (and the description if it names the agent count).

**Commit:** `docs: README and extending guide for 2.0; version 2.0.0`.

---

## Wave 7 — verification

### Task 23: Everything green
Run `bash tests/run-all.sh`. Every FAIL is fixed in the owning file. Also: `python3 -m py_compile tracker/server.py`,
`node --check tracker/static/app.js`, `bash -n` on every `.sh`, `jq empty` on every `.json`. Commit fixes as
`fix: {what} (verification)`.

### Task 24: Cold-executor dry run
Dispatch a fresh general-purpose subagent with ONLY: the paths of `commands/start.md`, `skills/sdlc-state/SKILL.md`,
`skills/sdlc-dispatch/SKILL.md` + its references, and a fixture state (a fast-lane epic with 3 stories) written into a
scratch dir. Scenario: (1) story A approved → merge by fast-forward; (2) story B rejected → fix pass → PM diff check;
(3) story C real merge red → merge fix; (4) batch end with gate run 1 red → fix loop → run 2 green → delivery →
`main_regression` = `if_main_gained_code` with 0 code paths; (5) `/agent-sdlc:milestone new`. It writes, per step, the
exact state edits, log lines, dispatch (template name + filled slots) and narration it would produce, and lists every
point where it had to guess or found two rules disagreeing. Every guess point is fixed in the owning file.

### Task 25: Independent review
Dispatch `superpowers:code-reviewer` over `git diff main...HEAD` against the design record and the spec's C1–C26, C29
(d) sections. Apply findings per superpowers:receiving-code-review (verify each; push back with reasons where wrong).

### Task 26: Finish
superpowers:finishing-a-development-branch — present merge / PR / keep options to the user. Nothing merges into `main`
or pushes without the user's go.
