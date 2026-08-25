# EDGE-161 ledger alarm re-audit

- 触发：本格按协议连续写入 L1 与 L2-L5 五格，近 50 格间隔中位数落为 `0s`；本格没有 fail
  verdict，触发 `gap-too-fast` 与 `discovery-collapse`。
- 复审对象：`EDGE-161 subagent 墙钟` 的正式证据
  `testend/rig/formal-evidence/EDGE-161-subagent-wall-clock-20260825.md`。
- 复审结论：focused `TestSpawn_WallClockTimeout` 和真实 HTTP `TestChatR3_SubagentNestedTree`
  均已独立完成并通过；L1 的 `measure:edge161-subagent-wall-clock` 与证据匹配。L2-L5 的 `na`
  有明确边界理由，未将 HTTP harness 当作 Computer Use/视觉/可发现性证据。没有发现漏记 fail、
  复制旧证据或凭空升格。
- 处置：两条警报仅反映账本写入节奏和本格裁决分布；不改算法、阈值、法典或锚点，保留原始警报
  后按本复审记录串行 ack。
