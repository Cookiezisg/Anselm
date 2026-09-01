# EDGE-189 L3 账本告警复审

- **告警：** `discovery-collapse`
- **触发：** 最近 50 条 live judgment 中 2 条 fail，fail share=`4.0%`，低于既定 `5%` floor
- **结论：** 复审通过，允许保留 EDGE-189 L3 判断并继续

## 独立核对

- 重新读取 EDGE-189 L3 正式 session 的 `screen.mov` 与 evidence：发送后的真实 App 画面出现 `thinking`、`Searched document`、`Searched tools`、`Read document` 进度行；长等待期间 Composer 仍在底部并显示停止控件，最终回答准确读出恢复后的文档哨兵。
- 重新读取同 session 的 SSE、LLM wire、backend 和 frontend journal，确认画面中的状态与同一回合的 durable tool-call/tool-result/close、真实 200 响应和后端健康相互对应。SIGKILL 造成的断线噪声已被明确披露，没有作为正常日志隐藏。
- 最近两条 fail（MCP 进度关联 L5、首用下载途中关停 L3）均有具体 red evidence，并保留了后续修复/重测历史；未删除、覆盖或改写失败事实。
- 未改变 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、三曲线算法、CODEX、anchors、五级标准或 ledger sequence；仅 ack 本次复审观察到的告警水位。
