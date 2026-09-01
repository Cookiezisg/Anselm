# EDGE-331 L4 账本警报独立复审

- alarm: `discovery-collapse`
- product session: `/private/tmp/anselm-rig-formal-20260901-14/sessions/20260901-233914`
- judgment under review: `EDGE|限额面板载入失败|L4|pass|C4`

## Independent checks

- L4 只复核视觉成品，不把 L3 的时延数字或 L5 的入口理解复用为视觉证据。错误态和恢复态的代表帧、
  原生录屏及 60fps 抽帧已逐帧检查：层级、圆角、行高、导航位置和恢复后的字段布局保持一致。
- 恢复过程中没有灰屏、重叠、文字截断、旧面板残留、白闪或持续 reflow；`measure diff` 的变化 bbox
  均在中心内容面板，稳定尾段没有超过阈值的非用户变化。
- backend `431` 行、SSE 三流、frontend console、LLM wire 和 app proxy 均与 L3 同一真实 session
  对账；proxy 的一次故障和一次 forward 与画面顺序一致，`rig-check`/`rig-down` 均通过。
- anchors `10/10`，CODEX 的 C4 未改，清册生成检查不变；警报仍只是近窗口 0% fail-share 的统计信号。

## Resolution

L4 视觉证据独立成立，统计警报没有提供降低 C4 标准的理由。未修改阈值、算法、法典、锚点、顺序门或
verdict，允许按原规则 ack；后续真实 fail 仍必须重新打开警报。
