# EDGE-191 ledger alarm re-audit

- 触发：EDGE-191 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或
  `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-191-attachment-sandbox-docx-20260826.md`。
- 复审结论：DOCX 真实 sandbox 抽取、LLM wire 注入、400K rune 头部截断和 ODT 诚实降级均有对应
  回归证据；L2-L5 明确保持 `na`，未把 testend 黑箱证据冒充五通道产品验收。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
