/* Anselm feature — settings 种子数据（mock）。设置六类页的展示数据，镜像后端真实形态（workspace/apikey/model/mcp/skill/sandbox/limits/free-tier）。 */
window.SETTINGS = {
  // ① 通用
  workspace: { name: "Personal", color: "海蓝", language: "中文 (zh-CN)" },

  // ② 模型与 Key —— 镜像后端：GET /providers + api_keys 单表 + model-capabilities + workspace 三场景默认（见 WRK-034）
  // provider 目录（ProviderMeta + 前端图标 glyph；图标后端不给、前端配）。12 LLM（mock 不入 UI）+ 4 search。
  providers: [
    { name: "openai", label: "OpenAI", glyph: "AI", base: "https://api.openai.com/v1", category: "llm" },
    { name: "anthropic", label: "Anthropic", glyph: "An", base: "https://api.anthropic.com", category: "llm" },
    { name: "google", label: "Google Gemini", glyph: "G", base: "https://generativelanguage.googleapis.com/v1beta", category: "llm" },
    { name: "deepseek", label: "DeepSeek", glyph: "DS", base: "https://api.deepseek.com", category: "llm" },
    { name: "anselm", label: "Anselm Free", glyph: "✦", base: "https://api.anselm.host/v1", category: "llm", managed: true },
    { name: "openrouter", label: "OpenRouter", glyph: "OR", base: "https://openrouter.ai/api/v1", category: "llm" },
    { name: "qwen", label: "通义千问", glyph: "通", base: "https://dashscope.aliyuncs.com/compatible-mode/v1", category: "llm" },
    { name: "zhipu", label: "智谱 GLM", glyph: "智", base: "https://open.bigmodel.cn/api/paas/v4", category: "llm" },
    { name: "moonshot", label: "Moonshot Kimi", glyph: "K", base: "https://api.moonshot.cn/v1", category: "llm" },
    { name: "doubao", label: "字节豆包", glyph: "豆", base: "https://ark.cn-beijing.volces.com/api/v3", category: "llm" },
    { name: "ollama", label: "Ollama", glyph: "L", base: "", baseReq: true, category: "llm" },
    { name: "custom", label: "Custom 兼容", glyph: "⚙", base: "", baseReq: true, apiFormat: true, category: "llm" },
    { name: "brave", label: "Brave Search", glyph: "B", base: "https://api.search.brave.com/res/v1", category: "search" },
    { name: "serper", label: "Serper.dev", glyph: "S", base: "https://google.serper.dev", category: "search" },
    { name: "tavily", label: "Tavily", glyph: "T", base: "https://api.tavily.com", category: "search" },
    { name: "bocha", label: "博查 Bocha", glyph: "博", base: "https://api.bochaai.com/v1", category: "search" },
  ],
  // 已配 key（api_keys 行，含 anselm managed 免费档）。id=aki_*；status=test_status；managed 行不可改删。
  keys: [
    { id: "aki_anselm", provider: "anselm", name: "免费额度", masked: "gwk_•••• 8c0a", status: "ok", managed: true, quota: { used: 1800, limit: 5000, resetAt: "07-01" } },
    { id: "aki_anthropic", provider: "anthropic", name: "个人 key", masked: "sk-ant-•••• a91f", status: "ok" },
    { id: "aki_openai", provider: "openai", name: "团队 key", masked: "sk-•••• 7c20", status: "ok" },
    { id: "aki_ollama", provider: "ollama", name: "本地", masked: "127.0.0.1:11434", status: "error", err: "连不上" },
    { id: "aki_brave", provider: "brave", name: "个人 key", masked: "BSA•••• f3d1", status: "ok" },
  ],
  // model-capabilities（GET /api/v1/model-capabilities）：每把 key → 可用 model + 每 model 的 knobs（per-model，换 model 换一套）。
  modelCaps: {
    aki_anselm: [
      { modelId: "deepseek-v4-flash", label: "DeepSeek V4 Flash", ctx: 1000000, knobs: [] },
    ],
    aki_anthropic: [
      { modelId: "claude-opus-4-8", label: "Claude Opus 4.8", ctx: 1000000, knobs: [
        { key: "thinking", label: "思考", type: "enum", values: ["adaptive", "disabled"], default: "adaptive" },
        { key: "effort", label: "强度", type: "enum", values: ["low", "medium", "high", "xhigh", "max"], default: "high" },
      ] },
      { modelId: "claude-sonnet-4-6", label: "Claude Sonnet 4.6", ctx: 200000, knobs: [
        { key: "thinking", label: "思考", type: "enum", values: ["adaptive", "enabled", "disabled"], default: "adaptive" },
        { key: "effort", label: "强度", type: "enum", values: ["low", "medium", "high", "xhigh", "max"], default: "high" },
      ] },
      { modelId: "claude-haiku-4-5", label: "Claude Haiku 4.5", ctx: 200000, knobs: [] },
    ],
    aki_openai: [
      { modelId: "gpt-5.5", label: "GPT-5.5", ctx: 400000, knobs: [
        { key: "reasoning_effort", label: "推理强度", type: "enum", values: ["none", "low", "medium", "high", "xhigh"], default: "medium" },
        { key: "verbosity", label: "详尽度", type: "enum", values: ["low", "medium", "high"], default: "medium" },
      ] },
      { modelId: "gpt-5-mini", label: "GPT-5 mini", ctx: 400000, knobs: [
        { key: "reasoning_effort", label: "推理强度", type: "enum", values: ["minimal", "low", "medium", "high"], default: "medium" },
      ] },
      { modelId: "o3", label: "o3", ctx: 200000, knobs: [
        { key: "reasoning_effort", label: "推理强度", type: "enum", values: ["low", "medium", "high"], default: "medium" },
      ] },
    ],
    aki_ollama: [],
  },
  // 三场景默认（workspace 三列）：ModelRef {apiKeyId, modelId, options}
  defaults: [
    { scenario: "dialogue", label: "对话", hint: "用户对话主回合 · subagent", ref: { apiKeyId: "aki_anthropic", modelId: "claude-opus-4-8", options: { thinking: "adaptive", effort: "high" } } },
    { scenario: "utility", label: "工具", hint: "标题 · 摘要 · 压缩 · 搜索精选", ref: { apiKeyId: "aki_openai", modelId: "gpt-5-mini", options: { reasoning_effort: "low" } } },
    { scenario: "agent", label: "Agent", hint: "Agent 实体调用", ref: { apiKeyId: "aki_anthropic", modelId: "claude-sonnet-4-6", options: {} } },
  ],
  defaultSearchKeyId: "aki_brave",

  // ③ MCP 与市场
  mcpMarket: [
    { name: "GitHub", desc: "代码仓库 · issue · PR", auth: "token", authLabel: "需 token" },
    { name: "Notion", desc: "笔记 · 数据库", auth: "oauth", authLabel: "OAuth" },
    { name: "Linear", desc: "项目 · issue 跟踪", auth: "token", authLabel: "需 token" },
    { name: "Box", desc: "网盘 · 文件", auth: "byo", authLabel: "需自建应用" },
    { name: "Glean", desc: "企业搜索", auth: "oauth-url", authLabel: "OAuth · 填 URL" },
    { name: "Figma", desc: "设计稿 Dev Mode", auth: "local", authLabel: "本地" },
    { name: "Stripe", desc: "支付 · 账单", auth: "token", authLabel: "需 token" },
    { name: "Sentry", desc: "错误监控", auth: "oauth", authLabel: "OAuth" },
    { name: "Supabase", desc: "Postgres · 后端", auth: "token", authLabel: "需 token" },
  ],
  mcpInstalled: [
    { name: "github", status: "ready", tools: 28, source: "市场" },
    { name: "filesystem", status: "ready", tools: 11, source: "市场" },
    { name: "notion", status: "degraded", tools: 15, source: "市场" },
    { name: "postgres", status: "ready", tools: 6, source: "市场" },
    { name: "slack", status: "failed", tools: 0, source: "市场", err: "需重新授权" },
  ],

  // ④ 技能
  skills: [
    { name: "release-notes", desc: "从 PR 生成发布说明", source: "user" },
    { name: "triage-flowrun", desc: "诊断失败的 flowrun", source: "ai" },
    { name: "code-review", desc: "审查 diff 的正确性", source: "user" },
  ],

  // ⑤ 运行时与索引
  embedder: "builtin",
  embedderStatus: "就绪 · embeddinggemma-300m",
  runtimes: [
    { kind: "python", version: "3.12.13", size: "82 MB" },
    { kind: "node", version: "22.22.3", size: "64 MB" },
    { kind: "uv", version: "0.11.4", size: "31 MB" },
  ],
  diskUsage: "1.9 GB",
  bootstrap: "ok",

  // ⑥ 高级（运行上限：13 字段 / 5 段）
  limits: [
    ["Agent", [["最大步数", "25"], ["调用轮数", "10"]]],
    ["上下文", [["压缩触发比例", "0.80"]]],
    ["超时（秒）", [["LLM 空闲", "150"], ["MCP 调用", "180"], ["Bash 默认", "120"], ["Function 运行", "300"], ["Agent 调用", "900"]]],
    ["工具", [["Read 默认行数", "2000"], ["Bash 输出上限 (KB)", "256"], ["工具结果上限 (KB)", "256"]]],
    ["护栏", [["附件上限 (MB)", "50"], ["Webhook body (MB)", "10"]]],
  ],
};
