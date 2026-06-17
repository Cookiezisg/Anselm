/* Anselm 原语 — <an-doc-tree>。Notion 式嵌套【文档】树（非文件夹）：New + 搜索 + 可折叠层级 + 每行悬停 ＋/⋯。
   tree（[{id,label,children}]）/ selected 经 JS 属性注入；搜索内置实时过滤（命中 + 祖先链自动展开）。
   交互分流：点 chevron 仅折叠、点行选中（开文档）——双职责须自管，an-row/sidebar-list 的 2 级模型覆盖不了任意深嵌套。
   事件（composed）：an-doc-new · an-doc-select{id} · an-doc-add{id}（加子文档）· an-doc-more{id,anchor}（编辑菜单）。 */
(function () {
  const e = window.anEsc;
  const lc = (s) => String(s == null ? "" : s).toLowerCase();
  // 所有"有子"节点 id（默认全展开）
  const parents = (list, acc) => { acc = acc || []; (list || []).forEach((n) => { if (n.children && n.children.length) { acc.push(n.id); parents(n.children, acc); } }); return acc; };
  // 过滤：保留命中节点 + 其祖先链（子命中则父留）
  const filterTree = (list, q) => !q ? (list || []) : (list || []).map((n) => { const kids = filterTree(n.children || [], q); return (lc(n.label).includes(q) || kids.length) ? { ...n, children: kids } : null; }).filter(Boolean);

  class AnDocTree extends window.AnElement {
    static tag = "an-doc-tree";
    static observed = [];
    static css = `
      :host { display: flex; flex-direction: column; }

      /* New / 搜索 共享 Row 三列网格（行首槽对齐，同 sidebar-list 语汇） */
      .head-row { display: grid; grid-template-columns: var(--lead) 1fr auto; align-items: center; column-gap: var(--gap);
        height: var(--row); padding: 0 var(--pad-row); border-radius: var(--r-btn); color: var(--ink-2); font-size: var(--t-body); }
      .lead { width: var(--lead); height: var(--lead); display: grid; place-items: center; color: var(--ink-3); }
      .lead svg { display: block; width: var(--icon); height: var(--icon); }
      .new { width: 100%; text-align: left; cursor: pointer; transition: background var(--d-fast), color var(--d-fast); }
      .new:hover { background: var(--island-3); color: var(--ink); }
      .new .label { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .filter { cursor: default; }
      .input { width: 100%; min-width: 0; border: var(--zero); background: none; font: inherit; font-size: var(--t-body); color: var(--ink); }
      .input::placeholder { color: var(--ink-3); }
      .input:focus { outline: none; }

      .tree { display: flex; flex-direction: column; min-height: 0; margin-top: var(--grid); }
      .nw:not(.open) > .kids { display: none; }

      /* 文档行：[chevron | 文档图标 | 标题]，缩进走 padding-left（每级 --indent）；尾动作绝对叠放、不占标题宽（同 Notion 悬停浮现） */
      .node { position: relative; display: grid; grid-template-columns: var(--icon) var(--icon) 1fr; align-items: center; column-gap: var(--gap-tight);
        height: var(--row); border-radius: var(--r-btn); color: var(--ink-2); font-size: var(--t-body); cursor: pointer; transition: background var(--d-fast), color var(--d-fast); }
      .node:hover { background: var(--island-3); color: var(--ink); }
      .node.sel { background: var(--island-4); color: var(--ink); }
      .tw { display: grid; place-items: center; width: var(--icon); height: var(--icon); color: var(--ink-3); border-radius: var(--r-tag); }
      .tw.has { cursor: pointer; }
      .tw.has:hover { background: var(--island-4); color: var(--ink); }
      .tw svg { width: var(--icon-sm); height: var(--icon-sm); transition: transform var(--d-mid) var(--ease-spring); }
      .nw.open > .node .tw svg { transform: rotate(90deg); }
      .ic { display: grid; place-items: center; width: var(--icon); height: var(--icon); color: var(--ink-3); }
      .ic svg { width: var(--icon); height: var(--icon); }
      .lbl { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .acts { position: absolute; right: var(--pad-row); top: 0; bottom: 0; display: flex; align-items: center; gap: var(--gap-hair);
        opacity: 0; background: var(--island-3); padding-left: var(--gap); }
      .node:hover .acts { opacity: 1; }
      .act { display: grid; place-items: center; width: var(--trail); height: var(--trail); color: var(--ink-3); border-radius: var(--r-tag); cursor: pointer; transition: background var(--d-fast), color var(--d-fast); }
      .act:hover { background: var(--island-4); color: var(--ink); }
      .act svg { width: var(--icon-sm); height: var(--icon-sm); }
    `;

    set tree(v) { this._tree = Array.isArray(v) ? v : []; this._open = new Set(parents(this._tree)); if (this.isConnected) this._render(); }
    get tree() { return this._tree || []; }
    set selected(v) { this._sel = v; if (this.$(".tree")) this._paintSel(); }
    get selected() { return this._sel; }

    render() {
      return `<button type="button" class="head-row new"><span class="lead">${window.icon("plus")}</span><span class="label">New Document</span><span></span></button>`
        + `<div class="head-row filter"><span class="lead">${window.icon("search")}</span><input class="input" type="text" placeholder="搜索文档…"><span></span></div>`
        + `<div class="tree">${this._nodes(this._tree || [], 0, "")}</div>`;
    }
    _nodes(list, depth, q) { return (list || []).map((n) => this._node(n, depth, q)).join(""); }
    _node(n, depth, q) {
      const has = n.children && n.children.length;
      const open = has && (q ? true : (this._open || new Set()).has(n.id));   // 搜索时命中分支恒展开
      const tw = has ? `<span class="tw has">${window.icon("chevr")}</span>` : `<span class="tw"></span>`;
      const pad = `padding-left: calc(var(--pad-row) + ${depth} * var(--indent))`;
      const node = `<div class="node" data-id="${e(n.id)}" style="${pad}">${tw}<span class="ic">${window.icon("doc")}</span><span class="lbl">${e(n.label)}</span>`
        + `<span class="acts"><button type="button" class="act act-add" data-id="${e(n.id)}" title="加子文档" aria-label="加子文档">${window.icon("plus")}</button>`
        + `<button type="button" class="act act-more" data-id="${e(n.id)}" title="更多" aria-label="更多">${window.icon("more")}</button></span></div>`;
      const kids = has ? `<div class="kids">${this._nodes(n.children, depth + 1, q)}</div>` : "";
      return `<div class="nw${open ? " open" : ""}" data-id="${e(n.id)}">${node}${kids}</div>`;
    }
    hydrate() {
      const tree = this.$(".tree"), input = this.$(".input");
      this.$(".new").addEventListener("click", () => this.emit("an-doc-new"));
      input.addEventListener("input", () => { const q = lc(input.value.trim()); tree.innerHTML = this._nodes(filterTree(this._tree, q), 0, q); this._paintSel(); });
      tree.addEventListener("click", (ev) => {
        const tw = ev.target.closest(".tw.has"); if (tw) { tw.closest(".nw").classList.toggle("open"); return; }
        const add = ev.target.closest(".act-add"); if (add) { ev.stopPropagation(); this.emit("an-doc-add", { id: add.dataset.id }); return; }
        const more = ev.target.closest(".act-more"); if (more) { ev.stopPropagation(); this.emit("an-doc-more", { id: more.dataset.id, anchor: more }); return; }
        const node = ev.target.closest(".node"); if (node) { this._sel = node.dataset.id; this._paintSel(); this.emit("an-doc-select", { id: node.dataset.id }); }
      });
      this._paintSel();
    }
    _paintSel() { this.$$(".node").forEach((n) => n.classList.toggle("sel", n.dataset.id === this._sel)); }
  }
  window.AnElement.define(AnDocTree);
})();
