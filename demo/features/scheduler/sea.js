/* Anselm feature — scheduler 海洋（sea）：durable 执行驾驶舱。
   双层时间线（用户选取 C）：① 时间河 an-run-river 选一次执行 → ② 切运行图 an-graph-canvas[mode=run] + 节点甘特 an-node-gantt。
   点图节点 / 甘特行 → 右岛出该节点的调试详情（记忆化 result / 状态 / iteration / 耗时 / 错误 / parked 审批）——debug 常驻面。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.scheduler = Object.assign(window.FEATURE.scheduler || {}, {
  sea: (ctx) => {
    const RUNS = window.SCHED_RUNS || [];
    const WFS = window.SCHED_WORKFLOWS || [];
    let cur = RUNS.find((r) => r.selected) || RUNS[0] || {};

    const el = (tag, attrs, ...kids) => {
      const n = document.createElement(tag);
      if (attrs) for (const k in attrs) { const v = attrs[k]; if (v == null || v === false) continue; if (k === "prop") Object.assign(n, v); else n.setAttribute(k, v === true ? "" : v); }
      kids.flat().forEach((c) => { if (c == null) return; n.append(c.nodeType ? c : document.createTextNode(String(c))); });
      return n;
    };
    const WIN = window.SCHED_WINDOW_MIN || 720;
    const posOf = (tMin) => 100 * (WIN - Math.min(WIN, Math.max(0, +tMin || 0))) / WIN;   // 距今越近越靠右（按真起始时刻算横位）
    const lanesOf = (selId) => {
      const by = {};
      RUNS.forEach((r) => { (by[r.wf] = by[r.wf] || { runs: [] }).runs.push({ id: r.id, status: r.status, when: r.when, label: r.id + " · " + r.when, atPct: posOf(r.tMin), wPct: 3, selected: r.id === selId }); });
      return WFS.filter((w) => by[w.id]).map((w) => ({ label: w.label, meta: w.meta, runs: by[w.id].runs }));
    };
    const hourTicks = () => { const t = []; for (let m = 60; m < WIN; m += 60) t.push(posOf(m)); return t; };

    // ── 主面 ──
    const page = el("an-page");
    page.append(el("an-ocean-header", { crumb: "Scheduler", title: "运行驾驶舱" }, el("span", { slot: "meta" }, "durable 执行 · 时间河 → 运行图 → 节点调试")));

    const river = el("an-run-river", { window: window.SCHED_WINDOW || "" });
    river.ticks = hourTicks();
    page.append(el("an-section", { label: "执行时间线 · 点胶囊切一次执行" }, river));

    const graphSec = el("an-section", { label: "运行图" });
    const cv = el("an-graph-canvas", { framed: true, toolbar: true, mode: "run", dir: "LR" });
    graphSec.append(cv);
    page.append(graphSec);

    const gantt = el("an-node-gantt");
    page.append(el("an-section", { label: "节点甘特 · 点节点看调试" }, gantt));

    // ── 右岛：运行详情 + 节点调试 ──
    const island = el("an-right-island", { title: "运行详情", icon: "scheduler" });

    function renderIsland(r, nodeId) {
      island.innerHTML = "";
      // flowrun 头
      const headCard = el("an-info-card", { title: "flowrun 头", icon: "workflow", meta: r.status });
      const kv = el("an-kv"); kv.setAttribute("wrap", ""); kv.rows = r.head || [];
      headCard.append(kv);
      // run 级动作
      const acts = el("an-action-group");
      if (r.status === "failed") { const b = el("an-button", { size: "sm", icon: "history" }, ":replay"); b.addEventListener("click", () => window.AnToast.show({ text: ":replay 清 failed 行、自断点续跑 · replay_count++" })); acts.append(b); }
      if (r.status === "running" || r.status === "parked") { const b = el("an-button", { size: "sm", variant: "danger", icon: "stop" }, ":kill"); b.addEventListener("click", () => window.AnToast.show({ text: ":kill 标 cancelled + 取消在途 ctx" })); acts.append(b); }
      headCard.append(el("div", { slot: "actions" }, acts));
      island.append(headCard);

      // 节点调试
      const d = (r.nodeDetail || {})[nodeId];
      if (d) {
        const nc = el("an-info-card", { title: "节点 · " + nodeId, icon: "sliders" });
        const nkv = el("an-kv"); nkv.setAttribute("wrap", ""); nkv.rows = d.kv || [];
        nc.append(nkv);
        if (d.code) { const ce = el("an-code-editor", { lang: d.lang || "text", editable: "false" }); ce.textContent = d.code; nc.append(ce); }
        if (d.json) { const jt = el("an-json-tree", { root: "false" }); jt.data = d.json; nc.append(jt); }
        if (d.parked) { nc.append(el("an-approval-gate", { flavor: "durable", title: "待审批", prompt: d.parked.prompt, ddl: d.parked.ddl })); }
        island.append(nc);
      } else if (nodeId) {
        island.append(el("an-callout", { tone: "info" }, "节点 " + nodeId + " 无记忆化详情（future / 本 demo 仅 parked run 含逐节点调试）。"));
      } else {
        island.append(el("an-callout", { tone: "info" }, "点运行图节点或甘特行 → 看该 (节点,轮次) 的记忆化 result / 状态 / 耗时 / 错误。"));
      }
    }

    function loadRun(r) {
      cur = r;
      river.lanes = lanesOf(r.id);
      graphSec.setAttribute("label", "运行图 · " + r.id + " · " + r.status);
      cv.graph = { nodes: r.graph.nodes, edges: r.graph.edges };
      cv.run = r.graph.run || null;
      gantt.nodes = r.gantt || [];
      renderIsland(r, null);
    }

    river.addEventListener("an-run-pick", (ev) => { const r = RUNS.find((x) => x.id === ev.detail.id); if (r) loadRun(r); });
    gantt.addEventListener("an-node-pick", (ev) => renderIsland(cur, ev.detail.id));
    cv.addEventListener("an-graph-select", (ev) => { const s = ev.detail.sel; if (s && s.type === "node") renderIsland(cur, s.id); });

    loadRun(cur);
    if (ctx.shell) ctx.shell.setRight(island);
    return page;
  },
});
