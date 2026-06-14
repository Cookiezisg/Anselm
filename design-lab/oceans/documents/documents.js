/* Forgify design-lab — Documents 海洋编排（单独，一人负责整个 oceans/documents/ 文件夹）。
   本页 = 包含「我们设计的全部 markdown 格式」的样张（可上下滑），加内联选段 AI。
   内容区放宽外壳禁横线/禁下划线（见 documents.css 注），正文不用灰填充块、行内代码不学 Notion 的红。
   交互：① 加载即静态全格式样张（看一眼所有格式）；② 真实选中正文文字 → 上方浮起 AI 浮条 → 点动作 → 选区流光扫过（演示 :iterate 流式改写视觉，mockup 不造假内容）；③ 主区头 ▶ 重置样张。
   依赖：shared/icons.js · shared/shell.js · ./right-island.js（DocAside）。打字机/流光自包含（不 import chat）。 */
(function () {
  const $ = (s, r = document) => r.querySelector(s);
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  let runId = 0;
  const alive = id => id === runId;

  // markdown 全格式样张（渲染产物；接后端时换真 content）
  const BODY_HTML = `
    <p>这是 Forgify 文档海洋的 <b>markdown 排版样张</b>。文档内容区<b>放宽</b>了外壳的「禁横线」规则——可以有 <a href="#">下划线链接</a>、分隔线、表格细线，大范围参考 Notion；但正文里 <b>不用灰色填充块</b>（代码、引用都是白底描边），行内代码也 <b>不学 Notion 的红色</b>。</p>

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
      <li>同样的紧凑节奏</li>
    </ol>

    <h2>任务清单</h2>
    <ul class="doc-tasks">
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">完成框是中性的近黑实底 + 白勾</span></li>
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">不用强调蓝（完成是事实、非「正在发生」）</span></li>
      <li><span class="box"></span><span class="t">未完成只是一个细描边空框</span></li>
    </ul>

    <h2>引用</h2>
    <blockquote>引用用左侧一道细竖线 + 文字降一档灰，白底无填充。学 Notion 的经典引用，但去掉了灰块。</blockquote>

    <h2>提示块</h2>
    <div class="doc-callout"><span class="ico">${icon('spark', 16, 1.6)}</span><div class="c"><b>这是一个 Callout。</b>我们设计的提示块（Notion 借鉴）：白底 + 一圈描边 + 左侧图标，用来强调一段话，而不靠底色块。</div></div>

    <h2>代码</h2>
    <p>行内是 <code>const x = 1</code>；多行是代码块——<b>白底、外面一个圈</b>、等宽字、右上角标语言：</p>
    <div class="doc-code"><span class="lang">ts</span><pre>// 文档正文 = 单块 markdown 字符串
function render(md: string): Html {
  return parse(md);   // 整篇覆盖、无版本 diff
}</pre></div>

    <h2>表格</h2>
    <p>表格可以有细线（表头一道、行间细线），干净利落：</p>
    <table class="doc-table">
      <thead><tr><th>构件</th><th>样式</th><th>说明</th></tr></thead>
      <tbody>
        <tr><td>引用</td><td>左竖线 + 灰字</td><td>白底无填充</td></tr>
        <tr><td>代码</td><td>白底 + 描边 + 等宽</td><td>不红</td></tr>
        <tr><td>表格</td><td>细线分隔</td><td>放宽禁线</td></tr>
      </tbody>
    </table>

    <h2>链接与提及</h2>
    <p>外部链接是 <a href="#">下划线文字</a>；文档间用 <span class="doc-pill"><span class="ico">${icon('link', 13)}</span>另一篇文档</span> 这样的 wikilink；提到实体用 <span class="doc-pill"><span class="ico">${icon('at', 13)}</span>某个 Agent</span>。都是「图标 + 下划线文字」，不再是灰药丸。失效链接：<span class="doc-pill broken"><span class="ico">${icon('link', 13)}</span>已删除的文档</span>。</p>

    <h2>分隔线</h2>
    <p>分隔线现在就是一条细线（不再是三个点）：</p>
    <hr>
    <p>用来分隔大段落。</p>

    <h2>图片</h2>
    <p>图片圆角裁切、可带说明：</p>
    <div class="doc-imgph">图片占位</div>
    <div class="doc-cap">图：示意配图（mockup 占位）</div>`;

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
      wireInlineAI();
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

  // 加载即静态全格式样张（▶ 也走这里重置）
  function render() {
    runId++;                                  // 打断任何进行中的 AI 流光
    const body = $('#docBody'); if (!body) return;
    renderHead();
    body.innerHTML = BODY_HTML;
    body.classList.remove('fadein'); void body.offsetWidth; body.classList.add('fadein');
    bindPills();
    setStatus('saved');
    DocAside.render();
    $('#docScroll').scrollTop = 0;
    hideBar();
  }

  // —— 内联 AI：真实选中正文文字 → 浮条；点动作 → 选区流光扫过（演示流式改写视觉，不造假内容） ——
  let bar = null;
  function hideBar() { if (bar) { bar.remove(); bar = null; } }

  function wireInlineAI() {
    const body = $('#docBody');
    body.addEventListener('mousedown', hideBar);
    body.addEventListener('mouseup', () => setTimeout(() => {
      const sel = window.getSelection();
      if (!sel || sel.isCollapsed || sel.rangeCount === 0 || !body.contains(sel.anchorNode)) return;
      const range = sel.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      if (rect.width < 2) return;
      showBar(rect, range.cloneRange());
    }, 0));
  }

  function showBar(rect, range) {
    hideBar();
    const doc = $('#doc');
    bar = document.createElement('div'); bar.className = 'ai-bar';
    bar.innerHTML = `<span class="spark">${icon('spark', 15, 1.6)}</span>` +
      ['改写', '续写', '精简', '翻译'].map(t => `<button>${t}</button>`).join('');
    doc.appendChild(bar);
    const dr = doc.getBoundingClientRect();
    const left = Math.min(Math.max(8, rect.left - dr.left), doc.clientWidth - bar.offsetWidth - 8);
    bar.style.left = left + 'px';
    bar.style.top = (rect.top - dr.top - bar.offsetHeight - 8) + 'px';
    // onmousedown + preventDefault：点钮不清除选区
    bar.querySelectorAll('button').forEach(b => b.addEventListener('mousedown', e => { e.preventDefault(); aiSweep(range); }));
  }

  async function aiSweep(range) {
    const id = ++runId;
    hideBar();
    setStatus('ai');
    let span = null;
    try { span = document.createElement('span'); span.className = 'ai-new run'; range.surroundContents(span); }
    catch (e) { span = null; }   // 选区跨元素边界：降级为只闪状态、不包裹
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
})();
