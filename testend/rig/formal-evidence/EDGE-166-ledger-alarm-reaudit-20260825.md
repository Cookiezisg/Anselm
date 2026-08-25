# EDGE-166 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口发出间隔/无 fail 分布警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-166-mcp-oauth-refresh-revoked-20260825.md`。
- 复审结论：新增真实 401/invalid_grant revoked endpoint 回归通过，正常轮换和无 refresh 负边界也
  通过；`ErrOAuthReauthRequired` 与证据匹配，没有假成功或未授权 fallback。L2-L5 的 na 边界明确。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
