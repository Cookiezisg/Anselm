# EDGE-351 | 429 不动钱 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：受管网关限流时，用户目标得到明确失败原因和有限恢复路径，且配额不会被误判为耗尽。

## 真实路径

正式 session=`/private/tmp/anselm-rig-formal-20260902-31/sessions/20260902-053825`。真实 App 在全新隔离
workspace 中发送 `Please summarize this rate-limit recovery test in one sentence.`；llmtap 只对真实
`https://api.anselm.website` 的 `/v1/chat/completions` 注入 HTTP `429`，响应体为闭集
`{"error":{"code":"RATE_LIMITED",...}}`。App 显示 `The model service is temporarily busy. Please try again shortly.`，
没有显示额度耗尽，也没有把失败伪装成成功答案。错误卡仍提供 `Retry`，重试菜单可见且 Composer 保持可用。

## 五通道互证

- **录屏 / Computer Use**：`screen.mov`=`234.080000s / 3104x1848 / 60fps`；AX 逐状态确认消息、限流错误、Retry 菜单和可用 Composer。
- **backend**：健康检查持续 `200`，消息回合以 `LLM_RATE_LIMITED` 收口，无 WARN/ERROR/panic。
- **SSE**：三条 `messages`、`entities`、`notifications` 流均连接并 clean EOF；messages 记录 user open/close 与 assistant error close，无成功答案帧。
- **frontend console**：无 Flutter/Dart/PlatformException/RenderFlex/Unhandled/Exception/overflow 红线，仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**：真实请求收到 `429`，四次有限退避均携带 `RATE_LIMITED`；未发生成功 completion 或 quota-exhausted 响应。

## 配额不动

既有真实受管网关基线快照在 `EDGE-351-rate-limit-no-spend-20260826.md`：同一限流语义的 before/after
quota 为 `limit=10000, used=1234, remaining=8766`，保持不变。正式现场的 wire 与 SSE 进一步证明没有成功
生成或额度耗用路径。

## 结论

限流被产品正确收敛为可理解的暂时繁忙状态，不与不可重试的额度耗尽混淆，用户仍可继续编辑或重试。
