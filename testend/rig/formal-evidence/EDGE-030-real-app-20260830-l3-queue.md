# EDGE-030 · 流式期间发送第二条消息 · L3

## 场景

在真实 Anselm App 中先发送第一条英文问题，等待其持续流式输出；在第一回合仍处于
`thinking` 状态时，在 Composer 输入第二条消息并按 Enter。验收目标是用户能立即知道
消息已经进入队列，而不是误以为点击没有生效。

## 逐帧证据

- 正式会话：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-130007`
- 录像：该会话的 `screen.mov`，窗口录制，`3104x1844`，名义 `60fps`
- 队列动作窗口：录像约 `45.25s` 至 `45.75s`
- 精确解码帧：`EDGE-030-real-app-20260830-l3-queue-frames/`
- 动作前基线：`frame-00013.png`，完整第二条消息仍在 Composer 中，未显示队列状态
- 首反馈：`frame-00014.png`，首次出现 `1 waiting to send`、消息胶囊和可移除的 `x`
- `go run ./cmd/measure latency -dir rig/formal-evidence/EDGE-030-real-app-20260830-l3-queue-frames -fps 60 -action 13 -roi 700,1300,1900,500 -threshold 0.0005`
- 测量结果：`feedbackFrame=14, latencyMs=16.7, changedFrac=0.01902, box=(1242,1516)-(2524,1630)`

录像原始轨是 ReplayKit VFR，动作附近存在真实的时间戳间隔；因此没有直接把原始帧序号
当作固定帧率使用，而是用**全量精确解码**后以 `fps=60` 保持画面生成 CFR 证据帧，再用
测量器计算。该做法只重复最后一帧，不插造新的 UI 内容；首反馈的像素来自录像中的真实
队列胶囊。原始 SSE 与后端时间线同时证明这不是第二回合已经完成后的假反馈：消息在 UI
排队期间没有新的 LLM 请求，直到第一回合收尾后才出现第二条消息的 POST 和 LLM 请求。

## 五通道互证

- **Frame**：L3 帧中 Composer 从输入态切换为明确的 `1 waiting to send` 队列态，且保留
  可移除胶囊；没有隐藏状态或不可解释的空白。
- **Backend**：第一条消息 POST 为 `13:01:07.372`；第二条消息 POST 为
  `13:01:55.110`，说明第二条没有在第一回合期间抢跑。
- **SSE**：第二条用户消息在第二次 POST 后才以 durable seq `9/10` 落行；第一回合先以
  seq `7/8` 收尾，顺序与 UI 语义一致。
- **Frontend console**：无 `FlutterError`、`DartError`、`RenderFlex` 或未处理异常；仅有
  已知 macOS IMK 诊断行。
- **LLM wire**：两次 `/v1/chat/completions` 均由真实 managed gateway 返回 `200`；没有
  因排队动作产生并发第二请求。

## 裁决

`A1`：首个可见队列反馈为 `16.7ms <= 100ms`，通过。

`A5`：流式期间 Composer 可继续输入，第二条消息进入可见 FIFO 队列，回合结束后按序
发送；交互没有冻结或产生第二个并发回合，通过。

