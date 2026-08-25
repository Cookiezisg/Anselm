# EDGE-199 ledger alarm re-audit

- 触发：EDGE-199 五项裁决连续写入，统计窗口可能触发 `gap-too-fast` 或 `discovery-collapse`。
- 复审对象：`testend/rig/formal-evidence/EDGE-199-attachment-proxy-not-ready-20260826.md`。
- 复审结论：bounded wait、原图 fallback、后台 worker 追上和 ready proxy staging 均由 focused 回归覆盖；
  没有当前独立 managed 五通道录制，L2-L5 明确保持 `na`。
- 处置：只按本复审记录串行 ack 统计警报；不改阈值、法典、锚点或覆盖边界。
