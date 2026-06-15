/* Foryx 原语 — Tabs(标签页)。统一一套(收掉 demo 里 Tabs/Segmented 两套打架的 API,SPEC §4.11)。
   懒渲染:只渲染当前页。mount(host, { items:[{key,label,render(paneEl)}], value?, onPick? }) → {el, select(key)}。 */
(function () {
  if (window.cssNextTo) cssNextTo(document.currentScript);

  function mount(host, o) {
    o = o || {};
    var items = o.items || [];
    var el = window.tag('div.fy-tabs');
    var strip = window.tag('div.fy-tabs-strip');
    var pane = window.tag('div.fy-tabs-pane');
    items.forEach(function (it) {
      var b = window.tag('button.fy-tab', { type: 'button', 'data-key': it.key }, window.esc(it.label));
      b.onclick = function () { select(it.key); if (o.onPick) o.onPick(it.key); };
      strip.appendChild(b);
    });
    el.appendChild(strip); el.appendChild(pane);

    function select(key) {
      window.qsa('.fy-tab', strip).forEach(function (b) { b.classList.toggle('on', b.dataset.key === key); });
      pane.innerHTML = '';
      var it = items.find(function (x) { return x.key === key; });
      if (it && it.render) it.render(pane);
    }

    if (host) host.appendChild(el);
    select(o.value || (items[0] && items[0].key));
    return { el: el, select: select };
  }

  window.FyTabs = { mount: mount };
})();
