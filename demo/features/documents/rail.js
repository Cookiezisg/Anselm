/* Anselm feature — documents 侧栏（rail）：Notion 式嵌套【文档】树（非文件夹）。
   走 an-doc-tree 原语：New Document + 搜索 + 可折叠层级 + 每行悬停 ＋（加子文档）/ ⋯（编辑菜单）。
   点行 → Intent.select({kind:document}) 路由回本海洋 owns:["document"] → sea loadDoc；New/＋/⋯ 为 mock 动作（真后端走 POST/:move/:duplicate/delete）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.documents = Object.assign(window.FEATURE.documents || {}, {
  rail: (ctx) => {
    const labelOf = (id) => { let f = id; (function w(ns) { (ns || []).forEach((n) => { if (n.id === id) f = n.label; if (n.children) w(n.children); }); })(window.DOC_TREE || []); return f; };
    const toast = (text) => window.AnToast && window.AnToast.show({ text });

    const tree = document.createElement("an-doc-tree");
    tree.tree = window.DOC_TREE || [];
    tree.selected = window.DOC_DEFAULT || "doc_prd";

    tree.addEventListener("an-doc-select", (ev) => ctx.Intent.select({ kind: "document", id: ev.detail.id }));
    tree.addEventListener("an-doc-new", () => toast("New Document → 根新建文档（mock · POST /documents）"));
    tree.addEventListener("an-doc-add", (ev) => toast("在「" + labelOf(ev.detail.id) + "」下加子文档（mock · POST ?parentId=" + ev.detail.id + "）"));
    // 行 ⋯ → 该文档的编辑菜单（重命名 / 加子文档 / 复制 / 移动 / 删除）——demo 走 toast
    tree.addEventListener("an-doc-more", (ev) => {
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
    return tree;
  },
});
