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
