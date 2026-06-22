/* Anselm 原语 C1d — <an-row-detail open>。可展开详情行：一条 an-row（slot=row）+ 其下方详情面板（默认 slot，常放 an-kv）。
   why 内化：点行展开/收起详情是可复用能力——面板缩进对齐 row 的 label 起点（lead+gap+pad-row）、底分隔线、显隐切换全焊进皮肤；
     消费方（schema render / 任意记录列）只声明「行 + 详情内容」，不再手搓 wrapper/panel cssText + toggle 监听（去裸写）。
   交互：内层 an-row 的 an-select 冒泡到本宿主 → 切 [open] + 同步 row[selected]；再点收起。observed 留空：[open] 只驱动 CSS、不触重渲（避免重绑监听）。 */
(function () {
  class AnRowDetail extends window.AnElement {
    static tag = "an-row-detail";
    static css = `
      :host { display: block; }
      .detail {
        display: none;
        padding: var(--grid) var(--pad-row) var(--sp-3) calc(var(--lead) + var(--gap) + var(--pad-row));
        border-bottom: var(--hairline) solid var(--line);
      }
      :host([open]) .detail { display: block; }
    `;
    render() {
      return `<slot name="row"></slot><div class="detail"><slot></slot></div>`;
    }
    hydrate() {
      // an-select 自内层 an-row 冒泡上来（composed）；切显隐 + 高亮该行
      this.addEventListener("an-select", (e) => {
        // why：嵌套时子 an-select 沿 composedPath 上冒会误触外层——只认本行 [slot=row] 在更内层 an-row-detail 之前出现
        const path = e.composedPath ? e.composedPath() : [];
        const row = this.querySelector('[slot="row"]');
        for (const t of path) {
          if (t === this) break;                       // 直达本宿主，未遇本行：来源在 detail 槽内或他处，不响应
          if (t === row) { this.toggle(); return; }     // 本行先于本宿主出现：本行触发
          if (t.tagName === "AN-ROW-DETAIL") return;   // 先遇更内层 row-detail：归它处理
        }
      });
    }
    toggle(force) {
      const open = force == null ? !this.has("open") : !!force;
      this.toggleAttribute("open", open);
      const row = this.querySelector('[slot="row"]');
      if (row) row.toggleAttribute("selected", open);
    }
  }
  window.AnElement.define(AnRowDetail);
})();
