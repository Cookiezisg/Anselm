/* Anselm feature — documents 侧栏（rail）：嵌套【文档】树（非文件夹）。
   后端：单 workspace markdown 树，父子有序、path 寻址；每个节点本身是一篇文档、又能有子文档。
   渲染：DOC_TREE 递归铺成缩进行（depth），全 doc 图标、靠缩进显嵌套；点行选中（打开的 PRD 高亮）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.documents = Object.assign(window.FEATURE.documents || {}, {
  rail: (ctx) => {
    const TREE = window.DOC_TREE || [];
    const openId = window.DOC_DEFAULT || "doc_prd";
    const items = [["g", "文档库"]];
    (function walk(nodes, depth) {
      nodes.forEach((n) => {
        items.push(["r", { icon: "doc", label: n.label, depth, id: n.id }]);
        if (n.children && n.children.length) walk(n.children, depth + 1);
      });
    })(TREE, 0);
    const w = ctx.rail(items);
    // 高亮当前打开文档
    w.querySelectorAll("an-row[data-id]").forEach((r) => { if (r.getAttribute("data-id") === openId) r.setAttribute("selected", ""); });
    // 点行 → 切到该文档（Intent.select 路由回本海洋 owns:["document"] → sea loadDoc）
    w.addEventListener("an-select", (ev) => {
      const id = ev.target && ev.target.getAttribute && ev.target.getAttribute("data-id");
      if (id) ctx.Intent.select({ kind: "document", id });
    });
    return w;
  },
});
