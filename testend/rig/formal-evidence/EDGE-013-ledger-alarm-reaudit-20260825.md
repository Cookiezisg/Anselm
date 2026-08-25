# EDGE-013 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-013 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- 公共 `ObjectMap` 回归确认原生 object 与 JSON 字符串承载的同一 object 解码结果一致；数组、数字、
  普通非 JSON 字符串和字符串化数组均拒绝，没有把错误值猜成 object。
- focused tool suite 与 `go test -race` 均通过；没有发现需要 stop-and-fix 的实现红线。
- L2-L5 的 `na` 是适用性边界，不是缺证据冒充通过：本条没有独立真实五通道 session、帧时延、视觉
  或用户导航表面。

## Resolution

两条警报仅针对 EDGE-013 写账窗口独立复审后销账，后续 drift detector 保持启用。
