/* Anselm 原语 C2 · C3 — 键值叶子两式（同域一文件，共用块模型 + 内生编辑）：
   · <an-field label hint value editable editor>  键值大行：label + 值；值在受约束 1fr 列内换行/截断，绝不溢出/重叠/挤扁 label。自适应高度（贴内容）。
   · <an-kv rows mono wrap>                        紧凑定义列表：值右贴边；【过长自动换行】（per-row 自检），不溢出不重叠。
   块模型：列轨 = [key 内容宽 minmax(0,auto) | value 受约束 minmax(0,1fr) | 编辑槽 auto]，每槽 min-width:0 → 长值在自己列消化。
   编辑是【内生】能力且【与标题一致】：值【原地】变 contenteditable（同字号/同盒/同位置，零偏移、不改高），尾槽铅笔→✓/✕；
     Enter/✓/失焦提交、Esc/✕/空值还原。枚举值仍用 <an-dropdown>（离散选择）。Field 派 'an-field-change'；KV 派 'an-kv-change'。done 一次性守卫。 */
(function () {
  function normRow(r) {
    if (Array.isArray(r)) return { key: r[0], value: r[1], editable: false };
    return {
      key: (r && r.key) != null ? r.key : "",
      value: r ? r.value : "",
      editable: !!(r && r.editable),
      editor: (r && r.editor) || "input",
      options: (r && r.options) || [],
    };
  }

  // 内生就地编辑（自由文本）：值槽原地 contenteditable，同盒同字号。返回 finish(commit) 供尾槽 ✓/✕ 调用。done 一次性。
  // realVal=真值（显示为 — 占位时编辑前清空）；commit(text) 写回+重渲+派事件；取消/未改→host._render()。onState(editing) 切尾槽铅笔↔✓✕。
  function editText(host, valueEl, realVal, commit, onState) {
    const orig = realVal == null ? "" : String(realVal);
    valueEl.textContent = orig;
    let done = false;
    valueEl.setAttribute("contenteditable", "plaintext-only");
    valueEl.classList.add("editing");
    if (onState) onState(true);
    const sel = window.getSelection();
    // 只给光标（落到值末尾），不全选——避免蓝色选区，把编辑权交给用户
    if (sel) { const r = document.createRange(); r.selectNodeContents(valueEl); r.collapse(false); sel.removeAllRanges(); sel.addRange(r); }
    valueEl.focus();
    const finish = (ok) => {
      if (done) return; done = true;
      valueEl.removeEventListener("keydown", onKey); valueEl.removeEventListener("blur", onBlur);
      valueEl.removeAttribute("contenteditable"); valueEl.classList.remove("editing");
      const text = (valueEl.textContent || "").trim();
      if (ok && text !== orig.trim()) commit(text);
      else host._render();
    };
    const onKey = (ev) => {
      if (ev.key === "Escape") { ev.preventDefault(); finish(false); }
      else if (ev.key === "Enter") { ev.preventDefault(); finish(true); }
    };
    const onBlur = () => finish(true);
    valueEl.addEventListener("keydown", onKey);
    valueEl.addEventListener("blur", onBlur);
    return finish;
  }

  // 枚举值就地选择：换入 <an-dropdown>。done 一次性。
  function editSelect(host, valueEl, rec, commit) {
    const wrap = document.createElement("span"); wrap.className = "edit";
    let done = false;
    const finish = (ok, value) => { if (done) return; done = true; document.removeEventListener("pointerdown", onDoc, true); if (ok) commit(value); else host._render(); };
    const dd = document.createElement("an-dropdown");
    dd.options = (rec.options || []).map((o) => (typeof o === "string" ? { value: o, label: o } : o));
    dd.value = rec.value;
    dd.addEventListener("an-change", (ev) => finish(true, ev.detail.value));
    dd.addEventListener("keydown", (ev) => { if (ev.key === "Escape") { ev.preventDefault(); finish(false); } });
    const onDoc = (ev) => {
      if (!wrap.isConnected) { finish(false); return; }
      const path = ev.composedPath ? ev.composedPath() : [ev.target];
      if (path.includes(valueEl) || path.includes(wrap) || path.some((n) => n.classList && n.classList.contains("an-float"))) return;
      finish(false);
    };
    document.addEventListener("pointerdown", onDoc, true);
    wrap.appendChild(dd); valueEl.replaceWith(wrap);
  }

  // 编辑尾槽 = <an-edit-affordance>（铅笔→✓/✕ 三连钮收口到该原语，含 focus-安全 mousedown + accent 保存）；本处只给定位类 .acts。
  function actsHtml() { return `<an-edit-affordance class="acts"></an-edit-affordance>`; }
  /* .acts = an-edit-affordance 的【绝对浮层定位】壳（不占网格列、不偷值宽）；皮肤/三钮在 an-edit-affordance；揭示可见性由各父 hover/focus/editing 规则控（见 AnField/AnKv css）。 */
  const ACTS_CSS = `
    .acts { position: absolute; top: 50%; right: var(--pad-row); transform: translateY(-50%); z-index: 1; }
    .v.editing { outline: none; box-shadow: inset 0 0 0 var(--hairline) var(--line-strong); border-radius: var(--r-tag); background: var(--island); cursor: text; }
  `;

  class AnField extends window.AnElement {
    static tag = "an-field";
    static observed = ["label", "hint", "value", "editable", "editor", "wrap"];
    static css = `
      :host { display: block; }
      /* 块模型 + 自适应高度（贴内容、不留空白）：[label 内容宽 | value 满 1fr 列]，编辑尾槽绝对浮层不偷值宽（短值单行、长值才换行） */
      .field {
        position: relative; display: grid; grid-template-columns: minmax(0, auto) minmax(0, 1fr); align-items: baseline; column-gap: var(--sp-4);
        padding: var(--sp-2) var(--pad-row); border-radius: var(--r-btn); transition: background var(--d-fast);
      }
      :host(:hover) .field, :host([editable]:focus-within) .field { background: var(--island-3); }
      .l { min-width: 0; align-self: baseline; }
      .k { min-width: 0; font-size: var(--t-body); color: var(--ink); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      .hint { min-width: 0; font-size: var(--t-meta); color: var(--ink-3); line-height: var(--lh-ui); margin-top: calc(var(--grid) / 2); overflow-wrap: anywhere; }
      .c { min-width: 0; display: block; }
      .v { min-width: 0; display: block; font-size: var(--t-body); color: var(--ink-2); white-space: normal; overflow-wrap: anywhere; }
      /* 揭示 affordance：hover/focus 或编辑中才显（默认藏）；:host .acts(0,2,0) 压过 affordance :host(0,1,0) */
      :host .acts { display: none; }
      :host([editable]:hover) .acts, :host([editable]:focus-within) .acts, :host .acts[editing] { display: inline-flex; }
      ${ACTS_CSS}
    `;

    set options(v) { this._options = Array.isArray(v) ? v : []; }
    get options() { return this._options || []; }

    render() {
      const e = window.anEsc;
      const valAttr = this.attr("value");
      const hasValueAttr = valAttr != null;
      const editableText = this.has("editable") && hasValueAttr;
      const hint = this.attr("hint") ? `<div class="hint">${e(this.attr("hint"))}</div>` : "";
      const label = e(this.attr("label", ""));
      const control = hasValueAttr ? `<span class="v">${e(valAttr === "" ? "—" : valAttr)}</span>` : `<slot></slot>`;
      const acts = editableText ? actsHtml() : "";
      return `<div class="field"><div class="l"><div class="k">${label}</div>${hint}</div><div class="c">${control}</div>${acts}</div>`;
    }

    hydrate() {
      this._editing = false;  // 每次重渲解锁（编辑收尾必经重渲）——配合 _startEdit 守卫挡快速双击
      const aff = this.$(".acts"); if (!aff) return;   // 三连钮收口 an-edit-affordance：铅笔→start / ✓→commit / ✕→abort
      aff.addEventListener("an-edit-start", () => this._startEdit());
      aff.addEventListener("an-edit-commit", () => this._finish && this._finish(true));
      aff.addEventListener("an-edit-abort", () => this._finish && this._finish(false));
    }
    _startEdit() {
      if (this._editing) return;  // 守卫：编辑中再触发不重入（否则两套 editText 监听器抢同一 .v、收尾互踩）
      const vEl = this.$(".v"), aff = this.$(".acts"); if (!vEl) return;
      const commit = (value) => { this.setAttribute("value", value); this.emit("an-field-change", { label: this.attr("label"), value }); };
      if ((this.attr("editor") || "input") === "select") { editSelect(this, vEl, { value: this.attr("value"), options: this._options || [] }, commit); return; }
      this._editing = true;
      this._finish = editText(this, vEl, this.attr("value"), commit, (on) => aff && aff.toggleAttribute("editing", on));
    }
  }
  window.AnElement.define(AnField);

  class AnKv extends window.AnElement {
    static tag = "an-kv";
    static observed = ["rows", "mono", "wrap"];
    static css = `
      :host { display: block; }
      .list { display: flex; flex-direction: column; }
      /* 块模型：[key 内容宽 | value 满 1fr 列]，编辑尾槽绝对浮层不偷值宽；value 右贴边单行，【溢出自检后逐行转多行左对齐】（.row.w 类） */
      .row {
        position: relative; display: grid; grid-template-columns: minmax(0, auto) minmax(0, 1fr); align-items: baseline;
        column-gap: var(--sp-3); min-height: var(--row); padding: var(--sp-1) var(--pad-row);
        border-radius: var(--r-btn); transition: background var(--d-fast);
      }
      .row:hover, .row.editable:focus-within { background: var(--island-3); }
      .k {
        min-width: 0; display: inline-flex; align-items: baseline; gap: var(--gap-tight);
        color: var(--ink-2); font-size: var(--t-body); line-height: var(--lh-ui); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      }
      .v {
        min-width: 0; justify-self: stretch; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
        color: var(--ink-3); font-size: var(--t-meta); line-height: var(--lh-ui);
        font-variant-numeric: tabular-nums; text-align: right;
      }
      :host([mono]) .v { font-family: var(--mono); }
      /* 过长值：转多行换行（自检命中 .row.w 或全件 [wrap]）——在 1fr 列内消化，绝不溢出/重叠 key；保持右贴边（两端对齐：key 左、value 右） */
      :host([wrap]) .row, .row.w { align-items: start; }
      :host([wrap]) .v, .row.w .v { white-space: normal; overflow: visible; text-overflow: clip; overflow-wrap: anywhere; text-align: right; }
      /* kv 行编辑槽 = an-edit-affordance（同 Field）；hover/focus/editing 才揭示（.row .acts 0,2,0 压过 affordance :host 0,1,0） */
      .row .acts { display: none; }
      .row.editable:hover .acts, .row.editable:focus-within .acts, .row .acts[editing] { display: inline-flex; }
      ${ACTS_CSS}
    `;

    get rows() { return this._data(); }
    set rows(v) { this._rows = (Array.isArray(v) ? v : []).map(normRow); if (this.isConnected) this._render(); }
    attributeChangedCallback(name) { if (name === "rows") this._rows = null; if (this.isConnected) this._render(); }
    _data() {
      if (!this._rows) {
        let raw = [];
        try { raw = JSON.parse(this.attr("rows", "[]")); } catch (_) { raw = []; }
        this._rows = (Array.isArray(raw) ? raw : []).map(normRow);
      }
      return this._rows;
    }

    render() {
      const e = window.anEsc;
      const body = this._data().map((r, i) => {
        const v = r.value == null || r.value === "" ? "—" : r.value;
        const key = `<span class="k"><span class="kt">${e(r.key)}</span></span>`;
        const acts = r.editable ? actsHtml() : "";
        return `<div class="row${r.editable ? " editable" : ""}" data-i="${i}">${key}<span class="v">${e(v)}</span>${acts}</div>`;
      }).join("");
      return `<div class="list">${body}</div>`;
    }

    hydrate() {
      this._editing = false;  // 每次重渲解锁（编辑收尾必经重渲）——配合 start 守卫挡快速双击
      // 过长值自检 → 逐行转多行（自适应换行）：rAF 等布局后量 scrollWidth，超列宽即给该行加 .w
      this._autowrap();
      this.$$('.row.editable').forEach((row) => {
        const i = Number(row.dataset.i);
        const aff = row.querySelector(".acts");   // 该行就地编辑三连钮（an-edit-affordance）
        const start = () => {
          if (this._editing) return;  // 守卫：编辑中再触发不重入（含同行双击）
          const vEl = row.querySelector(".v"), rec = this._rows[i];
          const commit = (value) => this._commit(i, value);
          if (rec.editor === "select") { editSelect(this, vEl, rec, commit); return; }
          this._editing = true;
          this._finish = editText(this, vEl, rec.value, commit, (on) => aff && aff.toggleAttribute("editing", on));
        };
        if (aff) {
          aff.addEventListener("an-edit-start", start);
          aff.addEventListener("an-edit-commit", () => this._finish && this._finish(true));
          aff.addEventListener("an-edit-abort", () => this._finish && this._finish(false));
        }
      });
    }
    // 过长值自检 → 给该行加 .w 转多行（value scrollWidth 超列宽即溢出）。idempotent（add 不重复）；
    // 多档 setTimeout 兜底惰性 tab/段布局时机不定，确保拿到真实宽度后落地。
    _autowrap() {
      if (this.has("wrap")) return;
      const apply = () => {
        if (!this.isConnected) return false;
        if (this.getBoundingClientRect().width < 40) return false;
        this.$$(".row").forEach((row) => { const v = row.querySelector(".v"); if (v && v.scrollWidth > v.clientWidth + 1) row.classList.add("w"); });
        return true;
      };
      if (!apply()) requestAnimationFrame(apply);
      [80, 250, 600].forEach((ms) => setTimeout(apply, ms));
    }
    _commit(i, value) {
      this._rows[i] = Object.assign({}, this._rows[i], { value });
      this._render();
      this.emit("an-kv-change", { key: this._rows[i].key, value, index: i });
    }
  }
  window.AnElement.define(AnKv);
})();
