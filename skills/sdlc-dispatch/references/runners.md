# Remote stack runners — the contract

Load when `project.json` `integrations.runners.enabled` is `true` (sdlc-state section 6) and a dispatch needs a stack, a batch gate is due, a slot must be reset, or a runner step's result must be read. Runners are optional: without them every stack is local and this file does not apply.

This file is the **contract** a project's runner tooling must satisfy — its single source of truth. The tooling lives in the project: `integrations.runners.tooling_dir` holds the commands named below (`runner-slot`, `run-step`, `runner-sync`, the provisioner and its check); `integrations.runners.inventory` lists each runner with its number `{NN}` and slot count. The plugin ships one reference implementation, `${CLAUDE_PLUGIN_ROOT}/tooling/runners/run-step.sh` with its `README.md` — adapt it, don't depend on it. WHY runners: a full test step once took 21 min on a 4 vCPU runner against about 2 h on a loaded laptop, and the laptop holds only `process.max_local_stacks` stacks. WHY a contract: a hand-quoted `ssh … nohup …` line once reported a pass for a step that ran nothing.

Legend: `{NN}` = the runner's number in the inventory (with the reference script, name the runner's `~/.ssh/config` `Host` entry `{NN}` itself, so the number is the transport's host); `{x}` = a slot letter; `{sha}` = a full commit SHA; `{reports}` = the absolute `{worktree_dir}/.reports` path from the brief.

## 1. Identical runners (LAW)

1. One idempotent provisioner sets up every runner, with pinned tool versions, and ends by printing a fingerprint of what it installed — WHY: runners that differ in one tool version give different results for the same commit; the fingerprint makes "identical" a checkable fact.
2. A check re-runs the provisioner on every runner and diffs the fingerprints; it exits 1 on any drift. A drifted runner gets no dispatch until it is re-provisioned and the check exits 0 — WHY: a drifted runner's red or green belongs to the runner, not to the commit.
3. Runners are never configured by hand, and are added one at a time — WHY: two concurrent adds once corrupted the shared SSH configuration.
4. Calibrate every new or re-provisioned runner before its first real step: run a known gate run there and compare the counts (the same test count, the same result). Different → the runner is not used.

## 2. No secrets on a runner (LAW)

1. A runner holds a bare repository that the local machine pushes to. It holds no source-host credential and never fetches from the source host — WHY: a runner is a rented machine outside the project's trust boundary; without a credential, a compromised runner cannot reach the source.
2. Each stack's secrets are generated on the runner by the stack's own `up`, into an ignored env file; they never travel — WHY: a secret that never travels cannot leak in transit or from a copy.
3. Only SSH comes in; every stack port is bound to the runner's localhost — WHY: an open stack port exposes a test system and its generated secrets to anyone.
4. Reference material (anything the project keeps out of its repository or marks as reference) never goes to a runner — WHY: it is licensed or confidential, and a runner is not an approved place to hold it.

## 3. Slots

- A runner has slots `a`–`d`. A slot is one work tree + one Compose project + its own block of host ports bound to localhost.
- A small runner takes one slot. *Default: below 8 GB of RAM, one slot — a full gate once peaked near 3.3 GB. Default, not law: deviate only on concrete grounds, and record the rationale in the inventory.*
- On a one-slot small runner the gate runs in two phases: the stackless rows first with the stack down; then `up` and the stack rows; then `down`.

## 4. Slot set-up — `runner-slot {NN} {x} {sha}`

The argument is a SHA, never a branch name — WHY: a branch can move between set-up and run, and a result must belong to one pushed commit. The command must:

1. push the commit to the slot's branch in the runner's bare repository;
2. create the slot's work tree, or move it to that commit — refusing a dirty tree unless `RESET=1` is set, which discards local changes;
3. write the slot's env file, keeping the secrets an earlier `up` generated;
4. install dependencies when a lock file changed since the tree's previous commit;
5. start nothing, and exit non-zero on any failure — a failed set-up means no step may run on the slot.

## 5. Running a step — `run-step start | wait`

```
run-step start {NN} {x} {name} -- {command}
run-step wait  {NN} {x} {name} [--expect {ERE}] [--allow-empty] [--timeout {secs}]
```

- `start` runs `{command}` detached in the slot's work tree: the command travels as a file (no nested quoting); output goes to `{name}.log`; `{name}.done` = `{exit} {secs} {token}` is published when the step ends. `wait` polls until a result, the timeout, or a refusal.
- **Every call** sets `RUN_STEP_STATE={reports}/run-step` — WHY: an agent's working directory resets between tool calls, and a cwd-relative state dir makes `wait` exit 3 (no start recorded) and dirties a work tree.
- `{name}` is a lower-case `[a-z0-9-]` slug, unique per run: IDs lower-cased (`tst-story-3-tests`); `{step}-r{N}` for gate run `{N}`.
- One `wait` fits one Bash tool call: with the default `--timeout 540`, call the Bash tool with `timeout: 600000`; at the tool's default 120000 ms, pass `--timeout 100`. Set `ConnectTimeout 10`, `ServerAliveInterval 15` and `ServerAliveCountMax 3` for each runner in `~/.ssh/config` — a hung ssh blocks `wait` past its timeout.
- Record `wait`'s exit code on its own line (`run-step wait … ; echo "exit=$?"`, evidence-and-shell.md), but **decide by the reason in its summary line, never by the number** — `run-step: {name} exit {code} ({reason}); {secs}s; log {bytes} bytes` — because a step's own exit code can be 2, 3 or 124 too (`make` exits 2 on a failure). Only that summary line for THIS start decides the step — never `cat` or `tail` a step's log on the runner to judge it.

| `{reason}` (exact text) | Exit | The agent does |
|---|---|---|
| `the step failed` | the step's own code — any number, 2, 3 and 124 included | red: the step's result; quote the tail |
| `passed` | `0` | green — it exited 0, its log is non-empty (or `--allow-empty`) and matches `--expect`: quote the summary line and the counter |
| `exit 0 with an empty log; --allow-empty only if silence is this step's green` · `exit 0 but the log does not match --expect` | `3` | red — the output proves nothing. Two exceptions, each a new `wait`, never a new `start`: the step's green is silence (add `--allow-empty`); the tail shows the counter line your pattern missed (correct `--expect`) |
| `no start recorded here; start first` · `the local token is empty; start again` | `3` | check `RUN_STEP_STATE` first — it must be the `{reports}/run-step` the `start` call used: wrong → `wait` again with it; right → `start` again |
| `the last start failed; start again` | `3` | read the failed `start`'s error, fix the cause, `start` again |
| `the runner's token differs: the result belongs to another start` | `3` | never read that log; `start` again |
| `the step died without a result; start it again` · `unreadable done file: '{…}'` | `3` | `start` again, once; a second time → BLOCKED |
| `could not read the step on {host} (transport exit {n}); state unknown, wait again once the transport works` | `3` | fix the transport, then `wait` again; a second failure is an outage → BLOCKED |
| `still running; call wait again` · `transport failing (exit {n}); call wait again` | `124` | `wait` again, same name — never a second `start` while it runs; `transport failing` twice in a row is an outage → BLOCKED. Still running after twice the step's last measured time (no earlier measurement: 2 h — *Default, not law: record a deviation in DETAILS*): check the runner is up; a runner that is down is an outage → BLOCKED |
| no summary line; stderr starts `usage: run-step.sh` | `2` | a usage error: fix the call — never red, never a result |

`start` succeeds only with exit 0 and `run-step: {name} started on {host} slot {x} (token {token})`. Anything else — `start of {name} on {host} slot {x} failed (transport exit {n}); wait refuses until a start succeeds`, `cannot create …`, `cannot write …`, a usage error — → fix the cause and `start` once more; a second failure → BLOCKED.

**Start tokens (LAW).** `start` first removes the local token and raises a local `.pending` marker; it writes a fresh token beside the step's files on the runner; only after the launch succeeded does it write the same token locally and drop the marker. A launch publishes its `done` only while the runner's token is still its own, and each `done` carries that token. `wait` accepts a result only when the local token, the runner's token and the `done` token are one. WHY: a failed `start` once left the previous run's `done` in place, and `wait` read its old exit 0 as this run's pass.

- `--expect {ERE}`: give it the counter line of every step that prints one (the test runner's summary), so a step that ran nothing is red.
- `--allow-empty`: only for a step whose green is silence — a breaking-change check, a drift check.
- EVIDENCE line: `- runner {NN} slot {x} {name}: {wait's summary line} (token {token from start}); {counter line}`.

## 6. Syncing a local worktree — `runner-sync {NN} {x} {worktree} [--pull {paths}]`

For a Developer's or Reviewer's stack on a runner: the worktree stays on the local machine. The command must:

1. push git-visible content (tracked plus untracked-not-ignored) incrementally, deletions included; ignored paths (dependency trees, caches, the env file) are never touched on either side;
2. with `--pull {paths}`, bring back files a tool on the runner wrote (a formatter fix, an API dump, generated clients or stubs) — before the commit, so they are committed from the worktree;
3. keep a sync cache for the increments; **clear it after a merge or cherry-pick in the worktree**, so the next sync is full — WHY: an incremental sync once lost a file that had been in conflict during a merge.

A service that bind-mounts a single file keeps the old file after a sync (a new inode): recreate that service (`docker compose up -d --force-recreate {service}` or the project's equivalent).

## 7. Allocation, release, reset (PM)

1. **Allocate** at dispatch, in the same response as the working status: a slot is free when no worktree entry's `stack` names it — `jq -r '.worktrees[] | .stack // empty' docs/state/project.json` lists the held ones. Set the holder's worktree entry `"stack": "runner {NN} slot {x}"` (sdlc-state section 6); the brief's STACK slot names it with the SHA; the dispatch line's note names it (sdlc-state section 7).
2. **Release** when the holder's report is verified: set `"stack": null`. Exception: a Developer's slot stays with the item for its Reviewer — the review re-runs on the story's own slot — and is cleared at the Reviewer's release.
3. **Reset** before a slot's next holder is dispatched — the PM does it (slot plumbing, like `git worktree add`); holders never reset a slot: (1) `down` with volumes in the slot (the project's down target); (2) `RESET=1 runner-slot {NN} {x} {the next holder's sha}`; both exit 0, else the slot is not used and you narrate why.
4. **Stale** — an item holds its slot only while it is in a working status (sdlc-state section 1) or `ready_for_review` (a Developer's slot waiting for its Reviewer); an `{EPIC-ID}-merge` worktree holds a stack only while Deploy or QA runs there (while Deploy runs, its `stack` is `"local"` and counts against the budget). Any other holder is stale: start.md Step 2.5 clears it with the decision line `stack released: {holder} {slot} (stale)`; step 3 runs before its next holder.

## 8. Use order and the stack budget

1. Batch gates first — a gate is a pure function of a pushed commit; the QA batch-gate brief names the runner and slot (story-qa, Remote procedure).
2. Then Developer and Reviewer stacks: the slot is set up at the item's base SHA, the holder starts `up`, and the local worktree is synced with `runner-sync`.
3. A review re-runs on the story's own slot (section 7, step 2).

`process.max_local_stacks` caps the worktrees holding `stack: "local"`; runner slots come on top and never count against it (sdlc-dispatch section 2). No free slot → a local stack if the budget has room, else queue, narrate, and pair with stackless work.

## Known gaps — Situation | Action

| Situation | Action |
|---|---|
| a step needs a browser (E2E specs) | runners have none: run E2E on the local machine (`stack: "local"`, counted by the budget) |
| a permission-sensitive test fails only on a runner (runners run as root) | exclude it on runners (the report names it), run it on the local machine and show it green there; both runs in the report |
| a new or re-provisioned runner | calibrate it (section 1, step 4) before its first real step |
| the drift check exits 1 | take the runner out of use; re-provision; re-check |
| `runner-slot` refuses a dirty tree | the holder's work is committed and pushed → `RESET=1`; otherwise ask the holder first |
| a merge or cherry-pick happened in a synced worktree | clear the sync cache before the next `runner-sync` |

## MUST NOT DO

- Accept a step result whose start token does not match — an old log is never this run's pass (sdlc-state MUST NOT).
- Set a slot up at a branch name, configure a runner by hand, or add two runners at once.
- Put a credential, a source-host key or reference material on a runner.
- Hand-quote `ssh … nohup …` lines instead of `run-step`, or `start` a step again while `wait` says 124.
- Run `run-step` without `RUN_STEP_STATE={reports}/run-step`.
