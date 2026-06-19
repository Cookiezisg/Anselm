/* Anselm feature — scheduler 侧栏（rail）：active/draining workflow 列表（lifecycle + concurrency 治理态）+ 搜索（无 New——workflow 不在此新建）。
   走 an-sidebar-list[no-new] + headless 类型（仅此一组、无需大标题）：工作流行（dot=活态、meta=治理态）；选中 → Intent.select({kind:workflow}) 路由回本海洋 owns:["workflow"] → sea loadWorkflow。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.scheduler = Object.assign(window.FEATURE.scheduler || {}, {
  rail: (ctx) => {
    const WFS = window.SCHED_WORKFLOWS || [];
    const sel = window.SCHED_DEFAULT;   // 默认预选首个 workflow（与 sea 默认 loadWorkflow 对齐）
    const el = document.createElement("an-sidebar-list");
    el.setAttribute("no-new", "");   // workflow 不在此新建，仅搜索 + 选中
    el.model = { filterPlaceholder: "搜索", groups: [{ types: [{
      rows: WFS.map((w) => ({ id: w.id, label: w.label, meta: w.meta, dot: w.dot, selected: w.id === sel })),
    }] }] };
    el.addEventListener("an-select", (ev) => { if (ev.detail && ev.detail.id != null) ctx.Intent.select({ kind: "workflow", id: ev.detail.id }); });
    return el;
  },
});
