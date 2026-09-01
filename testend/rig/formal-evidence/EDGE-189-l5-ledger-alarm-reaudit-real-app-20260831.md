# EDGE-189 L5 账本告警复审

- **告警：** `discovery-collapse`
- **触发：** 最近 50 条 live judgment 中 2 条 fail，fail share=`4.0%`，低于既定 `5%` floor
- **结论：** 复审通过，允许保留 EDGE-189 L5 判断并继续

## 独立核对

- 重新查看真实 App 尾帧与 L5 evidence：用户从可见的 Chat、New chat、Composer 出发，以自然语言完成搜索和文档读取，不需知道工具名、命令、Settings、索引或对账实现；最终显示精确结果。
- 重新对照同 session 的 durable messages、LLM wire、backend journal 和 SSE 记录，确认 L5 画面对应真实恢复回合，而非仅由 fixture 或人工文案构成。
- 最近两条 fail 仍是有具体 red evidence 的真实历史，不因本次用户路径成功而删除、改判或隐藏；本次 L5 也没有把 L2/L3/L4 事实重复冒充为发现性证据。
- 未改变 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、告警算法、CODEX、anchors、五级标准或 ledger sequence；仅 ack 当前复审水位。
