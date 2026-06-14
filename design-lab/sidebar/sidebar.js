/* Forgify design-lab — 左侧栏模块（单独，一人负责）。
   自挂载进 Shell.left。依赖：shared/icons.js（icon）+ shared/shell.js（Shell.left）。只读它们、不改。
   注：模式段/Recents 现为示意；接后端时换成真数据，外壳契约不变。 */
(function () {
  const left = Shell.left;
  left.innerHTML = `
    <div class="side-top">
      <div class="lights"><span class="light r"></span><span class="light y"></span><span class="light g"></span></div>
      <span class="grow"></span>
      <button class="ibtn" data-i="side"></button>
      <button class="ibtn" data-i="search"></button>
    </div>
    <div class="modeseg" id="modeseg">
      <button data-m="chat"><span class="ico" data-i="chat"></span><span class="lbl">Chat</span></button>
      <button data-m="tasks"><span class="ico" data-i="tasks"></span><span class="lbl">Tasks</span></button>
      <button class="on" data-m="code"><span class="ico" data-i="code"></span><span class="lbl">Code</span></button>
    </div>
    <div class="sact">
      <button class="sitem"><span class="ico" data-i="plus"></span> New session</button>
      <button class="sitem"><span class="ico" data-i="zap"></span> Routines</button>
      <button class="sitem"><span class="ico" data-i="dispatch"></span> Dispatch <span class="beta">Beta</span></button>
      <button class="sitem"><span class="ico" data-i="sliders"></span> Customize</button>
      <button class="sitem"><span class="ico" data-i="chevd"></span> More</button>
    </div>
    <div class="recents">
      <div class="rec-head"><span>Recents</span><button class="ibtn" data-i="sort"></button></div>
      <div id="reclist"></div>
    </div>
    <div class="suser">
      <span class="av">sw</span>
      <span class="m"><b>Sun Weilin</b><span class="plan">· Max</span></span>
      <span class="chev" data-i="chevd"></span>
    </div>`;

  const sz = { side: 18, search: 18, chat: 15, tasks: 15, code: 15, plus: 18, zap: 18, dispatch: 18, sliders: 18, chevd: 14, sort: 15 };
  left.querySelectorAll('[data-i]').forEach(el => { const k = el.dataset.i; el.innerHTML = icon(k, sz[k] || 18); });

  const SESS = [
    ['前端设计 (fork)', 'run', true], ['前端部署', 'run', false], ['Backend重构 [Done]', 'done', false],
    ['列名检查 [adhoc]', 'done', false], ['版本控制管理 [done]', 'done', false], ['Workflow重构 Implement [done]', 'done', false],
    ['Workflow重构 Review [done]', 'done', false], ['HardCode治理专项 [done]', 'done', false],
    ['Workflow Feature迭代探索 [done]', 'done', false], ['E2E修复 [Done]', 'done', false], ['Testend修复 [Done]', 'done', false],
    ['API模型配置迭代 [Done]', 'done', false], ['前端文档页面优化 [Done]', 'done', false],
  ];
  const rl = left.querySelector('#reclist');
  rl.innerHTML = SESS.map(([t, st, on]) =>
    `<div class="ritem${on ? ' on' : ''}"><span class="d${st === 'run' ? ' run' : ''}"></span><span class="t">${t}</span></div>`).join('');
  rl.querySelectorAll('.ritem').forEach(it => it.onclick = () => {
    rl.querySelectorAll('.ritem').forEach(x => x.classList.remove('on')); it.classList.add('on');
  });

  const seg = left.querySelector('#modeseg');
  seg.querySelectorAll('button').forEach(b => b.onclick = () => {
    seg.querySelectorAll('button').forEach(x => x.classList.remove('on')); b.classList.add('on');
  });
})();
