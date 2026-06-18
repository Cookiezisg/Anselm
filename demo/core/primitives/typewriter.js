/* Anselm 原语 — <an-typewriter prefix>。纯视觉打字机：循环 type → 停 → delete → 换下一句。
   why：chat 空态「时间问候 + 轮播意图」、任何"活"标语需打字机动效——抽成单源原语（可复用、可单测），不在 feature 手搓定时器。
   数据：.phrases=["…","…"]（JS 属性，循环句数组，setter 即重启循环）；attr prefix（恒定前缀如 "Good morning, "，不参与打字、常显左侧、主墨）。
   行为：typing 逐字加 → holding 停 PAUSE_MS → deleting 逐字删（半速、删比打快、视觉自然）→ idx=(idx+1)%n 打下一句。
   生命周期：单 setTimeout 链 this._timer；hydrate 启动；disconnectedCallback 清（移出 DOM 即停，杜绝 poke 已 detached 节点）。
   节拍 SPEED_MS/PAUSE_MS 是 JS 定时器常量（CSS token 触达不到 JS），集中此处、注释挂钩 motion 阶梯；光标闪烁等纯 CSS 仍走 token。字号/行高继承宿主（标题处大、副文处小复用同件）。 */
(function () {
  // 打字节拍（JS 定时器；对齐 motion 阶梯：SPEED≈--d-fast 量级单字、PAUSE≈--d-slow 数倍停顿）。删字取半速更自然。
  const SPEED_MS = 52, PAUSE_MS = 1500;

  class AnTypewriter extends window.AnElement {
    static tag = "an-typewriter";
    static observed = ["prefix"];
    static css = `
      :host { display: inline; }
      .tw { display: inline; color: var(--ink); font-size: inherit; line-height: inherit; }
      .pre { color: var(--ink); }
      .txt { color: var(--ink-2); }   /* 轮播句用次级墨，与恒定 prefix 主墨分层 */
      .cur { display: inline-block; width: var(--line-2); height: 1em; vertical-align: text-bottom;
        margin-left: var(--gap-hair); background: var(--accent); border-radius: var(--r-tag);
        animation: an-tw-blink var(--d-breath) var(--ease-out) infinite; }   /* 闪烁复用 --d-breath 与 status-dot 呼吸同频 */
      @keyframes an-tw-blink { 0%, 45% { opacity: 1; } 55%, 100% { opacity: 0; } }
    `;
    set phrases(v) { this._phrases = Array.isArray(v) ? v.slice() : []; if (this.isConnected) this._restart(); }
    get phrases() { return this._phrases || []; }
    render() {
      const e = window.anEsc;
      return `<span class="tw"><span class="pre">${e(this.attr("prefix", ""))}</span><span class="txt"></span><span class="cur"></span></span>`;
    }
    hydrate() { this._restart(); }
    disconnectedCallback() { if (this._timer) { clearTimeout(this._timer); this._timer = null; } }
    _restart() {
      if (this._timer) clearTimeout(this._timer);
      this._idx = 0; this._shown = ""; this._phase = "typing";
      const txt = this.$(".txt"); if (txt) txt.textContent = "";
      if ((this._phrases || []).length) this._tick();
    }
    _tick() {
      const phrases = this._phrases || []; if (!phrases.length) return;
      const full = phrases[this._idx % phrases.length] || "";
      let delay = SPEED_MS;
      if (this._phase === "typing") {
        this._shown = full.slice(0, this._shown.length + 1);
        if (this._shown === full) { this._phase = "holding"; delay = PAUSE_MS; }
      } else if (this._phase === "holding") {
        this._phase = "deleting"; delay = Math.round(SPEED_MS / 2);
      } else {   // deleting
        this._shown = this._shown.slice(0, -1); delay = Math.round(SPEED_MS / 2);
        if (!this._shown) { this._idx = (this._idx + 1) % phrases.length; this._phase = "typing"; delay = SPEED_MS; }
      }
      const txt = this.$(".txt"); if (txt) txt.textContent = this._shown;
      this._timer = setTimeout(() => this._tick(), delay);
    }
  }
  window.AnElement.define(AnTypewriter);
})();
