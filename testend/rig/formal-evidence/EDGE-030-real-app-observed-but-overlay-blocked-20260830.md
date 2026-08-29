# EDGE-030 · 真实探针已观察，正式收口被系统遮挡阻断

## Observed

Session `20260830-021449` 由 conductor 从当前源码真实构建并启动：LLM tap、后端、
SSE witness、macOS App 和窗口录屏均已归属。真实 App 打开并实时接收该会话的流；
通过同一 session 的 REST 连续发起该会话的并发 send，第三次请求得到：

```text
HTTP/1.1 409 Conflict
{"error":{"code":"STREAM_IN_PROGRESS","message":"this conversation already has an assistant turn running","details":null}}
```

重新打开该会话后，Computer Use AX 树和画面观察到原有 thought/tool 轨迹，以及
`Something went wrong · STREAM_IN_PROGRESS` 的明确反馈；回合随后自然收口。

## Formal disposition

`rig-check` 在收台前发现 `SecurityAgent` 与 `CoreServicesUIAgent` 窗口覆盖 Anselm
录屏区域，因此按规则失败。`rig-down` 已保存 `screen.mov`（`126.848333s`）和全部
channel journals，但这场不能作为正式 L2/L3 证据，未写 pass，也不把系统遮挡归因
为产品画面。该项已加入 `ledger-sequence.json` 的人工队列；清除遮挡后必须重新录制
并完整通过五通道 gate。L1 focused/race 证据仍有效，标准、阈值、CODEX、锚点集和
顺序 gate 未修改。
