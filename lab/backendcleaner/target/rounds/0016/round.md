# Round 0016 — infra/llm 其余 provider（波次 0 · M0.6）【进行中】

类型 / 目标：R0015 框架之上逐家移植其余 10 provider，**每家完整自包含 wire（不共享基座）**。逐家加 registry，各家测试随附。

进度（11 provider 总）：
- ✅ **openai**（R0015）
- ✅ **anthropic** — 原生方言：`/v1/messages`、x-api-key、**命名事件 SSE**（不能用 scanSSELines，自己 bufio 扫 `event:`+`data:`）、thinking budget + **signature round-trip**、cache_control 断点、block-form messages。去 `modelcatalog` 依赖（max_tokens 改 `Request.MaxTokens`，caller 从 catalog 填）；去 `slog`（malformed 历史 args 静默 fallback `{}`）；strip TE-25/03 §4 历史。
- ⬜ **gemini**（原生 generateContent）
- ⬜ **deepseek / qwen / zhipu / moonshot / doubao / openrouter / ollama / custom**（8 家 OpenAI-compat，各自完整）

每家通用动作：strip 历史叙述、error 内聚 `domain/errors` sentinel、各家 wire 类型/msg 编码/chunk 解析自包含、注册 registry、单元/golden 测试。

设计连带（R0016 引入）：
- **`Request.MaxTokens` 字段**（caller 从 catalog 派生填入；provider 不读 catalog）——anthropic max_tokens 用，**去除 infra/llm → modelcatalog 依赖**（保持零 domain 依赖）。caller 填 → deps-todo。
- `lookupProvider` 恢复 `custom`+`anthropic-compatible` → anthropic 路由。

验证（累计）：`gofmt -l` 空 / `go build ./...` / `go vet` / `go test` 全绿。

下一步：gemini（原生方言），然后 8 家 OpenAI-compat（各自完整）。
