// tab-sse.js — SSE event inspector (Phase 6 entity-state model).
// Subscribes to the 3 unified event types and renders them in a matrix:
//
//   Source: chat | forge | conversation   (which event family to show)
//   View:   stream | raw                  (rendered or raw JSON)
//
// Each event = full entity snapshot; subscribers find by id and replace.

document.addEventListener('alpine:init', () => {
  Alpine.data('sseTab', () => ({
    source: 'chat',     // 'chat' | 'forge' | 'conversation'
    view:   'stream',   // 'stream' | 'raw'

    events: [],         // raw view: [{type, time, data}]
    messages: [],       // chat view: [Message snapshot]
    forges:   [],       // forge view: [Forge snapshot]
    convs:    [],       // conversation view: [Conversation snapshot]

    _es: null,
    autoScroll: true,

    get conversationId() { return Alpine.store('app').conversationId },

    init() {
      this.$watch('conversationId', () => this._reconnect())
    },

    // ── source switch ─────────────────────────────────────────────────────────

    setSource(s) {
      this.source = s
      this.clear()
    },

    // ── SSE connection ────────────────────────────────────────────────────────

    _reconnect() {
      if (this._es) { this._es.close(); this._es = null }
      const id = this.conversationId
      if (!id) return

      const es = new EventSource(`/api/v1/events?conversationId=${id}`)
      this._es = es

      // Subscribe to all 3 — even when only one source is shown, we keep raw
      // log of everything for debugging.
      // 订阅全 3 个——即使只展示一个 source，raw 日志保留全部供调试。
      const types = ['chat.message', 'forge', 'conversation']
      types.forEach(type => {
        es.addEventListener(type, e => {
          const data = JSON.parse(e.data)
          this.events.push({
            type,
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
            data,
          })
          if (type === 'chat.message') this._handleChatMessage(data)
          else if (type === 'forge')   this._handleForge(data)
          else if (type === 'conversation') this._handleConversation(data)
          if (this.autoScroll) this._scroll()
        })
      })
    },

    // ── chat.message handler — replace by id ──────────────────────────────────

    _handleChatMessage(m) {
      if (!m || !m.id) return
      const idx = this.messages.findIndex(x => x.id === m.id)
      if (idx >= 0) this.messages[idx] = m
      else this.messages.push(m)
    },

    // ── forge handler — replace by id ─────────────────────────────────────────

    _handleForge(f) {
      if (!f || !f.id) return
      const idx = this.forges.findIndex(x => x.id === f.id)
      if (idx >= 0) this.forges[idx] = f
      else this.forges.push(f)
    },

    // ── conversation handler — single entity, replace ─────────────────────────

    _handleConversation(c) {
      if (!c || !c.id) return
      const idx = this.convs.findIndex(x => x.id === c.id)
      if (idx >= 0) this.convs[idx] = c
      else this.convs.push(c)
    },

    // ── helpers ───────────────────────────────────────────────────────────────

    clear() {
      this.events = []
      this.messages = []
      this.forges = []
      this.convs = []
    },

    pretty(data) { return JSON.stringify(data, null, 2) },
    cssClass(type) { return type.replace(/\./g, '-') },
    shortId(id) { return id ? id.slice(0, 12) : '?' },
    tryFmt(s) { try { return JSON.stringify(JSON.parse(s), null, 2) } catch { return s } },

    // Block helpers for chat.message stream view
    blockText(b) {
      try { return JSON.parse(b.data).text || '' } catch { return '' }
    },
    blockToolCall(b) {
      try { return JSON.parse(b.data) } catch { return {} }
    },
    blockToolResult(b) {
      try { return JSON.parse(b.data) } catch { return {} }
    },

    _scroll() {
      this.$nextTick(() => {
        const el = this.$el.querySelector('.event-log')
        if (el) el.scrollTop = el.scrollHeight
      })
    },
  }))
})
