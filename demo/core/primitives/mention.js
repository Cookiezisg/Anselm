/* Anselm 地基 — AnMention（@ 提及 picker·命令式 helper，非 custom element）。
   why：doc-editor 与 composer 都要「在 contenteditable 上 @ → 边打边滤实体/文档 picker → 内联插 an-ref-pill」。
        把这套 caret/query/插桩从 doc-editor 抽成地基级 helper，两处同源——杜绝两份 @ 处理（#8 复用优先、强化地基）。
   复用底座：AnMenu（picker UI）· AnFloating（浮层）· an-ref-pill（药丸）——只补「caret 探测 + @query 删插」这点 glue。
   API：AnMention.attach(editable, { mentions, namespace?, getSelection?, onInsert? }) → { pick(anchor?), end(), destroy() }
     editable     contenteditable 根元素（自动在其上监听「@」起会话）
     mentions     [] 或 () => []（动态取池；每项 {kind,id,label,desc?}）
     getSelection () => Selection（shadow 宿主传 shadowRoot.getSelection；默认 window.getSelection）
     onInsert(m)  选中插入后回调（可选）
   行为：键入「@」→ 起会话（监听 input 边打边滤 + 开 AnMenu）；选中插药丸 + 删「@query」；空格/Esc/Enter/失配/无 @ 结束。
        pick(anchor)：无 @ 会话直接开 picker 选一项插（斜杠「@提及」/ 工具栏 @ 钮）。 */
(function () {
  // an-ref-pill 串（doc-editor 与 composer 同源——插桩 HTML 单处）
  function refHtml(r) {
    var e = window.anEsc;
    return '<an-ref-pill kind="' + e(r.kind || "") + '" id="' + e(r.id || "") + '" label="' + e(r.label || "") + '" contenteditable="false"></an-ref-pill>';
  }

  function attach(editable, opts) {
    opts = opts || {};
    var ns = opts.namespace || "mention";
    var getSel = opts.getSelection || function () { return window.getSelection(); };
    var poolFn = typeof opts.mentions === "function" ? opts.mentions : function () { return opts.mentions || []; };
    var session = null;   // { input, key, query, closing }

    // 候选项（无匹配给一条不可选标签）
    function items(q) {
      var lo = (q || "").toLowerCase();
      var ms = poolFn().filter(function (m) { return !lo || (m.label + " " + (m.desc || "") + " " + m.id).toLowerCase().indexOf(lo) >= 0; });
      return ms.length
        ? ms.map(function (m) { return { value: m.id, label: m.label, icon: m.kind, meta: m.desc || m.kind, _m: m }; })
        : [{ type: "label", label: "无匹配「" + q + "」" }];
    }
    // caret 前的「@query」文本（无 @ 返 null）
    function queryText() {
      var s = getSel(); if (!s || !s.anchorNode || !editable.contains(s.anchorNode)) return null;
      var node = s.anchorNode; if (node.nodeType !== 3) return null;
      var text = node.textContent.slice(0, s.anchorOffset);
      var at = text.lastIndexOf("@");
      return at < 0 ? null : text.slice(at + 1);
    }
    // 菜单锚：caret 所在的 editable 直接子元素（doc-editor 的 .b 块 / composer 的 editable 本体）
    function anchorNow() {
      var s = getSel(); var n = s && s.anchorNode;
      if (!n) return editable;
      if (n.nodeType === 3) n = n.parentNode;
      while (n && n.parentNode && n.parentNode !== editable && n !== editable) n = n.parentNode;
      return (n && n.nodeType === 1) ? n : editable;
    }

    function update() {
      var q = queryText();
      if (q == null || /\s/.test(q)) { end(); return; }
      if (session && q === session.query) return;
      if (session) session.query = q;
      window.AnMenu.open(anchorNow(), {
        items: items(q), placement: "bottom", align: "start", namespace: ns,
        onClose: function () { if (session && !session.closing) end(); },
        onPick: function (_v, it) { if (!it._m) return; end(); insert(it._m); },
      });
    }
    function start() {
      if (session) return;
      session = { query: "@@INIT@@", closing: false };
      session.input = function () { update(); };
      session.key = function (ev) { if (ev.key === "Escape" || ev.key === " " || ev.key === "Enter") end(); };
      editable.addEventListener("input", session.input);
      editable.addEventListener("keydown", session.key);
      update();
    }
    function end() {
      if (!session) return;
      editable.removeEventListener("input", session.input);
      editable.removeEventListener("keydown", session.key);
      session.closing = true; window.AnFloating.close(ns); session = null;
    }

    // 删 caret 前的「@query」再插药丸（pick 路径无 @ 则直接插）
    function insert(m) {
      var s = getSel(); var node = s && s.anchorNode;
      if (node && node.nodeType === 3) {
        var text = node.textContent.slice(0, s.anchorOffset);
        var at = text.lastIndexOf("@");
        if (at >= 0) { var r = document.createRange(); r.setStart(node, at); r.setEnd(node, s.anchorOffset); r.deleteContents(); s.removeAllRanges(); s.addRange(r); }
      }
      insertPill(m);
      if (opts.onInsert) opts.onInsert(m);
    }
    function insertPill(m) {
      var s = getSel();
      var tmp = document.createElement("div");
      tmp.innerHTML = refHtml({ kind: m.kind, id: m.id, label: m.label }) + " ";
      var pill = tmp.firstChild, sp = tmp.lastChild;
      if (s && s.rangeCount && editable.contains(s.anchorNode)) {
        var r = s.getRangeAt(0); r.insertNode(sp); r.insertNode(pill); r.setStartAfter(sp); r.collapse(true);
        s.removeAllRanges(); s.addRange(r);
      } else { editable.append(pill, sp); }
    }

    // 无 @ 会话直接开 picker（斜杠「@提及」/ 工具栏 @ 钮）
    function pick(anchor) {
      window.AnMenu.open(anchor || editable, {
        items: poolFn().map(function (m) { return { value: m.id, label: m.label, icon: m.kind, meta: m.desc || m.kind, _m: m }; }),
        placement: "bottom", align: "start", namespace: ns,
        onPick: function (_v, it) { if (it._m) insert(it._m); },
      });
    }

    // editable 上自挂「@」起会话（宿主只 attach 一次即可）
    var onKey = function (ev) { if (ev.key === "@") setTimeout(start, 0); };
    editable.addEventListener("keydown", onKey);

    return { pick: pick, end: end, destroy: function () { end(); editable.removeEventListener("keydown", onKey); } };
  }

  window.AnMention = { attach: attach, refHtml: refHtml };
})();
