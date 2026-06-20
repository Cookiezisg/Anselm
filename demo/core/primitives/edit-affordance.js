/* Anselm 原语 — <an-edit-affordance editing>。就地编辑三连钮（铅笔 ↔ ✓/✕）单源——【同处（co-located）】式编辑用。
   why：标题类「文字原地 contenteditable + 文字右铅笔→保存/取消，铅笔与确认同处」是同一微交互（如 ocean-header 改名）——
     裸三连钮皮肤 + 铅笔↔✓✕ 切换 + focus-安全 mousedown 收口本件（复用 an-button），免各处手搓 icon 钮。
   注：key-value 的就地编辑（an-field/an-kv）是【分处】式（铅笔贴 key 右、✓✕ 贴 value 右），不用本件，用裸 pencil+✓✕（见 field.js EDIT_CSS）。
   状态：attr editing —— 无 = 显铅笔；有 = 显 ✓/✕。整件【可见性】由父按 hover/focus/editing 揭示（父定位 + reveal CSS），本件只切铅笔↔✓✕。
   事件（composed）：铅笔 click → 'an-edit-start'；✓ mousedown(preventDefault) → 'an-edit-commit'；✕ mousedown(preventDefault) → 'an-edit-abort'。
     ✓/✕ 走 mousedown + preventDefault：抢在 contenteditable blur（blur=提交）之前定调——否则「取消」会被 blur 误提交（取消须优先回滚）。
   保存钮 accent：an-button 的 icon 变体无 accent-icon 态，故经 ::part(button) 给绿——本件是该 affordance 皮肤的主人，合法着色。 */
(function () {
  class AnEditAffordance extends window.AnElement {
    static tag = "an-edit-affordance";
    static observed = [];   // editing 纯 CSS（:host([editing])）实时响应，不重渲——免每切态重建 3 个 an-button
    static css = `
      /* 裸钮（无药丸底）：与 an-field/an-kv 的就地编辑铅笔/取消保存 同观感，统一全局编辑语汇 */
      :host { display: inline-flex; align-items: center; gap: var(--gap-tight); }
      /* 非编辑态藏 取消/保存、只显铅笔；编辑态藏铅笔、显 取消/保存（与 code-editor 同款：取消左中性·保存右 accent） */
      :host(:not([editing])) .a-save, :host(:not([editing])) .a-cancel { display: none; }
      :host([editing]) .a-edit { display: none; }
      /* 保存钮 accent 加粗（经 an-button 暴露的 part=button 着色；本件是 affordance 皮肤主人） */
      .a-save::part(button) { color: var(--accent); font-weight: 600; }
      .a-save::part(button):hover { background: var(--accent-soft); color: var(--accent); }
    `;
    render() {
      return `<an-button class="a-edit" variant="icon" size="sm" icon="edit" aria-label="编辑"></an-button>`
        + `<an-button class="a-cancel" size="sm">取消</an-button>`
        + `<an-button class="a-save" size="sm">保存</an-button>`;
    }
    hydrate() {
      this.$(".a-edit").addEventListener("click", () => this.emit("an-edit-start"));
      this.$(".a-save").addEventListener("mousedown", (ev) => { ev.preventDefault(); this.emit("an-edit-commit"); });
      this.$(".a-cancel").addEventListener("mousedown", (ev) => { ev.preventDefault(); this.emit("an-edit-abort"); });
    }
  }
  window.AnElement.define(AnEditAffordance);
})();
