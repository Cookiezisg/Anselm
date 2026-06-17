/* ============================================================================
   Anselm flow-graph · 演示外壳：工具栏 · 检查器(可编辑) · 撤销/重做 · 小地图 · ops 日志。
   编辑动作 → FlowGraph handle → 生成后端 ops → 这里记日志 + 入撤销栈。
============================================================================ */
(function () {
  const FG = window.FG;
  const $ = (s, r = document) => r.querySelector(s), $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const esc = s => String(s == null ? '' : s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

  let gv, mode = 'edit', dir = 'LR', curSample;
  let history = [], hi = -1, opsLog = [];

  /* ---- 挂载组件 ---- */
  const stage = $('#stage');
  function boot(sampleKey) {
    curSample = sampleKey; const s = FG.SAMPLES[sampleKey];
    const graph = { nodes: s.nodes.map(n => ({ ...n, input: { ...n.input }, retry: n.retry && { ...n.retry } })), edges: s.edges.map(e => ({ ...e })) };
    const run = JSON.parse(JSON.stringify(s.run));
    if (gv) gv.el.remove();
    gv = FlowGraph.mount(stage, {
      graph, mode, dir, run,
      onSelect: renderInspector, onToast: toast,
      onChange: change => { pushHistory(); logOps(change); renderNote(); renderMinimap(); },
      onView: renderMinimapViewport,
    });
    window.fg = gv; // 调试 / 嵌入 handle
    history = [FG.clone(graph)]; hi = 0; opsLog = []; renderOps();
    renderInspector(null); renderNote(); renderLegend(); setTimeout(renderMinimap, 60);
  }

  /* ---- 撤销 / 重做（图快照栈）---- */
  function pushHistory() { const snap = gv.getGraph(); history = history.slice(0, hi + 1); history.push(snap); hi = history.length - 1; if (history.length > 60) { history.shift(); hi--; } updateUndoBtns(); }
  function undo() { if (hi <= 0) return; hi--; gv.setGraph(FG.clone(history[hi])); renderNote(); renderMinimap(); updateUndoBtns(); }
  function redo() { if (hi >= history.length - 1) return; hi++; gv.setGraph(FG.clone(history[hi])); renderNote(); renderMinimap(); updateUndoBtns(); }
  function updateUndoBtns() { $('#undo').disabled = hi <= 0; $('#redo').disabled = hi >= history.length - 1; }

  /* ---- ops 日志 ---- */
  function logOps(change) { if (change.minor && opsLog[0] && opsLog[0].label === '移动') opsLog.shift(); change.ops.forEach(op => opsLog.unshift({ op, label: change.label })); opsLog = opsLog.slice(0, 40); renderOps(); }
  function renderOps() {
    const wrap = $('#opslog'); if (!wrap.classList.contains('open')) return;
    wrap.querySelector('.ops-body').innerHTML = opsLog.length ? opsLog.map(o =>
      `<div class="op"><span class="op-t">${o.op.op}</span><code>${esc(JSON.stringify(stripOp(o.op)))}</code></div>`).join('')
      : '<div class="op-empty">编辑图（加节点 / 连线 / 改字段）即生成后端 ops…</div>';
  }
  function stripOp(op) { const o = { ...op }; delete o.op; return o; }

  /* ============================ 检查器（编辑器 / 运行态）============================ */
  function renderInspector(sel) {
    const ins = $('#inspector'), body = $('#ins-body'), ttl = $('#ins-ttl');
    if (!sel) { ins.classList.remove('open'); return; }
    ins.classList.add('open');
    if (sel.type === 'edge') return renderEdgeInspector(sel.id, body, ttl);
    const n = gv.getNode(sel.id); if (!n) { ins.classList.remove('open'); return; }
    ttl.innerHTML = `<span class="ins-kc" style="--kc:${FG.KIND[n.kind].c}"></span>${esc(n.id)}`;
    if (mode === 'run') return renderRunInspector(n, body);
    // ---- 编辑器：节点定义 ----
    const k = n.kind;
    let h = `<label class="fld"><span>类型</span><select id="f-kind" class="ipt">${FG.KIND_ORDER.map(kk => `<option value="${kk}" ${kk === k ? 'selected' : ''}>${FG.KIND[kk].label} · ${kk}</option>`).join('')}</select></label>`;
    h += `<label class="fld"><span>ref</span><input id="f-ref" class="ipt mono" value="${esc(n.ref)}" placeholder="${FG.KIND[k].prefix}…"></label>`;
    h += `<div class="fld-l">输入接线 <span class="hint">field → CEL（读上游节点 result）</span></div><div id="wires">`;
    const inp = n.input || {};
    Object.keys(inp).forEach(f => { h += wireRow(f, inp[f]); });
    h += `</div><button class="mini" id="add-wire">＋ 加一条接线</button>`;
    if (k === 'action') h += retryBlock(n.retry);
    const outs = gv.getGraph().edges.filter(e => e.from === n.id);
    if (outs.length) { h += `<div class="fld-l">出口</div>`; outs.forEach(e => { const back = gv.isBack(e.id); h += `<div class="row-line"><span class="pill ${back ? 'accent' : ''}">${esc(e.port || '—')}${back ? ' ↩' : ''}</span><span class="arr">→ ${esc(e.to)}</span></div>`; }); }
    h += `<div class="ins-foot"><button class="btn danger" id="del-node">删除节点</button></div>`;
    body.innerHTML = h;
    // wiring
    $('#f-kind').onchange = e => { const nk = e.target.value; const patch = { kind: nk }; if (n.ref === FG.KIND[k].prefix + 'new') patch.ref = FG.KIND[nk].prefix + 'new'; gv.updateNode(n.id, patch); };
    $('#f-ref').onchange = e => gv.updateNode(n.id, { ref: e.target.value.trim() });
    $('#add-wire').onclick = () => { const inp2 = { ...(gv.getNode(n.id).input || {}) }; let i = 1, key = 'field'; while (inp2[key]) key = 'field' + (++i); inp2[key] = ''; gv.updateNode(n.id, { input: inp2 }); };
    bindWires(n.id);
    if (k === 'action') bindRetry(n.id);
    $('#del-node').onclick = () => gv.deleteSelected();
  }
  function wireRow(f, v) { return `<div class="wire" data-f="${esc(f)}"><input class="ipt mono w-k" value="${esc(f)}"><span class="w-arr">→</span><input class="ipt mono w-v" value="${esc(v)}" placeholder="cel"><button class="w-x" title="删">×</button></div>`; }
  function bindWires(id) {
    $$('#wires .wire').forEach(row => {
      const collect = () => { const inp = {}; $$('#wires .wire').forEach(r => { const k = r.querySelector('.w-k').value.trim(); if (k) inp[k] = r.querySelector('.w-v').value.trim(); }); gv.updateNode(id, { input: inp }); };
      row.querySelector('.w-k').onchange = collect; row.querySelector('.w-v').onchange = collect;
      row.querySelector('.w-x').onclick = () => { const inp = { ...(gv.getNode(id).input || {}) }; delete inp[row.dataset.f]; gv.updateNode(id, { input: inp }); };
    });
  }
  function retryBlock(r) {
    const on = !!r; return `<div class="fld-l">durable 重试 <span class="hint">同一轮失败重试（≠ 循环迭代）</span></div>
      <label class="fld"><span><input type="checkbox" id="rt-on" ${on ? 'checked' : ''}> 启用</span></label>
      <div id="rt-fields" style="${on ? '' : 'display:none'}">
        <label class="fld"><span>maxAttempts</span><input id="rt-max" class="ipt" type="number" min="1" max="10" value="${r ? r.maxAttempts : 3}"></label>
        <label class="fld"><span>backoff</span><select id="rt-bo" class="ipt"><option ${r && r.backoff === 'fixed' ? 'selected' : ''}>fixed</option><option ${!r || r.backoff === 'exponential' ? 'selected' : ''}>exponential</option></select></label>
        <label class="fld"><span>delayMs</span><input id="rt-delay" class="ipt" type="number" min="0" step="100" value="${r ? r.delayMs : 1000}"></label>
      </div>`;
  }
  function bindRetry(id) {
    const collect = () => { if (!$('#rt-on').checked) return gv.updateNode(id, { retry: undefined }); gv.updateNode(id, { retry: { maxAttempts: +$('#rt-max').value || 1, backoff: $('#rt-bo').value, delayMs: +$('#rt-delay').value || 0 } }); };
    $('#rt-on').onchange = e => { $('#rt-fields').style.display = e.target.checked ? '' : 'none'; collect(); };
    ['#rt-max', '#rt-bo', '#rt-delay'].forEach(s => { const el = $(s); if (el) el.onchange = collect; });
  }
  function renderEdgeInspector(id, body, ttl) {
    const e = gv.getEdge(id); if (!e) return; const back = gv.isBack(id); const src = gv.getNode(e.from);
    ttl.innerHTML = `连线`;
    const portable = src && (src.kind === 'control' || src.kind === 'approval');
    let h = `<div class="row-line"><span class="pill">${esc(e.from)}</span><span class="arr">→</span><span class="pill">${esc(e.to)}</span>${back ? '<span class="pill accent">↩ 回边/循环</span>' : ''}</div>`;
    if (portable) h += `<label class="fld"><span>端口</span><input id="f-port" class="ipt" value="${esc(e.port)}" ${src.kind === 'approval' ? 'placeholder="yes / no"' : ''}></label>`;
    else h += `<div class="hint" style="margin:8px 0">仅 control / approval 源的边带端口</div>`;
    h += `<div class="ins-foot"><button class="btn danger" id="del-edge">删除连线</button></div>`;
    body.innerHTML = h;
    if (portable) $('#f-port').onchange = ev => gv.updateEdge(id, { port: ev.target.value.trim() });
    $('#del-edge').onclick = () => gv.deleteSelected();
  }
  function renderRunInspector(n, body) {
    const run = gv.getRun();
    const stt = run.state[n.id] || 'future', m = run.memo[n.id] || {};
    let h = `<div class="pill"><span class="d" style="background:${FG.STATE[stt].c}"></span>${FG.STATE[stt].label}</div>`;
    if (run.iters[n.id] > 1) h += ` <span class="pill accent">×${run.iters[n.id]} 轮</span>`;
    if (n.retry) h += ` <span class="pill warn">↻ retry ${n.retry.maxAttempts}</span>`;
    h += `<div class="fld-l">ref</div><code class="mono">${esc(n.ref)}</code>`;
    if (m.loop) { h += `<div class="fld-l">迭代记忆化 <span class="hint">每轮一行 · UNIQUE(node,iteration)</span></div>`; m.loop.forEach(([i, o]) => h += `<div class="iter"><span class="i">${i}</span><span class="o">${esc(o)}</span></div>`); }
    else if (m.parked) {
      h += `<div class="fld-l">审批门 <span class="hint">parked 行 = 收件箱</span></div><div class="prompt">${esc(m.prompt)}</div>
        <div class="meta3">${esc(m.form || '')} · ${esc(m.ddl || '')} · first-wins</div>
        <div class="ins-foot"><button class="btn primary" id="ap-yes">通过</button><button class="btn" id="ap-no">驳回</button></div>`;
    } else if (m.error) { h += `<div class="fld-l">错误</div><pre class="err">${esc(m.error)}</pre>`; }
    else if (Object.keys(m).length) { h += `<div class="fld-l">记忆化 result</div><pre>${esc(JSON.stringify(m, null, 2))}</pre>`; }
    body.innerHTML = h;
    if (m.parked) { $('#ap-yes').onclick = () => { gv.resolveApproval(n.id, 'yes'); renderNote(); }; $('#ap-no').onclick = () => { gv.resolveApproval(n.id, 'no'); renderNote(); }; }
  }

  /* ============================ 小地图 ============================ */
  function renderMinimap() {
    const g = gv.getGraph(), mm = $('#minimap'); if (!g.nodes.length) { mm.innerHTML = ''; return; }
    const xs = g.nodes.map(n => n.x), ys = g.nodes.map(n => n.y);
    const minX = Math.min(...xs) - 20, minY = Math.min(...ys) - 20, maxX = Math.max(...xs) + FG.NW + 20, maxY = Math.max(...ys) + FG.NH + 20;
    const W = maxX - minX, H = maxY - minY;
    let svg = `<svg viewBox="${minX} ${minY} ${W} ${H}" preserveAspectRatio="xMidYMid meet" style="width:100%;height:100%">`;
    g.edges.forEach(e => { const a = byId(g, e.from), b = byId(g, e.to); if (a && b) svg += `<line x1="${a.x + FG.NW / 2}" y1="${a.y + FG.NH / 2}" x2="${b.x + FG.NW / 2}" y2="${b.y + FG.NH / 2}" stroke="var(--edge-future)" stroke-width="3"/>`; });
    g.nodes.forEach(n => svg += `<rect x="${n.x}" y="${n.y}" width="${FG.NW}" height="${FG.NH}" rx="8" fill="${FG.KIND[n.kind].c}" opacity="0.7"/>`);
    svg += `<rect id="mm-vp" fill="var(--accent-soft)" stroke="var(--accent)" stroke-width="4"/></svg>`;
    mm.innerHTML = svg; mm._box = { minX, minY, W, H }; renderMinimapViewport(gv.getView());
    mm.onpointerdown = ev => { const r = mm.getBoundingClientRect(), b = mm._box; const gx = b.minX + (ev.clientX - r.left) / r.width * b.W, gy = b.minY + (ev.clientY - r.top) / r.height * b.H; gv.panTo(gx, gy); };
  }
  function renderMinimapViewport(v) { const mm = $('#minimap'), vp = mm.querySelector('#mm-vp'); if (!vp || !v || !v.rect) return; vp.setAttribute('x', (-v.x) / v.k); vp.setAttribute('y', (-v.y) / v.k); vp.setAttribute('width', v.rect.width / v.k); vp.setAttribute('height', v.rect.height / v.k); }
  const byId = (g, id) => g.nodes.find(n => n.id === id);

  /* ============================ 文案 / 图例 ============================ */
  function renderNote() {
    const g = gv.getGraph(), nb = gv.backEdges().size;
    $('#note').innerHTML = `<b>${esc(curSample)}</b> · ${g.nodes.length} 节点 / ${g.edges.length} 边 · ${nb ? `<span class="k">${nb} 条回边（循环）</span>` : '无回边'}<br>` +
      (mode === 'run'
        ? '运行态：状态叠加 + 迭代 ×N（重影栈=每轮一行记忆化）+ 已走/未来/实时导电边。点节点看 result；parked 节点可决策。'
        : '编辑器：悬停节点露<b>四周圆圈</b>拖拽连线；<b>＋节点</b>加孤立节点；点节点/边在右侧改定义；拖动改位；<b>↻ 规范化</b>重排。');
  }
  function renderLegend() {
    $('#legend').innerHTML = mode === 'run'
      ? `<b>运行态</b><div class="ln"><span class="sw taken"></span>已走</div><div class="ln"><span class="sw loop"></span>实时导电(循环)</div><div class="ln"><span class="sw future"></span>未来</div>
         <div class="ln"><span class="dot" style="background:var(--accent)"></span>运行 <span class="dot" style="background:var(--ink-3)"></span>完成 <span class="dot" style="background:var(--warn)"></span>待审 <span class="dot" style="background:var(--danger)"></span>失败</div>`
      : `<b>连线</b><div class="ln"><span class="sw taken"></span>前向边</div><div class="ln"><span class="sw loop"></span>回边/循环</div>
         <div class="ln"><span class="dot" style="background:var(--violet)"></span>触发 <span class="dot" style="background:var(--accent)"></span>动作 <span class="dot" style="background:var(--teal)"></span>智能体 <span class="dot" style="background:var(--warn)"></span>分支 <span class="dot" style="background:var(--danger)"></span>审批</div>`;
  }

  /* ============================ 工具栏 ============================ */
  function seg(attr, fn) { $$(`[data-${attr}]`).forEach(b => b.onclick = () => { $$(`[data-${attr}]`).forEach(x => x.classList.toggle('on', x === b)); fn(b.getAttribute('data-' + attr)); }); }
  function toast(m) { let t = $('#toast'); t.textContent = m; t.classList.add('show'); clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('show'), 2200); }

  function initToolbar() {
    const sel = $('#sample'); Object.keys(FG.SAMPLES).forEach(k => { const o = document.createElement('option'); o.value = k; o.textContent = k; sel.appendChild(o); });
    sel.onchange = () => boot(sel.value);
    seg('mode', v => { mode = v; gv.setMode(v); renderNote(); renderLegend(); renderInspector(gv.getSelection()); $('#add-menu-btn').style.display = v === 'edit' ? '' : 'none'; $('#del-btn').style.display = v === 'edit' ? '' : 'none'; });
    seg('dir', v => { dir = v; gv.setDir(v); setTimeout(renderMinimap, 60); });
    $('#relayout').onclick = () => { gv.relayout(); setTimeout(renderMinimap, 60); };
    $('#undo').onclick = undo; $('#redo').onclick = redo;
    $('#theme').onclick = () => { const d = document.documentElement; d.dataset.theme = d.dataset.theme === 'dark' ? '' : 'dark'; gv.fit(); };
    $('#zin').onclick = () => gv.zoomBy(1.2); $('#zout').onclick = () => gv.zoomBy(1 / 1.2); $('#zfit').onclick = () => gv.fit();
    $('#ops-btn').onclick = () => { $('#opslog').classList.toggle('open'); $('#ops-btn').classList.toggle('on'); renderOps(); };
    // 加节点菜单
    const menu = $('#add-menu');
    menu.innerHTML = FG.KIND_ORDER.map(k => `<div class="mi" data-k="${k}"><span class="mi-c" style="--kc:${FG.KIND[k].c}"></span>${FG.KIND[k].label} <span class="mi-s">${k}</span></div>`).join('');
    $('#add-menu-btn').onclick = e => { e.stopPropagation(); menu.classList.toggle('open'); };
    document.addEventListener('pointerdown', e => { if (!e.target.closest('#add-wrap')) menu.classList.remove('open'); });
    $$('.mi', menu).forEach(mi => mi.onclick = () => { menu.classList.remove('open'); gv.addNode(mi.dataset.k); setTimeout(renderMinimap, 30); });
    document.addEventListener('keydown', e => {
      if (/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) return;
      const mod = e.metaKey || e.ctrlKey;
      if (mod && e.key.toLowerCase() === 'z') { e.preventDefault(); e.shiftKey ? redo() : undo(); }
      else if (mod && e.key.toLowerCase() === 'y') { e.preventDefault(); redo(); }
      else if ((e.key === 'Delete' || e.key === 'Backspace') && mode === 'edit' && gv.getSelection()) { e.preventDefault(); gv.deleteSelected(); }
      else if (e.key === 'Escape') gv.select(null);
    });
  }

  /* ---- 启动 ---- */
  initToolbar();
  boot(Object.keys(FG.SAMPLES)[0]);
})();
