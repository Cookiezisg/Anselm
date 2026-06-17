/* Anselm feature — documents 侧栏（rail）：Notion 式嵌套【文档】树（非文件夹）。
   复用 an-sidebar-list（与 entities 同件，仅换文档图标）+ 嵌套行扩展：New Document + 搜索 + 任意深可折叠（点 chevron 折叠、点标题开文档）+ 每行悬停 ⋯（编辑菜单：含「加子文档」）。
   点行 → Intent.select({kind:document}) 路由回本海洋 owns:["document"] → sea loadDoc；New/＋/⋯ 为 mock（真后端 POST/:move/:duplicate/delete）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.documents = Object.assign(window.FEATURE.documents || {}, {
  rail: (ctx) => {
    const openId = window.DOC_DEFAULT || "doc_prd";
    const labelOf = (id) => { let f = id; (function w(ns) { (ns || []).forEach((n) => { if (n.id === id) f = n.label; if (n.children) w(n.children); }); })(window.DOC_TREE || []); return f; };
    const toast = (text) => window.AnToast && window.AnToast.show({ text });
    // DOC_TREE → sidebar-list 嵌套行（全文档图标；有子 → 可折叠树枝）
    const toRows = (nodes) => (nodes || []).map((n) => ({ id: n.id, label: n.label, icon: "doc", selected: n.id === openId, children: (n.children && n.children.length) ? toRows(n.children) : undefined }));

    const el = document.createElement("an-sidebar-list");
    el.setAttribute("more", "");   // 每行悬停 ⋯（编辑菜单，同 entities）
    el.model = { newLabel: "New Document", filterPlaceholder: "搜索文档…", groups: [{ types: [{ rows: toRows(window.DOC_TREE || []) }] }] };

    el.addEventListener("an-select", (ev) => { if (ev.detail && ev.detail.id != null) ctx.Intent.select({ kind: "document", id: ev.detail.id }); });
    el.addEventListener("an-new", () => toast("New Document → 根新建文档（mock · POST /documents）"));
    el.addEventListener("an-row-more", (ev) => {
      const id = ev.detail.id, name = labelOf(id);
      window.AnMenu.open(ev.detail.anchor, {
        align: "start", placement: "bottom", namespace: "doc-menu",
        items: [
          { value: "rename", label: "重命名", icon: "edit" },
          { value: "add", label: "加子文档", icon: "plus" },
          { value: "duplicate", label: "复制（深拷子树）", icon: "diff" },
          { value: "move", label: "移动到…", icon: "enter" },
          { value: "delete", label: "删除（软删子树）", icon: "trash", danger: true },
        ],
        onPick: (v) => toast("「" + name + "」· " + v + "（mock · " + ({ rename: "PATCH", add: "POST ?parentId", duplicate: ":duplicate", move: ":move", delete: "soft-delete" })[v] + "）"),
      });
    });
    return el;
  },
});
