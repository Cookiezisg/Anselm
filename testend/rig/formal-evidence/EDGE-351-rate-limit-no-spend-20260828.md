# EDGE-351 429 不动钱 · 真实 App 五通道实证

- **判定**：L2 `pass`。
- **真实路径**：正式 conductor 启动真实 macOS App、sidecar、三路 SSE、llmtap 与窗口录屏；受控上游对 `/v1/chat/completions` 每次返回 HTTP `429`，结构化码为 `RATE_LIMITED`，不返回配额耗尽码。
- **用户目的**：在新对话发送 `rate limit quota test`，遇到暂时限流时知道发生了什么、知道下一步，且不被误报为额度耗尽；Composer 收口回发送态。
- **产品结果**：App 只展示“模型服务暂时繁忙，请稍后重试。”，不展示 `LLM_RATE_LIMITED`、`429` 或上游原文；错误下方保留可见的 `重试` 操作。首轮旧二进制曾展示内部诊断串，已 stop-and-fix 并重建 App 后复验通过。
- **配额不变**：发送前与发送后均通过 `GET /api/v1/freetier/quota` 读取完全相同快照：`limit=10000, used=1234, remaining=8766, resetAt=2099-01-01T00:00:00Z, available=true`。
- **LLM 线缆**：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-011403`；llmtap 记录 4 次 `/v1/chat/completions`，状态全部 `429`（首请求 + 3 次退避重试），没有成功响应、usage 或生成调用。
- **SSE 真相**：messages 流记录 user `close=completed`，assistant `close=error`，`errorCode=LLM_RATE_LIMITED`、`inputTokens=0`、`outputTokens=0`；durable seq `1..4` 单调，notifications 随后记录自动标题，未伪造成功终态。
- **五通道**：`rig-check` 通过；录屏 `77.245000s` 且 `ffprobe` 可读；backend 无应用 `WARN/ERROR/panic/FATAL`；frontend 无 Flutter/Dart/RenderFlex/RenderBox/Unhandled/PlatformException 红线（仅一条 macOS IMK 宿主警告，已确认非 Flutter 运行时错误）；ssetap 三流均连接并记录上述帧；llmtap 记录 challenge/quota 与 4 次 429。
- **回归**：`mise exec -- flutter test test/features/chat/ui/chat_transcript_test.dart`（34/34）；`go test ./internal/infra/llm ./internal/app/loop` 既有分类/重试回归通过；`gen_coverage.py --check` 与 `git diff --check` 通过。
- **法条**：E1、F1、F2、F3、F4。

L3（顺滑）、L4（独立视觉 craft）、L5（可发现性）本次不判定；这是受控上游限流路径，不能把一次错误收口冒充完整自然旅程。
