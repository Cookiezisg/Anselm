# EDGE-223 | 视频轮询超时诚实话：真实 App 证据

## 判定

本证据覆盖同一真实 App session 的五级产品验收：

- L2 `pass`，法条 `F2`
- L3 `pass`，法条 `A4`
- L4 `pass`，法条 `C4`
- L5 `pass`，法条 `G1`

L1 的 focused backend 回归证据仍由既有
`testend/rig/formal-evidence/EDGE-223-video-poll-timeout-20260826.md` 承载；本次不以本地
回归替代真实产品证据。

## 真实场景

- session：`/private/tmp/anselm-rig-formal-20260905-edge236d/sessions/20260905-054731`
- 真实 macOS App PID：`84401`；真实 sidecar：`83633`；SSE witness：`83775`；LLM tap：`83585`
- 录屏：`232.861667s`，由 conductor-owned recorder 封口
- 真实受管 Anselm gateway：`https://api.anselm.website`
- `ChatTurnSec=30`；用户请求模型只调用一次 `generate_video`
- operator 完成真实危险操作确认，HTTP 决议为 `204`

LLM tap 对真实请求只注入动态视频轮询的合法网关响应：真实 `POST /v1/videos/generations`
返回 `202` 并产生 opaque job；随后五次 `GET /v1/videos/<opaque-id>` 返回合法的
`{"status":"pending"}`。challenge、install、models 和 chat completions 均由真实受管网关
透明返回 `200`。故障只模拟“上游任务持续 pending”，没有把提交或其它模型请求替换成本地假结果。

## 用户可见结果

Computer Use 打开最终对话画面确认：

- 工具卡显示 `Generated video ... · failed`，不是成功产物或假进度百分比；
- 工具错误正文为“video generation failed: gave up waiting after 25s; the upstream job may
  still complete”，明确说明本地停止等待不等于上游任务被取消；
- 整体回合同时显示“本次回复耗时过长，为保持应用响应已停止；可发送后续消息或简化任务重试”；
- 画面没有 opaque job handle、裸异常、截断、重叠、卡死 Composer 或残留 generating 状态；
- Composer 在终态可继续输入，工具卡提供可发现的 `Retry` 动作。

## 五通道互证

- **Channel 1 / frame**：`screen.mov` 封口；最终帧由 Computer Use 逐帧核对上述错误卡、进度和
  Composer 可用性；`rig-check` 确认录制区域无外部窗口遮挡。
- **Channel 2 / backend**：backend journal 记录 `generate_video` 的预期失败，错误正文与
  SSE tool-result 一致；无 panic、FATAL 或未解释应用级错误。
- **Channel 3 / SSE**：messages durable close 帧单调，工具帧先以 `error` 收口，再以
  `CHAT_TURN_TIMEOUT` 的 assistant close 收口；close 快照没有把工具失败伪装为 cancelled。
- **Channel 4 / frontend**：frontend journal 无 Flutter、Dart、RenderFlex、Unhandled 或
  应用 Exception 红线；唯一 IMK 日志为已分类的 macOS 宿主诊断。
- **Channel 5 / LLM wire**：real gateway bootstrap/chat 全链路在 tap 上可见；submit=`202`，
  动态 poll 的五次 `pending` 注入与最终 UI 错误一一对应，job handle 只存在于线缆证据中，
  没有泄漏到用户表面。

## 五级结论

- **L2 / F2**：SSE durable 序列与 close 快照保持单调、可解释，并与真实终态一致；工具错误
  没有被旧的 wall-clock cancellation 语义吞掉。
- **L3 / A4**：轮询超过 1 秒期间持续呈现 `queued…` 状态（约 2s、5s、10s、16s），25 秒
  停止等待后给出下一步为重试/简化任务的明确路径，等待不是无反馈黑箱。
- **L4 / C4**：失败工具卡、错误正文、整体回合提示和 Composer 保持既有圆角、层级、对齐、
  留白与稳定布局；没有因错误详情导致 reflow、遮挡或内部 handle 泄漏。
- **L5 / G1**：用户无需读协议即可从 `Generated video · failed` 工具卡读懂失败状态，并在
  同一可见区域找到 `Retry`；整体提示同时给出“发送后续消息或简化任务”的可执行下一步。

首轮真实运行暴露了两个产品缺陷并已 stop-and-fix：保护性回合墙钟曾把视频业务错误降成
通用 `cancelled`，结构化错误又曾丢掉继续提示，随后用户表面还曾泄漏 opaque handle。最终
session 使用修复后的 binary 重跑；当前证据只引用修复后的行为，红场与中间诊断均保留在
同一战役的 session 历史中。
