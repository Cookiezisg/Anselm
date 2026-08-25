# EDGE-192 ledger alarm re-audit

- 触发：EDGE-192 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-192-attachment-unsupported-mime-20260826.md`。
- 复审结论：不支持 MIME 的 focused short-circuit、真实 ODT 聊天降级、原始字节不泄漏和 completed
  终态均有对应证据；L2-L5 明确保持 `na`，没有把 testend 黑盒当成 App 五通道绿。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
