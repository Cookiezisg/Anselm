/* Forgify design-lab — 【Entities 海洋】的左侧栏内容（独立文件，一人负责；与外壳/别的海洋解耦）。
   外壳 sidebar.js 据四导航懒加载本文件；自注入 entities.css，经 SideBar.register('entities', render) 挂载。
   形态：New + 搜索 → 竖向折叠树「分组(可折叠) → 类型(可展开) → 实体行」。
   行复用 Chat 状态点 .en-st(idle/run/wait/err/done),按实体重映射;skill 无状态点(文件式),只标 allowed-tools 数。
   侧栏=实体列表导航;点行→右岛开实体卡(此处示意选中高亮)。执行/运行记录归 Scheduler、memory 归 Settings。
   类名全 en- 前缀,勿与 chat(cv-/cm-)及海洋海面 CSS 撞名。 */
(function () {
  const dir = new URL('.', document.currentScript.src).href;
  if (!document.querySelector('link[data-sb="entities"]')) {
    const l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = dir + 'entities.css'; l.dataset.sb = 'entities';
    document.head.appendChild(l);
  }

  // 分组 → 类型(icon/label)。approval 借 shield。
  const GROUPS = [
    ['Quadrinity', [['fn', 'Functions', 'function'], ['hd', 'Handlers', 'handler'], ['ag', 'Agents', 'agent'], ['wf', 'Workflows', 'workflow']]],
    ['Graph parts', [['trg', 'Triggers', 'trigger'], ['ctl', 'Controls', 'control'], ['apf', 'Approvals', 'shield']]],
    ['Connections', [['mcp', 'MCP', 'mcp']]],
    ['Skills', [['skill', 'Skills', 'skill']]],
  ];

  // 示意数据。接后端：各实体 GET list(分页);状态点冷启动取 REST 初值、entities/notifications 流跳变。
  // st → 五态(done绿=就绪 / run蓝脉冲=锻造·监听 / wait橙脉冲=需处理 / err红=失败 / idle空心=闲置)
  const ENTS = [
    { ty: 'fn', name: 'process_invoice', ver: 5, st: 'done', on: true },
    { ty: 'fn', name: 'fetch_news', ver: 2, st: 'run' },
    { ty: 'fn', name: 'parse_pdf', ver: 1, st: 'err' },
    { ty: 'hd', name: 'slack_handler', ver: 3, st: 'done' },
    { ty: 'hd', name: 'db_pool', ver: 2, st: 'wait' },
    { ty: 'ag', name: 'research_agent', ver: 2, st: 'idle' },
    { ty: 'ag', name: 'summarizer', ver: 4, st: 'idle' },
    { ty: 'wf', name: 'nightly_report', ver: 8, st: 'run' },
    { ty: 'wf', name: 'invoice_flow', ver: 3, st: 'wait' },
    { ty: 'wf', name: 'archive_cleanup', ver: 1, st: 'idle' },
    { ty: 'trg', name: 'cron_2am', st: 'run' },
    { ty: 'trg', name: 'webhook_pr', st: 'idle' },
    { ty: 'ctl', name: 'route_by_amount', ver: 2, st: 'idle' },
    { ty: 'apf', name: 'manager_approval', ver: 4, st: 'idle' },
    { ty: 'mcp', name: 'github_mcp', st: 'done' },
    { ty: 'mcp', name: 'linear_mcp', st: 'wait' },
    { ty: 'skill', name: 'deep_research', tools: 3 },
    { ty: 'skill', name: 'pdf_extract', tools: 1 },
  ];
  const OPEN_TYPES = new Set(['fn']);   // 默认展开 Functions 作示意;其余类型折叠

  const row = e => {
    const dot = e.ty === 'skill' ? `<span class="en-st none"></span>` : `<span class="en-st ${e.st || 'idle'}"></span>`;
    const meta = e.ty === 'skill' ? `<span class="en-tools">⚷ ${e.tools}</span>` : (e.ver ? `<span class="en-ver">v${e.ver}</span>` : '');
    return `<div class="en${e.on ? ' on' : ''}">${dot}<span class="en-t">${e.name}</span>${meta}<span class="en-more">${icon('more', 16)}</span></div>`;
  };

  const typeSec = ([id, label, ic]) => {
    const items = ENTS.filter(e => e.ty === id);
    return `<div class="en-ty collapsible${OPEN_TYPES.has(id) ? ' open' : ''}">
      <button class="tog en-ty-h"><span class="chev">${icon('chevr', 13)}</span><span class="en-ty-ico">${icon(ic, 15)}</span><span class="en-lbl">${label}</span><span class="cnt">${items.length}</span></button>
      <div class="cbody">${items.map(row).join('')}</div></div>`;
  };

  const groupSec = ([g, types]) => {
    const total = types.reduce((n, [id]) => n + ENTS.filter(e => e.ty === id).length, 0);
    return `<div class="en-grp collapsible open">
      <button class="tog en-grp-h"><span class="en-lbl">${g}</span><span class="cnt">${total}</span><span class="chev">${icon('chevr', 13)}</span></button>
      <div class="cbody">${types.map(typeSec).join('')}</div></div>`;
  };

  function render(host) {
    host.innerHTML = `
      <button class="en-new">${icon('plus', 18)}<span>New entity</span></button>
      <div class="en-filter">${icon('search', 16)}<input type="text" placeholder="Search entities…"></div>
      <div class="en-tree">${GROUPS.map(groupSec).join('')}</div>`;
    // 折叠:每个 .tog 切最近的 .collapsible(分组 / 类型 两层通用)
    host.querySelectorAll('.tog').forEach(h => h.onclick = () => h.closest('.collapsible').classList.toggle('open'));
    // 选中实体行(接后端 → 右岛开实体卡)
    host.querySelectorAll('.en').forEach(it => it.onclick = e => {
      if (e.target.closest('.en-more')) return;
      host.querySelectorAll('.en').forEach(x => x.classList.remove('on')); it.classList.add('on');
    });
    // 标题快滤:隐藏未命中行;过滤期间有命中的类型自动展开
    const fin = host.querySelector('.en-filter input');
    fin.oninput = () => {
      const q = fin.value.trim().toLowerCase();
      host.querySelectorAll('.en-ty').forEach(sec => {
        let any = false;
        sec.querySelectorAll('.en').forEach(en => { const hit = en.querySelector('.en-t').textContent.toLowerCase().includes(q); en.style.display = hit ? '' : 'none'; if (hit) any = true; });
        if (q) sec.classList.toggle('open', any);
      });
    };
  }

  SideBar.register('entities', render);
})();
