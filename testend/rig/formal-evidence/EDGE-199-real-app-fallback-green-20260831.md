# EDGE-199 绿证据：代理图未 ready 时真实 App 回退原图

- **结果**：GREEN
- **时间**：2026-08-31
- **场次**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-084340`
- **真实上游**：`https://api.anselm.website`
- **真实 App**：PID `39095`，窗口 `10257`，录屏 `116.865000s`
- **台架条件**：仅设置 `ANSELM_RIG_MEDIA_PROCESS_DELAY_MS=15000`，延迟真实 `ImageProcessor`；产品默认值为 `0`，不改变普通运行路径

## 验收动作

1. 真实 App 通过原生 macOS 文件选择器上传 `edge199-fallback.jpg`；源文件为 `12000x12000`、`2995581` bytes，低于受管网关 `3 MiB` 解码媒体额度。
2. 附件 chip 在发送前明确显示 `Preparing media…`，立即点击 Send。
3. 在真实聊天回合开始时，model-default derivative 仍未 ready；聊天路径等待约 2 秒后使用原图继续，未等待 15 秒的后台处理完成。
4. 真实受管 gateway 收到的 staging 分片为 `2995581` bytes 原图，不是之后生成的 `943140` bytes、`2048x2048` 代理图。
5. 后台 worker 随后完成 durable derivative，状态变为 `ready`；回合最终正常完成，App 无错误卡片或内部诊断泄漏。

## 五通道证据

- **Frame**：Computer Use 在发送前读取到 `edge199-fallback.jpg, Preparing media…`；发送后画面保持正常聊天状态，最终显示附件、思考块、助手答案与可用 Composer，无错误横幅、遮挡或布局崩坏。录屏为本 session 的 `recording.mov`。
- **Backend journal**：附件 `att_c5078e11ab419549` 的原图读取为 `2995581` bytes；`attachment_derivatives` 中 `mdr_26847300eaf5c7e9` 在 `00:45:20.852236Z` 创建，`00:45:37.727510Z` 才 ready，产物为 `943140` bytes、`2048x2048`。backend 无 `WARN`、`ERROR` 或 panic。
- **SSE**：messages 流记录 user `open/close`（seq 1-2）、attachment touchpoint（seq 3）、assistant `open`（seq 4）、reasoning/text block 与 completed message close（seq 5-9），durable seq 单调连续；三条 SSE 流均由 ssetap 观察。
- **Frontend console**：无 Flutter/Dart 应用异常；唯一日志为已知 macOS IMK 系统诊断，不属于产品错误。
- **LLM wire**：先发生真实 managed upload create、`PUT` 原图分片和 complete；`00005_v1_media_uploads_mup_60a7c8049fd2e03b277bb7379d7df21c.bin` 为 `2995581` bytes。chat body 仅携带 `/v1/media/leases/.../content?token=...` 相对 lease，无绝对 URL、`data:image` 或 base64 图片字节。chat completion 返回 `200`。

## 判定

- 有界等待确实优先保证本回合可用，不把后台代理生成延迟传播给用户。
- 未 ready 不是失败：本回合送出可交付原图，后台继续生成并持久化代理。
- 代理 ready 后仍保留优化路径；本次没有把 ready 路径误写成 fallback 证据。
- 失败/内部协议细节留在台架与服务日志，产品界面只呈现正常的附件与回答。

对应法条：`CODEX.md` F2、A4、C4、G1。
