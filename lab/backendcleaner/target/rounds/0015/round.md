# Round 0015 — infra/llm 核心框架 + openai（波次 0 · M0.6）

类型 / 目标：infra/llm 第一轮——搬框架（Provider 抽象 + 共享传输 + 中立类型 + factory + mock）+ 代表 provider openai。R0016 补其余 10 家。

考古结论（M0.6 全貌）：18 源 + 17 测试 ~11600 行。**零 domain 依赖、零外部 SDK**，纯标准库手写各家 wire。两接口撑起：`Client.Stream → iter.Seq[StreamEvent]`（provider 无关）+ `Provider`（BuildRequest/ParseStream wire 方言）。`providerClient` 跑共享铁律。11 provider（8 OpenAI-compat + anthropic + gemini）。

关键设计决策：
- **每家 provider 完整自包含 wire（作者拍板）**：不提取 oaicompat 共享基座。8 家 OpenAI-compat 看似共享 `toOpenAIMsgs`/oai 类型/emitChunk，但 wire 是各自独立演化的外部现实——强行 DRY 会让「加某家特性」变成共享代码 `if provider==x` 分支 + golden 互相牵连。**duplication < wrong abstraction**。openai.go 完整自含；R0016 每家各写各的（即使重复）。
- **共享边界**：仅「非 wire 方言」共享——协议机制（http client / `scanSSELines` / `providerClient` 铁律）+ 中立类型（StreamEvent/Request/LLMMessage）+ HTTP status 映射（`classifyHTTPError`）+ 消息配对（`SanitizeMessages`，旧代码 11 家含 anthropic/gemini 全调 → 真中立）。
- **error 内聚 domain/errors**：5 sentinel（Auth/RateLimited/BadRequest/ModelNotFound/ProviderError）会上 HTTP，从标准库升结构化（KindUnauthorized/RateLimited/Invalid/NotFound/BadGateway）。infra/llm 首次 import domain/errors（DIP 合理）。守则入 CLAUDE.md（S20）。
- **`classifyHTTPError` 从 openai.go 提到 transport.go**（HTTP status 通用，非 wire）。

落地（8 源 + 6 测试）：
- 框架：`llm.go`(类型+Generate/retry) · `transport.go`(http client+scanSSELines+doRequest+classifyHTTPError) · `sanitizer.go` · `mock.go`(T6 fake_llm) · `provider.go`(Provider 接口+providerClient 铁律+idle 超时+registry) · `factory.go`(Build，去 tracer)。
- provider：`openai.go` 完整自包含（BuildRequest+ParseStream+wire 类型+msg 编码+chunk 解析）。
- 清理：删死代码 `parseOpenAISSE`/`buildOpenAIBody`；`deepseekMapEffort` 留 R0016 deepseek；去 openai.go 里 Qwen flat-error / Ollama `reasoning` 字段（各家自处理）；strip TE-xx/03 §x/P3 历史叙述；`for→range` / `slices.Contains` 现代化。
- **trace.go 推迟**：`recordingClient` 依赖 `reqctx.GetConversationID`（随 chat/loop M5.2 重建）+ dev tracing（M7.2 判去留）。factory 去 tracer 钩子。

测试（`-race` 绿）：openai BuildRequest(body/headers/reasoning_effort/clamp) + ParseStream(SSE→events) + 非流式；classifyHTTPError(7 status→sentinel) + scanSSELines([DONE]/注释/早停)；withRetry(重试/不重试/耗尽/ctx cancel) + isRetryable；SanitizeMessages(配对/孤儿 stub/stray 丢)；MockClient(FIFO/空队列/ErrAfter)；factory(mock 短路/默认 baseurl/未知回落/显式 url) + providerClient 端到端 httptest(SSE→text / 401→ErrAuthFailed)。

验证：`gofmt -l` 空 / `go build ./...` / `go vet` / `go test -race` 全绿。

覆盖状态：infra/llm 框架 + openai 完成。R0016：deepseek/qwen/zhipu/moonshot/doubao/openrouter/ollama/custom（8 家各自完整 OpenAI-compat）+ anthropic + gemini（原生方言）+ 各家 golden，逐家加 registry。trace 随 M5.2/M7。

下一步：R0016 其余 10 provider（按方言分批：anthropic/gemini 原生 → 8 家 OpenAI-compat 各自完整）。
