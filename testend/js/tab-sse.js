// tab-sse.js — raw two-channel SSE viewer (M2 of testend rework).
//
// Lets a developer point at one of the two live SSE channels —
// /api/v1/eventlog?conversationId=X (per-conv recursive event log,
// 5 events × 6 block types) OR /api/v1/notifications (global entity
// updates, single envelope) — and watch the wire-format JSON stream
// in raw form. Useful for debugging protocol producers / consumers.
//
// Intentionally NOT semantic: every event renders as a single-line
// summary (#seq HH:MM:SS event-type [key fields]) with the full
// data payload hidden behind a <details> expander. Higher-level
// renderers live in chat.js (eventlog → message bubbles) and
// tab-notifications.js (notifications → entity feed).
//
// tab-sse.js — raw 两通道 SSE viewer。指向 /api/v1/eventlog 或
// /api/v1/notifications，看 wire-format JSON 原始流。故意不做语义
// 渲染——每事件一行摘要 + <details> 展开看 data payload。语义渲染留给
// chat.js / tab-notifications.js。

document.addEventListener('alpine:init', () => {
  Alpine.data('sseTab', () => ({
    // Channel: 'notifications' (global, default — works without picking
    // a conversation) or 'eventlog' (per-conv, requires conversationId).
    //
    // channel：'notifications'（默认，无需选对话）或 'eventlog'（per-conv）。
    channel: 'notifications',
    // For eventlog: which conversation to subscribe to. Defaults to the
    // app store's currently-selected conversation (set by sidebar /
    // chat). Manual override via the input.
    //
    // eventlog 用：默认从 app store 取当前选中对话，可手动改。
    convId: '',
    // Connection state for the right-side indicator. 'live' = open and
    // receiving; 'closed' = paused or never opened; 'error' = transport
    // error from EventSource.
    //
    // 连接状态供右上指示。'live' 已开正在收；'closed' 暂停 / 未开；
    // 'error' EventSource 报错。
    connState: 'closed',
    // Bounded ring of recent events. Cap = 500; oldest dropped on
    // overflow. Each entry: {seq, type, time, raw, parsed}.
    //
    // 有限 ring buffer，500 上限超出 drop 旧。每条 {seq, type, time, raw, parsed}。
    events: [],
    // Client-side filter — empty Set = show all; otherwise only render
    // events whose .type is in the set.
    //
    // 客户端过滤——空 Set 全显；非空只显 .type 在集合内的。
    filterTypes: new Set(),
    // Pause toggles whether incoming events get appended. Keeps the
    // EventSource alive (so seq doesn't reset) but freezes the UI.
    //
    // pause 控制是否往 events 追加。EventSource 不动（seq 不重置），UI 冻结。
    paused: false,
    // Auto-scroll: stays true until the user scrolls away from the
    // bottom; flips back to true when they scroll to the bottom again.
    //
    // 滚到底就自动跟随；用户手动向上滚就停。
    autoScroll: true,

    es: null, // EventSource instance — null when closed.

    init() {
      // Default convId from the global store (chat selected one).
      // 默认从 app store 拉 convId。
      const stored = Alpine.store('app').conversationId;
      if (stored) this.convId = stored;
      // Re-sync convId when chat changes selection (only updates the
      // input — doesn't auto-reconnect; user must click reload).
      // 对话切了同步 input，但不自动重连——用户主动点 reload。
      this.$watch('$store.app.conversationId', v => {
        if (this.channel === 'eventlog' && v && v !== this.convId) {
          this.convId = v;
        }
      });
      this.connect();
      // Track scroll position to gate auto-scroll behavior.
      // 跟踪滚动位置控制 auto-scroll。
      this.$nextTick(() => this._wireScroll());
    },

    _wireScroll() {
      const el = this.$refs.stream;
      if (!el) return;
      el.addEventListener('scroll', () => {
        const slop = 16; // px tolerance for "essentially at bottom"
        this.autoScroll = el.scrollHeight - el.scrollTop - el.clientHeight < slop;
      });
    },

    setChannel(c) {
      if (c === this.channel) return;
      this.channel = c;
      this.events = [];
      this.connect();
    },

    connect() {
      this.disconnect();
      let url;
      if (this.channel === 'eventlog') {
        if (!this.convId) {
          this.connState = 'closed';
          return;
        }
        url = '/api/v1/eventlog?conversationId=' + encodeURIComponent(this.convId);
      } else {
        url = '/api/v1/notifications';
      }
      this.es = new EventSource(url);
      this.connState = 'live';
      // EventSource named events fire one handler per type. We register
      // for the union of both channels' types so the same instance
      // handles both — extra registrations on the wrong channel are
      // dead weight (no events of that type arrive), not a bug.
      //
      // EventSource 按事件名分派。两通道事件名并集都注册——错通道的注册
      // 永远不触发，无害。
      const types = [
        // eventlog
        'message_start', 'message_stop', 'block_start', 'block_delta', 'block_stop',
        // notifications uses 'message' (default unnamed) so we add a
        // generic onmessage too. notifications types live INSIDE the
        // payload (.type field), not on the SSE event name.
        //
        // notifications 用默认 'message' 事件名；type 在 payload .type 字段里。
      ];
      for (const t of types) {
        this.es.addEventListener(t, e => this._onEvent(e, t));
      }
      this.es.onmessage = e => this._onEvent(e, 'message');
      this.es.onerror = () => {
        this.connState = 'error';
      };
      this.es.onopen = () => {
        this.connState = 'live';
      };
    },

    disconnect() {
      if (this.es) {
        this.es.close();
        this.es = null;
      }
      this.connState = 'closed';
    },

    _onEvent(e, sseEventName) {
      if (this.paused) return;
      let parsed;
      try {
        parsed = JSON.parse(e.data);
      } catch {
        parsed = { _parseError: true, raw: e.data };
      }
      // For notifications the meaningful "type" is in the payload;
      // for eventlog the SSE event name (sseEventName) is THE type.
      // Both are stored as ev.type so the filter UI works uniformly.
      //
      // notifications 的 type 在 payload；eventlog 的 type 是 SSE 事件名。
      // 都存 ev.type 让 filter 逻辑统一。
      const type = this.channel === 'notifications'
        ? (parsed.type || '(notif?)')
        : sseEventName;
      const now = new Date();
      const time = String(now.getHours()).padStart(2, '0') + ':' +
        String(now.getMinutes()).padStart(2, '0') + ':' +
        String(now.getSeconds()).padStart(2, '0') + '.' +
        String(now.getMilliseconds()).padStart(3, '0');
      this.events.push({
        seq: e.lastEventId || '',
        type,
        time,
        parsed,
        // summary line key fields we extract for one-glance reading
        // 摘要行的关键字段
        summary: this._summarize(type, parsed),
      });
      // Cap ring at 500.
      // 上限 500。
      if (this.events.length > 500) {
        this.events.splice(0, this.events.length - 500);
      }
      if (this.autoScroll) {
        this.$nextTick(() => {
          const el = this.$refs.stream;
          if (el) el.scrollTop = el.scrollHeight;
        });
      }
    },

    _summarize(type, p) {
      // Extract a one-line "key fields" preview per event type.
      // For eventlog: parentId / blockType / msgId / role. For
      // notifications: id / conversationId.
      //
      // 按事件类型提一行关键字段预览。eventlog: parentId / blockType /
      // msgId / role。notifications: id / conversationId。
      const parts = [];
      if (this.channel === 'eventlog') {
        if (p.id) parts.push('id=' + p.id);
        if (p.parentId) parts.push('parent=' + p.parentId);
        if (p.type && type.startsWith('block_')) parts.push('block.type=' + p.type);
        if (p.role) parts.push('role=' + p.role);
        if (p.status) parts.push('status=' + p.status);
        if (typeof p.delta === 'string') {
          const preview = p.delta.length > 40 ? p.delta.slice(0, 40) + '…' : p.delta;
          parts.push('delta=' + JSON.stringify(preview));
        }
      } else {
        if (p.id) parts.push('id=' + p.id);
        if (p.conversationId) parts.push('conv=' + p.conversationId);
        if (p.data && typeof p.data === 'object') {
          const keys = Object.keys(p.data).slice(0, 3).join(',');
          if (keys) parts.push('data:{' + keys + '}');
        }
      }
      return parts.join('  ');
    },

    togglePause() {
      this.paused = !this.paused;
    },

    clear() {
      this.events = [];
    },

    toggleFilter(t) {
      if (this.filterTypes.has(t)) this.filterTypes.delete(t);
      else this.filterTypes.add(t);
      // Force Alpine re-render — Set mutations don't trigger reactivity.
      // 强 Alpine 重渲——Set 改不触发响应式。
      this.filterTypes = new Set(this.filterTypes);
    },

    visibleEvents() {
      if (this.filterTypes.size === 0) return this.events;
      return this.events.filter(e => this.filterTypes.has(e.type));
    },

    // Per-channel known type list for the filter dropdown. Hardcoded
    // since both channels' type vocabularies are documented in §E1.
    //
    // 过滤下拉用的已知 type 列表，按通道。两通道词表都在 §E1 写死。
    knownTypes() {
      if (this.channel === 'eventlog') {
        return ['message_start', 'message_stop', 'block_start', 'block_delta', 'block_stop'];
      }
      return ['conversation', 'todo', 'mcp_server', 'skill', 'catalog'];
    },

    pretty(p) {
      try {
        return JSON.stringify(p, null, 2);
      } catch {
        return String(p);
      }
    },

    typeColor(t) {
      const map = {
        message_start: '#3267d2',
        message_stop: '#3267d2',
        block_start: '#2a9d3a',
        block_delta: '#888',
        block_stop: '#2a9d3a',
        conversation: '#3267d2',
        todo: '#7c3aed',
        mcp_server: '#c97600',
        skill: '#0891b2',
        catalog: '#0891b2',
      };
      return map[t] || '#666';
    },
  }));
});
