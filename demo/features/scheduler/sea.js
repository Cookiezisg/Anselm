/* Forgify demo — 运行海洋（Scheduler）海面：薄组合（样板）。
   只调组件库 + Shell + Intent，自己几乎不画像素：RunChip(头徽/历史) + RunGraph(Conducted Keynote 图) + Attention(stuck) + RightIsland+IterationStepper/ApprovalGate(节点抽屉)。
   选中通道：侧栏 workflow 行发 Intent.select({kind:'workflow'}) → 本海洋 Intent.on('workflow') 切驾驶舱；图节点点击 → 右岛看记忆化结果。
   依赖 mock/workflows.js。注册 Shell.registerOcean('scheduler')。 */
(function () {
  if (window.cssNextTo) cssNextTo(document.currentScript);
  const W = () => window.MOCK_WORKFLOWS || {};
  const firstName = () => Object.keys(W())[0];
  let stage, island, curName;

  const ST_TX = { running: '运行中', completed: '已完成', failed: '失败', cancelled: '已取消', waiting: '等审批' };

  function openNode(run, id) {
    const nd = run.nodes.find(x => x.id === id) || {}, m = run.memo[id] || {}, st = run.state[id] || 'future';
    if (!island) island = RightIsland.create('scheduler', { title: id, icon: (window.NODE_ICON || {})[nd.kind] || 'action' });
    island.setHead(`<span class="fg-island-ic">${icon((window.NODE_ICON || {})[nd.kind] || 'action', 17)}</span>
      <span class="sch-ndh"><b>${id}</b><span class="sch-ndsub">${nd.kind || ''} · ${StatusDot.dot(st)} ${ST_TX[window.stState ? window.stState(st) : st] || st}</span></span>
      <button class="fg-island-x">${icon('close', 16)}</button>`);
    island.el.querySelector('.fg-island-x').onclick = () => island.hide();
    const b = island.body; b.innerHTML = '';
    if (nd.ref) { const r = document.createElement('div'); r.className = 'sch-ndref'; r.innerHTML = `引用 ${RefPill.html(nd.kind === 'action' ? 'function' : nd.kind, nd.ref, nd.ref)} <span class="sch-mono">@${run.version}</span>`; RefPill.wire(r); b.appendChild(r); }
    if (m.loop) IterationStepper.mount(b, { items: m.loop });
    else if (m.parked) ApprovalGate.mount(b, { flavor: 'durable', title: id, prompt: m.prompt, ddl: m.ddl, allowReason: true });
    else if (m.error) { const e = document.createElement('div'); e.className = 'sch-nderr'; e.textContent = m.error; b.appendChild(e); }
    else if (m.decision) { const k = document.createElement('div'); KV.defs(k, [['decision', m.decision, { mono: true }], ['reason', m.reason || '—']]); b.appendChild(k); }
    else { const o = document.createElement('div'); o.className = 'sch-ndout'; o.textContent = st === 'future' ? '尚未运行' : (m.out || '—'); b.appendChild(o); }
    island.show();
  }

  function cockpit(name) {
    const wf = W()[name]; curName = name;
    if (!wf) { stage.innerHTML = '<div class="sch-empty">该 workflow 暂无运行记录</div>'; return; }
    const run = wf.runs[wf.cur] != null ? wf.runs[wf.cur] : wf.runs[wf.runs.length - 1];
    if (!run) { stage.innerHTML = `<div class="sch-empty">${name} · 最近无运行</div>`; return; }

    const stVals = Object.values(run.state);
    const hasParked = stVals.includes('parked'), hasFailed = run.runState === 'failed';
    const badge = (run.runState === 'running' && hasParked) ? 'waiting' : run.runState;
    const src = run.trigger ? `<span class="sch-src">${icon('trigger', 13)} 由 ${run.trigger} 触发</span>` : `<span class="sch-src">${icon('play', 13)} 手动</span>`;
    const retry = run.replay ? `<span class="sch-src">${icon('spin', 13)} Retry #${run.replay}</span>` : '';

    let stuck = '';
    if (hasParked) { const id = Object.keys(run.state).find(k => run.state[k] === 'parked'); const m = run.memo[id] || {}; stuck = Attention.html('shield', `停在 <b class="sch-mono">${id}</b> · 等待 ${m.form || '审批'}（${m.ddl || ''}）`, { tone: 'warn' }); }
    else if (hasFailed) { const id = Object.keys(run.state).find(k => run.state[k] === 'failed'); const m = run.memo[id] || {}; stuck = Attention.html('close', `<b class="sch-mono">${id}</b> 失败 · ${m.error || ''}`, { tone: 'danger' }); }

    stage.innerHTML = `
      <div class="sch-col">
        <div class="sch-head">
          ${RunChip.headBadge(badge)}
          <span class="sch-rid">${run.id}</span>
          <span class="sch-pos">node <b>${run.pos}</b></span>
          <span class="sch-ver">${run.version} pinned</span>
          ${src}${retry}
          <span class="grow"></span><span class="sch-when">${run.when}</span>
        </div>
        ${stuck}
        <div class="sch-graph" id="schGraph"></div>
        <div class="sch-rail" id="schRail"></div>
      </div>`;

    RunGraph.render(stage.querySelector('#schGraph'), Object.assign({ onNode: id => openNode(run, id) }, run));
    RunChip.rail(stage.querySelector('#schRail'), wf.runs.map(r => ({ id: r.id, state: r.runState, when: r.when, live: r.runState === 'running' })), {
      current: wf.cur != null ? wf.cur : wf.runs.length - 1,
      onPick: i => { wf.cur = i; cockpit(name); },
    });
    const sc = stage.parentElement; if (sc) sc.scrollTop = 0;
  }

  Shell.registerOcean('scheduler', {
    crumb: '运行',
    build(sea) {
      sea.innerHTML = `<div class="sch"><div class="sch-scroll scroll-fade" id="schScroll"><div id="schStage"></div></div></div>`;
      stage = sea.querySelector('#schStage');
      cockpit(firstName());
    },
  });

  // 选中通道：侧栏 workflow 行 → Intent.select({kind:'workflow'}) → 切驾驶舱
  Intent.on('workflow', sel => { if (stage) cockpit(sel.id); });
})();
