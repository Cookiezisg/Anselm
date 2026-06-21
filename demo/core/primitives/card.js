/* Anselm 原语 — <an-card variant row selectable selected pad>。通用卡片容器（「有边」对偶 info-card 的「无边」）。
   皮肤：inset hairline 描边（避圆角灰尖）+ r-chip 圆角 + island 底 + padding；内容走默认 slot（feature 自拼 icon/标题/动作）。
   variant=accent → accent 描边（编辑/聚焦态卡，如建 key 配置卡）· row → 横向 flex（icon+内容+尾）· selectable[+selected] → 可选卡（hover/选中 accent 边、点派 an-card-select）· pad=tight → 紧凑内距。
   why：settings/MCP/onboarding 8 处逐字相同的卡皮肤（.mk-card/.mk-scn/.mk-form/.mcp-card/.mcp-inst/.ob-choice）收口本件，杜绝散落 bespoke CSS（PATTERNS 纪律：不在册=造轮子）。 */
(function () {
  class AnCard extends window.AnElement {
    static tag = "an-card";
    static observed = [];   // variant/row/selected 纯 CSS 实时响应；selectable 点击在 hydrate 内判 has()，无需重渲
    static css = `
      :host { display: block; }
      .card { display: flex; flex-direction: column; gap: var(--sp-2); padding: var(--sp-3) var(--sp-4);
        box-shadow: inset 0 0 0 var(--hairline) var(--line); border-radius: var(--r-chip); background: var(--island); }
      :host([row]) .card { flex-direction: row; align-items: center; gap: var(--sp-3); }
      :host([variant="accent"]) .card { box-shadow: inset 0 0 0 var(--hairline) var(--accent-line); }
      :host([pad="tight"]) .card { padding: var(--grid) var(--pad-row); }
      :host([selectable]) .card { cursor: pointer; transition: box-shadow var(--d-fast); }
      :host([selectable]:hover) .card { box-shadow: inset 0 0 0 var(--hairline) var(--line-strong); }
      :host([selected]) .card { box-shadow: inset 0 0 0 var(--line-2) var(--accent-line); }
    `;
    render() { return `<div class="card"><slot></slot></div>`; }
    hydrate() {
      // 点击恒挂、运行时判 selectable —— 免 selectable 后置切换要重 hydrate
      this.$(".card").addEventListener("click", () => { if (this.has("selectable")) this.emit("an-card-select", { selected: this.has("selected") }); });
    }
  }
  window.AnElement.define(AnCard);
})();
