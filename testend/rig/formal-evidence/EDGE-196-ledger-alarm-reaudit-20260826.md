# EDGE-196 ledger alarm re-audit

- 触发：EDGE-196 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-196-attachment-managed-media-lease-20260826.md`。
- 复审结论：resumable upload、device-proof audience、相对 lease path 和应用层绝对 URL 拒绝均由 focused
  回归覆盖；没有当前独立 managed 五通道录制，L2-L5 明确保持 `na`。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
