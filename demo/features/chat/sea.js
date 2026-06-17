/* Anselm feature — chat 海洋（sea）：AI 对话运行时主战场。
   布局：中央 = an-page（居中列：ocean-header 可改名 + an-block-tree transcript）+ 底部固定 an-composer；右岛 = 仅 :iterate 对话展开（实体 live 编辑 pending 草稿）。
   契约落地（mock 演示）：Send=202+SSE → 这里以脚本回放模拟流式回合（每对话同时只一个在途回合 → generating 时 composer 切「停止」）；
     DB 行是真相 → blocks 数组是耐久态、脚本步增量改它再整渲（block-tree 声明式）；右岛 live 编辑订阅 entities build 流 → 这里以 island 步流式喂 an-code-editor。
   脚本解释器消费 data.js 的 turn 步：push/patch/island/gate（gate 等 an-block-tree 冒泡的 an-decide，approve→settled、deny→改道）。
   串接：composer an-send→追加 user 块 + 跑回复回合 · an-stop→停 · block-tree an-continue→续跑 · an-ref（ref-pill 点击）→Intent.select；rail 选会话→Intent.on('conversation')→loadConvo。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.chat = Object.assign(window.FEATURE.chat || {}, {
  sea: (ctx) => {
    const el = window.el;
    const CONVOS = window.CHAT_CONVOS || {};
    const toast = (t) => window.AnToast && window.AnToast.show({ text: t });

    // ── 持久骨架（切会话只更新内容，不重建）──
    const page = el("an-page");
    const header = el("an-ocean-header", { editable: true });
    const tree = el("an-block-tree");
    page.append(header, tree);
    const composer = el("an-composer");
    composer.mentions = window.CHAT_MENTIONS || [];
    const root = el("div", { class: "chat-sea" });
    root.style.cssText = "flex:1; min-height:0; display:flex; flex-direction:column;";
    root.append(page, composer);

    // ── 会话/回合态 ──
    let cur = null;          // 当前会话
    let blocks = [];         // live transcript（耐久态）
    let timers = [];         // 脚本步定时器（切会话全清）
    let gateListener = null; // 等待中的 an-decide 监听
    let island = null;       // 右岛（:iterate 对话）
    let islandCode = "";     // 右岛 live 代码累积

    const setBlocks = (b) => { blocks = b; tree.blocks = blocks; requestAnimationFrame(() => page.scrollToBottom()); };
    const pushBlock = (b) => setBlocks(blocks.concat([b]));
    const patchLast = (b) => setBlocks(blocks.slice(0, -1).concat([b]));

    function clearTurn() {
      timers.forEach(clearTimeout); timers = [];
      if (gateListener) { tree.removeEventListener("an-decide", gateListener); gateListener = null; }
    }
    const after = (ms, fn) => { timers.push(setTimeout(fn, ms)); };

    // ── 右岛（:iterate 对话）：实体 live 编辑 pending 草稿 ──
    function buildIsland(spec) {
      const isl = el("an-right-island", { title: "实时编辑 · " + spec.entity, icon: spec.kind || "function" });
      const card = el("an-info-card", { title: spec.entity, icon: spec.kind || "function", meta: "待 review · " + (spec.version || "草稿") });
      const code = el("an-code-editor", { lang: spec.lang || "text" });
      code.textContent = "";
      const acts = el("an-action-group", { footer: true });
      const adopt = el("an-button", { variant: "primary", size: "sm", icon: "check", onclick: () => toast("已采用草稿 · " + spec.entity + " 生效") }, "采用 " + (spec.version || "草稿"));
      const discard = el("an-button", { size: "sm", icon: "trash", onclick: () => toast("已丢弃草稿") }, "丢弃");
      acts.append(adopt, discard);
      card.append(code, acts);
      isl.append(card);
      isl._code = code;
      return isl;
    }

    // ── 脚本解释器（消费 data.js 的 turn 步）──
    function applyStep(s) {
      if (!s) return;
      if (s.push) pushBlock(s.push);
      if (s.patch) patchLast(s.patch);
      if (s.island && island && island._code) {
        islandCode = s.island.append != null ? islandCode + s.island.append : (s.island.code != null ? s.island.code : islandCode);
        island._code.value = islandCode;
      }
    }
    function runTurn(steps, i) {
      if (!cur || !steps || i >= steps.length) { composer.removeAttribute("generating"); return; }
      const s = steps[i];
      if (s.gate) {   // 危险确认：等 an-block-tree 冒泡的 an-decide（approve→settled / deny→改道）；3.5s 无人动则自动放行（自演）
        gateListener = (ev) => {
          clearTurn();
          const branch = ev.detail.action === "deny" ? s.gate.onDeny : s.gate.onApprove;
          applyStep(branch); after(branch.ms || 400, () => runTurn(steps, i + 1));
        };
        tree.addEventListener("an-decide", gateListener);
        after(3500, () => { if (gateListener) { tree.removeEventListener("an-decide", gateListener); gateListener = null; } applyStep(s.gate.onApprove); after(s.gate.onApprove.ms || 400, () => runTurn(steps, i + 1)); });
        return;
      }
      after(s.ms || 300, () => { applyStep(s); runTurn(steps, i + 1); });
    }
    function startTurn(steps) { if (!steps || !steps.length) return; composer.setAttribute("generating", ""); runTurn(steps, 0); }

    // 用户发送后的脚本回复回合（演示：真实经 messages SSE 流式）
    const replyTurn = () => [
      { ms: 500, push: { type: "reasoning", open: false, label: "推理", text: "理解用户的追加请求并简短回应。" } },
      { ms: 950, push: { type: "text", text: "收到 👍 我会按这个调整。\n\n（演示：真实回合经 messages SSE 逐块流式产出，此处为脚本回放。）" } },
    ];

    // ── 切会话 ──
    function loadConvo(id) {
      clearTurn();
      const c = CONVOS[id] || CONVOS[window.CHAT_DEFAULT]; if (!c) return;
      cur = c;
      header.setAttribute("crumb", c.crumb || "Chat");
      header.setAttribute("title", c.title || "对话");
      composer.removeAttribute("generating");
      composer.attachments = [];
      // 右岛：仅 :iterate 对话展开实体 live 编辑（其余收起、对话全宽）
      island = null; islandCode = "";
      if (c.island) { island = buildIsland(c.island); if (ctx.shell) ctx.shell.setRight(island); }
      else if (ctx.shell) ctx.shell.setRight(null);
      // 初始 transcript + 自动播放脚本回合
      setBlocks((c.blocks || []).slice());
      if (c.autoplay && c.turn) after(700, () => startTurn(c.turn));
    }

    // ── 串接 ──
    composer.addEventListener("an-send", (ev) => {
      if (composer.hasAttribute("generating")) return;
      const d = ev.detail || {};
      pushBlock({ type: "text", role: "user", html: d.html || window.anEsc(d.text || "") });
      startTurn(replyTurn());
    });
    composer.addEventListener("an-stop", () => { clearTurn(); composer.removeAttribute("generating"); pushBlock({ type: "text", text: "_（已停止生成）_" }); });
    tree.addEventListener("an-continue", () => { if (composer.hasAttribute("generating")) return; startTurn([{ ms: 400, push: { type: "text", text: "继续——本回合接着上一步推进（演示）。" } }]); });
    // ref-pill 点击（transcript 内 @提及 / 实体引用）→ 统一前门 Intent.select
    root.addEventListener("an-ref", (ev) => { const d = ev.detail || {}; if (d.kind && d.id) ctx.Intent.select({ kind: "entity", id: d.id, source: "chat" }); });

    ctx.Intent.on("conversation", (sel) => { if (root.isConnected && sel && sel.id) loadConvo(sel.id); });
    loadConvo(window.CHAT_DEFAULT || Object.keys(CONVOS)[0]);
    return root;
  },
});
