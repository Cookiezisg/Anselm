/* Anselm 原语 D5 — <an-ocean-header crumb title editable>。海洋页头：面包屑 + 大标题 + 可选 meta + 右侧动作。
   坐于海面（无卡），与正文段（白岛）分层；页头 = 你在哪（面包屑）/ 这是什么（标题）/ 附注（meta）/ 能做什么（动作）四件事，各有锚位与 token 间距。
   crumb：'|' 分隔层级串，自动插 / 分隔符。槽：slot[name=actions] 顶行右动作；slot[name=meta] meta 行。
   editable：标题【内生】就地改名——hover 现铅笔 → 点进编辑态：<h1> 本体原地变 contenteditable（保持 h2 字号/盒/位置，绝不缩成 input、零页面偏移），
     铅笔位换 ✓/✕；Enter/✓/失焦提交、Esc/✕/空值还原。派 composed 'an-title-change'{value,prev}（消费方落库）。done 一次性守卫。 */
(function () {
  class AnOceanHeader extends window.AnElement {
    static tag = "an-ocean-header";
    static observed = ["crumb", "title", "editable"];
    static css = `
      :host { display: block; }
      .oh { padding-bottom: var(--sp-6); }
      .top { display: flex; align-items: center; gap: var(--sp-3); min-height: var(--ctl); }
      .crumb {
        flex: 1; min-width: 0; display: flex; align-items: center; gap: var(--gap-tight);
        font-size: var(--t-meta); color: var(--ink-3); overflow: hidden; white-space: nowrap;
      }
      .sep { color: var(--line-strong); }
      .actions { flex: none; display: flex; align-items: center; gap: var(--sp-2); }
      .meta {
        display: flex; align-items: center; gap: var(--sp-4);
        font-size: var(--t-meta); color: var(--ink-3); flex-wrap: wrap;
      }
      ::slotted(an-badge) { height: var(--trail); }

      /* 标题行：h1（吃富余、可换行）+ 编辑动作槽（固定）。h1 字号/盒在显示与编辑态【完全一致】 */
      .title-row { display: flex; align-items: baseline; gap: var(--sp-2); margin: var(--sp-2) 0; min-width: 0; }
      /* flex:0 → 标题按内容宽（不撑满），铅笔/✓✕ 紧贴标题右边空两格（场景 B：编辑钮贴锚点文字），非推到行尾 */
      .title {
        min-width: 0; flex: 0 1 auto; overflow-wrap: anywhere;
        font-size: var(--t-h2); font-weight: 600; line-height: var(--lh-tight); letter-spacing: 0; margin: 0;
      }
      /* 视觉框 ≠ 逻辑框：竖向内距用负 margin 抵掉（不顶 crumb/meta、零竖向偏移）；横向【右侧真实占位】（margin-right:0）——框与取消/保存钮靠 title-row gap 隔开、不糊一起（左侧 -sp-2 抵掉、标题文字不右移） */
      .title.editing { outline: none; box-shadow: inset 0 0 0 var(--hairline) var(--line-strong); border-radius: var(--r-tag);
        background: var(--island); cursor: text; padding: var(--grid) var(--sp-2); margin: calc(var(--grid) * -1) 0 calc(var(--grid) * -1) calc(var(--sp-2) * -1); }
      /* 标题编辑三连钮 = an-edit-affordance（皮肤/铅笔↔✓✕ 在该原语）；这里只定位 + 揭示（hover/focus/editing 才显） */
      .t-acts { flex: none; align-self: center; }
      .title-row .t-acts { display: none; }
      .title-row:hover .t-acts, .title-row:focus-within .t-acts, .title-row .t-acts[editing] { display: inline-flex; }
    `;
    render() {
      const e = window.anEsc;
      const parts = (this.attr("crumb") || "").split("|").map((s) => s.trim()).filter(Boolean);
      const crumb = parts.length ? parts.map((c, i) => (i ? `<span class="sep">/</span>` : "") + `<span>${e(c)}</span>`).join("") : "";
      const title = this.attr("title");
      let titleEl = "";
      if (title != null) {
        const h1 = `<h1 class="title">${e(title)}</h1>`;
        titleEl = this.has("editable")
          ? `<div class="title-row"><h1 class="title">${e(title)}</h1><an-edit-affordance class="t-acts"></an-edit-affordance></div>`
          : h1;
      }
      return `<header class="oh">`
        + `<div class="top"><div class="crumb">${crumb}</div><div class="actions"><slot name="actions"></slot></div></div>`
        + titleEl
        + `<div class="meta"><slot name="meta"></slot></div>`
        + `</header>`;
    }

    hydrate() {
      const aff = this.$(".t-acts");   // 标题编辑三连钮收口 an-edit-affordance：铅笔→start / ✓→commit / ✕→abort
      if (aff) {
        aff.addEventListener("an-edit-start", () => this._beginTitleEdit());
        aff.addEventListener("an-edit-commit", () => this._finish && this._finish(true));
        aff.addEventListener("an-edit-abort", () => this._finish && this._finish(false));
      }
      this._wireCollapse();
    }

    // 滚动收起：大标题滑出顶部 → 喂 shell 左上角紧凑标题（含回顶回调）+ collapsed 切换；标题可见时收起紧凑标题。
    _wireCollapse() {
      const shell = this.closest("an-shell");
      const titleEl = this.$(".title");
      if (!shell || !titleEl || !shell.setHeadTitle || !window.IntersectionObserver) return;
      shell.setHeadTitle(this.attr("title", ""), () => titleEl.scrollIntoView({ behavior: "smooth", block: "start" }));
      if (this._io) this._io.disconnect();
      const head = parseFloat(getComputedStyle(this).getPropertyValue("--island-head")) || 44;
      this._io = new IntersectionObserver((ents) => {
        const en = ents[0]; if (!en || !shell.setHeadCollapsed) return;
        shell.setHeadCollapsed(en.intersectionRatio < 0.02);   // 大标题滑出头栏线 → 紧凑标题浮现
      }, { root: null, rootMargin: "-" + Math.round(head) + "px 0px 0px 0px", threshold: [0, 0.02, 1] });
      this._io.observe(titleEl);
    }
    disconnectedCallback() { if (this._io) { this._io.disconnect(); this._io = null; } }

    // 内生就地编辑：<h1> 本体原地 contenteditable（同字号同盒），done 一次性守卫（✓/✕ mousedown 与 blur 双触只生效一次）。
    _beginTitleEdit() {
      const h1 = this.$(".title"), acts = this.$(".t-acts"); if (!h1 || !acts) return;
      const orig = this.attr("title", "");
      let done = false;
      h1.setAttribute("contenteditable", "plaintext-only");
      h1.classList.add("editing"); acts.setAttribute("editing", "");   // affordance 切 ✓/✕ + 编辑中常显
      const sel = window.getSelection();
      // 只给光标（落到标题末尾），不全选——白底无蓝选区
      if (sel) { const r = document.createRange(); r.selectNodeContents(h1); r.collapse(false); sel.removeAllRanges(); sel.addRange(r); }
      h1.focus();
      const finish = (ok) => {
        if (done) return; done = true;
        h1.removeEventListener("keydown", onKey); h1.removeEventListener("blur", onBlur);
        const v = (h1.textContent || "").trim();
        if (ok && v && v !== orig) { this.setAttribute("title", v); this.emit("an-title-change", { value: v, prev: orig }); }
        else this._render();   // 取消 / 空标题（必填，唯一物理校验）/ 未改 → 回显
      };
      // ✓/✕ 经 an-edit-affordance 的 commit/abort 事件回调本 finish（mousedown+preventDefault 在 affordance 内、抢 h1 blur 前定调，取消优先回滚）；done 守卫兜双触
      this._finish = finish;
      const onKey = (ev) => {
        if (ev.key === "Escape") { ev.preventDefault(); finish(false); }
        else if (ev.key === "Enter") { ev.preventDefault(); finish(true); }
      };
      const onBlur = () => finish(true);
      h1.addEventListener("keydown", onKey);
      h1.addEventListener("blur", onBlur);
    }
  }
  window.AnElement.define(AnOceanHeader);
})();
