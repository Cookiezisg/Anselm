# EDGE-018 · sanitizer 孤儿 tool_call 补 stub

## Verification

发送 provider request 前，`SanitizeMessages` 维护 assistant `tool_calls` 与后续 tool messages 的配对：
已完成的 tool result 原样保留；被取消/缺失的 call 按 assistant 原始顺序补一个带 interrupted marker 的
stub；无对应 assistant 的 stray tool result 丢弃。该 sanitizer 在兼容 provider、Gemini 和 Anthropic
发送路径接入，避免严格 provider 因孤儿协议返回 400。

Focused verification passed:

```text
go test ./internal/infra/llm -run 'TestSanitizeMessages|TestDeepSeekReasoningRoundTrip|TestGemini' -count=1  PASS
go test -race ./internal/infra/llm -run 'TestSanitizeMessages' -count=1  PASS
```

新增多调用回归模拟一个 assistant 批次只完成第一个 tool、第二个被取消，断言真实结果不变、第二个按
原顺序补 stub、后续 user 消息保留；既有回归继续覆盖单调用孤儿与 stray tool 清理。

## Five-level applicability

- L1 `pass`: 取消后的 tool-call history 在发送前重新配对，严格 provider 不收到孤儿调用；测量法
  `measure:edge018-sanitizer-orphan-tool-call`。
- L2 `na`: 本轮未为 provider sanitizer 单独启动真实 managed gateway 五通道 session。
- L3 `na`: focused wire test 无真实 App 录屏、取消动作帧或响应时延数据。
- L4 `na`: 本条验证协议配对，不含独立视觉几何/动效 surface。
- L5 `na`: sanitizer 是内部 provider 兼容边界，不是用户可导航入口。
