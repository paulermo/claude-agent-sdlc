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

run_hook() { # $1 cwd, $2 command -> prints hook stdout; status = hook's exit code
  jq -n --arg c "$2" --arg d "$1" '{tool_input:{command:$c},cwd:$d}' | "$HOOK"
}

# allow = exit 0 AND empty stdout; deny = exit 0 AND a PreToolUse deny JSON.
# Anything else (crash, non-zero exit, stray output) fails the case.
expect() { # $1 name, $2 deny|allow, $3 cwd, $4 command
  local out rc got
  out=$(run_hook "$3" "$4"); rc=$?
  if [ "$rc" -ne 0 ]; then got="exit $rc"
  elif [ -z "$out" ]; then got=allow
  elif printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"
      and .hookSpecificOutput.permissionDecision == "deny"
      and (.hookSpecificOutput.permissionDecisionReason | type == "string" and length > 0)' >/dev/null 2>&1
  then got=deny
  else got="unexpected output"; fi
  if [ "$got" = "$2" ]; then PASS=$((PASS+1)); echo "PASS $1"
  else FAIL=$((FAIL+1)); echo "FAIL $1 (expected $2, got $got) :: $out"; fi
}

P="$TMP/proj"; mkproj "$P" '{}'
mkdir -p "$P/.worktrees/TST-STORY-1"; mkproj "$P/.worktrees/TST-STORY-1" '{}'
OFF="$TMP/off"; mkproj "$OFF" '{"commit_attribution":true}'
PFX="$TMP/pfx"; mkproj "$PFX" '{"commit_conventions":{"prefix_pattern":"^{PREFIX}-[A-Z]+-[0-9]+: "}}'
CUS="$TMP/cus"; mkproj "$CUS" '{"attribution_patterns":["internal-bot"]}'
EMPTY="$TMP/empty"; mkproj "$EMPTY" '{"attribution_patterns":[]}'
BAD="$TMP/bad"; mkdir -p "$BAD/docs/state"; printf '{not json\n' > "$BAD/docs/state/project.json"
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
expect "harness template denied"         deny  "$P" "git commit -m \"\$(cat <<'EOF'
Add x

Co-Authored-By: C <c@a>
EOF
)\""
expect "-F file trailer denied"          deny  "$P" 'git commit -F msg.txt'
expect "--file= trailer denied"          deny  "$P" 'git commit --file=msg.txt'
expect "-F clean file allowed"           allow "$P" 'git commit -F clean.txt'
expect "git -C path commit denied"       deny  "$TMP" "git -C $P commit -m 'x' -m 'co-authored-by: a'"
expect "git -C relative path denied"     deny  "$TMP" "git -C proj commit -m 'x' -m 'co-authored-by: a'"
expect "amend denied"                    deny  "$P" 'git commit --amend -m "x 🤖"'
expect "merge -m denied"                 deny  "$P" 'git merge --no-ff feat -m "Merge feat claude-session abc"'
expect "gh pr body-file denied"          deny  "$P" 'gh pr create --title "x" --body-file body.md'
expect "gh pr -F denied"                 deny  "$P" 'gh pr create -F body.md'
expect "gh pr title denied"              deny  "$P" 'gh pr edit 3 --title "x generated with Claude Code"'
expect "non-commit ignored"              allow "$P" 'echo "Co-Authored-By: me"'
expect "pattern before commit ignored"   allow "$P" 'grep -rn "co-authored-by" . && git commit -m x'
expect "git log --grep ignored"          allow "$P" 'git log --grep co-authored-by'
expect "git commit-tree ignored"         allow "$P" 'git commit-tree HEAD^{tree} -m "Co-Authored-By: a"'
expect "generated with (not claude) ok"  allow "$P" 'git commit -m "Regenerate lockfile generated with npm"'
expect "outside project ignored"         allow "$NONE" 'git commit -m "x" -m "Co-Authored-By: a"'
expect "malformed config still enforced" deny  "$BAD" 'git commit -m "x" -m "Co-Authored-By: a"'
expect "nested worktree scoped"          deny  "$P/.worktrees/TST-STORY-1" 'git commit -m "Co-Authored-By: a"'
expect "legacy off switch ignored"       deny  "$OFF" 'git commit -m "Co-Authored-By: a"'
expect "custom pattern denied"           deny  "$CUS" 'git commit -m "x by internal-bot"'
expect "custom list extends defaults"    deny  "$CUS" 'git commit -m "x" -m "Co-Authored-By: a"'
expect "empty list keeps defaults"       deny  "$EMPTY" 'git commit -m "x 🤖"'
expect "prefix ok"                       allow "$PFX" 'git commit -m "TST-STORY-2: Add y [by Developer]"'
expect "prefix wrong denied"             deny  "$PFX" 'git commit -m "Add y"'
expect "prefix exempt Merge"             allow "$PFX" 'git commit -m "Merge branch x"'
expect "prefix skipped without -m"       allow "$PFX" 'git commit -F clean.txt'
expect "prefix skipped for \$(heredoc)"  allow "$PFX" "git commit -m \"\$(cat <<'EOF'
Add x
EOF
)\""

echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
