# EDGE-175 L5 账本与警报独立复核

- 复核日期：2026-08-30
- 目标：`EDGE|MCP 失败附 stderr 尾|L5`
- 主证据：`EDGE-175-mcp-stderr-tail-l5-real-app-history-20260830.md`
- 台架会话：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-204436`
- 规则：`CODEX G1`

## 独立复核

- 主证据文件存在且非空，且明确记录真实 App、画面、后端 journal、SSE tap、前端 console、LLM wire 五通道。
- `rig-check.sh` 在会话收尾前通过五通道归属检查；`rig-down.sh` 后没有遗留本次台架进程。
- SSE 与后端交叉核对：首轮只有一条真实 `mcp__edge175__crash_with_stderr` 失败调用；第二轮是 `search_mcp_calls` 后接 `get_mcp_call`，没有重复执行动态 MCP 工具。
- 画面交叉核对：详情区显示 `logs · 102 lines`，并显示 `server-level` 与 `may predate this call` 边界；右侧仍保留失败工具卡。
- LLM wire 交叉核对：第二轮实际按“搜索失败记录 → 读取完整记录”执行，结果使用持久化日志，不是凭直接 tool result 猜测。
- 本次通过没有改变任何 CODEX 法条、统计阈值、判定语义或旧红证据；旧的 L5 红证据仍保留在 `EDGE-175-mcp-stderr-tail-l5-red-20260830.md`。

## 警报处置

`discovery-collapse` 的触发原因是近 50 裁决 fail share 为 4.0%，不是本格证据缺失。该比例来自先前真实缺陷被保留在账本中的 fail 记录；本格的新 PASS 有独立真实 App 证据，不能被同一批历史红结果否决。按既定机制完成独立复核后允许 ack，未调整阈值。

## 结论

**复核通过，允许 ack `discovery-collapse`。**
