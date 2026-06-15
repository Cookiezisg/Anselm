/* Foryx design-lab — 左侧栏【固定外壳 chrome】。与四海洋的侧栏内容彻底解耦，互不打扰。
   外壳只管：岛皮肤 + 红绿灯/折叠/搜索 + 四导航切换器 + 工作区/通知/设置 + 收起拖拽 + #sidebody 宿主。
   每个海洋的侧栏内容各自一个文件 sidebar/<id>.{js,css}，经 SideBar.register(id, render) 注册；
   外壳据四导航 mount(id) → 已注册则渲染，未注册则占位并按需懒加载 sidebar/<id>.js（缺文件则保持占位）。
   依赖 shared/icons.js(icon) + shared/shell.js(Shell.left/headLead/sideWidth)，只读。 */
(function () {
  const left = Shell.left;
  const html = document.documentElement;
  const DIR = new URL('.', document.currentScript.src).href;        // 本文件目录 → 懒加载 sidebar/<id>.js
  const NAV = [['chat', 'Chat', 'chat'], ['entities', 'Entities', 'entities'], ['scheduler', 'Scheduler', 'scheduler'], ['documents', 'Documents', 'doc']];
  const NAME = Object.fromEntries(NAV.map(([id, label]) => [id, label]));
  NAME.notifications = '通知';                                       // 铃铛接管侧栏（不在四导航内）→ 占位/兜底名

  // 首帧无闪：注入前据 localStorage 写终态宽度/收起态（避免 240→实际宽跳变）。宽度 clamp[240,420]，下限 240 保英文标签恒显。
  let w0 = parseInt(localStorage.getItem('fg.side.w'), 10);
  if (!(w0 >= 240 && w0 <= 420)) w0 = 240;
  html.style.setProperty('--side-w', w0 + 'px');
  html.dataset.side = localStorage.getItem('fg.side.collapsed') === '1' ? 'off' : 'on';

  left.innerHTML = `
    <div class="side-top">
      <div class="lights"><i class="light r"></i><i class="light y"></i><i class="light g"></i></div>
      <span class="grow"></span>
      <button class="ibtn" data-act="collapse" title="收起侧栏">${icon('side', 18)}</button>
      <button class="ibtn" title="搜索">${icon('search', 18)}</button>
    </div>
    <div class="modeseg" id="modeseg">
      ${NAV.map(([id, label, ic], i) => `<button class="${i === 0 ? 'on' : ''}" data-m="${id}"><span class="ico">${icon(ic, 18)}</span><span class="lbl">${label}</span></button>`).join('')}
    </div>
    <div id="sidebody"></div>
    <div class="sfoot">
      <button class="ws" title="工作区主页 / 设置"><span class="ws-ava"></span><span class="ws-name"></span></button>
      <button class="sf-act" title="通知">${icon('bell', 18)}<span class="sf-dot"></span></button>
    </div>`;

  // 工作区身份（示意；接后端换真 workspace）。头像 = 名字首字母（最多两词）
  const WS = 'Personal';
  left.querySelector('.ws-name').textContent = WS;
  left.querySelector('.ws-ava').textContent = WS.trim().split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();

  // ===== SideBar 契约：外壳 ↔ 海洋侧栏内容 =====
  const sidebody = left.querySelector('#sidebody');
  window.SideBar = {
    _render: {}, _cur: null, _tried: {},
    register(id, render) { this._render[id] = render; if (id === this._cur) render(sidebody); },   // 海洋文件调
    mount(id) {
      this._cur = id;
      if (this._render[id]) this._render[id](sidebody);                                            // render(host) 自填 + 接线
      else {
        sidebody.innerHTML = `<div class="side-soon">${NAME[id] || id} 侧栏设计中…</div>`;
        if (!this._tried[id]) { this._tried[id] = true; const s = document.createElement('script'); s.src = DIR + id + '.js'; s.onerror = () => (this._tried[id] = false); document.head.appendChild(s); }
      }
    },
  };

  // ===== 导航中枢：四 tab 切海洋(侧栏+海面一起换)；头像 → 设置(海面接管轴)；铃铛 → 通知 Inbox(侧栏接管轴)。两轴镜像、正交。 =====
  const seg = left.querySelector('.modeseg');
  const bell = left.querySelector('.sf-act'), dot = left.querySelector('.sf-dot');
  let cur = 'chat';                                                  // 当前内容海洋(供设置「返回」)
  let _sideBack = null;                                              // 进通知前的来源海洋(对称 Shell._back；SideBar._cur 即将被覆盖,先存)
  const mountSea = id => {                                           // 海面:已注册则挂载,否则占位(该海洋未在本页加载)
    document.querySelectorAll('[data-ocean-head]').forEach(el => el.remove());   // 清上个海洋留在主区头的上下文(如 chat 标题栏);Shell.mount 只清右岛、不清这个
    if (Shell.oceans && Shell.oceans[id]) Shell.mount(id);
    else Shell.sea.innerHTML = `<div style="flex:1;display:grid;place-items:center;color:var(--ink-3);font-size:var(--t-md)">${NAME[id] || id} · 海面待接入</div>`;
  };
  function nav(id) {                                                 // 切到某海洋:高亮 tab + 侧栏内容 + 海面；并退出通知接管(铃铛与 tab 互斥)
    cur = id;
    bell.classList.remove('on');
    seg.querySelectorAll('button').forEach(x => x.classList.toggle('on', x.dataset.m === id));
    SideBar.mount(id);
    mountSea(id);
  }
  Shell.toOcean = nav;                                              // 暴露:设置「返回」回到来源海洋
  seg.querySelectorAll('button').forEach(b => b.onclick = () => nav(b.dataset.m));
  // 头像 = 设置入口(海面接管轴)：记来源海洋、切到设置海面、四导航与铃铛不高亮(已离开内容海)
  left.querySelector('.ws').onclick = () => {
    Shell._back = cur;
    bell.classList.remove('on');
    seg.querySelectorAll('button').forEach(x => x.classList.remove('on'));
    mountSea('settings');
  };

  // ===== 铃铛 = 通知入口(侧栏接管轴，镜像头像→设置)：整个 #sidebody 换成通知 Inbox、四 tab 熄灭、铃铛高亮，海面不动。 =====
  SideBar.setUnread = has => { if (dot) dot.style.display = has ? '' : 'none'; };   // 未读红点出口(跟 CountUnread)
  function enterNotif() {
    peekDismiss();
    _sideBack = SideBar._cur || cur;                                // 先存来源(下一步 mount 会把 _cur 覆盖成 notifications)
    seg.querySelectorAll('button').forEach(x => x.classList.remove('on'));
    bell.classList.add('on');
    SideBar.mount('notifications');                                 // 不在 NAV → 已注册则渲染,否则懒加载 sidebar/notifications.js
  }
  function exitNotif() {                                            // 对称 settings 的「返回」：不碰海面,只重渲来源侧栏(故比 settings 返回更轻)
    bell.classList.remove('on');
    const back = _sideBack || 'chat';
    seg.querySelectorAll('button').forEach(x => x.classList.toggle('on', x.dataset.m === back));
    SideBar.mount(back);
  }
  SideBar.exitNotif = exitNotif;                                    // 暴露:通知 Inbox 的「← 返回」调它
  bell.onclick = () => bell.classList.contains('on') ? exitNotif() : enterNotif();

  // 左下角 peek：仅 actionable(approval_pending)到达时冒一片极简 pill(贴铃铛上沿)；FYI 只亮红点。点 pill/查看 → 进 Inbox。
  let peekTimer = null;
  function peekDismiss() {
    clearTimeout(peekTimer);
    const p = left.querySelector('.sf-peek');
    if (p) { p.classList.remove('in'); setTimeout(() => p.remove(), 220); }
  }
  function peekShow(text) {
    if (bell.classList.contains('on')) return;                      // 已在 Inbox 不重复冒
    peekDismiss();
    SideBar.setUnread(true);
    const p = document.createElement('div');
    p.className = 'sf-peek';
    p.innerHTML = `<span class="sf-peek-d"></span><span class="sf-peek-t">${text}</span><button class="sf-peek-go">查看</button><button class="sf-peek-x" title="忽略">${icon('close', 13)}</button>`;
    left.appendChild(p);
    setTimeout(() => p.classList.add('in'), 16);                   // 入场过渡（setTimeout 比 rAF 稳，无头/后台不被节流）
    const go = () => { peekDismiss(); enterNotif(); };
    p.querySelector('.sf-peek-go').onclick = go;
    p.querySelector('.sf-peek-t').onclick = go;
    p.querySelector('.sf-peek-x').onclick = e => { e.stopPropagation(); peekDismiss(); };
    p.onmouseenter = () => clearTimeout(peekTimer);
    p.onmouseleave = () => { peekTimer = setTimeout(peekDismiss, 2500); };
    peekTimer = setTimeout(peekDismiss, 8000);
  }
  setTimeout(() => peekShow('竞品动态日报流程 · 等待审批'), 2200);    // 示意:一条审批到达(纯前端,不连流)

  // ===== 收起/展开 + 拖拽调宽（状态/持久化全归侧栏；单一真相 = html[data-side] + --side-w） =====
  function toggle() {
    const off = html.dataset.side === 'off';
    html.dataset.side = off ? 'on' : 'off';
    localStorage.setItem('fg.side.collapsed', off ? '0' : '1');
  }
  left.querySelector('[data-act="collapse"]').onclick = toggle;

  // 收起后岛全隐 → 再展开按钮安家到 shell 中性槽 #head-lead
  const reopen = document.createElement('button');
  reopen.className = 'ibtn side-reopen';
  reopen.title = '展开侧栏';
  reopen.innerHTML = icon('side', 18);
  reopen.onclick = toggle;
  Shell.headLead.appendChild(reopen);

  // 拖拽手柄（贴右内缘）：window 级监听 + flag，move 改 CSS var、pointerup 落盘、拖拽中关过渡跟手
  const grip = document.createElement('div');
  grip.className = 'side-grip';
  left.appendChild(grip);
  let sx = 0, sw = 0, dragging = false;
  grip.addEventListener('pointerdown', e => {
    if (html.dataset.side !== 'on') return;
    dragging = true; sx = e.clientX; sw = Shell.sideWidth || 240;
    html.dataset.sideDragging = '';
    document.body.style.userSelect = 'none'; document.body.style.cursor = 'col-resize';
    e.preventDefault();
  });
  window.addEventListener('pointermove', e => {
    if (!dragging) return;
    html.style.setProperty('--side-w', Math.max(240, Math.min(420, sw + (e.clientX - sx))) + 'px');
  });
  window.addEventListener('pointerup', () => {
    if (!dragging) return;
    dragging = false;
    delete html.dataset.sideDragging;
    document.body.style.userSelect = ''; document.body.style.cursor = '';
    localStorage.setItem('fg.side.w', Math.round(Shell.sideWidth));
  });

  SideBar.mount('chat');   // 默认进 Chat（懒加载 sidebar/chat.js）
})();
