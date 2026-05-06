// tab-subagent.js — Subagent observation panel (D3-D4). Tied to the
// currently-selected conversation: lists subagent runs spawned during
// that conversation, lets you drill into one run to see its full
// message replay (the sub-LLM's internal thinking that the parent
// LLM only saw as a single tool_result).
//
// Also shows the static subagent type catalog (Explore / Plan /
// general-purpose) so testers know what types are available without
// digging into code.

document.addEventListener('alpine:init', () => {
  Alpine.data('subagentTab', () => ({
    runs: [],
    types: [],
    selectedRun: null,        // {id, type, status, ...} from the run list
    selectedDetail: null,     // full run object from GET /subagent-runs/{id}
    selectedMessages: [],     // messages in the selected run
    loading: false,
    err: '',

    get conversationId() { return Alpine.store('app').conversationId },

    init() {
      // Initial type catalog — never changes, fetch once.
      // 类型 catalog 不变，一次性取。
      this.loadTypes()
      // Re-load runs whenever the user picks a different conversation.
      // 切换对话时重 load runs。
      this.$watch('conversationId', () => {
        this.selectedRun = null
        this.selectedDetail = null
        this.selectedMessages = []
        this.loadRuns()
      })
      this.loadRuns()
    },

    async loadTypes() {
      try {
        const r = await fetch('/api/v1/subagent-types')
        if (!r.ok) return
        const j = await r.json()
        this.types = j.data || []
      } catch {}
    },

    async loadRuns() {
      this.err = ''
      if (!this.conversationId) {
        this.runs = []
        return
      }
      this.loading = true
      try {
        const r = await fetch(`/api/v1/conversations/${this.conversationId}/subagent-runs`)
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.runs = (j.data || []).sort((a, b) => (b.createdAt || '').localeCompare(a.createdAt || ''))
      } catch (e) {
        this.err = String(e)
      } finally {
        this.loading = false
      }
    },

    async selectRun(run) {
      this.selectedRun = run
      this.selectedDetail = null
      this.selectedMessages = []
      try {
        const [detailRes, msgsRes] = await Promise.all([
          fetch(`/api/v1/subagent-runs/${run.id}`),
          fetch(`/api/v1/subagent-runs/${run.id}/messages`),
        ])
        if (detailRes.ok) {
          const j = await detailRes.json()
          this.selectedDetail = j.data
        }
        if (msgsRes.ok) {
          const j = await msgsRes.json()
          this.selectedMessages = j.data || []
        }
      } catch (e) {
        this.err = String(e)
      }
    },

    statusColor(status) {
      switch (status) {
        case 'completed': return '#2a9d3a'
        case 'failed': return '#c93434'
        case 'cancelled': return '#888'
        case 'max_turns': return '#c97600'
        case 'running': return '#3267d2'
        default: return '#888'
      }
    },

    fmtTime(s) {
      if (!s) return '—'
      try { return new Date(s).toLocaleTimeString() } catch { return s }
    },

    fmtTokens(t) { return (t == null) ? '—' : t.toString() },
  }))
})
