# EDGE-175 MCP 失败附 stderr 尾：L5 真实 App 历史诊断

- 日期：2026-08-30
- 级别：L5（可发现性与产品完成度）
- 台架会话：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-204436`
- 数据目录：`/private/tmp/anselm-data-edge175-l5-historyfix-20260830`
- 工作区：`ws_e6db5e2ae6406cde`
- 规则：`CODEX G1`（能力与证据可发现；用户明确要求完整技术详情时，产品必须带用户到权威历史记录，而不是让用户猜）

## 用户目的

用户先要求真实 App 执行已连接的 `edge175/crash_with_stderr` 一次，接受其预期失败；随后要求查看“刚才失败的 MCP 调用”的完整详情，包含 server stderr tail，说明这是 server-level 诊断输出且可能早于本次调用，并明确要求不要再次执行工具。

## 真实 App 结果

首轮真实 App 只执行了一次动态工具调用。工具卡给出平静的人话失败摘要，原始错误留在可展开的 `Technical details` 中，右侧 Activity 同步显示失败工具与下一步提示。

第二轮没有重新执行 MCP 工具，而是展示了可追溯的历史调用详情面：

- 记录类型：`failed / crash_with_stderr / chat`
- 页面显示 `logs · 102 lines`，并提供日志代码块与复制入口
- 详情明确显示 `server-level` 与 `may predate this call`
- 详情给出 stderr 尾部的范围、行数和原始日志字段的权威来源
- 详情中包含 `EDGE175L5DETAIL`

画面还保留右侧 Activity 的原始失败工具卡，中心详情与工具卡职责分离，没有重复发起调用。

## 五通道证据

1. **画面/帧**：`screen.mov` 已由 Anselm-window recorder 录制，时长约 177 秒；画面检查确认中心详情页、102 行日志入口、stderr 说明和右侧失败 Activity 同时可见。
2. **后端 journal**：`backend.log` 只出现一条 `mcp__edge175__crash_with_stderr` 的真实执行失败；详情查询没有执行第二次动态 MCP 工具。
3. **SSE tap**：`sse.jsonl` 记录第二轮依次发出 `search_mcp_calls`（`limit=1`、同 server、同 tool、`status=failed`）与 `get_mcp_call`，随后收到持久化 `logs`，未出现第二个动态工具调用。
4. **前端 console**：`frontend.log` 仅有 macOS IMK 环境诊断，没有 Flutter/Dart exception、RenderFlex overflow、Unhandled 或布局错误。
5. **LLM wire**：`llm.jsonl` 完整记录真实 App 通过 `llmtap` 发出的请求与响应；第二轮模型先取失败记录，再取完整调用记录，响应中保留 `server-level` / `may predate this call` 语义，并未将诊断请求改写成再次执行。

## 台架完整性

`rig-check.sh` 在收尾前通过：backend 端口归属、backend health、SSE tap、LLM tap、真实 App PID/窗口归属、屏幕录制区域与生命周期全部通过。随后 `rig-down.sh` 有序停止并保留全部 journal；会话没有遗留台架进程。

## 判定

**PASS**。用户从失败工具卡可以发现入口，在明确要求技术详情后能通过历史调用记录得到完整、可追溯且带边界说明的 stderr 诊断；系统没有重复执行失败工具，也没有把 server-level 历史日志伪装成此次调用必然产生的输出。
