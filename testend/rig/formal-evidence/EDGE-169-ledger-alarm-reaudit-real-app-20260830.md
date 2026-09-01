# EDGE-169 账本统计告警独立复审

- 复审对象：`EDGE-169|MCP degraded 态` L2 的真实 App 裁决，正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-173628`。
- `gap-too-fast` 的触发原因是本次单个 L2 裁决写入很快；但它的证据已由 `rig-check.sh`、封存录屏、backend journal、三路 SSE、frontend console 和 managed LLM wire 五通道交叉核验，且 screen.mov 已由 ffprobe 读出 `3104x1844 / 60fps / 122.45s`。没有用告警阈值替代证据，也没有修改阈值。
- `discovery-collapse` 的触发原因是近尾 50 个判断没有 fail；本次复审重新核对红线扫描、真实 `MCP_RPC_ERROR` 三次失败、`ready→degraded→ready` 状态信号以及恢复调用，确认这是样本形态而不是跳过失败路径。没有修改发现率门禁、法典、锚点或顺序门。
- 复审结论：两项告警均可按原阈值 ack；本文件只记录原因与证据，不为任何额外 COVERAGE 单元提供通过依据。
