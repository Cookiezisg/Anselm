/* ============================================================================
   Anselm flow-graph · 模型层（与后端逐字对齐）
   - 图 = 可归约控制流图：前向边构成 DAG；回边只能从 control/approval 节点发出。
   - 节点 5 类；执行按 (node, iteration) 展开循环（回边 +1）。
   - 节点字段对齐 domain/workflow Node：{id, kind, ref, input(field→CEL), retry?, pos}。
   - 编辑动作生成后端 ops（add_node/update_node/delete_node/add_edge/update_edge/delete_edge）。
   纯模型，无 DOM。挂在 window.FG。
============================================================================ */
(function () {
  const FG = (window.FG = window.FG || {});

  /* ---- 几何（节点卡 + 布局间距），全部取自 Anselm 密度阶梯 ---- */
  FG.NW = 188; FG.NH = 60;            // 节点卡尺寸
  FG.GAPX = 84; FG.GAPY = 44;         // 层间 / 跨轴间距
  FG.PAD = 48;                        // 画布留白
  FG.STUB = 22;                       // 端口出线段（边离开节点的直段）
  FG.CORNER = 12;                     // 正交边圆角半径
  FG.LOOP_GAP = 26;                   // 回边通道间距

  /* ---- 节点类型（对齐 NodeKind*；色仅用于类型 chip，正文克制）---- */
  FG.KIND = {
    trigger:  { label: '触发',  c: 'var(--violet)', s: 'var(--violet-soft)', prefix: 'trg_', ico: 'M13 2 4 14h6l-1 8 9-12h-6z' },
    action:   { label: '动作',  c: 'var(--accent)', s: 'var(--accent-soft)', prefix: 'fn_',  ico: 'M4 5h16v14H4z M9 9l4 3-4 3' },
    agent:    { label: '智能体', c: 'var(--teal)',  s: 'var(--teal-soft)',   prefix: 'ag_',  ico: 'M12 3v4 M12 17v4 M3 12h4 M17 12h4 M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z' },
    control:  { label: '分支',  c: 'var(--warn)',   s: 'var(--warn-soft)',   prefix: 'ctl_', ico: 'M6 4v6a4 4 0 0 0 4 4h8 M18 10l3 4-3 4 M6 4 3 8m3-4 3 4' },
    approval: { label: '审批',  c: 'var(--danger)', s: 'var(--danger-soft)', prefix: 'apf_', ico: 'M12 3 4 6v5c0 4 3 7 8 9 5-2 8-5 8-9V6z M9 11l2 2 4-4' },
  };
  FG.KIND_ORDER = ['trigger', 'action', 'agent', 'control', 'approval'];

  /* ---- 运行态（对齐 flowrun NodeStatus + 派生 future/running 呈现态）---- */
  FG.STATE = {
    completed: { c: 'var(--ink-3)',  ring: 'var(--line)',        fill: 'var(--island)',   label: '已完成' },
    running:   { c: 'var(--accent)', ring: 'var(--accent-line)', fill: 'var(--island)',   label: '运行中' },
    failed:    { c: 'var(--danger)', ring: 'var(--danger)',      fill: 'var(--island)',   label: '失败' },
    parked:    { c: 'var(--warn)',   ring: 'var(--warn)',        fill: 'var(--island)',   label: '待审批' },
    future:    { c: 'var(--ink-3)',  ring: 'var(--line)',        fill: 'var(--island-2)', label: '未运行' },
    ready:     { c: 'var(--ink-3)',  ring: 'var(--line)',        fill: 'var(--island)',   label: '' },
  };

  /* ---- 工具 ---- */
  let _seq = 0;
  FG.uid = (p) => p + '_' + (Date.now().toString(36).slice(-4)) + (_seq++).toString(36);
  FG.clone = (g) => ({
    nodes: g.nodes.map(n => ({ ...n, input: { ...(n.input || {}) }, retry: n.retry ? { ...n.retry } : undefined })),
    edges: g.edges.map(e => ({ ...e })),
  });
  FG.nodeById = (g, id) => g.nodes.find(n => n.id === id);

  /* ============================ 纯图算法（与后端同义）============================ */

  // 回边：经典可归约回边判定（DFS 指向递归栈上节点的边）。同 domain/workflow BackEdges。
  FG.backEdges = function (g) {
    const out = {}; g.edges.forEach(e => (out[e.from] = out[e.from] || []).push(e));
    const color = {}, back = new Set();
    g.nodes.forEach(n => {
      if (color[n.id]) return;
      const st = [{ id: n.id, i: 0 }]; color[n.id] = 1;
      while (st.length) {
        const f = st[st.length - 1], es = out[f.id] || [];
        if (f.i >= es.length) { color[f.id] = 2; st.pop(); continue; }
        const e = es[f.i++], c = color[e.to] || 0;
        if (c === 1) back.add(e.id); else if (c === 0) { color[e.to] = 1; st.push({ id: e.to, i: 0 }); }
      }
    });
    return back;
  };

  // from 是否能沿现有边到达 to（用于判定新边是否闭环 = 回边）。
  FG.reachable = function (g, from, to) {
    const adj = {}; g.edges.forEach(e => (adj[e.from] = adj[e.from] || []).push(e.to));
    const seen = new Set([from]), q = [from];
    while (q.length) { const u = q.shift(); for (const v of (adj[u] || [])) { if (v === to) return true; if (!seen.has(v)) { seen.add(v); q.push(v); } } }
    return false;
  };

  // 连线校验（对齐后端 ValidateGraph 的环纪律 + 端口规则）。
  // 返回 { ok, isBack, port, reason }。
  FG.validateEdge = function (g, from, to) {
    if (from === to) return { ok: false, reason: '不允许自环（节点不能连自己）' };
    if (g.edges.some(e => e.from === from && e.to === to)) return { ok: false, reason: '已存在该连线' };
    const src = FG.nodeById(g, from);
    const isBack = FG.reachable(g, to, from); // to 已能到 from → 新边 from→to 闭环
    if (isBack && src.kind !== 'control' && src.kind !== 'approval')
      return { ok: false, reason: '回边只能从 control / approval 节点发出（循环须由分支决策闭合）' };
    let port = '';
    if (src.kind === 'control') {
      const used = g.edges.filter(e => e.from === from && e.port).length;
      port = isBack ? '重试' : '分支' + (used + 1);
    } else if (src.kind === 'approval') {
      const used = new Set(g.edges.filter(e => e.from === from).map(e => e.port));
      port = !used.has('yes') ? 'yes' : (!used.has('no') ? 'no' : '');
      if (!port) return { ok: false, reason: 'approval 只有 yes / no 两个出口' };
    }
    return { ok: true, isBack, port };
  };

  // 结构体检（编辑器侧即时反馈；后端 ValidateGraph 是最终权威）。返回问题数组。
  FG.lint = function (g) {
    const problems = [];
    const triggers = g.nodes.filter(n => n.kind === 'trigger');
    if (!triggers.length) problems.push('缺少 trigger 入口节点');
    // 可达性
    const adj = {}; g.edges.forEach(e => (adj[e.from] = adj[e.from] || []).push(e.to));
    const reached = new Set(); const q = triggers.map(n => n.id); q.forEach(id => reached.add(id));
    while (q.length) { const u = q.shift(); for (const v of (adj[u] || [])) if (!reached.has(v)) { reached.add(v); q.push(v); } }
    g.nodes.forEach(n => { if (!reached.has(n.id) && n.kind !== 'trigger') problems.push(`节点 ${n.id} 从 trigger 不可达`); });
    // control 末路兜底（建议）
    g.nodes.filter(n => n.kind === 'control').forEach(n => {
      const outs = g.edges.filter(e => e.from === n.id);
      if (outs.length && !outs.some(e => e.port === '兜底' || e.port === 'else' || e.port === 'true'))
        problems.push(`control ${n.id} 建议加一条兜底分支（when=="true"）`);
    });
    return problems;
  };

  /* ============================ 后端 ops 生成 ============================ */
  // 编辑动作 → 后端 workflow :edit 的 op（线上发什么这里就生成什么）。
  FG.ops = {
    addNode: (n) => ({ op: 'add_node', node: nodeWire(n) }),
    updateNode: (id, patch) => ({ op: 'update_node', id, patch }),
    deleteNode: (id) => ({ op: 'delete_node', id }),
    addEdge: (e) => ({ op: 'add_edge', edge: edgeWire(e) }),
    updateEdge: (id, patch) => ({ op: 'update_edge', id, patch }),
    deleteEdge: (id) => ({ op: 'delete_edge', id }),
  };
  function nodeWire(n) {
    const o = { id: n.id, kind: n.kind, ref: n.ref };
    if (n.input && Object.keys(n.input).length) o.input = n.input;
    if (n.retry) o.retry = n.retry;
    if (n.pos) o.pos = n.pos;
    return o;
  }
  function edgeWire(e) { const o = { id: e.id, from: e.from, to: e.to }; if (e.port) o.fromPort = e.port; return o; }

  /* ============================ 示例图（去坐标，全靠自动布局）============================ */
  const n = (id, kind, ref, input, retry) => ({ id, kind, ref, input: input || {}, retry });
  const e = (from, to, port) => ({ id: from + '>' + to, from, to, port: port || '' });

  FG.SAMPLES = {
    '研报抓取流 · 有循环': {
      nodes: [
        n('cron', 'trigger', '每日 02:00'),
        n('fetch', 'action', 'fetch_news', { since: 'cron.firedAt' }, { maxAttempts: 3, backoff: 'exponential', delayMs: 1000 }),
        n('parse', 'action', 'parse_pdf', { file: 'cron.payload' }),
        n('summarize', 'agent', 'research_agent', { sources: 'fetch.out', issues: 'parse.out', prev: 'route.feedback' }),
        n('route', 'control', 'route_by_score', { score: 'summarize.score' }),
        n('publish', 'action', 'slack_handler', { draft: 'summarize.out' }),
        n('notify', 'approval', 'manager_approval', { amount: 'summarize.amount' }),
      ],
      edges: [e('cron', 'fetch'), e('cron', 'parse'), e('fetch', 'summarize'), e('parse', 'summarize'),
        e('summarize', 'route'), e('route', 'publish', '发布'), e('route', 'notify', '审批'), e('route', 'summarize', '重试')],
      run: {
        state: { cron: 'completed', fetch: 'completed', parse: 'completed', summarize: 'running', route: 'completed', publish: 'future', notify: 'future' },
        taken: ['cron>fetch', 'cron>parse', 'fetch>summarize', 'parse>summarize', 'summarize>route', 'route>summarize'],
        live: 'route>summarize', iters: { summarize: 3 },
        memo: {
          cron: { out: 'fired 02:00' }, fetch: { out: '51 commits' }, parse: { out: '23 issues' },
          summarize: { loop: [['#0', 'draft v1 · 缺引用'], ['#1', 'draft v2 · 0.72 < 0.8'], ['#2', '生成中…']] },
          route: { __port: '重试', score: 0.72 },
        },
      },
    },
    '竞品监控流 · 等审批': {
      nodes: [n('web', 'trigger', 'PR Webhook'), n('crawl', 'action', 'fetch_news', { url: 'web.payload' }),
        n('diff', 'agent', 'summarizer', { html: 'crawl.out' }), n('gate', 'approval', 'manager_approval', { change: 'diff.out' }),
        n('alert', 'action', 'slack_handler', { msg: 'diff.out' })],
      edges: [e('web', 'crawl'), e('crawl', 'diff'), e('diff', 'gate'), e('gate', 'alert', 'yes')],
      run: {
        state: { web: 'completed', crawl: 'completed', diff: 'completed', gate: 'parked', alert: 'future' },
        taken: ['web>crawl', 'crawl>diff', 'diff>gate'], live: null, iters: {},
        memo: { web: { out: 'PR #482' }, crawl: { out: '竞品 3 处改动' }, diff: { out: '降价 12%' },
          gate: { parked: true, prompt: '检测到竞品定价页改动（降价 12%）。是否推送告警并触发应对评审？', ddl: '自动驳回 22h', form: 'manager_approval v4' } },
      },
    },
    '账单对账流 · 失败': {
      nodes: [n('in', 'trigger', 'Webhook'), n('extract', 'action', 'process_invoice', { pdf: 'in.payload' }, { maxAttempts: 2, backoff: 'fixed', delayMs: 500 }),
        n('match', 'action', 'db_pool', { rows: 'extract.out' }), n('post', 'action', 'db_pool', { matched: 'match.out' })],
      edges: [e('in', 'extract'), e('extract', 'match'), e('match', 'post')],
      run: {
        state: { in: 'completed', extract: 'failed', match: 'future', post: 'future' }, taken: ['in>extract'], live: null, iters: {},
        memo: { in: { out: '12 张发票' }, extract: { error: 'SandboxError: 依赖物化超时（pdfplumber 38s > 30s）' } },
      },
    },
    '多分支审批 · 复杂': {
      nodes: [n('hook', 'trigger', '订单 Webhook'), n('enrich', 'action', 'enrich_order', { id: 'hook.payload' }),
        n('risk', 'agent', 'risk_agent', { order: 'enrich.out', fix: 'fix.out' }), n('gate', 'control', 'route_risk', { score: 'risk.score' }),
        n('auto', 'action', 'auto_approve', { order: 'enrich.out' }), n('human', 'approval', 'ops_review', { order: 'enrich.out', risk: 'risk.out' }),
        n('fix', 'agent', 'remediation', { issues: 'human.reason' }), n('done', 'action', 'finalize', { order: 'enrich.out' })],
      edges: [e('hook', 'enrich'), e('enrich', 'risk'), e('risk', 'gate'),
        e('gate', 'auto', 'low'), e('gate', 'human', 'high'), e('gate', 'risk', 'rescore'),
        e('auto', 'done'), e('human', 'done', 'yes'), e('human', 'fix', 'no'), e('fix', 'risk')],
      run: {
        state: { hook: 'completed', enrich: 'completed', risk: 'completed', gate: 'completed', auto: 'future', human: 'parked', fix: 'future', done: 'future' },
        taken: ['hook>enrich', 'enrich>risk', 'risk>gate', 'gate>human'], live: null, iters: { risk: 2 },
        memo: { hook: { out: '#9921' }, enrich: { out: '已补全' }, risk: { out: 'score 0.81', score: 0.81 }, gate: { __port: 'high', score: 0.81 },
          human: { parked: true, prompt: '高风险订单 #9921（0.81）。是否人工放行？', ddl: '自动驳回 8h', form: 'ops_review v2' } },
      },
    },
    '空白 · 从零搭': { nodes: [n('start', 'trigger', 'trg_manual')], edges: [], run: { state: {}, taken: [], live: null, iters: {}, memo: {} } },
  };
})();
