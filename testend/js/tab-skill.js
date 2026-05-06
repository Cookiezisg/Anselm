// tab-skill.js — Skill management panel (D7). Lists installed
// Anthropic Agent Skills from ~/.forgify/skills/, lets testers
// inspect frontmatter + body, manually invoke a skill, drop
// a SKILL.md file to import, force a Scan, and delete.
//
// Skill state is filesystem-backed; the harness skill watcher
// auto-rescans on disk changes so most operations don't need an
// explicit refresh, but the button is there for cases where the
// watcher missed an event (NFS, container fs quirks).

document.addEventListener('alpine:init', () => {
  Alpine.data('skillTab', () => ({
    skills: [],
    selected: null,           // skill object from list
    body: '',                 // SKILL.md raw content (lazy-loaded on select)
    loading: false,
    refreshing: false,
    importBusy: false,
    invokeBusy: false,
    invokeArgs: '',           // JSON array string for activate args
    invokeResult: '',
    err: '',
    dragOver: false,

    async init() {
      await this.load()
    },

    async load() {
      this.loading = true
      this.err = ''
      try {
        const r = await fetch('/api/v1/skills')
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.skills = (j.data || []).sort((a, b) => a.name.localeCompare(b.name))
      } catch (e) {
        this.err = String(e)
      } finally {
        this.loading = false
      }
    },

    async refresh() {
      this.refreshing = true
      this.err = ''
      try {
        const r = await fetch('/api/v1/skills:refresh', { method: 'POST' })
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.skills = (j.data || []).sort((a, b) => a.name.localeCompare(b.name))
      } catch (e) {
        this.err = String(e)
      } finally {
        this.refreshing = false
      }
    },

    async select(sk) {
      this.selected = sk
      this.body = '(loading...)'
      this.invokeResult = ''
      this.invokeArgs = ''
      try {
        const r = await fetch(`/api/v1/skills/${encodeURIComponent(sk.name)}/body`)
        if (!r.ok) {
          this.body = `(failed: HTTP ${r.status})`
          return
        }
        const j = await r.json()
        this.body = j.data?.body || ''
      } catch (e) {
        this.body = `(error: ${e})`
      }
    },

    async invoke() {
      if (!this.selected) return
      this.invokeBusy = true
      this.invokeResult = ''
      this.err = ''
      try {
        let args = []
        if (this.invokeArgs.trim()) {
          try {
            const parsed = JSON.parse(this.invokeArgs)
            if (!Array.isArray(parsed)) throw new Error('args must be a JSON array')
            args = parsed
          } catch (e) {
            this.err = 'invalid args JSON: ' + e.message
            return
          }
        }
        const url = `/api/v1/skills/${encodeURIComponent(this.selected.name)}:invoke`
        const r = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ arguments: args }),
        })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        const j = await r.json()
        this.invokeResult = j.data?.result || '(empty)'
      } catch (e) {
        this.err = String(e)
      } finally {
        this.invokeBusy = false
      }
    },

    async del(sk) {
      if (!confirm(`Delete skill "${sk.name}"? Removes ~/.forgify/skills/${sk.name}/ from disk.`)) return
      this.err = ''
      try {
        const r = await fetch(`/api/v1/skills/${encodeURIComponent(sk.name)}`, { method: 'DELETE' })
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        if (this.selected?.name === sk.name) this.selected = null
        await this.load()
      } catch (e) {
        this.err = String(e)
      }
    },

    onDragOver(e) {
      e.preventDefault()
      this.dragOver = true
    },

    onDragLeave() { this.dragOver = false },

    async onDrop(e) {
      e.preventDefault()
      this.dragOver = false
      const files = Array.from(e.dataTransfer?.files || [])
        .filter(f => f.name.endsWith('.md') || f.name === 'SKILL.md')
      if (files.length === 0) {
        this.err = 'drop a .md file (SKILL.md format expected)'
        return
      }
      await this.importFiles(files)
    },

    async importFiles(files) {
      this.importBusy = true
      this.err = ''
      try {
        const fd = new FormData()
        for (const f of files) fd.append('file', f, f.name)
        const r = await fetch('/api/v1/skills:import?overwrite=true', { method: 'POST', body: fd })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        const j = await r.json()
        const res = j.data || {}
        let msg = `imported: ${(res.imported || []).length}`
        if ((res.conflicts || []).length) msg += `, conflicts: ${res.conflicts.join(', ')}`
        if ((res.errors || []).length) msg += `, errors: ${res.errors.length}`
        // Stash transiently in err just for visibility; not actually error.
        this.err = msg
        await this.load()
      } catch (e) {
        this.err = String(e)
      } finally {
        this.importBusy = false
      }
    },
  }))
})
