// tab-processes.js — Bash background-process inspector (TE-12). Lists every
// child the LLM has spawned with run_in_background:true via the Bash tool,
// alongside its lifecycle phase (running / exited / killed / errored), the
// command, ring-buffer size, and an optional non-mutating tail sample.
//
// IMPORTANT: this is a pure read-side view. It does NOT advance the
// BashOutput read cursor — testers can peek without affecting the LLM's
// own polling. Killing a process is intentionally NOT exposed here; the
// LLM owns lifecycle (it spawned them, it kills them via KillShell). If
// a runaway process needs forced termination, restart the backend.
//
// tab-processes.js — Bash 后台进程检查器（TE-12）。列出每个 LLM 用
// run_in_background:true 经 Bash 工具 spawn 的子进程及其生命周期阶段、
// 命令、环形缓冲大小、可选非破坏性尾样本。
//
// 重要：纯只读视图，不动 BashOutput 游标——测试者偷看不影响 LLM 轮询。
// 故意不暴露 kill——LLM 拥有生命周期（自己 spawn 自己 KillShell）；失控
// 进程要终止就重启后端。

document.addEventListener('alpine:init', () => {
  Alpine.data('processesTab', () => ({
    processes: [],
    sample: 2048,
    expanded: {},     // bash_id → bool (show buf sample)
    loading: false,
    err: '',
    autoRefresh: true,
    _poll: null,

    init() {
      this.load()
      // Auto-poll every 3s for status transitions while user has the tab open.
      // 自动 3s 轮询让用户看到状态变化。
      this._poll = setInterval(() => {
        if (this.autoRefresh) this.load()
      }, 3000)
    },

    destroy() {
      if (this._poll) clearInterval(this._poll)
    },

    async load() {
      this.loading = true
      try {
        const r = await fetch(`/dev/bash-processes?sample=${this.sample}`)
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.processes = j.data?.processes || []
        this.err = ''
      } catch (e) {
        this.err = String(e)
      } finally {
        this.loading = false
      }
    },

    toggle(id) {
      this.expanded[id] = !this.expanded[id]
    },

    statusColor(s) {
      switch (s) {
        case 'running': return 'var(--accent)'
        case 'exited':  return 'var(--text-mute)'
        case 'killed':  return 'var(--err)'
        case 'errored': return 'var(--err)'
        default:        return 'var(--text)'
      }
    },

    fmtTime(s) {
      if (!s) return '—'
      try { return new Date(s).toLocaleTimeString() } catch { return s }
    },

    fmtBytes(n) {
      if (!n) return '0 B'
      const u = ['B', 'KB', 'MB']
      let i = 0
      while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
      return n.toFixed(i === 0 ? 0 : 1) + ' ' + u[i]
    },

    fmtElapsed(start, finish) {
      if (!start) return ''
      const startMs = new Date(start).getTime()
      const endMs = finish ? new Date(finish).getTime() : Date.now()
      const sec = Math.max(0, Math.floor((endMs - startMs) / 1000))
      if (sec < 60) return sec + 's'
      const m = Math.floor(sec / 60)
      const s = sec % 60
      return m + 'm ' + s + 's'
    },
  }))
})
