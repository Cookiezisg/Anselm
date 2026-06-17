/* Anselm 原语 — <an-outline>。文档大纲 / 目录（ToC）：左侧导引线 + 按层级缩进的可点标题，当前节高亮。
   items（[{text, level}]）/ active（当前节索引）经 JS 属性注入；点条目 emit 'an-outline-pick'{index}（消费方滚到对应标题）。
   why 内化：ToC 是反复出现的"导引线 + 缩进 + 高亮 + 跳转"范式，收进单件、各长文页复用，免每处手搓 an-row 堆。 */
(function () {
  const e = window.anEsc;

  class AnOutline extends window.AnElement {
    static tag = "an-outline";
    static observed = [];
    static css = `
      :host { display: block; }
      .toc { position: relative; padding-left: var(--sp-3); }
      /* 左导引线（贯穿）：弱灰，active 条目处叠 accent 短条 */
      .toc::before { content: ""; position: absolute; left: var(--zero); top: var(--grid); bottom: var(--grid); width: var(--line-2); border-radius: var(--r-pill); background: var(--line); }
      .item { position: relative; display: block; width: 100%; text-align: left; padding: var(--grid) var(--gap);
        border: var(--zero); background: none; cursor: pointer; border-radius: var(--r-tag);
        font-size: var(--t-meta); line-height: var(--lh-ui); color: var(--ink-3);
        overflow: hidden; text-overflow: ellipsis; white-space: nowrap; transition: color var(--d-fast), background var(--d-fast); }
      .item:hover { color: var(--ink); background: var(--island-3); }
      .item.active { color: var(--accent); font-weight: 600; }
      .item.active::before { content: ""; position: absolute; left: calc(-1 * var(--sp-3)); top: var(--grid); bottom: var(--grid); width: var(--line-2); border-radius: var(--r-pill); background: var(--accent); }
      .item.l2 { padding-left: var(--sp-4); }
      .item.l3 { padding-left: var(--sp-8); }
      .empty { padding: var(--grid) var(--gap); font-size: var(--t-meta); color: var(--ink-3); }
    `;

    set items(v) { this._items = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }
    get items() { return this._items || []; }
    set active(v) { this._active = v; this.$$(".item").forEach((b) => b.classList.toggle("active", +b.dataset.i === v)); }

    render() {
      const items = this._items || [];
      if (!items.length) return `<div class="toc"><div class="empty">（暂无标题）</div></div>`;
      return `<div class="toc">${items.map((o, i) => `<button type="button" class="item l${o.level || 2}${i === this._active ? " active" : ""}" data-i="${i}">${e(o.text || "")}</button>`).join("")}</div>`;
    }
    hydrate() {
      this.$$(".item").forEach((b) => b.addEventListener("click", () => { this.active = +b.dataset.i; this.emit("an-outline-pick", { index: +b.dataset.i }); }));
    }
  }
  window.AnElement.define(AnOutline);
})();
