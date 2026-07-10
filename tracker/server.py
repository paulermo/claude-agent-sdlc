#!/usr/bin/env python3
"""agent-sdlc tracker — local read-only progress dashboard.

Stdlib only. Binds 127.0.0.1, serves the static UI from the plugin and a
small JSON API over the docs/state files of projects registered in
~/.agent-sdlc/tracker/projects.d/. One server per machine (singleton on a
port from BASE_PORT..BASE_PORT+19); /agent-sdlc:tracker manages the
lifecycle (start, version-mismatch restart, browser open).

Never reads docs/state/.secrets.json. /api/doc serves only docs/**/*.md
resolved inside the requesting project.
"""

import json
import hashlib
import os
import re
import socket
import sys
import threading
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
STATIC_DIR = Path(__file__).resolve().parent / "static"
TRACKER_DIR = Path.home() / ".agent-sdlc" / "tracker"
PROJECTS_D = TRACKER_DIR / "projects.d"
SERVER_JSON = TRACKER_DIR / "server.json"
BASE_PORT = 4680
PORT_SPAN = 20
APP = "agent-sdlc-tracker"

ACTIVE_EPIC_STATUSES = {"in_progress", "ready_for_deploy", "deployed"}
STATE_FILES = ["project.json", "epics.json", "active.json", "backlog.json", "log.jsonl"]
CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
}


def plugin_version():
    try:
        with open(PLUGIN_ROOT / ".claude-plugin" / "plugin.json", encoding="utf-8") as f:
            return json.load(f).get("version", "0")
    except Exception:
        return "0"


VERSION = plugin_version()


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def registry():
    """{realpath_str: {path, name, prefix}} from projects.d/*.json."""
    out = {}
    if PROJECTS_D.is_dir():
        for f in sorted(PROJECTS_D.glob("*.json")):
            meta = read_json(f)
            if isinstance(meta, dict) and meta.get("path"):
                out[str(Path(meta["path"]).resolve())] = meta
    return out


def resolve_project(param):
    """Registered project path or None. Only registered dirs are ever read."""
    if not param:
        return None
    real = str(Path(param).resolve())
    return Path(real) if real in registry() else None


def state_dir(proj):
    return proj / "docs" / "state"


def empty_bucket():
    return {"stories": {}, "content_tasks": {}}


def load_buckets(proj):
    """Normalized (layout, epics_doc, active, backlog, archived) for v2 or legacy v1."""
    sd = state_dir(proj)
    epics_doc = read_json(sd / "epics.json") or {"priority_order": [], "epics": {}}
    for e in epics_doc.get("epics", {}).values():
        e.pop("history", None)

    if (sd / "stories.json").exists() or (sd / "content-tasks.json").exists():
        # Legacy v1: single maps + inline history; bucket on the fly by epic status.
        active, backlog = empty_bucket(), empty_bucket()
        archived = {"epics": {}, "stories": {}, "content_tasks": {}}
        epics = epics_doc.get("epics", {})
        for kind, fname in (("stories", "stories.json"), ("content_tasks", "content-tasks.json")):
            for item_id, entry in (read_json(sd / fname) or {}).items():
                entry = dict(entry)
                entry.pop("history", None)
                epic_status = epics.get(entry.get("epic"), {}).get("status", "planning")
                if epic_status == "done":
                    archived[kind][item_id] = entry
                elif epic_status in ACTIVE_EPIC_STATUSES:
                    active[kind][item_id] = entry
                else:
                    backlog[kind][item_id] = entry
        for epic_id, e in list(epics.items()):
            if e.get("status") == "done":
                archived["epics"][epic_id] = e
        return "v1", epics_doc, active, backlog, archived

    active = read_json(sd / "active.json") or empty_bucket()
    backlog = read_json(sd / "backlog.json") or empty_bucket()
    archived = {"epics": {}, "stories": {}, "content_tasks": {}}
    arch_dir = sd / "archive"
    if arch_dir.is_dir():
        for f in sorted(arch_dir.glob("done-*.json")):
            month = read_json(f) or {}
            for key in archived:
                archived[key].update(month.get(key, {}))
    return "v2", epics_doc, active, backlog, archived


def epic_progress(epics_doc, active, backlog, archived):
    """{epic_id: {total, done}} across all buckets."""
    prog = {}
    ids = set(epics_doc.get("epics", {})) | set(archived["epics"])
    for eid in ids:
        prog[eid] = {"total": 0, "done": 0}
    for bucket in (active, backlog, archived):
        for kind in ("stories", "content_tasks"):
            for entry in bucket.get(kind, {}).values():
                eid = entry.get("epic")
                if eid not in prog:
                    prog[eid] = {"total": 0, "done": 0}
                prog[eid]["total"] += 1
                if entry.get("status") == "done":
                    prog[eid]["done"] += 1
    return prog


def compute_stamp(proj):
    sd = state_dir(proj)
    parts = []
    for name in STATE_FILES + ["stories.json", "content-tasks.json"]:
        p = sd / name
        parts.append(str(int(p.stat().st_mtime)) if p.exists() else "0")
    arch = sd / "archive"
    if arch.is_dir():
        for f in sorted(arch.glob("done-*.json")):
            parts.append(f.name + str(int(f.stat().st_mtime)))
    return hashlib.md5("|".join(parts).encode()).hexdigest()[:16]


def api_state(proj, given_stamp):
    stamp = compute_stamp(proj)
    if given_stamp and given_stamp == stamp:
        return {"unchanged": True, "stamp": stamp}
    layout, epics_doc, active, backlog, archived = load_buckets(proj)
    project = read_json(state_dir(proj) / "project.json") or {}
    project.pop("agents", None)  # registry noise, UI never needs it
    return {
        "stamp": stamp,
        "layout": layout,
        "project": project,
        "epics": epics_doc,
        "active": active,
        "backlog": backlog,
        "archived_epics": archived["epics"],
        "epic_progress": epic_progress(epics_doc, active, backlog, archived),
    }


def api_projects():
    out = []
    for real, meta in registry().items():
        pj = read_json(Path(real) / "docs" / "state" / "project.json")
        out.append({
            "path": real,
            "name": (pj or {}).get("name") or meta.get("name") or Path(real).name,
            "prefix": (pj or {}).get("prefix") or meta.get("prefix") or "?",
            "phase": (pj or {}).get("phase", "unknown"),
            "alive": pj is not None,
        })
    return {"projects": sorted(out, key=lambda p: p["name"].lower())}


def api_log(proj, n):
    path = state_dir(proj) / "log.jsonl"
    if not path.exists():
        return {"lines": []}
    with open(path, "rb") as f:
        f.seek(0, os.SEEK_END)
        size = f.tell()
        f.seek(max(0, size - 65536))
        raw = f.read().decode("utf-8", errors="replace")
    lines = []
    for line in raw.splitlines()[-n:]:
        try:
            lines.append(json.loads(line))
        except Exception:
            continue
    return {"lines": lines}


def find_entry(proj, item_id):
    """(kind, bucket_name, entry) searching active → backlog → archive → epics."""
    layout, epics_doc, active, backlog, archived = load_buckets(proj)
    for bucket_name, bucket in (("active", active), ("backlog", backlog), ("archive", archived)):
        for kind in ("stories", "content_tasks"):
            if item_id in bucket.get(kind, {}):
                return kind, bucket_name, bucket[kind][item_id]
    if item_id in epics_doc.get("epics", {}):
        return "epic", "epics", epics_doc["epics"][item_id]
    if item_id in archived["epics"]:
        return "epic", "archive", archived["epics"][item_id]
    return None, None, None


def safe_doc_path(proj, rel):
    """Resolve rel inside proj; docs/**/*.md only."""
    if not rel or rel.startswith(("/", "~")) or ".." in Path(rel).parts:
        return None
    full = (proj / rel).resolve()
    try:
        inside = full.relative_to(proj.resolve())
    except ValueError:
        return None
    if inside.parts[:1] != ("docs",) or full.suffix != ".md" or not full.is_file():
        return None
    return full


def read_doc(proj, rel):
    full = safe_doc_path(proj, rel)
    if not full:
        return None
    try:
        return full.read_text(encoding="utf-8", errors="replace")[:524288]
    except Exception:
        return None


def api_item(proj, item_id):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", item_id or ""):
        return None
    kind, bucket, entry = find_entry(proj, item_id)
    if entry is None:
        return None
    doc_path = None
    if kind == "epic":
        hits = sorted(proj.glob("docs/issues/%s-*/epic.md" % item_id))
    else:
        epic_id = entry.get("epic", "")
        hits = sorted(proj.glob("docs/issues/%s-*/%s-*.md" % (epic_id, item_id)))
        if not hits:
            hits = sorted(proj.glob("docs/issues/*/%s-*.md" % item_id))
    if hits:
        doc_path = str(hits[0].relative_to(proj))
    related = []
    for field in ("review_feedback", "qa_feedback", "regression_feedback"):
        val = entry.get(field)
        if isinstance(val, str) and val.startswith("docs/"):
            related.append({"label": field.replace("_", " "), "path": val})
    for pattern, label in (("docs/reviews/%s-*.md", "review"), ("docs/reports/%s-*.md", "report")):
        for hit in sorted(proj.glob(pattern % item_id)):
            rel = str(hit.relative_to(proj))
            if all(r["path"] != rel for r in related):
                related.append({"label": label, "path": rel})
    return {
        "id": item_id,
        "kind": kind,
        "bucket": bucket,
        "entry": entry,
        "doc_path": doc_path,
        "doc": read_doc(proj, doc_path) if doc_path else None,
        "related": related,
    }


def api_archive(proj):
    _, _, _, _, archived = load_buckets(proj)
    return archived


class Handler(BaseHTTPRequestHandler):
    server_version = APP + "/" + VERSION

    def log_message(self, fmt, *args):  # keep server.log terse: errors only
        if args and str(args[1] if len(args) > 1 else "").startswith(("4", "5")):
            sys.stderr.write("%s %s\n" % (self.log_date_time_string(), fmt % args))

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_static(self, rel):
        full = (STATIC_DIR / rel).resolve()
        if not str(full).startswith(str(STATIC_DIR.resolve())) or not full.is_file():
            return self.send_json({"error": "not found"}, 404)
        body = full.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", CONTENT_TYPES.get(full.suffix, "application/octet-stream"))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def project_or_400(self, q):
        proj = resolve_project((q.get("project") or [""])[0])
        if proj is None:
            self.send_json({"error": "unknown or unregistered project"}, 400)
        return proj

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        route = url.path
        try:
            if route == "/" or route == "/index.html":
                return self.send_static("index.html")
            if route.startswith("/static/"):
                return self.send_static(route[len("/static/"):])
            if route == "/favicon.ico":
                self.send_response(204)
                self.end_headers()
                return
            if route == "/api/health":
                return self.send_json({"app": APP, "version": VERSION, "pid": os.getpid(),
                                       "port": self.server.server_address[1]})
            if route == "/api/projects":
                return self.send_json(api_projects())
            proj = self.project_or_400(q)
            if proj is None:
                return
            if route == "/api/state":
                return self.send_json(api_state(proj, (q.get("stamp") or [None])[0]))
            if route == "/api/archive":
                return self.send_json(api_archive(proj))
            if route == "/api/log":
                n = min(max(int((q.get("n") or ["50"])[0]), 1), 500)
                return self.send_json(api_log(proj, n))
            if route == "/api/item":
                item = api_item(proj, (q.get("id") or [""])[0])
                return self.send_json(item if item else {"error": "not found"}, 200 if item else 404)
            if route == "/api/doc":
                text = read_doc(proj, (q.get("path") or [""])[0])
                if text is None:
                    return self.send_json({"error": "forbidden or missing"}, 403)
                return self.send_json({"path": q["path"][0], "markdown": text})
            self.send_json({"error": "not found"}, 404)
        except BrokenPipeError:
            pass
        except Exception as exc:  # never take the singleton down over one request
            try:
                self.send_json({"error": str(exc)}, 500)
            except Exception:
                pass

    def do_POST(self):
        if urlparse(self.path).path == "/api/shutdown":
            self.send_json({"ok": True, "pid": os.getpid()})
            threading.Thread(target=self.server.shutdown, daemon=True).start()
        else:
            self.send_json({"error": "not found"}, 404)


def existing_server():
    info = read_json(SERVER_JSON)
    if not info or not info.get("port"):
        return None
    try:
        with urllib.request.urlopen(
                "http://127.0.0.1:%s/api/health" % info["port"], timeout=1) as resp:
            health = json.load(resp)
        if health.get("app") == APP:
            return health
    except Exception:
        return None
    return None


def pick_port():
    for port in range(BASE_PORT, BASE_PORT + PORT_SPAN):
        try:
            probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            probe.bind(("127.0.0.1", port))
            probe.close()
            return port
        except OSError:
            continue
    raise SystemExit("no free port in %d-%d" % (BASE_PORT, BASE_PORT + PORT_SPAN - 1))


def main():
    TRACKER_DIR.mkdir(parents=True, exist_ok=True)
    PROJECTS_D.mkdir(parents=True, exist_ok=True)

    alive = existing_server()
    if alive:
        if alive.get("version") == VERSION:
            print("already running: http://127.0.0.1:%s (v%s)" % (alive["port"], VERSION))
            return
        # version mismatch: the command normally shuts the old one down first,
        # but be self-sufficient if started by hand
        try:
            req = urllib.request.Request(
                "http://127.0.0.1:%s/api/shutdown" % alive["port"], method="POST", data=b"")
            urllib.request.urlopen(req, timeout=2).read()
            time.sleep(0.5)
        except Exception:
            pass

    port = pick_port()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    SERVER_JSON.write_text(json.dumps({
        "port": port, "pid": os.getpid(), "plugin_version": VERSION,
        "started_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }, indent=2))
    print("%s v%s on http://127.0.0.1:%d (pid %d)" % (APP, VERSION, port, os.getpid()))
    try:
        server.serve_forever()
    finally:
        info = read_json(SERVER_JSON)
        if info and info.get("pid") == os.getpid():
            SERVER_JSON.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
