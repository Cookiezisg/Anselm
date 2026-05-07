// tab-notifications.js — read the toasts store + record everything pushed
// (active and dismissed) into a local history. Lets the user browse what
// fired recently + manually trigger test toasts to verify wiring.
//
// tab-notifications.js — 读 toasts store + 把推过的全记录到本地 history。
// 让用户回看近期触发了什么 + 手动触发测试 toast 验证接线正常。

document.addEventListener('alpine:init', () => {
  Alpine.data('notificationsTab', () => ({
    history: [],   // [{id, type, text, ts, active}]
    filter: 'all', // 'all' | 'success' | 'error' | 'warn' | 'info'

    init() {
      // Watch the toasts store: any new toast (id we haven't seen) is
      // recorded into history. Dismissed toasts stay in history but flip
      // .active=false. Cap at 200 entries (drop oldest first).
      //
      // 监听 toasts store：新 toast 入 history，已 dismiss 的留 history 但
      // active=false。容量 200，溢出 drop 最旧。
      this.$watch('$store.toasts.list', list => {
        const now = Date.now();
        for (const t of list) {
          if (!this.history.some(h => h.id === t.id)) {
            this.history.unshift({
              id: t.id,
              type: t.type,
              text: t.text,
              ts: now,
              active: true,
            });
          }
        }
        // Mark vanished as inactive (still in history).
        // 已消失的标 inactive。
        const liveIds = new Set(list.map(t => t.id));
        for (const h of this.history) {
          if (h.active && !liveIds.has(h.id)) h.active = false;
        }
        // Trim.
        if (this.history.length > 200) this.history.length = 200;
      });
    },

    get filteredHistory() {
      if (this.filter === 'all') return this.history;
      return this.history.filter(h => h.type === this.filter);
    },

    countByType() {
      const c = { all: this.history.length, success: 0, error: 0, warn: 0, info: 0 };
      for (const h of this.history) {
        if (c[h.type] != null) c[h.type]++;
      }
      return c;
    },

    fire(type) {
      const samples = {
        success: ['Saved', 'Created', 'Operation completed'],
        error:   ['Save failed: connection refused', 'Server returned 500', 'Network error'],
        warn:    ['Cache out of date', 'Deprecation: this endpoint will be removed', 'Unusual response shape'],
        info:    ['Backend restart in 5s', 'Sync in progress', 'Reconnecting…'],
      };
      const arr = samples[type] || ['Hello'];
      window.toast[type](arr[Math.floor(Math.random() * arr.length)]);
    },

    fireSticky() {
      window.toast.info('Sticky notification (manual dismiss only)', { sticky: true });
    },

    clearHistory() {
      this.history = [];
    },

    clearActive() {
      window.Alpine.store('toasts').clear();
    },

    fmtElapsed(ts) {
      const sec = Math.floor((Date.now() - ts) / 1000);
      if (sec < 1) return 'just now';
      if (sec < 60) return sec + 's ago';
      const m = Math.floor(sec / 60);
      if (m < 60) return m + 'm ago';
      const h = Math.floor(m / 60);
      return h + 'h ago';
    },
  }));
});
