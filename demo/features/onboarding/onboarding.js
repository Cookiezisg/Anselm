/* Anselm demo — onboarding 首启向导（standalone，manifest.onboarding.standalone 指向 onboarding.html）。
   冷启动路径外壳：欢迎 → 工作区 → 接入模型(免费档同意=涨 star 抓手) → 装工具(MCP) → 完成 → 进 app。
   纯视觉 mock：选择推进步骤、接 toast；用品牌图标（像素 F，demo/brand/anselm-icon.svg）。
   why：onboarding 是 demo 唯一缺的「第一次打开 app」画面；workspace/key/免费档/MCP 四步串成完整冷启动故事（见 demo-completeness 审计）。 */
(function () {
  const el = window.el, icon = window.icon;
  const toast = (t) => window.AnToast && window.AnToast.show({ text: t });
  const BRAND = "../../brand/anselm-icon.svg";
  // 首启可一键装的热门 MCP（真项目图标，来自 GitHub MCP Registry）
  const MCPS = [
    { name: "GitHub", icon: "https://avatars.githubusercontent.com/u/9919?v=4", desc: "仓库 · issue · PR" },
    { name: "Context7", icon: "https://avatars.githubusercontent.com/u/74989412?v=4", desc: "实时代码文档" },
    { name: "Playwright", icon: "https://avatars.githubusercontent.com/u/6154722?v=4", desc: "浏览器自动化" },
    { name: "Notion", icon: "https://avatars.githubusercontent.com/u/4792552?v=4", desc: "笔记 · 数据库" },
  ];

  function ensureStyle() {
    if (document.getElementById("ob-style")) return;
    const s = document.createElement("style"); s.id = "ob-style";
    s.textContent = `
      .ob { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; background: var(--sea); padding: var(--sp-8); overflow: auto; }
      .ob-card { width: 100%; max-width: calc(var(--w-content) - var(--side-w)); display: flex; flex-direction: column; gap: var(--sp-4); }
      .ob-card.center { align-items: center; text-align: center; }
      .ob-icon { width: calc(var(--island-head) * 2); height: calc(var(--island-head) * 2); border-radius: calc(var(--island-head) * 0.45); box-shadow: var(--shadow-float); }
      .ob-title { font-size: var(--t-h1); font-weight: 700; color: var(--ink); letter-spacing: -0.01em; }
      .ob-h { font-size: var(--t-h2); font-weight: 600; color: var(--ink); }
      .ob-sub { font-size: var(--t-body); color: var(--ink-2); line-height: var(--lh-prose); }
      /* 卡/步骤点/图标 已内化为 an-card / an-stepper / an-brand-icon 原语；此处仅留 standalone 向导外壳 + 卡内文案布局 */
      .ob-nav { display: flex; align-items: center; gap: var(--sp-2); margin-top: var(--sp-2); }
      .ob-grow { flex: 1; }
      .ob-ct { display: flex; align-items: center; gap: var(--sp-2); }
      .ob-ct .t { flex: 1; min-width: var(--zero); font-size: var(--t-body); font-weight: 600; color: var(--ink); }
      .ob-csub { font-size: var(--t-meta); color: var(--ink-2); }
      .ob-cnote { font-size: var(--t-meta); color: var(--ink-3); }
      .ob-mcp-grid { display: grid; grid-template-columns: repeat(2, minmax(var(--zero), 1fr)); gap: var(--sp-2); }
      .ob-m { flex: 1; min-width: var(--zero); }
      .ob-m .nm { font-size: var(--t-body); font-weight: 500; color: var(--ink); }
      .ob-m .d { font-size: var(--t-meta); color: var(--ink-3); }
      .ob-chk { flex: none; width: var(--lead); height: var(--lead); display: grid; place-items: center; color: var(--accent); }
    `;
    document.head.appendChild(s);
  }

  let root, idx = 0;
  const st = { ws: "Personal", model: null, mcp: {} };
  const CONFIG = 3; // workspace / models / mcp 三步进度

  const grow = () => { const g = el("span"); g.className = "ob-grow"; return g; };
  const btn = (label, variant, on) => { const b = el("an-button", variant ? { variant } : {}, label); b.addEventListener("click", on); return b; };
  const nav = (kids) => { const n = el("div"); n.className = "ob-nav"; kids.forEach((k) => n.append(k)); return n; };
  const dots = (active) => el("an-stepper", { count: String(CONFIG), active: String(active) });
  function brandIcon() { const i = el("img"); i.className = "ob-icon"; i.src = BRAND; i.alt = "Anselm"; return i; }

  // ── 步骤 ──
  function welcome(card) {
    card.classList.add("center");
    const h = el("div"); h.className = "ob-title"; h.textContent = "Anselm";
    const s = el("div"); s.className = "ob-sub"; s.textContent = "本地优先的 Agentic Workflow 平台 —— 实体、工作流、durable 执行，全在你这台机器上。";
    card.append(brandIcon(), h, s, btn("开始", "primary", () => go(1)));
  }
  function workspace(card) {
    const h = el("div"); h.className = "ob-h"; h.textContent = "创建工作区";
    const s = el("div"); s.className = "ob-sub"; s.textContent = "工作区装着你所有的实体、对话和配置。单机单用户、本地落盘。";
    const inp = el("an-input", { full: "", value: st.ws, placeholder: "工作区名称" });
    inp.addEventListener("an-input", (e) => { st.ws = e.detail.value; });
    card.append(dots(1), h, s, inp, nav([btn("继续", "primary", () => go(1))]));
  }
  function choice(id, title, sub, note, rec) {
    const c = el("an-card", { selectable: "" }); c.dataset.id = id; if (st.model === id) c.setAttribute("selected", "");
    const top = el("div"); top.className = "ob-ct";
    const t = el("div"); t.className = "t"; t.textContent = title; top.append(t);
    if (rec) top.append(el("an-badge", { tone: "accent" }, "推荐"));
    const su = el("div"); su.className = "ob-csub"; su.textContent = sub;
    const no = el("div"); no.className = "ob-cnote"; no.textContent = note;
    c.append(top, su, no);
    c.addEventListener("an-card-select", () => { st.model = id; root.querySelectorAll("an-card[data-id]").forEach((x) => x.toggleAttribute("selected", x.dataset.id === id)); });
    return c;
  }
  function models(card) {
    const h = el("div"); h.className = "ob-h"; h.textContent = "接入一个模型";
    const s = el("div"); s.className = "ob-sub"; s.textContent = "用免费额度立刻开始，或配置你自己的 Key。随时能在设置里改。";
    const a = choice("free", "✦  Anselm Free · DeepSeek", "免费额度 · 无需 key", "经我们代理 + 第三方 DeepSeek，不享本地隐私保证。", true);
    const b = choice("byok", "用我自己的 Key", "OpenAI / Claude / Gemini / 通义 / …", "明文仅存一次、加密落盘、永不出机。", false);
    card.append(dots(2), h, s, a, b, nav([btn("上一步", null, () => go(-1)), grow(), btn("继续", "primary", () => { if (!st.model) { toast("先选一种接入方式"); return; } go(1); })]));
  }
  function mcpCard(m) {
    const c = el("an-card", { selectable: "", row: "" }); if (st.mcp[m.name]) c.setAttribute("selected", "");
    const ico = el("an-brand-icon", { src: m.icon });
    const mid = el("div"); mid.className = "ob-m"; const nm = el("div"); nm.className = "nm"; nm.textContent = m.name; const d = el("div"); d.className = "d"; d.textContent = m.desc; mid.append(nm, d);
    const chk = el("span"); chk.className = "ob-chk"; if (st.mcp[m.name]) chk.innerHTML = icon("check", 14);
    c.append(ico, mid, chk);
    c.addEventListener("an-card-select", () => { st.mcp[m.name] = !st.mcp[m.name]; c.toggleAttribute("selected", st.mcp[m.name]); chk.innerHTML = st.mcp[m.name] ? icon("check", 14) : ""; });
    return c;
  }
  function mcp(card) {
    const h = el("div"); h.className = "ob-h"; h.textContent = "装个工具？";
    const s = el("div"); s.className = "ob-sub"; s.textContent = "MCP 让 agent 连上 GitHub、数据库、浏览器…… 可跳过，随时在设置里装。";
    const grid = el("div"); grid.className = "ob-mcp-grid"; MCPS.forEach((m) => grid.append(mcpCard(m)));
    card.append(dots(3), h, s, grid, nav([btn("上一步", null, () => go(-1)), grow(), btn("跳过", null, () => go(1)), btn("继续", "primary", () => go(1))]));
  }
  function done(card) {
    card.classList.add("center");
    const h = el("div"); h.className = "ob-h"; h.textContent = "一切就绪";
    const picked = Object.keys(st.mcp).filter((k) => st.mcp[k]).length;
    const bits = ["工作区 " + (st.ws || "Personal")];
    if (st.model === "free") bits.push("免费档已启用"); else if (st.model === "byok") bits.push("待配置 Key");
    if (picked) bits.push(picked + " 个工具");
    const s = el("div"); s.className = "ob-sub"; s.textContent = bits.join(" · ");
    const enter = el("an-button", { variant: "primary" }, "进入 Anselm"); enter.addEventListener("click", () => { location.href = "../../app.html"; });
    card.append(brandIcon(), h, s, enter);
  }

  const STEPS = [welcome, workspace, models, mcp, done];
  function go(d) { idx = Math.max(0, Math.min(STEPS.length - 1, idx + d)); render(); }
  function render() {
    root.innerHTML = "";
    const wrap = el("div"); wrap.className = "ob";
    const card = el("div"); card.className = "ob-card";
    STEPS[idx](card);
    wrap.append(card); root.append(wrap);
  }
  function mount(r) { root = r; ensureStyle(); render(); }
  window.ONBOARDING = { mount };
})();
