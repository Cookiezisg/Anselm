# EDGE-012 ledger/alarm re-audit · 2026-08-25

## Trigger

EDGE-012 五个层级写入后，统计窗口打开 `gap-too-fast` 与 `discovery-collapse`，未打开
`pass-burst`。本复审不改变 detector、阈值、法典、锚点或 sequence gate。

## Evidence review

- `StripStandardFields` 的现有回归确认 `none`/其它非法值和缺失 `danger` 均回落 `safe`；
  静态 `DangerFloorer` 回归确认不可绕过的危险 floor 仍会开启人闸。
- 普通 focused tool/loop suite 和 `go test -race` 均通过；没有发现需 stop-and-fix 的实现红线。
- L2-L5 的 `na` 是适用性边界，不是缺证据冒充通过：本条没有独立真实五通道 session、帧时延、视觉
  或用户导航表面。

## Resolution

两条警报仅针对 EDGE-012 写账窗口独立复审后销账，后续 drift detector 保持启用。
