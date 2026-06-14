/* Forgify design-lab — Documents 海洋编排（单独，一人负责整个 oceans/documents/ 文件夹）。
   注册进外壳：Shell.registerOcean('documents', { build(sea) })，渲染文档页到 #sea；右岛交给 right-island.js。
   形态：WYSIWYG 渲染即编辑 + 内联选段 :iterate（本页 --accent 主舞台）+ 严格只做文档页（树归侧栏）。
   硬规则：手编辑路径刻意零流光/零 diff（忠于后端「整篇覆盖、无 delta 流」）；唯 :iterate 选段改写才上 --accent 流光。
   依赖：shared/icons.js · shared/shell.js · ./right-island.js（DocAside）。打字机引擎自包含（不 import chat）。 */
(function () {
  const $ = (s, r = document) => r.querySelector(s);
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  let runId = 0;
  const alive = id => id === runId;

  // 自包含打字机（同 chat-v0 引擎：caret + 逐字 + runId 守护，可被重播打断）
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

  // 示意正文（markdown 渲染产物；接后端时换真 content）。#aiTarget = 内联 AI 改写靶。
  const BODY_HTML = `
    <p>本页定义 <span class="doc-pill"><span class="ico">${icon('link', 12)}</span>文档海洋</span> 里「一篇文档」的<span id="aiTarget">视觉与交互规范</span>，供并发设计与 Flutter 落地共用。</p>
    <h2>排版即分区</h2>
    <p>整页 <b>不画一条横线</b>。层级靠字号、分节靠留白、代码与引用靠浮起的灰色小岛——与 <span class="doc-pill"><span class="ico">${icon('at', 12)}</span>设计原则</span> 一脉相承。</p>
    <ul>
      <li>标题用尺寸阶梯（24 / 19 / 15），不靠编号或下划线。</li>
      <li>段落之间用 <code>--s4</code> 留白分隔。</li>
      <li>引用与代码是两档灰的「岛」，再靠字体区分。</li>
    </ul>
    <blockquote>海与岛同色，只靠海岸线分。文档区不能像 Notion 那样靠底色块划区，得靠留白与圆角。</blockquote>
    <h2>正文怎么存</h2>
    <p>后端把正文存成 <b>单块 markdown 字符串</b>，整篇覆盖、无版本 diff。所以这里按「一篇 markdown」建模，而非可拖拽的 block 数据库：</p>
    <div class="doc-code"><span class="lang">md</span><pre>## 关键约束
- 单篇正文 ≤ 1 MB
- 标题 ≤ 256 字、不含 "/"
- [[wikilink]] 写入即同步关系出边</pre></div>
    <h3>待办</h3>
    <ul class="doc-tasks">
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">渲染态零横线方案</span></li>
      <li class="done"><span class="box">${icon('check', 12)}</span><span class="t">内联 AI 选段改写</span></li>
      <li><span class="box"></span><span class="t">表格斑马底待内核拍板</span></li>
    </ul>
    <div class="doc-hr"><i></i><i></i><i></i></div>
    <table class="doc-table">
      <thead><tr><th>构件</th><th>处理</th><th>底色</th></tr></thead>
      <tbody>
        <tr><td>引用</td><td>浮起浅灰岛</td><td>--cc-hover</td></tr>
        <tr><td>代码</td><td>深一档灰岛 + 等宽</td><td>--cc-active</td></tr>
        <tr><td>分隔线</td><td>留白 + 三点</td><td>—</td></tr>
      </tbody>
    </table>`;

  Shell.registerOcean('documents', {
    crumb: '文档',
    build(sea) {
      sea.innerHTML = `
        <div class="doc-scroll" id="docScroll">
          <article class="doc" id="doc">
            <div class="doc-path" id="docPath"></div>
            <h1 class="doc-title" id="docTitle" contenteditable="true" spellcheck="false"></h1>
            <div class="doc-meta" id="docMeta"></div>
            <div class="doc-body" id="docBody" contenteditable="true" spellcheck="false"></div>
          </article>
        </div>`;
      // 主区头：状态指示 + 右岛钮 + 重播（海洋自己的按钮，进 #head-extra）
      Shell.headExtra(`
        <span class="doc-status" id="docStatus"></span>
        <button class="ibtn" id="i_panel" title="大纲 / 反链 / 元信息">${icon('panel')}</button>
        <button class="ibtn" id="i_replay" title="重播">${icon('play', 16)}</button>`);
      $('#i_panel').onclick = () => DocAside.toggle();
      $('#i_replay').onclick = run;
      DocAside.ensure();
      run();
    },
  });

  function setStatus(mode) {
    const el = $('#docStatus'); if (!el) return;
    if (mode === 'saved') { el.className = 'doc-status'; el.innerHTML = `<span class="ico">${icon('check', 14)}</span>已保存`; }
    else if (mode === 'edit') { el.className = 'doc-status live'; el.innerHTML = `<span class="pulse"></span>编辑中`; }
    else if (mode === 'ai') { el.className = 'doc-status live'; el.innerHTML = `<span class="pulse"></span>AI 编辑中`; }
  }

  function renderHead() {
    $('#docPath').innerHTML = `
      <span class="ico">${icon('folder', 13)}</span>
      <button class="doc-pathseg">产品</button><span class="sep">/</span>
      <button class="doc-pathseg">前端</button><span class="sep">/</span>
      <span class="cur">文档页设计规范</span>`;
    $('#docTitle').textContent = '文档页设计规范';
    $('#docMeta').innerHTML = `
      <span>更新于 2 小时前</span><span class="dot-sep">·</span>
      <span>1.2k 字</span><span class="dot-sep">·</span>
      <button class="doc-backref" id="docBackref">3 个反链</button>
      <span class="doc-tags">
        <span class="doc-tag"><span class="ico">${icon('tag', 11)}</span>design</span>
        <span class="doc-tag"><span class="ico">${icon('tag', 11)}</span>frontend</span>
      </span>`;
    $('#docBackref').onclick = () => DocAside.show();
  }

  function bindPills() {
    $('#docBody').querySelectorAll('.doc-pill').forEach(p => p.onclick = () => DocAside.show());
  }

  // 内联 AI 浮条：贴选区上方弹出（位置算自靶元素相对 #doc）
  function showAiBar(target) {
    const doc = $('#doc');
    const bar = document.createElement('div'); bar.className = 'ai-bar';
    bar.innerHTML = `<span class="spark">${icon('spark', 15, 1.6)}</span>
      <button>改写</button><button>续写</button><button>精简</button><button>翻译</button>`;
    doc.appendChild(bar);
    const r = target.getBoundingClientRect(), dr = doc.getBoundingClientRect();
    bar.style.left = Math.max(0, r.left - dr.left) + 'px';
    bar.style.top = (r.top - dr.top - bar.offsetHeight - 8) + 'px';
    return bar;
  }

  // —— 自动演示编排（八步，复刻 chat 的重播肌肉记忆）——
  async function run() {
    const id = ++runId;
    const body = $('#docBody'); if (!body) return;
    DocAside.hide();

    // ① 进场：一篇已有文档，错峰淡入（证明零横线下全构件清晰分层）
    renderHead();
    body.innerHTML = BODY_HTML;
    [...body.children].forEach((c, i) => { c.classList.add('fadein'); c.style.animationDelay = (i * 55) + 'ms'; });
    bindPills();
    setStatus('saved');
    DocAside.render();
    await sleep(1500); if (!alive(id)) return;

    // ③ 手编辑 + markdown 即输即渲（零流光，诚实手/AI 二分）
    setStatus('edit');
    const h = document.createElement('h2'); h.className = 'doc-morph'; body.appendChild(h);
    h.scrollIntoView({ behavior: 'smooth', block: 'center' });
    await sleep(120);
    await typeInto(h, '## 边界与缺口'); if (!alive(id)) return;
    await sleep(180); h.textContent = '边界与缺口'; h.classList.remove('doc-morph');   // ## 标记落定 → spring 长成标题
    await sleep(380); if (!alive(id)) return;
    const ul = document.createElement('ul'); const li = document.createElement('li'); ul.appendChild(li); body.appendChild(ul);
    await typeInto(li, '树状导航归侧栏，本页只渲染文档本身。'); if (!alive(id)) return;
    await sleep(650); if (!alive(id)) return;
    setStatus('saved');
    await sleep(750); if (!alive(id)) return;

    // ④ 内联 AI（S1 选区 → S2 浮条）
    const target = $('#aiTarget'); if (!target) return;
    target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    await sleep(550); if (!alive(id)) return;
    target.classList.add('doc-sel');
    const bar = showAiBar(target);
    await sleep(950); if (!alive(id)) return;

    // ⑤ 触发改写流式（S3：旧文退场 + 新文 --accent 文字流光逐字锻造，forge 镜像感）
    bar.remove();
    target.classList.remove('doc-sel');
    const oldTxt = target.textContent;
    target.innerHTML = `<span class="ai-old">${oldTxt}</span><span class="ai-new run"></span><span class="ai-live"></span>`;
    setStatus('ai');
    await typeInto(target.querySelector('.ai-new'), '完整的视觉与交互契约'); if (!alive(id)) return;
    await sleep(280); if (!alive(id)) return;

    // ⑥ 落定（S4：旧文移除、新文沉淀 ink，浮 ✓保留/↩还原，自动接受 → 回落已保存）
    target.querySelector('.ai-old')?.remove();
    target.querySelector('.ai-live')?.remove();
    target.querySelector('.ai-new')?.classList.remove('run');
    const acts = document.createElement('span'); acts.className = 'ai-actions';
    acts.innerHTML = `<button class="ai-act keep"><span class="ico">${icon('check', 12)}</span>保留</button><button class="ai-act undo">还原</button>`;
    target.appendChild(acts);
    setStatus('edit');
    await sleep(1200); if (!alive(id)) return;
    acts.remove();
    target.textContent = '完整的视觉与交互契约';   // unwrap 收回靶元素
    setStatus('saved');
    await sleep(750); if (!alive(id)) return;

    // ⑦ 亮网：右岛滑入（TOC 高亮当前节 / 反链 / 元信息）
    DocAside.show();
  }
})();
