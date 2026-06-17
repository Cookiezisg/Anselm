/* Anselm 原语 G6 — <an-run-river>。flowrun 时间河：每个 workflow 一条泳道，flowrun 沿共享时间轴铺成胶囊。
   lanes 经 JS 属性注入（[{label, meta, runs:[{id,status,when,atPct,wPct,selected}]}]）；位置 atPct/wPct ∈[0,100] 纯几何（demo 预算）。
   胶囊色 = 终态（completed→ok / failed→danger / parked→warn 脉冲 / running→accent 脉冲）；点胶囊 emit 'an-run-pick'{id}。
   why 自画：时间轴 + 泳道 + 定位胶囊是 scheduler 专属 viz，声明式原语覆盖不了，收进单件。 */
(function () {
  const e = window.anEsc;
  const SCLS = { completed: "s-done", failed: "s-err", parked: "s-park", running: "s-run", cancelled: "s-cancel" };

  class AnRunRiver extends window.AnElement {
    static tag = "an-run-river";
    static observed = ["window"];
    static css = `
      :host { display: block; }
      .win { font-size: var(--t-meta); color: var(--ink-3); margin-bottom: var(--sp-2); }
      .lane { display: grid; grid-template-columns: var(--lane-w) 1fr; align-items: center; column-gap: var(--sp-3); margin-bottom: var(--sp-2); }
      .ln { min-width: 0; display: flex; flex-direction: column; }
      .ln .nm { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: var(--t-meta); font-weight: 500; color: var(--ink-2); }
      .ln .mt { font-size: var(--t-meta); color: var(--ink-3); }
      .track { position: relative; height: var(--ctl); border-radius: var(--r-btn); background: var(--island-3); overflow: hidden; }
      .tick { position: absolute; top: 0; bottom: 0; width: var(--hairline); background: var(--line); }
      .cap {
        position: absolute; top: var(--grid); bottom: var(--grid); min-width: var(--ctl-sm);
        border: var(--zero); border-radius: var(--r-tag); cursor: pointer; padding: 0;
        transition: box-shadow var(--d-fast), filter var(--d-fast);
      }
      .cap:hover { filter: brightness(1.06); }
      .cap.s-done { background: var(--ok); }
      .cap.s-err { background: var(--danger); }
      .cap.s-park { background: var(--warn); animation: anRiverPulse calc(var(--d-slow) * 2) var(--ease-out) infinite; }
      .cap.s-run { background: var(--accent); animation: anRiverPulse calc(var(--d-slow) * 2) var(--ease-out) infinite; }
      .cap.s-cancel { background: var(--ink-3); }
      .cap.sel { box-shadow: 0 0 0 var(--line-2) var(--island), 0 0 0 var(--focus-ring) var(--ink); }
      @keyframes anRiverPulse { 0%,100% { opacity: 1; } 50% { opacity: .55; } }
    `;

    set lanes(v) { this._lanes = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }
    get lanes() { return this._lanes || []; }
    set ticks(v) { this._ticks = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }

    render() {
      const win = this.attr("window") ? `<div class="win">${e(this.attr("window"))}</div>` : "";
      const ticks = (this._ticks || []).map((p) => `<span class="tick" style="left:${+p}%"></span>`).join("");
      const lanes = (this._lanes || []).map((lane) => {
        const caps = (lane.runs || []).map((r) => {
          const cls = "cap " + (SCLS[r.status] || "s-done") + (r.selected ? " sel" : "");
          const w = Math.max(2, +r.wPct || 0);
          return `<button type="button" class="${cls}" data-id="${e(r.id)}" title="${e((r.label || r.id) + " · " + (r.when || "") + " · " + r.status)}" style="left:${+r.atPct || 0}%;width:${w}%"></button>`;
        }).join("");
        return `<div class="lane"><div class="ln"><span class="nm">${e(lane.label || "")}</span><span class="mt">${e(lane.meta || "")}</span></div>`
          + `<div class="track">${ticks}${caps}</div></div>`;
      }).join("");
      return `${win}${lanes}`;
    }
    hydrate() {
      this.$$(".cap").forEach((b) => b.addEventListener("click", () => this.emit("an-run-pick", { id: b.dataset.id })));
    }
  }
  window.AnElement.define(AnRunRiver);
})();
