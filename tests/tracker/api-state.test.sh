#!/bin/bash
# Tests /api/state milestone_progress of tracker/server.py. Run: bash tests/tracker/api-state.test.sh
# Builds its fixture projects in a fresh mktemp dir on EVERY run (never a committed state fixture), starts the server
# the way commands/tracker.md does but with a fake HOME and base port 4700 (the real tracker lives on 4680-4699 and
# its ~/.agent-sdlc is never touched), and kills the server on exit.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP=$(mktemp -d)
SPID=""
cleanup() {
  if [ -n "$SPID" ]; then kill "$SPID" 2>/dev/null; wait "$SPID" 2>/dev/null; fi
  rm -rf "$TMP"
}
trap cleanup EXIT
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL+1)); echo "FAIL $1"; }
finish() { echo "passed=$PASS failed=$FAIL"; [ "$FAIL" -eq 0 ]; exit $?; }

for tool in python3 jq curl; do
  command -v "$tool" >/dev/null 2>&1 || { fail "$tool is installed"; finish; }
done

export HOME="$TMP/home"
export AGENT_SDLC_TRACKER_BASE_PORT=4700
export CLAUDE_PLUGIN_ROOT="$ROOT"
mkdir -p "$HOME"

# ---------- fixture builders ----------
mkstate() { # $1 project dir, $2 prefix, $3 name -> empty v2 state
  mkdir -p "$1/docs/state/archive"
  printf '{"name":"%s","prefix":"%s","state_version":2,"phase":"implementation"}\n' "$3" "$2" > "$1/docs/state/project.json"
  printf '{"stories":{},"content_tasks":{}}\n' > "$1/docs/state/active.json"
  printf '{"stories":{},"content_tasks":{}}\n' > "$1/docs/state/backlog.json"
  : > "$1/docs/state/log.jsonl"
}

# Project with two milestones (each edge case the server handles is locked in here):
#   TST-MS-1 (in_progress) links TST-EPIC-1 (archived in done-2026-08.json — a SECOND month file, so the archive
#            months must merge: STORY-1 done, BUG-1 done) and TST-EPIC-2 (in_progress, batch at gate run 2:
#            STORY-3 done, STORY-4 in_review, STORY-5 todo); its `stories` ALSO lists TST-STORY-3, an item of a
#            linked epic — counted once (dedup)
#   TST-MS-2 (in_progress) links TST-EPIC-5 (deployed = awaiting main regression: STORY-11 done, STORY-12 done)
#            and the uncut-exception TST-STORY-9 (archived in done-2026-09.json, done) of TST-EPIC-4, whose sibling
#            TST-STORY-10 is NOT in the milestone; no planned_count
#   TST-EPIC-3 (ready, backlog) is linked to no milestone
MS="$TMP/ms-project"; mkstate "$MS" TST "Milestone fixture"
cat > "$MS/docs/state/epics.json" <<'EOF'
{
  "priority_order": ["TST-EPIC-5", "TST-EPIC-2", "TST-EPIC-3"],
  "epics": {
    "TST-EPIC-2": {"title": "Checkout flow", "status": "in_progress", "type": "epic", "brd": "TST-BRD-1",
                   "branch": "feature/TST-EPIC-2-checkout", "lane": "fast",
                   "batch": {"n": 1, "items": null, "stage": "gate", "gate_run": 2, "gated_sha": null},
                   "milestone": "TST-MS-1"},
    "TST-EPIC-3": {"title": "Reporting", "status": "ready", "type": "epic", "brd": "TST-BRD-1",
                   "branch": "feature/TST-EPIC-3-reporting"},
    "TST-EPIC-5": {"title": "Exports", "status": "deployed", "type": "epic", "brd": "TST-BRD-1",
                   "branch": "feature/TST-EPIC-5-exports", "lane": "fast",
                   "batch": {"n": 1, "items": null, "stage": "delivery", "gate_run": 1, "gated_sha": "abc1234"},
                   "milestone": "TST-MS-2"}
  },
  "milestones": {
    "TST-MS-1": {"id": "TST-MS-1", "title": "First demo", "goal": "A user can buy one item.", "target": "2026-10-15",
                 "status": "in_progress", "epics": ["TST-EPIC-1", "TST-EPIC-2"], "stories": ["TST-STORY-3"],
                 "slice_doc": null, "planned_count": {"epics": 2, "items": 6},
                 "created_at": "2026-09-01T10:00:00Z", "delivered_at": null, "demoed_at": null, "closed_at": null},
    "TST-MS-2": {"id": "TST-MS-2", "title": "Reports demo", "goal": "Show the export.", "target": null,
                 "status": "in_progress", "epics": ["TST-EPIC-5"], "stories": ["TST-STORY-9"],
                 "slice_doc": null, "planned_count": null,
                 "created_at": "2026-09-02T10:00:00Z", "delivered_at": null, "demoed_at": null, "closed_at": null}
  },
  "milestone_order": ["TST-MS-1", "TST-MS-2"]
}
EOF
cat > "$MS/docs/state/active.json" <<'EOF'
{"stories": {
  "TST-STORY-3": {"epic": "TST-EPIC-2", "title": "Cart", "kind": "story", "status": "done"},
  "TST-STORY-4": {"epic": "TST-EPIC-2", "title": "Payment", "kind": "story", "status": "in_review"},
  "TST-STORY-5": {"epic": "TST-EPIC-2", "title": "Receipt", "kind": "story", "status": "todo"},
  "TST-STORY-11": {"epic": "TST-EPIC-5", "title": "Export CSV", "kind": "story", "status": "done"},
  "TST-STORY-12": {"epic": "TST-EPIC-5", "title": "Export PDF", "kind": "story", "status": "done"}
 }, "content_tasks": {}}
EOF
cat > "$MS/docs/state/backlog.json" <<'EOF'
{"stories": {
  "TST-STORY-6": {"epic": "TST-EPIC-3", "title": "Charts", "kind": "story", "status": "todo"}
 }, "content_tasks": {}}
EOF
cat > "$MS/docs/state/archive/done-2026-08.json" <<'EOF'
{"epics": {
  "TST-EPIC-1": {"title": "Catalog", "status": "done", "type": "epic", "brd": "TST-BRD-1",
                 "branch": "feature/TST-EPIC-1-catalog", "milestone": "TST-MS-1"}
 },
 "stories": {
  "TST-STORY-1": {"epic": "TST-EPIC-1", "title": "List products", "kind": "story", "status": "done"},
  "TST-BUG-1": {"epic": "TST-EPIC-1", "title": "Price rounds wrong", "kind": "bug", "status": "done"}
 },
 "content_tasks": {}}
EOF
cat > "$MS/docs/state/archive/done-2026-09.json" <<'EOF'
{"epics": {
  "TST-EPIC-4": {"title": "Admin", "status": "done", "type": "epic", "brd": "TST-BRD-1",
                 "branch": "feature/TST-EPIC-4-admin"}
 },
 "stories": {
  "TST-STORY-9": {"epic": "TST-EPIC-4", "title": "Report page", "kind": "story", "status": "done",
                  "milestone": "TST-MS-2"},
  "TST-STORY-10": {"epic": "TST-EPIC-4", "title": "Audit log", "kind": "story", "status": "done"}
 },
 "content_tasks": {}}
EOF

# v2 project without milestones (epics.json has no milestones keys at all)
NOMS="$TMP/no-ms-project"; mkstate "$NOMS" NOM "No milestones"
cat > "$NOMS/docs/state/epics.json" <<'EOF'
{"priority_order": ["NOM-EPIC-1"],
 "epics": {"NOM-EPIC-1": {"title": "Only epic", "status": "in_progress", "type": "epic"}}}
EOF
printf '{"stories":{"NOM-STORY-1":{"epic":"NOM-EPIC-1","title":"x","status":"in_progress"}},"content_tasks":{}}\n' \
  > "$NOMS/docs/state/active.json"

# Legacy v1 project (stories.json present, no buckets, no milestones)
V1="$TMP/v1-project"; mkdir -p "$V1/docs/state"
printf '{"name":"Legacy","prefix":"OLD","phase":"implementation"}\n' > "$V1/docs/state/project.json"
printf '{"priority_order":["OLD-EPIC-1"],"epics":{"OLD-EPIC-1":{"title":"Old","status":"in_progress","history":[]}}}\n' \
  > "$V1/docs/state/epics.json"
printf '{"OLD-STORY-1":{"epic":"OLD-EPIC-1","title":"Old story","status":"done","history":[]}}\n' \
  > "$V1/docs/state/stories.json"

# ---------- register (commands/tracker.md Step 2, verbatim, run inside each project) ----------
register() {
  (
    cd "$1" || exit 1
    mkdir -p ~/.agent-sdlc/tracker/projects.d
    PROJ="$(pwd)"
    HASH=$(python3 -c 'import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:12])' "$PROJ")
    NAME=$(jq -r '.name // "unknown"' docs/state/project.json)
    PREFIX=$(jq -r '.prefix // "?"' docs/state/project.json)
    printf '{"path": "%s", "name": "%s", "prefix": "%s"}\n' "$PROJ" "$NAME" "$PREFIX" > ~/.agent-sdlc/tracker/projects.d/"$HASH".json
  )
}
register "$MS"; register "$NOMS"; register "$V1"

# ---------- start the server (commands/tracker.md Step 3) ----------
nohup python3 "${CLAUDE_PLUGIN_ROOT}/tracker/server.py" >> ~/.agent-sdlc/tracker/server.log 2>&1 &
SPID=$!
PORT=""; HEALTH=""
for i in $(seq 1 20); do
  PORT=$(jq -r '.port // empty' ~/.agent-sdlc/tracker/server.json 2>/dev/null)
  HEALTH=$(curl -sf -m 1 "http://127.0.0.1:${PORT:-0}/api/health" 2>/dev/null) && break
  sleep 0.5
done
# Isolation: the answering server must be the one this test started, inside 4700-4719.
if [ -n "$HEALTH" ] && [ "$(printf '%s' "$HEALTH" | jq -r .pid)" = "$SPID" ] \
   && [ "$PORT" -ge 4700 ] && [ "$PORT" -le 4719 ]; then
  pass "server started by this test answers on port $PORT"
else
  fail "server started by this test answers (port=${PORT:-none}, health=${HEALTH:-none}, pid=$SPID)"
  tail -20 ~/.agent-sdlc/tracker/server.log 2>/dev/null
  finish
fi

state() { # $1 project dir -> /api/state JSON on stdout (empty on HTTP error)
  local q
  q=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1")
  curl -sf -m 5 "http://127.0.0.1:${PORT}/api/state?project=${q}"
}

# expect NAME JSON JQ-PATH EXPECTED-JSON — compares canonical (jq -c) values
expect() {
  local got want
  got=$(printf '%s' "$2" | jq -c "$3" 2>/dev/null)
  want=$(printf '%s' "$4" | jq -c . 2>/dev/null)
  if [ -n "$got" ] && [ "$got" = "$want" ]; then pass "$1"
  else fail "$1 (expected $want, got ${got:-<no value>})"; fi
}

S=$(state "$MS")
expect "milestones project: /api/state answers"          "$S" '.layout'                               '"v2"'
expect "milestone_progress lists exactly both milestones" "$S" '.milestone_progress | keys'           '["TST-MS-1","TST-MS-2"]'
SHAPE='["epics_deployed","epics_done","epics_total","in_flight","items_done","items_total","planned_items"]'
expect "MS-1 has the full shape (no key missing)"       "$S" '.milestone_progress["TST-MS-1"] | keys' "$SHAPE"
expect "MS-2 has the full shape (no key missing)"       "$S" '.milestone_progress["TST-MS-2"] | keys' "$SHAPE"
P1='.milestone_progress["TST-MS-1"]'
expect "MS-1 epics_total (archived + active epic)"       "$S" "$P1.epics_total"                       '2'
expect "MS-1 epics_done (epic archived in the 2nd month file)" "$S" "$P1.epics_done"                  '1'
expect "MS-1 epics_deployed"                             "$S" "$P1.epics_deployed"                    '0'
expect "MS-1 items_total (2 archived + 3 active; STORY-3 listed twice, counted once)" "$S" "$P1.items_total" '5'
expect "MS-1 items_done (2 archived + 1 active)"         "$S" "$P1.items_done"                        '3'
expect "MS-1 in_flight (the in_review story only)"       "$S" "$P1.in_flight"                         '["TST-STORY-4"]'
expect "MS-1 planned_items from planned_count.items"     "$S" "$P1 | [has(\"planned_items\"), .planned_items]" '[true,6]'
P2='.milestone_progress["TST-MS-2"]'
expect "MS-2 epics_total (the deployed epic)"            "$S" "$P2.epics_total"                       '1'
expect "MS-2 epics_done (deployed is not done)"          "$S" "$P2.epics_done"                        '0'
expect "MS-2 epics_deployed"                             "$S" "$P2.epics_deployed"                    '1'
expect "MS-2 items_total (2 of the deployed epic + the archived uncut story)" "$S" "$P2.items_total"   '3'
expect "MS-2 items_done"                                 "$S" "$P2.items_done"                        '3'
expect "MS-2 in_flight"                                  "$S" "$P2.in_flight"                         '[]'
expect "MS-2 planned_items present and null (no planned_count)" "$S" "$P2 | [has(\"planned_items\"), .planned_items]" '[true,null]'
expect "epic_progress still served (regression)"         "$S" '.epic_progress["TST-EPIC-2"]'          '{"total":3,"done":1}'

S=$(state "$NOMS")
expect "project without milestones: milestone_progress is {}" "$S" '.milestone_progress'             '{}'

S=$(state "$V1")
expect "legacy v1 project: layout v1 served"             "$S" '.layout'                               '"v1"'
expect "legacy v1 project: milestone_progress is {}"     "$S" '.milestone_progress'                   '{}'

finish
