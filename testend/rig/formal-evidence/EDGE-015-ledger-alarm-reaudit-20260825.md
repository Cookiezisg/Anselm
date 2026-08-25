# EDGE-015 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-015 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- loop 回归使用真实 MCP 混合结果形状 `[image: image/png]` 加嵌入 JSON receipt，确认合法 attachment
  到达正确 producing tool call 分组；mediaref 既有回归继续拒绝伪造 id、去重并封顶。
- 普通 loop/mediaref suite 与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 保持显式 `na`：本条没有独立真实 MCP/gateway 五通道 session、帧时延、视觉 surface 或用户
  导航入口，不将内部解析测试冒充产品绿证据。

## Resolution

两条警报仅针对 EDGE-015 写账窗口独立复审后销账，后续 drift detector 保持启用。
