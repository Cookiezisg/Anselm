# EDGE-020 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-020 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- loop gate 回归实际证明第一次 `(cv1, deploy)` 批准后第二次同键不再 surface；不同工具和不同会话仍各自
  需要批准。越界事实闸路径未被白名单覆盖。
- 普通 loop suite 与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 保持显式 `na`：本条没有独立真实 chat/gateway 五通道 session、interaction 帧、视觉 surface 或
  用户导航入口。

## Resolution

两条警报仅针对 EDGE-020 写账窗口独立复审后销账，后续 drift detector 保持启用。
