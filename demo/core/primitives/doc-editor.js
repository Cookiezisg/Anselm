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
    if (t === "callout") { const tone = b.tone === "warn" ? "warn" : "info", ic = tone === "warn" ? "error" : "info"; return `<div class="b callout ${tone}" data-t="callout"><span class="ci" contenteditable="false">${window.icon(ic)}</span><span class="bt">${b.html != null ? b.html : e(b.text || "")}</span></div>`; }
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
      /* 阅读密度对齐产品调性（与实体/各海洋同 13px 正文，非 Notion 放大）：正文 t-body + 标题阶 t-h3/t-strong/t-body */
      :host { display: block; position: relative; }
      .doc { outline: none; color: var(--ink); font-size: var(--t-body); line-height: var(--lh-doc); }
      /* 垂直节奏（best practice：标题"段前" >> "段后"——标题归属其后内容；top-only margin 免折叠歧义） */
      .b { position: relative; margin-top: var(--sp-3); min-height: calc(var(--t-body) * var(--lh-doc)); }
      .b:first-child { margin-top: 0; }

      /* 标题阶（h1 20 / h2 16 / h3 13bold）：自适应高度（去 min-height 幻影空白）、段前留白足、段后贴附引领内容 */
      .h1, .h2, .h3 { font-weight: 600; line-height: var(--lh-tight); color: var(--ink); min-height: 0; scroll-margin-top: var(--sp-12); }
      .h1 { font-size: var(--t-h3); font-weight: 700; margin-top: var(--sp-8); }
      .h2 { font-size: var(--t-strong); margin-top: var(--sp-6); }
      .h3 { font-size: var(--t-body); margin-top: var(--sp-5); }
      /* 标题"段后"：紧跟标题的块贴附标题（间距远小于段前），令标题与其内容成组 */
      .h1 + .b, .h2 + .b, .h3 + .b { margin-top: var(--sp-2); }
      /* 同型列表项之间收紧（列表内部是一组，非段落级间距） */
      .bl + .bl, .td + .td { margin-top: var(--grid); }

      /* 列表 / 待办：[行首槽 = 图标+缝 | 文本]，标记居中对齐正文首行 */
      .bl, .td { display: grid; grid-template-columns: calc(var(--icon) + var(--gap)) 1fr; align-items: start; }
      .bt { min-width: 0; }
      .mk { display: grid; place-items: center; height: calc(var(--t-body) * var(--lh-doc)); color: var(--ink-2); font-size: var(--t-body); }
      /* 待办勾选框：16px 方框 · 空=描边 / 勾=accent 实底白勾 */
      .ck { width: var(--icon); height: var(--icon); margin-top: calc((var(--t-body) * var(--lh-doc) - var(--icon)) / 2);
        display: grid; place-items: center; border-radius: var(--r-tag); box-shadow: inset 0 0 0 var(--line-2) var(--line-strong);
        color: var(--ink-on-accent); cursor: pointer; transition: background var(--d-fast), box-shadow var(--d-fast); }
      .ck svg { width: var(--icon-sm); height: var(--icon-sm); }
      .td.on .ck { background: var(--accent); box-shadow: none; }
      .td.on .bt { color: var(--ink-3); text-decoration: line-through; }

      /* 引用：左强调条 + 斜体灰 */
      blockquote.b { margin-left: 0; padding: var(--grid) 0 var(--grid) var(--sp-4);
        border-left: var(--pad-hair) solid var(--line-strong); color: var(--ink-2); font-style: italic; }

      /* 提示条（tone：info=accent / warn=warn 底色 + 同色图标） */
      .callout { display: grid; grid-template-columns: var(--icon) 1fr; align-items: start; column-gap: var(--gap);
        padding: var(--sp-3) var(--sp-4); border-radius: var(--r-chip); background: var(--accent-soft); }
      .callout.warn { background: var(--warn-soft); }
      .callout .ci { display: grid; place-items: center; height: calc(var(--t-body) * var(--lh-doc)); color: var(--accent); }
      .callout.warn .ci { color: var(--warn); }
      .callout .ci svg { width: var(--icon); height: var(--icon); }

      /* 代码块 */
      pre.code { position: relative; margin: var(--sp-3) 0; padding: var(--sp-3) var(--sp-4); border-radius: var(--r-card);
        background: var(--island-2); box-shadow: inset 0 0 0 var(--hairline) var(--line);
        font-family: var(--mono); font-size: var(--t-meta); line-height: var(--lh-prose); color: var(--ink-2); white-space: pre-wrap; overflow-wrap: anywhere; }
      pre.code .lang { position: absolute; top: var(--sp-2); right: var(--sp-3); color: var(--ink-3); font-size: var(--t-meta); }

      hr.b { border: none; border-top: var(--hairline) solid var(--line); margin-top: var(--sp-5); min-height: 0; }
      an-ref-pill { margin: 0 var(--grid); vertical-align: baseline; }
      /* 空块占位提示（仅当前聚焦的空块显示） */
      .b[data-empty]:focus::before { content: attr(data-empty); color: var(--ink-3); pointer-events: none; }

      /* 左槽块手柄（＋）：悬停某块时浮现于其左空白，点开块菜单插块 */
      .gutter { position: absolute; left: calc(-1 * (var(--icon) + var(--gap))); width: var(--icon);
        height: calc(var(--t-body) * var(--lh-doc)); display: grid; place-items: center;
        border-radius: var(--r-tag); color: var(--ink-3); opacity: 0; cursor: pointer;
        transition: opacity var(--d-fast), background var(--d-fast), color var(--d-fast); }
      .gutter.show { opacity: 1; }
      .gutter:hover { background: var(--island-3); color: var(--ink); }
      .gutter svg { width: var(--icon); height: var(--icon); }
    `;

    set blocks(v) { this._blocks = Array.isArray(v) ? v : []; if (this.isConnected) this._render(); }
    get blocks() { return this._blocks || []; }
    set mentions(v) { this._mentions = Array.isArray(v) ? v : []; }
    get mentions() { return this._mentions || []; }
    // 滚到第 i 个标题（h1/h2/h3 出现序）——供大纲 ToC 点击跳转
    scrollToHeading(i) { const h = this.$$(".h1, .h2, .h3")[i]; if (h) h.scrollIntoView({ behavior: "smooth", block: "start" }); }

    render() {
      return `<div class="doc" contenteditable="true" spellcheck="false">${(this._blocks || []).map(blockHtml).join("")}</div>`
        + `<button type="button" class="gutter" aria-label="加块" contenteditable="false">${window.icon("plus")}</button>`;
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
      // 斜杠触发块菜单
      doc.addEventListener("keydown", (ev) => {
        if (ev.key === "/") setTimeout(() => this._slash(), 0);
      });
      // @ 提及：复用地基 AnMention（contenteditable 上 @→边打边滤→内联插 ref-pill；与 composer 同源、不再各抄一份）
      this._mention = window.AnMention.attach(doc, {
        mentions: () => this._mentions || [],
        namespace: "doc-at",
        getSelection: () => (this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection()),
      });
      // 左槽块手柄：悬停某块 → 手柄移到该块左侧并浮现；离开整个编辑器才隐
      const handle = this.$(".gutter");
      if (handle) {
        doc.addEventListener("pointerover", (ev) => {
          const b = ev.target.closest && ev.target.closest(".b");
          if (!b) return;
          const hr = this.getBoundingClientRect(), br = b.getBoundingClientRect();
          handle.style.top = (br.top - hr.top) + "px";
          handle.classList.add("show");
          this._handleBlock = b;
        });
        this.addEventListener("pointerleave", () => handle.classList.remove("show"));
        handle.addEventListener("click", () => {
          const block = this._handleBlock; if (!block) return;
          window.AnMenu.open(handle, {
            items: SLASH, placement: "bottom", align: "start", namespace: "doc-add",
            onPick: (type) => { type === "mention" ? this._mention.pick(this._addBelow(block, "p")) : this._addBelow(block, type); },
          });
        });
      }
    }

    // 在某块之后插入新块并落焦（左槽 ＋）；返回新块（divider 后补一个空段）
    _addBelow(block, type) {
      const tmp = document.createElement("div");
      tmp.innerHTML = blockHtml({ type, text: "" });
      const nb = tmp.firstElementChild;
      if (type !== "divider") nb.setAttribute("data-empty", PLACEHOLDER[type] || "");
      block.after(nb);
      if (type === "divider") { const p = document.createElement("p"); p.className = "b"; p.setAttribute("data-t", "p"); p.setAttribute("data-empty", PLACEHOLDER.p); nb.after(p); this._caretEnd(p); return p; }
      this._caretEnd(nb.querySelector(".bt, code") || nb);
      return nb;
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
        onPick: (type) => { this._stripTrailing(block, "/"); type === "mention" ? this._mention.pick(block) : this._applyBlock(block, type); },
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

    // @ 提及全套（caret 探测 / @query 删插 / picker）已上提到地基 AnMention（core/primitives/mention.js），见 hydrate 的 attach + _slash/gutter 的 this._mention.pick。

    _openCard(pill) {
      this._hovered = pill;
      const kind = pill.getAttribute("kind"), id = pill.getAttribute("id"), label = pill.getAttribute("label");
      const FALLBACK = { doc: { label: "文档", icon: "doc" } };   // 纯提及 kind（非 9 实体）补标签/图标
      const ent = (window.ENTITY_KINDS || {})[kind] || FALLBACK[kind] || {};
      const m = (this._mentions || []).find((x) => x.id === id) || {};   // 富信息源：mentions 自带 desc
      const card = `<div class="dc-card">`
        + `<div class="dc-h"><span class="dc-i">${window.icon(ent.icon || kind)}</span>`
        + `<span class="dc-tt"><div class="dc-t">${e(label)}</div><div class="dc-kind">${e(ent.label || kind)}</div></span></div>`
        + (m.desc ? `<div class="dc-desc">${e(m.desc)}</div>` : "")
        + `<div class="dc-r"><span class="dc-k">ID</span><span class="dc-v">${e(id)}</span></div>`
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
      .dc-float .dc-card { min-width: calc(var(--side-w) - var(--sp-4)); max-width: var(--side-w); padding: var(--sp-3) var(--sp-4);
        border-radius: var(--r-chip); background: var(--island); box-shadow: inset 0 0 0 var(--hairline) var(--line), var(--shadow-pop); }
      .dc-float .dc-h { display: flex; align-items: center; gap: var(--gap); }
      .dc-float .dc-i { display: grid; place-items: center; flex: none; width: var(--ctl-sm); height: var(--ctl-sm);
        border-radius: var(--r-tag); background: var(--island-3); color: var(--ink-2); }
      .dc-float .dc-i svg { width: var(--icon); height: var(--icon); }
      .dc-float .dc-tt { min-width: 0; }
      .dc-float .dc-t { font-size: var(--t-body); font-weight: 600; color: var(--ink); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
      .dc-float .dc-kind { font-size: var(--t-meta); color: var(--ink-3); line-height: var(--lh-ui); }
      .dc-float .dc-desc { margin-top: var(--sp-2); font-size: var(--t-meta); line-height: var(--lh-ui); color: var(--ink-2); }
      .dc-float .dc-r { display: flex; justify-content: space-between; gap: var(--sp-3); margin-top: var(--sp-2); font-size: var(--t-meta); line-height: var(--lh-ui); }
      .dc-float .dc-k { color: var(--ink-3); }
      .dc-float .dc-v { color: var(--ink-2); font-family: var(--mono); }
      .dc-float .dc-f { margin-top: var(--sp-2); padding-top: var(--sp-2); border-top: var(--hairline) solid var(--line); color: var(--ink-3); font-size: var(--t-meta); }
    `;
    document.head.appendChild(s);
  }
})();
