#!/bin/bash
# run-step.sh — run one step detached on a runner slot, then wait for its result.
#
#   run-step.sh start {host} {slot} {name} -- {command…}
#   run-step.sh wait  {host} {slot} {name} [--expect {ERE}] [--allow-empty] [--timeout {secs}]
#
# A reference implementation of the runner contract in skills/sdlc-dispatch/references/runners.md:
# adapt it to your project, don't depend on it. Env vars and exit codes: tooling/runners/README.md.
#
# Remote layout (paths relative to RUNNER_ROOT, which is relative to the remote home unless absolute):
#   {slot}/                                  the slot's work tree; the step runs here; never written to
#   .steps/{slot}/{name}.{cmd,log,done,token} the step's files, outside the work tree
#     done = "{exit code} {seconds} {token}", written atomically when the step ends
# Local: {RUN_STEP_STATE}/{host}-{slot}-{name}.{token,pending}
#
# Runs on bash 3.2 (macOS) and bash 4/5. No `set -e`: every exit code is read explicitly.
set -u

RUNNER_SSH="${RUNNER_SSH:-ssh}"
RUNNER_ROOT="${RUNNER_ROOT:-slots}"
RUN_STEP_STATE="${RUN_STEP_STATE:-.run-step}"
RUN_STEP_POLL="${RUN_STEP_POLL:-10}"

# The detached runner, executed remotely as: bash -c "$RUNNER" run-step {steps}/{name} {token}.
# It writes "{rc} {secs} {token}" to {name}.done atomically (tmp file, then mv), so `wait` never
# reads a half-written result, and the token binds the result to the start that launched it.
# shellcheck disable=SC2016  # expanded by the remote bash, not here
RUNNER='s=$(date +%s); bash "$1.cmd" > "$1.log" 2>&1 < /dev/null; rc=$?; e=$(date +%s); echo "$rc $((e - s)) $2" > "$1.done.tmp" && mv "$1.done.tmp" "$1.done"'

usage() {
  echo "usage: run-step.sh start {host} {slot} {name} -- {command…}" >&2
  echo "       run-step.sh wait  {host} {slot} {name} [--expect {ERE}] [--allow-empty] [--timeout {secs}]" >&2
  [ $# -gt 0 ] && echo "run-step: $1" >&2
  exit 2
}

q() { printf '%q' "$1"; }

is_num() {
  local re='^[0-9]+([.][0-9]+)?$'
  [[ $1 =~ $re ]]
}

# host, slot and name become file names on both sides, and host is ssh's first argument:
# no path separators, no leading dot (no "..") and no leading dash (no ssh option injection).
check_id() { # $1 label, $2 value
  case $2 in
    ''|[.-]*|*[!A-Za-z0-9._@-]*) usage "$1 must match [A-Za-z0-9._@-]+ and not start with . or -: '$2'" ;;
  esac
}

set_ids() { # $1 host, $2 slot, $3 name
  check_id host "$1"; check_id slot "$2"; check_id name "$3"
  host=$1 slot=$2 name=$3
  base="$RUN_STEP_STATE/$host-$slot-$name"
  QROOT=$(q "$RUNNER_ROOT"); QSLOT=$(q "$slot"); QNAME=$(q "$name")
}

cmd_start() {
  [ $# -ge 5 ] || usage "start needs {host} {slot} {name} -- {command…}"
  set_ids "$1" "$2" "$3"; shift 3
  [ "$1" = "--" ] || usage "start: expected -- before the command"
  shift
  local cmd="$*"
  [ -n "$cmd" ] || usage "start: empty command"

  mkdir -p "$RUN_STEP_STATE" || { echo "run-step: cannot create $RUN_STEP_STATE" >&2; exit 1; }
  # Until this start is confirmed, `wait` must refuse: drop the old token, raise the pending marker.
  rm -f "$base.token"
  printf '%s\n' "$cmd" > "$base.pending" || { echo "run-step: cannot write $base.pending" >&2; exit 1; }

  local token rc
  token="$(date +%s)-$$-$RANDOM"
  # One round trip: enter the work tree (a missing slot fails here, before anything is written); the
  # command travels on stdin into {name}.cmd (no nested quoting) via a tmp file and mv, because bash
  # reads a script as it runs and an earlier launch still running must keep its own file; the
  # previous result and log are removed; the token is written; the step is launched detached. Every
  # step is chained with &&; only the launch is backgrounded ({ … & }), so the list's exit code
  # reports every step before it.
  local remote="cd $QROOT && S=\"\$(pwd)\"/.steps/$QSLOT && cd $QSLOT && mkdir -p \"\$S\""
  remote="$remote && cat > \"\$S\"/$QNAME.cmd.tmp && mv \"\$S\"/$QNAME.cmd.tmp \"\$S\"/$QNAME.cmd"
  remote="$remote && rm -f \"\$S\"/$QNAME.done \"\$S\"/$QNAME.done.tmp \"\$S\"/$QNAME.log"
  remote="$remote && printf '%s\\n' $(q "$token") > \"\$S\"/$QNAME.token"
  remote="$remote && { nohup bash -c $(q "$RUNNER") run-step \"\$S\"/$QNAME $(q "$token") > /dev/null 2>&1 < /dev/null & }"

  printf '%s\n' "$cmd" | "$RUNNER_SSH" "$host" "$remote"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "run-step: start of $name on $host slot $slot failed (transport exit $rc); wait refuses until a start succeeds" >&2
    exit "$rc"
  fi
  printf '%s\n' "$token" > "$base.token" || { echo "run-step: cannot write $base.token" >&2; exit 1; }
  rm -f "$base.pending"
  echo "run-step: $name started on $host slot $slot (token $token)"
  exit 0
}

# Print the one summary line, then the log tail (only when the log is this start's), and exit.
finish() { # $1 code, $2 reason, $3 secs, $4 bytes, $5 tail
  echo "run-step: $name exit $1 ($2); $3s; log $4 bytes"
  [ -n "${5:-}" ] && printf '%s\n' "$5"
  exit "$1"
}

cmd_wait() {
  [ $# -ge 3 ] || usage "wait needs {host} {slot} {name}"
  set_ids "$1" "$2" "$3"; shift 3
  local expect='' have_expect=0 allow_empty=0 timeout=540
  while [ $# -gt 0 ]; do
    case $1 in
      --expect) [ $# -ge 2 ] || usage "--expect needs a regex"; expect=$2; have_expect=1; shift 2 ;;
      --allow-empty) allow_empty=1; shift ;;
      --timeout) { [ $# -ge 2 ] && is_num "$2"; } || usage "--timeout needs a number of seconds"; timeout=$2; shift 2 ;;
      *) usage "wait: unknown argument '$1'" ;;
    esac
  done
  { is_num "$RUN_STEP_POLL" && awk -v p="$RUN_STEP_POLL" 'BEGIN { exit !(p > 0) }'; } \
    || usage "RUN_STEP_POLL must be a number of seconds > 0: '$RUN_STEP_POLL'"

  [ -e "$base.pending" ] && finish 3 "the last start failed; start again" "?" "?"
  [ -f "$base.token" ] || finish 3 "no start recorded here; start first" "?" "?"
  local tok
  tok=$(head -n 1 "$base.token")
  [ -n "$tok" ] || finish 3 "the local token is empty; start again" "?" "?"

  # One remote read per poll: token, done, log size, --expect match (only once done), log tail.
  local grep_part=''
  if [ "$have_expect" = 1 ]; then
    grep_part="if [ -n \"\$d\" ]; then if grep -Eq -e $(q "$expect") \"\$B.log\" 2>/dev/null; then m=match; else m=nomatch; fi; fi;"
  fi
  local probe="cd $QROOT || exit 1; B=.steps/$QSLOT/$QNAME;"
  probe="$probe t=\$(head -n 1 \"\$B.token\" 2>/dev/null); d=\$(head -n 1 \"\$B.done\" 2>/dev/null);"
  probe="$probe n=0; [ -f \"\$B.log\" ] && n=\$(wc -c < \"\$B.log\"); m=-; $grep_part"
  probe="$probe printf '%s\\n%s\\n%s\\n%s\\n' \"\$t\" \"\$d\" \$n \"\$m\"; tail -n 20 \"\$B.log\" 2>/dev/null; exit 0"

  # Bash arithmetic is integer-only: bound the wait by a poll count (supports fractions) and by
  # wall-clock seconds (so slow transport round trips cannot stretch the wait past the timeout).
  local max_polls limit polls=0
  max_polls=$(awk -v t="$timeout" -v p="$RUN_STEP_POLL" 'BEGIN { n = t / p; c = int(n); if (c < n) c++; print c }')
  limit=$(awk -v t="$timeout" 'BEGIN { c = int(t); if (c < t) c++; print c }')
  SECONDS=0

  local out prc r_tok r_done r_bytes r_match r_tail d_rc d_secs d_tok d_rest started elapsed
  while :; do
    out=$("$RUNNER_SSH" "$host" "$probe" < /dev/null)
    prc=$?
    [ "$prc" -eq 0 ] || finish 3 "could not read the step on $host (transport exit $prc)" "?" "?"
    r_tok='' r_done='' r_bytes='' r_match='' r_tail=''
    { IFS= read -r r_tok; IFS= read -r r_done; IFS= read -r r_bytes; IFS= read -r r_match; r_tail=$(cat); } <<< "$out"
    case $r_bytes in ''|*[!0-9]*) r_bytes=0 ;; esac

    [ "$r_tok" = "$tok" ] || finish 3 "the runner's token differs: the result belongs to another start" "?" "$r_bytes"

    d_rc='' d_secs='' d_tok=''
    # shellcheck disable=SC2034  # d_rest keeps any extra field out of d_tok
    [ -n "$r_done" ] && read -r d_rc d_secs d_tok d_rest <<< "$r_done"
    # The runner's token is ours, so a done file carrying another token was written late by an
    # earlier launch of this step that was still running when we started: not our result, ignore it.
    if [ -n "$r_done" ] && [ "$d_tok" = "$tok" ]; then
      case $d_rc in ''|*[!0-9]*) finish 3 "unreadable done file: '$r_done'" "?" "$r_bytes" "$r_tail" ;; esac
      [ "$d_rc" -ne 0 ] && finish "$d_rc" "the step failed" "$d_secs" "$r_bytes" "$r_tail"
      [ "$r_bytes" -eq 0 ] && [ "$allow_empty" = 0 ] \
        && finish 3 "exit 0 with an empty log; --allow-empty only if silence is this step's green" "$d_secs" 0
      [ "$have_expect" = 1 ] && [ "$r_match" != match ] \
        && finish 3 "exit 0 but the log does not match --expect" "$d_secs" "$r_bytes" "$r_tail"
      finish 0 "passed" "$d_secs" "$r_bytes" "$r_tail"
    fi

    if [ "$polls" -ge "$max_polls" ] || [ "$SECONDS" -ge "$limit" ]; then
      started=${tok%%-*}
      case $started in ''|*[!0-9]*) elapsed='?' ;; *) elapsed=$(( $(date +%s) - started )) ;; esac
      finish 124 "still running; call wait again" "$elapsed" "$r_bytes" "$r_tail"
    fi
    sleep "$RUN_STEP_POLL"
    polls=$((polls + 1))
  done
}

[ $# -ge 1 ] || usage
sub=$1; shift
case $sub in
  start) cmd_start "$@" ;;
  wait) cmd_wait "$@" ;;
  *) usage "unknown command '$sub'" ;;
esac
