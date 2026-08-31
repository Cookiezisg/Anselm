# EDGE-234 三步优雅关停：账本与警报独立复审

本格的 `gap-too-fast` / `discovery-collapse` 只反映近期裁决统计窗口，不能因为真实
关停证据清晰就跳过复审。本复审重新核对 formal session 的 `screen.mov`、
`backend.log`、`frontend.log`、`sse.jsonl`、`llm.jsonl`、`recording-lifecycle.json`
以及 `rig-check`/`rig-down` 封口：录屏可解析，三路 resident SSE 均 clean EOF，backend
先取消请求再完成 HTTP shutdown，frontend/backend 没有应用红线，owned processes 全部
正常退出且没有 SIGKILL escalation。

本格是 backend/transport 生命周期动作，没有 completion 业务请求；llmtap 的 managed
challenge/install/models 仍由独立 tap 记录，但本复审不把无 completion 冒充业务证据。

警报复审不修改阈值、曲线算法、CODEX、锚点、顺序门或五级标准。`discovery-collapse`
的 fail-share 低于阈值只表示本窗口没有失败裁决，不能把它改写成绿色或降低发现率门槛；
后续新裁决仍会重新计算并可能重新打开警报。
