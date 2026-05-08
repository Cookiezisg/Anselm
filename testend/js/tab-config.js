document.addEventListener('alpine:init', () => {
  Alpine.data('configTab', () => ({
    keys: [],
    modelConfig: null,
    busyKeyId: '',     // id of key currently being tested — string compare is reliably reactive
    showAdd: false,
    ap: 'deepseek', akey: '', aurl: '',
    addBusy: false,
    mp: '', mid: '',
    modelBusy: false,

    // providersMeta is fetched from GET /api/v1/providers on init —
    // single source of truth for the LLM/Search whitelist + per-provider
    // displayName + baseUrlRequired flag. Replaces the previous
    // hardcoded allProviders array.
    //
    // providersMeta 在 init 时从 GET /api/v1/providers 拉——LLM/Search 白名单 +
    // 各 provider displayName + baseUrlRequired 标志的单一事实源。替代之前
    // 的硬编码 allProviders。
    providersMeta: [],

    async init() {
      await this._loadProviders()
      await Promise.all([this._loadKeys(), this._loadModel()])
      this.$watch('mp', p => {
        const ms = this._modelsFor(p)
        this.mid = ms[0] ?? ''
      })
    },

    async _fetch(method, url, body) {
      const opts = { method, headers: {} }
      if (body != null) {
        opts.headers['Content-Type'] = 'application/json'
        opts.body = JSON.stringify(body)
      }
      try {
        const r = await fetch(url, opts)
        const j = await r.json().catch(() => null)
        return { r, j, networkErr: null }
      } catch (e) {
        return { r: null, j: null, networkErr: e }
      }
    },

    // _toastFetchError surfaces a backend / network failure as a toast.
    // ctx is a short label like "save model" so the user sees what
    // operation failed. Honors the {data, error} envelope.
    //
    // _toastFetchError 把后端 / 网络失败转 toast。ctx 是简短标签如 "save model"
    // 让用户看出哪一步炸了。遵从 {data,error} envelope。
    _toastFetchError(ctx, res) {
      if (res.networkErr) {
        toast.error(ctx + ' failed: ' + res.networkErr)
        return
      }
      const msg = res.j?.error?.message || ('HTTP ' + (res.r?.status ?? '?'))
      toast.error(ctx + ' failed: ' + msg)
    },

    async _loadProviders() {
      const res = await this._fetch('GET', '/api/v1/providers')
      if (!res.r || !res.r.ok) {
        this._toastFetchError('Load providers', res)
        return
      }
      this.providersMeta = res.j?.data ?? []
    },

    async _loadKeys() {
      const res = await this._fetch('GET', '/api/v1/api-keys?limit=50')
      if (!res.r || !res.r.ok) {
        this._toastFetchError('Load API keys', res)
        return
      }
      this.keys = res.j?.data ?? []
    },

    async _loadModel() {
      const res = await this._fetch('GET', '/api/v1/model-configs')
      if (!res.r || !res.r.ok) {
        this._toastFetchError('Load model config', res)
        return
      }
      const chat = (res.j?.data ?? []).find(m => m.scenario === 'chat')
      if (chat) {
        this.modelConfig = { provider: chat.provider, modelId: chat.modelId }
        this.mp = chat.provider
        this.mid = chat.modelId
      } else {
        const ok = this.keys.find(k => k.testStatus === 'ok' && this._isLLM(k.provider))
        if (ok) { this.mp = ok.provider; this.mid = this._modelsFor(ok.provider)[0] ?? '' }
      }
    },

    // ── Provider lookups (driven by providersMeta) ───────────────────
    _providerMeta(name) { return this.providersMeta.find(p => p.name === name) },
    _isLLM(name)        { return this._providerMeta(name)?.category === 'llm' },
    _isSearch(name)     { return this._providerMeta(name)?.category === 'search' },

    // llmProviders / searchProviders feed the optgroups in the add-key
    // dropdown. Default sort order from the backend is alphabetical.
    //
    // llmProviders / searchProviders 给 add-key 下拉 optgroup 用。后端默认按
    // 字母序排。
    llmProviders()    { return this.providersMeta.filter(p => p.category === 'llm') },
    searchProviders() { return this.providersMeta.filter(p => p.category === 'search') },

    // okProviders feeds the Chat Model picker — search providers are
    // filtered out since they don't return models (testSearchPing only
    // verifies connectivity).
    //
    // okProviders 给 Chat Model picker 用——过滤掉搜索 provider，它们不返
    // 模型（testSearchPing 只验连通）。
    okProviders() {
      return [...new Set(
        this.keys
          .filter(k => k.testStatus === 'ok' && this._isLLM(k.provider))
          .map(k => k.provider)
      )]
    },
    _modelsFor(p)   { return this.keys.find(k => k.provider === p && k.testStatus === 'ok')?.modelsFound ?? [] },
    modelsForMP()   { return this._modelsFor(this.mp) },
    needsURL()      { return this._providerMeta(this.ap)?.baseUrlRequired === true },

    // providerLabel renders "DisplayName (name)" for dropdown options
    // when displayName differs meaningfully from name; otherwise just
    // the name.
    //
    // providerLabel 给下拉项渲染 "DisplayName (name)"，displayName 与 name
    // 实质不同时才用括号备注；否则只显示 name。
    providerLabel(p) {
      if (!p) return ''
      if (!p.displayName || p.displayName === p.name) return p.name
      return `${p.displayName} (${p.name})`
    },

    async addKey() {
      if (!this.akey.trim()) return
      this.addBusy = true
      try {
        const res = await this._fetch('POST', '/api/v1/api-keys', {
          provider: this.ap, displayName: this.ap,
          key: this.akey, baseUrl: this.aurl, apiFormat: '',
        })
        if (!res.r || !res.r.ok) {
          this._toastFetchError('Add API key', res)
          return
        }
        this.akey = ''; this.aurl = ''; this.showAdd = false
        await this._loadKeys()
      } finally { this.addBusy = false }
    },

    testKey(id) {
      // Non-async wrapper so the busyKeyId assignment is synchronous before the event loop yields.
      // 非 async 包装，让 busyKeyId 赋值在事件循环让出前同步完成。
      this.busyKeyId = id
      this._runTest(id)
    },

    async _runTest(id) {
      try {
        const res = await this._fetch('POST', `/api/v1/api-keys/${id}:test`)
        if (!res.r || !res.r.ok) {
          this._toastFetchError('Test API key', res)
          return
        }
        await this._loadKeys()
        const ms = this._modelsFor(this.mp)
        if (ms.length > 0 && !this.mid) this.mid = ms[0]
      } finally {
        this.busyKeyId = ''
      }
    },

    async delKey(id) {
      const res = await this._fetch('DELETE', `/api/v1/api-keys/${id}`)
      if (!res.r || !res.r.ok) {
        this._toastFetchError('Delete API key', res)
        return
      }
      await this._loadKeys()
    },

    async saveModel() {
      if (!this.mp || !this.mid.trim()) return
      this.modelBusy = true
      try {
        const res = await this._fetch('PUT', '/api/v1/model-configs/chat',
          { provider: this.mp, modelId: this.mid })
        if (!res.r || !res.r.ok) {
          this._toastFetchError('Save chat model', res)
          return
        }
        await this._loadModel()
        toast.success('Chat model saved: ' + this.mp + ' · ' + this.mid)
      } finally { this.modelBusy = false }
    },
  }))
})
