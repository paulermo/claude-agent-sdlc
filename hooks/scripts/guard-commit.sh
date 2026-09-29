#!/bin/bash
# agent-sdlc PreToolUse hook (Bash).
# In SDLC-initialized projects, denies commits and PRs whose text carries an
# attribution trailer (Co-Authored-By, "Generated with Claude", 🤖,
# claude-session — always; process.attribution_patterns may only ADD patterns). Agents follow
# the harness's default commit template over a brief line that merely states
# the rule, so the rule is enforced at the moment of the commit.
#   Checked: git [-C path] [-c k=v] commit ..., git ... merge ... -m ...,
#            gh pr create|edit with --title/-t/--body/-b/--body-file/-F.
#   Scanned: the checked command's own text (from the invocation onward, so
#            heredocs and -m "$(cat <<'EOF' ...)" are covered) plus the
#            -F/--file (git) or --body-file/-F (gh) message file.
#   Mandatory: there is no off switch — the built-in patterns apply even when
#            project.json is unreadable (only the optional prefix check fails open).
#   Optional: process.commit_conventions.prefix_pattern ({PREFIX} = .prefix)
#            is enforced on a `git commit` with one quoted -m message
#            (Merge/Revert/fixup!/squash! exempt).
# The project is found by walking up from the -C path (else the session cwd)
# to the first docs/state/project.json. Silent no-op everywhere else.
# Best-effort guard, not a security boundary. Known gaps: sh -c "...",
# /usr/bin/git, merge -F/--message, -F "$VAR" (unexpanded paths).

# Hot path: no jq, no subshell for commands that cannot be a checked one.
IFS= read -r -d '' INPUT
case $INPUT in *git*|*gh*pr*) ;; *) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
case $CMD in *git*|*gh*pr*) ;; *) exit 0 ;; esac

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

unquote() {
  local v=$1
  case $v in
    \"*\") v=${v#\"}; v=${v%\"} ;;
    \'*\') v=${v#\'}; v=${v%\'} ;;
  esac
  printf '%s' "$v"
}

# --- Is this a checked command? (parse the invocation, not the patterns) ---
Q="'"
VAL="((\"[^\"]*\"|${Q}[^${Q}]*${Q}|[^[:space:];&|)\"${Q}])+)"
BOUND='(^|[;&|(`[:space:]])'
GFLAGS="([[:space:]]+(-[Cc][[:space:]]+${VAL}|--(git-dir|work-tree|namespace)[[:space:]]+${VAL}|--[A-Za-z][A-Za-z-]*(=${VAL})?|-[pP]))*"
RE_COMMIT="${BOUND}git${GFLAGS}[[:space:]]+commit([[:space:]]|\$)"
RE_MERGE="${BOUND}git${GFLAGS}[[:space:]]+merge([[:space:]]|\$)"
RE_GHPR="${BOUND}gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|\$)"
RE_DASHC="[[:space:]]-C[[:space:]]+${VAL}"
RE_DASHM='(^|[[:space:]])-m([[:space:]]|$)'
RE_GHFLAG='(^|[[:space:]])(--title|--body|--body-file|-[tbF])'
RE_GITFILE="(^|[[:space:]])(-F[[:space:]]+|--file[[:space:]]+|--file=)${VAL}"
RE_GHFILE="(^|[[:space:]])(-F[[:space:]]+|--body-file[[:space:]]+|--body-file=)${VAL}"

# *_REST = the checked command's remainder (text after the subcommand);
# only these, plus the message file, are scanned for patterns.
CHECKED=0; COMMIT=0; GIT_INV=""; COMMIT_REST=""; MERGE_REST=""; GH_REST=""
if [[ $CMD =~ $RE_COMMIT ]]; then
  CHECKED=1; COMMIT=1; GIT_INV=${BASH_REMATCH[0]}
  COMMIT_REST=${CMD#*"$GIT_INV"}
fi
if [[ $CMD =~ $RE_MERGE ]]; then
  M=${BASH_REMATCH[0]}
  R=${CMD#*"$M"}
  if [[ $R =~ $RE_DASHM ]]; then
    CHECKED=1; MERGE_REST=$R; [ -n "$GIT_INV" ] || GIT_INV=$M
  fi
fi
if [[ $CMD =~ $RE_GHPR ]]; then
  M=${BASH_REMATCH[0]}
  R=${CMD#*"$M"}
  if [[ $R =~ $RE_GHFLAG ]]; then
    CHECKED=1; GH_REST=$R
  fi
fi
[ "$CHECKED" -eq 1 ] || exit 0

# --- Scope: -C path (relative to cwd) or cwd, walk up to project.json ---
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || CWD=$PWD
START=$CWD
if [[ $GIT_INV =~ $RE_DASHC ]]; then
  C=$(unquote "${BASH_REMATCH[1]}")
  case $C in /*) START=$C ;; *) START=$CWD/$C ;; esac
fi
D=$(CDPATH= cd -- "$START" 2>/dev/null && pwd) || D=$START
ROOT=""
while [ -n "$D" ]; do
  if [ -f "$D/docs/state/project.json" ]; then ROOT=$D; break; fi
  NEXT=${D%/*}; [ -n "$NEXT" ] || NEXT=/
  [ "$NEXT" = "$D" ] && break
  D=$NEXT
done
[ -n "$ROOT" ] || exit 0
PROJ="$ROOT/docs/state/project.json"

# --- Attribution patterns: checked command's remainder + message/body file ---
TEXT="$COMMIT_REST
$MERGE_REST
$GH_REST"
add_file() { # $1 raw file argument
  local f
  f=$(unquote "$1")
  [ "$f" = "-" ] && return
  case $f in /*) ;; *) f=$START/$f ;; esac
  if [ -f "$f" ] && [ -r "$f" ]; then
    TEXT="$TEXT
$(cat "$f")"
  fi
}
if [ -n "$COMMIT_REST" ] && [[ $COMMIT_REST =~ $RE_GITFILE ]]; then
  add_file "${BASH_REMATCH[3]}"
fi
if [ -n "$GH_REST" ] && [[ $GH_REST =~ $RE_GHFILE ]]; then
  add_file "${BASH_REMATCH[3]}"
fi

# Built-in patterns always apply; a project's list only adds to them.
BUILTIN='co-authored-by
generated with claude
🤖
claude-session'
EXTRA=$(jq -r '(.process.attribution_patterns // [])
  | if type == "array" then .[] | strings else empty end' "$PROJ" 2>/dev/null)
PATTERNS="$BUILTIN
$EXTRA"
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if printf '%s\n' "$TEXT" | grep -qiF -e "$p"; then
    deny "agent-sdlc: commit/PR text contains the attribution pattern \"$p\". agent-sdlc projects never carry attribution trailers; this rule overrides the harness's default commit template. Rewrite the message without it."
  fi
done <<EOF
$PATTERNS
EOF

# --- Optional prefix convention: git commit with one quoted -m ---
[ "$COMMIT" -eq 1 ] || exit 0
PFXPAT=$(jq -r '((.prefix // "") | tostring) as $p
  | (.process.commit_conventions.prefix_pattern? // "")
  | if type == "string" then split("{PREFIX}") | join($p) else "" end' "$PROJ" 2>/dev/null)
[ -n "$PFXPAT" ] || exit 0

NM=$(printf '%s\n' "$COMMIT_REST" | grep -oE -- '(^|[[:space:]])-a?m([[:space:]]|$)' | wc -l)
[ "$NM" -eq 1 ] || exit 0
RE_MSG="(^|[[:space:]])-a?m[[:space:]]+(\"([^\"]*)\"|${Q}([^${Q}]*)${Q})"
[[ $COMMIT_REST =~ $RE_MSG ]] || exit 0
case ${BASH_REMATCH[2]} in
  \"*) MSG=${BASH_REMATCH[3]}
       case $MSG in *'$'*|*'`'*) exit 0 ;; esac ;;  # expansion: not extractable
  *)   MSG=${BASH_REMATCH[4]} ;;
esac
case $MSG in Merge*|Revert*|'fixup!'*|'squash!'*) exit 0 ;; esac

[[ $MSG =~ $PFXPAT ]]
rc=$?
# rc 1 = no match -> deny; rc 2 = invalid regex in the config -> fail open.
if [ "$rc" -eq 1 ]; then
  deny "agent-sdlc: commit message \"$MSG\" does not match the project's commit prefix pattern \"$PFXPAT\" (process.commit_conventions.prefix_pattern). Rewrite the message to match it (Merge, Revert, fixup! and squash! messages are exempt)."
fi

exit 0
