/* Anselm feature — chat 海洋（sea）：AI 对话运行时主战场。
   布局：中央 = an-page（居中列：an-block-tree transcript）+ 底部固定 an-composer；会话名走 shell 左上角紧凑标题（恒显，无文章式大标题）；右岛 = 仅 :iterate 对话展开（实体面订阅 entities build 流实时填充【新 active 版本】，edit 立即生效、可 revert，无草稿/采用门）。
   契约落地（mock 演示）：Send=202+SSE → 这里以脚本回放模拟流式回合（每对话同时只一个在途回合 → generating 时 composer 切「停止」）；
     DB 行是真相 → blocks 数组是耐久态、脚本步增量改它再整渲（block-tree 声明式）；右岛 = entities build 流镜像 → 这里以 islandStream 步逐字喂 an-code-editor（写完即 active）。
   脚本解释器消费 data.js 的 turn 步：push/patch/island/gate（gate 等 an-block-tree 冒泡的 an-decide，approve→settled、deny→改道）。
   串接：composer an-send→追加 user 块 + 跑回复回合 · an-stop→停 · block-tree an-continue→续跑 · an-ref（ref-pill 点击）→Intent.select；rail 选会话→Intent.on('conversation')→loadConvo。 */
window.FEATURE = window.FEATURE || {};
window.FEATURE.chat = Object.assign(window.FEATURE.chat || {}, {
  sea: (ctx) => {
    const el = window.el;
    const CONVOS = window.CHAT_CONVOS || {};
    const toast = (t) => window.AnToast && window.AnToast.show({ text: t });

    // ── 持久骨架（切会话只更新内容，不重建）──
    // chat 无文章式大标题——会话名一上来即显于左上角紧凑标题（shell.setHeadTitle，恒 collapsed）；transcript 直接顶到头栏下。
    const page = el("an-page");
    const tree = el("an-block-tree");
    page.append(tree);
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

    // ── 右岛（:iterate 对话）：实体面订阅 entities build 流实时填充【新 active 版本】（edit 写完即生效，无草稿/采用门；唯一动作 = revert 移指针）──
    function buildIsland(spec) {
      const isl = el("an-right-island", { title: "实时编辑 · " + spec.entity, icon: spec.kind || "function" });
      const card = el("an-info-card", { title: spec.entity, icon: spec.kind || "function", meta: "已生效 · " + (spec.version || "v2") });
      const code = el("an-code-editor", { lang: spec.lang || "text" });
      code.textContent = "";
      const acts = el("an-action-group", { footer: true });
      const prev = el("an-button", { variant: "ghost", size: "sm", icon: "history", onclick: () => toast("已 revert · " + spec.entity + " 回退到上一版本（revert_* 移 active 指针）") }, "revert 回退");
      acts.append(prev);
      card.append(code, acts);
      isl.append(card);
      isl._code = code;
      return isl;
    }

    // ── 脚本解释器：instant 步（push/patch）+ 流式步（stream 逐 token / islandStream 逐字），对齐后端 Open→Delta*→Close ──
    function applyStep(s) {
      if (!s) return;
      if (s.push) pushBlock(s.push);
      if (s.patch) patchLast(s.patch);
    }
    // 文本/推理逐 token 流出（先 push 空块=Open 整渲一次 → 每帧 pokeText 就地增量=Delta → 末帧落 blocks[i]=Close 快照）
    function streamBlock(spec, done) {
      const b = Object.assign({}, spec, { text: "" });
      blocks = blocks.concat([b]); tree.blocks = blocks;
      const i = blocks.length - 1, full = spec.text || "";
      const toks = full.match(/\s+|\S+/g) || (full ? [full] : []);
      const tps = spec.tps || 26;   // tokens/sec
      let acc = "", k = 0;
      const step = () => {
        if (!cur) return;
        if (k >= toks.length) { blocks[i].text = full; tree.pokeText(i, full); page.scrollToBottom(); if (done) done(); return; }
        acc += toks[k++]; blocks[i].text = acc; tree.pokeText(i, acc); page.scrollToBottom();
        timers.push(setTimeout(step, Math.round(1000 / tps)));
      };
      step();
    }
    // 右岛代码逐字流入（= entities build 流镜像：edit_* 工具的 arg delta 镜像到右岛实体面，close 快照才是重连真相）
    function streamIsland(spec, done) {
      if (!island || !island._code) { if (done) done(); return; }
      const full = spec.code || "", chunk = spec.chunk || 2, cps = spec.cps || 140;
      islandCode = full;
      let n = 0;
      const step = () => {
        if (!cur) return;
        if (n >= full.length) { island._code.value = full; if (done) done(); return; }
        n = Math.min(full.length, n + chunk); island._code.value = full.slice(0, n);
        timers.push(setTimeout(step, Math.round(1000 / (cps / chunk))));
      };
      step();
    }
    // progress 终端式 live 流：push 空 progress 块（Open）→ pokeLog 逐行追加（Delta，实时脉冲）→ done:true 落定（Close）
    function streamLog(spec, done) {
      const lines = Array.isArray(spec.lines) ? spec.lines : [];
      blocks = blocks.concat([{ type: "progress", label: spec.label, done: false, lines: [] }]); tree.blocks = blocks;
      const i = blocks.length - 1, lps = spec.lps || 6;
      let k = 0;
      const step = () => {
        if (!cur) return;
        if (k >= lines.length) { blocks[i].done = true; blocks[i].lines = lines; tree.blocks = blocks; page.scrollToBottom(); if (done) done(); return; }
        k++; blocks[i].lines = lines.slice(0, k); tree.pokeLog(i, blocks[i].lines); page.scrollToBottom();
        timers.push(setTimeout(step, Math.round(1000 / lps)));
      };
      step();
    }
    function runStep(s, done) {
      if (!s) { if (done) done(); return; }
      if (s.stream) { after(s.ms || 250, () => streamBlock(s.stream, done)); return; }
      if (s.islandStream) { after(s.ms || 250, () => streamIsland(s.islandStream, done)); return; }
      if (s.progressStream) { after(s.ms || 250, () => streamLog(s.progressStream, done)); return; }
      after(s.ms || 300, () => { applyStep(s); if (done) done(); });
    }
    function runTurn(steps, i) {
      if (!cur || !steps || i >= steps.length) { composer.removeAttribute("generating"); return; }
      const s = steps[i], next = () => runTurn(steps, i + 1);
      if (s.gate) {   // 人在环门：等 an-block-tree 冒泡的 an-decide（approve/accept→onApprove · deny/decline→onDeny）；3.5s 无人动自动放行（自演）
        gateListener = (ev) => { clearTurn(); const a = ev.detail.action; const no = a === "deny" || a === "decline"; runStep(no ? s.gate.onDeny : s.gate.onApprove, next); };
        tree.addEventListener("an-decide", gateListener);
        after(3500, () => { if (gateListener) { tree.removeEventListener("an-decide", gateListener); gateListener = null; } runStep(s.gate.onApprove, next); });
        return;
      }
      runStep(s, next);
    }
    function startTurn(steps) { if (!steps || !steps.length) return; composer.setAttribute("generating", ""); runTurn(steps, 0); }

    // 用户发送后的脚本回复回合（逐 token 流式；演示真实经 messages SSE Delta 帧）
    const replyTurn = () => [
      { ms: 400, stream: { type: "reasoning", open: true, label: "推理", text: "理解用户的追加请求，给出简短回应。", tps: 42 } },
      { ms: 450, stream: { type: "text", text: "收到 👍 我会按这个调整。\n\n（演示：真实回合经 messages SSE 逐 token 流式产出，此处为脚本流式回放。）", tps: 24 } },
    ];

    // ── 切会话 ──
    function loadConvo(id) {
      clearTurn();
      const c = CONVOS[id] || CONVOS[window.CHAT_DEFAULT]; if (!c) return;
      cur = c;
      // 会话名 → 左上角紧凑标题（chat 恒 collapsed=一上来即显）；标题点回顶，⌄ 开对话动作菜单
      if (ctx.shell && ctx.shell.setHeadTitle) {
        ctx.shell.setHeadTitle(c.title || "对话", () => page.scrollToTop(true));
        ctx.shell.setHeadCollapsed(true);
        ctx.shell.setHeadMenu && ctx.shell.setHeadMenu((a) => window.AnMenu.open(a, {
          align: "end", placement: "bottom", namespace: "chat-head-menu",
          items: [
            { value: "rename", label: "重命名", icon: "edit" },
            { value: "pin", label: "置顶", icon: "history" },
            { value: "archive", label: "归档", icon: "enter" },
            { value: "delete", label: "删除", icon: "trash", danger: true },
          ],
          onPick: (v) => toast(({ rename: "已重命名", pin: "已置顶", archive: "已归档", delete: "已删除" }[v]) + "「" + (c.title || "") + "」"),
        }));
      }
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
    // :cancel → 回合终态快照 stopReason=cancelled（对齐后端 message_stop status=cancelled），非裸文本
    composer.addEventListener("an-stop", () => { clearTurn(); composer.removeAttribute("generating"); pushBlock({ type: "turnEnd", stopReason: "cancelled" }); });
    tree.addEventListener("an-continue", () => { if (composer.hasAttribute("generating")) return; startTurn([{ ms: 300, stream: { type: "text", text: "继续——本回合接着上一步推进（演示，逐 token 流式）。", tps: 24 } }]); });
    // ref-pill 点击（transcript 内 @提及 / 实体引用）→ 统一前门 Intent.select
    root.addEventListener("an-ref", (ev) => { const d = ev.detail || {}; if (d.kind && d.id) ctx.Intent.select({ kind: "entity", id: d.id, source: "chat" }); });

    ctx.Intent.on("conversation", (sel) => { if (root.isConnected && sel && sel.id) loadConvo(sel.id); });
    loadConvo(window.CHAT_DEFAULT || Object.keys(CONVOS)[0]);
    return root;
  },
});
