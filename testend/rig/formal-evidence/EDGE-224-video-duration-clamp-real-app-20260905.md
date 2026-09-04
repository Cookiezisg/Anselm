# EDGE-224 | 不可能的生成组合钳制：真实 App 证据

## 判定

- L2 `pass`，法条 `F4`
- L3 `pass`，法条 `A4`
- L4 `pass`，法条 `C4`
- L5 `pass`，法条 `G1`

L1 focused contract 证据仍由既有
`testend/rig/formal-evidence/EDGE-224-video-duration-clamp-20260826.md` 承载；本次补齐真实
产品现场，不把本地 TLS 网关回归冒充真实生成。

## 真实场景

- session：`/private/tmp/anselm-rig-formal-20260905-edge236d/sessions/20260905-055901`
- 真实 macOS App PID：`91777`；录屏：`497.560000s`
- 真实受管 Anselm gateway：`https://api.anselm.website`
- 用户请求：30 秒横向视频；真实模型 wire 的 tool call arguments 确实为 `seconds:30`
- operator 完成真实危险确认，HTTP 决议为 `204`

真实 LLM tap 记录的生成提交 body 为：

```json
{"aspect":"landscape","prompt":"A red lighthouse standing by the sea at dusk, with warm golden and purple hues in the sky, gentle waves lapping against the rocky shore, cinematic and atmospheric","resolution":"720p","seconds":15}
```

这证明钳制发生在 Anselm 的生成工具边界，而不是模型请求阶段被改写。真实上游任务历经
`running` 轮询后返回成功，最终 tool-result receipt 为 `seconds:15`、`mime:video/mp4`、
真实 `attachmentId` 和 `sizeBytes:10062772`。

## 用户可见结果

Computer Use 打开最终对话画面确认：

- 正文明确显示“视频已生成，实际时长为 15 秒（未达请求的 30 秒，受提供商上限限制）”；
- 工具卡显示 `Saved as a video attachment · 15s`，与 receipt 的实际值相同；
- 没有把 30 秒写成成功事实，没有裸 provider payload、内部 job handle、假视频或失败态；
- 生成期间 Composer 保持可用，逐步显示 `running…` 和已耗时，最终稳定收口为可播放附件；
- 任务完成后提供 `Retry`，对话可继续使用。

## 五通道互证

- **Channel 1 / frame**：`screen.mov` 由 conductor-owned recorder 封口；最终画面逐帧核对 15s
  工具卡、中文事实说明、Composer 和稳定布局；`rig-check` 确认无外部窗口遮挡。
- **Channel 2 / backend**：backend journal 记录一次真实视频工具执行和最终附件结果，无 panic、
  FATAL 或未解释应用级错误。
- **Channel 3 / SSE**：messages durable 序列从用户 close、tool call、长进度、tool-result 到
  assistant close 单调；tool-result 的 receipt 与 REST/画面相同。
- **Channel 4 / frontend**：frontend journal 无 Flutter、Dart、RenderFlex、Unhandled 或应用
  Exception 红线；唯一 IMK 信息是已分类的 macOS 宿主诊断。
- **Channel 5 / LLM wire**：真实 challenge/install/models/chat bootstrap 全部成功；模型先发
  `seconds:30`，Anselm 发给真实视频供应商的 submit body 为 `seconds:15`，上游成功 receipt
  和 UI 均为 `15`。

## 五级结论

- **L2 / F4**：模型意图、实际供应商请求、上游响应、SSE、REST、SQLite 和 UI 对同一真实任务
  的 duration 结论一致；仅请求值与实际值不同，差异被明确解释为上限钳制。
- **L3 / A4**：约 6 分 46 秒的真实异步任务期间持续显示 `running…` 和已耗时，结束后快速
  呈现附件与实际时长，没有无反馈黑箱。
- **L4 / C4**：成功工具卡、事实说明、附件状态和 Composer 保持既有圆角、层级、对齐、留白
  与稳定布局；15s 事实在卡片与正文中没有冲突或视觉跳变。
- **L5 / G1**：用户无需读 provider 协议即可从正文与工具卡理解“请求 30 秒但实际 15 秒”，
  找到已保存的视频附件并继续操作。

真实任务完成后已执行 `rig-check` 和 `rig-down`，owned processes/listeners 收台归零。
