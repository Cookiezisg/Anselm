/* Forgify design-lab — 左侧栏【固定外壳 chrome】。与四海洋的侧栏内容彻底解耦，互不打扰。
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
      <button class="ws" title="切换工作区"><span class="ws-ava"></span><span class="ws-name"></span></button>
      <button class="sf-act" title="通知">${icon('bell', 18)}<span class="sf-dot"></span></button>
      <button class="sf-act" title="设置">${icon('gear', 18)}</button>
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

  // 四导航切换 → 挂载对应海洋。data-m 是与海洋 harness 的契约（harness 用 #modeseg [data-m=<id>].click() 切到本海洋侧栏）。
  const seg = left.querySelector('.modeseg');
  seg.querySelectorAll('button').forEach(b => b.onclick = () => {
    seg.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
    SideBar.mount(b.dataset.m);
  });

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
