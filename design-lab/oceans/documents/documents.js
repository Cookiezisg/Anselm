/* Forgify design-lab — Documents 海洋编排（单独，一人负责整个 oceans/documents/ 文件夹）。
   本页 = 全 markdown 格式样张（可上下滑）+ 两套「零 markdown 心智」编辑操作：
     ① 斜杠菜单 /：敲 / 弹窗，所有「插入」（标题/列表/待办/引用/代码/表格/图片/分隔线/提示块 + [[文档]]/@提及/✦AI）收进一个窗，打字过滤、↑↓回车或点选插入——非 markdown 用户的唯一入口。
     ② 选中工具条：选文字→上方浮条，点选加粗/斜体/删除线/高亮/行内代码/链接（真改，不用记符号）+ ✦AI（改写/续写/精简/翻译）。
   markdown 快捷键（## / - / >）作为「奖励」仍可保留，不在此 mockup 强求。
   内容区放宽外壳禁横线（见 documents.css 注）。依赖：shared/icons.js · shared/shell.js · ./right-island.js。 */
(function () {
  const $ = (s, r = document) => r.querySelector(s);
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  let runId = 0;
  const alive = id => id === runId;

  function typeInto(node, text, cps = 56) {
    const id = runId;
    return new Promise(res => {
      const caret = document.createElement('span'); caret.className = 'caret'; node.appendChild(caret);
      let i = 0;
      (function step() {
        if (!alive(id)) { caret.remove(); return res(); }
        caret.insertAdjacentText('beforebegin', text[i++] ?? '');
        if (i > text.length) { caret.remove(); return res(); }
        setTimeout(step, 1000 / cps + Math.random() * 16);
      })();
    });
  }

  const BODY_HTML = `
    <p>这是 Forgify 文档海洋的 <b>markdown 排版样张</b>。文档内容区<b>放宽</b>了外壳的「禁横线」规则——可以有 <a href="#">下划线链接</a>、分隔线、表格细线，大范围参考 Notion；但正文里 <b>不用灰色填充块</b>（代码、引用都是白底描边），行内代码也 <b>不学 Notion 的红色</b>。</p>
    <p><b>不会 markdown？</b>在空行敲 <code>/</code> 唤出命令窗挑要插入的块；选中文字会浮出工具条点选格式——都不用记符号。</p>

    <h2>标题层级</h2>
    <p>靠尺寸阶梯区分（24 / 19 / 15），不靠编号或下划线。</p>
    <h3>这是一个三级标题</h3>
    <p>正文紧随其后，靠留白分节。</p>

    <h2>文字样式</h2>
    <p>支持 <b>粗体</b>、<em>斜体</em>、<del>删除线</del>、<mark>高亮</mark>、<code>行内代码</code>，以及 <a href="#">带下划线的链接</a>。行内代码是白底 + 细描边的等宽字，<b>没有</b>那种刺眼的红。</p>

    <h2>列表</h2>
    <ul>
      <li>无序列表用小圆点</li>
      <li>支持嵌套
        <ul><li>第二层换成空心环</li><li>靠缩进，不画连接线</li></ul>
      </li>
      <li>项与项之间留白呼吸</li>
    </ul>
    <ol>
      <li>有序列表用等宽数字</li>
      <li>序号即层级线索</li>
    </ol>

    <h2>任务清单</h2>
    <ul class="doc-tasks">
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">完成框是中性的近黑实底 + 白勾</span></li>
      <li><span class="box"></span><span class="t">未完成只是一个细描边空框</span></li>
    </ul>

    <h2>引用</h2>
    <blockquote>引用用左侧一道细竖线 + 文字降一档灰，白底无填充。学 Notion 的经典引用，但去掉了灰块。</blockquote>

    <h2>提示块</h2>
    <div class="doc-callout"><span class="ico">${icon('spark', 16, 1.6)}</span><div class="c"><b>这是一个 Callout。</b>白底 + 一圈描边 + 左侧图标，强调一段话而不靠底色块。</div></div>

    <h2>代码</h2>
    <p>行内是 <code>const x = 1</code>；多行是代码块——白底、外面一个圈、等宽字、右上角标语言：</p>
    <div class="doc-code"><span class="lang">ts</span><pre>// 文档正文 = 单块 markdown 字符串
function render(md: string): Html {
  return parse(md);   // 整篇覆盖、无版本 diff
}</pre></div>

    <h2>表格</h2>
    <table class="doc-table">
      <thead><tr><th>构件</th><th>样式</th><th>说明</th></tr></thead>
      <tbody>
        <tr><td>引用</td><td>左竖线 + 灰字</td><td>白底无填充</td></tr>
        <tr><td>代码</td><td>白底 + 描边 + 等宽</td><td>不红</td></tr>
      </tbody>
    </table>

    <h2>链接与提及</h2>
    <p>文档间用 <span class="doc-pill"><span class="ico">${icon('link', 13)}</span>另一篇文档</span> 这样的 wikilink；提到实体用 <span class="doc-pill"><span class="ico">${icon('at', 13)}</span>某个 Agent</span>。都是「图标 + 下划线文字」，不是灰药丸。</p>

    <h2>分隔线</h2>
    <p>分隔线就是一条细线：</p>
    <hr>
    <p>用来分隔大段落。</p>`;

  // 斜杠菜单块清单（接后端时这套就是「插入」能力表）
  const BLOCKS = [
    { grp: '基础' },
    { k: 'text', ic: 'text', nm: '文本', hint: '', html: '<p>新段落</p>' },
    { k: 'h2', ic: 'heading', nm: '标题 1', hint: '#', html: '<h2>新标题</h2>' },
    { k: 'h3', ic: 'heading', nm: '标题 2', hint: '##', html: '<h3>新小标题</h3>' },
    { k: 'todo', ic: 'check', nm: '待办清单', hint: '[ ]', html: '<ul class="doc-tasks"><li><span class="box"></span><span class="t">待办项</span></li></ul>' },
    { k: 'ul', ic: 'list', nm: '无序列表', hint: '-', html: '<ul><li>列表项</li></ul>' },
    { k: 'ol', ic: 'listol', nm: '有序列表', hint: '1.', html: '<ol><li>列表项</li></ol>' },
    { k: 'quote', ic: 'quote', nm: '引用', hint: '>', html: '<blockquote>引用内容</blockquote>' },
    { k: 'code', ic: 'code', nm: '代码块', hint: '```', html: '<div class="doc-code"><span class="lang">代码</span><pre>// 在此写代码</pre></div>' },
    { k: 'table', ic: 'table', nm: '表格', hint: '', html: '<table class="doc-table"><thead><tr><th>列 1</th><th>列 2</th></tr></thead><tbody><tr><td>—</td><td>—</td></tr><tr><td>—</td><td>—</td></tr></tbody></table>' },
    { k: 'callout', ic: 'spark', nm: '提示块', hint: '', html: '<div class="doc-callout"><span class="ico">' + icon('spark', 16, 1.6) + '</span><div class="c">提示内容</div></div>' },
    { k: 'hr', ic: 'divider', nm: '分隔线', hint: '---', html: '<hr>' },
    { k: 'img', ic: 'image', nm: '图片', hint: '', html: '<div class="doc-imgph">图片占位</div>' },
    { grp: '引用与 AI' },
    { k: 'wikilink', ic: 'link', nm: '链接到文档', hint: '[[', inline: '<span class="doc-pill"><span class="ico">' + icon('link', 13) + '</span>某篇文档</span>' },
    { k: 'mention', ic: 'at', nm: '提及实体', hint: '@', inline: '<span class="doc-pill"><span class="ico">' + icon('at', 13) + '</span>某个 Agent</span>' },
    { k: 'ai', ic: 'spark', nm: '让 AI 写…', hint: '', ai: true },
  ];

  Shell.registerOcean('documents', {
    crumb: '文档',
    build(sea) {
      sea.innerHTML = `
        <div class="doc-scroll scroll-fade" id="docScroll">
          <article class="doc" id="doc">
            <div class="doc-path" id="docPath"></div>
            <h1 class="doc-title" id="docTitle" contenteditable="true" spellcheck="false"></h1>
            <div class="doc-meta" id="docMeta"></div>
            <div class="doc-body" id="docBody" contenteditable="true" spellcheck="false"></div>
          </article>
        </div>`;
      Shell.headExtra(`
        <span class="doc-status" id="docStatus"></span>
        <button class="ibtn" id="i_panel" title="大纲 / 反链 / 元信息">${icon('panel')}</button>
        <button class="ibtn" id="i_replay" title="重置样张">${icon('play', 16)}</button>`);
      $('#i_panel').onclick = () => DocAside.toggle();
      $('#i_replay').onclick = render;
      DocAside.ensure();
      render();
      wireSelectionToolbar();
      wireSlashMenu();
    },
  });

  function setStatus(mode) {
    const el = $('#docStatus'); if (!el) return;
    if (mode === 'ai') { el.className = 'doc-status live'; el.innerHTML = `<span class="pulse"></span>AI 编辑中`; }
    else { el.className = 'doc-status'; el.innerHTML = `<span class="ico">${icon('check', 14)}</span>已保存`; }
  }

  function renderHead() {
    $('#docPath').innerHTML = `
      <span class="ico">${icon('folder', 13)}</span>
      <button class="doc-pathseg">产品</button><span class="sep">/</span>
      <button class="doc-pathseg">前端</button><span class="sep">/</span>
      <span class="cur">Markdown 排版总览</span>`;
    $('#docTitle').textContent = 'Markdown 排版总览';
    $('#docMeta').innerHTML = `
      <span>更新于 2 小时前</span><span class="dot-sep">·</span>
      <span>全部格式样张</span><span class="dot-sep">·</span>
      <button class="doc-backref" id="docBackref">3 个反链</button>
      <span class="doc-tags">
        <span class="doc-tag"><span class="ico">${icon('tag', 11)}</span>design</span>
        <span class="doc-tag"><span class="ico">${icon('tag', 11)}</span>markdown</span>
      </span>`;
    $('#docBackref').onclick = () => DocAside.show();
  }

  function bindPills() {
    $('#docBody').querySelectorAll('.doc-pill').forEach(p => p.onclick = e => { e.preventDefault(); DocAside.show(); });
  }

  function render() {
    runId++;
    const body = $('#docBody'); if (!body) return;
    closeSlash(); hideToolbar();
    renderHead();
    body.innerHTML = BODY_HTML;
    body.classList.remove('fadein'); void body.offsetWidth; body.classList.add('fadein');
    bindPills();
    setStatus('saved');
    DocAside.render();
    $('#docScroll').scrollTop = 0;
  }

  const docBody = () => $('#docBody');
  const doc = () => $('#doc');
  function caretRect() { const s = window.getSelection(); if (!s.rangeCount) return null; const r = s.getRangeAt(0).getBoundingClientRect(); return r.width || r.height ? r : null; }
  function placeAbove(el, rect) {                                     // 把浮层放选区/光标上方，限制在 .doc 内
    const dr = doc().getBoundingClientRect();
    el.style.left = Math.min(Math.max(8, rect.left - dr.left), doc().clientWidth - el.offsetWidth - 8) + 'px';
    el.style.top = (rect.top - dr.top - el.offsetHeight - 8) + 'px';
  }
  function placeBelow(el, rect) {
    const dr = doc().getBoundingClientRect();
    el.style.left = Math.min(Math.max(8, rect.left - dr.left), doc().clientWidth - el.offsetWidth - 8) + 'px';
    el.style.top = (rect.bottom - dr.top + 6) + 'px';
  }

  /* ===== ① 选中工具条：点选格式化 + AI ===== */
  let bar = null;
  function hideToolbar() { if (bar) { bar.remove(); bar = null; } }
  function wireSelectionToolbar() {
    const b = docBody();
    b.addEventListener('mousedown', hideToolbar);
    b.addEventListener('mouseup', () => setTimeout(() => {
      if (slashOpen()) return;
      const s = window.getSelection();
      if (!s || s.isCollapsed || s.rangeCount === 0 || !b.contains(s.anchorNode)) return;
      const rect = s.getRangeAt(0).getBoundingClientRect();
      if (rect.width < 2) return;
      showToolbar(rect, s.getRangeAt(0).cloneRange());
    }, 0));
  }
  const FMT = [
    { a: 'bold', h: '<b>B</b>', t: '加粗' }, { a: 'italic', h: '<i>I</i>', t: '斜体' }, { a: 'strike', h: '<s>S</s>', t: '删除线' },
    { a: 'mark', h: '<span class="hl">高</span>', t: '高亮' }, { a: 'code', h: icon('code', 14), t: '行内代码' }, { a: 'link', h: icon('link', 14), t: '链接' },
  ];
  function showToolbar(rect, range) {
    hideToolbar();
    bar = document.createElement('div'); bar.className = 'ai-bar';
    bar.innerHTML = `<button class="sb ai" data-a="ai"><span class="ico">${icon('spark', 14, 1.7)}</span>AI</button><span class="sb-div"></span>` +
      FMT.map(f => `<button class="sb" data-a="${f.a}" title="${f.t}">${f.h}</button>`).join('');
    doc().appendChild(bar);
    placeAbove(bar, rect);
    bar.querySelectorAll('button').forEach(btn => btn.addEventListener('mousedown', e => {
      e.preventDefault();
      if (btn.dataset.a === 'ai') return showAiActions(rect, range);
      applyFormat(btn.dataset.a, range);
    }));
  }
  function reselect(range) { const s = window.getSelection(); s.removeAllRanges(); s.addRange(range); }
  function wrap(range, tag, cls) { try { const el = document.createElement(tag); if (cls) el.className = cls; range.surroundContents(el); } catch (e) {} }
  function applyFormat(a, range) {
    reselect(range);
    if (a === 'bold' || a === 'italic') document.execCommand(a);
    else if (a === 'strike') document.execCommand('strikethrough');
    else if (a === 'mark') wrap(range, 'mark');
    else if (a === 'code') wrap(range, 'code');
    else if (a === 'link') { const el = document.createElement('a'); el.href = '#'; try { range.surroundContents(el); } catch (e) {} }
    hideToolbar();
  }
  // AI 子层：改写/续写/精简/翻译 → 选区流光扫过（演示流式改写视觉）
  function showAiActions(rect, range) {
    hideToolbar();
    bar = document.createElement('div'); bar.className = 'ai-bar';
    bar.innerHTML = `<span class="spark" style="display:grid;place-items:center;color:var(--accent);padding:0 4px 0 6px">${icon('spark', 15, 1.6)}</span>` +
      ['改写', '续写', '精简', '翻译'].map(t => `<button class="sb">${t}</button>`).join('');
    doc().appendChild(bar);
    placeAbove(bar, rect);
    bar.querySelectorAll('button').forEach(btn => btn.addEventListener('mousedown', e => { e.preventDefault(); aiSweep(range); }));
  }
  async function aiSweep(range) {
    const id = ++runId;
    hideToolbar();
    setStatus('ai');
    let span = null;
    try { span = document.createElement('span'); span.className = 'ai-new run'; range.surroundContents(span); } catch (e) { span = null; }
    window.getSelection()?.removeAllRanges();
    await sleep(1500); if (!alive(id)) { if (span) unwrap(span); return; }
    if (span) unwrap(span);
    setStatus('saved');
  }
  function unwrap(span) {
    span.classList.remove('run');
    const p = span.parentNode; if (!p) return;
    while (span.firstChild) p.insertBefore(span.firstChild, span);
    p.removeChild(span); p.normalize && p.normalize();
  }

  /* ===== ② 斜杠菜单 / 命令窗 ===== */
  let menu = null, slash = null, onIdx = 0, flat = [];
  const slashOpen = () => !!menu;
  function wireSlashMenu() {
    const b = docBody();
    b.addEventListener('input', onInput);
    b.addEventListener('keydown', onKey, true);
    document.addEventListener('mousedown', e => { if (menu && !menu.contains(e.target)) closeSlash(); });
  }
  function onInput() {
    const s = window.getSelection();
    if (!s.rangeCount) return closeSlash();
    const r = s.getRangeAt(0);
    if (r.startContainer.nodeType !== 3) return closeSlash();
    const node = r.startContainer;
    const before = node.textContent.slice(0, r.startOffset);
    const m = before.match(/(?:^|\s)\/([^\s/]*)$/);
    if (!m) return closeSlash();
    slash = { node, start: r.startOffset - m[1].length - 1, end: r.startOffset, query: m[1] };
    openSlash();
  }
  function matched() {
    const q = (slash?.query || '').toLowerCase();
    const out = []; let lastGrp = null;
    BLOCKS.forEach(it => {
      if (it.grp) { lastGrp = it; return; }
      const hit = !q || it.nm.toLowerCase().includes(q) || it.k.includes(q) || (it.hint || '').includes(q);
      if (hit) { if (lastGrp) { out.push(lastGrp); lastGrp = null; } out.push(it); }
    });
    return out;
  }
  function openSlash() {
    const list = matched();
    flat = list.filter(x => !x.grp);
    if (!menu) { menu = document.createElement('div'); menu.className = 'slash-menu'; doc().appendChild(menu); onIdx = 0; }
    if (onIdx >= flat.length) onIdx = 0;
    menu.innerHTML = flat.length ? list.map(it => it.grp
      ? `<div class="slash-group">${it.grp}</div>`
      : `<div class="slash-item${flat[onIdx] === it ? ' on' : ''}" data-k="${it.k}">
           <span class="si-ic">${icon(it.ic, 16)}</span><span class="si-nm">${it.nm}</span>${it.hint ? `<span class="si-hint">${it.hint}</span>` : ''}
         </div>`).join('')
      : `<div class="slash-empty">没有匹配「${slash.query}」的块</div>`;
    menu.querySelectorAll('.slash-item').forEach(el => {
      el.addEventListener('mousedown', e => { e.preventDefault(); choose(flat.find(x => x.k === el.dataset.k)); });
      el.addEventListener('mousemove', () => { onIdx = flat.findIndex(x => x.k === el.dataset.k); paintOn(); });
    });
    const rect = caretRect(); if (rect) placeBelow(menu, rect);
  }
  function paintOn() {
    menu.querySelectorAll('.slash-item').forEach((el, i) => el.classList.toggle('on', flat[onIdx] && el.dataset.k === flat[onIdx].k));
  }
  function onKey(e) {
    if (!menu) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); onIdx = (onIdx + 1) % flat.length; paintOn(); ensureVisible(); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); onIdx = (onIdx - 1 + flat.length) % flat.length; paintOn(); ensureVisible(); }
    else if (e.key === 'Enter') { e.preventDefault(); choose(flat[onIdx]); }
    else if (e.key === 'Escape') { e.preventDefault(); closeSlash(); }
  }
  function ensureVisible() { const on = menu.querySelector('.slash-item.on'); on && on.scrollIntoView({ block: 'nearest' }); }
  function closeSlash() { if (menu) { menu.remove(); menu = null; } slash = null; }
  function choose(block) {
    if (!block || !slash) return closeSlash();
    const { node, start, end } = slash;
    try { node.textContent = node.textContent.slice(0, start) + node.textContent.slice(end); } catch (e) {}
    closeSlash();
    // 宿主块 = node 在 #docBody 下的直接子元素
    let host = node;
    while (host && host.parentNode && host.parentNode !== docBody()) host = host.parentNode;
    if (!host || host.parentNode !== docBody()) host = docBody().lastElementChild;
    if (block.inline) {                                              // 行内：wikilink / @提及
      host.insertAdjacentHTML('beforeend', ' ' + block.inline);
      bindPills();
    } else if (block.ai) {                                           // ✦ AI 写：在宿主块后插一段、流光打字
      host.insertAdjacentHTML('afterend', '<p class="ai-host"></p>');
      const p = host.nextElementSibling;
      aiWrite(p);
    } else {                                                         // 块：插到宿主块之后；宿主空则替换
      host.insertAdjacentHTML('afterend', block.html);
      const fresh = host.nextElementSibling;
      if (host.textContent.trim() === '' && host.tagName === 'P') host.remove();
      bindPills();
      fresh && fresh.scrollIntoView({ block: 'nearest' });
    }
  }
  async function aiWrite(p) {
    if (!p) return;
    const id = ++runId; setStatus('ai');
    const span = document.createElement('span'); span.className = 'ai-new run'; p.appendChild(span);
    p.scrollIntoView({ block: 'nearest' });
    await typeInto(span, 'AI 根据上下文续写的一段内容，落定后从流光沉淀为正文。'); if (!alive(id)) return;
    await sleep(200); if (!alive(id)) return;
    unwrap(span); setStatus('saved');
  }
})();
