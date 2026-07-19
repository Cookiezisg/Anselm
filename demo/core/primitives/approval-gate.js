/* Anselm 原语 G1 — <an-approval-gate flavor>。人在环决策门，三 flavor 共一套皮肤（描边浮卡 + 盾牌头 + settled 收口）。
   为何同一原语多 flavor 而非多原语：~90% 皮肤共享，差异只在头部右侧 + 动作动词 + 主体。
     flavor="chat"    → 内存 danger 门：approve / approve_always / deny；danger 三级自报徽（safe|cautious|dangerous）；顶角 run 脉冲点；工具名 + args 预览；无倒计时。
     flavor="ask"     → ask_user 提问门：accept{answer} / decline；accent 盾；渲 prompt.message + options 单选 chip 或文本框；【无】danger 徽/倒计时/reason（区别于 danger 门与 flowrun 门）。
     flavor="durable" → flowrun :decide：yes(通过) / no(驳回)；warn 倒计时 deadline；渲染后的 prompt 文本；可选 reason 输入；first-wins 脚注。【仅 scheduler 海洋】，非 chat。
   决策属人在环动作（非实体导航）：交互对外 emit composed 'an-decide'{action, reason?}；命令式 settle(text)/wait(autoAct,ms)→Promise 供自动播放复用。
   复用：顶角脉冲 = <an-status-dot state="run">（系统唯一 accent 呼吸，归一一处）；danger 徽 = <an-badge>；动作 = <an-button>；args = <an-code-editor>；不重造。
   属性：flavor | title | tool | danger | summary | args | prompt | ddl | allow-reason | placeholder | settled。 */
(function () {
  const e = window.anEsc;

  // chat danger 三级 → <an-badge> tone（safe=中性灰 / cautious=warn / dangerous=danger），单一翻译路径。
  const DANGER_TONE = { safe: "neutral", cautious: "warn", dangerous: "danger" };

  class AnApprovalGate extends window.AnElement {
    static tag = "an-approval-gate";
    static observed = ["flavor", "title", "tool", "danger", "summary", "args", "prompt", "options", "ddl", "allow-reason", "placeholder", "settled"];

    // why：options 经数组 prop 注入时含「|」的选项不会被裂开（attr 分隔符不可转义）
    set options(v) { this._options = Array.isArray(v) ? v.slice() : null; if (this.isConnected) this._render(); }
    get options() { return this._options || null; }
    static css = `
      :host { display: block; margin: var(--sp-3) 0; }

      /* 外框：warn 与 line 混的暖描边浮卡 + 双层浮岛阴影；settled 后松回中性线 */
      .gate {
        position: relative; overflow: hidden;
        border: var(--hairline) solid color-mix(in srgb, var(--warn) 45%, var(--line));
        border-radius: var(--r-card); background: var(--island);
        box-shadow: var(--shadow-island);
      }
      :host([settled]) .gate { border-color: var(--line); }

      /* 顶角 run 脉冲点（chat 味：正在等你；durable 不显）——复用 status-dot 的 accent 呼吸 */
      .pulse { position: absolute; top: var(--sp-3); right: var(--sp-3); }

      /* 头：盾牌 + 标题/工具 + 右侧（danger 徽 or 倒计时） */
      .head { display: flex; align-items: center; gap: var(--sp-3); padding: var(--sp-3) var(--sp-3) var(--sp-2); }
      .shield {
        width: var(--ctl); height: var(--ctl); border-radius: var(--r-btn); flex: none;
        display: grid; place-items: center;
        background: color-mix(in srgb, var(--warn) 12%, transparent); color: var(--warn);
      }
      .shield svg { width: var(--icon); height: var(--icon); }
      .tt { flex: 1; min-width: 0; }
      .tt b { display: block; font-size: var(--t-strong); font-weight: 600; color: var(--ink); line-height: var(--lh-tight); }
      .tool { font-family: var(--mono); font-size: var(--t-meta); color: var(--ink-2); }
      .sub { font-size: var(--t-meta); color: var(--ink-2); line-height: var(--lh-ui); }

      /* durable 倒计时（warn 色 · mono 截止文案 + 内联时钟） */
      .countdown { flex: none; display: inline-flex; align-items: center; gap: var(--gap-tight); font-size: var(--t-meta); color: var(--warn); }
      .countdown svg { display: block; flex: none; width: var(--icon-sm); height: var(--icon-sm); }

      /* 主体 */
      .body { padding: 0 var(--sp-3) var(--sp-3); }
      .sum { font-size: var(--t-body); color: var(--ink-2); line-height: var(--lh-prose); margin: var(--grid) 0 var(--sp-2); }

      /* chat args / durable rendered prompt：mono/正文 灰底框（复用 island-2 嵌套面） */
      .panel {
        background: var(--island-2); border: var(--hairline) solid var(--line); border-radius: var(--r-chip);
        color: var(--ink-2); white-space: pre-wrap; margin-bottom: var(--sp-3);
      }
      .panel.args { padding: var(--sp-2) var(--sp-3); }
      .panel.rendered { padding: var(--sp-2) var(--sp-3); font-size: var(--t-body); line-height: var(--lh-prose); }
      .panel.args an-code-editor { display: block; }

      /* durable 可选 reason 输入 */
      .reason {
        width: 100%; box-sizing: border-box; background: var(--island-2);
        border: var(--hairline) solid var(--line); border-radius: var(--r-chip); padding: var(--sp-2) var(--sp-3);
        font: inherit; font-size: var(--t-body); color: var(--ink); line-height: var(--lh-ui);
        outline: 0; resize: none; margin-bottom: var(--sp-3);
      }
      .reason:focus { border-color: var(--accent-line); box-shadow: 0 0 0 var(--focus-ring) var(--accent-soft); }
      .reason::placeholder { color: var(--ink-3); }

      /* 动作行（复用 an-button：primary 蓝填 / ghost 中性 / danger 红 hover） */
      .actions { display: flex; align-items: center; gap: var(--sp-2); flex-wrap: wrap; }
      .note { font-size: var(--t-meta); color: var(--ink-3); margin-left: var(--grid); }

      /* durable first-wins 脚注 */
      .foot { font-size: var(--t-meta); color: var(--ink-3); margin-top: var(--sp-2); line-height: var(--lh-ui); }

      /* ask 提问门：accent 盾 + 选项 chip 单选（无 danger 徽/倒计时/reason） */
      .shield.ask { background: var(--accent-soft); color: var(--accent); }
      .ask-opts { display: flex; flex-wrap: wrap; gap: var(--gap-tight); margin-bottom: var(--sp-3); }
      .ask-opt { padding: var(--gap-tight) var(--sp-3); border-radius: var(--r-pill);
        box-shadow: inset 0 0 0 var(--hairline) var(--line); background: var(--island); color: var(--ink-2);
        font-size: var(--t-body); cursor: pointer; transition: background var(--d-fast), color var(--d-fast), box-shadow var(--d-fast); }
      .ask-opt:hover { background: var(--island-3); color: var(--ink); }
      .ask-opt.on { background: var(--accent-soft); box-shadow: inset 0 0 0 var(--hairline) var(--accent-line); color: var(--accent); }

      /* settled 收口面：默认藏，settled 后亮（隐头/体 + 亮绿勾） */
      .settled { display: none; align-items: center; gap: var(--sp-2); padding: var(--sp-3); font-size: var(--t-body); color: var(--ink-3); }
      .settled .ico { display: grid; place-items: center; color: var(--ok); }
      .settled .ico svg { width: var(--icon); height: var(--icon); }
      :host([settled]) .pulse,
      :host([settled]) .head,
      :host([settled]) .body { display: none; }
      :host([settled]) .settled { display: flex; }
    `;

    render() {
      const flavor = this.attr("flavor");
      const pulse = flavor === "durable" ? "" : `<span class="pulse"><an-status-dot state="run"></an-status-dot></span>`;
      const body = flavor === "durable" ? this.durableHtml() : flavor === "ask" ? this.askHtml() : this.chatHtml();
      return `<div class="gate">${pulse}${body}` +
        `<div class="settled"><span class="ico">${window.icon("check")}</span><span data-settled></span></div></div>`;
    }

    // ask 味：ask_user 提问门（accept{answer}/decline）。渲 prompt.message + options 单选 chip 或文本框；【无】danger 徽/倒计时/reason。
    askHtml() {
      const prompt = this.attr("prompt") ? `<div class="sum">${e(this.attr("prompt"))}</div>` : "";
      // 数组 prop 优先（含「|」的选项不裂）；回退到 attr「|」分隔（简单声明式用法）
      const opts = this._options || (this.attr("options") || "").split("|").filter(Boolean);
      const optHtml = opts.length
        ? `<div class="ask-opts">${opts.map((o, k) => `<button type="button" class="ask-opt" data-opt="${k}">${e(o)}</button>`).join("")}</div>`
        : `<textarea class="reason ask-answer" rows="2" placeholder="${e(this.attr("placeholder", "输入你的回答…"))}"></textarea>`;
      return `
        <div class="head">
          <span class="shield ask">${window.icon("chat")}</span>
          <span class="tt"><b>${e(this.attr("title", "需要你的输入"))}</b><span class="sub">ask_user · 等待回答</span></span>
        </div>
        <div class="body">${prompt}${optHtml}
          <div class="actions">
            <an-button variant="primary" size="sm" icon="check" data-act="accept">提交</an-button>
            <an-button size="sm" data-act="decline">跳过</an-button>
          </div>
        </div>`;
    }

    // chat 味：危险闸（批准/始终批准/拒绝）。danger 三级自报徽 + args 框 + 预授权说明。
    chatHtml() {
      const danger = this.attr("danger", "dangerous");
      const tone = DANGER_TONE[danger] || "danger";
      const tool = this.attr("tool") ? `<span class="tool">${e(this.attr("tool"))}</span>` : "";
      const sum = this.attr("summary") ? `<div class="sum">${e(this.attr("summary"))}</div>` : "";
      const args = this.attr("args")
        ? `<div class="panel args"><an-code-editor inline lang="json">${e(this.attr("args"))}</an-code-editor></div>`
        : "";
      return `
        <div class="head">
          <span class="shield">${window.icon("shield")}</span>
          <span class="tt"><b>${e(this.attr("title", "需要审批确认"))}</b>${tool}</span>
          <an-badge tone="${tone}">${e(danger)}</an-badge>
        </div>
        <div class="body">${sum}${args}
          <div class="actions">
            <an-button variant="primary" size="sm" icon="check" data-act="approve">批准</an-button>
            <an-button size="sm" data-act="approve_always">始终批准</an-button>
            <span class="note">本会话内预授权</span>
            <an-button variant="danger" size="sm" data-act="deny">拒绝</an-button>
          </div>
        </div>`;
    }

    // durable 味：flowrun :decide（通过/驳回）。warn 倒计时 + 渲染 prompt + 可选 reason + first-wins 脚注。
    durableHtml() {
      const ddl = this.attr("ddl")
        ? `<span class="countdown" data-countdown>${window.icon("scheduler", 12)}<span data-ddl>${e(this.attr("ddl"))}</span></span>`
        : "";
      const prompt = this.attr("prompt") ? `<div class="panel rendered">${e(this.attr("prompt"))}</div>` : "";
      const reason = this.has("allow-reason")
        ? `<textarea class="reason" rows="2" placeholder="${e(this.attr("placeholder", "理由（可选）…"))}"></textarea>`
        : "";
      return `
        <div class="head">
          <span class="shield">${window.icon("shield")}</span>
          <span class="tt"><b>${e(this.attr("title", "审批收件箱"))}</b><span class="sub">flowrun parked · 待人工决策</span></span>
          ${ddl}
        </div>
        <div class="body">${prompt}${reason}
          <div class="actions">
            <an-button variant="primary" size="sm" icon="check" data-act="yes">通过</an-button>
            <an-button variant="danger" size="sm" data-act="no">驳回</an-button>
          </div>
          <div class="foot">first-wins：人工决策与超时竞争，先到者生效，后到者返回 422。</div>
        </div>`;
    }

    hydrate() {
      // 决策派发：读 data-act + durable 的 reason / ask 的 answer，emit composed an-decide
      const flavor = this.attr("flavor");
      // ask 选项单选（点 chip 选中）
      if (flavor === "ask") {
        this.$$(".ask-opt").forEach((o) => o.addEventListener("click", () => {
          this.$$(".ask-opt").forEach((x) => x.classList.remove("on"));
          o.classList.add("on"); this._answer = o.textContent;
        }));
      }
      this.$$("[data-act]").forEach((b) => {
        b.addEventListener("click", () => {
          if (this._done) return;
          const detail = { action: b.dataset.act };
          if (flavor === "durable") { const r = this.$(".reason"); detail.reason = r ? r.value : ""; }
          if (flavor === "ask" && b.dataset.act === "accept") { const t = this.$(".ask-answer"); detail.answer = this._answer != null ? this._answer : (t ? t.value : ""); }
          this.emit("an-decide", detail);
        });
      });
    }

    // ── 命令式 API（自动播放复用：松开 settle 收口 / wait 模拟点选） ──
    // 收口：替换为「已决」面（隐头/体，亮绿勾 + 文案），并松回中性描边。
    settle(text) {
      // 先翻 settled（observed → 重渲出空 data-settled 槽），再写文案——否则文案被随后的重渲抹掉
      this.toggleAttribute("settled", true);
      const t = this.$("[data-settled]");
      if (t) t.textContent = text == null ? "" : text;
    }

    // 等用户决议；autoAct/ms 用于自动播放（模拟点选）。durable 带可选 reason。
    wait(autoAct, ms) {
      return new Promise((res) => {
        this._done = false;
        const fin = (action) => {
          if (this._done) return;
          this._done = true;
          const out = { action };
          if (this.attr("flavor") === "durable") { const r = this.$(".reason"); out.reason = r ? r.value : ""; }
          res(out);
        };
        const onDecide = (ev) => fin(ev.detail.action);
        this.addEventListener("an-decide", onDecide, { once: true });
        if (autoAct) setTimeout(() => { this.removeEventListener("an-decide", onDecide); fin(autoAct); }, ms || 1800);
      });
    }

    // 更新倒计时文案（host 持有秒级 tick；deadline 续传走 DB 真相、此处只刷瞬时视图）。
    setDeadline(text) {
      this.setAttribute("ddl", text == null ? "" : text);
      const d = this.$("[data-ddl]");
      if (d) d.textContent = text == null ? "" : text;
    }
  }

  window.AnElement.define(AnApprovalGate);
})();
