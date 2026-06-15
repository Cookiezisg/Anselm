/* Foryx design-lab — 设置海洋（接管海面的临时场景）。
   侧栏底部齿轮 → Shell.mount('settings')；内部左类目 + 右详情；← 返回 回到主界面(home 占位)。
   依赖 shared/shell.js(Shell.registerOcean/mount/left) + icons.js(icon)。 */
(function () {
  const dir = new URL('.', document.currentScript.src).href;
  if (!document.querySelector('link[data-sb="settings"]')) {
    const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = dir + 'settings.css'; l.dataset.sb = 'settings';
    document.head.appendChild(l);
  }
  const chev = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';

  // ——— 组件 helpers ———
  const sec = (label, body) => `<div class="st-sec">${label ? `<div class="lab">${label}</div>` : ''}<div class="st-island">${body}</div></div>`;
  const row = (k, ctrl, h) => `<div class="st-row"><div class="l"><div class="k">${k}</div>${h ? `<div class="h">${h}</div>` : ''}</div><div class="c">${ctrl}</div></div>`;
  const seg = (opts, on = 0) => `<div class="st-seg">${opts.map((o, i) => `<button class="${i === on ? 'on' : ''}">${o}</button>`).join('')}</div>`;
  const dd = t => `<button class="st-dd">${t}${chev}</button>`;
  const badge = (cls, t) => `<span class="st-badge ${cls}"><span class="d"></span>${t}</span>`;
  const del = `<button class="st-icbtn" title="删除">${icon('close', 15)}</button>`;
  const chip = txt => `<span class="st-ei" style="font-size:11px;font-weight:600">${txt}</span>`;

  // ——— 各分类 ———
  const RENDER = {
    overview: () => `
      <div class="st-hero"><div class="st-av">P</div><div class="nm">Personal</div><div class="sub">本地工作区 · 自 2026-01-03 · 活跃 142 天</div></div>
      <div class="st-stats">
        <div class="st-stat"><div class="num">28.3m</div><div class="lab">累计 Token</div></div>
        <div class="st-stat"><div class="num">1,284</div><div class="lab">对话</div></div>
        <div class="st-stat"><div class="num">47</div><div class="lab">构建实体</div></div>
        <div class="st-stat"><div class="num">6 天</div><div class="lab">当前连续</div></div>
        <div class="st-stat"><div class="num">23 天</div><div class="lab">最长连续</div></div>
      </div>
      <div class="st-actv">
        <div class="hd"><span class="t">活动</span><div class="st-tog"><span class="on">每日</span><span>每周</span><span>累计</span></div></div>
        <div class="st-grid" id="st-grid"></div><div class="st-months" id="st-months"></div>
      </div>
      <div class="st-cols">
        <div><h3>活动洞察</h3>
          <div class="st-irow"><span class="k">最常用模型</span><span class="v">claude-opus-4-8</span></div>
          <div class="st-irow"><span class="k">默认模式</span><span class="v">标准 · 92%</span></div>
          <div class="st-irow"><span class="k">探索 / 已用技能</span><span class="v">5 / 7</span></div>
          <div class="st-irow"><span class="k">平均对话时长</span><span class="v">12 分钟</span></div>
          <div class="st-irow"><span class="k">最长运行</span><span class="v">28 分 37 秒</span></div></div>
        <div><h3>最常用实体</h3><div id="st-ents"></div></div>
      </div>`,

    general: () => '<div class="st-htitle">通用</div>' +
      sec('外观与语言', row('主题', seg(['亮', '暗', '跟随系统'], 0)) + row('界面与回复语言', seg(['中文', 'English'], 0))) +
      sec('网页抓取', row('WebFetch 抓取方式', seg(['本地直取', 'Jina Reader'], 0), 'Jina 模式会把 URL 发往第三方公共 reader（提取更好但出本机）')),

    models: () => '<div class="st-htitle">模型与密钥</div>' +
      sec('默认模型', row('对话', dd('claude-opus-4-8')) + row('工具 / Utility', dd('claude-haiku-4-5')) + row('Agent', dd('claude-sonnet-4-6'))) +
      sec('API 密钥（本地保险箱 · AES-GCM）',
        row('Anthropic', badge('ok', '已连接') + del) +
        row('OpenAI', badge('off', '未测') + `<button class="st-btn">测试</button>` + del) +
        row('DeepSeek', badge('ok', '已连接') + del) +
        row('', `<button class="st-btn ghost">${icon('plus', 14)} 添加密钥</button>`)),

    search: () => '<div class="st-htitle">搜索与嵌入</div>' +
      sec('嵌入引擎', row('引擎', seg(['内置', 'Ollama', '关闭'], 0)) + row('引擎状态', badge('ok', '就绪 · EmbeddingGemma-300m'))) +
      sec('Ollama（选 Ollama 时）', row('地址', `<input class="st-in mono" value="127.0.0.1:11434">`) + row('模型', `<input class="st-in mono" value="embeddinggemma">`)) +
      sec('索引', row('重建全部索引', `<button class="st-btn">重建</button>`, '将重建全部文档/实体索引，期间检索短暂不可用')),

    mcp: () => '<div class="st-htitle">连接器 · MCP</div>' +
      sec('MCP Servers',
        row('GitHub', badge('ok', '已就绪') + `<button class="st-btn ghost">重连</button>` + del) +
        row('Notion', badge('ok', '已就绪') + `<button class="st-btn ghost">重连</button>` + del) +
        row('Filesystem', badge('warn', '降级') + `<button class="st-btn ghost">重连</button>` + del) +
        row('', `<button class="st-btn ghost">${icon('plus', 14)} 添加 Server</button>`)),

    runtimes: () => '<div class="st-htitle">运行时与磁盘</div>' +
      sec('沙箱运行时（按需下载 · 钉死版本）',
        row(`${chip('Py')} Python`, badge('ok', '3.12.4') + `<button class="st-btn ghost">删除</button>`) +
        row(`${chip('JS')} Node`, badge('ok', '20.14') + `<button class="st-btn ghost">删除</button>`) +
        row(`${chip('uv')} uv`, badge('off', '未安装') + `<button class="st-btn">安装</button>`) +
        row(`${chip('.N')} .NET`, badge('off', '未安装') + `<button class="st-btn">安装</button>`)) +
      sec('磁盘', row('沙箱占用', `<span style="font-size:var(--t-md);color:var(--ink-2)">1.24 GB</span><button class="st-btn">清理</button>`)),

    workspace: () => '<div class="st-htitle">工作区</div>' +
      sec('当前工作区', row('名称', `<input class="st-in" value="Personal">`) + row('数据目录', `<span class="st-in mono" style="border:0;min-width:0;color:var(--ink-3)">~/Library/Application Support/Foryx</span>`)) +
      sec('全部工作区', row('Personal', badge('ok', '当前')) + row('实验场', `<button class="st-btn ghost">切换</button>`) + row('', `<button class="st-btn ghost">${icon('plus', 14)} 新建工作区</button>`)) +
      `<div class="st-danger"><div class="dl">删除工作区</div><div class="dd">将级联永久删除该工作区的全部对话、实体、调度与本地文件，无法恢复。请输入工作区名以确认。</div>
        <div style="display:flex;gap:8px"><input class="st-in" placeholder="输入 Personal 确认" style="flex:1"><button class="st-btn danger" disabled style="opacity:.5">删除</button></div></div>`,

    notif: () => '<div class="st-htitle">通知</div>' +
      sec('并发', row('活动运行上限', `<input class="st-in" value="4" style="min-width:80px;text-align:center">`, '同时进行的工作流运行数上限')) +
      sec('通知', row('运行完成', seg(['开', '关'], 0)) + row('待审批', seg(['开', '关'], 0)) + row('实体变更', seg(['开', '关'], 1))),

    about: () => '<div class="st-htitle">关于</div>' +
      sec('', row('版本', `<span style="font-size:var(--t-md);color:var(--ink-2)">Foryx 0.3.0 · design-lab</span>`) +
        row('数据目录', `<button class="st-btn ghost">打开目录</button>`) +
        row('隐私', `<span style="font-size:var(--t-md);color:var(--ink-2)">只存本地 SQLite · 绝不外传</span>`)),
  };

  const CATS = [
    ['个人化', [['overview', '概览'], ['general', '通用']]],
    ['模型', [['models', '模型与密钥'], ['search', '搜索与嵌入']]],
    ['集成', [['mcp', '连接器'], ['runtimes', '运行时与磁盘']]],
    ['系统', [['workspace', '工作区'], ['notif', '通知'], ['about', '关于']]],
  ];

  function wireDetail(id, detail) {
    detail.classList.toggle('center', id === 'overview');
    // 段控通用交互
    detail.querySelectorAll('.st-seg').forEach(s => s.querySelectorAll('button').forEach(b => b.onclick = () => {
      s.querySelectorAll('button').forEach(x => x.classList.remove('on')); b.classList.add('on');
    }));
    if (id !== 'overview') return;
    // 概览:热力图 + 最常用实体
    const grid = detail.querySelector('#st-grid'), months = detail.querySelector('#st-months');
    const cols = 40, fills = ['var(--island-3)', 'rgba(0,113,227,.16)', 'rgba(0,113,227,.32)', 'rgba(0,113,227,.52)', 'rgba(0,113,227,.74)'];
    for (let w = 0; w < cols; w++) {
      const col = document.createElement('div'); col.className = 'st-col';
      for (let d = 0; d < 7; d++) {
        const c = document.createElement('div'); c.className = 'st-c';
        const r = Math.random(), wknd = (d === 0 || d === 6);
        let lvl = r > (wknd ? 0.62 : 0.34) ? 1 + Math.floor(Math.random() * 4) : 0;
        if (w < 4 && Math.random() > 0.45) lvl = 0;
        c.style.background = fills[lvl]; col.appendChild(c);
      }
      grid.appendChild(col);
    }
    ['7月', '8月', '9月', '10月', '11月', '12月', '1月', '2月', '3月', '4月', '5月', '6月'].forEach(m => {
      const s = document.createElement('span'); s.textContent = m; months.appendChild(s);
    });
    const ENTS = [['Researcher', 'agent', 312], ['fetch_news', 'function', 188], ['daily-digest', 'workflow', 142], ['inbox', 'handler', 96], ['每早 6 点', 'trigger', 61]];
    detail.querySelector('#st-ents').innerHTML = ENTS.map(([nm, ic, ct]) =>
      `<div class="st-erow"><span class="st-ei">${icon(ic, 16)}</span><span class="nm">${nm}<em>${ic}</em></span><span class="ct">${ct} 次</span></div>`).join('');
  }

  // ——— 注册为 Shell 海洋（接管海面）———
  Shell.registerOcean('settings', {
    crumb: '设置',
    build(sea) {
      const nav = CATS.map(([g, items]) => `<div class="st-grp">${g}</div>` +
        items.map(([id, label]) => `<div class="st-cat" data-cat="${id}"><span class="dot"></span>${label}</div>`).join('')).join('');
      sea.innerHTML = `<div class="st-root">
        <nav class="st-nav">
          <a class="st-back"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>返回 Foryx</a>
          <div class="st-search">${icon('search', 15)}<input placeholder="搜索设置…"></div>
          ${nav}
        </nav>
        <section class="st-detail" id="st-detail"></section>
      </div>`;
      const detail = sea.querySelector('#st-detail');
      const cats = sea.querySelectorAll('.st-cat');
      const show = id => {
        cats.forEach(c => c.classList.toggle('on', c.dataset.cat === id));
        detail.innerHTML = RENDER[id]();
        detail.scrollTop = 0;
        wireDetail(id, detail);
      };
      cats.forEach(c => c.onclick = () => show(c.dataset.cat));
      // ← 返回：回到来源海洋（chrome 暴露的 Shell.toOcean；缺则回 chat）
      sea.querySelector('.st-back').onclick = () => (Shell.toOcean || Shell.mount)(Shell._back || 'chat');
      show('overview');
    },
  });
  // 入口 = 侧栏底部头像（chrome 已接 .ws → mountSea('settings')）；本模块只负责注册设置海洋。
})();
