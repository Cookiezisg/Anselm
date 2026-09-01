# EDGE-174 L4 · 账本告警独立复审

- 复审对象：`discovery-collapse`
- 触发原因：本次 L4 写账后，最近 50 个裁决的 fail share 为 `0.0%`，低于既定
  `5%` 下限。
- 复审 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-181342`
- L4 证据：`EDGE-174-mcp-progress-correlation-l4-real-app-20260830.md`

## 复审结论

关键帧覆盖 progress live、双调用并列、settling 和完成态；C4 已存在于 CODEX，且
证据位于正式 session 内，未将 L2/L3 结论冒充视觉 craft。复审确认这是真实证据充分
后的低失败率，而非判断系统失灵。

本次没有修改告警阈值、统计窗口、法典、锚点集合或顺序门。按原规则 ack；后续
裁决仍重新计算该曲线，若失败率或其他曲线再次越界会重新打开告警。
