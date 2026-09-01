# EDGE-189 账本告警复审

- **告警：** `discovery-collapse`
- **结论：** 复审通过，告警为统计保护动作，不是放宽质量标准的理由
- **触发事实：** 最近 50 条 live judgment 中 2 条为 fail，fail share 为 4.0%，低于既定 5% floor
- **复审时间：** 2026-08-31

## 复审动作

1. 独立读取 `~/.anselm-rig-formal-20260801-7/judgments.jsonl` 的最近窗口，确认触发是新增 `EDGE|Changed 队满丢事件 L2` 后的统计结果，而非清理、覆盖或重写历史判断。
2. 重新读取并核对本次真实 session `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-002700`：1500 个文档 HTTP 201、435 条真实队列溢出 journal、硬崩重启后的数据库 3000 个相关 chunk、三条 SSE 重连、LLM wire 200 响应，以及真实 App 读出 `EDGE189 live recovery sentinel 1499`。
3. 复核最近两个 fail：`MCP 进度关联 L5` 与 `首用下载途中关停 L3` 均有具体 red evidence，分别代表真实发现与真实体验缺陷，不是误报或可删除的坏数据；其后已有对应修复/重测记录。
4. 未修改 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、判断标准、CODEX 法条、anchors 或 ledger sequence；仅以本复审记录 ack 当前告警。

## 复审结论

本次 `discovery-collapse` 的保护意义成立：它阻止在发现率偏低的窗口继续橡皮章式入账。当前窗口中的低 fail share 由真实修复后的通过与已保留的真实失败共同产生；EDGE-189 L2 的证据完整且可重放，因此允许在复审后继续，后续任何新证据仍会重新触发既有曲线。
