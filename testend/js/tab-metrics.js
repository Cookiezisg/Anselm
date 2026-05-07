// tab-metrics.js — backend runtime telemetry. Polls /dev/runtime every 5s
// (when this tab is visible AND the document isn't backgrounded — same
// guard pattern as tab-info / tab-processes). Surfaces goroutine count
// (leak detection), heap stats (memory bloat detection), GC activity,
// and SQLite connection pool — the four things you'd hit pprof for.
//
// tab-metrics.js — 后端运行时遥测。当本 tab active 且文档不在后台时每 5s
// 轮询 /dev/runtime（同 tab-info / tab-processes 的守卫模式）。覆盖 4 大
// 常用诊断维度：goroutine（泄漏）/ heap（内存）/ GC / SQLite 连接池。

document.addEventListener('alpine:init', () => {
  Alpine.data('metricsTab', () => ({
    data: null,
    loading: false,
    err: '',
    autoRefresh: true,
    lastFetchedAt: 0,
    _poll: null,

    async init() {
      await this.load();
      this._poll = setInterval(() => {
        if (!this.autoRefresh) return;
        if (Alpine.store('app').activeRightTab !== 'metrics') return;
        if (document.hidden) return;
        this.load();
      }, 5000);
    },

    destroy() {
      if (this._poll) clearInterval(this._poll);
    },

    async load() {
      this.loading = true;
      try {
        const r = await fetch('/dev/runtime');
        if (!r.ok) {
          this.err = `HTTP ${r.status}` + (r.status === 404 ? ' — restart backend with --dev' : '');
          return;
        }
        const j = await r.json();
        this.data = j.data;
        this.err = '';
        this.lastFetchedAt = Date.now();
      } catch (e) {
        this.err = String(e);
      } finally {
        this.loading = false;
      }
    },

    fmtElapsed(ts) {
      const sec = Math.floor((Date.now() - ts) / 1000);
      if (sec < 1) return 'just now';
      if (sec < 60) return sec + 's ago';
      const m = Math.floor(sec / 60);
      return m + 'm ' + (sec % 60) + 's ago';
    },
  }));
});
