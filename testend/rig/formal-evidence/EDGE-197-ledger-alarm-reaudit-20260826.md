# EDGE-197 ledger alarm re-audit

- 触发：EDGE-197 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-197-attachment-lease-refresh-20260826.md`。
- 复审结论：safety-window refresh、刷新字节不变、client 重启不复用内存 lease，以及 inspect_media 共用
  relative-path gate 均由 focused 回归覆盖；没有当前独立 managed 五通道录制，L2-L5 明确保持 `na`。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
