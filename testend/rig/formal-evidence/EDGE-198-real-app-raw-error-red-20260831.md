# EDGE-198 红证据：受管附件 staging 失败泄漏内部错误

- **结果**：RED，禁止记账为通过
- **时间**：2026-08-31
- **场次**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-080111`
- **真实上游**：`https://api.anselm.website`
- **故障来源**：`llmtap` 仅对精确路径 `/v1/media/uploads` 注入一次 HTTP 503；不是网关原生故障
- **观测方式**：真实 macOS App、窗口录屏、backend journal、SSE tap、LLM tap、Flutter stdout

## 复现

1. 真实 App 选择 `edge193-neutral-test.png` 作为图片附件。
2. 真实附件准备请求穿过本地 tap；tap 在 `POST /v1/media/uploads` 注入 503，并记录 `fault_injected`。
3. 用户发送视觉问题。
4. messages SSE 的终帧与 App 画面都进入错误态。

## 产品失败面

App transcript 实际显示：

```text
Something went wrong · INTERNAL_ERROR · load history: chatapp.LoadHistory: render user message msg_9bb29efb86195082: render attachments: attachment: stage "edge193-neutral-test.png" for managed media: llm.media: llm: provider error (503)
```

这违反 CODEX E1：用户看到的是内部错误码、message id、附件 staging 实现细节和 HTTP 状态，而不是发生了什么以及如何恢复。Retry 按钮虽然存在，但错误主体把用户推入基础设施排错，不能接受。

## 五通道事实

- **Frame**：录屏中真实错误横幅可见，图片气泡仍在，未出现可行动的附件准备说明。
- **Backend journal**：回合以 `error` 终止，`errorCode=INTERNAL_ERROR`，`errorMessage` 含上述内部链。
- **SSE**：messages close 帧同样携带该内部链，故不是 UI 单独拼错。
- **Frontend console**：只有 macOS IMK diagnostic，没有 Flutter/Dart 应用异常；这确认是产品错误分类/文案问题，不是渲染崩溃。
- **LLM wire**：`llm.jsonl` 记录 `/v1/media/uploads` 的一次 503 注入；后续模型请求未发送，符合 staging 失败应中止本回合的边界。

## 修复条件

修复必须同时满足：

1. staging 错误拥有稳定的 `ATTACHMENT_STAGING_FAILED` 分类；
2. UI 显示可行动的人话和 Retry，不显示内部码、路径、message id、provider 原文或 HTTP 状态；
3. 原始细节仍只进入 backend/rig 诊断证据；
4. 用同一真实 App、真实上游和同一路径 503 注入重新跑绿后，才允许继续 EDGE-198 的 L2-L5 记账。
