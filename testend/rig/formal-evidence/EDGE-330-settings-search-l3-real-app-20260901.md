# EDGE-330 设置项搜索索引漂移：L3 真实 App 顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260901-13/sessions/20260901-232852`
- recording: `screen.mov`, `84.398333s`, 60fps；分析帧为录屏 `35s..65s` 的 30fps、`1440px` 宽抽帧
- law: `A1`（可见反馈 ≤100ms）
- verdict: `pass` for L3

## Product path

1. 从真实 Chat 壳进入 Settings，保持完整目录可见。
2. 在设置搜索框使用真实键盘事件输入 `zoom`；搜索结果按 General、Storage & logs、Shortcuts 分组出现。
3. 点击 `Reset zoom` 结果；搜索框清空，面板跳到 Shortcuts，目标行出现一次性浅蓝洗亮。
4. 输入 `zzzqqxx`；界面只显示一条 `No matching settings`，没有旧结果残留。连续退格清空后，13 个设置面板目录恢复。

## Measurement

对录屏 `35s..65s` 抽取的 `900` 个 30fps 帧，在 ROI `0,0,1440,800` 上执行：

```text
go run ./cmd/measure latency -dir edge330-l3-frames-late -fps 30 -action 146 -roi 0,0,1440,800 -threshold 0.001
→ feedbackFrame=147 latencyMs=33.3 changedFrac=0.03851

go run ./cmd/measure latency -dir edge330-l3-frames-late -fps 30 -action 476 -roi 0,0,1440,800 -threshold 0.001
→ feedbackFrame=477 latencyMs=33.3 changedFrac=0.02186

go run ./cmd/measure latency -dir edge330-l3-frames-late -fps 30 -action 875 -roi 0,0,1440,800 -threshold 0.001
→ feedbackFrame=876 latencyMs=33.3 changedFrac=0.01366
```

三次首反馈均在 A1 的 `100ms` 内。`measure diff` 的动作窗口变化分别落在设置面板打开、搜索结果更新和跳转洗亮区域；动作完成后稳定观察没有超过 `0.001` 的 ROI 变化，没有持续重排、闪回、重复洗亮或输入卡顿。

## Five-channel cross-check

- **frames / Computer Use**: 真实键盘输入、结果点击、目标跳转、洗亮、无匹配和清空恢复均由同一真实 App 录屏覆盖；AX 同时确认 query、分组结果、Shortcuts 目标和空结果文案。
- **backend**: `backend.log` 共 `338` 行，无 `WARN`、`ERROR`、`panic`、`fatal` 或应用级异常；本路径是前端索引与导航，只读后端 workspace 状态。
- **SSE**: `sse.jsonl` 共 `8` 帧，`entities`、`messages`、`notifications` 三条流各完成真实连接；该路径不产生业务 durable 事件，不伪造 seq。
- **frontend console**: `frontend.log` 共 `5` 行；Flutter VM 正常，另外两条为 macOS 输入法宿主诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed gateway challenge/install/models 均为 HTTP `200`；设置搜索不应调用模型，未出现伪造或多余 completion。
- **durable truth**: 搜索只改变设置面板选择和一次性洗亮，不创建消息或后端实体；画面状态与该产品边界一致。
- **rig lifecycle**: `rig-check.sh` 在操作前通过五通道归属与无外部遮挡，`rig-down.sh` 封口录屏并停止 App/backend/ssetap/llmtap，session journals 完整保留。

## Verdict

`L3 pass (A1)`。设置搜索从输入、分组、跳转到空结果恢复均有即时可见反馈，时延数字在标准内且稳定态无非用户跳变；L4 craft 和 L5 discoverability 不在本格重复结算。
