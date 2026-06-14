/* Forgify design-lab — Documents 海洋编排（单独，一人负责整个 oceans/documents/ 文件夹）。
   本页 = 全 markdown 格式样张（可上下滑）+ 零-markdown 心智编辑：
     · 斜杠菜单 /：敲 / 弹命令窗，所有「插入」收进一窗，打字过滤、↑↓回车/点选插入（非 md 用户唯一入口）。
     · 选中即浮工具条：点选 加粗/斜体/删除线/高亮/行内代码/链接（execCommand 真改）+ ✦AI（给一句指令→流式改写）。
     · 块左侧悬浮手柄：+ 在此后插入（开命令窗）· ⋮⋮ 拖拽重排 / 点开块菜单（转换/复制/删除）。
     · markdown 即输即渲：行首打 # / - / 1. / > / [] / --- + 空格，块 spring 变形（给会的人的「奖励」，不强求）。
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
    <p>这是 Forgify 文档海洋的 <b>markdown 排版样张</b>。文档内容区<b>放宽</b>了外壳的「禁横线」规则——可以有 <a href="#">下划线链接</a>、分隔线、表格细线，大范围参考 Notion；但正文里 <b>不用灰色填充块</b>，行内代码也 <b>不学 Notion 的红色</b>。</p>
    <p><b>不会 markdown？</b>空行敲 <code>/</code> 唤出命令窗挑块；选中文字浮出工具条点选格式；块左侧悬停有 <code>+</code> 和拖拽手柄——都不用记符号。</p>

    <h2>标题层级</h2>
    <p>靠尺寸阶梯区分（24 / 19 / 15），不靠编号或下划线。行首打 <code>## </code> 会即时变标题。</p>
    <h3>这是一个三级标题</h3>
    <p>正文紧随其后，靠留白分节。</p>

    <h2>文字样式</h2>
    <p>支持 <b>粗体</b>、<em>斜体</em>、<del>删除线</del>、<mark>高亮</mark>、<code>行内代码</code>，以及 <a href="#">带下划线的链接</a>。行内代码是白底 + 细描边的等宽字，<b>没有</b>那种刺眼的红。</p>

    <h2>列表</h2>
    <ul>
      <li>无序列表用小圆点</li>
      <li>支持嵌套
        <ul><li>第二层换成空心环</li></ul>
      </li>
    </ul>
    <ol>
      <li>有序列表用等宽数字</li>
      <li>序号即层级线索</li>
    </ol>

    <h2>任务清单</h2>
    <ul class="doc-tasks">
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">完成框是中性近黑实底 + 白勾</span></li>
      <li><span class="box"></span><span class="t">未完成只是一个细描边空框</span></li>
    </ul>

    <h2>引用</h2>
    <blockquote>引用用左侧一道细竖线 + 文字降一档灰，白底无填充。学 Notion 的经典引用，但去掉了灰块。</blockquote>

    <h2>代码</h2>
    <div class="doc-code"><span class="lang">ts</span><pre>// 文档正文 = 单块 markdown 字符串
function render(md: string): Html {
  return parse(md);   // 整篇覆盖、无版本 diff
}</pre></div>

    <h2>表格</h2>
    <table class="doc-table">
      <thead><tr><th>构件</th><th>样式</th></tr></thead>
      <tbody>
        <tr><td>引用</td><td>左竖线 + 灰字</td></tr>
        <tr><td>代码</td><td>白底 + 描边 + 等宽</td></tr>
      </tbody>
    </table>

    <h2>链接与提及</h2>
    <p>文档间用 <span class="doc-pill"><span class="ico">${icon('link', 13)}</span>另一篇文档</span> 这样的 wikilink；提到实体用 <span class="doc-pill"><span class="ico">${icon('at', 13)}</span>某个 Agent</span>。</p>

    <h2>分隔线</h2>
    <p>分隔线就是一条细线：</p>
    <hr>
    <p>用来分隔大段落。</p>`;

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
      wireGutter();
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
    closeSlash(); hideToolbar(); closeBlockMenu();
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
  function directBlock(node) {                                       // node 所在的 #docBody 直接子元素（= 一个「块」）
    if (!node) return null;
    let el = node.nodeType === 3 ? node.parentNode : node;
    while (el && el.parentNode && el.parentNode !== docBody()) el = el.parentNode;
    return el && el.parentNode === docBody() ? el : null;
  }
  function caretRect() { const s = window.getSelection(); if (!s.rangeCount) return null; const r = s.getRangeAt(0).getBoundingClientRect(); return (r.width || r.height) ? r : null; }
  function caretTo(el, end) { try { const r = document.createRange(); r.selectNodeContents(el); r.collapse(!end); const s = window.getSelection(); s.removeAllRanges(); s.addRange(r); } catch (e) {} }
  function placeAbove(el, rect) { const dr = doc().getBoundingClientRect(); el.style.left = Math.min(Math.max(8, rect.left - dr.left), doc().clientWidth - el.offsetWidth - 8) + 'px'; el.style.top = (rect.top - dr.top - el.offsetHeight - 8) + 'px'; }
  function placeBelow(el, rect) { const dr = doc().getBoundingClientRect(); el.style.left = Math.min(Math.max(8, rect.left - dr.left), doc().clientWidth - el.offsetWidth - 8) + 'px'; el.style.top = (rect.bottom - dr.top + 6) + 'px'; }

  /* ===== 选中工具条：点选格式化 + AI ===== */
  let bar = null, aiTarget = null, askOut = null;
  function hideToolbar() {
    if (askOut) { document.removeEventListener('mousedown', askOut); askOut = null; }
    if (bar) { bar.remove(); bar = null; }
    if (aiTarget) { unwrap(aiTarget); aiTarget = null; }   // 取消 AI：去掉持久高亮、复原文字
  }
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
      if (btn.dataset.a === 'ai') return showAiAsk(rect, range);
      applyFormat(btn.dataset.a, range);
    }));
  }
  function reselect(range) { const s = window.getSelection(); s.removeAllRanges(); s.addRange(range); }
  // 包住选区：surroundContents 跨内联边界(选区含/截断 <b><code> 等)会抛错 → extractContents 兜底，能包任意范围
  function wrapRange(range, tag, cls) {
    let el = document.createElement(tag); if (cls) el.className = cls;
    try { range.surroundContents(el); return el; }
    catch (e) {
      try { el = document.createElement(tag); if (cls) el.className = cls; el.appendChild(range.extractContents()); range.insertNode(el); return el; }
      catch (e2) { return null; }
    }
  }
  function applyFormat(a, range) {
    reselect(range);
    if (a === 'bold' || a === 'italic') document.execCommand(a);
    else if (a === 'strike') document.execCommand('strikethrough');
    else if (a === 'mark') wrapRange(range, 'mark');
    else if (a === 'code') wrapRange(range, 'code');
    else if (a === 'link') { const el = wrapRange(range, 'a'); if (el) el.href = '#'; }
    hideToolbar();
  }
  // AI 询问：给一句自然语言指令（对齐后端 :iterate）+ 快捷动作 → 选区流光改写
  function showAiAsk(rect, range) {
    hideToolbar();
    // 持久点亮选区：focus 移到输入框后原生 ::selection 会消失，用 .ai-target 一直点亮，用户看得见 AI 要改哪段
    aiTarget = wrapRange(range, 'span', 'ai-target');
    window.getSelection()?.removeAllRanges();
    bar = document.createElement('div'); bar.className = 'ai-ask';
    bar.innerHTML = `
      <div class="row"><span class="ico">${icon('spark', 16, 1.7)}</span><input id="aiAsk" placeholder="让 AI 改写选中内容…" autocomplete="off"></div>
      <div class="quick">${['改简洁', '续写', '翻译成英文', '更正式'].map(t => `<button>${t}</button>`).join('')}</div>`;
    doc().appendChild(bar);
    placeBelow(bar, (aiTarget || range).getBoundingClientRect());
    const input = bar.querySelector('#aiAsk');
    setTimeout(() => input.focus(), 0);
    input.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); runAi(); } else if (e.key === 'Escape') hideToolbar(); });
    bar.querySelectorAll('.quick button').forEach(b => b.addEventListener('mousedown', e => { e.preventDefault(); runAi(); }));
    askOut = e => { if (bar && !bar.contains(e.target)) hideToolbar(); };   // 点面板外即取消（复原高亮）
    setTimeout(() => document.addEventListener('mousedown', askOut), 0);
  }
  async function runAi() {
    const target = aiTarget; aiTarget = null;   // 交给流光，别在 hideToolbar 里被复原
    hideToolbar();
    if (!target) { setStatus('saved'); return; }
    const id = ++runId; setStatus('ai');
    target.classList.remove('ai-target'); target.classList.add('ai-new', 'run');   // 持久高亮 → 流光
    await sleep(1500); if (!alive(id)) { unwrap(target); return; }
    unwrap(target); setStatus('saved');
  }
  function unwrap(span) {
    span.classList.remove('run');
    const p = span.parentNode; if (!p) return;
    while (span.firstChild) p.insertBefore(span.firstChild, span);
    p.removeChild(span); p.normalize && p.normalize();
  }

  /* ===== 斜杠菜单 / 命令窗（敲 / · 块手柄 + · 块菜单转换 共用） ===== */
  let menu = null, slash = null, onIdx = 0, flat = [];
  const slashOpen = () => !!menu;
  function wireSlashMenu() {
    const b = docBody();
    b.addEventListener('input', onBodyInput);
    document.addEventListener('keydown', onSlashKey, true);
    document.addEventListener('mousedown', e => { if (menu && !menu.contains(e.target)) closeSlash(); });
  }
  function onBodyInput() { if (detectSlash()) return; closeSlash(); autoFormat(); }
  function detectSlash() {
    const s = window.getSelection(); if (!s.rangeCount) return false;
    const r = s.getRangeAt(0); if (r.startContainer.nodeType !== 3) return false;
    const node = r.startContainer; const before = node.textContent.slice(0, r.startOffset);
    const m = before.match(/(?:^|\s)\/([^\s/]*)$/); if (!m) return false;
    slash = { mode: 'type', node, start: r.startOffset - m[1].length - 1, end: r.startOffset, query: m[1] };
    openSlash(); return true;
  }
  function openSlashAfter(block) { slash = { mode: 'plus', host: block, query: '' }; openSlash(gutterAnchor()); }
  function openSlashTurn(block) { slash = { mode: 'turn', host: block, query: '' }; openSlash(gutterAnchor()); }
  function gutterAnchor() { return gutter && gutter.classList.contains('show') ? gutter.getBoundingClientRect() : (gutterBlock ? gutterBlock.getBoundingClientRect() : null); }
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
  function openSlash(anchorRect) {
    const list = matched();
    flat = list.filter(x => !x.grp);
    if (!menu) { menu = document.createElement('div'); menu.className = 'slash-menu'; doc().appendChild(menu); onIdx = 0; }
    if (onIdx >= flat.length) onIdx = 0;
    menu.innerHTML = flat.length ? list.map(it => it.grp
      ? `<div class="slash-group">${it.grp}</div>`
      : `<div class="slash-item${flat[onIdx] === it ? ' on' : ''}" data-k="${it.k}"><span class="si-ic">${icon(it.ic, 16)}</span><span class="si-nm">${it.nm}</span>${it.hint ? `<span class="si-hint">${it.hint}</span>` : ''}</div>`).join('')
      : `<div class="slash-empty">没有匹配「${slash.query}」的块</div>`;
    menu.querySelectorAll('.slash-item').forEach(el => {
      el.addEventListener('mousedown', e => { e.preventDefault(); choose(flat.find(x => x.k === el.dataset.k)); });
      el.addEventListener('mousemove', () => { const i = flat.findIndex(x => x.k === el.dataset.k); if (i !== onIdx) { onIdx = i; paintOn(); } });
    });
    const rect = anchorRect || caretRect(); if (rect) placeBelow(menu, rect);
  }
  function paintOn() { menu.querySelectorAll('.slash-item').forEach(el => el.classList.toggle('on', flat[onIdx] && el.dataset.k === flat[onIdx].k)); }
  function onSlashKey(e) {
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
    const mode = slash.mode;
    let host;
    if (mode === 'type') { const { node, start, end } = slash; try { node.textContent = node.textContent.slice(0, start) + node.textContent.slice(end); } catch (e) {} host = directBlock(node) || docBody().lastElementChild; }
    else host = slash.host;
    closeSlash();
    if (!host) return;
    if (block.inline) { host.insertAdjacentHTML('beforeend', ' ' + block.inline); bindPills(); }
    else if (block.ai) { host.insertAdjacentHTML('afterend', '<p class="ai-host"></p>'); aiWrite(host.nextElementSibling); }
    else if (mode === 'turn') { host.insertAdjacentHTML('beforebegin', block.html); const fresh = host.previousElementSibling; host.remove(); fresh && fresh.classList.add('blk-morph'); bindPills(); }
    else { host.insertAdjacentHTML('afterend', block.html); const fresh = host.nextElementSibling; if (mode === 'type' && host.tagName === 'P' && host.textContent.trim() === '') host.remove(); fresh && fresh.classList.add('blk-morph'); fresh && fresh.scrollIntoView({ block: 'nearest' }); bindPills(); }
    DocAside.render();
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

  /* ===== markdown 即输即渲（行首打 # / - / 1. / > / [] / --- + 空格 → 块 spring 变形） ===== */
  const MD = [
    { re: /^###\s/, tag: 'h3' }, { re: /^##\s/, tag: 'h3' }, { re: /^#\s/, tag: 'h2' },
    { re: /^[-*]\s/, kind: 'ul' }, { re: /^\d+\.\s/, kind: 'ol' },
    { re: /^>\s/, tag: 'blockquote' }, { re: /^\[[ xX]?\]\s/, kind: 'todo' }, { re: /^---$/, kind: 'hr' },
  ];
  function autoFormat() {
    const s = window.getSelection(); if (!s.rangeCount) return;
    const blk = directBlock(s.anchorNode); if (!blk || blk.tagName !== 'P') return;
    const text = blk.textContent;
    const rule = MD.find(r => r.re.test(text)); if (!rule) return;
    const rest = text.replace(rule.re, '');
    let neo, tgt;
    if (rule.tag) { neo = document.createElement(rule.tag); neo.textContent = rest; tgt = neo; }
    else if (rule.kind === 'ul' || rule.kind === 'ol') { neo = document.createElement(rule.kind); const li = document.createElement('li'); li.textContent = rest; neo.appendChild(li); tgt = li; }
    else if (rule.kind === 'todo') { neo = document.createElement('ul'); neo.className = 'doc-tasks'; neo.innerHTML = `<li><span class="box"></span><span class="t">${rest || ''}</span></li>`; tgt = neo.querySelector('.t'); }
    else if (rule.kind === 'hr') { neo = document.createElement('hr'); }
    if (!neo) return;
    blk.replaceWith(neo);
    if (neo.classList) neo.classList.add('blk-morph');
    if (rule.kind === 'hr') { const p = document.createElement('p'); p.innerHTML = '<br>'; neo.after(p); caretTo(p, false); }
    else if (tgt) caretTo(tgt, true);
    DocAside.render();
  }

  /* ===== 块左侧悬浮手柄：+ 插入 · ⋮⋮ 拖拽重排 / 点开菜单 ===== */
  let gutter = null, gutterBlock = null, dragging = false, dragBlock = null, dropBefore = null, dropEl = null, justDragged = false;
  function wireGutter() {
    gutter = document.createElement('div'); gutter.className = 'blk-gutter';
    gutter.innerHTML = `<button class="bg-add" title="在此后插入">${icon('plus', 16)}</button><button class="bg-handle" title="拖动重排 · 点击菜单">${icon('grip', 16)}</button>`;
    doc().appendChild(gutter);
    docBody().addEventListener('mousemove', e => { if (dragging) return; const b = directBlock(e.target); if (b) showGutterFor(b); });
    docBody().addEventListener('mouseleave', () => { if (!dragging && !blkMenuOpen()) hideGutter(); });
    gutter.addEventListener('mouseenter', () => gutter.classList.add('show'));
    gutter.addEventListener('mouseleave', () => { if (!dragging && !blkMenuOpen()) hideGutter(); });
    gutter.querySelector('.bg-add').addEventListener('click', () => { if (gutterBlock) openSlashAfter(gutterBlock); });
    const handle = gutter.querySelector('.bg-handle');
    handle.addEventListener('click', () => { if (!justDragged && gutterBlock) openBlockMenu(gutterBlock); });
    handle.addEventListener('pointerdown', startDrag);
  }
  function showGutterFor(b) { gutterBlock = b; gutter.classList.add('show'); const dr = doc().getBoundingClientRect(), br = b.getBoundingClientRect(); gutter.style.left = (br.left - dr.left - 44) + 'px'; gutter.style.top = (br.top - dr.top + 1) + 'px'; }
  function hideGutter() { if (gutter) gutter.classList.remove('show'); gutterBlock = null; }
  function startDrag(e) {
    if (!gutterBlock) return;
    e.preventDefault();
    dragging = true; dragBlock = gutterBlock; justDragged = false; dropBefore = null;
    window.addEventListener('pointermove', onDrag);
    window.addEventListener('pointerup', endDrag, { once: true });
  }
  function onDrag(e) {
    if (!justDragged) { justDragged = true; dragBlock.classList.add('blk-dragging'); document.body.style.cursor = 'grabbing'; }
    const others = [...docBody().children].filter(b => b !== dragBlock);
    let before = null;
    for (const b of others) { const r = b.getBoundingClientRect(); if (e.clientY < r.top + r.height / 2) { before = b; break; } }
    dropBefore = before;
    showDrop(before);
  }
  function showDrop(before) {
    if (!dropEl) { dropEl = document.createElement('div'); dropEl.className = 'blk-drop'; doc().appendChild(dropEl); }
    const dr = doc().getBoundingClientRect(), bodyR = docBody().getBoundingClientRect();
    const ref = before || dragBlock; const rr = ref.getBoundingClientRect();
    const y = before ? rr.top : (docBody().lastElementChild.getBoundingClientRect().bottom);
    dropEl.style.left = (bodyR.left - dr.left) + 'px';
    dropEl.style.width = docBody().clientWidth + 'px';
    dropEl.style.top = (y - dr.top - 1) + 'px';
  }
  function endDrag() {
    dragging = false; document.body.style.cursor = '';
    window.removeEventListener('pointermove', onDrag);
    if (justDragged && dragBlock) { if (dropBefore) docBody().insertBefore(dragBlock, dropBefore); else docBody().appendChild(dragBlock); DocAside.render(); }
    dragBlock && dragBlock.classList.remove('blk-dragging');
    if (dropEl) { dropEl.remove(); dropEl = null; }
    dragBlock = null; dropBefore = null;
    setTimeout(() => { justDragged = false; }, 0);
  }
  // 块菜单（点 ⋮⋮）
  let blkMenuEl = null;
  const blkMenuOpen = () => !!blkMenuEl;
  function openBlockMenu(block) {
    closeBlockMenu();
    blkMenuEl = document.createElement('div'); blkMenuEl.className = 'blk-menu';
    blkMenuEl.innerHTML = `
      <button data-a="turn"><span class="ico">${icon('edit', 15)}</span>转换成…</button>
      <button data-a="dup"><span class="ico">${icon('copy', 15)}</span>复制</button>
      <button class="danger" data-a="del"><span class="ico">${icon('trash', 15)}</span>删除</button>`;
    doc().appendChild(blkMenuEl);
    const dr = doc().getBoundingClientRect(), gr = gutter.getBoundingClientRect();
    blkMenuEl.style.left = (gr.left - dr.left) + 'px';
    blkMenuEl.style.top = (gr.bottom - dr.top + 4) + 'px';
    blkMenuEl.querySelectorAll('button').forEach(b => b.addEventListener('mousedown', e => { e.preventDefault(); blkAction(b.dataset.a, block); }));
    setTimeout(() => document.addEventListener('mousedown', closeBlkOut), 0);
  }
  function closeBlkOut(e) { if (blkMenuEl && !blkMenuEl.contains(e.target)) closeBlockMenu(); }
  function closeBlockMenu() { if (blkMenuEl) { blkMenuEl.remove(); blkMenuEl = null; document.removeEventListener('mousedown', closeBlkOut); } }
  function blkAction(a, block) {
    if (a === 'del') { block.remove(); closeBlockMenu(); hideGutter(); DocAside.render(); }
    else if (a === 'dup') { const c = block.cloneNode(true); block.after(c); c.classList.add('blk-morph'); bindPills(); closeBlockMenu(); DocAside.render(); }
    else if (a === 'turn') { closeBlockMenu(); openSlashTurn(block); }
  }
})();
