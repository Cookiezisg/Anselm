/* Anselm 原语 — <an-stepper count active>。步骤进度点：count 个点；active(1-based) = accent 胶囊、<active = done 灰点、>active = 待激活浅点。
   why：onboarding 向导 .ob-dots/.ob-dot + dots() JS 收口（PATTERNS 早登记 ⬚ planned，此落地）。 */
(function () {
  class AnStepper extends window.AnElement {
    static tag = "an-stepper";
    static observed = ["count", "active"];
    static css = `
      :host { display: inline-flex; }
      .dots { display: flex; align-items: center; gap: var(--sp-2); }
      .dot { width: var(--dot); height: var(--dot); border-radius: var(--r-pill); background: var(--line-strong);
        transition: background var(--d-fast), width var(--d-fast); }
      .dot.on { background: var(--accent); width: calc(var(--dot) * 3); }
      .dot.done { background: var(--ink-3); }
    `;
    render() {
      const count = Math.max(0, this.num("count", 3)), active = this.num("active", 1);
      let dots = "";
      for (let i = 1; i <= count; i++) dots += `<span class="dot${i === active ? " on" : i < active ? " done" : ""}"></span>`;
      return `<div class="dots">${dots}</div>`;
    }
  }
  window.AnElement.define(AnStepper);
})();
