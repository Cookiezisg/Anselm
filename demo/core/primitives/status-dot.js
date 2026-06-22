/* Anselm 原语 A1 — <an-status-dot state>。语义色状态点；run = 唯一 accent 呼吸动效。
   state ∈ idle(默认) | run | wait | err | done。状态归一只此一处（单一翻译路径 config/state-model anState）。 */
(function () {
  class AnStatusDot extends window.AnElement {
    static tag = "an-status-dot";
    static observed = ["state"];
    static css = `
      :host { display: inline-block; line-height: 0; }
      .dot { display: inline-block; width: var(--dot); height: var(--dot); border-radius: var(--r-pill); background: var(--ink-3); }
      :host([state="run"])  .dot { background: var(--accent); animation: pulse var(--d-breath) var(--ease-out) infinite; }
      :host([state="wait"]) .dot { background: var(--warn); }
      :host([state="err"])  .dot { background: var(--danger); }
      :host([state="done"]) .dot { background: var(--ok); }
      @keyframes pulse {
        0%   { box-shadow: 0 0 0 0 var(--accent-soft); }
        70%  { box-shadow: 0 0 0 var(--dot-pulse) transparent; }
        100% { box-shadow: 0 0 0 0 transparent; }
      }
    `;
    // Canonicalize state to lowercase so the case-sensitive CSS selectors above match
    // backend strings of any casing (DONE/Run/…) instead of silently falling to the default gray.
    // 单一归一路径：badge 的 dot 也经 <an-status-dot> 渲染，故只此一处折正、两处皆受益。
    // 仅在大小写不同才回写，避免 attributeChangedCallback 自激重渲染循环。
    hydrate() {
      const raw = this.getAttribute("state");
      if (raw == null) return;
      const lc = raw.toLowerCase();
      if (lc !== raw) this.setAttribute("state", lc);
    }
    render() { return `<span class="dot"></span>`; }
  }
  window.AnElement.define(AnStatusDot);
})();
