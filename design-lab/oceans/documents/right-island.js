/* Foryx design-lab — 文档海洋 · 右岛（元信息抽屉；重写 v2）。
   右岛是「本海洋的」：自己 append 到 Shell.body（作第三个 flex 子），自管显隐。默认收起、点主区头面板钮滑入。
   装「真实存在、却不该塞进单块 markdown 正文」的元数据：大纲 TOC / 反向链接 / path·tags·更新·大小。
   分区(.da-sec)/行(.da-toc a) 风格对齐侧栏会话史；接后端时换真数据，形态不变。
   依赖：shared/icons.js（icon）+ shared/shell.js（Shell.body）。样式在同目录 documents.css。 */
window.DocAside = (function () {
  const $ = (s, r) => r.querySelector(s);
  let el = null;

  // 反链 = relation 入边的消费视图（wikilink 单向出边的反查、非本表字段）
  const BACK = [
    ['上手指南', '… 排版遵循 [[文档页设计]] 的海岸线一节 …'],
    ['组件规格速查', '… 药丸样式对齐 [[文档页设计]] …'],
    ['Onboarding 文案', '… 风格沿用 [[文档页设计]] …'],
  ];

  function ensure() {
    if (el && document.body.contains(el)) return el;
    el = document.createElement('aside');
    el.className = 'doc-aside';
    el.setAttribute('data-ocean-right', 'documents');   // 外壳切海洋时据此清理
    el.innerHTML = `<div class="body">
      <div class="da-sec"><div class="da-h">大纲</div><div class="da-toc" data-toc></div></div>
      <div class="da-sec"><div class="da-h">反向链接</div><div class="da-back" data-back></div></div>
      <div class="da-sec"><div class="da-h">信息</div><div class="da-meta" data-meta></div></div>
    </div>`;
    Shell.body.appendChild(el);
    render();
    return el;
  }

  // 大纲从正文 H2/H3 实时抽（scroll-spy 示意，当前节中性灰底高亮、非 accent）
  function render() {
    if (!el) return;
    const heads = [...document.querySelectorAll('#docBody h2, #docBody h3')];
    $('[data-toc]', el).innerHTML = heads.length
      ? heads.map((h, i) => `<a class="${h.tagName === 'H3' ? 'h3' : ''}${i === 0 ? ' on' : ''}" data-h="${i}">${h.textContent}</a>`).join('')
      : `<a style="color:var(--ink-3)">（暂无小节）</a>`;
    $('[data-toc]', el).querySelectorAll('a[data-h]').forEach(a => a.onclick = e => {
      e.preventDefault();
      el.querySelectorAll('[data-toc] a').forEach(x => x.classList.remove('on'));
      a.classList.add('on');
      heads[+a.dataset.h]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
    $('[data-back]', el).innerHTML = BACK.map(([nm, snip]) =>
      `<a href="#" onclick="return false"><span class="doc-pill"><span class="ico">${icon('doc', 13)}</span>${nm}</span><span class="snip">${snip}</span></a>`).join('');
    $('[data-meta]', el).innerHTML = `
      <div class="row"><span class="k">路径</span><span class="v mono">/产品/前端/文档页设计</span></div>
      <div class="row"><span class="k">标签</span><span class="v">design · markdown</span></div>
      <div class="row"><span class="k">更新</span><span class="v">2 小时前</span></div>
      <div class="row"><span class="k">大小</span><span class="v">3.2 KB / 1 MB</span></div>`;
  }

  return {
    ensure, render,
    get el() { return el; },
    show() { ensure(); render(); el.classList.add('show'); },
    hide() { if (el) el.classList.remove('show'); },
    toggle() { ensure(); if (el.classList.contains('show')) el.classList.remove('show'); else { render(); el.classList.add('show'); } },
  };
})();
