// tab-mock-llm.js — Mock LLM control panel (TE-4c). Push canned
// scripts into the dev MockClient via /dev/mock-llm/scripts +
// inspect what the chat runner most recently sent the LLM via
// /dev/mock-llm/last-prompt. Together they make the testend a
// real LLM testbench: drive arbitrary chat scenarios with no API
// key + verify wire-level prompt content.
//
// Provides script templates so testers don't have to memorize the
// llminfra.StreamEvent JSON shape: text-only / single tool call /
// multi tool call / error / finish-with-tokens.

document.addEventListener('alpine:init', () => {
  Alpine.data('mockLLMTab', () => ({
    queueDepth: 0,
    callCount: 0,
    previews: [],
    scriptText: '',          // textarea content (JSON of the body to push)
    pushBusy: false,
    err: '',
    lastPrompt: null,        // {modelId, baseURL, system, messages, tools}
    lastPromptOpen: false,

    async init() {
      // Auto-prefill with the most useful template so testers can
      // immediately push something + see how chat reacts.
      // 自动预填最有用模板让测试立即推 + 看 chat 反应。
      this.scriptText = JSON.stringify({
        scripts: [{
          events: [
            { type: 'text', delta: 'Hello from mock LLM!' },
            { type: 'finish', finishReason: 'stop', outputTokens: 6 },
          ],
        }],
      }, null, 2)
      await this.loadQueue()
      // Poll queue depth every 2s — keeps tester aware of consumption
      // without eating CPU.
      // 每 2s 轮询队列深度——让测试感知消耗状态不爆 CPU。
      this._poll = setInterval(() => this.loadQueue(), 2000)
    },

    destroy() {
      if (this._poll) clearInterval(this._poll)
    },

    async loadQueue() {
      try {
        const r = await fetch('/dev/mock-llm/queue')
        if (!r.ok) return
        const j = await r.json()
        this.queueDepth = j.data?.depth ?? 0
        this.callCount = j.data?.callCount ?? 0
        this.previews = j.data?.previews ?? []
      } catch {}
    },

    async push() {
      this.pushBusy = true
      this.err = ''
      try {
        let body
        try {
          body = JSON.parse(this.scriptText)
        } catch (e) {
          this.err = 'invalid JSON: ' + e.message
          return
        }
        const r = await fetch('/dev/mock-llm/scripts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
        if (!r.ok) {
          const j = await r.json().catch(() => null)
          this.err = `HTTP ${r.status}` + (j?.error?.message ? ': ' + j.error.message : '')
          return
        }
        const j = await r.json()
        this.err = `pushed ${j.data?.pushed} → queue depth ${j.data?.queueDepth}`
        await this.loadQueue()
      } finally {
        this.pushBusy = false
      }
    },

    async clear() {
      if (!confirm('Clear all queued mock scripts?')) return
      const r = await fetch('/dev/mock-llm/scripts', { method: 'DELETE' })
      if (r.ok) {
        const j = await r.json()
        this.err = `dropped ${j.data?.dropped} scripts`
        await this.loadQueue()
      }
    },

    async showLastPrompt() {
      try {
        const r = await fetch('/dev/mock-llm/last-prompt')
        if (!r.ok) return
        const j = await r.json()
        this.lastPrompt = j.data
        this.lastPromptOpen = true
      } catch {}
    },

    closeLastPrompt() { this.lastPromptOpen = false },

    // Templates — clicking one replaces the textarea content.
    // 模板——点一个替换 textarea 内容。
    templates: [
      {
        label: 'text response',
        body: {
          scripts: [{
            events: [
              { type: 'text', delta: 'Sure, here is your answer.' },
              { type: 'finish', finishReason: 'stop', outputTokens: 7 },
            ],
          }],
        },
      },
      {
        label: 'single tool call (search_forges)',
        body: {
          scripts: [{
            events: [
              { type: 'tool_start', toolIndex: 0, toolId: 'call_1', toolName: 'search_forges' },
              { type: 'tool_delta', toolIndex: 0, argsDelta: '{"query":"csv"}' },
              { type: 'finish', finishReason: 'tool_use', outputTokens: 12 },
            ],
          }],
        },
      },
      {
        label: 'reasoning + text (R1-style)',
        body: {
          scripts: [{
            events: [
              { type: 'reasoning', delta: 'Let me think about this...' },
              { type: 'reasoning', delta: ' the user wants ...' },
              { type: 'text', delta: 'Based on my analysis: ...' },
              { type: 'finish', finishReason: 'stop' },
            ],
          }],
        },
      },
      {
        label: 'two-script: tool then ack',
        body: {
          scripts: [
            {
              events: [
                { type: 'tool_start', toolIndex: 0, toolId: 'call_1', toolName: 'search_forges' },
                { type: 'tool_delta', toolIndex: 0, argsDelta: '{"query":"csv","summary":"finding csv tools"}' },
                { type: 'finish', finishReason: 'tool_use' },
              ],
            },
            {
              events: [
                { type: 'text', delta: 'Found 3 CSV-related forges.' },
                { type: 'finish', finishReason: 'stop' },
              ],
            },
          ],
        },
      },
      {
        label: 'error: simulated 500',
        body: {
          scripts: [{ errAfter: 'simulated provider 500 — testing LLM_STREAM_ERROR path' }],
        },
      },
    ],

    applyTemplate(t) {
      this.scriptText = JSON.stringify(t.body, null, 2)
      this.err = ''
    },
  }))
})
