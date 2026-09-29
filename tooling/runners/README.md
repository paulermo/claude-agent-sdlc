# run-step.sh — reference runner tool

**A reference implementation: adapt it to your project, don't depend on it.** It shows one way to satisfy the
runner contract in `skills/sdlc-dispatch/references/runners.md` (the single source of truth for that contract). It
runs one gate step detached on a runner slot, so a long step survives the tool call, and `wait` polls for its result.
Only `run-step` ships here; slot setup and sync are protocol-only.

```
run-step.sh start {host} {slot} {name} -- {command}
run-step.sh wait  {host} {slot} {name} [--expect {ERE}] [--allow-empty] [--timeout {secs}]
```

- `{command}` is one shell string, run by `bash` in the slot's work tree (like `ssh {host} {command}`). Chain with `&&`:
  the step's exit code is the script's last exit code.
- `{host}`, `{slot}`, `{name}`: `[A-Za-z0-9._@-]+`, not starting with `.` or `-`. No control characters in `--expect`.
- `wait` prints one line, `run-step: {name} exit {code} ({reason}); {secs}s; log {bytes} bytes`, then the log's last
  20 lines (only when the log is this start's). Read the exit code on its own line. `wait` never changes state.

## Exit codes (`wait`)

| Exit | When |
|---|---|
| the step's own code | the step finished with it |
| 0 | the step exited 0, its log is non-empty (or `--allow-empty`) and matches `--expect` (when given) |
| 3 | the last `start` failed (the `.pending` marker is present), or no `start` was recorded in this state dir |
| 3 | the runner's token differs from the local one: the result belongs to another start |
| 3 | the step exited 0 with an empty log, without `--allow-empty` (for steps whose green is silence) |
| 3 | the step exited 0 but the log does not match `--expect {ERE}` |
| 3 | the step died without a result (its process is gone, no `done`): `start` it again |
| 3 | the first read of the runner failed: the state is unknown; fix the transport, then `wait` again |
| 124 | still running after `--timeout` (default 540 s), or the transport kept failing after the first read: `wait` again |
| 2 | usage error (both commands) |

`start` exits 0 once the step is launched, otherwise with the transport's code (the `.pending` marker stays).

**Why the tokens and markers:** a failed `start` once left the previous run's `.done` in place, and `wait` read its old
exit 0 as this run's pass. So `start` raises a local `.pending` marker and writes the local token only after the
launch succeeded; the runner holds the same token, a launch publishes its `done` only while the token is still its
own, and each `done` carries that token.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `RUNNER_SSH` | `ssh` | transport, one executable, called as `$RUNNER_SSH {host} {remote command}`; options go in `~/.ssh/config` or a wrapper |
| `RUNNER_ROOT` | `slots` | remote root, relative to the remote home unless absolute |
| `RUN_STEP_STATE` | `.run-step` | local state dir (tokens, `.pending` markers); add it to `.gitignore`, call `start` and `wait` from the same directory |
| `RUN_STEP_POLL` | `10` | seconds between polls (fractions allowed) |

Remote layout: work tree `{RUNNER_ROOT}/{slot}` (never written to); step files
`{RUNNER_ROOT}/.steps/{slot}/{name}.{cmd,log,done,token,pid}`, where `done` = `{exit} {secs} {token}`.
The runner needs a POSIX login shell, `bash`, `nohup`, `kill` and coreutils.

## Notes

- A hung ssh blocks `wait` past its timeout. Set `ConnectTimeout 10`, `ServerAliveInterval 15` and
  `ServerAliveCountMax 3` for each runner host in `~/.ssh/config`.
- `wait --timeout 540` (the default) fits in one Bash tool call only with the tool's timeout at 600000 ms. At the tool's
  default 120000 ms, pass `--timeout 100`.
- Tests: `bash tests/runners/run-step.test.sh` (local stub transport `tests/runners/stub-ssh.sh`; dash when installed).
