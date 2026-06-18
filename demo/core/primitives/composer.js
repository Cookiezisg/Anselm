/* Anselm 原语 🧩 — <an-composer>。chat 输入条：多行 contenteditable + @ 提及内联药丸 + 附件 chip + send/stop。
   why 新建：现有 an-input[multiline] 只是裸 textarea，缺 @picker/附件/send 态——是 chat 海洋唯一必须新建的件。
   复用底座：AnMention（@ → 边打边滤 picker → 内联 an-ref-pill，与 doc-editor 同源）· an-button（工具钮/send/stop）· an-ref-pill（提及药丸）· icons。
   能力：① 多行自增高 contenteditable（max 6 行后内滚）；② 「@」起会话 or 工具栏 @ 钮开 picker → 内联插药丸；③ 附件 chip 行（可删）；
        ④ Enter 发送 / Shift+Enter 换行；⑤ generating 态 send↔stop 互换（纯 CSS，不重渲、不抹输入）。
   数据：.mentions=[{kind,id,label,desc}]（@picker 池）· .attachments=[{name,icon?}]（附件 chip）· generating 属性切发送/停止态。
   交互对外（composed）：an-send{text,html,refs,attachments} · an-stop · an-attach（附件钮，宿主可挂真选文件；demo 自插占位 chip）。 */
(function () {
  const e = window.anEsc;

  class AnComposer extends window.AnElement {
    static tag = "an-composer";
    static observed = [];   // generating 走 :host([generating]) CSS 实时响应、不触发重渲（保住 editable 输入不被抹）
    static css = `
      :host { display: block; }
      .bar { max-width: var(--w-content); margin: 0 auto; padding: var(--sp-2) var(--sp-6) var(--sp-4); }
      /* 输入盒：圆角面 + inset 描边环（半透 border 圆角会叠灰尖，用 inset 均匀）；聚焦叠 accent 光环 */
      .box {
        border-radius: var(--r-card); background: var(--island);
        box-shadow: inset 0 0 0 var(--hairline) var(--line);
        transition: box-shadow var(--d-fast);
      }
      .box:focus-within { box-shadow: inset 0 0 0 var(--hairline) var(--accent-line), 0 0 0 var(--focus-ring) var(--accent-soft); }

      /* 附件 chip 行（空则整行塌陷） */
      .chips { display: flex; flex-wrap: wrap; gap: var(--gap-tight); padding: var(--sp-2) var(--sp-3) 0; }
      .chips:empty { display: none; }
      .chip {
        display: inline-flex; align-items: center; gap: var(--gap-tight); height: var(--badge-h);
        padding: 0 var(--grid) 0 var(--badge-pad-x); border-radius: var(--r-tag);
        background: var(--island-3); color: var(--ink-2); font-size: var(--t-meta);
      }
      .chip .ci { display: grid; place-items: center; color: var(--ink-3); }
      .chip .ci svg { width: var(--icon-sm); height: var(--icon-sm); }
      .chip .x { display: grid; place-items: center; width: var(--icon); height: var(--icon); border-radius: var(--r-tag); color: var(--ink-3); cursor: pointer; }
      .chip .x:hover { background: var(--island-4); color: var(--ink); }
      .chip .x svg { width: var(--icon-sm); height: var(--icon-sm); }

      /* contenteditable 编辑区：多行自增、超 6 行内滚（无 native gutter）；空态占位 */
      .edit {
        outline: none; padding: var(--sp-3) var(--sp-3) var(--sp-2);
        font-size: var(--t-body); line-height: var(--lh-ui); color: var(--ink);
        min-height: calc(var(--t-body) * var(--lh-ui)); max-height: calc(var(--row) * 6);
        overflow-y: auto; overflow-wrap: anywhere; scrollbar-width: none; -ms-overflow-style: none;
      }
      .edit::-webkit-scrollbar { width: var(--zero); }
      .edit:empty::before { content: attr(data-ph); color: var(--ink-3); pointer-events: none; }
      an-ref-pill { margin: 0 var(--grid); vertical-align: baseline; }

      /* 工具栏行：@ / 附件 钮（左）· 提示 + 发送/停止（右） */
      .tools { display: flex; align-items: center; gap: var(--grid); padding: var(--grid) var(--sp-2) var(--sp-2) var(--sp-2); }
      .tools .grow { flex: 1; }

      /* generating：send↔stop 互换（纯 CSS） */
      :host(:not([generating])) .t-stop { display: none; }
      :host([generating]) .t-send { display: none; }
    `;

    set mentions(v) { this._mentions = Array.isArray(v) ? v : []; }
    get mentions() { return this._mentions || []; }
    set attachments(v) { this._atts = Array.isArray(v) ? v : []; if (this.isConnected) this._renderChips(); }
    get attachments() { return this._atts || []; }
    // 焦点入编辑区（feature 切会话后聚焦）
    focus() { const ed = this.$(".edit"); if (ed) ed.focus(); }
    // 清空输入（feature 发送后 / 切会话）
    clear() { const ed = this.$(".edit"); if (ed) ed.innerHTML = ""; this._atts = []; this._renderChips(); }

    render() {
      // 无占位文字 / 无 hint / send·stop 纯图标——干净空条（Enter 发送 / Shift+Enter 换行靠键位约定，不写字）
      const ph = e(this.attr("placeholder", ""));
      return `<div class="bar"><div class="box">
        <div class="chips"></div>
        <div class="edit" contenteditable="true" spellcheck="false" data-ph="${ph}"></div>
        <div class="tools">
          <an-button class="t-at" variant="icon" icon="at-sign">提及</an-button>
          <an-button class="t-att" variant="icon" icon="paperclip">附件</an-button>
          <span class="grow"></span>
          <an-button class="t-send" variant="primary" size="sm" icon="arrow-up" aria-label="发送"></an-button>
          <an-button class="t-stop" variant="danger" size="sm" icon="stop" aria-label="停止"></an-button>
        </div>
      </div></div>`;
    }

    hydrate() {
      const ed = this.$(".edit");
      this._renderChips();

      // @ 提及（复用地基 AnMention：「@」起会话 + 工具栏钮 pick；shadow 内取 shadowRoot 选区）
      this._mention = window.AnMention.attach(ed, {
        mentions: () => this._mentions || [],
        namespace: "composer-at",
        getSelection: () => (this.shadowRoot.getSelection ? this.shadowRoot.getSelection() : window.getSelection()),
      });
      this.$(".t-at").addEventListener("click", () => this._mention.pick(ed));

      // 附件：派 an-attach 供宿主挂真选文件；demo 自插占位 chip（无宿主也自演）
      this.$(".t-att").addEventListener("click", () => {
        this.emit("an-attach", {});
        this._addChip({ name: ["spec.md", "screenshot.png", "data.csv"][(this._atts || []).length % 3], icon: "doc" });
      });

      // Enter 发送 / Shift+Enter 换行；空态保持 :empty（清掉残留 <br>）
      ed.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" && !ev.shiftKey) { ev.preventDefault(); this._send(); }
      });
      ed.addEventListener("input", () => { if (!ed.textContent.trim() && !ed.querySelector("an-ref-pill")) ed.innerHTML = ""; });

      this.$(".t-send").addEventListener("click", () => this._send());
      this.$(".t-stop").addEventListener("click", () => this.emit("an-stop", {}));
    }

    // 附件 chip 行（命令式重绘，不动 editable）
    _addChip(att) { this._atts = (this._atts || []).concat([att]); this._renderChips(); }
    _renderChips() {
      const box = this.$(".chips"); if (!box) return;
      box.innerHTML = (this._atts || []).map((a, i) =>
        `<span class="chip"><span class="ci">${window.icon(a.icon || "doc", 12)}</span>${e(a.name || "附件")}<span class="x" data-x="${i}">${window.icon("close", 12)}</span></span>`
      ).join("");
      box.querySelectorAll(".x").forEach((x) => x.addEventListener("click", () => {
        this._atts.splice(Number(x.dataset.x), 1); this._renderChips();
      }));
    }

    // 提取纯文本（ref-pill → @label）；收集引用 + 附件，派 an-send，清空
    _plainText(ed) {
      let out = "";
      ed.childNodes.forEach((n) => {
        if (n.nodeType === 3) out += n.textContent;
        else if (n.nodeName && n.nodeName.toLowerCase() === "an-ref-pill") out += "@" + (n.getAttribute("label") || "");
        else if (n.tagName === "BR") out += "\n";
        else out += n.textContent || "";
      });
      return out;
    }
    _send() {
      if (this.has("generating")) return;
      const ed = this.$(".edit");
      const text = this._plainText(ed);
      const atts = (this._atts || []).slice();
      if (!text.trim() && !atts.length) return;
      const refs = this.$$("an-ref-pill").map((p) => ({ kind: p.getAttribute("kind"), id: p.getAttribute("id"), label: p.getAttribute("label") }));
      this.emit("an-send", { text: text, html: ed.innerHTML, refs: refs, attachments: atts });
      ed.innerHTML = ""; this._atts = []; this._renderChips();
    }
  }
  window.AnElement.define(AnComposer);
})();
