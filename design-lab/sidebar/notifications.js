/* Forgify design-lab — 【通知 Inbox】侧栏接管内容（独立文件，一人负责；与外壳/海洋解耦）。
   外壳 sidebar.js 的铃铛点击 → SideBar.mount('notifications') 接管 #sidebody（镜像 settings 接管海面）。
   本文件自注入 notifications.css，经 SideBar.register('notifications', render) 挂载；只碰 render(host) 宿主 + 外壳暴露的 SideBar.exitNotif / SideBar.setUnread。
   后端事实：notifications 流唯一 durable actionable = workflow.approval_pending（→ /flowruns/{id}/approvals/{node}:decide）；
   其余 15 类均 FYI 生命周期（function/handler/agent/workflow/skill/mcp/document/conversation/memory/sandbox 增删改）；
   后端无人类可读文案/严重级——文案+状态点由前端按 type+payload 自渲（此处用示意数据）。 */
(function () {
  // 自注入样式（自包含，只加载一次）
  const dir = new URL('.', document.currentScript.src).href;
  if (!document.querySelector('link[data-sb="notifications"]')) {
    const l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = dir + 'notifications.css'; l.dataset.sb = 'notifications';
    document.head.appendChild(l);
  }

  const BACK = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>';

  // ① 待决：仅 workflow.approval_pending（唯一 actionable）。prompt 真身=停泊 flowrun_nodes 行上的 markdown，此处示意。
  const NEEDS = [
    { id: 'fr_a1', t: '竞品动态日报流程 · 发布前过目', time: '14:05', ic: 'workflow',
      prompt: '即将向 #marketing 发布今日 3 条竞品动态摘要，确认内容无误后批准。\n\n· 来源：fetch_news（function）\n· 条数：3\n· 去向：Slack #marketing' },
    { id: 'fr_a2', t: '账单对账流程 · 金额超阈值确认', time: '昨天', ic: 'workflow',
      prompt: '本月对账差额 ¥1,280 超过自动通过阈值 ¥1,000，需人工确认后继续入账。' },
  ];

  // ② 时间线：FYI 生命周期，按日期分组（newest-first，对齐后端 List）。st: done 绿/err 红/idle 空环；unread 靠字色明暗。
  const GROUPS = [
    ['今天', [
      { type: 'handler.crashed',        t: 'Webhook 入库 handler 崩溃（已自动重启）', st: 'err',  time: '13:40', ic: 'handler',  unread: true },
      { type: 'workflow.run_failed',    t: '周报自动汇总 workflow 运行失败',          st: 'err',  time: '11:22', ic: 'workflow', unread: true },
      { type: 'function.edited',        t: 'PDF 提取 function 已发布新版本',           st: 'done', time: '10:08', ic: 'function', unread: true },
      { type: 'conversation.compacted', t: '「Researcher 调优」会话已压缩',            st: 'idle', time: '09:30', ic: 'chat' },
    ]],
    ['昨天', [
      { type: 'agent.updated',     t: 'Researcher agent 配置已更新',  st: 'idle', time: '周二', ic: 'agent' },
      { type: 'mcp.reconnected',   t: 'Notion 连接器已重新连上',      st: 'done', time: '周二', ic: 'mcp' },
    ]],
    ['过去 7 天', [
      { type: 'skill.created',     t: '新增技能「网页摘要」',         st: 'done', time: 'Jun 9', ic: 'skill' },
      { type: 'document.moved',    t: '「上线清单」已移动到 归档/',   st: 'idle', time: 'Jun 8', ic: 'doc' },
    ]],
    ['更早', [
      { type: 'workflow.lifecycle_changed', t: '竞品动态日报流程 已激活', st: 'idle', time: 'May 28', ic: 'workflow' },
    ]],
  ];

  // ③ 已读：标记已读沉底
  const READ = [
    { type: 'function.created', t: '新建 fetch_news function', st: 'done', time: 'Jun 7', ic: 'function' },
    { type: 'memory.updated',   t: '记忆「项目偏好」已更新',    st: 'idle', time: 'Jun 6', ic: 'spark' },
  ];

  // 展示状态（filter 行 sliders；跨重绘保留）
  let flt = 'all', group = true;

  const row = n => `<div class="nt-row${n.unread ? ' unread' : ''}" data-id="${n.id || ''}"><span class="nt-st ${n.st || 'idle'}"></span><span class="nt-ico">${icon(n.ic || 'spark', 16)}</span><span class="nt-t">${n.t}</span><span class="nt-time">${n.time || ''}</span><span class="nt-more">${icon('more', 16)}</span></div>`;
  const fatRow = a => `<div class="nt-fat" data-fr="${a.id}">
      <div class="nt-fat-top"><span class="nt-st wait"></span><span class="nt-ico">${icon('workflow', 16)}</span><span class="nt-t">${a.t}</span><span class="nt-time">${a.time}</span><span class="chev">${icon('chevr', 14)}</span></div>
      <div class="nt-approve"><div class="nt-prompt">${a.prompt}</div>
        <div class="nt-acts"><button class="nt-btn go" data-act="approve">批准</button><button class="nt-btn" data-act="deny">驳回</button><span class="nt-link" data-act="open">在 Scheduler 打开</span></div>
      </div></div>`;
  const opt = (k, v, on, label) => `<button class="nt-opt${on ? ' on' : ''}" data-${k}="${v}"><span class="nt-ck">${icon('check', 14)}</span>${label}</button>`;
  const sec = (cls, head, rows) => `<div class="nt-sec ${cls}">${head}<div class="nt-sec-body">${rows}</div></div>`;

  function build() {
    const needs = NEEDS.length ? sec('needs',
      `<div class="nt-sec-h"><span class="nt-sec-t">Needs you</span><span class="cnt">${NEEDS.length}</span></div>`,
      NEEDS.map(fatRow).join('')) : '';
    const timeline = sec('timeline',
      `<div class="nt-sec-h"><span class="nt-sec-t">时间线</span></div>`,
      GROUPS.map(([l, items]) => `<div class="nt-sub">${l}</div>${items.map(row).join('')}`).join(''));
    const read = READ.length ? sec('read collapsible',
      `<button class="nt-sec-h tog"><span class="nt-sec-t">已读</span><span class="cnt">${READ.length}</span><span class="chev">${icon('chevr', 14)}</span></button>`,
      READ.map(row).join('')) : '';
    const fltCls = flt === 'unread' ? ' only-unread' : flt === 'action' ? ' only-action' : '';
    return `
      <div class="nt-head"><button class="nt-back" title="返回">${BACK}</button><span class="nt-title">通知</span><button class="nt-allread">全部已读</button></div>
      <div class="nt-filter">${icon('search', 16)}<input type="text" placeholder="筛选通知…">
        <button class="nt-mbtn" title="显示选项">${icon('sliders', 16)}</button>
        <div class="nt-menu">
          <div class="nt-mh">筛选</div>
          ${opt('flt', 'all', flt === 'all', '全部')}
          ${opt('flt', 'unread', flt === 'unread', '仅未读')}
          ${opt('flt', 'action', flt === 'action', '仅待决')}
          <div class="nt-mh">显示</div>
          ${opt('toggle', 'group', group, '按时间分组')}
        </div>
      </div>
      <div class="nt-list${group ? '' : ' no-group'}${fltCls}">${needs}${timeline}${read}</div>`;
  }

  function render(host) {
    host.innerHTML = build();
    const list = host.querySelector('.nt-list');
    const refreshUnread = () => window.SideBar && SideBar.setUnread && SideBar.setUnread(!!host.querySelector('.nt-row.unread, .nt-fat'));

    // ← 返回 → 退出接管、回到来源海洋（外壳暴露）
    host.querySelector('.nt-back').onclick = () => (window.SideBar && SideBar.exitNotif) && SideBar.exitNotif();
    // 全部已读
    host.querySelector('.nt-allread').onclick = () => { host.querySelectorAll('.nt-row.unread').forEach(r => r.classList.remove('unread')); refreshUnread(); };

    // 折叠「已读」
    host.querySelectorAll('.tog').forEach(h => h.onclick = () => h.closest('.collapsible').classList.toggle('open'));

    // 普通行：点击 = 标记该条已读（+ 真实接线深链跳来源实体，此处 no-op）；⋯ 同义
    host.querySelectorAll('.nt-row').forEach(r => r.onclick = () => { r.classList.remove('unread'); refreshUnread(); });

    // Needs you 胖行：点 top 展开/收起；批准/驳回 = 就地拍板
    host.querySelectorAll('.nt-fat').forEach(fat => {
      fat.querySelector('.nt-fat-top').onclick = () => fat.classList.toggle('open');
      fat.querySelectorAll('[data-act]').forEach(b => b.onclick = e => {
        e.stopPropagation();
        const act = b.dataset.act;
        if (act === 'open') return;   // 深链逃生口（示意）
        decide(host, fat, act === 'approve');
      });
    });

    // sliders 菜单：筛选单选 + 分组开关（实时改 .nt-list 类）
    const btn = host.querySelector('.nt-mbtn'), menu = host.querySelector('.nt-menu');
    btn.onclick = e => { e.stopPropagation(); const open = menu.classList.toggle('open'); btn.classList.toggle('on', open); };
    menu.addEventListener('click', e => e.stopPropagation());
    menu.querySelectorAll('[data-flt]').forEach(o => o.onclick = () => {
      menu.querySelectorAll('[data-flt]').forEach(x => x.classList.remove('on')); o.classList.add('on'); flt = o.dataset.flt;
      list.classList.toggle('only-unread', flt === 'unread'); list.classList.toggle('only-action', flt === 'action');
    });
    menu.querySelector('[data-toggle="group"]').onclick = function () { group = !group; this.classList.toggle('on', group); list.classList.toggle('no-group', !group); };

    // 标题快滤
    const fin = host.querySelector('.nt-filter input');
    fin.oninput = () => {
      const q = fin.value.trim().toLowerCase();
      host.querySelectorAll('.nt-row, .nt-fat').forEach(it => { it.style.display = it.querySelector('.nt-t').textContent.toLowerCase().includes(q) ? '' : 'none'; });
    };

    refreshUnread();
  }

  // 就地拍板：移出 Needs you、降级为一条 done FYI 进时间线（留痕，镜像后端「决定后该行降级」）
  function decide(host, fat, approve) {
    const wf = fat.querySelector('.nt-t').textContent;
    const sec = fat.closest('.nt-sec');
    fat.remove();
    const rest = sec.querySelectorAll('.nt-fat').length;
    if (!rest) sec.remove(); else sec.querySelector('.cnt').textContent = rest;
    const tl = host.querySelector('.nt-sec.timeline .nt-sec-body');
    if (tl) {
      const tmp = document.createElement('div');                                  // 已决=对自己动作的留痕，非未读（不重新点亮红点）
      tmp.innerHTML = row({ t: `${approve ? '已批准' : '已驳回'} · ${wf}`, st: 'done', time: '刚刚', ic: 'workflow' });
      const firstSub = tl.querySelector('.nt-sub');
      tl.insertBefore(tmp.firstElementChild, firstSub ? firstSub.nextSibling : tl.firstChild);
    }
    window.SideBar && SideBar.setUnread && SideBar.setUnread(!!host.querySelector('.nt-row.unread, .nt-fat'));   // 仍有未读 FYI 或未决审批 → 红点亮
  }

  // 点菜单外收起（一次性）
  document.addEventListener('click', () => {
    const m = document.querySelector('#sidebody .nt-menu.open');
    if (m) { m.classList.remove('open'); document.querySelector('#sidebody .nt-mbtn')?.classList.remove('on'); }
  });

  SideBar.register('notifications', render);
})();
