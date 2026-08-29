# EDGE-349 语音流中上游断线

## 结论

`EDGE-349` 的 L2 真实产品验收通过。真实 Flutter App 在语音 WebSocket 已建立、收到一段
增量转写后遭遇上游断线时，停止录音并保留已转写文字；自动重连只执行一次，自动重连再次
失败后给出可解释的重试卡。点击“重试转写”会重放本地 PCM，第二次失败仍回到同一可重试
状态，没有无限重连、永久录音或吞掉草稿。

## 台架与构造数据

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-004607`
- data=`/private/tmp/anselm-data-edge347-fix2-20260827`
- screen recording=`66.045000s`
- workspace=`ws_a0c08e8dc49d9a60`
- 上游使用一次性本地断线 fixture（本边界需要构造中途断线）；真实 App、sidecar、三路 SSE、
  `llmtap` 和窗口录制均由标准 conductor 启动，fixture 不绕过 `llmtap`。

## 红场与 stop-and-fix

第一轮真实 App 中途断线复验发现 `onError` 与 `onDone` 可能同时到达，两个回调会并发
执行 recorder teardown / reconnect，前端 journal 出现：
`PlatformException(record, Recorder has not yet been created or has already been disposed.)`。
该 session 未计绿。

修复为每个 WebSocket generation 设置单飞断线恢复门，并让上游
`SPEECH_UPSTREAM_CLOSED` 事件复用同一恢复路径；增加 `duplicate socket loss callbacks do not
race recorder teardown` 回归测试。测试过程中一次错误的 Computer Use 索引曾点中“提及实体”
而产生 `@`，已判定为台架操作错误，未计入产品缺陷或证据。

## 最终绿场

- Computer Use 准确点击当前 AX 树中的“语音输入”；录音中显示 `00:00`，fixture 发送增量
  `你` 后关闭上游。首次断线自动重连一次，第二条语音连接也关闭，App 显示“语音输入中断”
  和“草稿已保留，可用本地录音重放一次重新转写。”，输入框保留 `你`。
- Computer Use 从新 AX 树解析并点击“重试转写”；界面短暂显示“正在收尾 00:01”，第三条
  语音连接关闭后再次回到同一重试卡，输入框仍为 `你`。没有多余 `@`、没有残留录音态、
  没有无限重连。
- channel 2 backend：三次 `GET /api/v1/speech/asr` 均完成本地 WebSocket 收口，状态为
  `200`，无 `panic`、`WARN`、`ERROR`。
- channel 3 SSE witness：`notifications`、`messages`、`entities` 三流均连接；无缺流，
  本次语音错误没有伪造 durable 消息帧。
- channel 4 frontend console：最终绿场只有 Flutter VM service 与已知 macOS
  `IMKCFRunLoopWakeUpReliable` 系统噪声；无 `PlatformException`、`FlutterError`、
  `DartError`、`RenderFlex`、`Unhandled`、应用 `Exception` 或 fatal。
- channel 5 LLM wire：fixture challenge `200`；三次 `/v1/speech/asr` 均为成功升级
  `101`，初次、自动重连和用户重试均穿过 `llmtap`，没有绕过线缆。
- channel 1：窗口录制=`66.045000s`；`rig-check` 五通道通过，`rig-down` 正常封口且无残留。

## 裁决边界

本证据只支持 L2 的断线收口、草稿保留、一次自动重连和用户重试目的；没有把一次错误态
验证冒充完整顺滑、视觉 craft 或可发现性完成。因此 L3、L4、L5 保持 `na`。

法条：`A4`（错误反馈与终态）、`F2`（断线后的本地草稿与真实状态交叉核对）。
