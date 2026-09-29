#!/bin/bash
# Runs every tests/**/*.test.sh suite (sorted), then the content lint. Run: bash tests/run-all.sh (from any directory)
# Prints each suite's output, then "run-all: {n} suites, {f} failed"; exits 1 if any suite (or the lint) failed.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
n=0; f=0; failed=""

run() { # $1 = suite path relative to ROOT
  n=$((n+1))
  echo "=== $1"
  (cd "$ROOT" && bash "$1" </dev/null); rc=$?
  if [ "$rc" -eq 0 ]; then echo "=== $1: ok"
  else f=$((f+1)); failed="$failed $1"; echo "=== $1: FAILED (exit $rc)"; fi
}

while IFS= read -r t; do
  [ -n "$t" ] && run "$t"
done <<EOF
$(cd "$ROOT" && find tests -type f -name '*.test.sh' | sort)
EOF
run tests/lint/check-content.sh

echo "run-all: $n suites, $f failed${failed:+ —$failed}"
[ "$f" -eq 0 ]
