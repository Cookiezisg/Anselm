/* Anselm feature — documents 侧栏（rail）：Notion 式嵌套【文档】树（非文件夹）。
   复用 an-sidebar-list（与 entities 同件，仅换文档图标）+ 嵌套行扩展：New Document + 搜索 + 任意深可折叠（点 chevron 折叠、点标题开文档）+ 每行悬停 ⋯（编辑菜单：含「加子文档」）。
   点行 → Intent.select({kind:document}) 路由回本海洋 owns:["document"] → sea loadDoc；New/＋/⋯ 为 mock（真后端 POST/:move/:duplicate/delete）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.documents = Object.assign(window.FEATURE.documents || {}, {
  rail: (ctx) => {
    const openId = window.DOC_DEFAULT;   // 默认预选首篇文档（与 sea 默认 loadDoc 对齐）
    const labelOf = (id) => { let f = id; (function w(ns) { (ns || []).forEach((n) => { if (n.id === id) f = n.label; if (n.children) w(n.children); }); })(window.DOC_TREE || []); return f; };
    const toast = (text) => window.AnToast && window.AnToast.show({ text });
    // DOC_TREE → sidebar-list 嵌套行（全文档图标；有子 → 可折叠树枝）
    const toRows = (nodes) => (nodes || []).map((n) => ({ id: n.id, label: n.label, icon: "doc", selected: n.id === openId, children: (n.children && n.children.length) ? toRows(n.children) : undefined }));

    const el = document.createElement("an-sidebar-list");
    el.setAttribute("more", "");   // 每行悬停 ⋯（编辑菜单，同 entities）
    el.model = { newLabel: "New Document", filterPlaceholder: "搜索", groups: [{ types: [{ rows: toRows(window.DOC_TREE || []) }] }] };

    el.addEventListener("an-select", (ev) => { if (ev.detail && ev.detail.id != null) ctx.Intent.select({ kind: "document", id: ev.detail.id }); });
    el.addEventListener("an-new", () => toast("已新建文档"));   // New Document → mock 新建（真后端 POST）
    el.addEventListener("an-row-more", (ev) => {
      const id = ev.detail.id, name = labelOf(id);
      window.AnMenu.open(ev.detail.anchor, {
        align: "start", placement: "bottom", namespace: "doc-menu",
        items: [
          { value: "rename", label: "重命名", icon: "edit" },
          { value: "add", label: "新建子文档", icon: "plus" },
          { value: "duplicate", label: "复制", icon: "diff" },
          { value: "move", label: "移动到…", icon: "enter" },
          { value: "delete", label: "删除", icon: "trash", danger: true },
        ],
        onPick: (v) => toast({ rename: "已重命名「" + name + "」", add: "已在「" + name + "」下新建子文档", duplicate: "已复制「" + name + "」", move: "已移动「" + name + "」", delete: "已删除「" + name + "」" }[v]),
      });
    });
    return el;
  },
});
