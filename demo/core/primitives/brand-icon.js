/* Anselm 原语 — <an-brand-icon src svg glyph size managed>。品牌/项目图标单源。
   三源择一：src（图 URL → img+cover+r-tag 底，如 MCP 项目头像）| svg（内联 SVG 串，走 prop/attr，logo 自呈现、无底、随 ink 着色）| glyph（字母兜底 → 灰底圆角）。
   size sm（lead）/ 默认 md（ctl）/ lg（≈88，欢迎屏）；managed → accent 色（免费档火花）。
   why：settings/MCP/onboarding 4 处自绘图标框（.mk-ico/.an-pp-ico/.mcp-ico/.ob-mcp-ico）+ brandIcoHtml 串重抄收口。 */
(function () {
  class AnBrandIcon extends window.AnElement {
    static tag = "an-brand-icon";
    static observed = ["src", "glyph", "size", "managed"];
    static css = `
      :host { display: inline-flex; }
      .ico { flex: none; width: var(--ctl); height: var(--ctl); display: grid; place-items: center; border-radius: var(--r-tag); overflow: hidden;
        background: var(--island-3); color: var(--ink-2); font-size: calc(var(--lead) + var(--sp-1)); font-weight: 600; }
      :host([size="sm"]) .ico { width: var(--lead); height: var(--lead); font-size: var(--lead); }
      :host([size="lg"]) .ico { width: calc(var(--island-head) * 2); height: calc(var(--island-head) * 2); font-size: var(--island-head); border-radius: calc(var(--island-head) * 0.45); }
      /* svg logo：去底自呈现、随 ink 着色 */
      :host([data-svg]) .ico { background: none; color: var(--ink); }
      :host([managed]) .ico { background: var(--accent-soft); color: var(--accent); }
      .ico img { width: 100%; height: 100%; object-fit: cover; display: block; }
      .ico svg { width: 1em; height: 1em; display: block; }
    `;
    get svg() { return this._svg; }
    set svg(v) { this._svg = v; if (this.isConnected) this._render(); }
    render() {
      const e = window.anEsc;
      const src = this.attr("src"), svg = this._svg != null ? this._svg : this.attr("svg"), glyph = this.attr("glyph");
      let inner;
      if (src) { inner = `<img src="${e(src)}" alt="" loading="lazy">`; this.removeAttribute("data-svg"); }
      else if (svg) { inner = svg; this.setAttribute("data-svg", ""); }   // 信任的内联 SVG 串（lobehub/simple-icons currentColor）
      else { inner = e(glyph || "?"); this.removeAttribute("data-svg"); }
      return `<span class="ico">${inner}</span>`;
    }
  }
  window.AnElement.define(AnBrandIcon);
})();
