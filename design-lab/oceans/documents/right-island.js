/* Forgify design-lab — Documents 海洋 · 右岛（元信息抽屉）。右岛属于海洋：框 + 内容都在这。
   装「真实存在、却不该塞进单块 markdown 正文」的元数据：大纲 TOC / 反向链接 / path·tags·更新·大小。
   默认收起、可一键滑入（守极简、给长文导航留后路）。自建 <aside data-ocean-right="documents"> append 到 Shell.body，
   切海洋时由外壳据 data-ocean-right 清理。依赖：shared/icons.js（icon）。接后端时换真数据，形态不变。 */
window.DocAside = (function () {
  let el = null;

  function ensure() {
    if (el && document.body.contains(el)) return el;
    el = document.createElement('aside');
    el.className = 'doc-aside';
    el.dataset.oceanRight = 'documents';
    el.innerHTML = `
      <div class="doc-aside-body">
        <div class="da-sect"><div class="da-h">大纲</div><div class="da-toc" id="daToc"></div></div>
        <div class="da-sect"><div class="da-h">反向链接</div><div class="da-back" id="daBack"></div></div>
        <div class="da-sect"><div class="da-h">信息</div><div class="da-meta" id="daMeta"></div></div>
      </div>`;
    Shell.body.appendChild(el);
    render();
    return el;
  }

  // 大纲从当前正文 H2/H3 实时抽（scroll-spy 示意，当前节中性灰底高亮，非 accent）
  function render() {
    if (!el) return;
    const heads = [...document.querySelectorAll('#docBody h2, #docBody h3')].filter(h => !h.classList.contains('doc-morph'));
    const toc = el.querySelector('#daToc');
    toc.innerHTML = heads.length
      ? heads.map((h, i) => `<a class="${h.tagName === 'H3' ? 'h3' : ''}${i === 0 ? ' on' : ''}" data-h="${i}">${h.textContent}</a>`).join('')
      : `<a style="color:var(--ink-3)">（暂无小节）</a>`;
    toc.querySelectorAll('a[data-h]').forEach(a => a.onclick = e => {
      e.preventDefault();
      toc.querySelectorAll('a').forEach(x => x.classList.remove('on'));
      a.classList.add('on');
      heads[+a.dataset.h]?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });

    // 反链 = relation 入边的消费视图（非 documents 表字段；wikilink 单向出边的反查）
    const BACK = [
      ['上手指南', '… 排版遵循 [[文档页设计规范]] 的海岸线一节 …'],
      ['组件规格速查', '… 药丸样式对齐 [[文档页设计规范]] …'],
      ['Onboarding 文案', '… 风格沿用 [[文档页设计规范]] …'],
    ];
    el.querySelector('#daBack').innerHTML = BACK.map(([n, s]) =>
      `<a class="da-backitem" href="#" onclick="return false">
        <span class="doc-pill"><span class="ico">${icon('doc', 12)}</span>${n}</span>
        <span class="snip">${s}</span>
      </a>`).join('');

    // 元信息：size 用纯文字暗示上限（不画贯穿细横条——那观感仍是横线，违禁线铁律）
    el.querySelector('#daMeta').innerHTML = `
      <div class="da-row"><span class="k">路径</span><span class="v mono">/产品/前端/文档页设计规范</span></div>
      <div class="da-row"><span class="k">标签</span><span class="v">design · frontend</span></div>
      <div class="da-row"><span class="k">更新</span><span class="v">2 小时前</span></div>
      <div class="da-row"><span class="k">大小</span><span class="v">3.2 KB / 1 MB</span></div>`;
  }

  return {
    ensure, render,
    get el() { return el; },
    show() { ensure(); render(); el.classList.add('show'); },
    hide() { if (el) el.classList.remove('show'); },
    toggle() {
      ensure();
      if (el.classList.contains('show')) el.classList.remove('show');
      else { render(); el.classList.add('show'); }
    },
  };
})();
