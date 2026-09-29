# Teammate recovery

Load when a teammate stops or drops mid-work (a usage or session limit, a lost connection), thrashes on its context, hands off with `CONTINUE:`, sends a truncated report, a blocker it reported is resolved, a spawn fails, or start.md Step 2.5 finds a working status with no live teammate. It extends the teammate lifecycle law of `sdlc-dispatch` section 4 (release by TaskStop after verification). Every rule here is LAW unless it carries the Default suffix. In the subagent fallback, "message the same teammate" means SendMessage to the same agent by name — it resumes from its transcript.

## 1. The law

1. **SendMessage to a finished or stopped teammate is allowed ONLY for:**
   a. a **report fix** — the envelope, evidence or artifacts failed verification (sdlc-dispatch sections 3–4);
   b. ***interrupted* work** — a usage or session limit reset, a dropped connection, or a BLOCKED report whose blocker is now resolved: the work stopped before it was done, and no verdict judged it;
   c. a **truncated report's missing tail**.
   WHY: the session still holds unfinished work that a fresh one would redo — but only work that was cut off, never work that was judged.
2. **Rework is ALWAYS a fresh teammate**, named `{role}-{ITEM-ID}-fix`, with the feedback brief — never a message to the old session. WHY: a stale session carries its prior conclusions into the rework instead of following the rejection brief.
3. **Never a silent fallback to background subagents.** When a named spawn fails, say so in the same turn and name the fallback. Before falling back: (1) TaskStop every teammate whose report is verified or whose session is dead; (2) ask the user to close dead panes and keep the terminal window maximised; (3) lower the parallelism by one and retry the spawn. Only a spawn that still fails falls back, narrated: `Spawn failed for {name}: {error}. Falling back to background subagents for {ITEM-IDs}; no pane will show them.` WHY: a silent fallback once left eleven agents behind three stale panes, and the user had to ask what was running.

## 2. Situations

| # | Situation | PM does | Log line (sdlc-state section 7) |
|---|---|---|---|
| 1 | Dispatching | named teammates, one pane each (`{role}-{ITEM-ID}`); a failed spawn → law 3 | the usual `dispatch: {Role}` line |
| 2 | The cap | count WORKING teammates only against `max_parallel_teammates`; the stack budget (sdlc-dispatch section 2) is a second, independent cap | none |
| 3 | Release | TaskStop right after verification (sdlc-dispatch section 4) — lingering panes use up window room, and new panes then fail to open | none |
| 4 | Rework | a fresh teammate `{role}-{ITEM-ID}-fix` with the feedback brief (law 2) | `dispatch: Developer (fix pass)` (fast lane) / `dispatch: Developer` (classic lane) |
| 5 | Account session or usage limit | section 3 | `decision`: `teammates stopped: session limit`, then `teammates resumed: {names}` |
| 6 | Connection dropped mid-response | the dropped-connection message (section 4) to the same teammate | `dispatch: {Role} (resumed)`, note `dropped connection` |
| 7 | A teammate thrashing on its context | replace it with a fresh teammate and a narrow brief (section 5) | `dispatch: {Role} (continuation)`, note `replaces {name}: out of context; uncommitted: {files \| none}` |
| 8 | Planned hand-off: OUTCOME `BLOCKED` + `CONTINUE:` | a continuation at once (section 6) | `dispatch: Developer (continuation)`, note `next task = {…}; base {sha}` |
| 9 | Truncated report | the truncated-report message (section 4) to the same teammate; apply nothing until the tail arrives | none until the transition |
| 10 | Session lost (older practice) | re-dispatch on the existing worktree (section 7) | `decision`, note `session lost: re-dispatched on {worktree}; commits found: {n} ({a}..{b} \| none)` |

A BLOCKED report whose blocker you resolved (an answer, a ruling, a prerequisite merged) → the blocker-resolved message (section 4) to the same teammate — it was not released (sdlc-dispatch section 4); log `dispatch: {Role} (resumed)`, note `unblocked: {decision or ruling commit}`.

## 3. Usage or session limit

1. The limit stops every teammate at once. Do NOT TaskStop them and dispatch nothing — their sessions hold the work.
2. For each item whose teammate stopped, append a decision line (`from` = `to` = its status) with the fixed note `teammates stopped: session limit`; commit state by path.
3. Wait for the reset: the user says so, or your own next turn runs.
4. Send each stopped teammate the limit-reset message (section 4). Its runner steps are read through their start tokens (`runners.md`) — never an old log as a pass.
5. For each item, a decision line `teammates resumed: {role}-{ITEM-ID}`; commit state by path.
6. A message that fails (`No task found`, the teammate is gone) → section 7 for that item.

## 4. Messages (send verbatim, filling the placeholders)

Placeholders: `{work}` = the item and the step in flight (`{ITEM-ID}, the targeted set`); `{sha}` = the worktree's head (`git -C {worktree} rev-parse --short HEAD`); `{ while you were on {X}}` = optional — the step you last saw it on; `{last words}` = the last words that arrived; `{what is missing}` = the envelope sections absent (`the rest of DETAILS, BLOCKERS`); the blocker message's braces are one line each, the steps numbered.

After an account session or usage limit reset:

```
The session limit has reset. Continue {work} on {sha} from where you stopped. The runner step may have finished while you were paused: read its result with `run-step wait`; the start tokens tell you whether that log is this run's. If the step was interrupted, restart it; never read an old log as a pass. Then finish the remaining steps and send the envelope as briefed.
```

After a dropped connection:

```
The connection dropped mid-response{ while you were on {X}}. Continue {ITEM-ID} from where you stopped. 1. Check `git -C {worktree} status` and the log to see what is already written and committed. 2. Commit what is complete. 3. Carry on as briefed and send the envelope.
```

A truncated report:

```
Your report was cut off at '{last words}'. Please resend only the rest of DETAILS from that line to the end: {what is missing}. Nothing else, and no new work.
```

A blocker resolved mid-flight:

```
{ITEM-ID} is unblocked. {The decision or ruling, and its commit to cherry-pick.} {Numbered steps.} {Stack.}
```

## 5. Replacing a thrashing teammate

| Signal | Thrashing? |
|---|---|
| it says its context is full, or its pane shows a second automatic compaction | yes |
| it re-reads files it already read, or redoes a step it already reported done, 3 or more times | yes |
| no new commit in its worktree (`git -C {worktree} log -1 --format=%cr`) for more than ~60 minutes while it keeps working | yes |
| it is waiting on a long runner step (`run-step wait` exit 124) | no — waiting is not thrashing |

*Default, not law: deviate only on concrete grounds, and record the rationale in the dispatch line's note.*

1. TaskStop the teammate.
2. `git -C {worktree} status --short` → `{files}`, the uncommitted edits.
3. Fresh dispatch from the role's template, named `{role}-{ITEM-ID}-c{n}` (`{n}` = 2 for the first replacement or continuation, then 3, …). The brief is NARROW: INPUTS name only the files the remaining work needs; CARRIED IN says, verbatim: ``The previous session ran out of context; UNCOMMITTED edits exist in {files}: read `git diff` of those first; keep what is sound, revert what is not. Never cat large or generated files — grep and tail them.``
4. The item keeps its status — no transition.

## 6. Planned hand-off

A Developer stops at a task boundary — after about 4–5 tasks, or when its context is heavy (story-implementation) — commits, pushes, and reports OUTCOME `BLOCKED` with `CONTINUE: next task = …` (sdlc-state section 3). It is a hand-off, not a blocker:

1. Verify the report (sdlc-dispatch section 3: its commits exist, evidence for the tasks done); release the teammate (TaskStop).
2. The item keeps `in_progress` — no transition.
3. At once — no waiting for other completions — dispatch **Developer — continuation** (`briefs/developer.md`) with the `CONTINUE:` line and the head SHA, named `developer-{ITEM-ID}-c{n}`. The continuation first commits any tree left uncommitted as a checkpoint.

## 7. Session lost (older practice)

When start.md Step 2.5 finds an item in a working status with no live teammate, or a message to a stopped teammate fails:

1. `git -C {worktree} log --oneline {feature-branch}..HEAD` → the commits already made (`{n}`, `{a}..{b}`); `git -C {worktree} status --short` → the uncommitted files.
2. Re-dispatch the same role, fresh, on the existing worktree; the brief's WORKTREE slot says that work may already exist and lists those commits and files.
3. Log the decision line of row 10.

## MUST NOT DO

- Message a finished teammate for anything but a report fix, interrupted work or a report's tail — never for rework, never to "also fix" a finding.
- Fall back to background subagents without saying so in the same turn.
- TaskStop teammates stopped by a limit, or restart their items from scratch — their sessions hold the work.
- Accept a runner result after a resume without a matching start token (sdlc-state MUST NOT).
- Wait for other completions before dispatching a continuation.
