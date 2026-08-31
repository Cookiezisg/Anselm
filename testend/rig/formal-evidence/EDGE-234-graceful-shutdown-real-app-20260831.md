# EDGE-234 三步优雅关停：真实 App 五通道证据

## 结论

本格通过。真实 App、backend、三路常驻 SSE、frontend console、llmtap 和录屏全部由同一
conductor session 托管。收台时先封住录屏，再停止 App，随后 backend 收到 SIGTERM；backend
先记录 `shutting down gracefully`，三条 resident SSE 同时收到 EOF，最后 sandbox handles
收口，所有 owned processes 均退出，没有升级到 SIGKILL。

## Session

- formal session: `/private/tmp/anselm-rig-formal-20260831-16-edge234/sessions/20260831-140051`
- isolated data: `/private/tmp/anselm-data-edge234-20260831`
- real App PID: `86173`; backend PID: `85682`; ssetap PID: `85739`; llmtap PID: `85655`
- recording: `screen.mov`, H.264, `3104x1844`, `60fps`, `32.426667s`
- final frame: `evidence/frames/edge234-final.png`

## 五通道对账

- **帧**：录屏在关停前保持稳定 Scheduler 空态，无白屏、残留 overlay 或布局红线；录屏可
  解析，conductor 以 `INT` 封口，随后 App 正常退出。
- **后端**：`backend.log` 在三路 stream 请求结束后记录 `shutting down gracefully`，
  随后 `sandbox shutdown: all handles killed {count: 0}`；无 panic、FATAL、ERROR、WARN。
- **SSE**：ssetap 在同一 workspace 独立连接 `notifications`、`messages`、`entities`
  各一次；关停时三者都记录 `tap=disconnect, err=eof`，没有卡住 HTTP shutdown。
- **前端**：`frontend.log` 无 `FlutterError`、`DartError`、`RenderFlex`、Unhandled、
  Exception、ERROR 或 FATAL。
- **LLM 线缆**：llmtap 启动为 ready，managed key 经过独立 tap；本格是关停路径，没有把
  无 completion 冒充模型业务证据。

`rig-check.sh` 在三路 SSE 已连接时通过；`rig-down.sh` 顺序收台并报告 backend、ssetap、
llmtap 全部正常停止，未出现 SIGKILL escalation。

## 判定

L1 使用既有 `F5` focused shutdown/reap evidence。L2 使用本 session 的 `F2` 五通道关停
证据；L3 使用 `A4`，连接结束和 backend 收口没有无界等待；L4 使用 `C4`，关停前稳定帧
无视觉破坏；L5 记明确适用性 `na`：优雅关停是内部生命周期动作，不产生用户寻找功能
入口或独立 discoverability 对象，不能把台架日志冒充用户发现性证据。
