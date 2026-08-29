# EDGE-306 导演器清 Live 幽灵：L3 真实帧顺滑证据

- primary session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-162708`
- data: `/private/tmp/anselm-data-edge306-l3-20260829-r2`
- screen: `screen.mov`, 2784x1808, 60fps, 117.193333s
- frame samples: `/private/tmp/edge306-resync-20260829`, `/private/tmp/edge306-resync-hi-20260829`, 696x452, 10/60fps
- perturbation: App API proxy targeted `/api/v1/messages/stream`; the first stream was closed at `16:28:28.815`, the first reconnect returned HTTP `410` at `16:28:29.079`, and the next reconnect was forwarded normally.

## Product path

1. 在真实 App 中启动一条会产生多个 `create_document` 活动的长链：连续创建 `EDGE306-01` 至 `EDGE306-08`，最后读取 `EDGE306-08`。
2. 让 messages SSE 在活动仍进行时断开；此时独立 SSE witness 仍看到真实 `tool_call` 活动，且断开前尚有多个活动未收口。
3. App 续连收到真实 `410` 后立即重取会话 messages/interactions/touchpoints；最终 UI 显示正文、8 个活动条目和准确的 `EDGE306-08` 回读结果，没有永久 `Live` 幽灵。

## Frame measurement

- 断线前 `t≈56.0s` 的帧显示 Activity 侧幕中 `create_document` 仍为 `Live`；`410` 后约半秒，旧活动画面先被清出，中心回到完整宽度，避免把已失去终态的 Live 行继续当作运行中。
- 随着重取后的真实活动重新经过防抖，侧幕从右侧再次连续揭示；高帧样本显示收回/揭示均为单向过渡，没有来回弹跳或闪烁。揭示窄条阶段连续约 `233.3ms`，与 `AnMotion.mid=240ms` 对齐。
- 这不是把清理和重新登台压成一帧：短暂无侧幕是诚实的重同步状态，之后仍在执行的活动重新获得舞台；录屏没有永久残留行，也没有把已完成活动误显示为 Live。

## Five-channel cross-check

- frames: 同一正式 session 的窗口专属录屏与 Computer Use 观察到断线前 Live 活动、410 后清理、重新登台及最终 8 条准确活动。
- backend: `backend.log` 217 行；无应用级 `WARN`、`ERROR`、`panic`、`FATAL`。
- SSE: `sse.jsonl` 455 行；独立 witness 的 `messages` durable seq=`1..61`、`notifications`=`1..10` 均单调无 gap；messages witness 保留了断点期间真实完整后端活动。
- frontend: `frontend.log` 5 行；包含一次与本轮 proxy 断流对应的 `Connection closed while receiving data`，这是预期的注入网络故障，不是 Flutter/Dart/RenderFlex/Unhandled 红线；除此之外无应用红线。
- LLM wire: `llm.jsonl` 22 行；challenge/install/models 与 8 次 chat completion 响应均为 HTTP `200`。
- durable truth: SQLite `documents` 查询得到 8 条未删除文档，名称、正文和描述均精确对应 `EDGE306-01..08`；最终消息流含 `read_document` 与 `8 touched` 的闭环。

## Judgment

- L3 `pass (B2)`: messages 410 发生在真实活动期间时，导演器先清理失去终态的 Live 幽灵，再让仍真实存在的活动通过正常防抖重新登台；过渡单向、可解释、无闪烁，最终 UI 与后端持久真相一致。
- 本证据不把一次注入故障下的重同步行为冒充为 L4/L5，也不把预期的网络断开日志误报成应用故障；阈值、法典、锚点和 gate 均未修改。
