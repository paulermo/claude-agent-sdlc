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

# a late finish of an older launch must not replace the newer start's result
"$RS" start h a late -- 'sleep 1; echo A' >/dev/null; "$RS" wait h a late --timeout 0.2 >/dev/null
apid=$(cat "$RUNNER_ROOT/.steps/a/late.pid")
"$RS" start h a late -- 'echo B' >/dev/null; "$RS" wait h a late --timeout 5 >/dev/null
i=0; while kill -0 "$apid" 2>/dev/null && [ $i -lt 100 ]; do sleep 0.1; i=$((i+1)); done
"$RS" wait h a late --expect '^B$' --timeout 1 >/dev/null; rc=$?
check "older launch finishing late keeps the newer result" 0 "$rc"

# a done carrying another start's token is not this start's result
"$RS" start h a foreign -- 'sleep 2; echo mine; exit 5' >/dev/null
echo "0 0 someone-else" > "$RUNNER_ROOT/.steps/a/foreign.done"
"$RS" wait h a foreign --timeout 0.2 >/dev/null; rc=$?
check "foreign done ignored" 124 "$rc"
"$RS" wait h a foreign --timeout 10 >/dev/null; rc=$?
check "then its own result" 5 "$rc"

# a step whose wrapper died without a result is red, not "still running" forever
"$RS" start h a die -- "echo \$\$ > '$TMP/die.child'; exec sleep 30" >/dev/null
i=0; while [ ! -s "$TMP/die.child" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i+1)); done
kill -9 "$(cat "$RUNNER_ROOT/.steps/a/die.pid")"; kill "$(cat "$TMP/die.child")" 2>/dev/null
"$RS" wait h a die --timeout 5 >/dev/null; rc=$?
check "dead step is red" 3 "$rc"

# IDs are file names and ssh's first argument; free text must quote for a POSIX remote shell
"$RS" start -oProxyCommand=x a n -- 'true' >/dev/null 2>&1; rc=$?
check "leading-dash host refused" 2 "$rc"
"$RS" wait h a ok --expect "$(printf 'a\tb')" >/dev/null 2>&1; rc=$?
check "control character in --expect refused" 2 "$rc"

# a missing slot fails the start, and wait then refuses
"$RS" start h nosuch n -- 'echo x' >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && srt=nonzero || srt=zero
check "missing slot fails start" nonzero "$srt"
"$RS" wait h nosuch n >/dev/null; rc=$?
check "then wait refuses" 3 "$rc"

# transport failures: a failed first read means the state is unknown (3); later ones count as polls (124)
RUNNER_SSH=false "$RS" wait h a ok >/dev/null; rc=$?
check "unreadable runner at first read" 3 "$rc"
cat > "$TMP/flaky-ssh.sh" <<EOF
#!/bin/bash
# the first call passes through; every later call fails like a dropped ssh connection
[ -e "$TMP/flaky.used" ] && exit 255
: > "$TMP/flaky.used"
exec "$RUNNER_SSH" "\$@"
EOF
chmod +x "$TMP/flaky-ssh.sh"
"$RS" start h a flaky -- 'sleep 2; echo late' >/dev/null
RUNNER_SSH="$TMP/flaky-ssh.sh" "$RS" wait h a flaky --timeout 0.5 >/dev/null; rc=$?
check "transport failing mid-wait" 124 "$rc"

# the work tree stays clean: no step files inside it
[ -z "$(ls -A "$RUNNER_ROOT/a")" ] && clean=yes || clean=no
check "work tree untouched" yes "$clean"

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
