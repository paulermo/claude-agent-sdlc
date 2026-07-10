# /agent-sdlc:tracker — local read-only progress dashboard

**Status:** approved 2026-07-11 (user-selected: single port + project selector; Python3 stdlib)
**Goal:** open a local page showing near-real-time pipeline progress (roadmap, current work,
statuses, drill-down into epic/story/task docs) fed by `docs/state/` v2 files. Read-only.
Ships with the plugin — no JS rewriting per launch. Multiple projects on one machine share
one server on one port with a project switcher.

## Components

```
tracker/server.py         stdlib-only HTTP server (http.server), binds 127.0.0.1
tracker/static/           index.html + app.js + style.css — vanilla, no build, no CDN
commands/tracker.md       /agent-sdlc:tracker
~/.agent-sdlc/tracker/    machine-shared: projects.d/{md5(path)}.json (one file per
                          project — atomic registration, no RMW races), server.json
                          {port,pid,plugin_version,started_at}, server.log
```

## Lifecycle (singleton)

Command: verify project + python3 → write registry file → health-check `server.json`'s port
(`/api/health` → `{app:"agent-sdlc-tracker",version}`) → dead: start detached; alive with
stale `plugin_version`: POST /api/shutdown, start fresh (plugin upgrade ⇒ auto-restart);
alive and current: reuse → wait for health → `open http://127.0.0.1:{port}/?project={path}`.
Ports: scan 4680–4699 (foreign process on port → next); real port always in `server.json`.

## API (no server-side caching; every request re-reads the small v2 files)

- `/api/projects` — registry + liveness (`gone` if path lost; never auto-deleted)
- `/api/state?project=&stamp=` — project/epics/active/backlog + derived per-epic done/total
  (archive included) + archived epic entries + phase; `stamp` = max mtime of state files;
  unchanged → `{unchanged:true}` (cheap 2s polling)
- `/api/archive?project=` — merged done-*.json (read only when the Archive view opens)
- `/api/log?project=&n=` — tail of log.jsonl (reads last 64KB, not the file)
- `/api/item?project=&id=` — entry + its doc markdown (server globs
  `docs/issues/{EPIC}-*/{ID}-*.md` / `epic.md`) + related review/report paths
- `/api/doc?project=&path=` — markdown by path; realpath must stay inside the project,
  start with `docs/`, end `.md` — else 403 (blocks traversal and `.secrets.json`)
- `POST /api/shutdown`

`project` must match a registered path. `.secrets.json` is never read. Legacy v1 layouts are
normalized on the fly (`layout:"v1"` + migrate banner) so the tracker works pre-migration.

## UI (hash-routed SPA, 2s stamp-polling, live dot in header)

Roadmap (epics by priority, progress bars, archived collapsed) · Board (active.json kanban:
Todo / In progress / Review / QA / Merge / Rejected-Failed / Done) · Backlog · Activity
(log tail feed incl. decision lines) · Item (metadata + rendered markdown via ~120-line
vanilla renderer with checkbox support; feedback files open from here). Dark/light via
prefers-color-scheme; offline-safe (zero external resources).

## Errors

No python3 → command stops with instruction. Dead server → next command run restarts
(server.log kept). Gone project → marked in selector. v1 layout → banner, best-effort render.

## Tests

Fixture project in scratchpad → curl all endpoints (stamp-unchanged path, item glob, doc 403
on traversal and .secrets.json), two registered projects on one port, UI screenshot in Chrome.
