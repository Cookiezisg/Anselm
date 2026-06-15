/* Forgify design-lab — 【Documents 海洋】的左侧栏内容（独立文件，一人负责；与外壳/别的海洋解耦）。
   外壳 sidebar.js 据四导航按需懒加载本文件；自注入 documents.css，经 SideBar.register('documents', render) 挂载。
   定位：文档库的【树导航器】——浏览/组织/选中打开。编辑器在海面、TOC/反链在右岛，侧栏一概不碰。
   类名全 dt-（document-tree）专属，避让 doc-*(海面)/da-*(右岛)/cv-·cm-·cvsec-(chat 侧栏)。依赖 icon()（只读）。 */
(function () {
  // 自注入样式（自包含，只一次）
  const dir = new URL('.', document.currentScript.src).href;
  if (!document.querySelector('link[data-sb="documents"]')) {
    const l = document.createElement('link');
    l.rel = 'stylesheet'; l.href = dir + 'documents.css'; l.dataset.sb = 'documents';
    document.head.appendChild(l);
  }

  // 示意树（接后端 = GET /documents/tree 的 metadata；整树一趟拉、折叠纯前端）。u = 更新新近度(示意,越大越新)。
  const TREE = [
    { id: 'd1', name: 'Product', u: 4, children: [
      { id: 'd2', name: 'Frontend', u: 6, children: [
        { id: 'd3', name: '文档页设计', u: 9, on: true },
        { id: 'd4', name: 'Roadmap 2026', u: 7 },
      ] },
      { id: 'd5', name: '竞品列表', u: 3 },
    ] },
    { id: 'd6', name: 'Engineering', u: 8, children: [
      { id: 'd7', name: 'Backend 重构记录', u: 2 },
      { id: 'd8', name: 'API 契约', u: 8 },
    ] },
    { id: 'd9', name: '随手记', u: 5 },
  ];
  const RECENT = [{ id: 'd3', name: '文档页设计' }, { id: 'd8', name: 'API 契约' }, { id: 'd4', name: 'Roadmap 2026' }];

  // 排序/展示状态（filter 行 sliders 控制；跨重绘保留）
  let sort = 'manual', showRecent = true;

  // 树节点（递归）：缩进按 depth；有子=分支(默认展开)；data-pos 原序(Manual 复位)、data-u 新近度(Recently edited)。
  const node = (n, depth, pos) => {
    const kids = n.children && n.children.length;
    return `<div class="dt-node${kids ? ' branch open' : ''}">
      <div class="dt-row${n.on ? ' on' : ''}" data-id="${n.id}" data-pos="${pos}" data-u="${n.u || 0}" style="padding-left:${8 + depth * 15}px">
        <span class="dt-chev">${kids ? icon('chevr', 13) : ''}</span>
        <span class="dt-ico">${icon('doc', 15)}</span>
        <span class="dt-name">${n.name}</span>
        <button class="dt-act dt-add" title="New sub-page">${icon('plus', 15)}</button>
        <button class="dt-act dt-more" title="More">${icon('more', 15)}</button>
      </div>
      ${kids ? `<div class="dt-children">${n.children.map((c, i) => node(c, depth + 1, i)).join('')}</div>` : ''}
    </div>`;
  };
  const recentRow = r => `<div class="dt-row dt-rrow" data-id="${r.id}"><span class="dt-ico">${icon('doc', 15)}</span><span class="dt-name">${r.name}</span></div>`;
  const dopt = (k, v, on, label) => `<button class="dt-disp-opt${on ? ' on' : ''}" data-${k}="${v}"><span class="dt-disp-ck">${icon('check', 14)}</span>${label}</button>`;

  function build() {
    if (!TREE.length) return `
      <button class="dt-new">${icon('plus', 18)}<span>New document</span></button>
      <div class="dt-empty">${icon('doc', 30)}<p>No documents yet</p></div>`;
    return `
      <button class="dt-new">${icon('plus', 18)}<span>New document</span></button>
      <div class="dt-filter">${icon('search', 16)}<input type="text" placeholder="Filter by name…">
        <button class="dt-disp" title="Sort & filter">${icon('sliders', 16)}</button>
        <div class="dt-disp-menu">
          <div class="dt-disp-h">Sort by</div>
          ${dopt('sort', 'manual', sort === 'manual', 'Manual order')}
          ${dopt('sort', 'name', sort === 'name', 'Name A–Z')}
          ${dopt('sort', 'recent', sort === 'recent', 'Recently edited')}
          <div class="dt-disp-h">Display</div>
          ${dopt('show', 'recent', showRecent, 'Show recent')}
        </div>
      </div>
      <div class="dt-list">
        <div class="dt-sec open"${showRecent ? '' : ' style="display:none"'}>
          <button class="dt-sec-h"><span class="dt-sec-t">Recent</span><span class="dt-chev">${icon('chevr', 13)}</span></button>
          <div class="dt-sec-body">${RECENT.map(recentRow).join('')}</div>
        </div>
        <div class="dt-tree">${TREE.map((n, i) => node(n, 0, i)).join('')}</div>
      </div>`;
  }

  // 就地按 sort 重排树的兄弟节点（递归；不重渲染，保留展开态/菜单态）
  function applySort(host, mode) {
    const sortIn = container => {
      const nodes = [...container.children].filter(x => x.classList.contains('dt-node'));
      nodes.sort((a, b) => {
        const ra = a.querySelector(':scope > .dt-row'), rb = b.querySelector(':scope > .dt-row');
        if (mode === 'name') return ra.querySelector('.dt-name').textContent.localeCompare(rb.querySelector('.dt-name').textContent, 'zh');
        if (mode === 'recent') return (+rb.dataset.u) - (+ra.dataset.u);
        return (+ra.dataset.pos) - (+rb.dataset.pos);   // manual = 原序
      });
      nodes.forEach(n => { container.appendChild(n); const c = n.querySelector(':scope > .dt-children'); if (c) sortIn(c); });
    };
    const tree = host.querySelector('.dt-tree'); if (tree) sortIn(tree);
  }

  function render(host) {
    host.innerHTML = build();
    const tree = host.querySelector('.dt-tree');

    // 展开/折叠（点 chevron，不冒泡到选中）
    host.querySelectorAll('.dt-node.branch > .dt-row .dt-chev').forEach(c => c.onclick = e => {
      e.stopPropagation(); c.closest('.dt-node').classList.toggle('open');
    });
    // Recent 折叠
    const sec = host.querySelector('.dt-sec');
    if (sec) sec.querySelector('.dt-sec-h').onclick = () => sec.classList.toggle('open');

    // 选中 + 打开：高亮当前行 + 发 nav intent 给海面（外壳通道若已加；无则仅高亮）
    host.querySelectorAll('.dt-row').forEach(r => r.onclick = e => {
      if (e.target.closest('.dt-act') || e.target.closest('.dt-chev')) return;
      host.querySelectorAll('.dt-row').forEach(x => x.classList.remove('on')); r.classList.add('on');
      if (window.Shell && Shell.openDocument) Shell.openDocument(r.dataset.id);
    });
    // ＋/⋯ hover 占位入口（菜单/拖拽下一轮）：吃掉点击、不误触选中
    host.querySelectorAll('.dt-act').forEach(b => b.onclick = e => e.stopPropagation());

    // 排序/展示菜单（sliders）：排序就地重排(菜单留开)，Show recent 即时显隐
    const disp = host.querySelector('.dt-disp'), menu = host.querySelector('.dt-disp-menu');
    disp.onclick = e => { e.stopPropagation(); const open = menu.classList.toggle('open'); disp.classList.toggle('on', open); };
    menu.addEventListener('click', e => e.stopPropagation());
    menu.querySelectorAll('[data-sort]').forEach(o => o.onclick = () => {
      menu.querySelectorAll('[data-sort]').forEach(x => x.classList.remove('on')); o.classList.add('on');
      sort = o.dataset.sort; applySort(host, sort);
    });
    menu.querySelector('[data-show="recent"]').onclick = function () {
      showRecent = !showRecent; this.classList.toggle('on', showRecent);
      if (sec) sec.style.display = showRecent ? '' : 'none';
    };

    // 名字过滤：命中 + 祖先链可见 + 命中分支自动展开；Recent 同步过滤
    const fin = host.querySelector('.dt-filter input');
    fin.oninput = () => {
      const q = fin.value.trim().toLowerCase();
      const walk = nd => {
        const nm = nd.querySelector(':scope > .dt-row .dt-name').textContent.toLowerCase();
        let hit = !q || nm.includes(q);
        nd.querySelectorAll(':scope > .dt-children > .dt-node').forEach(ch => { if (walk(ch)) hit = true; });
        nd.style.display = hit ? '' : 'none';
        if (q && hit && nd.classList.contains('branch')) nd.classList.add('open');
        return hit;
      };
      [...tree.children].forEach(walk);
      host.querySelectorAll('.dt-sec .dt-rrow').forEach(r => {
        r.style.display = (!q || r.querySelector('.dt-name').textContent.toLowerCase().includes(q)) ? '' : 'none';
      });
    };

    if (sort !== 'manual') applySort(host, sort);   // 复位时应用当前排序
  }

  // 点菜单外收起排序菜单（一次性）
  document.addEventListener('click', () => {
    const m = document.querySelector('#sidebody .dt-disp-menu.open');
    if (m) { m.classList.remove('open'); document.querySelector('#sidebody .dt-disp')?.classList.remove('on'); }
  });

  SideBar.register('documents', render);
})();
