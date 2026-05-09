// tab-mcp.js — MCP servers + marketplace panel (Marketplace V3). Two
// sub-views: configured servers (lifecycle ops + tool inspection)
// and the curated marketplace (21 hand-picked entries — one-click
// install with required env/args validation + Tier 2 OAuth flow).
//
// Drop zone accepts a Claude-Desktop-shaped JSON fragment
// ({mcpServers: {...}}) and POSTs it to /mcp-servers:import. The
// most common way users configure MCP outside the GUI.

document.addEventListener('alpine:init', () => {
  Alpine.data('mcpTab', () => ({
    section: 'servers',         // 'servers' | 'marketplace'
    servers: [],
    selected: null,
    // Marketplace V3 (2026-05-09): full list — 21 curated entries
    // returned by GET /api/v1/mcp-registry. Client-side substring filter
    // replaces V2's server-side keyword search.
    // Marketplace V3：全量返 21 条 curated。客户端过滤替代 V2 服务端搜索。
    filterQuery: '',
    loadingRegistry: false,
    registry: [],
    selectedRegEntry: null,
    installEnv: {},             // map[name]string — for selected reg entry
    installArgs: {},            // map[name]string
    loading: false,
    importBusy: false,
    actionBusy: '',             // server name being acted on
    err: '',
    dragOver: false,
    // TE-14 stderr viewer
    stderrModal: { open: false, name: '', text: '', size: 0, loading: false, err: '' },

    async init() {
      // ESC closes the stderr modal — match the global modal-dismiss
      // convention used everywhere else.
      // ESC 关 stderr modal——跟其他 modal 行为一致。
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && this.stderrModal.open) {
          this.closeStderr();
        }
      });
      // V3: load both installed servers and the curated marketplace
      // up-front. Marketplace is now ~21 entries — small enough to
      // fetch eagerly so the dev sees the full list immediately.
      // V3：服务和 marketplace 都预加载。Marketplace ~21 条体量小，eager
      // 抓让 dev 立刻看到全列表。
      await this.loadServers()
      await this.loadRegistry()
    },

    async loadServers() {
      this.loading = true
      this.err = ''
      try {
        const r = await fetch('/api/v1/mcp-servers')
        if (!r.ok) {
          this.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.servers = (j.data || []).sort((a, b) => a.name.localeCompare(b.name))
      } catch (e) {
        this.err = String(e)
      } finally {
        this.loading = false
      }
    },

    async loadRegistry() {
      this.loadingRegistry = true
      this.err = ''
      try {
        const r = await fetch('/api/v1/mcp-registry')
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `marketplace load failed HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          this.registry = []
          return
        }
        const j = await r.json()
        // Backend returns tier-asc + name-asc; trust that ordering.
        // 后端已 tier asc + name asc 排，直接用。
        this.registry = j.data || []
      } catch (e) {
        this.err = String(e)
        this.registry = []
      } finally {
        this.loadingRegistry = false
      }
    },

    filteredRegistry() {
      const q = (this.filterQuery || '').trim().toLowerCase()
      if (!q) return this.registry
      return this.registry.filter(e =>
        (e.name || '').toLowerCase().includes(q) ||
        (e.category || '').toLowerCase().includes(q) ||
        (e.description || '').toLowerCase().includes(q)
      )
    },

    selectServer(srv) {
      this.selected = srv
      this.selectedRegEntry = null
    },

    async reconnect(srv) {
      this.actionBusy = srv.name
      this.err = ''
      try {
        const r = await fetch(`/api/v1/mcp-servers/${encodeURIComponent(srv.name)}:reconnect`, { method: 'POST' })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `reconnect failed HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        await this.loadServers()
      } catch (e) {
        this.err = 'reconnect error: ' + e
      } finally {
        this.actionBusy = ''
      }
    },

    async healthCheck(srv) {
      this.actionBusy = srv.name
      this.err = ''
      try {
        const r = await fetch(`/api/v1/mcp-servers/${encodeURIComponent(srv.name)}:health-check`, { method: 'POST' })
        if (!r.ok) {
          this.err = `health-check failed HTTP ${r.status}`
          return
        }
        const j = await r.json()
        const h = j.data || {}
        this.err = `${srv.name}: ${h.healthy ? 'healthy' : 'unhealthy'} (${h.latencyMs}ms, ${h.toolCount} tools${h.error ? ', err: ' + h.error : ''})`
        await this.loadServers()
      } finally {
        this.actionBusy = ''
      }
    },

    async openStderr(srv) {
      this.stderrModal = { open: true, name: srv.name, text: '', size: 0, loading: true, err: '' }
      await this.refreshStderr()
    },

    async refreshStderr() {
      if (!this.stderrModal.name) return
      this.stderrModal.loading = true
      try {
        const r = await fetch(`/api/v1/mcp-servers/${encodeURIComponent(this.stderrModal.name)}/stderr`)
        if (!r.ok) {
          this.stderrModal.err = `HTTP ${r.status}`
          return
        }
        const j = await r.json()
        this.stderrModal.text = (j.data?.stderr) || ''
        this.stderrModal.size = j.data?.size || 0
        this.stderrModal.err = ''
      } catch (e) {
        this.stderrModal.err = String(e)
      } finally {
        this.stderrModal.loading = false
      }
    },

    closeStderr() { this.stderrModal.open = false },

    async deleteServer(srv) {
      if (!confirm(`Delete MCP server "${srv.name}"? Removes from ~/.forgify/mcp.json + disconnects subprocess.`)) return
      this.actionBusy = srv.name
      this.err = ''
      try {
        const r = await fetch(`/api/v1/mcp-servers/${encodeURIComponent(srv.name)}`, { method: 'DELETE' })
        if (!r.ok && r.status !== 204) {
          const j = await r.json().catch(() => null)
          this.err = `delete failed HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        if (this.selected?.name === srv.name) this.selected = null
        await this.loadServers()
      } catch (e) {
        this.err = 'delete error: ' + e
      } finally {
        this.actionBusy = ''
      }
    },

    selectRegEntry(entry) {
      this.selectedRegEntry = entry
      this.selected = null
      // Pre-init env/args maps to empty strings so x-model bindings render.
      // 预初始化 env/args map 为空串让 x-model 绑定渲染。
      this.installEnv = {}
      for (const r of (entry.requiredEnv || [])) this.installEnv[r.name] = ''
      this.installArgs = {}
      for (const r of (entry.requiredArgs || [])) this.installArgs[r.name] = ''
    },

    async install() {
      if (!this.selectedRegEntry) return
      const name = this.selectedRegEntry.name
      const tier = this.selectedRegEntry.tier || 0
      this.actionBusy = name
      this.err = ''
      try {
        const r = await fetch(`/api/v1/mcp-registry/${encodeURIComponent(name)}:install`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ env: this.installEnv, args: this.installArgs }),
        })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `install failed HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        const j = await r.json()
        const status = j.data || {}
        this.err = `installed ${name}: status=${status.status}` + (status.lastError ? ', err: ' + status.lastError : '')
        await this.loadServers()
        this.section = 'servers'
        this.selected = this.servers.find(s => s.name === name) || null
        const installedSrv = this.selected
        this.selectedRegEntry = null
        // Tier 2 (OAuth device-code): auto-open stderr modal so the
        // login URL surfaces immediately, then poll a few times to
        // catch the URL appearing after subprocess startup.
        // Tier 2 (OAuth 设备码)：自动打开 stderr 让登录链接立刻可见，再
        // 短轮询几次抓 subprocess 启动后才印出的 URL。
        if (tier === 2 && installedSrv) {
          await this.openStderr(installedSrv)
          for (let i = 0; i < 6; i++) {
            await new Promise(res => setTimeout(res, 1000))
            if (!this.stderrModal.open) break
            await this.refreshStderr()
            if (/https?:\/\//.test(this.stderrModal.text)) break
          }
        }
      } finally {
        this.actionBusy = ''
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
        .filter(f => f.name.endsWith('.json'))
      if (files.length === 0) {
        this.err = 'drop a .json file (Claude Desktop format: {"mcpServers": {...}})'
        return
      }
      this.importBusy = true
      try {
        const text = await files[0].text()
        const r = await fetch('/api/v1/mcp-servers:import', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: text,
        })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `import failed HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        const j = await r.json()
        const res = j.data || {}
        let msg = `imported: ${(res.imported || []).length}`
        if ((res.conflicts || []).length) msg += `, conflicts: ${res.conflicts.join(', ')}`
        this.err = msg
        await this.loadServers()
      } catch (ex) {
        this.err = String(ex)
      } finally {
        this.importBusy = false
      }
    },

    statusColor(s) {
      switch (s) {
        case 'ready': return '#2a9d3a'
        case 'degraded': return '#c97600'
        case 'failed': return '#c93434'
        case 'connecting': return '#3267d2'
        case 'disconnected': return '#888'
        default: return '#888'
      }
    },

    fmtTime(s) {
      if (!s) return '—'
      try { return new Date(s).toLocaleTimeString() } catch { return s }
    },
  }))
})
