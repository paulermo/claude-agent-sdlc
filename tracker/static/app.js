/* agent-sdlc tracker SPA — vanilla JS, no build, no external deps.
   Polls /api/state every 2s with a stamp; re-renders only on change. */
(() => {
  "use strict";

  // ---------- stage model (hues validated for both modes — see style.css) ----------
  const STAGES = [
    { key: "todo",    label: "Todo",              cls: "neutral", statuses: ["todo"] },
    { key: "wip",     label: "In progress",       cls: "wip",     statuses: ["in_progress", "creating", "integrating"] },
    { key: "review",  label: "Review",            cls: "review",  statuses: ["ready_for_review", "in_review", "ready_for_integration"] },
    { key: "qa",      label: "QA",                cls: "qa",      statuses: ["ready_for_qa", "in_qa"] },
    { key: "merge",   label: "Merge",             cls: "merge",   statuses: ["ready_for_merge", "merged"] },
    { key: "blocked", label: "Rejected / Failed", cls: "blocked", statuses: ["review_rejected", "qa_rejected", "regression_failed"] },
    { key: "done",    label: "Done",              cls: "done",    statuses: ["done"] },
  ];
  const STATUS_CLS = {};
  STAGES.forEach(s => s.statuses.forEach(st => { STATUS_CLS[st] = s.cls; }));
  const EPIC_CLS = { planning: "neutral", ready: "neutral", frozen: "neutral",
    in_progress: "wip", ready_for_deploy: "merge", deployed: "merge", done: "done" };

  const S = { project: null, data: null, stamp: null, log: [], archive: null,
    archiveStamp: null, view: "roadmap", itemId: null, docPath: null,
    item: null, itemStamp: null, ok: false, last: null };

  const $ = sel => document.querySelector(sel);
  const view = $("#view");

  // ---------- utils ----------
  const esc = s => String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const chip = (status, cls) =>
    `<span class="chip ${cls || STATUS_CLS[status] || "neutral"}">${esc(String(status).replace(/_/g, " "))}</span>`;
  const meter = p => {
    const pct = p && p.total ? Math.round(100 * p.done / p.total) : 0;
    return `<div class="meter"><div class="track"><div class="fill" style="width:${pct}%"></div></div>
      <span class="num">${p ? p.done : 0}/${p ? p.total : 0}</span></div>`;
  };
  const fmtTime = iso => {
    const d = new Date(iso);
    return isNaN(d) ? esc(iso || "") :
      d.toLocaleDateString(undefined, { month: "short", day: "2-digit" }) + " " +
      d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  };

  async function api(path, params) {
    const q = new URLSearchParams(params || {});
    const resp = await fetch(path + (q.toString() ? "?" + q : ""));
    if (!resp.ok) throw new Error(path + " → " + resp.status);
    return resp.json();
  }

  // ---------- data ----------
  async function loadProjects() {
    const { projects } = await api("/api/projects");
    const sel = $("#project-select");
    sel.innerHTML = projects.map(p =>
      `<option value="${esc(p.path)}" ${p.alive ? "" : "disabled"}>
        ${esc(p.prefix)} — ${esc(p.name)}${p.alive ? "" : " (gone)"}</option>`).join("");
    const wanted = new URLSearchParams(location.search).get("project");
    const found = projects.find(p => p.path === wanted && p.alive) || projects.find(p => p.alive);
    if (found) { sel.value = found.path; setProject(found.path, true); }
    else view.innerHTML = `<div class="empty">No projects registered. Run <code>/agent-sdlc:tracker</code> in a project.</div>`;
    sel.onchange = () => setProject(sel.value);
  }

  function setProject(path, keepUrl) {
    S.project = path; S.data = null; S.stamp = null; S.archive = null; S.item = null;
    if (!keepUrl) history.replaceState(null, "", "?project=" + encodeURIComponent(path) + location.hash);
    refresh();
  }

  async function refresh() {
    if (!S.project) return;
    try {
      const payload = await api("/api/state", { project: S.project, stamp: S.stamp || "" });
      if (!payload.unchanged) {
        S.data = payload; S.stamp = payload.stamp;
        S.log = (await api("/api/log", { project: S.project, n: 100 })).lines;
        render();
      }
      S.ok = true; S.last = new Date();
    } catch (e) {
      S.ok = false;
    }
    const live = $("#live");
    live.classList.toggle("stale", !S.ok);
    $("#live-text").textContent = S.ok
      ? "live · " + S.last.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit", second: "2-digit" })
      : "server unreachable";
    if (S.data) $("#phase").textContent = (S.data.project.phase || "?") + (S.data.layout === "v1" ? " · legacy" : "");
  }

  // ---------- routing ----------
  function route() {
    const h = location.hash || "#/roadmap";
    const mItem = h.match(/^#\/item\/([A-Za-z0-9_-]+)/);
    if (mItem) { S.view = "item"; S.itemId = mItem[1]; S.docPath = null; }
    else { S.view = h.replace(/^#\//, "") || "roadmap"; S.itemId = null; S.docPath = null; }
    render();
  }
  window.addEventListener("hashchange", route);

  // ---------- renders ----------
  function render() {
    document.body.dataset.view = S.view;  // drives per-view layout (e.g. full-width board)
    document.querySelectorAll("#nav a").forEach(a =>
      a.classList.toggle("on", a.dataset.view === S.view));
    if (!S.data) { view.innerHTML = `<div class="empty">Loading…</div>`; return; }
    ({ roadmap: renderRoadmap, board: renderBoard, backlog: renderBacklog,
       activity: renderActivity, archive: renderArchive, item: renderItem }[S.view] || renderRoadmap)();
  }

  const v1banner = () => S.data.layout === "v1"
    ? `<div class="banner">Legacy state layout — run <code>/agent-sdlc:init</code> in this project to migrate to state v2.</div>` : "";

  function epicCard(id, e, progress, archived) {
    const cls = EPIC_CLS[e.status] || "neutral";
    return `<div class="card epic-card clicky" data-item="${esc(id)}">
      <div class="head">${chip(e.status, cls)}<span class="title">${esc(e.title)}</span></div>
      ${meter(progress)}
      <div class="sub"><span class="id mono">${esc(id)}</span>
        <span>${e.type === "cepic" ? "content epic" : "epic"}</span>
        ${e.branch ? `<span class="mono">${esc(e.branch)}</span>` : ""}
        ${archived ? "<span>archived</span>" : ""}</div>
    </div>`;
  }

  function renderRoadmap() {
    const d = S.data, epics = d.epics.epics || {};
    const order = (d.epics.priority_order || []).filter(id => epics[id]);
    Object.keys(epics).forEach(id => { if (!order.includes(id)) order.push(id); });
    const live = order.map((id, i) =>
      `<div style="display:flex;gap:10px;align-items:center">
        <span class="id mono" style="color:var(--muted);width:18px;flex:none">${i + 1}</span>
        <div style="flex:1">${epicCard(id, epics[id], d.epic_progress[id])}</div></div>`).join("");
    const arch = Object.entries(d.archived_epics || {});
    view.innerHTML = v1banner() +
      (live ? `<div class="epic-list">${live}</div>` : `<div class="empty">No epics yet — the pipeline hasn't planned anything.</div>`) +
      (arch.length ? `<details class="archived"><summary>Archived epics (${arch.length})</summary>
        <div class="epic-list">${arch.map(([id, e]) => epicCard(id, e, d.epic_progress[id], true)).join("")}</div></details>` : "");
  }

  function taskCard(id, entry) {
    return `<div class="task" data-item="${esc(id)}">
      <div class="id mono">${esc(id)}${entry.assignee ? " · " + esc(entry.assignee) : ""}</div>
      <div class="t">${esc(entry.title)}</div>
      <div class="meta">${chip(entry.status)}${entry.epic ? `<span class="chip neutral">${esc(entry.epic)}</span>` : ""}</div>
    </div>`;
  }

  function planningStrip() {
    // Live planning work: epics in `planning`, or whose latest log line is an
    // open `dispatch: {Role}` (planning chain leaves no status transitions).
    const epics = S.data.epics.epics || {};
    const lastLine = {};
    S.log.forEach(l => { if (l.item) lastLine[l.item] = l; });
    const rows = Object.entries(epics)
      .filter(([id, e]) => e.status === "planning" ||
        (lastLine[id] && String(lastLine[id].trigger || "").startsWith("dispatch:")))
      .map(([id, e]) => {
        const l = lastLine[id];
        const who = l && String(l.trigger || "").startsWith("dispatch:")
          ? `<span class="chip wip">${esc(l.trigger.replace("dispatch:", "").trim())} working</span>
             <span class="trigger">since ${fmtTime(l.at)}</span>`
          : `<span class="trigger">${esc(l && l.note ? l.note : "waiting for the planning chain")}</span>`;
        return `<div class="row" data-item="${esc(id)}"><span class="id mono">${esc(id)}</span>
          <span class="t">${esc(e.title)}</span>${chip(e.status, EPIC_CLS[e.status])}${who}</div>`;
      });
    return rows.length
      ? `<div class="group"><div class="card"><h3 style="margin:0 0 4px;font-size:12px;color:var(--ink-2)">Planning in flight</h3>
         <div class="rows">${rows.join("")}</div></div></div>` : "";
  }

  function renderBoard() {
    const a = S.data.active;
    const all = Object.entries(a.stories || {}).concat(Object.entries(a.content_tasks || {}));
    const strip = planningStrip();
    if (!all.length && !strip) { view.innerHTML = v1banner() + `<div class="empty">Nothing in flight — no epic is in progress.</div>`; return; }
    view.innerHTML = v1banner() + strip + (all.length ? `<div class="board">` + STAGES.map(stage => {
      const cards = all.filter(([, e]) => stage.statuses.includes(e.status));
      return `<div class="col ${stage.cls}"><h3>${stage.label}<span class="n">${cards.length}</span></h3>
        ${cards.map(([id, e]) => taskCard(id, e)).join("")}</div>`;
    }).join("") + `</div>` : `<div class="empty">No implementation items in flight.</div>`);
  }

  function itemRow(id, e) {
    return `<div class="row" data-item="${esc(id)}"><span class="id mono">${esc(id)}</span>
      <span class="t">${esc(e.title)}</span>${chip(e.status)}</div>`;
  }

  function groupByEpic(bucket) {
    const groups = {};
    for (const kind of ["stories", "content_tasks"])
      for (const [id, e] of Object.entries(bucket[kind] || {}))
        (groups[e.epic || "?"] = groups[e.epic || "?"] || []).push([id, e]);
    return groups;
  }

  function renderBacklog() {
    const d = S.data, groups = groupByEpic(d.backlog);
    const epicIds = (d.epics.priority_order || []).filter(id => groups[id])
      .concat(Object.keys(groups).filter(id => !(d.epics.priority_order || []).includes(id)));
    view.innerHTML = v1banner() + (epicIds.length ? epicIds.map(eid => {
      const e = d.epics.epics[eid] || { title: eid, status: "?" };
      return `<div class="group">${epicCard(eid, e, d.epic_progress[eid])}
        <div class="rows">${groups[eid].map(([id, en]) => itemRow(id, en)).join("")}</div></div>`;
    }).join("") : `<div class="empty">Backlog is empty.</div>`);
  }

  function renderActivity() {
    const rows = S.log.slice().reverse().map(l => {
      // from == null: registration; from == to: decision / planning dispatch /
      // planning completion (no status change) — one chip + the note.
      const move = l.from == null ? `<span class="chip neutral">registered</span>${chip(l.to)}`
        : l.from === l.to ? `${chip(l.to)}${l.note ? `<span class="note">${esc(l.note)}</span>` : ""}`
        : `${chip(l.from)}<span class="arrow">→</span>${chip(l.to)}${l.note ? `<span class="note">${esc(l.note)}</span>` : ""}`;
      return `<div class="row"><span class="time">${fmtTime(l.at)}</span>
        <span class="item-link mono" data-item="${esc(l.item)}">${esc(l.item)}</span>
        ${move}<span class="trigger">${esc(l.trigger || "")}</span></div>`;
    }).join("");
    view.innerHTML = rows ? `<div class="feed card">${rows}</div>`
      : `<div class="empty">No transitions logged yet.</div>`;
  }

  async function renderArchive() {
    if (S.archiveStamp !== S.stamp) {
      try { S.archive = await api("/api/archive", { project: S.project }); S.archiveStamp = S.stamp; }
      catch (e) { view.innerHTML = `<div class="empty">Archive unavailable.</div>`; return; }
    }
    if (S.view !== "archive") return;
    const groups = groupByEpic(S.archive);
    const ids = Object.keys(groups);
    view.innerHTML = ids.length ? ids.map(eid => {
      const e = (S.archive.epics || {})[eid] || (S.data.epics.epics || {})[eid] || { title: eid, status: "done" };
      return `<div class="group">${epicCard(eid, e, S.data.epic_progress[eid], true)}
        <div class="rows">${groups[eid].map(([id, en]) => itemRow(id, en)).join("")}</div></div>`;
    }).join("") : `<div class="empty">Nothing archived yet.</div>`;
  }

  async function renderItem() {
    if (S.itemStamp !== S.stamp || !S.item || S.item.id !== S.itemId) {
      try { S.item = await api("/api/item", { project: S.project, id: S.itemId }); S.itemStamp = S.stamp; }
      catch (e) { view.innerHTML = `<div class="empty">${esc(S.itemId)} not found.</div>`; return; }
    }
    if (S.view !== "item") return;
    const it = S.item, e = it.entry;
    if (S.docPath) {
      let doc;
      try { doc = await api("/api/doc", { project: S.project, path: S.docPath }); }
      catch (err) { doc = { markdown: "_(file not readable)_" }; }
      view.innerHTML = `<div class="crumbs"><a data-item="${esc(it.id)}">← ${esc(it.id)}</a>
        <span class="mono"> · ${esc(S.docPath)}</span></div>
        <div class="doc">${mdRender(doc.markdown)}</div>`;
      return;
    }
    const kv = [["epic", e.epic], ["branch", e.branch], ["worktree", e.worktree],
      ["assignee", e.assignee], ["bucket", it.bucket], ["type", e.type]]
      .filter(([, v]) => v)
      .map(([k, v]) => `<dt>${k}</dt><dd class="mono">${esc(v)}</dd>`).join("");
    // Epic decomposition: its items with statuses, clickable — same shape as the backlog rows.
    const prog = S.data.epic_progress ? S.data.epic_progress[it.id] : null;
    const decomposition = it.kind === "epic" && it.children && it.children.length
      ? `<div class="group"><div class="card">
          <div style="display:flex;align-items:center;gap:14px;margin-bottom:6px">
            <h3 style="margin:0;font-size:12px;color:var(--ink-2)">Stories &amp; tasks</h3>
            <div style="flex:1;max-width:260px">${meter(prog)}</div>
          </div>
          <div class="rows">${it.children.map(c => itemRow(c.id, c)).join("")}</div>
        </div></div>`
      : "";
    view.innerHTML = `<div class="crumbs"><a href="#/${it.kind === "epic" ? "roadmap" : "board"}">← back</a></div>
      <div class="item-head"><h2>${esc(e.title || it.id)}</h2>${chip(e.status, it.kind === "epic" ? EPIC_CLS[e.status] : undefined)}
        <span class="chip neutral">${esc(it.kind)}</span></div>
      <div class="id mono" style="color:var(--muted)">${esc(it.id)}</div>
      <dl class="kv">${kv}</dl>
      ${it.related.length ? `<div class="related">${it.related.map(r =>
        `<button data-doc="${esc(r.path)}">${esc(r.label)}: ${esc(r.path.split("/").pop())}</button>`).join("")}</div>` : ""}
      ${decomposition}
      ${it.doc != null ? `<div class="doc">${mdRender(it.doc)}</div>`
        : `<div class="empty">No document found for ${esc(it.id)}.</div>`}`;
  }

  // ---------- clicks ----------
  document.addEventListener("click", ev => {
    const itemEl = ev.target.closest("[data-item]");
    if (itemEl) {
      const id = itemEl.dataset.item;
      if (S.view === "item" && S.itemId === id && S.docPath) { S.docPath = null; render(); }
      else location.hash = "#/item/" + id;
      return;
    }
    const docEl = ev.target.closest("[data-doc]");
    if (docEl) { S.docPath = docEl.dataset.doc; renderItem(); }
  });

  // ---------- markdown mini-renderer ----------
  function inline(s) {
    return esc(s)
      .replace(/!\[([^\]]*)\]\(([^)]*)\)/g, "<em>$1</em>")
      .replace(/\[([^\]]+)\]\((docs\/[^)]+\.md)\)/g, `<a data-doc="$2">$1</a>`)
      .replace(/\[([^\]]+)\]\((https?:[^)]+)\)/g, `<a href="$2" target="_blank" rel="noopener">$1</a>`)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/(^|[\s(])\*([^*\s][^*]*)\*/g, "$1<em>$2</em>");
  }

  function mdRender(text) {
    const lines = String(text || "").replace(/\r/g, "").split("\n");
    const out = [];
    let i = 0, listStack = 0, inQuote = false;
    const closeLists = () => { while (listStack > 0) { out.push("</ul>"); listStack--; } };
    const closeQuote = () => { if (inQuote) { out.push("</blockquote>"); inQuote = false; } };
    while (i < lines.length) {
      const line = lines[i];
      if (/^```/.test(line)) {
        closeLists(); closeQuote();
        const buf = []; i++;
        while (i < lines.length && !/^```/.test(lines[i])) buf.push(lines[i++]);
        i++; out.push(`<pre><code>${esc(buf.join("\n"))}</code></pre>`); continue;
      }
      if (/^\|/.test(line) && /^\|?[\s:|-]+\|?$/.test(lines[i + 1] || "")) {
        closeLists(); closeQuote();
        const cells = r => r.replace(/^\||\|$/g, "").split("|").map(c => inline(c.trim()));
        out.push("<table><thead><tr>" + cells(line).map(c => `<th>${c}</th>`).join("") + "</tr></thead><tbody>");
        i += 2;
        while (i < lines.length && /^\|/.test(lines[i]))
          out.push("<tr>" + cells(lines[i++]).map(c => `<td>${c}</td>`).join("") + "</tr>");
        out.push("</tbody></table>"); continue;
      }
      const h = line.match(/^(#{1,6})\s+(.*)/);
      if (h) { closeLists(); closeQuote(); out.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`); i++; continue; }
      if (/^\s*(-{3,}|\*{3,})\s*$/.test(line)) { closeLists(); closeQuote(); out.push("<hr>"); i++; continue; }
      const q = line.match(/^>\s?(.*)/);
      if (q) { closeLists(); if (!inQuote) { out.push("<blockquote>"); inQuote = true; } out.push(inline(q[1]) + "<br>"); i++; continue; }
      const li = line.match(/^(\s*)([-*]|\d+\.)\s+(.*)/);
      if (li) {
        closeQuote();
        const depth = Math.floor(li[1].length / 2) + 1;
        while (listStack < depth) { out.push("<ul>"); listStack++; }
        while (listStack > depth) { out.push("</ul>"); listStack--; }
        const task = li[3].match(/^\[( |x|X)\]\s+(.*)/);
        if (task) out.push(`<li class="${task[1] === " " ? "task-open" : "task-done"}">${inline(task[2])}</li>`);
        else out.push(`<li>${inline(li[3])}</li>`);
        i++; continue;
      }
      if (/^\s*$/.test(line)) { closeLists(); closeQuote(); i++; continue; }
      closeLists(); closeQuote();
      const buf = [line];
      while (i + 1 < lines.length && !/^\s*$/.test(lines[i + 1]) &&
             !/^(#|```|>|\||\s*([-*]|\d+\.)\s)/.test(lines[i + 1])) buf.push(lines[++i]);
      out.push(`<p>${inline(buf.join(" "))}</p>`); i++;
    }
    closeLists(); closeQuote();
    return out.join("\n");
  }

  // ---------- boot ----------
  fetch("/api/health").then(r => r.json())
    .then(h => { $("#ver").textContent = "v" + h.version; })
    .catch(() => {});
  route();
  loadProjects();
  setInterval(refresh, 2000);
})();
