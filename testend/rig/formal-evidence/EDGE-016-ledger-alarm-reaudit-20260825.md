# EDGE-016 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-016 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- loop/mediaref 回归确认 `source=generate_image` 不触发 producer veto，生成 receipt 到达下一次 request，
  并且仍按 producing tool call 保持归属；ADR 0020 的策略与实现一致。
- 普通 focused loop/mediaref suite 与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 保持显式 `na`：本条没有独立真实生成/gateway 五通道 session、帧时延、视觉 surface 或用户导航
  入口，不将内部 policy 测试冒充产品绿证据。

## Resolution

两条警报仅针对 EDGE-016 写账窗口独立复审后销账，后续 drift detector 保持启用。
