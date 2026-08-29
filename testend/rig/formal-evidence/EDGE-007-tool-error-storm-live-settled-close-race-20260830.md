# EDGE-007 · 工具错误风暴与 settled close 竞态（2026-08-30）

## 结论

本轮真实 session 证明了 loop 业务失败归类修复有效，也暴露并修复了第二个前端竞态；本文件是红证据与修复记录，不是正式通过凭证。正式 pass 必须来自重建前端后的新 clean session。

## 复现事实

- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-012238`
- 数据目录：`/private/tmp/anselm-data-edge007-20260830-r4`
- workspace：`ws_6cde3d288873d0e1`
- conversation：`cv_0bc20b1f736b8ab2`
- 真实 fixture：`edge007r4`，函数执行故意抛出 `EDGE007 deliberate tool failure`
- 真实 App 依次执行 nonce `601`、`602`、`603`；三次调用均独立进入 ReAct step，第三次后后端落 `TOOL_ERROR_STORM`
- SQLite：`integrity_check=ok`；assistant 为 `status=error`、`stop_reason=error`、`error_code=TOOL_ERROR_STORM`；三张 tool_result 为 `status=error` 且 error 非空
- SSE：messages durable `seq=1..64` 连续无 gap；最终 `message close` 携带 `TOOL_ERROR_STORM`
- LLM tap：challenge/install/models 与全部 completion 均为 HTTP `200`
- 录屏：`screen.mov` `512.706667s`、`3016x1756`、`60fps`

## 红点

REST 水化已将 assistant 根节点放入 `settled` 后，迟到的 durable `message_stop` 为避免重复渲染被整体跳过。结果是数据库已有终态、SSE 也已收到终态，但 live transcript 没有即时显示“tools kept failing...”终态提示；这是数据已真而用户界面暂时不真，不能通过。

## 修复

`ConversationTranscript.applyFrame` 对已经存在于 `settled` 的 message 根只合并 durable close 的 `status`、`error` 和 `result.content`，不创建 live duplicate；其它 settled block 仍保持不重建规则。新增 `conversation_transcript_test.dart` 回归覆盖该竞态。

## 观察边界

本 session 初期曾有一轮错误输入实验，产生 `function not found` backend warning，故不作为 clean formal pass。所有正式结论均以后续重建 App 的新 session 为准。
