# EDGE-303 侧幕 activity 门控：L3 真实帧顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-154941`
- data: `/private/tmp/anselm-data-edge303-l3-20260829-r1`
- screen: `screen.mov`, 2784x1808, 60fps, 116.191667s
- frame sample: `/private/tmp/anselm-edge303-frames-20260829-r1`, 696x452, 60fps

## Product path

1. 在真实 App 的新工作区空 Chat 中创建 `EDGE303 activity note`。
2. 首个真实 `create_document` 活动到达时，Activity 侧幕和头部入口出现；这次自动展开由现行 FollowMode 契约驱动，不以改掉自动展开作为“修复”。
3. 侧幕稳定后，手动关闭；关闭后的入口仍保留，中心内容恢复完整宽度。

## Frame measurement

- `go run ./cmd/measure diff -dir /private/tmp/anselm-edge303-frames-20260829-r1 -threshold 0.0001`:
  - `frame-00128 -> frame-00129`: `changedFrac=0.08411`, box `(206,23)-(664,411)`。
  - 这是侧幕开始揭示时的一次目标宽度重排：中心 transcript 从全宽切换到最终窄宽，之后不再重复重排。
  - `frame-00129 -> frame-00143` 的右侧 ROI 只出现连续的窄条变化；侧幕从右缘连续揭示，持续约 `14/60s=233.3ms`，与 `AnMotion.mid=240ms` 对齐。
  - 侧幕稳定后没有第二个结构性大变化。唯一另一个大变化 `frame-00343 -> frame-00344` 位于正文流式收尾，包围盒 `(208,41)-(488,399)`，是 transcript 新文本/自动滚动，不是侧幕开合；其后仅有局部输入区微变化。
- 侧幕过渡放大帧确认：入口/Activity 面板从右侧连续展开；已有文本只在进入目标布局时重排一次，没有“展开一次、收回一次”或重复闪烁。

## Five-channel cross-check

- frames: 同一 session 的窗口专属录屏，Computer Use 观察到空态无 Activity，活动到达后侧幕显示 `1 touched`、`Created`。
- backend: 同一 session 的 `backend.log`，219 行；无应用 `WARN`、`ERROR`、`panic`、`FATAL`。
- SSE: 同一 session 的 `sse.jsonl`，177 行；`messages` durable seq 单调，包含 touchpoint 与 tool-result 收口，无 gap。
- frontend: 同一 session 的 `frontend.log`，仅 Dart VM 启动行和已知 macOS IMK 宿主诊断；无 Flutter/Dart/RenderFlex/Unhandled 红线。
- LLM wire: 同一 session 的 `llm.jsonl`，真实 managed challenge/install/models 与 chat completions 均为 200。

## Judgment

- L3 `pass (B2)`: 这是一个由用户发起的 activity 侧幕揭示，发生一次有边界的目标布局切换，随后采用 240ms 连续揭示；未观察到额外跳变、重复布局或闪烁。
- 本证据不把这一帧目标宽度重排描述成“零像素变化”；若未来要求自动揭示也完全不重排，应另立 overlay/布局策略工单，不能通过改写本次测量结论达成。
