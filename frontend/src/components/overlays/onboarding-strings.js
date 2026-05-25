// Onboarding copy (zh / en) + UI constants. Scoped i18n: full-app i18n is a
// future module. Picked by settings.lang (device-detected on first run).
//
// 引导文案(中/英)+ 常量。scoped i18n;全 app i18n 留以后。按 settings.lang 取。

export const ACCENTS = [
  ["claude", "#d97757"],
  ["blue", "#2383e2"],
  ["ink", "#37352f"],
  ["green", "#0f7b6c"],
  ["purple", "#6940a5"],
];

// LLM provider chips (abbr + brand color). Keyed by backend provider `name`.
export const LLM_HINTS = {
  deepseek: { abbr: "DS", color: "#4D6BFE" },
  openai: { abbr: "OA", color: "#10A37F" },
  anthropic: { abbr: "AN", color: "#D97757" },
  google: { abbr: "GO", color: "#4285F4" },
  qwen: { abbr: "QW", color: "#615CED" },
  zhipu: { abbr: "ZP", color: "#3870E0" },
  moonshot: { abbr: "MS", color: "#37352F" },
  ollama: { abbr: "OL", color: "#6b6459" },
};

export const SEARCH_HINTS = {
  bocha: { abbr: "BC", color: "#1f9d55" },
  brave: { abbr: "BR", color: "#fb542b" },
  serper: { abbr: "SE", color: "#5436da" },
  tavily: { abbr: "TV", color: "#0f7b6c" },
};

// Fallback model id used ONLY when :test returns no modelsFound (e.g.
// Anthropic ping). Must be a real, runnable id.
export const PROVIDER_DEFAULT_MODEL = {
  anthropic: "claude-sonnet-4-6",
};

export const STRINGS = {
  zh: {
    brandSub: "本地 AI 工作台 · v1.2",
    footer1: "数据本地存储于",
    footer2: "不上传 · 无需登录",
    stepWord: "步骤",
    back: "上一步", next: "继续", start: "开始", skip: "跳过", enter: "进入 Forgify",
    auto: "已根据系统",
    journey: {
      welcome: ["欢迎", "了解 Forgify"],
      workspace: ["工作空间", "命名"],
      appearance: ["外观", "主题与语言"],
      model: ["模型", "API Key 与模型"],
      search: ["搜索", "可选"],
      done: ["完成", "开始使用"],
    },
    welcome: {
      kicker: "第 1 步 · 欢迎",
      title: "欢迎使用 Forgify",
      sub: "本地优先的 AI agent 工作台。用自然语言驱动它完成任务,并将过程沉淀为可复用的工具。",
      features: [
        ["对话驱动", "描述目标,agent 自主选择工具、编写代码、运行工作流。"],
        ["能力沉淀", "协助构建 Function、Handler、Workflow,内置版本管理与回滚。"],
        ["本地运行", "数据存储于本地,不上传云端,无需登录。"],
      ],
    },
    workspace: {
      kicker: "第 2 步 · 工作空间",
      title: "创建工作空间",
      sub: "为工作空间命名。后续可在设置中新增或切换,各空间的数据相互隔离。",
      label: "工作空间名称",
      placeholder: "例如 个人 / 工作 / 写作",
      hint: "显示在侧边栏底部。切换工作空间时仅切换该空间的数据。",
    },
    appearance: {
      kicker: "第 3 步 · 外观",
      title: "外观与语言",
      sub: "语言与主题已根据系统设置自动选择,可随时调整。以下均可在「设置」中修改。",
      accent: "主题色", language: "语言", theme: "主题",
      themeOpts: { light: "浅色", dark: "深色", system: "跟随系统" },
    },
    model: {
      kicker: "第 4 步 · 模型",
      title: "配置模型",
      sub: "选择厂商、填入 API Key,验证后选择要使用的模型。也可稍后在「设置」中配置。",
      providerLabel: "模型服务商",
      scrollNote: "可滚动查看全部厂商",
      keyLabel: (p) => `${p} API Key`,
      keyPlaceholder: "sk-…",
      verify: "验证并获取模型", verifying: "验证中…", verified: "已验证",
      modelLabel: "模型",
      ollamaHint: "Ollama 为本地推理,无需 API Key。请确保 ollama serve 已启动。",
      availHint: (list) => `可用模型:${list.join(" · ")}(下拉切换)`,
    },
    search: {
      kicker: "第 5 步 · 联网搜索",
      optional: "· 可选",
      title: "联网搜索",
      sub: "配置一个搜索服务,agent 即可联网检索资料。不配也能正常使用 —— 需要时在「设置」里再加。",
      providerLabel: "搜索服务商",
      keyLabel: (p) => `${p} API Key`,
      keyPlaceholder: "填入 key,或跳过此步",
    },
    done: {
      title: "设置完成",
      sub: "一切就绪。开始你的第一个对话,或让 agent 为你构建第一个工具。",
      recap: { workspace: "工作空间", accent: "主题色", model: "模型", search: "搜索" },
      none: "稍后",
    },
    toast: {
      keyVerified: "API Key 已验证",
      keyFail: "Key 已保存,但验证未通过",
      opFail: "操作失败",
      welcome: "欢迎使用 Forgify",
    },
  },
  en: {
    brandSub: "Local AI workspace · v1.2",
    footer1: "Data stored locally at",
    footer2: "No upload · No login",
    stepWord: "Step",
    back: "Back", next: "Continue", start: "Start", skip: "Skip", enter: "Enter Forgify",
    auto: "From system",
    journey: {
      welcome: ["Welcome", "About Forgify"],
      workspace: ["Workspace", "Name it"],
      appearance: ["Appearance", "Theme & language"],
      model: ["Model", "API key & model"],
      search: ["Search", "Optional"],
      done: ["Done", "Get started"],
    },
    welcome: {
      kicker: "Step 1 · Welcome",
      title: "Welcome to Forgify",
      sub: "A local-first AI agent workspace. Drive it with natural language, and distill the work into reusable tools.",
      features: [
        ["Conversation-driven", "Describe a goal; the agent picks tools, writes code, runs workflows."],
        ["Distilled capability", "Build Functions, Handlers, Workflows — with built-in versioning and rollback."],
        ["Runs locally", "Data lives on your machine. No cloud upload, no login."],
      ],
    },
    workspace: {
      kicker: "Step 2 · Workspace",
      title: "Create a workspace",
      sub: "Name your workspace. Add or switch more later in Settings; each one's data is isolated.",
      label: "Workspace name",
      placeholder: "e.g. Personal / Work / Writing",
      hint: "Shown at the bottom of the sidebar. Switching swaps only that workspace's data.",
    },
    appearance: {
      kicker: "Step 3 · Appearance",
      title: "Appearance & language",
      sub: "Language and theme follow your system by default. Adjust anytime — all of this lives in Settings.",
      accent: "Accent", language: "Language", theme: "Theme",
      themeOpts: { light: "Light", dark: "Dark", system: "System" },
    },
    model: {
      kicker: "Step 4 · Model",
      title: "Configure a model",
      sub: "Pick a provider, enter an API key, verify, then choose a model. You can also do this later in Settings.",
      providerLabel: "Model provider",
      scrollNote: "Scroll for all providers",
      keyLabel: (p) => `${p} API key`,
      keyPlaceholder: "sk-…",
      verify: "Verify & list models", verifying: "Verifying…", verified: "Verified",
      modelLabel: "Model",
      ollamaHint: "Ollama runs locally — no API key needed. Make sure `ollama serve` is running.",
      availHint: (list) => `Available: ${list.join(" · ")} (switch in dropdown)`,
    },
    search: {
      kicker: "Step 5 · Web search",
      optional: "· Optional",
      title: "Web search",
      sub: "Configure a search provider and the agent can browse the web. Optional — add it later in Settings.",
      providerLabel: "Search provider",
      keyLabel: (p) => `${p} API key`,
      keyPlaceholder: "Enter a key, or skip this step",
    },
    done: {
      title: "All set",
      sub: "Everything's ready. Start your first conversation, or have the agent build your first tool.",
      recap: { workspace: "Workspace", accent: "Accent", model: "Model", search: "Search" },
      none: "Later",
    },
    toast: {
      keyVerified: "API key verified",
      keyFail: "Key saved, but verification failed",
      opFail: "Operation failed",
      welcome: "Welcome to Forgify",
    },
  },
};
