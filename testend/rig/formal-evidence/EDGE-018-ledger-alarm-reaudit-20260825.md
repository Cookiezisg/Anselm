# EDGE-018 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-018 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- sanitizer 回归覆盖多调用批次：已完成 result 保留，取消 call 按原序补 interrupted stub，后续 user message
  不丢；单调用孤儿与 stray tool 路径也继续通过。
- 普通 llm suite、DeepSeek/Gemini 相关回归与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 保持显式 `na`：本条没有独立真实 managed gateway 五通道 session、取消帧时延、视觉 surface 或
  用户导航入口。

## Resolution

两条警报仅针对 EDGE-018 写账窗口独立复审后销账，后续 drift detector 保持启用。
