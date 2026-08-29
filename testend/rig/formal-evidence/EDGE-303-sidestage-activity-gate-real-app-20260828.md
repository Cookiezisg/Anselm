# EDGE-303 侧幕 activity 门控：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035907`
- data: `/private/tmp/anselm-data-edge303-20260828-r1`
- workspace: `ws_2e1f1299ec60af13`
- app PID: `58176`; window: `4617`; recorder: `58223`
- backend PID: `57719`; ssetap: `57740`; llmtap: `57701`

## Product walk

1. 真实 onboarding 创建 `EDGE-303 activity gate` 工作区，进入 Chat 的空线程。
2. 空线程没有任何工具/触点活动；画面右侧没有 Activity 侧幕，也没有右岛入口。
3. 新建干净对话，发送真实用户意图：创建名为 `EDGE-303 activity note` 的文档，并提供正文。
4. 受管 Anselm 网关真实执行 `create_document`。首条可登台活动到达后，右岛入口从头部横向出现；侧幕显示 `Activity`、`1 touched` 和 `EDGE-303 activity note · Created`。
5. 中心 transcript 同时显示 `Created document EDGE-303 activity note` 与成功答复；侧幕实体名、创建动词、中心结果一致。
6. 关闭侧幕后，头部仍保留 `Toggle panel` 入口；没有活动时的空门不出现，有活动后入口不丢失。

## Five channels

- frames: `screen.mov` 由 conductor 绑定窗口 `4617` 录制；空态与首条活动后的入口/侧幕均逐帧观察。
- backend: `backend.log` 527 行；无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 224 行；三条 stream 均连接，messages durable seq `1..35`，含 `touchpoint` signal seq `29` 与最终 message close seq `35`。
- frontend: `frontend.log` 496 行；除已单独审查的 macOS Flutter accessibility bridge churn 外，无 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- LLM wire: `llm.jsonl` 31 行；真实 challenge/install/models 与多轮 chat completions 均经 `llmtap`，网关响应为 200。

## Verdict

- L1 `pass`: 空态无门，活动到达后入口出现，真实画面满足 G1。
- L2 `pass`: 台架五通道归属和真实执行已封口，满足 F1。
- L3-L5: `na`，本格只验证存在性/门控，不把本次路径冒充顺滑、视觉 craft 或可发现性深评。
