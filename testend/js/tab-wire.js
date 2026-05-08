// tab-wire.js — LLM HTTP wire trace viewer (TE-5b). Tied to the
// currently-selected conversation: lists every recent Stream() call
// with the full request payload + every emitted SSE event + final
// text + elapsed. Together with TE-2's [📋 raw] (chat.message
// snapshot) this gives the testend complete visibility from
// 'what we sent the LLM' all the way to 'what the LLM sent back'
// to 'what the chat runner persisted as a message'.

document.addEventListener('alpine:init', () => {
  Alpine.data('wireTab', () => ({
    traces: [],
    loading: false,
    err: '',
    expanded: {},      // index → bool
    eventTypeColor: {
      text: '#2a9d3a',
      reasoning: '#8a6d00',
      tool_start: '#3267d2',
      tool_delta: '#3267d2',
      finish: '#888',
      error: '#c93434',
    },

    get conversationId() { return Alpine.store('app').conversationId },

    init() {
      this.$watch('conversationId', () => this.load())
      this.load()
    },

    async load() {
      this.err = ''
      if (!this.conversationId) {
        this.traces = []
        return
      }
      this.loading = true
      try {
        const r = await fetch(`/dev/llm-trace?conversationId=${encodeURIComponent(this.conversationId)}`)
        if (!r.ok) {
          if (r.status === 503) {
            this.err = 'LLM tracer not enabled (server not running with --dev)'
          } else {
            this.err = `HTTP ${r.status}`
          }
          return
        }
        const j = await r.json()
        this.traces = (j.data?.traces || []).reverse()  // newest first
      } catch (e) {
        this.err = String(e)
      } finally {
        this.loading = false
      }
    },

    toggle(i) {
      this.expanded[i] = !this.expanded[i]
    },

    fmtTime(s) {
      if (!s) return '—'
      try { return new Date(s).toLocaleTimeString() } catch { return s }
    },

    summarize(t) {
      const counts = {}
      for (const ev of (t.events || [])) {
        counts[ev.Type] = (counts[ev.Type] || 0) + 1
      }
      const parts = []
      for (const k of ['text', 'reasoning', 'tool_start', 'tool_delta', 'finish', 'error']) {
        if (counts[k]) parts.push(`${counts[k]}× ${k}`)
      }
      return parts.join(', ') || '(no events)'
    },

    eventLabel(ev) {
      // Compose a one-line preview: type + key fields (delta first 60 chars / tool name etc.)
      // 单行概览：type + 关键字段（delta 前 60 字符 / tool 名等）。
      const pieces = []
      if (ev.Delta) pieces.push(JSON.stringify(ev.Delta.length > 60 ? ev.Delta.slice(0, 60) + '…' : ev.Delta))
      if (ev.ToolName) pieces.push('tool=' + ev.ToolName)
      if (ev.ToolID) pieces.push('id=' + ev.ToolID)
      if (ev.ArgsDelta) pieces.push('args+=' + JSON.stringify(ev.ArgsDelta.length > 60 ? ev.ArgsDelta.slice(0, 60) + '…' : ev.ArgsDelta))
      if (ev.FinishReason) pieces.push('reason=' + ev.FinishReason)
      if (ev.InputTokens || ev.OutputTokens) pieces.push(`↑${ev.InputTokens||0} ↓${ev.OutputTokens||0}`)
      // Backend StreamEvent.Err is `error` interface with no JSON tag /
      // MarshalJSON, so JSON-encoding yields `{}`. Skip empty objects to
      // avoid useless "err={}" lines; trace-level t.error already shows
      // the actual message. When backend later adds proper marshaling
      // (string), this branch picks it up automatically.
      //
      // 后端 StreamEvent.Err 是 error interface 无 JSON tag，序列化得 `{}`。
      // 跳空对象避免 "err={}" 噪音；trace-level t.error 已显真实信息。
      // 后端将来加 MarshalJSON 输出字符串时此分支自动捕获。
      const errStr = typeof ev.Err === 'string'
        ? ev.Err
        : (ev.Err && Object.keys(ev.Err).length > 0 ? JSON.stringify(ev.Err) : '')
      if (errStr) pieces.push('err=' + errStr)
      return pieces.join(' ')
    },
  }))
})
