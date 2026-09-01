# EDGE-174 L3 · 账本告警独立复审

- 复审对象：`discovery-collapse`
- 触发原因：本次 L3 写账后，最近 50 个裁决的 fail share 为 `0.0%`，低于既定
  `5%` 下限。
- 复审 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`
- 复审证据：`EDGE-174-mcp-progress-correlation-l3-real-app-20260830.md`

## 复审结论

本次新增裁决有完整的真实 App 五通道证据，并且 L3 使用的 `B2` 已存在于
`CODEX.md`。原始 `screen.mov`、backend journal、三路 SSE、frontend log 和
managed LLM wire 均来自同一封存 manifest；测量命令和稳定尾段结果已写入正式证据。

复审没有修改告警阈值、统计窗口、法典、锚点集合或顺序门。`discovery-collapse`
在现有证据充分、且没有发现判断系统失灵的情况下按原规则 ack；后续裁决仍会重新
计算该曲线，若再次越界会重新打开告警。
