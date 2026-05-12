// tab-forge.js — live feed of trinity forging events from /api/v1/forge
// SSE (C4 D-redo-4). 4 event types × 3 scope.kind (function/handler/
// workflow). Same shape as tab-notifications.js minus the toast source
// (forge is SSE-only — no local trigger surface).
//
// Per-event renderer extracts the key fields (scope.kind/id, operation
// for started, attempt + status for env_attempt, attemptsUsed +
// envStatus for completed) so the dev can read the stream at a glance
// without expanding payload JSON.
//
// tab-forge.js — 实时 forge 事件 feed(C4 D-redo-4)。4 事件 × 3 scope.kind。
// 跟 tab-notifications.js 同模式但仅 SSE 源(forge 没有本地触发器);
// per-event 渲染抽关键字段。

document.addEventListener('alpine:init', () => {
  Alpine.data('forgeTab', () => ({
    // Feed entries: { id, type, ts, summary, ev, seq }
    events: [],

    // Type filter — closed enum (4 event types).
    typeFilters: new Set(),

    // Scope filter — kind ∈ {function/handler/workflow} or empty (all).
    kindFilter: 'all',

    _unsubForge: null,
    connState: 'closed',

    EVENT_TYPES: ['forge_started', 'forge_op_applied', 'forge_env_attempt', 'forge_completed'],
    KINDS: ['function', 'handler', 'workflow'],
    MAX_EVENTS: 200,

    init() {
      this._connectSSE()
    },

    _connectSSE() {
      const bus = Alpine.store('forgeBus')
      this.connState = bus.connState
      this._unsubForge = bus.subscribe((type, ev, lastEventId) => {
        this.events.push({
          id: 'forge:' + (lastEventId || (Date.now() + ':' + Math.random())),
          type: type,
          ts: Date.now(),
          summary: this._summarize(type, ev),
          ev: ev,
          seq: lastEventId || '',
        })
        this._trim()
      })
      this.$watch('$store.forgeBus.connState', v => { this.connState = v })
    },

    _trim() {
      if (this.events.length > this.MAX_EVENTS) {
        this.events.splice(0, this.events.length - this.MAX_EVENTS)
      }
    },

    // _summarize produces a one-line preview. Format per type:
    //   forge_started      → "<kind>/<id> [<operation>]"
    //   forge_op_applied   → "<kind>/<id> op#<index>: <op>"
    //   forge_env_attempt  → "<kind>/<id> attempt <n> [<status>]"
    //   forge_completed    → "<kind>/<id> [<status>] envStatus=<ready|failed> attempts=<n>"
    //
    // _summarize 给每类事件抽关键字段一行预览。
    _summarize(type, ev) {
      const scope = ev.scope || {}
      const head = (scope.kind || '?') + '/' + (scope.id || '?')
      switch (type) {
        case 'forge_started':
          return head + ' [' + (ev.operation || '?') + ']'
        case 'forge_op_applied':
          return head + ' op#' + (ev.index ?? '?') + ': ' + (ev.op || '?')
        case 'forge_env_attempt': {
          let s = head + ' attempt ' + (ev.attempt ?? '?') + ' [' + (ev.status || '?') + ']'
          if (ev.error) s += ' err: ' + String(ev.error).slice(0, 60)
          return s
        }
        case 'forge_completed': {
          let s = head + ' [' + (ev.status || '?') + ']'
          if (ev.envStatus) s += ' envStatus=' + ev.envStatus
          if (ev.attemptsUsed) s += ' attempts=' + ev.attemptsUsed
          return s
        }
        default:
          return head
      }
    },

    // ── Filter controls ────────────────────────────────────────────────

    setKindFilter(k) {
      this.kindFilter = k
    },

    toggleTypeFilter(t) {
      if (this.typeFilters.has(t)) this.typeFilters.delete(t)
      else this.typeFilters.add(t)
      this.typeFilters = new Set(this.typeFilters)
    },

    filteredEvents() {
      let out = this.events
      if (this.kindFilter !== 'all') {
        out = out.filter(e => (e.ev.scope || {}).kind === this.kindFilter)
      }
      if (this.typeFilters.size > 0) {
        out = out.filter(e => this.typeFilters.has(e.type))
      }
      return out
    },

    countByType(t) { return this.events.filter(e => e.type === t).length },

    typeColor(type) {
      const map = {
        forge_started: '#3267d2',
        forge_op_applied: '#0891b2',
        forge_env_attempt: '#c97600',
        forge_completed: '#2a9d3a',
      }
      return map[type] || '#666'
    },

    fmtElapsed(ts) {
      const sec = Math.floor((Date.now() - ts) / 1000)
      if (sec < 1) return 'just now'
      if (sec < 60) return sec + 's ago'
      const m = Math.floor(sec / 60)
      if (m < 60) return m + 'm ago'
      const h = Math.floor(m / 60)
      return h + 'h ago'
    },

    pretty(p) {
      try { return JSON.stringify(p, null, 2) } catch { return String(p) }
    },

    clearHistory() {
      this.events = []
    },
  }))
})
