# EDGE-195 ledger alarm re-audit

- 触发：EDGE-195 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-195-attachment-undeliverable-format-20260826.md`。
- 复审结论：HEIC MIME 点名降级、网关上传前拦截和整轮不失败由 focused 回归覆盖；未执行正式受管
  五通道，L2-L5 明确保持 `na`。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
