/* Anselm 原语 🪂 — <an-doc-editor>。Notion 式块编辑器（全 demo 唯一自画像素区，逃生舱）。
   blocks 经 JS 属性注入（h1/h2/h3 · p[spans 含 @ref] · bullet · todo · quote · code · callout · divider）→ 渲一次 contenteditable 富文本，之后编辑活在 DOM。
   三大能力：① 斜杠「/」→ 块类型菜单（AnMenu）→ 变当前块；② 「@」→ 实体/文档 picker → 内联插 an-ref-pill；③ 悬停 ref-pill → 浮信息卡（AnFloating）。
   why 逃生舱：块编辑须自管 contenteditable + caret + 浮层，非声明式原语能覆盖——收进单件、对外只暴露 blocks/mentions 属性。 */
(function () {
  const e = window.anEsc;

  // 斜杠菜单的块类型（value = 目标块型）
  const SLASH = [
    { type: "label", label: "基础块" },
    { value: "p", label: "文本", icon: "doc", meta: "正文段" },
    { value: "h2", label: "标题", icon: "doc", meta: "H2" },
    { value: "h3", label: "小标题", icon: "doc", meta: "H3" },
    { value: "bullet", label: "无序列表", icon: "doc", meta: "•" },
    { value: "todo", label: "待办", icon: "check", meta: "[ ]" },
    { value: "quote", label: "引用", icon: "doc", meta: "❝" },
    { type: "label", label: "富块" },
    { value: "code", label: "代码", icon: "terminal", meta: "code" },
    { value: "callout", label: "提示条", icon: "shield", meta: "callout" },
    { value: "divider", label: "分割线", icon: "sliders", meta: "—" },
    { value: "mention", label: "@ 提及实体/文档", icon: "sparkles", meta: "@" },
  ];

  function refHtml(r) {
    return `<an-ref-pill kind="${e(r.kind || "")}" id="${e(r.id || "")}" label="${e(r.label || "")}" contenteditable="false"></an-ref-pill>`;
  }
  function spansHtml(b) {
    if (b.html != null) return b.html;
    if (b.spans) return b.spans.map((s) => (s.ref ? refHtml(s.ref) : e(s.t != null ? s.t : ""))).join("");
    return e(b.text || "");
  }
  function blockHtml(b) {
    const t = b.type || "p";
    if (t === "divider") return `<hr class="b" data-t="divider" contenteditable="false">`;
    if (t === "code") return `<pre class="b code" data-t="code"><span class="lang" contenteditable="false">${e(b.lang || "text")}</span><code>${e(b.text || "")}</code></pre>`;
    if (t === "callout") return `<div class="b callout" data-t="callout"><span class="ci" contenteditable="false">${window.icon("shield")}</span><span class="bt">${b.html != null ? b.html : e(b.text || "")}</span></div>`;
    if (t === "quote") return `<blockquote class="b" data-t="quote">${e(b.text || "")}</blockquote>`;
    if (t === "bullet") return `<div class="b bl" data-t="bullet"><span class="mk" contenteditable="false">•</span><span class="bt">${e(b.text || "")}</span></div>`;
    if (t === "todo") return `<div class="b td${b.checked ? " on" : ""}" data-t="todo"><span class="ck" contenteditable="false">${b.checked ? window.icon("check") : ""}</span><span class="bt">${e(b.text || "")}</span></div>`;
    if (t === "h1" || t === "h2" || t === "h3") return `<div class="b ${t}" data-t="${t}">${e(b.text || "")}</div>`;
    return `<p class="b" data-t="p">${spansHtml(b)}</p>`;
  }
  const PLACEHOLDER = { p: "写点什么，或按 / 选块、@ 提及…", h2: "标题", h3: "小标题", bullet: "列表项", todo: "待办项", quote: "引用…", code: "// 代码" };

  class AnDocEditor extends window.AnElement {
    static tag = "an-doc-editor";
    static observed = [];
    static css = `
      :host { display: block; }
      .doc { outline: none; color: var(--ink); font-size: var(--t-body); line-height: var(--lh-prose); }
      .b { margin: var(--sp-2) 0; min-height: var(--lh-prose); }
      .b:first-child { margin-top: 0; }
      .h2 { font-size: var(--t-h3); font-weight: 600; line-height: var(--lh-tight); margin: var(--sp-5) 0 var(--sp-2); }
      .h3 { font-size: var(--t-strong); font-weight: 600; line-height: var(--lh-tight); margin: var(--sp-4) 0 var(--sp-1); }
      .bl, .td { display: grid; grid-template-columns: var(--lead) 1fr; align-items: start; column-gap: var(--gap); }
      .mk, .ck { display: grid; place-items: center; height: var(--lh-prose); color: var(--ink-3); }
      .ck { width: var(--ctl-sm); height: var(--ctl-sm); border-radius: var(--r-tag); box-shadow: inset 0 0 0 var(--hairline) var(--line); cursor: pointer; color: var(--accent); }
      .ck svg { width: var(--icon-sm); height: var(--icon-sm); }
      .td.on .bt { color: var(--ink-3); text-decoration: line-through; }
      blockquote.b { margin-left: 0; padding: var(--sp-1) 0 var(--sp-1) var(--sp-4); border-left: var(--line-2) solid var(--line-strong); color: var(--ink-2); }
      .callout { display: grid; grid-template-columns: var(--lead) 1fr; align-items: start; column-gap: var(--gap);
        padding: var(--sp-3) var(--btn-pad-x); border-radius: var(--r-chip); background: var(--accent-soft); }
      .callout .ci { display: grid; place-items: center; height: var(--lh-prose); color: var(--accent); }
      .callout .ci svg { width: var(--icon); height: var(--icon); }
      pre.code { position: relative; margin: var(--sp-3) 0; padding: var(--sp-3) var(--sp-4); border-radius: var(--r-card);
        background: var(--island-2); box-shadow: inset 0 0 0 var(--hairline) var(--line);
        font-family: var(--mono); font-size: var(--t-meta); line-height: var(--lh-prose); color: var(--ink-2); white-space: pre-wrap; overflow-wrap: anywhere; }
      pre.code .lang { position: absolute; top: var(--sp-2); right: var(--sp-3); color: var(--ink-3); font-size: var(--t-meta); }
      hr.b { border: none; border-top: var(--hairline) solid var(--line); margin: var(--sp-5) 0; }
      an-ref-pill { margin: 0 var(--grid); vertical-align: baseline; }
      /* 空块占位提示（仅当前聚焦的空块显示） */
      .b[data-empty]:focus::before { content: attr(data-empty); color: var(--ink-3); pointer-events: none; }
    `;

    set blocks(v) { this._blocks = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }
    get blocks() { return this._blocks || []; }
    set mentions(v) { this._mentions = Array.isArray(v) ? v : []; }
    get mentions() { return this._mentions || []; }

    render() {
      return `<div class="doc" contenteditable="true" spellcheck="false">${(this._blocks || []).map(blockHtml).join("")}</div>`;
    }

    hydrate() {
      const doc = this.$(".doc");
      if (!doc) return;
      // 待办勾选
      doc.addEventListener("click", (ev) => {
        const ck = ev.target.closest && ev.target.closest(".ck");
        if (!ck) return;
        const td = ck.closest(".td"); if (!td) return;
        const on = td.classList.toggle("on");
        ck.innerHTML = on ? window.icon("check") : "";
      });
      // 悬停 ref-pill → 浮信息卡
      doc.addEventListener("pointerover", (ev) => {
        const pill = ev.target.closest && ev.target.closest("an-ref-pill");
        if (pill && pill !== this._hovered) this._openCard(pill);
      });
      doc.addEventListener("pointerout", (ev) => {
        const pill = ev.target.closest && ev.target.closest("an-ref-pill");
        if (pill && !pill.contains(ev.relatedTarget)) this._closeCard();
      });
      // 斜杠 / @ 触发
      doc.addEventListener("keydown", (ev) => {
        if (ev.key === "/") setTimeout(() => this._slash(), 0);
        else if (ev.key === "@") setTimeout(() => this._mention(), 0);
      });
    }

    // 当前 caret 所在块（.b 祖先）
    _curBlock() {
      const sel = (this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection());
      if (!sel || !sel.anchorNode) return null;
      let n = sel.anchorNode;
      while (n && n !== this.$(".doc") && !(n.classList && n.classList.contains("b"))) n = n.parentNode;
      return (n && n.classList && n.classList.contains("b")) ? n : null;
    }
    _caretEnd(el) {
      const sel = (this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection());
      const r = document.createRange();
      r.selectNodeContents(el); r.collapse(false);
      sel.removeAllRanges(); sel.addRange(r);
      el.focus && el.focus();
    }
    // 去掉块尾刚敲的触发字符（/ 或 @）
    _stripTrailing(block, ch) {
      const tn = block.lastChild;
      if (tn && tn.nodeType === 3 && tn.textContent.endsWith(ch)) tn.textContent = tn.textContent.slice(0, -1);
    }

    _slash() {
      const block = this._curBlock();
      if (!block || (block.textContent || "").trim() !== "/") return;   // 仅当块内容恰为「/」（行首斜杠）才弹
      window.AnMenu.open(block, {
        items: SLASH, placement: "bottom", align: "start", namespace: "doc-slash",
        onPick: (type) => { this._stripTrailing(block, "/"); type === "mention" ? this._insertRefInto(block) : this._applyBlock(block, type); },
      });
    }
    _applyBlock(block, type) {
      const tmp = document.createElement("div");
      tmp.innerHTML = blockHtml({ type, text: "" });
      const nb = tmp.firstElementChild;
      if (type !== "divider") nb.setAttribute("data-empty", PLACEHOLDER[type] || "");
      block.replaceWith(nb);
      if (type === "divider") { const p = document.createElement("p"); p.className = "b"; p.setAttribute("data-t", "p"); nb.after(p); this._caretEnd(p); }
      else this._caretEnd(nb.querySelector(".bt") || nb);
    }

    _sel() { return this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection(); }
    // 「@」起一段提及会话：开筛选菜单 + 监听后续输入边打边滤；选中/空格/Esc/删掉@ 结束。
    _mention() {
      const block = this._curBlock();
      if (!block) return;
      this._atBlock = block;
      this._atQuery = "@@INIT@@";
      this._atUpdate();
      if (!this._atInput) {
        const doc = this.$(".doc");
        this._atInput = () => this._atUpdate();
        this._atKey = (ev) => { if (ev.key === "Escape" || ev.key === " " || ev.key === "Enter") this._endAt(); };
        doc.addEventListener("input", this._atInput);
        doc.addEventListener("keydown", this._atKey);
      }
    }
    _atQueryText() {
      const sel = this._sel();
      if (!sel || !sel.anchorNode || !this._atBlock || !this._atBlock.contains(sel.anchorNode)) return null;
      const node = sel.anchorNode;
      if (node.nodeType !== 3) return null;
      const text = node.textContent.slice(0, sel.anchorOffset);
      const at = text.lastIndexOf("@");
      return at < 0 ? null : text.slice(at + 1);
    }
    _atUpdate() {
      const q = this._atQueryText();
      if (q == null || /\s/.test(q)) { this._endAt(); return; }
      if (q === this._atQuery) return;
      this._atQuery = q;
      const lo = q.toLowerCase();
      let ms = (this._mentions || []).filter((m) => !lo || (m.label + " " + (m.desc || "") + " " + m.id).toLowerCase().includes(lo));
      const items = ms.length ? ms.map((m) => ({ value: m.id, label: m.label, icon: m.kind, meta: m.desc || m.kind, _m: m }))
        : [{ type: "label", label: "无匹配「" + q + "」" }];
      window.AnMenu.open(this._atBlock, {
        items, placement: "bottom", align: "start", namespace: "doc-at",
        onClose: () => { this._closing || this._endAt(); },
        onPick: (_v, it) => { if (!it._m) return; this._endAt(); this._pickMention(it._m); },
      });
    }
    _endAt() {
      if (this._atInput) { const doc = this.$(".doc"); doc.removeEventListener("input", this._atInput); doc.removeEventListener("keydown", this._atKey); this._atInput = null; }
      this._atBlock = null; this._atQuery = null;
      this._closing = true; window.AnFloating.close("doc-at"); this._closing = false;
    }
    // 选中提及：删掉「@query」再插药丸（无则直接插）
    _pickMention(m) {
      const sel = this._sel();
      const node = sel && sel.anchorNode;
      if (node && node.nodeType === 3) {
        const text = node.textContent.slice(0, sel.anchorOffset);
        const at = text.lastIndexOf("@");
        if (at >= 0) { const r = document.createRange(); r.setStart(node, at); r.setEnd(node, sel.anchorOffset); r.deleteContents(); sel.removeAllRanges(); sel.addRange(r); }
      }
      this._insertPill(m);
    }
    // 斜杠「@提及」路径：无会话、直接开菜单选一项插（无 @ 可删）
    _insertRefInto(block) {
      const items = (this._mentions || []).map((m) => ({ value: m.id, label: m.label, icon: m.kind, meta: m.desc || m.kind, _m: m }));
      window.AnMenu.open(block, { items, placement: "bottom", align: "start", namespace: "doc-at", onPick: (_v, it) => this._insertPill(it._m) });
    }
    _insertPill(m) {
      const sel = (this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection());
      const tmp = document.createElement("div");
      tmp.innerHTML = refHtml({ kind: m.kind, id: m.id, label: m.label }) + "&nbsp;";
      const pill = tmp.firstChild, sp = tmp.lastChild;
      const block = this._curBlock() || this.$(".doc");
      if (sel && sel.rangeCount && block.contains(sel.anchorNode)) {
        const r = sel.getRangeAt(0); r.insertNode(sp); r.insertNode(pill); r.setStartAfter(sp); r.collapse(true);
        sel.removeAllRanges(); sel.addRange(r);
      } else { block.append(pill, sp); }
    }

    _openCard(pill) {
      this._hovered = pill;
      const kind = pill.getAttribute("kind"), id = pill.getAttribute("id"), label = pill.getAttribute("label");
      const FALLBACK = { doc: { label: "文档", icon: "doc" } };   // 纯提及 kind（非 9 实体）补标签/图标
      const ent = (window.ENTITY_KINDS || {})[kind] || FALLBACK[kind] || {};
      const rows = [["类型", ent.label || kind], ["ID", id]];
      const card = `<div class="dc-card">`
        + `<div class="dc-h"><span class="dc-i">${window.icon(ent.icon || kind)}</span><span class="dc-t">${e(label)}</span></div>`
        + rows.map((r) => `<div class="dc-r"><span class="dc-k">${e(r[0])}</span><span class="dc-v">${e(r[1])}</span></div>`).join("")
        + `<div class="dc-f">点击跳转 · 悬停看卡片</div></div>`;
      window.AnFloating.open(pill, { content: card, placement: "top", align: "start", namespace: "doc-card", className: "dc-float" });
    }
    _closeCard() { this._hovered = null; window.AnFloating.close("doc-card"); }
  }

  window.AnElement.define(AnDocEditor);

  // 悬卡皮肤（light-DOM 浮层，一次性注入；token-only）
  if (!document.getElementById("an-doc-card-style")) {
    const s = document.createElement("style");
    s.id = "an-doc-card-style";
    s.textContent = `
      .dc-float .dc-card { min-width: calc(var(--side-w) - var(--sp-6)); padding: var(--sp-3) var(--sp-4);
        border: var(--hairline) solid var(--line); border-radius: var(--r-chip); background: var(--island); box-shadow: var(--shadow-pop); }
      .dc-float .dc-h { display: flex; align-items: center; gap: var(--gap); margin-bottom: var(--sp-2); }
      .dc-float .dc-i { display: grid; place-items: center; color: var(--ink-3); }
      .dc-float .dc-i svg { width: var(--icon); height: var(--icon); }
      .dc-float .dc-t { font-size: var(--t-body); font-weight: 600; color: var(--ink); }
      .dc-float .dc-r { display: flex; justify-content: space-between; gap: var(--sp-3); font-size: var(--t-meta); line-height: var(--lh-ui); }
      .dc-float .dc-k { color: var(--ink-3); }
      .dc-float .dc-v { color: var(--ink-2); font-family: var(--mono); }
      .dc-float .dc-f { margin-top: var(--sp-2); color: var(--ink-3); font-size: var(--t-meta); }
    `;
    document.head.appendChild(s);
  }
})();
