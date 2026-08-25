# EDGE-168 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-168-mcp-tenant-url-template-20260825.md`。
- 复审结论：目录契约和真实 `InstallFromRegistry` OAuth 路径均通过；展开后的 URL 同时出现在
  persisted server URL 与 OAuth resource，L2-L5 的 `na` 边界明确，没有把受控 server 冒充真实
  第三方浏览器或 App 视觉证据。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
