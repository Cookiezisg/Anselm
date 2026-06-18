/* Anselm 原语 — <an-entity-workspace>。chat 右岛「实体工作台」：把一段对话碰过的实体各开一个 tab（顶层 an-tabs）+ 末尾可选 Todo tab；
   每个实体卡（an-info-card）内按其在对话里出现的 tool call 开若干子视图（an-segmented 切换）——
     create → an-code-editor 流式新建源码（function/handler 源 · agent 指令 · workflow graph ops）
     edit   → an-version-diff 旧→新逐字红绿 diff（写新版本立即生效，无审批门）
     run    → an-run-terminal 终端（:run/:call 单次执行 → stdout + 终态 + 结构化输出）
     flowrun→ an-node-gantt 逐节点点亮（:trigger 产出 durable flowrun，非单值）
     trace  → 嵌套 an-block-tree（:invoke 的 ReAct 轨迹，耐久在 Execution.transcript）
     detail/config → an-kv（版本/env/接线/flowrun 快照等键值）
   why：本件是 entities SSE 流的前端「实体面板」镜像——对话流 an-block-tree 是 messages 流的耐久真相，二者并行双写；
     本件只承载【结构 + live 子元素入口】，逐字/逐行的流式节奏由 chat sea 持有（切会话统一清 timer），守「DB 行是真相、流只为实时」。
   model（JS 属性，承载 render 数据无法塞 attr）：{ title?, entities:[EntitySpec], todo?:bool（建空 Todo 看板，待 setTodo 喂）, todos?:[…]（直接种入 Todo 看板，静态/画廊用）}；
     EntitySpec={ id, kind, name, lang?, meta?, revert?, views:[ViewSpec] }；
     ViewSpec={ key:create|edit|run|flowrun|trace|detail|config, label, 按 key 携 code/before/after/range/note/args/trace/gate/nodes/blocks/rows }。
   命令式（sea 回合驱动）：focus(id,viewKey)→切实体 tab + 子视图、返回该 view 的 live 元素供流式喂入；viewEl(id,viewKey)；setTodo(items)→喂 Todo tab 看板；emit 'an-revert'{id}。 */
(function () {
  const el = window.el;
  const KIND = window.ENTITY_KINDS || {};

  class AnEntityWorkspace extends window.AnElement {
    static tag = "an-entity-workspace";
    static observed = [];   // 全经 model 属性驱动，无 attr 响应
    static css = `
      :host { display: block; }
      /* 顶层 tab 占满岛内宽；子视图（code/diff/terminal/gantt）各自管高度，pane 块流自然排布。 */
      .mount { display: block; min-width: 0; }
      an-tabs { display: block; }
    `;

    set model(v) { this._spec = v || { entities: [] }; if (this.isConnected) this._build(); }
    get model() { return this._spec || { entities: [] }; }

    render() { return `<div class="mount"></div>`; }
    hydrate() { this._build(); }

    // 据 _spec 重建：顶层 an-tabs（每实体一项 + 可选 Todo），各卡预建好供懒 render 回调挂入（已设种子值的子元素连上即显）。
    _build() {
      const mount = this.$(".mount"); if (!mount) return;
      mount.innerHTML = "";
      this._islands = new Map();   // id → { card, seg, views:Map<key,el> }
      this._todoTree = null;
      const spec = this._spec || { entities: [] };
      const tabs = el("an-tabs");
      const items = [];
      (spec.entities || []).forEach((es) => {
        const built = this._buildCard(es);
        this._islands.set(es.id, built);
        items.push({ key: es.id, label: es.name || es.id, render: (pane) => pane.append(built.card) });
      });
      const todos = Array.isArray(spec.todos) ? spec.todos : null;
      if (spec.todo || todos) {   // todo:bool 仅建空看板（待 setTodo 喂）；todos:[] 直接种入（静态/画廊）
        const tree = el("an-block-tree", { nested: true });
        if (todos) tree.blocks = [{ type: "todo", open: true, items: todos }];
        this._todoTree = tree;
        items.push({ key: "__todo__", label: "Todo", render: (pane) => pane.append(tree) });
      }
      tabs.items = items;
      this._tabs = tabs;
      mount.append(tabs);
    }

    // 单实体卡（按 kind 分派子视图）：an-info-card[title=实体名,icon=kind 图标,meta=态] > an-segmented（>1 视图才出）+ 各 view 元素（hidden 切换）+ footer revert。
    _buildCard(es) {
      const kind = KIND[es.kind] || {};
      const card = el("an-info-card", { title: es.name || es.id, icon: kind.icon || es.kind, meta: es.meta || "" });
      const views = new Map();
      const viewEls = [];
      (es.views || []).forEach((v, i) => {
        const ve = this._buildView(es, v);
        if (i !== 0) ve.setAttribute("hidden", "");
        views.set(v.key, ve); viewEls.push(ve);
      });
      const seg = el("an-segmented");
      seg.items = (es.views || []).map((v) => ({ value: v.key, label: v.label || v.key }));
      seg.addEventListener("an-pick", (ev) => viewEls.forEach((x, i) => x.toggleAttribute("hidden", (es.views[i] || {}).key !== ev.detail.value)));
      if ((es.views || []).length > 1) card.append(seg);
      viewEls.forEach((x) => card.append(x));
      if (es.revert) {
        const rv = el("an-button", { slot: "actions", variant: "ghost", size: "sm", icon: "history",
          onclick: () => this.emit("an-revert", { id: es.id, name: es.name }) }, typeof es.revert === "string" ? es.revert : "revert 回退");
        card.append(rv);
      }
      return { card, seg, views };
    }

    // kind × viewKey → 一种 live 子元素（种子值随 spec 设入；流式时 sea 经 focus 拿到它再喂）。
    _buildView(es, v) {
      const lang = es.lang || "text";
      const kind = KIND[es.kind] || {};
      if (v.key === "create") {
        const ed = el("an-code-editor", { lang });
        if (v.code != null) ed.textContent = v.code;
        return ed;
      }
      if (v.key === "edit") {
        const d = el("an-version-diff", { lang });
        if (v.range) d.setAttribute("range", v.range);
        if (v.note) d.setAttribute("note", v.note);
        if (v.before != null) d.before = v.before;
        if (v.after != null) d.after = v.after;
        return d;
      }
      if (v.key === "run") {
        const t = el("an-run-terminal", { verb: kind.verb || "Run", vico: "play", lang: "json" });
        if (v.args != null) t.setAttribute("args", v.args);
        if (v.gate) t.setAttribute("gate", v.gate);
        if (v.trace) t.setAttribute("data-trace", JSON.stringify(v.trace));
        return t;
      }
      if (v.key === "flowrun") {
        const g = el("an-node-gantt");
        if (v.nodes) g.nodes = v.nodes;
        return g;
      }
      if (v.key === "trace") {
        const bt = el("an-block-tree", { nested: true });
        if (v.blocks) bt.blocks = v.blocks;
        return bt;
      }
      // detail / config / 兜底 → an-kv
      const kv = el("an-kv", { wrap: true });
      if (v.rows) kv.rows = v.rows;
      return kv;
    }

    // ── 命令式：切实体 tab + 子视图、返回该 view live 元素（sea 流式喂入前必经此确保 tab 已 render = 元素已连上） ──
    focus(id, viewKey) {
      if (!this._tabs) return null;
      this._tabs.select(id, false);   // 懒 render → 卡连上（种子值显出）
      const isl = this._islands && this._islands.get(id);
      if (!isl) return null;
      if (viewKey && isl.views.has(viewKey)) {
        isl.seg.value = viewKey;        // 移段控胶囊
        isl.views.forEach((elx, k) => elx.toggleAttribute("hidden", k !== viewKey));   // 我方元素显隐为准
        return isl.views.get(viewKey);
      }
      return null;
    }
    viewEl(id, viewKey) { const isl = this._islands && this._islands.get(id); return isl ? (isl.views.get(viewKey) || null) : null; }
    // Todo tab 看板：整表替换写（复用 block-tree 已成型 todo 渲染）；并切到 Todo tab 让其可见。
    setTodo(items) {
      if (!this._todoTree) return;
      this._todoTree.blocks = [{ type: "todo", open: true, items: items || [] }];
    }
    showTodo() { if (this._tabs && this._todoTree) this._tabs.select("__todo__", false); }
  }
  window.AnElement.define(AnEntityWorkspace);
})();
