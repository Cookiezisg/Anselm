/* Anselm 原语 G7 — <an-node-gantt>。单 flowrun 的逐节点甘特：每节点一行，时段条沿 run 内时间轴铺。
   nodes 经 JS 属性注入（[{id,kind,label,status,atPct,wPct, iters?:[{atPct,wPct}], parked?}]）；位置 ∈[0,100]（demo 预算）。
   能看出：哪个节点慢（条长）· 循环几轮（iters 多条 + ×N 徽）· 在哪 parked（虚框等待条）· 谁未起（future 占位）。点行 emit 'an-node-pick'{id}。 */
(function () {
  const e = window.anEsc;
  const SCLS = { done: "s-done", completed: "s-done", err: "s-err", failed: "s-err", parked: "s-park", future: "s-future" };
  // 定位百分比钳进 [0,100]：越界值（脏 demo 数据）会让条飞出轨道，钳死即保证条始终在轨内
  const pct = (v) => Math.min(100, Math.max(0, +v || 0));

  class AnNodeGantt extends window.AnElement {
    static tag = "an-node-gantt";
    static observed = [];
    static css = `
      /* 海量节点不撑爆容器：封顶 + 自滚（复用 graph-preview 定高 token，与内嵌运行视图同节奏） */
      :host { display: block; max-height: var(--h-graph-preview); overflow: auto; }
      .row { display: grid; grid-template-columns: var(--lane-w) 1fr; align-items: center; column-gap: var(--sp-3);
        height: var(--row); padding: 0 var(--sp-2); border-radius: var(--r-btn); cursor: pointer; transition: background var(--d-fast); }
      .row:hover { background: var(--island-3); }
      .row.sel { background: var(--island-4); }
      .lab { display: flex; align-items: center; gap: var(--gap-tight); min-width: 0; }
      .ic { display: grid; place-items: center; flex: none; color: var(--ink-3); }
      .ic svg { width: var(--icon-sm); height: var(--icon-sm); }
      .nm { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-family: var(--mono); font-size: var(--t-meta); color: var(--ink-2); }
      .xn { flex: none; color: var(--accent); font-size: var(--t-meta); }
      .track { position: relative; height: var(--ctl-sm); }
      .bar { position: absolute; top: 0; bottom: 0; min-width: var(--grid); border-radius: var(--r-tag); }
      .bar.s-done { background: var(--ok); }
      .bar.s-err { background: var(--danger); }
      .bar.s-park { background: var(--warn-soft); box-shadow: inset 0 0 0 var(--hairline) var(--warn);
        display: flex; align-items: center; padding: 0 var(--gap-tight); }
      .bar.s-park .pk { color: var(--warn); font-size: var(--t-meta); white-space: nowrap; }
      .bar.s-future { background: var(--island-4); }
      .stub { position: absolute; left: 0; top: 50%; transform: translateY(-50%); color: var(--ink-3); font-size: var(--t-meta); }
    `;

    set nodes(v) { this._nodes = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }
    get nodes() { return this._nodes || []; }

    render() {
      const KI = window.NODE_ICON || {};
      return (this._nodes || []).map((n) => {
        const ico = window.icon(KI[n.kind] || n.kind || "action");
        const segs = (n.iters && n.iters.length) ? n.iters : ((+n.wPct || 0) > 0 ? [{ atPct: n.atPct, wPct: n.wPct }] : []);
        let bars;
        if (n.parked) {
          bars = `<span class="bar s-park" style="left:${pct(n.atPct)}%;width:${Math.max(6, pct(n.wPct))}%"><span class="pk">等待审批</span></span>`;
        } else if (!segs.length) {
          bars = `<span class="stub">未运行</span>`;
        } else {
          const cls = SCLS[n.status] || "s-done";
          bars = segs.map((s) => `<span class="bar ${cls}" style="left:${pct(s.atPct)}%;width:${Math.max(2, pct(s.wPct))}%"></span>`).join("");
        }
        const xn = (n.iters && n.iters.length > 1) ? `<span class="xn">×${n.iters.length}</span>` : "";
        return `<div class="row" data-id="${e(n.id)}"><div class="lab"><span class="ic">${ico}</span><span class="nm">${e(n.label || n.id)}</span>${xn}</div>`
          + `<div class="track">${bars}</div></div>`;
      }).join("");
    }
    hydrate() {
      this.$$(".row").forEach((r) => r.addEventListener("click", () => { this.$$(".row").forEach((x) => x.classList.remove("sel")); r.classList.add("sel"); this.emit("an-node-pick", { id: r.dataset.id }); }));
    }
  }
  window.AnElement.define(AnNodeGantt);
})();
