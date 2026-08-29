# EDGE-332 · 账本与统计警报独立复核

## 复核对象

- 新增裁决：`EDGE|MCP 面板帧不可信|L2|pass|G2`
- 真实 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-025843`
- 证据：`EDGE-332-mcp-frame-coalescing-real-app-20260828.md`

## 复核结论

- 410 重同步发生在 MCP provider 已建立之后，代理日志和 backend 名册 GET 时间点相互吻合。
- 4 次 MCP 生命周期动作在约 100ms 内产生密集 entities 帧，backend 只新增 1 次合并后的名册 GET；
  删除后又新增 1 次重取并收敛为空态，非按帧请求。
- `rig-check`、录屏、三路 SSE、backend、frontend console 和 llmtap 均有同一 session 的归属证据。

## 警报处置

- `pass-burst`：本格经历真实 410 延迟构造、真实状态帧突发和收台检查，未使用批量 judge 或省略通道；已 ack。
- `discovery-collapse`：统计窗口没有 fail，但本轮保留并审阅了上一红场记录、真实 410 与状态帧对抗路径；
  覆盖和 stop-and-fix 标准未放宽，已 ack。

未修改警报阈值、算法或历史 journal；ack 后必须由 `alarms.py check` 得到 clean。
