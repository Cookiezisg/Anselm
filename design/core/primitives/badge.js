/* Foryx 原语 — Badge(状态/标签药丸)。可带状态点。tone: neutral/ok/warn/danger/accent。
   opts:{ label, dot?, tone? }。 */
(function () {
  if (window.cssNextTo) cssNextTo(document.currentScript);

  function html(o) {
    o = o || {};
    var d = o.dot ? window.FyDot.dot(o.dot) : '';
    return '<span class="fy-badge fy-badge-' + (o.tone || 'neutral') + '">' + d + '<span>' + window.esc(o.label || '') + '</span></span>';
  }
  function mount(host, o) { var e = window.el(html(o)); if (host) host.appendChild(e); return { el: e }; }

  window.FyBadge = { html: html, mount: mount };
})();
