#!/bin/bash
# Content lint for the agent-sdlc plugin. Run: bash tests/lint/check-content.sh (from any directory)
#
# The plugin's markdown is executed by LLMs: a cited path that does not exist, a JSON example that does not
# parse (agents copy them verbatim into state files) or a reference to a removed file is a real failure.
#
# Checks (each prints PASS {summary} when clean, or one FAIL {detail} line per defect):
#   1. json       every ```json block in skills/**, commands/*, templates/**, agents/* parses with jq
#                 (```jsonc blocks are skipped — use that tag for commented examples)
#   2. path       every ${CLAUDE_PLUGIN_ROOT}/… and ${CLAUDE_SKILL_DIR}/… path cited in agents/, skills/,
#                 commands/ exists (${CLAUDE_SKILL_DIR} = the citing skill's directory; templated paths skipped)
#   3. load-when  every references/…md path in a "Load when" table exists
#   4. stale      no reference to the removed briefs.md; the quality-gate seed has 9 "## " sections
#   5. hooks      every script named in hooks/hooks.json exists and is executable
#   6. version    .claude-plugin/plugin.json and marketplace.json carry the same version
#
# Ends with "lint: {P} passed, {F} failed" (items, not checks); exits 1 if F > 0, 2 if the lint cannot run.
# Portable to macOS /bin/bash 3.2: no associative arrays, no mapfile.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || { echo "FAIL lint: cannot enter $ROOT"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FAIL lint: jq is required"; exit 2; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
TAB=$'\t'
PASS=0; FAIL=0; CF=0 # CF = failures of the current check

ok()  { PASS=$((PASS+1)); }
bad() { FAIL=$((FAIL+1)); CF=$((CF+1)); echo "FAIL $*"; }
end_check() { # $1 = PASS summary, printed only when the check had no failure
  if [ "$CF" -eq 0 ]; then echo "PASS $1"; fi
  CF=0
}
skill_dir() { # skills/{name}/… -> skills/{name}; anything else -> empty
  case "$1" in skills/*/*) printf '%s\n' "$1" | cut -d/ -f1-2 ;; *) echo "" ;; esac
}

# ---- 1. JSON blocks parse ----------------------------------------------------------------------------------
{ find skills templates -type f -name '*.md'; find agents commands -maxdepth 1 -type f -name '*.md'; } 2>/dev/null \
  | sort > "$TMP/json.files"
mkdir -p "$TMP/json"
: > "$TMP/json.idx"
if [ -s "$TMP/json.files" ]; then
  # One pass over all files. A block opens at a line that is exactly ```json (leading/trailing blanks allowed)
  # and closes at the next line starting with ```. Index line: file TAB start-line TAB block-file | U(nterminated).
  # shellcheck disable=SC2046
  awk -v dir="$TMP/json" -v idx="$TMP/json.idx" '
    function unterminated() { if (inb) { printf "%s\t%d\tU\n", cur, start > idx; close(out); inb = 0 } }
    FNR == 1 { unterminated(); cur = FILENAME }
    inb && /^[[:space:]]*```/ { inb = 0; close(out); printf "%s\t%d\t%s\n", cur, start, out > idx; next }
    inb { print > out; next }
    /^[[:space:]]*```json[[:space:]]*$/ { n++; out = dir "/b" n ".json"; printf "" > out; inb = 1; start = FNR; next }
    END { unterminated() }
  ' $(cat "$TMP/json.files")
fi
# Content deliberately uses key/value FRAGMENTS (one map entry `"{ID}": { … }`, or a few `"key": value,` lines).
# A block passes if it parses as-is, or wrapped as { block }, or wrapped after dropping one trailing comma on its
# last non-blank line. Only a block that fails every way FAILs (unquoted {PLACEHOLDER}s, [...], comments do).
nj=0
while IFS="$TAB" read -r f start blk; do
  [ -n "$f" ] || continue
  nj=$((nj+1))
  if [ "$blk" = U ]; then bad "json $f:$start: unterminated block (no closing \`\`\`)"; continue; fi
  if ! grep -q '[^[:space:]]' "$blk"; then bad "json $f:$start: empty block"; continue; fi
  { echo '{'; cat "$blk"; echo '}'; } > "$blk.w1"
  { echo '{'
    awk '{ l[NR] = $0 } NF { last = NR } END { for (i = 1; i <= NR; i++) { if (i == last) sub(/,[[:space:]]*$/, "", l[i]); print l[i] } }' "$blk"
    echo '}'; } > "$blk.w2"
  how=""
  if err0=$(jq . < "$blk" 2>&1 >/dev/null); then how="as-is"
  elif jq . < "$blk.w1" >/dev/null 2>&1; then how="fragment"
  elif err2=$(jq . < "$blk.w2" 2>&1 >/dev/null); then how="fragment, trailing comma dropped"
  fi
  if [ -n "$how" ]; then
    ok; [ "${LINT_VERBOSE:-0}" = 1 ] && echo "  ok json $f:$start ($how)"
    continue
  fi
  # Report the error of the reading the author meant: a block opening with { or [ is a whole document;
  # anything else is a fragment (its wrapped line numbers are one past the block's, for the added "{").
  first=$(tr -d ' \t\r\n' < "$blk" | cut -c1)
  case "$first" in '{'|'[') err=$err0; off=0; as="" ;; *) err=$err2; off=-1; as="read as a fragment; " ;; esac
  err=$(printf '%s\n' "$err" | head -1)
  rel=$(printf '%s\n' "$err" | sed -nE 's/.* at line ([0-9]+), column [0-9]+$/\1/p')
  [ -n "$rel" ] && err="$err (${as}file line $((start + rel + off)))"
  bad "json $f:$start: $err"
done < "$TMP/json.idx"
[ "$nj" -gt 0 ] || bad "json: no \`\`\`json block found — the scanner is broken"
end_check "json: $nj blocks parse"

# ---- 2. Cited ${CLAUDE_PLUGIN_ROOT}/… and ${CLAUDE_SKILL_DIR}/… paths exist -------------------------------------
grep -rnIoE '\$\{CLAUDE_(PLUGIN_ROOT|SKILL_DIR)\}/[A-Za-z0-9_./{}-]+' agents skills commands 2>/dev/null \
  | sort -t: -k1,1 -k2,2n > "$TMP/paths"
np=0; nt=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  f=${hit%%:*}; rest=${hit#*:}; line=${rest%%:*}; tok=${rest#*:}
  tok=$(printf '%s\n' "$tok" | sed -E 's/[.,)`]+$//')
  rel=${tok#*\}/}
  case "$rel" in *'{'*|*'}'*) nt=$((nt+1)); continue ;; esac # templated, e.g. references/briefs/{role}.md
  np=$((np+1))
  case "$tok" in
    '${CLAUDE_SKILL_DIR}/'*)
      sd=$(skill_dir "$f")
      if [ -z "$sd" ]; then bad "path $f:$line: $tok (\${CLAUDE_SKILL_DIR} used outside a skill)"; continue; fi
      target="$sd/$rel" ;;
    *) target="$rel" ;;
  esac
  if [ -e "$target" ]; then ok; else bad "path $f:$line: $tok"; fi
done < "$TMP/paths"
[ "$np" -gt 0 ] || bad "path: no \${CLAUDE_PLUGIN_ROOT}/ or \${CLAUDE_SKILL_DIR}/ citation found — the scanner is broken"
end_check "path: $np cited paths exist ($nt templated skipped)"

# ---- 3. "Load when" table paths exist -----------------------------------------------------------------------
# A "Load when" table = a markdown table (outside code fences) whose header row contains "Load when".
# Emits: file TAB line TAB H|R TAB row  (H = header, R = body row; the |---| separator is dropped).
{ find agents commands -maxdepth 1 -type f -name '*.md'; find skills templates -type f -name '*.md'; } 2>/dev/null \
  | sort > "$TMP/lw.files"
: > "$TMP/lw.rows"
if [ -s "$TMP/lw.files" ]; then
  # shellcheck disable=SC2046
  awk '
    FNR == 1 { fence = 0; intable = 0; prev = 0 }
    /^[[:space:]]*```/ { fence = !fence; intable = 0; prev = 0; next }
    fence { next }
    !/^[[:space:]]*\|/ { intable = 0; prev = 0; next }
    !prev { prev = 1; intable = (tolower($0) ~ /load when/); if (intable) printf "%s\t%d\tH\t%s\n", FILENAME, FNR, $0; next }
    intable && !/^[[:space:]]*\|[-:|[:space:]]*$/ { printf "%s\t%d\tR\t%s\n", FILENAME, FNR, $0 }
  ' $(cat "$TMP/lw.files") > "$TMP/lw.rows"
fi
ntab=0; nl=0; ncov=0
while IFS="$TAB" read -r f line kind row; do
  [ -n "$f" ] || continue
  if [ "$kind" = H ]; then ntab=$((ntab+1)); continue; fi
  printf '%s\n' "$row" \
    | grep -oE '(\$\{CLAUDE_(SKILL_DIR|PLUGIN_ROOT)\}/)?[A-Za-z0-9_./{}-]*references/[A-Za-z0-9_./{}-]*\.md' \
    > "$TMP/lw.toks"
  while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    case "$tok" in
      '${CLAUDE_'*)
        case "$f" in agents/*|skills/*|commands/*) ncov=$((ncov+1)); continue ;; esac # verified by check 2
        rel=${tok#*\}/} ;;
      *) rel=$tok ;;
    esac
    case "$rel" in *'{'*|*'}'*) continue ;; esac # templated
    nl=$((nl+1))
    sd=$(skill_dir "$f")
    case "$tok" in
      '${CLAUDE_PLUGIN_ROOT}/'*|skills/*) target="$rel" ;;
      '${CLAUDE_SKILL_DIR}/'*)
        if [ -z "$sd" ]; then bad "load-when $f:$line: $tok (\${CLAUDE_SKILL_DIR} used outside a skill)"; continue; fi
        target="$sd/$rel" ;;
      references/*) # bare: relative to the skill that holds the table (else to the citing file's directory)
        if [ -n "$sd" ]; then target="$sd/$rel"; else target="$(dirname "$f")/$rel"; fi ;;
      *) target="$(dirname "$f")/$rel" ;;
    esac
    if [ -e "$target" ]; then ok; else bad "load-when $f:$line: $tok"; fi
  done < "$TMP/lw.toks"
done < "$TMP/lw.rows"
end_check "load-when: $ntab tables, $nl reference paths exist ($ncov more verified by the path check)"

# ---- 4. Stale references -----------------------------------------------------------------------------------
# 4a. The old monolithic brief file (skills/sdlc-dispatch/references/briefs.md) was split into references/briefs/.
#     Scope: shipped plugin content and top-level docs; docs/plans/ (historical records) and tests/ are excluded.
STALE_SCOPE="agents skills commands templates hooks tracker .claude-plugin README.md"
for d in docs/*.md; do [ -f "$d" ] && STALE_SCOPE="$STALE_SCOPE $d"; done
# shellcheck disable=SC2086
grep -rnIoE --exclude-dir=__pycache__ '[A-Za-z0-9_./{}$-]*briefs\.md' $STALE_SCOPE 2>/dev/null \
  | sort -t: -k1,1 -k2,2n > "$TMP/stale"
ns=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  f=${hit%%:*}; rest=${hit#*:}; line=${rest%%:*}; tok=${rest#*:}
  case "$tok" in briefs.md|*/briefs.md) ns=$((ns+1)); bad "stale $f:$line: $tok (removed; use references/briefs/{role}.md)" ;; esac
done < "$TMP/stale"
[ "$ns" -eq 0 ] && ok
end_check "stale: no reference to the removed briefs.md"

# 4b. The quality-gate seed has exactly 9 "## " sections.
QG=templates/rules/quality-gate.md
if [ -f "$QG" ]; then
  nsec=$(grep -c '^## ' "$QG")
  if [ "$nsec" -eq 9 ]; then ok; else bad "stale $QG: $nsec '## ' sections, expected 9"; fi
else
  bad "stale $QG: missing"
fi
end_check "stale: $QG has 9 '## ' sections"

# ---- 5. hooks/hooks.json scripts exist and are executable ---------------------------------------------------
HJ=hooks/hooks.json
nh=0
if ! jq -r '[.. | objects | select(has("command")) | .command] | .[]' "$HJ" > "$TMP/hooks" 2> "$TMP/hooks.err"; then
  bad "hooks $HJ: $(head -1 "$TMP/hooks.err")"
else
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    printf '%s\n' "$cmd" | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^[:space:]"'"'"']+' > "$TMP/hook.toks"
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      nh=$((nh+1))
      script="$ROOT/${tok#\$\{CLAUDE_PLUGIN_ROOT\}/}"
      if [ ! -f "$script" ]; then bad "hooks $tok: missing"
      elif [ ! -x "$script" ]; then bad "hooks $tok: not executable"
      else ok; fi
    done < "$TMP/hook.toks"
  done < "$TMP/hooks"
  [ "$nh" -gt 0 ] || bad "hooks $HJ: no \${CLAUDE_PLUGIN_ROOT}/ script found in any command"
fi
end_check "hooks: $nh scripts exist and are executable"

# ---- 6. plugin.json and marketplace.json carry the same version -----------------------------------------------
PJ=.claude-plugin/plugin.json; MJ=.claude-plugin/marketplace.json
pname=$(jq -r '.name // empty' "$PJ" 2>/dev/null)
pv=$(jq -r '.version // empty' "$PJ" 2>/dev/null)
mv=$(jq -r --arg n "$pname" '(.plugins // []) | (map(select(.name == $n)) + .)[0].version // empty' "$MJ" 2>/dev/null)
if [ -z "$pv" ]; then bad "version $PJ: no .version"
elif [ -z "$mv" ]; then bad "version $MJ: no plugin version"
elif [ "$pv" != "$mv" ]; then bad "version $PJ $pv != $MJ $mv"
else ok; fi
end_check "version: $PJ and $MJ both at ${pv:-?}"

echo "lint: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
