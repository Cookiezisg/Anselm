# EDGE-198 绿证据：受管附件 staging 失败大声失败且可恢复

- **结果**：GREEN
- **时间**：2026-08-31
- **场次**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-081342`
- **真实上游**：`https://api.anselm.website`
- **故障来源**：`llmtap` 仅对精确路径 `/v1/media/uploads` 注入一次 HTTP 503；这是受控台架故障，不冒充网关原生故障
- **真实 App**：PID `35466`，窗口 `10121`，录屏 `142.038333s`

## 验收动作

1. 真实 App 新建对话并从系统文件选择器上传 `edge193-neutral-test.png`。
2. 真实附件 staging 的第一次 `POST /v1/media/uploads` 被 tap 注入 503。
3. App 进入错误终态，画面显示：

   > This attachment couldn't be prepared for the reply, so the reply couldn't continue. Retry to try preparing it again.

4. 错误面保留 Retry；执行 Retry 后，第二次 staging 完成 `POST`、`PUT`、`complete`，随后模型真实调用 `inspect_media` 并返回图片描述，回复正常完成。

## 五通道证据

- **Frame**：录屏与 Computer Use AX 均确认错误横幅只显示用户文案，未显示 `ATTACHMENT_STAGING_FAILED`、`INTERNAL_ERROR`、message id、文件路径、503 或 provider 原文；Retry 后显示真实图片描述和已完成回复。
- **Backend journal**：错误终态稳定写入 `errorCode=ATTACHMENT_STAGING_FAILED`；没有 `WARN`、`ERROR` 或 panic。
- **SSE**：messages close 帧携带稳定错误码，随后 Retry 的 durable seq 连续推进到完成终态；notifications/entities/messages 三流均由 ssetap 连接并正常断开。
- **Frontend console**：没有 Flutter/Dart 应用错误；仅出现 macOS IMK/键盘系统诊断。
- **LLM wire**：第一次 staging 记录一次精确路径 503 注入；Retry 记录完整上传链和 HTTP 200 chat completion。上游仍是真实 `api.anselm.website`。

## 判定

- 受控 staging 故障没有被静默吞掉，也没有把用户推入基础设施排错。
- 错误说明发生了什么、为什么本次回复停住、下一步如何重试。
- 重试不是装饰：同一附件真实重新 staging 并完成模型回复。
- 原始诊断细节仍留在 backend/SSE/LLM 证据中，产品 surface 不泄漏。

对应法条：`CODEX.md` E1、E2、F1、F2、G1。
