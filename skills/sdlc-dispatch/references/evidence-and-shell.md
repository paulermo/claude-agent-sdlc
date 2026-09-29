# Evidence and shell discipline

Every agent and the PM follow this file whenever they run a check and report its result. It is LAW: a false reading of
an exit code looks exactly like a pass. WHY: on one project six agent readings of an exit code were false — the worst
reported a pass for a check that never ran — and a gate guard exited 0 while never evaluating what it guarded.

## What counts as evidence

1. **Evidence is a counter, an exit code or a diff** — `412 passed, 0 failed`, `exit 0`, `0 files changed`. Silence is
   not evidence: `ok: true`, empty output and "the run passed" prove nothing until the check is shown to have run.
2. **A run that selected or evaluated nothing is red** until shown otherwise: a test filter matching 0 tests, a policy
   script evaluating 0 fixtures, a command that executed 0 runs. WHY: "0 failed" out of 0 run is indistinguishable from
   a pass in a report.
3. **Quote the last run that actually passed** — the one on the current tree. Never an earlier run, never a run on
   another SHA. WHY: a fix after the run changes what the run proved.
4. **Only the gate's own targets are gate evidence** (the commands in `.claude/rules/quality-gate.md`). A direct tool
   call is a diagnostic — useful, but never a substitute. WHY: a direct call can skip the config, the cache clear or the
   selection the gate target applies.
5. **A component "not present yet" is red, not a skip.** If the gate names it, it must run. WHY: a skipped component
   ships unproven, and nothing later re-checks it.
6. **Detached steps** (a long step started on a runner, polled later) are bound to a start token: an empty log with
   exit 0 is red, a log that fails its expected-output check (`--expect`) is red, and a log from another start is never
   this run's result. Procedure: `${CLAUDE_PLUGIN_ROOT}/skills/sdlc-dispatch/references/runners.md`. WHY: a failed start
   once left the previous run's result in place, and it was read as this run's pass.
7. **Commit trailers are part of the evidence check**: a commit carrying an attribution trailer fails verification
   while `process.commit_attribution` is `false` (sdlc-state section 7).

## Shell rules (every shell)

1. Read `$?` on the very next line, from the command itself: `cmd; echo "exit=$?"`. Never after a pipe, never after an
   `&&` or `||` list — WHY: after a pipe `$?` is the LAST command's exit (`tail`, `grep`), not the check's.
2. Send long output to a file and read back `tail -n 30` or a `grep`: `cmd > {reports}/{name}.log 2>&1; echo "exit=$?"`,
   where `{reports}` is the absolute path your brief names (the main checkout's `{worktree_dir}/.reports`) — outside
   your worktree, so a log is never committed; never a relative `.reports/`, which would land inside your worktree.
   WHY: printing a whole suite or a generated file floods the context the rest of the work needs.
3. `grep -c` exits 1 when it counts zero: read the printed count, never the exit status. Count a file that may be
   missing with `cat {file} 2>/dev/null | grep -c '{pattern}'` — WHY: `grep -c … || echo 0` prints `0` twice.
4. Run `type {tool}` before trusting a gate tool you did not install — WHY: an alias once shadowed a gate tool, so the
   "check" ran something else entirely.
5. Never place a destructive command after `;` behind an `&&` chain (`a && b; rm -rf x`) — WHY: `;` runs even when the
   chain failed.
6. Verify a loop's effects with a listing (`ls`, `git worktree list`), never with the loop's own `echo` — WHY: a loop
   once created worktrees whose paths held spaces and a branch name, and echoed success.
7. Never run a command held in an unquoted variable — WHY: word splitting differs by shell; use an array or one
   command per item.

## zsh additions (apply when `process.shell` is `zsh`)

1. The pipe status array is `pipestatus`, indexed from 1 (`$pipestatus[1]`); `PIPESTATUS` does not exist — WHY: the
   bash spelling reads an unset variable and looks like success.
2. zsh does not word-split: `for x in $list` and `set -- $pair` take the whole string. Use arrays (`"${arr[@]}"`),
   `read -r a b <<< "$pair"`, or one command per item — WHY: the loop runs once with the whole string as its argument.
3. Brace a variable followed by a colon: `"${REF}:path"` — WHY: `$REF:h` and `$REF:t` are history modifiers, so
   `$REF:path` silently becomes something else.
4. Guard globs that may match nothing: `*.md(N)` or `setopt null_glob` — WHY: an unmatched glob is a hard error in zsh
   and aborts the rest of the line.
5. For alternation in `git grep`, use `-E` with a plain `|` (`git grep -nE 'foo|bar'`), never the basic-regex
   backslash form — WHY: the backslash form returned nothing on one host.

## Situation | Action

| Situation | Action |
|---|---|
| A check printed nothing and exited 0 | red until you show it ran: re-run with its verbose/count flag, or prove the selection is non-empty |
| A test filter selected 0 tests | red — fix the filter; never report "0 failed" as a pass |
| A tool behaves unexpectedly | `type {tool}`; call it by full path or `command {tool}` |
| A cache may be stale (compiled container, analyser cache) | clear it, confirm the clear (a listing or a count), then run; an unconfirmed clear is an un-run check, not a failure |
| An infrastructure outage (container engine down, registry unreachable) | report BLOCKED with the outage evidence — not FAILED — and never run a destructive reset ("reset to factory defaults", `docker system prune -a --volumes`) |
