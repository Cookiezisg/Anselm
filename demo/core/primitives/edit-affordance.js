/* Anselm 原语 — <an-edit-affordance editing>。就地编辑三连钮（铅笔 → ✓/✕）单源。
   why：field / kv / ocean-header 的「值/标题原地 contenteditable + 尾槽铅笔→保存/取消」是同一微交互——
     三连钮的皮肤 + 铅笔↔✓✕ 切换 + focus-安全 mousedown 收口到本件（复用 an-button），杜绝三处各手搓 raw button 重抄 icon 钮。
   状态：attr editing —— 无 = 显铅笔；有 = 显 ✓/✕。整件【可见性】由父按 hover/focus/editing 揭示（父定位 + reveal CSS），本件只切铅笔↔✓✕。
   事件（composed）：铅笔 click → 'an-edit-start'；✓ mousedown(preventDefault) → 'an-edit-commit'；✕ mousedown(preventDefault) → 'an-edit-abort'。
     ✓/✕ 走 mousedown + preventDefault：抢在 contenteditable blur（blur=提交）之前定调——否则「取消」会被 blur 误提交（取消须优先回滚）。
   保存钮 accent：an-button 的 icon 变体无 accent-icon 态，故经 ::part(button) 给绿——本件是该 affordance 皮肤的主人，合法着色。 */
(function () {
  class AnEditAffordance extends window.AnElement {
    static tag = "an-edit-affordance";
    static observed = [];   // editing 纯 CSS（:host([editing])）实时响应，不重渲——免每切态重建 3 个 an-button
    static css = `
      :host { display: inline-flex; align-items: center; gap: var(--gap-tight);
        background: var(--island-3); border-radius: var(--r-tag); padding-left: var(--grid); }
      /* 非编辑态藏 ✓/✕、只显铅笔；编辑态藏铅笔、显 ✓/✕ */
      :host(:not([editing])) .a-save, :host(:not([editing])) .a-cancel { display: none; }
      :host([editing]) .a-edit { display: none; }
      /* 保存钮 accent（经 an-button 暴露的 part=button 着绿；本件是 affordance 皮肤主人） */
      .a-save::part(button) { color: var(--accent); }
      .a-save::part(button):hover { background: var(--accent-soft); color: var(--accent); }
    `;
    render() {
      return `<an-button class="a-edit" variant="icon" size="sm" icon="edit" aria-label="编辑"></an-button>`
        + `<an-button class="a-save" variant="icon" size="sm" icon="check" aria-label="保存"></an-button>`
        + `<an-button class="a-cancel" variant="icon" size="sm" icon="close" aria-label="取消"></an-button>`;
    }
    hydrate() {
      this.$(".a-edit").addEventListener("click", () => this.emit("an-edit-start"));
      this.$(".a-save").addEventListener("mousedown", (ev) => { ev.preventDefault(); this.emit("an-edit-commit"); });
      this.$(".a-cancel").addEventListener("mousedown", (ev) => { ev.preventDefault(); this.emit("an-edit-abort"); });
    }
  }
  window.AnElement.define(AnEditAffordance);
})();
