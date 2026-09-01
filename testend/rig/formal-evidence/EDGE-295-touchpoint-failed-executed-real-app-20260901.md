# EDGE-295 · 触点记真执行的失败 · 真实 App 收口

- 日期：2026-09-01
- 正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-134446`
- 修复前红证据：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-133209/evidence/EDGE-295-failure-raw-exception-red.jpeg`
- 修复后关键帧：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-134446/evidence/EDGE-295-failure-sanitized-real-app.jpeg`

## 场景与修复

在真实 App 中创建会主动抛出异常的 `edge295-failure` Function，用户要求只执行一次、预期失败，并询问执行历史位置。修复前，工具卡之外的助手正文复述了裸 `RuntimeError` 和 fixture 实现，违反 CODEX `E1`；修复后，loop 只在普通用户面折叠技术异常为「这一步执行失败，详细技术信息见下方执行记录」，而工具卡、durable SSE close、执行历史和 LLM wire 继续保留完整技术证据。用户明确索要原始错误/traceback 时不启用该折叠。

实现回归：`ToolError` 是 provider-agnostic LLM history 的内部投影标记，供应商序列化层不输出该字段；跨 UTF-8 provider chunk 的流式过滤与 durable close 均有单测。聚焦 ordinary 测试通过：`./internal/app/loop`、`./internal/app/chat`、`./internal/infra/llm`。

## 五通道证据

- 画面与录屏：修复后关键帧显示完整红色 traceback 仅位于失败工具卡；助手正文显示「函数已执行并如预期失败」及「这一步执行失败，详细技术信息见下方执行记录」，未出现 `RuntimeError`；Activity 显示 `1 touched · 1 executed`、`Failed` 和可检查错误提示。录屏已由 `rig-down.sh` 封口，时长约 142 秒。
- 后端：`backend.log` 有 Function 失败执行及正常 HTTP 记录，无 `WARN`、`ERROR`、panic 或 FATAL；失败执行仍产生执行历史事实。
- SSE：`sse.jsonl` 共 109 帧，messages/entities/notifications 三流均有连接；messages durable 序列连续推进至 25。tool_result close 保留 traceback，assistant text delta/close 只含收敛后的人话正文。
- 前端：`rig-check.sh` 五通道通过；无 Flutter/Dart/Unhandled/RenderFlex 错误，失败 Activity 行与工具卡状态一致。
- LLM wire：managed gateway challenge/install/models 与 3 次 chat completion 均返回 200。原始模型响应确实含裸异常，但该内容只在 loop 内部 raw 输入/工具结果观察面出现，发送给 App 的 messages delta 已确定性收敛；没有重试失败 Function。

## 级别裁决

- L1 `F1`：触点在失败工具真实执行后记录 `executed`，没有把失败误记为未发生。
- L2 `F1`：真实 App、managed gateway、五通道 session 均存在；工具卡、Activity 与执行记录一致。
- L3 `B2`：失败工具卡先完成、助手随后给出收敛摘要，失败行没有跳成成功或重复执行。
- L4 `C4`：技术细节集中在工具卡，助手正文保持短、稳定、可读；失败态色彩、层级与 Activity 红行一致。
- L5 `G1`：用户无需理解 Python 异常即可知道执行失败、详情在哪里；技术证据仍可从相邻工具卡和执行历史获得。

## 结论

修复前问题已 stop-and-fix 并由同一真实场景复验；修复后未发现新的产品问题。
