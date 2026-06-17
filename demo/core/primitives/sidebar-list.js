/* Anselm 原语 C5 — <an-sidebar-list>（复合·左岛 rail 的真正操作件）。
   整条侧栏 = 一个模版：New / 过滤 / 分组标签 / 类型头 / 实体行 全部走同一 Row 三列网格，
   行首槽（--lead）结构共享 → New 的 + 、过滤的 🔍、类型图标、实体点 永远对齐（不靠手量）。
   why：模型是 groups→types→rows 的递归结构，attr 表达不了 → 走 model 属性注入（同 <an-sidebar>）。
        实体行用 <an-row depth=1> 标签拼（运行时解析，作者期无需 an-row 已注册）；
        sliders 菜单走命令式 window.AnMenu.attach（菜单是 body 顶层浮层，逃 shadow 裁剪）。
   model：{ newLabel, filterPlaceholder, menuItems?, groups:[{label?, open?, types:[{icon,label,count,open,rows:[{id,label,dot,meta,…}]}]}] }
        group 有 label → 可折叠大组（chat 式头，open 默认 true）；无 label → 直接平铺其 types（兼容单组）。
   动作：an-new（点 New）· an-filter{value}（域内垂搜）· an-select{id}（选实体行）。 */
(function () {
  class AnSidebarList extends window.AnElement {
    static tag = "an-sidebar-list";
    static css = `
      :host { display: flex; flex-direction: column; }

      /* New / 过滤 共享 Row 三列网格 → + / 🔍 与实体图标同列同心（行首槽 --lead） */
      .head-row {
        display: grid; grid-template-columns: var(--lead) 1fr auto; align-items: center; column-gap: var(--gap);
        height: var(--row); padding: 0 var(--pad-row); border-radius: var(--r-btn);
        color: var(--ink-2); font-size: var(--t-body);
      }
      .lead { width: var(--lead); height: var(--lead); display: grid; place-items: center; color: var(--ink-3); }
      .lead svg { display: block; width: var(--icon); height: var(--icon); }

      /* New 行：整行可点的左对齐按钮 */
      .new { width: 100%; text-align: left; cursor: pointer; transition: background var(--d-fast), color var(--d-fast); }
      .new:hover { background: var(--island-3); color: var(--ink); }
      .new .label { min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

      /* 过滤行：内联输入（域内垂搜）+ 尾部 sliders 锚（排序/显示菜单） */
      .filter { cursor: default; }
      .input {
        width: 100%; min-width: 0; border: var(--zero); background: none;
        font: inherit; font-size: var(--t-body); color: var(--ink);
      }
      .input::placeholder { color: var(--ink-3); }
      .input:focus { outline: none; }
      .sliders {
        display: grid; place-items: center; width: var(--trail); height: var(--trail);
        color: var(--ink-3); border-radius: var(--r-tag); cursor: pointer;
        transition: background var(--d-fast), color var(--d-fast);
      }
      .sliders svg { display: block; width: var(--icon-sm); height: var(--icon-sm); }
      .sliders:hover { background: var(--island-3); color: var(--ink); }

      /* 树主体 */
      .tree { display: flex; flex-direction: column; min-height: 0; }

      /* 大组：可折叠分组（chat「Pinned/Recents」式头——整行可点、无图标占位、尾 chevron 旋转）。
         比 type 头更轻：小字灰、计数贴右、箭头收尾；组内才是 type（kind）层。 */
      .grp-sec { margin-bottom: var(--sp-1); }
      .grp-head {
        display: flex; align-items: center; gap: var(--gap-tight); width: 100%; height: var(--ctl); padding: 0 var(--pad-row);
        border-radius: var(--r-btn); font-size: var(--t-meta); font-weight: 600; color: var(--ink-3);
        transition: background var(--d-fast);
      }
      .grp-head:hover { background: var(--island-3); }
      .grp-cnt { color: var(--ink-3); font-weight: 500; }
      .grp-chev { margin-left: auto; display: inline-grid; place-items: center; color: var(--ink-3); transition: transform var(--d-mid) var(--ease-spring); }
      .grp-chev svg { width: var(--icon-sm); height: var(--icon-sm); }
      .grp-sec.collapsible.open > .grp-head .grp-chev { transform: rotate(90deg); }
      .grp-sec.collapsible:not(.open) > .grp-body { display: none; }

      /* 类型块：折叠关 → 隐藏其行 */
      .type:not(.open) > .rows { display: none; }
      /* 嵌套树枝（documents 文档树）：行包裹 .nw，折叠关 → 隐藏其子行容器 */
      .nw:not(.open) > .rows { display: none; }
    `;

    render() {
      const e = window.anEsc;
      const m = this._model || {};
      const groups = (m.groups || []).map((g, gi) => this._groupHtml(g, gi)).join("");
      // no-new：隐藏 New 行（如 scheduler——工作流不在此新建，仅搜索 + 选中）
      const newRow = this.has("no-new") ? "" : `
        <button type="button" class="head-row new">
          <span class="lead">${window.icon("plus")}</span>
          <span class="label">${e(m.newLabel || "New")}</span>
          <span></span>
        </button>`;
      return `${newRow}
        <div class="head-row filter">
          <span class="lead">${window.icon("search")}</span>
          <input class="input" type="text" placeholder="${e(m.filterPlaceholder || "")}">
          <button type="button" class="sliders" title="显示选项">${window.icon("sliders")}</button>
        </div>
        <div class="tree">${groups}</div>`;
    }

    // 分组：有标题 → 可折叠大组（chat 式头 + 计数 + chevron）；无标题 → 直接平铺各类型块（兼容单组用法）
    _groupHtml(g) {
      const e = window.anEsc;
      const types = (g.types || []).map((t) => this._typeHtml(t)).join("");
      if (!g.label) return types;
      const open = g.open !== false;
      const total = (g.types || []).reduce((s, t) => s + (t.rows ? t.rows.length : 0), 0);
      return `<div class="grp-sec collapsible${open ? " open" : ""}">`
        + `<button type="button" class="grp-head tog"><span class="grp-lbl">${e(g.label)}</span><span class="grp-cnt">${total}</span><span class="grp-chev">${window.icon("chevr")}</span></button>`
        + `<div class="grp-body">${types}</div></div>`;
    }

    // 类型块：有标题/图标 → 类型头（可折叠 Row，meta=计数）+ 缩进一级的行；无标题无图标 → headless（无头，行直接铺·depth 0）
    // headless 用于：scheduler（单类型无需大标题）· documents（文件夹内文档树根）。
    _typeHtml(t) {
      const e = window.anEsc;
      const headless = !t.label && !t.icon;
      const rows = (t.rows || []).map((r) => this._rowHtml(r, headless ? 0 : 1)).join("");
      if (headless) return `<div class="type open"><div class="rows">${rows}</div></div>`;
      const head =
        `<an-row class="type-head"` +
        (t.icon ? ` icon="${e(t.icon)}"` : "") +
        ` label="${e(t.label || "")}" collapsible${t.open ? " open" : ""}` +
        (t.count != null ? ` meta="${e(String(t.count))}"` : "") +
        ` passive></an-row>`;
      return `<div class="type${t.open ? " open" : ""}">${head}<div class="rows">${rows}</div></div>`;
    }

    // 实体行（可递归树枝）：depth 缩进、有 children → collapsible + 嵌套 .rows（fold on an-toggle）；行尾 ＋(add)/⋯(more) 按 host attr
    _rowHtml(r, depth) {
      const e = window.anEsc;
      if (depth == null) depth = 1;
      const has = r.children && r.children.length;
      const open = r.open !== false;
      let a = ` depth="${depth}"`;
      if (r.id != null) a += ` data-id="${e(r.id)}"`;
      if (r.dot) a += ` dot="${e(r.dot)}"`;
      else if (r.icon) a += ` icon="${e(r.icon)}"`;
      if (r.label != null) a += ` label="${e(r.label)}"`;
      if (r.hint) a += ` hint="${e(r.hint)}"`;
      if (r.meta != null && r.meta !== "") a += ` meta="${e(String(r.meta))}"`;
      if (r.selected) a += ` selected`;
      if (has) a += ` collapsible${open ? " open" : ""}`;   // 有子 → 可折叠树枝（点 chevron 折叠、点标题选中）
      const addBtn = this.has("add") && r.id != null
        ? `<an-button slot="actions" variant="icon" icon="plus" class="row-add" data-add="${e(r.id)}"></an-button>` : "";
      const moreBtn = this.has("more") && r.id != null
        ? `<an-button slot="actions" variant="icon" icon="more" class="row-more" data-more="${e(r.id)}"></an-button>` : "";
      const rowEl = `<an-row class="entity${has ? " branch" : ""}"${a}>${addBtn}${moreBtn}</an-row>`;
      const kids = has ? `<div class="rows">${r.children.map((c) => this._rowHtml(c, depth + 1)).join("")}</div>` : "";
      return `<div class="nw${open ? " open" : ""}">${rowEl}${kids}</div>`;
    }

    hydrate() {
      // New（no-new 时无此行）
      const newBtn = this.$(".new"); if (newBtn) newBtn.addEventListener("click", () => this.emit("an-new"));

      // 域内垂搜：原生 input → 实时过滤本 rail 行（隐藏未命中 · 命中类型/组强制展开）+ 对外派 'an-filter'
      const input = this.$(".input");
      input.addEventListener("input", () => { this._applyFilter(input.value.trim().toLowerCase()); this.emit("an-filter", { value: input.value }); });

      // 排序/显示 sliders 菜单（命令式浮层，body 顶层逃裁剪）
      const sliders = this.$(".sliders");
      if (window.AnMenu) {
        window.AnMenu.attach(sliders, {
          compact: true,
          namespace: "sidebar-menu",
          items: (this._model && this._model.menuItems) || this._defaultMenuItems(),
          onPick: (value, item) => this.emit("an-menu", { value, item }),
        });
      }

      // 大组折叠：点组头 → 切本 .grp-sec open（chat 式整行可点）
      this.$$(".grp-head.tog").forEach((h) => {
        h.addEventListener("click", () => { const sec = h.closest(".grp-sec"); if (sec) sec.classList.toggle("open"); });
      });

      // 类型头折叠：点头 → 切本类型块 open
      this.$$(".type-head").forEach((h) => {
        h.addEventListener("click", () => {
          const block = h.parentNode;
          const open = block.classList.toggle("open");
          h.toggleAttribute("open", open);
        });
      });

      // 实体行选中：<an-row> 派发 an-select → 收敛单选 + 转发本组的 an-select{id}
      this.$$(".entity").forEach((row) => {
        row.addEventListener("an-select", () => {
          this.$$(".entity").forEach((x) => x.removeAttribute("selected"));
          row.setAttribute("selected", "");
          this.emit("an-select", { id: row.dataset.id });
        });
      });

      // 树枝折叠：点 chevron（an-row 派 an-toggle）→ 折叠本 .nw（documents 文档树）
      this.$$(".entity.branch").forEach((row) => {
        row.addEventListener("an-toggle", () => { const nw = row.closest(".nw"); if (!nw) return; const open = nw.classList.toggle("open"); row.toggleAttribute("open", open); });
      });

      // 行 ＋ 动作（add）：点 → 派 an-row-add{id, anchor}（如 documents 在此节点下加子文档）
      this.$$(".row-add").forEach((b) => {
        b.addEventListener("click", (ev) => { ev.stopPropagation(); this.emit("an-row-add", { id: b.dataset.add, anchor: b }); });
      });
      // 行 … 动作：点 → 派 an-row-more{id, anchor}（feature 据此开该实体的动作菜单）
      this.$$(".row-more").forEach((b) => {
        b.addEventListener("click", (ev) => { ev.stopPropagation(); this.emit("an-row-more", { id: b.dataset.more, anchor: b }); });
      });
    }

    // 实时过滤（支持嵌套树）：① 逐行按 label+meta 显隐其 .nw 包裹；② 命中行回填祖先链（可见 + 展开）；③ 空 type/组隐藏
    _applyFilter(q) {
      const rows = this.$$(".entity");
      const hayOf = (row) => ((row.getAttribute("label") || "") + " " + (row.getAttribute("meta") || "")).toLowerCase();
      rows.forEach((row) => { const nw = row.closest(".nw") || row; nw.style.display = (!q || hayOf(row).includes(q)) ? "" : "none"; });
      if (q) rows.forEach((row) => {
        if (!hayOf(row).includes(q)) return;
        let nw = row.closest(".nw");
        while (nw) { nw.style.display = ""; nw.classList.add("open"); const r = nw.querySelector(":scope > .entity"); if (r) r.setAttribute("open", ""); nw = nw.parentElement && nw.parentElement.closest(".nw"); }
        const type = row.closest(".type"); if (type) type.classList.add("open");
        const sec = row.closest(".grp-sec"); if (sec) sec.classList.add("open");
      });
      this.$$(".type").forEach((type) => { const vis = [...type.querySelectorAll(".nw")].some((n) => n.style.display !== "none"); type.style.display = (q && !vis) ? "none" : ""; });
      this.$$(".grp-sec").forEach((sec) => { const vis = [...sec.querySelectorAll(".nw")].some((n) => n.style.display !== "none"); sec.style.display = (q && !vis) ? "none" : ""; });
    }

    // 排序 / 显示 默认项（域内垂搜的伴随控制）
    _defaultMenuItems() {
      return [
        { type: "label", label: "Sort" },
        { label: "Recently updated", value: "updated", checked: true },
        { label: "Name", value: "name" },
        { label: "Runs", value: "runs" },
        { type: "label", label: "Display" },
        { label: "Show versions", value: "versions", checked: true },
        { label: "Show status dots", value: "status", checked: true },
      ];
    }

    set model(v) { this._model = v; if (this.isConnected) this._render(); }
    get model() { return this._model; }
  }
  window.AnElement.define(AnSidebarList);
})();
