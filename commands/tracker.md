---
name: "agent-sdlc:tracker"
description: "Open the local read-only progress dashboard in the browser"
---

Launch (or attach to) the agent-sdlc tracker — a local web dashboard that shows this project's pipeline progress in near-real-time by reading `docs/state/`. Read-only: it visualizes, never manages. One tracker server per machine serves ALL registered projects on one port with a project switcher.

## Step 1: Preconditions

| Check | Command | On failure |
|-------|---------|------------|
| Project initialized | `[ -f docs/state/project.json ]` | "SDLC not initialized. Run `/agent-sdlc:init` first." — stop |
| python3 present | `command -v python3` | "The tracker needs python3 (stdlib only). Install Xcode CLT / python3 and retry." — stop |

Legacy state layout (`docs/state/stories.json` still present) is NOT a blocker — the tracker renders it with a migrate banner.

## Step 2: Register this project

```bash
mkdir -p ~/.agent-sdlc/tracker/projects.d
PROJ="$(pwd)"
HASH=$(python3 -c 'import hashlib,sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest()[:12])' "$PROJ")
NAME=$(jq -r '.name // "unknown"' docs/state/project.json)
PREFIX=$(jq -r '.prefix // "?"' docs/state/project.json)
printf '{"path": "%s", "name": "%s", "prefix": "%s"}\n' "$PROJ" "$NAME" "$PREFIX" > ~/.agent-sdlc/tracker/projects.d/"$HASH".json
```

One file per project — re-running just rewrites the same file; no shared-file races between projects.

## Step 3: Ensure the server (singleton, version-matched)

```bash
PLUGIN_VERSION=$(jq -r .version "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
PORT=$(jq -r '.port // empty' ~/.agent-sdlc/tracker/server.json 2>/dev/null)
HEALTH=$(curl -sf -m 1 "http://127.0.0.1:${PORT:-0}/api/health" 2>/dev/null)
```

| Situation | Action |
|-----------|--------|
| `HEALTH` empty (no server / stale server.json) | start it (below) |
| `HEALTH` has `"app": "agent-sdlc-tracker"` and `.version == $PLUGIN_VERSION` | reuse — skip to Step 4 |
| `HEALTH` ours but version differs (plugin was updated) | `curl -s -X POST http://127.0.0.1:$PORT/api/shutdown`, wait 1s, start fresh — this is how the UI/server code refreshes after a plugin update |
| Port answers but `"app"` is not ours | do nothing special — the server scans 4680-4699 itself and records the real port in server.json |

Start (background — the server must outlive this session):

```bash
nohup python3 "${CLAUDE_PLUGIN_ROOT}/tracker/server.py" >> ~/.agent-sdlc/tracker/server.log 2>&1 &
```

Then wait until healthy (give up after ~10s and show `tail -20 ~/.agent-sdlc/tracker/server.log`):

```bash
for i in $(seq 1 20); do
  PORT=$(jq -r '.port // empty' ~/.agent-sdlc/tracker/server.json 2>/dev/null)
  curl -sf -m 1 "http://127.0.0.1:${PORT:-0}/api/health" >/dev/null 2>&1 && break
  sleep 0.5
done
```

## Step 4: Open the browser

```bash
URL="http://127.0.0.1:${PORT}/?project=$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "$PROJ")"
open "$URL" 2>/dev/null || xdg-open "$URL" 2>/dev/null || true
```

## Step 5: Report

Output exactly this shape (fill the placeholders):

> Tracker running: {URL}
> Views: Roadmap · Board · Backlog · Activity · Archive — click any epic/story/task for its document.
> Data refreshes every 2s from docs/state/; the page needs no restart when state changes.
> All registered projects are available in the project switcher (top-left).
> Stop the server: `curl -X POST http://127.0.0.1:{PORT}/api/shutdown`

## MUST NOT DO

- Do not edit anything under `docs/state/` from this command — the tracker is read-only and so is its launcher (registration writes ONLY to `~/.agent-sdlc/tracker/`).
- Do not start a second server when a healthy same-version one answers — reuse it (the singleton is the multi-project design).
- Do not kill a version-matched running server "just to be safe" — other projects' tabs are using it.
