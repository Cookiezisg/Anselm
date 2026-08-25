# EDGE-198 ledger alarm re-audit

- 触发：EDGE-198 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-198-attachment-staging-failure-20260826.md`。
- 复审结论：uploader error、chat history error propagation、loop error finalization 和 terminal frame 均由
  focused 回归覆盖；没有当前独立 managed 五通道录制，L2-L5 明确保持 `na`。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
