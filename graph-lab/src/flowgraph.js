/* ============================================================================
   Anselm flow-graph · 视图组件（逃生舱：自绘 SVG + 吃 token）
   职责：分层自动布局 · 浮动正交连线路由 · 渲染 · 画布交互（缩放/平移/拖拽/连线/选中）。
   连线 = 浮动边：锚到「朝向对方的那一面」→ 任意相对位置都干净（修掉斜穿/倒灌的丑线）。
   API：FlowGraph.mount(host, opts) → handle。opts: {graph, mode, dir, run, onSelect, onChange, onToast}。
============================================================================ */
(function () {
  const FG = window.FG;
  const { NW, NH, GAPX, GAPY, PAD, STUB, CORNER, LOOP_GAP } = FG;
  const SVGNS = 'http://www.w3.org/2000/svg';
  const el = (t, a) => { const e = document.createElementNS(SVGNS, t); for (const k in a) e.setAttribute(k, a[k]); return e; };
  const esc = s => String(s == null ? '' : s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));

  /* ============================ 几何 / 路由 ============================ */
  const center = n => ({ x: n.x + NW / 2, y: n.y + NH / 2 });
  const anchor = (n, side) => ({ top: { x: n.x + NW / 2, y: n.y }, bottom: { x: n.x + NW / 2, y: n.y + NH }, left: { x: n.x, y: n.y + NH / 2 }, right: { x: n.x + NW, y: n.y + NH / 2 } }[side]);
  const normal = side => ({ top: { x: 0, y: -1 }, bottom: { x: 0, y: 1 }, left: { x: -1, y: 0 }, right: { x: 1, y: 0 } }[side]);
  // 朝向：按中心向量（按卡片长宽比归一）决定两端各连哪一面
  function facing(a, b) {
    const ac = center(a), bc = center(b), dx = bc.x - ac.x, dy = bc.y - ac.y;
    const horiz = Math.abs(dx) * NH >= Math.abs(dy) * NW;
    return horiz ? [dx >= 0 ? 'right' : 'left', dx >= 0 ? 'left' : 'right'] : [dy >= 0 ? 'bottom' : 'top', dy >= 0 ? 'top' : 'bottom'];
  }
  function roundedPath(raw, r) {
    const pts = [];
    raw.forEach(p => { const l = pts[pts.length - 1]; if (!l || Math.abs(l.x - p.x) > 0.5 || Math.abs(l.y - p.y) > 0.5) pts.push(p); });
    if (pts.length < 2) return pts.length ? `M${pts[0].x},${pts[0].y}` : '';
    let d = `M${pts[0].x},${pts[0].y}`;
    for (let i = 1; i < pts.length - 1; i++) {
      const p = pts[i], a = pts[i - 1], b = pts[i + 1];
      const v1 = { x: p.x - a.x, y: p.y - a.y }, v2 = { x: b.x - p.x, y: b.y - p.y };
      const l1 = Math.hypot(v1.x, v1.y) || 1, l2 = Math.hypot(v2.x, v2.y) || 1, rr = Math.min(r, l1 / 2, l2 / 2);
      d += ` L${p.x - v1.x / l1 * rr},${p.y - v1.y / l1 * rr} Q${p.x},${p.y} ${p.x + v2.x / l2 * rr},${p.y + v2.y / l2 * rr}`;
    }
    const last = pts[pts.length - 1]; return d + ` L${last.x},${last.y}`;
  }
  function pointAtMid(pts) {
    let total = 0; for (let i = 1; i < pts.length; i++) total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
    let d = total / 2;
    for (let i = 1; i < pts.length; i++) { const seg = Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y); if (d <= seg) { const t = seg ? d / seg : 0; return { x: pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t, y: pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t }; } d -= seg; }
    return pts[pts.length - 1];
  }
  // 前向边：浮动正交（带圆角），任意相对位置都顺
  function orthoPath(a, b) {
    const [sa, sb] = facing(a, b);
    const S = anchor(a, sa), T = anchor(b, sb), ns = normal(sa), nt = normal(sb);
    const S1 = { x: S.x + ns.x * STUB, y: S.y + ns.y * STUB }, T1 = { x: T.x + nt.x * STUB, y: T.y + nt.y * STUB };
    const sh = sa === 'left' || sa === 'right', th = sb === 'left' || sb === 'right';
    let pts;
    if (sh && th) { const mx = (S1.x + T1.x) / 2; pts = [S, S1, { x: mx, y: S1.y }, { x: mx, y: T1.y }, T1, T]; }
    else if (!sh && !th) { const my = (S1.y + T1.y) / 2; pts = [S, S1, { x: S1.x, y: my }, { x: T1.x, y: my }, T1, T]; }
    else { const corner = sh ? { x: T1.x, y: S1.y } : { x: S1.x, y: T1.y }; pts = [S, S1, corner, T1, T]; }
    return { pts, d: roundedPath(pts, CORNER), mid: pointAtMid(pts) };
  }

  /* ============================ 分层布局（Sugiyama-lite，处理回边）============================ */
  function layout(G, dir) {
    const back = FG.backEdges(G);
    const fwd = G.edges.filter(e => !back.has(e.id));
    const succ = {}, pred = {}, indeg = {};
    G.nodes.forEach(n => { succ[n.id] = []; pred[n.id] = []; indeg[n.id] = 0; });
    fwd.forEach(e => { if (succ[e.from]) { succ[e.from].push(e.to); pred[e.to].push(e.from); indeg[e.to]++; } });
    const rank = {}, q = G.nodes.filter(n => indeg[n.id] === 0).map(n => n.id); q.forEach(id => rank[id] = 0);
    const ind = { ...indeg };
    while (q.length) { const u = q.shift(); succ[u].forEach(v => { rank[v] = Math.max(rank[v] ?? 0, (rank[u] ?? 0) + 1); if (--ind[v] === 0) q.push(v); }); }
    G.nodes.forEach(n => { if (rank[n.id] == null) rank[n.id] = 0; });
    const maxR = Math.max(0, ...G.nodes.map(n => rank[n.id]));
    const layers = Array.from({ length: maxR + 1 }, () => []);
    G.nodes.forEach(n => layers[rank[n.id]].push(n.id));
    const pos = {}; layers.forEach(L => L.forEach((id, i) => pos[id] = i));
    const med = (id, adj) => { const ps = adj[id].map(x => pos[x]).filter(v => v != null); if (!ps.length) return pos[id]; ps.sort((a, b) => a - b); return ps[(ps.length - 1) >> 1]; };
    for (let p = 0; p < 8; p++) { const down = p % 2 === 0;
      (down ? [...layers.keys()] : [...layers.keys()].reverse()).forEach(li => { const adj = down ? pred : succ;
        layers[li] = layers[li].map(id => ({ id, m: med(id, adj) })).sort((a, b) => a.m - b.m).map(o => o.id);
        layers[li].forEach((id, i) => pos[id] = i); });
    }
    const horiz = dir === 'LR', main = horiz ? NW + GAPX : NH + GAPY, cross = horiz ? NH + GAPY : NW + GAPX;
    const maxLen = Math.max(...layers.map(L => L.length));
    layers.forEach((L, li) => { const off = (maxLen - L.length) * cross / 2;
      L.forEach((id, i) => { const node = FG.nodeById(G, id), m = PAD + li * main, c = PAD + off + i * cross; if (horiz) { node.x = m; node.y = c; } else { node.x = c; node.y = m; } });
    });
  }

  /* ============================ 组件 ============================ */
  function mount(host, opts) {
    opts = opts || {};
    const S = {
      G: opts.graph || { nodes: [], edges: [] },
      mode: opts.mode || 'edit', dir: opts.dir || 'LR', run: opts.run || null,
      sel: null, view: { x: 60, y: 60, k: 1 }, hover: null, back: new Set(), bounds: { maxX: 0, maxY: 0 },
    };
    const onSelect = opts.onSelect || (() => {}), onChange = opts.onChange || (() => {}), toast = opts.onToast || (() => {});

    const cv = el('svg', { class: 'fg-canvas' });
    cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;display:block;cursor:grab';
    host.appendChild(cv);

    /* ---- 派生 ---- */
    function recompute() { S.back = FG.backEdges(S.G); }
    function bounds() {
      S.bounds.maxX = Math.max(NW, ...S.G.nodes.map(n => n.x + NW));
      S.bounds.maxY = Math.max(NH, ...S.G.nodes.map(n => n.y + NH));
      const ch = S.back.size ? 16 + S.back.size * LOOP_GAP + 8 : 0, horiz = S.dir === 'LR';
      S._w = S.bounds.maxX + PAD + (horiz ? 0 : ch); S._h = S.bounds.maxY + PAD + (horiz ? ch : 0);
    }
    function loopPath(a, b, bi) {
      const off = 16 + bi * LOOP_GAP;
      if (S.dir === 'LR') { const sx = a.x + NW / 2, sy = a.y + NH, tx = b.x + NW / 2, ty = b.y + NH, ch = S.bounds.maxY + off;
        const pts = [{ x: sx, y: sy }, { x: sx, y: ch }, { x: tx, y: ch }, { x: tx, y: ty }]; return { pts, d: roundedPath(pts, CORNER), mid: { x: (sx + tx) / 2, y: ch } }; }
      const sx = a.x + NW, sy = a.y + NH / 2, tx = b.x + NW, ty = b.y + NH / 2, ch = S.bounds.maxX + off;
      const pts = [{ x: sx, y: sy }, { x: ch, y: sy }, { x: ch, y: ty }, { x: tx, y: ty }]; return { pts, d: roundedPath(pts, CORNER), mid: { x: ch, y: (sy + ty) / 2 } };
    }

    /* ---- 坐标换算 ---- */
    const toGraph = ev => { const r = cv.getBoundingClientRect(); return { x: (ev.clientX - r.left - S.view.x) / S.view.k, y: (ev.clientY - r.top - S.view.y) / S.view.k }; };
    const nodeAt = (gx, gy) => { for (let i = S.G.nodes.length - 1; i >= 0; i--) { const n = S.G.nodes[i]; if (gx >= n.x && gx <= n.x + NW && gy >= n.y && gy <= n.y + NH) return n; } return null; };
    const applyView = () => { const r = cv.querySelector('#fg-root'); if (r) r.setAttribute('transform', `translate(${S.view.x},${S.view.y}) scale(${S.view.k})`); emitView(); };
    const emitView = () => opts.onView && opts.onView({ x: S.view.x, y: S.view.y, k: S.view.k, w: S._w, h: S._h, rect: cv.getBoundingClientRect() });

    /* ============================ 渲染 ============================ */
    function render() {
      recompute(); bounds();
      cv.innerHTML = '';
      const defs = el('defs', {});
      defs.innerHTML = mk('ah', 'var(--edge)') + mk('ah-taken', 'var(--ink)') + mk('ah-fut', 'var(--edge-future)') + mk('ah-loop', 'var(--accent)', true) + mk('ah-sel', 'var(--accent)') +
        '<filter id="fg-lift" x="-30%" y="-40%" width="160%" height="180%"><feDropShadow dx="0" dy="1.5" stdDeviation="3" flood-color="#000" flood-opacity="0.10"/></filter>';
      cv.appendChild(defs);
      const root = el('g', { id: 'fg-root', transform: `translate(${S.view.x},${S.view.y}) scale(${S.view.k})` }); cv.appendChild(root);
      const eL = el('g', {}), nL = el('g', {}), oL = el('g', { id: 'fg-overlay' }); root.appendChild(eL); root.appendChild(nL); root.appendChild(oL);

      const by = {}; S.G.nodes.forEach(n => by[n.id] = n);
      const taken = new Set(S.run && S.mode === 'run' ? S.run.taken : []); const live = S.mode === 'run' && S.run ? S.run.live : null;
      let li = 0; const loopOrd = {}; S.G.edges.forEach(e => { if (S.back.has(e.id)) loopOrd[e.id] = li++; });

      S.G.edges.forEach(e => {
        const a = by[e.from], b = by[e.to]; if (!a || !b) return;
        const isBack = S.back.has(e.id), selE = S.sel && S.sel.type === 'edge' && S.sel.id === e.id;
        let tier = 'base';
        if (S.mode === 'run') tier = e.id === live ? 'live' : taken.has(e.id) ? 'taken' : (S.run.state[e.to] && S.run.state[e.to] !== 'future' ? 'base' : 'future');
        const route = isBack ? loopPath(a, b, loopOrd[e.id]) : orthoPath(a, b);
        let stroke = 'var(--edge)', mk2 = 'url(#ah)', w = 1.8, dash = '';
        if (isBack) { stroke = 'var(--accent)'; mk2 = 'url(#ah-loop)'; dash = '6 5'; }
        if (tier === 'taken') { stroke = 'var(--ink)'; mk2 = 'url(#ah-taken)'; w = 2.3; if (isBack) dash = '6 5'; }
        if (tier === 'future') { stroke = 'var(--edge-future)'; mk2 = 'url(#ah-fut)'; dash = '5 5'; }
        if (tier === 'live') { stroke = 'var(--accent)'; mk2 = 'url(#ah-loop)'; w = 2.6; dash = isBack ? '6 5' : ''; }
        if (selE) { stroke = 'var(--accent)'; mk2 = 'url(#ah-sel)'; w = 2.6; }
        const p = el('path', { d: route.d, fill: 'none', stroke, 'stroke-width': w, 'marker-end': mk2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' });
        if (dash) p.setAttribute('stroke-dasharray', dash); eL.appendChild(p);
        // 命中条（点边选中，编辑模式）
        if (S.mode === 'edit') { const hit = el('path', { d: route.d, fill: 'none', stroke: 'transparent', 'stroke-width': 14, class: 'fg-edge-hit' });
          hit.style.cursor = 'pointer'; hit.addEventListener('pointerdown', ev => { ev.stopPropagation(); selectEdge(e.id); }); eL.appendChild(hit); }
        if (tier === 'live') { const comet = el('circle', { r: 3.6, fill: 'var(--accent)' }); comet.appendChild(el('animateMotion', { dur: '1.1s', repeatCount: 'indefinite', path: route.d })); eL.appendChild(comet); }
        if (e.port) { const g = el('g', { transform: `translate(${route.mid.x},${route.mid.y})` }), tw = e.port.length * 12 + 14;
          g.appendChild(el('rect', { x: -tw / 2, y: -9, width: tw, height: 18, rx: 6, fill: 'var(--island)', stroke: isBack || selE ? 'var(--accent-line)' : 'var(--line)', 'stroke-width': 1 }));
          const t = el('text', { x: 0, y: 4, 'text-anchor': 'middle', 'font-size': 11, 'font-weight': 600, fill: isBack ? 'var(--accent)' : 'var(--ink-2)' }); t.textContent = e.port; g.appendChild(t); eL.appendChild(g); }
      });

      S.G.nodes.forEach(n => {
        const k = FG.KIND[n.kind] || FG.KIND.action;
        const st = S.mode === 'run' ? (S.run.state[n.id] || 'future') : 'ready', ST = FG.STATE[st] || FG.STATE.ready;
        const iters = S.mode === 'run' && S.run.iters[n.id] || 0, selN = S.sel && S.sel.type === 'node' && S.sel.id === n.id;
        const g = el('g', { class: 'fg-node', transform: `translate(${n.x},${n.y})`, 'data-id': n.id });
        if (iters > 1) { g.appendChild(el('rect', { x: 6, y: 6, width: NW, height: NH, rx: 14, fill: ST.fill, stroke: ST.ring, opacity: .35 })); g.appendChild(el('rect', { x: 3, y: 3, width: NW, height: NH, rx: 14, fill: ST.fill, stroke: ST.ring, opacity: .6 })); }
        const card = el('rect', { class: 'fg-card', width: NW, height: NH, rx: 14, fill: ST.fill, stroke: selN ? 'var(--accent)' : ST.ring, 'stroke-width': selN ? 2 : (st === 'running' || st === 'failed' || st === 'parked' ? 1.6 : 1), filter: 'url(#fg-lift)' });
        g.appendChild(card);
        if (st === 'running') { const pr = el('rect', { width: NW, height: NH, rx: 14, fill: 'none', stroke: 'var(--accent)', 'stroke-width': 2, opacity: 0 }); pr.appendChild(el('animate', { attributeName: 'opacity', values: '0;.5;0', dur: '1.6s', repeatCount: 'indefinite' })); g.appendChild(pr); }
        if (st === 'future') card.setAttribute('stroke-dasharray', '4 4');
        g.appendChild(el('rect', { x: 12, y: 17, width: 26, height: 26, rx: 8, fill: k.s }));
        g.appendChild(el('path', { d: k.ico, transform: 'translate(18,23) scale(0.58)', fill: 'none', stroke: k.c, 'stroke-width': 2.6, 'stroke-linecap': 'round', 'stroke-linejoin': 'round' }));
        const id = el('text', { x: 48, y: 26, 'font-size': 13.5, 'font-weight': 600, fill: 'var(--ink)' }); id.textContent = n.id; g.appendChild(id);
        const ref = el('text', { x: 48, y: 44, 'font-size': 11.5, fill: 'var(--ink-3)', 'font-family': 'var(--mono)' }); ref.textContent = (n.ref || '').length > 20 ? n.ref.slice(0, 19) + '…' : n.ref; g.appendChild(ref);
        if (S.mode === 'run') g.appendChild(el('circle', { cx: NW - 15, cy: 15, r: 4, fill: ST.c }));
        else if (n.retry) { g.appendChild(el('circle', { cx: NW - 16, cy: 16, r: 7.5, fill: 'var(--warn-soft)' })); const rt = el('text', { x: NW - 16, y: 19.5, 'text-anchor': 'middle', 'font-size': 9, 'font-weight': 700, fill: 'var(--warn)' }); rt.textContent = '↻'; g.appendChild(rt); }
        if (iters > 1) { g.appendChild(el('rect', { x: NW - 40, y: NH - 19, width: 32, height: 15, rx: 7.5, fill: 'var(--accent-soft)' })); const t = el('text', { x: NW - 24, y: NH - 8, 'text-anchor': 'middle', 'font-size': 10.5, 'font-weight': 700, fill: 'var(--accent)' }); t.textContent = '×' + iters; g.appendChild(t); }
        // 四向连接桩（编辑模式；hover 节点或连线进行中显）
        if (S.mode === 'edit') [['top', NW / 2, 0], ['right', NW, NH / 2], ['bottom', NW / 2, NH], ['left', 0, NH / 2]].forEach(([side, hx, hy]) => {
          const hg = el('g', { class: 'fg-handle' });
          hg.appendChild(el('circle', { cx: hx, cy: hy, r: 11, fill: 'transparent' }));
          hg.appendChild(el('circle', { class: 'fg-handle-dot', cx: hx, cy: hy, r: 4.5 }));
          hg.style.cursor = 'crosshair'; hg.addEventListener('pointerdown', ev => startConnect(ev, n, side)); g.appendChild(hg);
        });
        g.addEventListener('pointerdown', ev => startNodeDrag(ev, n));
        nL.appendChild(g);
      });
    }
    function mk(id, color, big) { const s = big ? 'M0,0 L7.5,3.2 L0,6.4 Z' : 'M0,0 L7,3 L0,6 Z'; const r = big ? 3.2 : 3, w = big ? 10 : 9;
      return `<marker id="${id}" markerWidth="${w}" markerHeight="${w}" refX="${big ? 8 : 7.5}" refY="${r}" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><path d="${s}" fill="${color}"/></marker>`; }

    /* ============================ 交互：缩放 / 平移 ============================ */
    cv.addEventListener('wheel', ev => { ev.preventDefault(); const r = cv.getBoundingClientRect(), mx = ev.clientX - r.left, my = ev.clientY - r.top, f = Math.exp(-ev.deltaY * 0.0015), nk = Math.min(2.5, Math.max(.2, S.view.k * f)), kr = nk / S.view.k; S.view.x = mx - (mx - S.view.x) * kr; S.view.y = my - (my - S.view.y) * kr; S.view.k = nk; applyView(); }, { passive: false });
    let pan = null;
    cv.addEventListener('pointerdown', ev => { if (ev.target.closest('.fg-node') || ev.target.closest('.fg-edge-hit')) return; if (S.sel) { S.sel = null; render(); onSelect(null); } pan = { x: ev.clientX, y: ev.clientY, vx: S.view.x, vy: S.view.y }; cv.style.cursor = 'grabbing'; cv.setPointerCapture(ev.pointerId); });
    cv.addEventListener('pointermove', ev => { if (!pan) return; S.view.x = pan.vx + (ev.clientX - pan.x); S.view.y = pan.vy + (ev.clientY - pan.y); applyView(); });
    cv.addEventListener('pointerup', () => { pan = null; cv.style.cursor = 'grab'; });
    function fit() { bounds(); const r = cv.getBoundingClientRect(), pd = 60; const k = Math.min((r.width - pd * 2) / S._w, (r.height - pd * 2) / S._h, 1.3); S.view.k = Math.max(.25, k || 1); S.view.x = (r.width - S._w * S.view.k) / 2; S.view.y = (r.height - S._h * S.view.k) / 2; applyView(); }

    /* ============================ 交互：拖节点 ============================ */
    let nd = null;
    function startNodeDrag(ev, n) { if (ev.target.closest('.fg-handle')) return; ev.stopPropagation(); selectNode(n.id); if (S.mode !== 'edit') return; nd = { n, x: ev.clientX, y: ev.clientY, nx: n.x, ny: n.y, moved: false }; window.addEventListener('pointermove', ndMove); window.addEventListener('pointerup', ndUp); }
    function ndMove(ev) { if (!nd) return; const dx = (ev.clientX - nd.x) / S.view.k, dy = (ev.clientY - nd.y) / S.view.k; if (Math.abs(dx) + Math.abs(dy) > 2) nd.moved = true; nd.n.x = nd.nx + dx; nd.n.y = nd.ny + dy; render(); }
    function ndUp() { window.removeEventListener('pointermove', ndMove); window.removeEventListener('pointerup', ndUp); if (nd && nd.moved) { nd.n.pos = { x: Math.round(nd.n.x), y: Math.round(nd.n.y) }; onChange({ ops: [FG.ops.updateNode(nd.n.id, { pos: nd.n.pos })], label: '移动', minor: true }); } nd = null; }

    /* ============================ 交互：连线（四向桩）============================ */
    let conn = null;
    function startConnect(ev, node, side) {
      ev.stopPropagation(); ev.preventDefault(); cv.classList.add('connecting');
      const A = anchor(node, side), nrm = normal(side);
      conn = { from: node.id, A, nrm, path: el('path', { fill: 'none', stroke: 'var(--accent)', 'stroke-width': 2, 'stroke-dasharray': '4 4', 'stroke-linecap': 'round' }) };
      cv.querySelector('#fg-overlay').appendChild(conn.path);
      window.addEventListener('pointermove', connMove); window.addEventListener('pointerup', connUp);
    }
    function connMove(ev) {
      if (!conn) return; const p = toGraph(ev), c1 = { x: conn.A.x + conn.nrm.x * 44, y: conn.A.y + conn.nrm.y * 44 };
      conn.path.setAttribute('d', `M${conn.A.x},${conn.A.y} C${c1.x},${c1.y} ${p.x},${p.y} ${p.x},${p.y}`);
      const t = nodeAt(p.x, p.y); cv.querySelectorAll('.fg-node').forEach(g => g.classList.toggle('hl', !!t && t.id !== conn.from && g.dataset.id === t.id));
    }
    function connUp(ev) {
      window.removeEventListener('pointermove', connMove); window.removeEventListener('pointerup', connUp); cv.classList.remove('connecting');
      cv.querySelectorAll('.fg-node').forEach(g => g.classList.remove('hl'));
      const p = toGraph(ev), t = nodeAt(p.x, p.y); if (conn.path.remove) conn.path.remove();
      const from = conn.from; conn = null; if (t && t.id !== from) addEdge(from, t.id);
    }

    /* ============================ 变更（生成 ops + 通知）============================ */
    function addEdge(from, to) {
      const v = FG.validateEdge(S.G, from, to); if (!v.ok) return toast(v.reason);
      const edge = { id: FG.uid('e'), from, to, port: v.port }; S.G.edges.push(edge); recompute();
      onChange({ ops: [FG.ops.addEdge(edge)], label: '连线 ' + from + '→' + to + (v.port ? ' (' + v.port + ')' : '') });
      selectEdge(edge.id); toast('已连线 ' + from + ' → ' + to + (v.port ? ' (' + v.port + ')' : ''));
    }
    function addNode(kind, at) {
      const id = uniqueId(kind), node = { id, kind, ref: FG.KIND[kind].prefix + 'new', input: {} };
      const r = cv.getBoundingClientRect(); node.x = at ? at.x : (r.width / 2 - S.view.x) / S.view.k - NW / 2; node.y = at ? at.y : (r.height / 2 - S.view.y) / S.view.k - NH / 2;
      node.pos = { x: Math.round(node.x), y: Math.round(node.y) }; S.G.nodes.push(node); if (S.run) S.run.state[id] = 'future'; recompute();
      onChange({ ops: [FG.ops.addNode(node)], label: '加节点 ' + id }); selectNode(id); toast('已加节点 ' + id + '：拖动定位，悬停露出四周圆圈连线');
    }
    function uniqueId(kind) { const base = ({ trigger: 'trigger', action: 'task', agent: 'agent', control: 'route', approval: 'review' })[kind]; let i = 1, id = base; while (FG.nodeById(S.G, id)) id = base + (++i); return id; }
    function deleteSel() {
      if (!S.sel || S.mode !== 'edit') return;
      if (S.sel.type === 'node') { const id = S.sel.id; const cascade = S.G.edges.filter(e => e.from === id || e.to === id).map(e => FG.ops.deleteEdge(e.id));
        S.G.nodes = S.G.nodes.filter(n => n.id !== id); S.G.edges = S.G.edges.filter(e => e.from !== id && e.to !== id); recompute();
        onChange({ ops: [FG.ops.deleteNode(id), ...cascade], label: '删节点 ' + id }); }
      else { const id = S.sel.id; S.G.edges = S.G.edges.filter(e => e.id !== id); recompute(); onChange({ ops: [FG.ops.deleteEdge(id)], label: '删边' }); }
      S.sel = null; onSelect(null); render();
    }
    function updateNode(id, patch) {
      const node = FG.nodeById(S.G, id); if (!node) return; Object.assign(node, patch); if (patch.input) node.input = patch.input; recompute();
      onChange({ ops: [FG.ops.updateNode(id, patch)], label: '改节点 ' + id }); render(); onSelect(S.sel);
    }
    function updateEdge(id, patch) { const e = S.G.edges.find(x => x.id === id); if (!e) return; Object.assign(e, patch); recompute(); onChange({ ops: [FG.ops.updateEdge(id, { fromPort: patch.port })], label: '改端口' }); render(); onSelect(S.sel); }

    /* ---- 选中 ---- */
    function selectNode(id) { S.sel = { type: 'node', id }; render(); onSelect(S.sel); }
    function selectEdge(id) { S.sel = { type: 'edge', id }; render(); onSelect(S.sel); }

    /* ---- 运行态：审批决策（轻量模拟推进）---- */
    function resolveApproval(id, decision) {
      if (!S.run) return; S.run.state[id] = 'completed'; const m = S.run.memo[id] || (S.run.memo[id] = {}); delete m.parked; m.decision = decision;
      const next = S.G.edges.find(e => e.from === id && e.port === decision); if (next) { S.run.taken.push(next.id); S.run.state[next.to] = 'running'; S.run.live = next.id; }
      render(); onSelect(S.sel);
    }

    /* 键盘（Del/Esc）由演示外壳 app.js 在 document 层统一处理，避免每次 mount 叠加监听。 */

    /* ============================ 公开 handle ============================ */
    recompute(); render();
    const handle = {
      el: cv,
      setMode(m) { S.mode = m; if (m === 'run') S.sel = null; render(); onSelect(S.sel); },
      setDir(d) { S.dir = d; layout(S.G, d); render(); fit(); },
      setRun(r) { S.run = r; render(); },
      setGraph(g) { S.G = g; S.sel = null; recompute(); render(); onSelect(null); },
      getGraph: () => FG.clone(S.G),
      getRun: () => S.run,
      getSelection: () => S.sel,
      getNode: id => FG.nodeById(S.G, id), getEdge: id => S.G.edges.find(e => e.id === id),
      relayout() { layout(S.G, S.dir); render(); fit(); }, fit,
      zoomBy(f) { const r = cv.getBoundingClientRect(), mx = r.width / 2, my = r.height / 2, nk = Math.min(2.5, Math.max(.2, S.view.k * f)), kr = nk / S.view.k; S.view.x = mx - (mx - S.view.x) * kr; S.view.y = my - (my - S.view.y) * kr; S.view.k = nk; applyView(); },
      panTo(cx, cy) { const r = cv.getBoundingClientRect(); S.view.x = r.width / 2 - cx * S.view.k; S.view.y = r.height / 2 - cy * S.view.k; applyView(); },
      getView: () => ({ ...S.view, w: S._w, h: S._h, rect: cv.getBoundingClientRect() }),
      addNode, addEdge, updateNode, updateEdge, deleteSelected: deleteSel, resolveApproval,
      select: sel => { if (!sel) { S.sel = null; render(); onSelect(null); } else if (sel.type === 'edge') selectEdge(sel.id); else selectNode(sel.id); },
      backEdges: () => S.back, isBack: id => S.back.has(id),
    };
    // 首帧布局 + 适配
    layout(S.G, S.dir); render(); requestAnimationFrame(fit);
    return handle;
  }

  window.FlowGraph = { mount, layout };
})();
