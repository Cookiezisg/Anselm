# Round 0016 — infra/llm 其余 10 provider（波次 0 · M0.6）

类型 / 目标：R0015 框架之上逐家移植其余 10 provider，**每家完整自包含 wire（不共享基座）**。逐家加 registry，各家测试随附。M0.6 由此收官（11 家 provider）。

进度（11 provider 全完成）：
- ✅ **openai**（R0015，框架代表）
- ✅ **anthropic** — 原生方言：/v1/messages、x-api-key、命名事件 SSE、thinking budget + signature round-trip、cache_control、block-form messages。
- ✅ **gemini** — 原生 generateContent：model-in-path、x-goog-api-key、thought parts + thoughtSignature round-trip、functionCall/Response。
- ✅ **deepseek** — OpenAI-compat 自包含模板：reasoning_content round-trip + thinking enabled+effort/disabled。
- ✅ **qwen** — `enable_thinking` *bool + `thinking_budget`；扁平错误信封（顶层 code/message）；非流式关 thinking 避 400。
- ✅ **zhipu** — `thinking:{type}`；`tool_choice` 仅 "auto"；不回传 assistant reasoning_content（无 round-trip，发了 400）。
- ✅ **moonshot** — `thinking:{type}`；reasoning_content；无 max_tokens。
- ✅ **doubao** — `thinking:{type:enabled|disabled}` + `budget_tokens`。
- ✅ **openrouter** — `reasoning:{effort|max_tokens}`；流中 error 对象 surface。
- ✅ **ollama** — `reasoning_effort`；有 tools 强制非流式（绕 bug）；`delta.reasoning`（无下划线）。
- ✅ **custom** — 纯 OpenAI-compat，**无 thinking**（通用端点不认识的字段会 400）。

每家自包含：自己前缀的 wire 类型 + msg 编码 + tool-state；不借 openai(`oai*`)/deepseek(`ds*`)；error 用包内 sentinel；去 modelcatalog（→`Request.MaxTokens`）/slog（malformed args 静默 fallback）；strip 历史叙述；注释双语 Why-only。

**后 7 家（qwen…custom）经 workflow 并行生成**：7 agent（~424k token / 90 tool-use / ~5min），每 agent 读自己旧文件 + deepseek 模板，写自包含 provider + 测试、各自 gofmt，不碰 registry（避并发冲突）。

收尾（主 loop 统一）：加 registry 11 条 + `lookupProvider` 恢复 `custom`+`anthropic-compatible` → anthropic 路由；全量 `gofmt -l` 空 / `go build ./...` / `go vet` / **`go test -race`** 全绿；**合规 grep**（7 家无禁用 import modelcatalog/slog/domain-errors、无 `errors.New`、无跨借用 `oai*`·`ds*`·`toOpenAIMsgs`·`toolCallState`、无 TE-/03§/P3/V1.2 历史叙述）全净；抽查 ollama tools→关流、custom 无 thinking、各家 `Name()` 值匹配 registry key。

设计连带（R0016 引入）：
- **`Request.MaxTokens` 字段**（caller 从 catalog 派生填；provider 不读 catalog）——anthropic/gemini 用，去除 infra/llm → modelcatalog 依赖。
- `lookupProvider` 恢复 `custom`+`anthropic-compatible` → anthropic 路由。

覆盖状态：infra/llm 11 家 provider 全完成（17 源 + 16 测试）。trace（dev tracing，依赖 conv-ctx）随 M5.2/M7；pkg llmclient/llmcost/llmparse 随业务；caller 填 `Request.MaxTokens` 随业务接线。

**M0.6 完成。** 下一步：M0.7 transport 框架。
