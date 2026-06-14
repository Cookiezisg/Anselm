/* Forgify design-lab — 左侧栏模块（单独，一人负责）。
   自挂载进 Shell.left。依赖：shared/icons.js（icon）+ shared/shell.js（Shell.left）。只读它们、不改。
   注：模式段/Recents 现为示意；接后端时换成真数据，外壳契约不变。 */
(function () {
  const left = Shell.left;
  const html = document.documentElement;

  // 首帧无闪：注入前先据 localStorage 把终态宽度/收起态写到 <html>（避免 240→实际宽跳变）
  let w0 = parseInt(localStorage.getItem('fg.side.w'), 10);
  if (!(w0 >= 240 && w0 <= 420)) w0 = 240;                 // 脏值/NaN/旧窄值 回退(下限 240=最长标签 Documents 恒显)
  html.style.setProperty('--side-w', w0 + 'px');
  html.dataset.side = localStorage.getItem('fg.side.collapsed') === '1' ? 'off' : 'on';

  left.innerHTML = `
    <div class="side-top">
      <div class="lights"><span class="light r"></span><span class="light y"></span><span class="light g"></span></div>
      <span class="grow"></span>
      <button class="ibtn" data-i="side"></button>
      <button class="ibtn" data-i="search"></button>
    </div>
    <!-- 四导航(海洋切换器):Notion 式选中展开药丸。中间两个(Entities/Scheduler)的「侧栏内容」待定,
         此处只立切换器骨架;data-m 用真海洋 id,便于日后接 Shell.mount。命名待拍:Scheduler 偏窄(候选 Runs/Operate)。 -->
    <div class="modeseg" id="modeseg">
      <button class="on" data-m="chat"><span class="ico" data-i="chat"></span><span class="lbl">Chat</span></button>
      <button data-m="entities"><span class="ico" data-i="entities"></span><span class="lbl">Entities</span></button>
      <button data-m="scheduler"><span class="ico" data-i="scheduler"></span><span class="lbl">Scheduler</span></button>
      <button data-m="documents"><span class="ico" data-i="doc"></span><span class="lbl">Documents</span></button>
    </div>
    <!-- 海洋专属内容区:据顶部四导航切换。当前实现 Chat(会话史);其余海洋待设计,占位。 -->
    <div id="sidebody"></div>
    <!-- 底部:工作区(圆头像+名,点切换、无箭头) + 通知 + 设置。学 Claude Code 用户行清爽;英文名;铃铛/齿轮 15px 同顶部导航。 -->
    <div class="sfoot">
      <button class="ws" title="Switch workspace">
        <span class="ws-ava" id="ws-ava"></span>
        <span class="ws-name" id="ws-name"></span>
      </button>
      <button class="sf-act" title="Notifications"><span data-i="bell"></span><span class="sf-dot"></span></button>
      <button class="sf-act" title="Settings"><span data-i="gear"></span></button>
    </div>`;

  const sz = { side: 18, search: 18, chat: 18, entities: 18, scheduler: 18, doc: 18, bell: 18, gear: 18 };   // 仅静态结构用;Chat 内容区的图标在 buildChat 里直接 icon() 调
  left.querySelectorAll('[data-i]').forEach(el => { const k = el.dataset.i; el.innerHTML = icon(k, sz[k] || 18); });

  // 工作区身份(示意;接后端换真 workspace)。头像 = 名字首字母(最多两词)
  const WS = 'Personal';
  left.querySelector('#ws-name').textContent = WS;
  left.querySelector('#ws-ava').textContent = WS.trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();

  // ===== 海洋专属侧栏内容（据四导航切换；当前实现 Chat，其余海洋占位） =====
  const body = left.querySelector('#sidebody');
  const OCEAN_NAME = { entities: 'Entities', scheduler: 'Scheduler', documents: 'Documents' };

  // Chat 会话史（示意数据）。接后端：列表/置顶/归档/标题滤已有；运行点=B3 isGenerating；时间分组=B4 last_message_at。
  function buildChat() {
    const PINNED = [{ t: '竞品动态日报流程' }, { t: 'Researcher agent 调优', on: true }];
    const GROUPS = [
      ['Today', [{ t: '修复 CEL 校验器', run: true }, { t: 'Webhook 入库 handler' }]],
      ['Yesterday', [{ t: '周报自动汇总 workflow' }, { t: '文档问答 agent' }]],
      ['Previous 7 days', [{ t: '账单对账流程' }, { t: 'Slack 通知 trigger' }, { t: 'PDF 提取 function' }]],
      ['Older', [{ t: 'Notion 同步实验' }, { t: '旧版迁移笔记' }]],
    ];
    const ARCHIVED = ['临时调试 agent', '废弃的爬虫流程', '一次性数据清洗'];
    const row = c => `<div class="cv${c.on ? ' on' : ''}"><span class="t">${c.t}</span>${c.run ? '<span class="cv-run" title="生成中"></span>' : ''}<span class="cv-more">${icon('more', 16)}</span></div>`;
    const sec = (label, items) => `<div class="cvsec"><div class="cvsec-h">${label}</div>${items.map(row).join('')}</div>`;
    return `
      <button class="newconv">${icon('plus', 18)} New conversation</button>
      <div class="cfilter">${icon('search', 16)}<input type="text" placeholder="Filter conversations…">
        <button class="cdisp" title="Display options">${icon('sliders', 16)}</button>
        <div class="cdisp-menu">
          <div class="cdisp-h">Sort by</div>
          <button class="cdisp-opt on" data-sort="recent"><span class="ck">${icon('check', 14)}</span>Recent activity</button>
          <button class="cdisp-opt" data-sort="created"><span class="ck">${icon('check', 14)}</span>Date created</button>
          <button class="cdisp-opt" data-sort="title"><span class="ck">${icon('check', 14)}</span>Title A–Z</button>
        </div>
      </div>
      <div class="cvlist">
        ${sec('Pinned', PINNED)}
        ${GROUPS.map(([l, items]) => sec(l, items)).join('')}
        <div class="cvarch">
          <button class="cvarch-h"><span class="cvarch-t">Archived</span><span class="cnt">12</span><span class="chev">${icon('chevr', 14)}</span></button>
          <div class="cvarch-list">${ARCHIVED.map(t => row({ t })).join('')}</div>
        </div>
      </div>`;
  }

  function wireChat() {
    body.querySelectorAll('.cv').forEach(it => it.onclick = e => {
      if (e.target.closest('.cv-more')) return;
      body.querySelectorAll('.cv').forEach(x => x.classList.remove('on'));
      it.classList.add('on');
    });
    const arch = body.querySelector('.cvarch');
    arch.querySelector('.cvarch-h').onclick = () => arch.classList.toggle('open');
    // 展示/排序选项菜单（sliders 按钮）——选哪种排法。接后端 = List sort 参数
    const disp = body.querySelector('.cdisp'), dmenu = body.querySelector('.cdisp-menu');
    disp.onclick = e => { e.stopPropagation(); const open = dmenu.classList.toggle('open'); disp.classList.toggle('on', open); };
    dmenu.querySelectorAll('.cdisp-opt').forEach(o => o.onclick = () => {
      dmenu.querySelectorAll('.cdisp-opt').forEach(x => x.classList.remove('on'));
      o.classList.add('on'); dmenu.classList.remove('open'); disp.classList.remove('on');
    });
    const fin = body.querySelector('.cfilter input');   // 标题快滤前端体感（对应 List ?q= LIKE）
    fin.oninput = () => {
      const q = fin.value.trim().toLowerCase();
      body.querySelectorAll('.cvsec, .cvarch').forEach(s => {
        let any = false;
        s.querySelectorAll('.cv').forEach(cv => {
          const hit = cv.querySelector('.t').textContent.toLowerCase().includes(q);
          cv.style.display = hit ? '' : 'none'; if (hit) any = true;
        });
        const h = s.querySelector('.cvsec-h'); if (h) h.style.display = any ? '' : 'none';
      });
    };
  }

  function renderBody(ocean) {
    if (ocean === 'chat') { body.innerHTML = buildChat(); wireChat(); }
    else { body.innerHTML = `<div class="side-soon">${OCEAN_NAME[ocean] || ocean} 侧栏设计中…</div>`; }
  }

  const seg = left.querySelector('#modeseg');
  seg.querySelectorAll('button').forEach(b => b.onclick = () => {
    seg.querySelectorAll('button').forEach(x => x.classList.remove('on'));
    b.classList.add('on');
    renderBody(b.dataset.m);
  });
  renderBody('chat');   // 默认进 Chat 海洋

  // 点菜单外收起展示选项菜单（一次性挂载；body 重渲染后查询仍有效）
  document.addEventListener('click', () => {
    const m = body.querySelector('.cdisp-menu.open');
    if (m) { m.classList.remove('open'); body.querySelector('.cdisp')?.classList.remove('on'); }
  });

  // —— 收起/展开 + 拖拽调宽（状态/交互/持久化全归侧栏；单一真相 = html[data-side]） ——
  function toggle() {
    const off = html.dataset.side === 'off';
    html.dataset.side = off ? 'on' : 'off';
    localStorage.setItem('fg.side.collapsed', off ? '0' : '1');
  }
  left.querySelector('[data-i="side"]').onclick = toggle;   // 岛顶折叠按钮（展开态可见）

  // 再展开按钮 → shell 的中性 #head-lead 槽（收起后岛全隐、按钮需岛外有家；收起语义不进内核）
  const reopen = document.createElement('button');
  reopen.className = 'ibtn side-reopen';
  reopen.title = '展开侧栏';
  reopen.innerHTML = icon('side', 18);
  reopen.onclick = toggle;
  Shell.headLead.appendChild(reopen);

  // 拖拽手柄（贴右内缘）：window 级监听 + flag（稳健处理指针移出窗口）；
  // move 中只改 CSS var、pointerup 才落盘；拖拽中关 transition 跟手。
  const grip = document.createElement('div');
  grip.className = 'side-grip';
  left.appendChild(grip);
  let sx = 0, sw = 0, dragging = false;
  grip.addEventListener('pointerdown', e => {
    if (html.dataset.side !== 'on') return;                 // 收起态不响应（双保险①）
    dragging = true; sx = e.clientX; sw = Shell.sideWidth || 240;
    html.dataset.sideDragging = '';
    document.body.style.userSelect = 'none'; document.body.style.cursor = 'col-resize';
    e.preventDefault();
  });
  window.addEventListener('pointermove', e => {
    if (!dragging) return;
    const next = Math.max(240, Math.min(420, sw + (e.clientX - sx)));   // clamp[240,420]（下限 240 保英文标签恒显）
    html.style.setProperty('--side-w', next + 'px');
  });
  window.addEventListener('pointerup', () => {
    if (!dragging) return;
    dragging = false;
    delete html.dataset.sideDragging;
    document.body.style.userSelect = ''; document.body.style.cursor = '';
    localStorage.setItem('fg.side.w', Math.round(Shell.sideWidth));     // 仅松手时落盘
  });
})();
