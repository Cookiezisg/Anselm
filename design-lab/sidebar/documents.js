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

  // 示意树（接后端 = GET /documents/tree 的 metadata；整树一趟拉、折叠纯前端）。每个节点都是一篇 markdown 文档，有 children 即可当"文件夹"。
  const TREE = [
    { id: 'd1', name: 'Product', children: [
      { id: 'd2', name: 'Frontend', children: [
        { id: 'd3', name: '文档页设计', on: true },
        { id: 'd4', name: 'Roadmap 2026' },
      ] },
      { id: 'd5', name: '竞品列表' },
    ] },
    { id: 'd6', name: 'Engineering', children: [
      { id: 'd7', name: 'Backend 重构记录' },
      { id: 'd8', name: 'API 契约' },
    ] },
    { id: 'd9', name: '随手记' },
  ];
  const RECENT = [{ id: 'd3', name: '文档页设计' }, { id: 'd8', name: 'API 契约' }, { id: 'd4', name: 'Roadmap 2026' }];

  // 树节点（递归）：缩进按 depth；有子=分支(.branch,带 chevron,默认展开)；行尾 hover 露出 ＋(建子页)/⋯(更多)
  const node = (n, depth) => {
    const kids = n.children && n.children.length;
    return `<div class="dt-node${kids ? ' branch open' : ''}">
      <div class="dt-row${n.on ? ' on' : ''}" data-id="${n.id}" style="padding-left:${8 + depth * 15}px">
        <span class="dt-chev">${kids ? icon('chevr', 13) : ''}</span>
        <span class="dt-ico">${icon('doc', 15)}</span>
        <span class="dt-name">${n.name}</span>
        <button class="dt-act dt-add" title="New sub-page">${icon('plus', 15)}</button>
        <button class="dt-act dt-more" title="More">${icon('more', 15)}</button>
      </div>
      ${kids ? `<div class="dt-children">${n.children.map(c => node(c, depth + 1)).join('')}</div>` : ''}
    </div>`;
  };
  const recentRow = r => `<div class="dt-row dt-rrow" data-id="${r.id}"><span class="dt-ico">${icon('doc', 15)}</span><span class="dt-name">${r.name}</span></div>`;

  function build() {
    if (!TREE.length) return `
      <button class="dt-new">${icon('plus', 18)}<span>New document</span></button>
      <div class="dt-empty">${icon('doc', 30)}<p>No documents yet</p></div>`;
    return `
      <button class="dt-new">${icon('plus', 18)}<span>New document</span></button>
      <div class="dt-filter">${icon('search', 16)}<input type="text" placeholder="Filter by name…"></div>
      <div class="dt-list">
        <div class="dt-sec open">
          <button class="dt-sec-h"><span class="dt-sec-t">Recent</span><span class="dt-chev">${icon('chevr', 13)}</span></button>
          <div class="dt-sec-body">${RECENT.map(recentRow).join('')}</div>
        </div>
        <div class="dt-tree">${TREE.map(n => node(n, 0)).join('')}</div>
      </div>`;
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

    // 选中 + 打开：高亮当前行 + 发 nav intent 给海面（外壳通道若已加；design-lab 无则仅高亮）
    host.querySelectorAll('.dt-row').forEach(r => r.onclick = e => {
      if (e.target.closest('.dt-act') || e.target.closest('.dt-chev')) return;
      host.querySelectorAll('.dt-row').forEach(x => x.classList.remove('on')); r.classList.add('on');
      if (window.Shell && Shell.openDocument) Shell.openDocument(r.dataset.id);
    });
    // ＋/⋯ 仅作 hover 露出的占位入口（菜单/拖拽下一轮）：吃掉点击、不误触选中
    host.querySelectorAll('.dt-act').forEach(b => b.onclick = e => e.stopPropagation());

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
  }

  SideBar.register('documents', render);
})();
