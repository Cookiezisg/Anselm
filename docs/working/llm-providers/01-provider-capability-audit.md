# LLM Provider 能力审计（2026-05-29）

> **目的**：在不开任何付费 key 的前提下，把"我们声称支持的每个 provider 到底怎么被调用、能不能跑通、thinking 怎么配"彻底排清楚。
> **方法**：对照 `backend/internal/infra/llm` 代码 + 各厂商当前官方 API 文档（2025-2026）。
> **状态**：调查完成。结论驱动后续 spec（thinking 开关 + provider 排雷）。

---

## §0 TL;DR

1. **后端今天从不发任何 thinking/reasoning 请求参数**——`oaiRequest`(openai.go:404) 与 `anthropicRequest`(anthropic.go:351) 两个出站结构体里都没有。是否 thinking 完全由所选 **model 名**决定（如 `deepseek-reasoner` vs `deepseek-chat`）。"thinking 开关"是真实功能缺口，不是配置问题。
2. **不是"只有 DeepSeek 测过"**：每个非 mock provider 的 `:test` 都有真实验证路径。但**有 3 个静态即可确认的真 bug**，会让对应 provider 在真实 chat 时直接坏掉，而 `:test` 仍报绿。
3. **thinking 编码每家都不一样**——OpenAI-compat 同一条线上就有 4 种不同形状。任何 thinking 开关必须 per-provider 序列化。
4. **不开 key 能排清楚**：靠"构造请求不发送"的黄金线格式测试 + 本地 httptest 回环 + Ollama 本地真跑。seam 已经现成。

### 判决表

| Provider | 线格式 | 今天能跑? | 关键问题 |
|---|---|---|---|
| DeepSeek | openai-compat | ✅ 能（live 测过） | thinking 只能靠换 model 名，不能用参数开关 |
| OpenAI | openai-compat | ⚠️ 能（侥幸） | 推理模型只因我们没发 temperature/max_tokens 才没 400；一旦加这俩就炸 |
| Anthropic | anthropic-native | ⚠️ 普通能 / 🔴 开 thinking 即坏 | `signature` 不回传 → thinking+工具必 400；max_tokens 硬编码 8096 |
| **Google Gemini** | openai-compat | 🔴 **chat 404** | base-url 少 `/v1beta/openai` 后缀；`:test` 走另一端点假报绿 |
| Qwen | openai-compat | ⚠️ 能 | thinking 不可开关；`enable_thinking=true` 仅 stream |
| Zhipu GLM | openai-compat | ⚠️ 能 | thinking 不可开关 |
| Moonshot | openai-compat | ⚠️ 能 | thinking 靠 model 名；`/models` 列举存疑 |
| Doubao | openai-compat | ⚠️ 能 | thinking 不可开关；`/models` 可能 404 → 假报"测试失败" |
| OpenRouter | openai-compat | ✅ 能 | thinking 不可请求（但 `reasoning_content` 别名能收到） |
| **Ollama** | openai-compat | 🔴 **base-path 自相矛盾** | 无单一 base_url 能同时让 `:test` 和 chat 工作 |
| custom(anthropic-compat) | — | 🔴 **死路** | `APIFormat` 在到达 factory 前被丢，永远落到 OpenAI 客户端、说错线格式 |

---

## §1 现状的一句话真相

**请求侧**：`buildOpenAIBody`(openai.go:267) 只填 `model/messages/tools/stream/stream_options`；`buildAnthropicBody`(anthropic.go:178) 只填 `model/max_tokens(硬编码 8096)/system/messages/tools/stream`。全后端 grep `reasoning_effort|"thinking"|enable_thinking|budget_tokens` 在请求构造处**零命中**。

**响应侧**：OpenAI-compat 解析 `delta.reasoning_content`→`EventReasoning`(openai.go:221)；Anthropic 解析 `thinking_delta`→`EventReasoning`(anthropic.go:162)。reasoning 块单独持久化(loop/stream.go:67)，并在下一轮回传给 provider(loop/history.go:52)。

→ 即：**我们会"接收并回传"reasoning，但从不"请求"它**。今天能看到 thinking，纯粹因为用户选了一个默认就 thinking 的 model。

**线格式选择**：`factory.go:55-80` 按 **provider 名** switch，不是按 `api_format` 字段。除 `anthropic`（和 `custom`+anthropic-compatible）外全部走 OpenAI 客户端。

---

## §2 逐 Provider 矩阵

> base-url「ours/correct」一栏：ours = 实际生效的；correct = 官方正确值。两者不同即 bug。

### OpenAI-compat 家族

| Provider | base-url ours / correct | auth | /models | thinking 请求编码 | 响应 reasoning 字段 |
|---|---|---|---|---|---|
| **OpenAI** | `api.openai.com/v1`（一致 ✅） | Bearer | ✅ | 顶层 `reasoning_effort: none/minimal/low/medium/high`；推理模型**拒绝** temperature/max_tokens，需 `max_completion_tokens` | 不返回（仅 `usage.reasoning_tokens`）→ 我们的 `reasoning_content` 解析对 OpenAI 永不触发 |
| **DeepSeek** | `api.deepseek.com`（一致 ✅） | Bearer | ✅ | ① model 名 `deepseek-reasoner`/`deepseek-chat`；② 新版顶层 `thinking:{type:enabled}` + 可选 `reasoning_effort` | `reasoning_content` ✅（解析已对） |
| **Gemini** | 🔴 `…googleapis.com`（缺后缀）/ 应为 `…/v1beta/openai` | Bearer（chat）/ `?key=`（test） | compat 层支持 | `reasoning_effort` 或 `extra_body.google.thinking_config{thinking_budget/level}`（二选一，互斥） | compat 层 `reasoning_content`（需 `include_thoughts:true`） |
| **Qwen** | `dashscope.aliyuncs.com/compatible-mode/v1` ✅ | Bearer | ✅ | 顶层 `enable_thinking: bool`(+`thinking_budget`)；**=true 时仅 stream**，非流式会 400 | `reasoning_content` ✅ |
| **Zhipu GLM** | `open.bigmodel.cn/api/paas/v4` ✅ | Bearer | ✅ | 顶层 `thinking:{type:enabled/disabled}`（对象，非 bool） | `reasoning_content` ✅ |
| **Moonshot** | `api.moonshot.cn/v1` ✅ | Bearer | ⚠️ 存疑 | ① model 名 `kimi-k2-thinking` 等；② k2.x 顶层 `thinking:{type}` | `reasoning_content` ✅ |
| **Doubao** | `ark.cn-beijing.volces.com/api/v3` ✅ | Bearer | ⚠️ 可能 404 | 顶层 `thinking:{type:enabled/disabled/auto}` | `reasoning_content` ✅（精确匹配） |
| **OpenRouter** | `openrouter.ai/api/v1` ✅ | Bearer | ✅ | 顶层 `reasoning:{effort\|max_tokens, exclude, enabled}`（effort 与 max_tokens 互斥） | `reasoning`，且文档明确 `reasoning_content` 为其**别名** ✅ |
| **Ollama** | 🔴 base-path 矛盾（见 §4） | Bearer（被忽略，本地无 key） | `/api/tags` | compat 层用 `reasoning_effort`；**native `think:true` 在 `/v1` 被拒** | compat 响应字段未文档化（可能是 `reasoning` 而非 `reasoning_content`）⚠️ |

### Anthropic-native（独一份）

| 维度 | ours | 正确 | 状态 |
|---|---|---|---|
| base-url | `api.anthropic.com` + `/v1/messages` | 同 | ✅ |
| auth | `x-api-key` + `anthropic-version: 2023-06-01` | 同（version 头稳定，beta 走 `anthropic-beta`） | ✅ |
| /models | 假设无 → ping 写死 `claude-3-5-haiku-latest`，不返 models | **现已有 `GET /v1/models`**（返 id + `capabilities.thinking` + per-model max_tokens） | ⚠️ 假设过时 |
| max_tokens | **硬编码 8096**(anthropic.go:19) | per-model 上限；开 thinking 时须 > budget | ⚠️ 封死每个 model |
| thinking 请求 | **无** | `thinking:{type:enabled, budget_tokens:N}`；budget≥1024 且 < max_tokens；开时须省略 temperature/top_p | 🔴 缺失 |
| **signature 回传** | **双向都坏**：解析器不抓 `signature_delta`(anthropic.go:424 无字段)；构造器回传 thinking 块无 signature(anthropic.go:283) | 工具循环中必须**原样回传** thinking 块含 signature，否则 400 | 🔴 开 thinking + 工具即炸 |

---

## §3 thinking 编码分类（功能设计的核心输入）

同一个"开/关思考"的意图，落到线上有 **5 种不同形状**：

| 形状 | 字段 | 谁用 |
|---|---|---|
| A. 字符串档位 | `reasoning_effort: "low"/"medium"/"high"/"none"` | OpenAI、Gemini(compat)、Ollama(compat) |
| B. 对象 type | `thinking: {type: "enabled"/"disabled"[/"auto"]}` | DeepSeek、Zhipu、Moonshot(k2.x)、Doubao |
| C. 布尔 | `enable_thinking: true/false` (+`thinking_budget`) | Qwen（**且 true 仅 stream**） |
| D. 对象 effort/budget | `reasoning: {effort \| max_tokens, exclude, enabled}` | OpenRouter |
| E. Anthropic 原生 | `thinking: {type:enabled, budget_tokens:N}` + signature 回传 | Anthropic |
| F. 换 model 名 | 无参数，选 reasoner/thinking 版 model id | DeepSeek、Moonshot 旧版、OpenAI(o 系本身就是) |

→ **单一字段覆盖不了**。thinking 开关必须 per-provider 序列化。最贴合现有架构的做法：在 `Request`(llm.go:110) 加一个 provider 中立的意图字段（如 `ThinkingMode auto/on/off` + 可选 budget/effort），再由各 `Adapter.BeforeRequest`（adapter.go，已有 `deepseekAdapter` 改 message 的先例）把意图翻译成该家正确的线上形状。`buildOpenAIBody` 本身不认 provider 名，故翻译应放 adapter 或给 Request 带上 provider。

---

## §4 已确认的真 Bug（按严重度）

> 区分：**Bug = 今天就坏**；**Feature gap = 没这功能**（thinking 不可开关属后者，见 §3，不在此列）。

### 🔴 B1 — Gemini chat 必 404（已逐行核对，置信 ~0.9）
- `adapter.go:40` 正确 base = `…/v1beta/openai`；`providers.go:43` 注册 base = `…googleapis.com`（缺后缀）。两处唯二声明、互相矛盾。
- 存 key 时 base 为空 → `ResolveCredentialsByID`(apikey.go:320-326) 用 `providers.go` 的**缺后缀**值回填。
- `resolveBaseURL`(factory.go:83) 见非空直接返回、**永不取** adapter 的正确默认。
- chat POST → `…googleapis.com/chat/completions` = 404。而 `:test` 走 `/v1beta/models?key=`(tester.go:226) 另一端点 → 假报绿。
- **修**：删 `providers.go:43` 的缺后缀默认（设空），让 adapter 默认生效；同时把 `testGoogleListModels` 指到与运行时一致的 compat 端点。前端加 key 表单对 LLM provider 无 base-url 输入框，故此 bug 对所有 UI 建的 Google key **必现**，非边缘情况。

### 🔴 B2 — Ollama base-path 自相矛盾（已确认）
- 同一 `base_url` 同时喂 `:test`(`+/api/tags`) 和 chat(`+/v1/chat/completions`)。
- `…:11434` → test 对、chat 缺 `/v1` 错；`…:11434/v1` → chat 对、test 变 `/v1/api/tags` 错。**无单一值两者都对**。
- **修**：`testOllamaTags` 先 `TrimSuffix(base, "/v1")` 再拼 `/api/tags`。

### 🔴 B3 — custom + anthropic-compatible 死路（前期调查确认）
- `Credentials`(domain/apikey/apikey.go:51) 无 `APIFormat` 字段 → 在到达 `factory.Build` 前被丢 → `custom` 永远落 `default`→OpenAI 客户端，对 anthropic-compatible 端点说错线格式。
- **修**：`Credentials` 加 `APIFormat` 字段并透传到 `Config`。

### 🔴 B4 — Anthropic 开 thinking 即坏（thinking 功能的硬前置）
- 普通 chat 今天能跑。但 `signature` 解析/回传双向都缺（anthropic.go:424 / :283）。
- Anthropic 规定工具循环中 thinking 块须原样回传含 signature，否则 400。我们 agent 循环重度用工具 → **一旦加 thinking 而不修 signature，必 400**。
- **修**（做 thinking 时一并）：解析加 `signature_delta`、`StreamEvent` 带 signature、构造回传带 signature；max_tokens 去硬编码并保证 > budget；开 thinking 时省略 temperature；interleaved 加 `anthropic-beta: interleaved-thinking-2025-05-14`。

### ⚠️ B5 — Doubao / Moonshot 的 `/models` 列举存疑
- 两家 `:test=get_models`，但 `/models` 是否公开未确证 → 可能 404 → 假报"测试失败"（与 Gemini 反向：那个假绿、这个可能假红）。
- **修**：实跑确认；若无 `/models`，改用一次极小 chat 探活或放宽。

---

## §5 不开 key 怎么验证（核心交付手段）

三层，全部零 key 零 token：

### L1 — 黄金线格式测试（主力，覆盖请求侧）
对每个 (provider, model, thinking 开/关)，直接调包内 `buildOpenAIBody`(openai.go:259) / `buildAnthropicBody`(anthropic.go:178)，断言**生成的 JSON 字节**与该厂商官方 curl 文档**逐字一致**。
- 抓的 bug：thinking 编码错（§3）、Anthropic 缺 signature、base-path 错。
- 现状：**一个都没有**。`*_test.go` 里只有"marshal 再 unmarshal 回结构体断言几个字段"，不钉字节、且只覆盖 OpenAI+Anthropic（其余 7 家共用 `buildOpenAIBody`、零 per-provider 断言）。
- seam 现成：`buildOpenAIBody`/`buildAnthropicBody` 是包内可调的未导出函数。

### L2 — httptest 回环（覆盖响应侧 + base-url 拼装）
起本地 `httptest.Server` 返回各家**响应**形状（含 reasoning/thinking delta、Anthropic signature_delta），把 `Request.BaseURL`(llm.go:113) 指过去，断言解析正确。
- 抓的 bug：Gemini base-url 拼错（会打到错路径）、Ollama base-path、响应字段不匹配（Ollama 的 `reasoning` vs `reasoning_content`）。
- seam 现成：`Request.BaseURL` 可覆盖（`WithFakeLLMBaseURL` 已在用）；缺口：外部包无法注入 `http.Client`（私有字段），故这类测试宜放 `package llm` 内。

### L3 — Ollama 本地真 e2e（唯一真飞一次，零成本）
Ollama 免费本地、无需 key。`base_url=http://localhost:11434/v1`，gate 在 `/api/tags` 可达 + 已 pull 一个 model（否则 `t.Skip`，遵 T3）。用带工具的 model 还能顺带覆盖 `parseOpenAINonStreaming`（DisableStream 路径，其他 live provider 很少走到）。
- 注意：因 B2，Ollama 的 app `:test` 在 `…/v1` 下会假报失败，故 smoke test 应直接调 LLM 客户端、不走 `apikey :test`。

---

## §6 thinking 开关功能要动什么（待 spec 细化）

1. **意图层**：`Request`(llm.go:110) 加 provider 中立字段——`ThinkingMode {auto|on|off}` + 可选 `ReasoningEffort/Budget`。
2. **序列化层**：各 `Adapter.BeforeRequest` 把意图翻译成 §3 的对应形状（A–F）；`buildOpenAIBody` 需能拿到 provider（或由 adapter 直接 stamp 字段到扩展过的 Request）。Anthropic 走 `buildAnthropicBody` 加 `thinking` 对象 + signature 全链路。
3. **约束守卫**：Qwen 的 `enable_thinking=true` 强制 stream（与 `DisableStream` 冲突时须置 false）；Anthropic budget < max_tokens 且 ≥1024 且省略 temperature；OpenAI 推理模型用 `max_completion_tokens`。
4. **配置层（开放设计问题，留给 spec）**：用户的 thinking 选择存在哪？
   - 选项：① 挂在 model-config（每 scenario 一个 thinking 默认）；② 挂在 conversation（每对话临时切）；③ 引入"model 能力目录"（哪些 model 支持 thinking、默认开关），因为现在 modelId 是 `/models` 来的自由字符串、无任何能力元数据。
   - 这决定 UI 怎么露（model picker 旁一个 thinking 开关？还是 scenario 卡片里？）。

---

## 参考来源（各 provider 官方文档）
- OpenAI reasoning：learn.microsoft.com/azure/foundry/openai/how-to/reasoning · developers.openai.com/api/docs/guides/reasoning
- DeepSeek：api-docs.deepseek.com/guides/reasoning_model · /guides/thinking_mode
- Anthropic：platform.claude.com/docs/build-with-claude/extended-thinking · /api/models-list
- Gemini：ai.google.dev/gemini-api/docs/openai · /docs/thinking
- Qwen：alibabacloud.com/help/model-studio/deep-thinking · /compatibility-of-openai-with-dashscope
- Zhipu：docs.bigmodel.cn/cn/guide/capabilities/thinking
- Moonshot：platform.kimi.ai/docs/guide/use-kimi-k2-thinking-model
- Doubao：doc.dmxapi.com/thinking-doubao.html（Ark 思考参数）
- OpenRouter：openrouter.ai/docs/guides/best-practices/reasoning-tokens
- Ollama：docs.ollama.com/api/openai-compatibility · github.com/ollama/ollama/issues/15029 · /14820
