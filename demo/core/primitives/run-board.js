/* Anselm 原语 G6 — <an-run-board>。单 workflow 的运行看板：左 = 每次 run 列表（trigger 多次 → 多条 flowrun），右 = 选中 run 的逐节点甘特。
   runs（[{id,status,when,trigger,replay,selected,gantt:[…]}]）经 JS 属性注入；选中 run 内置同步——点左列表行 → 右甘特随切 + emit an-run-pick{id}（消费方据此切运行图 + 节点调试）。
   内嵌 an-node-gantt（逐节点条/iters/parked/future），其 an-node-pick 经 composed 冒泡至消费方。
   why 自件：左 run 列表 + 右甘特的"同步选中一个块"是 scheduler 专属布局，收进单件、对外只暴露 runs/selectedId。 */
(function () {
  const e = window.anEsc;
  const DOT = { running: "run", completed: "done", failed: "err", parked: "wait", cancelled: "idle" };

  class AnRunBoard extends window.AnElement {
    static tag = "an-run-board";
    static observed = [];
    static css = `
      :host { display: block; }
      .board { display: grid; grid-template-columns: var(--run-list-w) 1fr; align-items: stretch;
        border: var(--hairline) solid var(--line); border-radius: var(--r-card); background: var(--island); overflow: hidden; }
      .runs { display: flex; flex-direction: column; min-width: 0; border-right: var(--hairline) solid var(--line); }
      .gpane { display: flex; flex-direction: column; min-width: 0; }
      .rhead, .ghead { flex: none; height: var(--ctl); display: flex; align-items: center; padding: 0 var(--sp-3);
        font-size: var(--t-meta); font-weight: 600; color: var(--ink-3); border-bottom: var(--hairline) solid var(--line); }
      .rlist { min-height: 0; overflow-y: auto; }

      /* run 行：状态点 + [id / trigger·when] + replay 徽；选中 = accent 软底 + 左强调条 */
      .run { display: grid; grid-template-columns: var(--lead) 1fr auto; align-items: center; column-gap: var(--gap); width: 100%; text-align: left;
        padding: var(--sp-2) var(--sp-3); border: var(--zero); background: none; cursor: pointer;
        border-bottom: var(--hairline) solid var(--line); transition: background var(--d-fast); }
      .run:last-child { border-bottom: var(--zero); }
      .run:hover { background: var(--island-3); }
      .run.sel { background: var(--accent-soft); box-shadow: inset var(--line-2) 0 0 var(--accent); }
      .rmain { min-width: 0; display: flex; flex-direction: column; }
      .rid { font-family: var(--mono); font-size: var(--t-meta); color: var(--ink); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .rsub { font-size: var(--t-meta); color: var(--ink-3); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .rtrail { font-size: var(--t-meta); color: var(--accent); font-variant-numeric: tabular-nums; white-space: nowrap; }

      an-node-gantt { display: block; padding: var(--sp-3); }
    `;

    set runs(v) { this._runs = Array.isArray(v) ? v : []; this._sel = (this._runs.find((r) => r.selected) || this._runs[0] || {}).id; if (this.isConnected) this._render(); }
    get runs() { return this._runs || []; }
    set selectedId(v) { if (v != null) { this._sel = v; if (this.isConnected) this._select(v, true); } }
    get selectedId() { return this._sel; }

    render() {
      const runs = this._runs || [];
      const items = runs.map((r) => {
        const sub = [r.trigger, r.when].filter(Boolean).join(" · ");
        return `<button type="button" class="run${r.id === this._sel ? " sel" : ""}" data-id="${e(r.id)}">`
          + `<an-status-dot state="${DOT[r.status] || "idle"}"></an-status-dot>`
          + `<span class="rmain"><span class="rid">${e(r.id)}</span><span class="rsub">${e(sub)}</span></span>`
          + `<span class="rtrail">${r.replay ? "↻" + e(String(r.replay)) : ""}</span></button>`;
      }).join("");
      return `<div class="board">`
        + `<div class="runs"><div class="rhead">运行 · ${runs.length} 次</div><div class="rlist">${items}</div></div>`
        + `<div class="gpane"><div class="ghead">节点甘特 · 本次 run 内逐节点时段</div><an-node-gantt></an-node-gantt></div>`
        + `</div>`;
    }
    hydrate() {
      const g = this.$("an-node-gantt");
      const cur = (this._runs || []).find((r) => r.id === this._sel);
      if (g) g.nodes = (cur && cur.gantt) || [];
      this.$$(".run").forEach((b) => b.addEventListener("click", () => this._select(b.dataset.id, false)));
    }
    // 切 run：高亮 + 右甘特随切；silent=true 为外部同步（不回派事件，避免环）
    _select(id, silent) {
      this._sel = id;
      this.$$(".run").forEach((b) => b.classList.toggle("sel", b.dataset.id === id));
      const run = (this._runs || []).find((r) => r.id === id) || {};
      const g = this.$("an-node-gantt"); if (g) g.nodes = run.gantt || [];
      if (!silent) this.emit("an-run-pick", { id });
    }
  }
  window.AnElement.define(AnRunBoard);
})();
