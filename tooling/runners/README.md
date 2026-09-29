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

## Exit codes and what to do

The `wait` table — every reason text, its exit code and what the agent does — has one home:
`skills/sdlc-dispatch/references/runners.md` §5. Decide by the reason in the summary line, never by the number: a
step's own exit code can be 2, 3 or 124 too. `start` exits 0 once the step is launched, otherwise with the transport's
code (the `.pending` marker stays); a usage error exits 2 with no summary line.

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
