/* Anselm feature — documents 海洋（sea）：打开文档的编辑面 + 右岛信息。
   主面 = an-page（居中阅读列）：ocean-header（path crumb + 可改名标题）+ an-doc-editor（块编辑 + 斜杠 + @ + 悬卡）。
   右岛 = 大纲 ToC · 反链/出链（relation 双向边）· 元信息 · AI 编辑入口——四块按用户选取铺成 info-card 堆叠。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.documents = Object.assign(window.FEATURE.documents || {}, {
  sea: (ctx) => {
    const D = window.DOC_OPEN || {};
    const el = (tag, attrs, ...kids) => {
      const n = document.createElement(tag);
      if (attrs) for (const k in attrs) { const v = attrs[k]; if (v == null || v === false) continue; if (k === "prop") Object.assign(n, v); else n.setAttribute(k, v === true ? "" : v); }
      kids.flat().forEach((c) => { if (c == null) return; n.append(c.nodeType ? c : document.createTextNode(String(c))); });
      return n;
    };
    const rowsCard = (title, icon, rows) => el("an-info-card", { title, icon }, ...rows.map((r) => el("an-row", r)));

    // ── 主面：页头 + 编辑器 ──
    const segs = (D.path || "").split("/").filter(Boolean);
    const page = el("an-page");
    const head = el("an-ocean-header", { crumb: "Documents | " + segs.slice(0, -1).join(" | "), title: D.title || "未命名", editable: true });
    const editor = el("an-doc-editor");
    editor.mentions = window.DOC_MENTIONS || [];
    editor.blocks = D.blocks || [];
    page.append(head, editor);

    // ── 右岛：四块 ──
    const island = el("an-right-island", { title: "文档信息", icon: "doc" });

    // 大纲 ToC（按 level 缩进）
    island.append(el("an-info-card", { title: "大纲", icon: "sliders" },
      ...(D.outline || []).map((o) => el("an-row", { label: o.text, depth: Math.max(0, (o.level || 2) - 2), passive: true }))));

    // 反链（谁引用了本文）
    island.append(rowsCard("反链 · 被引用", "history", (D.backlinks || []).map((b) => ({ icon: b.icon, label: b.label, meta: b.meta, hint: b.hint }))));

    // 出链 / @ 提及（本文引用了谁）
    island.append(rowsCard("出链 · @ 提及", "enter", (D.outlinks || []).map((o) => ({ icon: o.icon, label: o.label, meta: o.meta, passive: true }))));

    // 元信息
    const metaCard = el("an-info-card", { title: "元信息", icon: "shield-check" });
    const metaKv = el("an-kv"); metaKv.setAttribute("wrap", ""); metaKv.rows = D.meta || [];
    metaCard.append(metaKv);
    island.append(metaCard);

    // AI 编辑入口 + 历史
    const aiCard = el("an-info-card", { title: "AI 编辑", icon: "sparkles" });
    const aiBtn = el("an-button", { icon: "sparkles", block: true }, "AI 编辑本文（:iterate）");
    aiBtn.addEventListener("click", () => window.AnToast && window.AnToast.show({ text: "开对话编辑文档 → conversationId（接 chat 海洋）" }));
    aiCard.append(aiBtn, ...(D.history || []).map((h) => el("an-row", { icon: h.icon, label: h.label, meta: h.meta, hint: h.hint, passive: true })));
    island.append(aiCard);

    if (ctx.shell) ctx.shell.setRight(island);
    return page;
  },
});
