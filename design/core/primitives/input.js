/* Foryx 原语 — Input / Textarea。高 --ctl;统一焦点环;只读 token。
   opts:{ value?, placeholder?, multiline?, mono?, full? }。 */
(function () {
  if (window.cssNextTo) cssNextTo(document.currentScript);

  function html(o) {
    o = o || {};
    var cls = 'fy-input' + (o.mono ? ' fy-mono' : '') + (o.full ? ' fy-input-full' : '');
    if (o.multiline) return '<textarea class="' + cls + ' fy-input-area" placeholder="' + window.esc(o.placeholder || '') + '">' + window.esc(o.value || '') + '</textarea>';
    return '<input class="' + cls + '" placeholder="' + window.esc(o.placeholder || '') + '" value="' + window.esc(o.value || '') + '">';
  }
  function mount(host, o) { var e = window.el(html(o)); if (host) host.appendChild(e); return { el: e }; }

  window.FyInput = { html: html, mount: mount };
})();
