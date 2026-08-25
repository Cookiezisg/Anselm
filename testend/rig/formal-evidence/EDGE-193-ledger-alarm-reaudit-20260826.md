# EDGE-193 ledger alarm re-audit

- 触发：EDGE-193 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-193-attachment-no-vision-degrade-20260826.md`。
- 复审结论：focused 图片降级、真实 provider user-content wire、图片字节不出线和附件可下载均有
  对应证据；L2-L5 明确保持 `na`，没有把 mock 黑盒误写成视觉产品绿。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
