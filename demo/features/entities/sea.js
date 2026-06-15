/* Forgify demo — 实体海洋海面：薄组合（产品级详情/编辑平台，移植 design-lab entities 终极重做形态）。
   窄阅读列 + 大留白 + 字号阶梯（同源 documents 美学）；像素全在组件库——
   CodeEditor(代码/class/prompt/template/playbook) + Tags(deps/tools/triggers/outputs/knowledge/allowed) + KV(runtime/model/rules/frontmatter/connection)
   + ThinTable(IO/methods/init-args/exposed tools) + Tabs(概览/版本/运行/迭代) + VersionDiff(版本 tab) + RunGraph(workflow 图) + RunDebug(试运行) + Attention(警示) + StatusDot/RefPill。
   选中通道：侧栏实体行 → Intent.select({kind:'entity'}) → 本海洋 Intent.on('entity') morph 成该实体；
            workflow 图节点点击 → RightIsland 检视记忆化引用；关系/反链 → Intent.select 跳归属海洋。
   依赖 mock/entities.js + config/entity-kinds.js + config/state-model.js。注册 Shell.registerOcean('entities')。 */
(function () {
  if (window.cssNextTo) cssNextTo(document.currentScript);
  const D = () => window.MOCK_ENTITIES || {};
  const K = () => window.ENTITY_KINDS || {};
  const esc = s => String(s == null ? '' : s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

  let stage, island, curId;

  // faux 后端 ID（<prefix>_<hex>，S15）：稳定哈希实体名，纯展示
  function fauxId(kind, id) {
    let h = 2166136261; for (const c of id) { h ^= c.charCodeAt(0); h = (h * 16777619) >>> 0; }
    return ((K()[kind] || {}).prefix || 'en') + '_' + h.toString(16).padStart(8, '0');
  }

  // ===== 薄分节：小标签 + 内容直接铺白底（无盒，靠留白）=====
  function sec(host, label, cnt) {
    const s = tag('div.ent-sec', `<div class="ent-h"><span>${esc(label)}</span>${cnt != null ? `<span class="ent-cnt">${cnt}</span>` : ''}</div>`);
    host.appendChild(s);
    return s;
  }
  function prose(host, value, cls) {
    const p = tag('div.' + (cls || 'ent-desc'));
    p.contentEditable = 'true'; p.spellcheck = false; p.textContent = value || '';
    p.addEventListener('input', markDirty);
    host.appendChild(p);
    return p;
  }
  // 细线表格 IO 行：名(+必填星) / 类型
  const ioRows = arr => arr.map(f => [`<span class="ent-nm">${esc(f[0])}</span>${f[2] ? '<span class="ent-req">*</span>' : ''}`, `<span class="ent-ty">${esc(f[1])}</span>`]);

  // dirty / 保存态（保存指示在 headExtra；dirty 类挂 .ent-saved 直接染 accent）
  let savedEl = null;
  function markDirty() {
    if (savedEl) { savedEl.classList.add('dirty'); savedEl.innerHTML = `<span class="ent-saved-ic">${icon('edit', 13)}</span>未保存`; }
  }

  // ===== 关系/反链（RightIsland body 内容；行点击 → Intent.select 跳归属海洋）=====
  function relations(host, groups) {
    (groups || []).forEach(g => {
      const s = tag('div.ent-rel-sec', `<div class="ent-rel-h">${esc(g.title)}</div>`);
      if (!g.rows.length) s.appendChild(tag('div.ent-none', '— 无 —'));
      g.rows.forEach(r => {
        const ico = (K()[r.kind] || {}).icon || r.kind || 'link';
        const row = tag('div.ent-rel-row', `<span class="ent-rel-ico">${icon(ico, 14)}</span><span class="ent-rel-n">${esc(r.name)}</span><span class="ent-rel-m">${esc(r.meta || '')}</span>`);
        // 反链行 → 统一意图通道（实体类型即 kind；conversation/run 等非实体走各自归属海洋）
        if (K()[r.kind]) row.onclick = () => Intent.select({ kind: 'entity', id: r.name });
        else if (r.kind === 'conversation') row.onclick = () => Intent.select({ kind: 'conversation', id: r.meta || r.name });
        else if (r.kind === 'workflow') row.onclick = () => Intent.select({ kind: 'workflow', id: r.name });
        s.appendChild(row);
      });
      host.appendChild(s);
    });
  }

  // ===== workflow 图节点检视（RightIsland body）=====
  function openNode(wf, nodeId) {
    const nd = wf.nodes.find(x => x.id === nodeId) || {};
    const st = (wf.state || {})[nodeId] || 'future';
    const refKind = nd.kind === 'action' ? 'function' : nd.kind;
    if (!island) island = RightIsland.create('entities', { title: nodeId, icon: (window.NODE_ICON || {})[nd.kind] || 'action' });
    island.setHead(`<span class="fg-island-ico">${icon((window.NODE_ICON || {})[nd.kind] || 'action', 17)}</span>
      <span class="ent-ndh"><b>${esc(nodeId)}</b><span class="ent-ndsub">${esc(nd.kind || '')} · ${StatusDot.dot(st)} ${StatusDot.label(st)}</span></span>
      <button class="fg-island-x" type="button">${icon('close', 16)}</button>`);
    island.head.querySelector('.fg-island-x').onclick = () => island.hide();
    const b = island.body; b.innerHTML = '';
    if (nd.ref) {
      const r = tag('div.ent-ndref', `引用 ${RefPill.html(refKind, nd.ref, nd.ref)}`);
      RefPill.wire(r);
      b.appendChild(r);
    }
    const cel = tag('div.ent-fld', `<label>${nd.kind === 'control' ? '分支条件 (CEL)' : 'Input 映射 (CEL)'}</label>`);
    b.appendChild(cel);
    CodeEditor.mount(cel, { code: nd.kind === 'control' ? 'amount > 1000' : 'input: ctx.upstream.result', corner: 'cel' });
    island.show();
  }

  // ===================== 各类型概览 =====================
  const ENV_GATE = { pending: '排队', syncing: '物化中', failed: '失败' };
  const OVER = {
    function(b, a) {
      prose(b, a.desc);
      CodeEditor.mount(sec(b, 'Code'), { code: a.code, corner: a.lang, onDirty: markDirty });
      RunDebug.mount(sec(b, '调试运行'), a.env === 'ready'
        ? { argsSeed: '{\n  "currency": "USD"\n}', verb: 'Run', vico: 'play', trace: { lines: ['→ spawn sandbox (python 3.12)', '→ exec process_invoice()', 'stdout: parsed 14 line items', 'stdout: validated ✓'], result: { st: 'ok', out: '{ "vendor": "Acme Inc", "total": 1284.50, "tax_id": "US-99-1" }', ms: 412 } } }
        : { gate: '环境' + (ENV_GATE[a.env] || a.env) + ' — 就绪后可运行' });
      const g = tag('div.ent-2col'); b.appendChild(g);
      ThinTable.table(sec(g, 'Inputs', a.inputs.length), ['参数', '类型'], ioRows(a.inputs));
      ThinTable.table(sec(g, 'Output'), ['返回', '字段'], a.output.map(o => [`<span class="ent-nm">${esc(o[0])}</span>`, `<span class="ent-ty">${esc(o[1])}</span>`]));
      Tags.mount(sec(b, 'Dependencies', a.deps.length), { items: a.deps, onChange: markDirty });
      const env = sec(b, 'Environment');
      const r = tag('div.ent-envrow', `${StatusDot.badge('ENV', a.env)}<span class="ent-note">上次：${esc(a.lastRun || '—')}</span><button class="ent-mini">${icon('spin', 13)}Rebuild env</button>`);
      env.appendChild(r);
    },
    handler(b, a) {
      prose(b, a.desc);
      KV.defs(sec(b, 'Runtime'), [
        ['Runtime', '', { html: a.life === 'active' ? `${StatusDot.dot('done')}<span class="ent-inlabel">运行中</span>` : `${StatusDot.dot('idle')}<span class="ent-inlabel">未上线</span>` }],
        ['Config', '', { html: StatusDot.badge('CFG', a.cfg) }],
        ['Env', '', { html: StatusDot.badge('ENV', a.env) }],
      ]);
      CodeEditor.mount(sec(b, 'Assembled class'), { code: a.code, corner: a.lang, onDirty: markDirty });
      ThinTable.table(sec(b, 'Methods', a.methods.length), ['方法', '签名', ''], a.methods.map(m => [`<span class="ent-nm">${esc(m[0])}</span>`, `<span class="ent-ty">${esc(m[1])}</span>`, `<span class="ent-act">Call ›</span>`]));
      const t = ThinTable.table(sec(b, 'Init args'), ['参数', '值'], a.initArgs.map(([k, v, s]) => [`<span class="ent-nm">${esc(k)}</span>`, s ? { edit: true, html: '<span class="ent-mask">••••••••</span>' } : { edit: true, html: esc(v || '') }]));
      t.insertAdjacentHTML('afterend', '<div class="ent-note ent-note-mt">改 config 触发重启</div>');
    },
    agent(b, a) {
      if (a.tools.some(t => t.health === 'bad')) {
        const w = tag('div', Attention.html('shield', '挂载工具 <b>cite</b> 不可解析，invoke 时将跳过。', { tone: 'warn' }));
        b.appendChild(w.firstElementChild);
      }
      prose(b, a.desc);
      prose(sec(b, 'System prompt'), a.system, 'ent-block');
      Tags.mount(sec(b, 'Mounted tools', a.tools.length), { items: a.tools, icon: 'code', onChange: markDirty });
      const g = tag('div.ent-2col'); b.appendChild(g);
      KV.defs(sec(g, 'Model'), [['model', a.model, { edit: true, mono: true }], ['maxSteps', a.maxSteps, { edit: true, mono: true }]]);
      Tags.mount(sec(g, 'Skill · 0–1'), { items: a.skill ? [a.skill] : [], icon: 'skill', mode: 'single', addLabel: '挂技能', onChange: markDirty });
      Tags.mount(sec(b, 'Knowledge', a.knowledge.length), { items: a.knowledge, onChange: markDirty });
      RunDebug.mount(sec(b, '调试调用'), { argsSeed: '{\n  "query": "竞品近况",\n  "scope": "2026"\n}', verb: 'Invoke', vico: 'play', trace: { lines: ['mount-health: 4/5 ok（cite 跳过）', '⟐ reasoning…', '→ tool web_search("竞品近况 2026")', '→ tool fetch_url(...)', '⟐ 综述生成中…'], result: { st: 'ok', out: 'stopReason=end · 6 steps · 1.2k→3.4k tok', ms: 8800 } } });
    },
    workflow(b, a) {
      if (a.attention) {
        const w = tag('div', Attention.html('shield', a.attention, { tone: 'warn' }));
        b.appendChild(w.firstElementChild);
      }
      if (a.desc) prose(b, a.desc);
      const graphSec = sec(b, 'Graph', a.nodes.length + ' 节点');
      const gwrap = tag('div.ent-gwrap');
      graphSec.appendChild(gwrap);
      RunGraph.render(gwrap, {
        nodes: a.nodes, edges: a.edges, loopbacks: a.loopbacks, vb: a.vb,
        state: a.state, taken: a.taken, live: a.live, iters: a.iters, ports: a.ports,
        onNode: id => openNode(a, id),
      });
      gwrap.insertAdjacentHTML('beforeend', '<div class="ent-ghint">点击节点检视引用与记忆化结果 · 深度运行历史在 Scheduler 海</div>');
      const g = tag('div.ent-2col'); b.appendChild(g);
      KV.defs(sec(g, 'Run'), [
        ['lifecycle', '', { html: a.life === 'active' ? `${StatusDot.dot('run')}<span class="ent-inlabel">已激活</span>` : `${StatusDot.dot('idle')}<span class="ent-inlabel">未上线</span>` }],
        ['concurrency', a.concurrency, { edit: true, mono: true }],
      ]);
      Tags.mount(sec(g, 'Triggers', a.triggers.length), { items: a.triggers, icon: 'trigger', onChange: markDirty });
    },
    trigger(b, a) {
      prose(b, a.desc);
      KV.defs(sec(b, 'Signal source'), a.cfg.map(([k, v, mask]) => [k, v, mask ? { mask: true } : { edit: true, mono: true }]));
      Tags.mount(sec(b, 'Outputs', a.outputs.length), { items: a.outputs, onChange: markDirty });
      RunDebug.mount(sec(b, '调试 · Fire now'), { verb: 'Fire', vico: 'zap', trace: { lines: ['fanned to 1 workflow', 'trf_8a → nightly_report → started', 'flowrun fr_4c2 created'], result: { st: 'ok', out: 'fired · 1 firing · 0 skipped', ms: 42 } } });
    },
    control(b, a) {
      prose(b, a.desc);
      const br = sec(b, 'Branches · 首个为真胜出', a.branches.length);
      a.branches.forEach((x, i) => {
        const row = tag('div.ent-branch', `<span class="ent-bn">${i + 1}</span><span class="ent-bwhen">${CodeEditor.highlight(x[0])}</span><span class="ent-bport">→ ${esc(x[1])}</span>`);
        br.appendChild(row);
      });
      br.appendChild(tag('div.ent-branch.catchall', `<span class="ent-bn">·</span><span class="ent-bwhen">true</span><span class="ent-bport">→ default</span>`));
      ThinTable.table(sec(b, 'Inputs (CEL namespace)', a.inputs.length), ['参数', '类型'], ioRows(a.inputs));
      RunDebug.mount(sec(b, '调试 · Probe（内联求值，不落运行）'), { argsSeed: '{ "amount": 1500 }', verb: 'Evaluate', vico: 'play', trace: { lines: ['branch 1: amount > 1000 → ✓ 命中', 'branch 2: 不再求值'], result: { st: 'ok', out: '→ port "approve"', ms: 3 } } });
    },
    approval(b, a) {
      prose(b, a.desc);
      CodeEditor.mount(sec(b, 'Template · {{input.*}} 插值'), { code: a.template, corner: 'jinja+cel', onDirty: markDirty });
      const g = tag('div.ent-2col'); b.appendChild(g);
      KV.defs(sec(g, 'Decision rules'), a.rules.map(([k, v]) => [k, v, { edit: true, mono: true }]));
      ThinTable.table(sec(g, 'Input schema', a.inputs.length), ['字段', '类型'], ioRows(a.inputs));
      RunDebug.mount(sec(b, '调试 · Render & decide'), { argsSeed: '{ "vendor":"Acme", "total":1284.5, "currency":"USD" }', verb: 'Render', vico: 'play', trace: { lines: ['解析 {{input.*}} → 渲染 markdown', 'emit parked · 待决策 · 24h 后 reject'], result: { st: 'ok', out: 'parked → 等待人工 通过/驳回', ms: 6 } } });
    },
    mcp(b, a) {
      prose(b, a.desc);
      KV.defs(sec(b, 'Connection'), [
        ['status', '', { html: StatusDot.badge('CONN', a.conn) }],
        ...a.cfg.map(([k, v, mask]) => [k, v, mask ? { mask: true } : { edit: true, mono: true }]),
        ['calls / fails', `${a.calls} / ${a.fails}`, { mono: true }],
      ]);
      ThinTable.table(sec(b, 'Exposed tools', a.tools.length), ['工具', ''], a.tools.map(t => [`<span class="ent-nm">${esc(t)}</span>`, `<span class="ent-act">Invoke ›</span>`]));
    },
    skill(b, a) {
      prose(b, a.desc);
      CodeEditor.mount(sec(b, 'Playbook · $n / ${...} 插值'), { code: a.body, corner: 'markdown', onDirty: markDirty });
      const g = tag('div.ent-2col'); b.appendChild(g);
      KV.defs(sec(g, 'Frontmatter'), a.frontmatter.map(([k, v]) => [k, v, { edit: true, mono: true }]));
      Tags.mount(sec(g, 'Allowed tools', a.allowed.length), { items: a.allowed, icon: 'code', onChange: markDirty });
      RunDebug.mount(sec(b, '调试 · Render（技能是注入、非执行）'), { argsSeed: '$1 = "竞品调研"', verb: 'Render', vico: 'play', trace: { lines: ['替换 $1 → "竞品调研"', '替换 ${CLAUDE_SESSION_ID}', '注入 agent system-prompt 的 ## Execution guide'], result: { st: 'ok', out: '已展开 · 注入 312 字', ms: 2 } } });
    },
  };

  // ===================== 版本 / 运行 / 迭代 tab =====================
  function tabVersions(b, a) {
    if (a.kind === 'function') return VersionDiff.mount(b, { versions: a.versions, field: 'code', caption: 'Function 版本 diff · 非 git' });
    // 非 function：取当前主体字段 + 上一次保存作两版 diff（trigger/mcp/skill 标无版本）
    const cur = a.code || a.system || a.template || a.body || (a.branches ? a.branches.map(x => x.join(' → ')).join('\n') : JSON.stringify(a.cfg || {}, null, 2));
    const verLess = ['trigger', 'mcp', 'skill'].includes(a.kind);
    const cap = verLess
      ? (a.kind === 'skill' ? '保存文件 diff · 无版本' : (a.kind === 'mcp' ? '连接配置 diff · 无版本 · 外部 server' : '配置编辑 · 无版本 · Trigger 不入版本'))
      : (K()[a.kind].label + ' 版本 diff · 非 git');
    VersionDiff.mount(b, {
      versions: [
        { v: a.version || 1, active: true, t: '当前', reason: '当前', _: cur },
        { v: (a.version || 2) - 1, t: '更早', reason: '上一次保存', _: cur.split('\n').slice(0, -1).join('\n') },
      ],
      field: v => v._, caption: cap,
    });
  }
  function tabRuns(b, a) {
    const ex = a.execs || [['ok', 'manual', '120ms', '刚刚'], ['ok', 'workflow', '98ms', '今天'], ['failed', 'manual', '—', '昨天']];
    const ok = ex.filter(e => e[0] === 'ok').length;
    b.appendChild(tag('div.ent-agg', `<span><b>${ex.length}</b> 次</span><span><b class="ok">${ok}</b> 成功</span><span><b class="bad">${ex.length - ok}</b> 失败</span>`));
    const led = tag('div.ent-led'); b.appendChild(led);
    ex.forEach((e, i) => {
      const cst = e[0] === 'ok' ? 'done' : 'err';
      led.appendChild(tag('div.ent-lrow', `${StatusDot.dot(cst, { size: 7 })}<span class="ent-cid">${a.kind}e_${(i + 7).toString(16)}a${i}</span><span class="ent-ctrig">${esc(e[1])}</span><span class="ent-cmeta">${esc(e[3])}</span><span class="ent-cdur">${esc(e[2])}</span>`));
    });
    const note = tag('div.ent-sched', `${icon('scheduler', 14)}深度运行历史在 <span class="ent-lnk" data-s>Scheduler 海</span>`);
    b.appendChild(note);
    note.querySelector('[data-s]').onclick = () => Shell.toOcean && Shell.toOcean('scheduler');
  }
  function tabIterate(b) {
    b.appendChild(tag('div.ent-none', '迭代 = 在对话里让 AI 改这个实体（:iterate → conversationId）。形态见 Chat 海洋右岛实体卡流式编辑。'));
  }

  function tabsFor(a) {
    const t = [{ key: 'o', label: '概览', render: bd => OVER[a.kind](bd, a) }];
    const verLess = ['trigger', 'mcp', 'skill'].includes(a.kind);
    if (a.kind !== 'mcp') t.push({ key: 'v', label: verLess ? (a.kind === 'skill' ? '历史' : '编辑历史') : '版本', render: bd => tabVersions(bd, a) });
    if (!['control', 'approval', 'skill'].includes(a.kind)) t.push({ key: 'r', label: a.kind === 'handler' ? '调用' : '运行', render: bd => tabRuns(bd, a) });
    t.push({ key: 'rel', label: '关系', render: bd => relations(bd, a.rel || [{ title: 'Referenced by', rows: [] }]) });
    t.push({ key: 'i', label: '迭代', render: bd => tabIterate(bd) });
    return t;
  }

  // ===================== 详情（文档头 + headExtra 操作 + Tabs）=====================
  function detail(id) {
    const a = D()[id];
    if (!a) return empty();
    curId = id;
    if (island) island.hide();
    const k = K()[a.kind] || K().function;

    const meta = [];
    if (a.version != null) meta.push(`v${a.version}`);
    meta.push(`<span class="ent-st-in">${StatusDot.dot(a.status || 'idle')}<span>${StatusDot.label(a.status || 'idle')}</span></span>`);
    if (a.life) meta.push(`<span class="ent-life${a.life === 'active' ? ' active' : ''}">${a.life === 'active' ? '已激活' : '未上线'}</span>`);
    if (a.runs != null) meta.push(`${a.runs} runs`);
    meta.push(`<span class="ent-mono">${fauxId(a.kind, id)}</span>`);
    if (a.path) meta.push(`<span class="ent-mono">${esc(a.path)}</span>`);

    stage.innerHTML = `<div class="ent-doc ent-morph">
      <div class="ent-path"><span class="ent-path-ic">${icon(k.icon, 13)}</span><span>${esc(k.label)}</span><span class="ent-sep">/</span><span>${esc(id)}</span></div>
      <div class="ent-title" contenteditable="true" spellcheck="false">${esc(id)}</div>
      <div class="ent-meta">${meta.join('<span class="ent-sep">·</span>')}</div>
      <div class="ent-tabwrap"></div>
    </div>`;
    stage.querySelector('.ent-title').addEventListener('input', markDirty);

    // headExtra 操作（顶栏右上，对齐 documents）：保存态 + 执行动词钮 + 迭代 + 更多
    Shell.headExtra(`<span class="ent-saved"><span class="ent-saved-ic">${icon('check', 13)}</span>已保存</span>${k.verb ? `<button class="ent-run" data-run>${icon(k.vico, 13)}${k.verb}</button>` : ''}<button class="ibtn" data-iter title="迭代（AI 改）">${icon('spark', 16)}</button><button class="ibtn" data-more title="更多">${icon('more', 16)}</button>`);
    savedEl = Shell.headExtra ? document.querySelector('#head-extra .ent-saved') : null;
    const iterBtn = document.querySelector('#head-extra [data-iter]');
    if (iterBtn) iterBtn.onclick = () => Intent.act({ verb: 'iterate', kind: 'entity', id });

    Tabs.mount(stage.querySelector('.ent-tabwrap'), tabsFor(a));
    const sc = document.querySelector('#entScroll'); if (sc) sc.scrollTop = 0;
  }

  function empty() {
    curId = null;
    if (island) island.hide();
    if (Shell.headExtra) Shell.headExtra('');
    const cnt = kind => Object.values(D()).filter(e => e.kind === kind).length;
    const stat = (kind, l) => `<span class="ent-stat"><b>${cnt(kind)}</b><span>${l}</span></span>`;
    stage.innerHTML = `<div class="ent-empty"><div class="ent-empty-in ent-morph"><div class="ent-empty-ic">${icon('entities', 24)}</div><h2>四项全能实体</h2><p>Function · Handler · Agent · Workflow——及组成图的触发器、控制、审批、连接器与技能。<br>从左侧选一个：看全貌、抓必要信息、就地调试与修改。</p><div class="ent-stats">${stat('function', 'Functions')}${stat('handler', 'Handlers')}${stat('agent', 'Agents')}${stat('workflow', 'Workflows')}</div></div></div>`;
  }

  Shell.registerOcean('entities', {
    crumb: '实体',
    build(sea) {
      sea.innerHTML = `<div class="ent"><div class="ent-scroll scroll-fade" id="entScroll"><div id="entStage"></div></div></div>`;
      stage = sea.querySelector('#entStage');
      detail('process_invoice');   // 默认开首个 function（与侧栏默认高亮同步）
    },
  });

  // 选中通道：侧栏实体行 / 关系反链 → Intent.select({kind:'entity'}) → morph 成该实体
  Intent.on('entity', sel => { if (stage) detail(sel.id); });
})();
