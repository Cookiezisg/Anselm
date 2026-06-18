/* Anselm feature — chat 侧栏（rail）：会话列表（置顶/今天/昨天/已归档 + 搜索 + New Chat + 每行 ⋯）。
   复用 an-sidebar-list（与 entities/documents/scheduler 同件）：可折叠大组承载会话分组（按 lastMessageAt 降序，dot=活态）。
   点行 → Intent.select({kind:conversation}) 路由回本海洋 owns:['conversation'] → sea loadConvo；New/⋯ 为 mock（真后端 POST /conversations · PATCH pin/archive · DELETE）。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.chat = Object.assign(window.FEATURE.chat || {}, {
  rail: (ctx) => {
    const LIST = window.CHAT_CONVOS_LIST || [];
    const sel = window.CHAT_DEFAULT;
    const labelOf = (id) => { let f = id; LIST.forEach((g) => (g.rows || []).forEach((r) => { if (r.id === id) f = r.label; })); return f; };
    const toast = (text) => window.AnToast && window.AnToast.show({ text });

    const elx = document.createElement("an-sidebar-list");
    elx.setAttribute("more", "");   // 每行悬停 ⋯（会话动作菜单）
    elx.model = {
      newLabel: "New Chat", filterPlaceholder: "搜索",
      groups: LIST.map((g) => ({
        label: g.group, open: g.open !== false,
        types: [{ rows: (g.rows || []).map((r) => ({ id: r.id, label: r.label, dot: r.dot, meta: r.meta, selected: r.id === sel })) }],
      })),
    };

    elx.addEventListener("an-select", (ev) => { if (ev.detail && ev.detail.id != null) ctx.Intent.select({ kind: "conversation", id: ev.detail.id }); });
    elx.addEventListener("an-new", () => toast("已新建对话"));
    elx.addEventListener("an-row-more", (ev) => {
      const id = ev.detail.id, name = labelOf(id);
      window.AnMenu.open(ev.detail.anchor, {
        align: "start", placement: "bottom", namespace: "chat-menu",
        items: [
          { value: "rename", label: "重命名", icon: "edit" },
          { value: "pin", label: "置顶", icon: "history" },
          { value: "archive", label: "归档", icon: "enter" },
          { value: "delete", label: "删除", icon: "trash", danger: true },
        ],
        onPick: (v) => toast({ rename: "已重命名「" + name + "」", pin: "已置顶「" + name + "」", archive: "已归档「" + name + "」", delete: "已删除「" + name + "」" }[v]),
      });
    });
    return elx;
  },
});
