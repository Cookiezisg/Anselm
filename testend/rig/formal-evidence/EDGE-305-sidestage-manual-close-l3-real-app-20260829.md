# EDGE-305 侧幕尊重手动关：L3 真实帧顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-161757`
- data: `/private/tmp/anselm-data-edge305-l3-20260829-r1`
- screen: `screen.mov`, 2784x1808, 60fps, 120.246667s
- frame samples: `/private/tmp/edge305-hi-20260829`, `/private/tmp/edge305-close-hi-20260829`, 696x452, 60fps

## Product path

1. 在真实 App 的 Chat 设置中确认 `Every time`，在新会话创建 `EDGE305 first activity`；活动完成后 Activity 侧幕自动打开并显示 `1 touched`。
2. 通过真实 UI 手动关闭侧幕；中心 transcript 恢复完整宽度，`Toggle panel` 入口保留。
3. 在同一会话再次创建 `EDGE305 after close`；活动完成后侧幕保持关闭，中心布局不被重新收窄，入口仍可发现。

## Frame measurement

- 首次揭示前后，右侧 ROI 出现从右缘向左的连续变化；`edge305-hi` 从视频 `t=52s` 开始，`frame-0143→0156` 对应约 `t=54.38..54.60s`、约 `233.3ms` 的揭示窗口，与 `AnMotion.mid=240ms` 对齐，没有来回开合。
- 手动关闭阶段的 `edge305-close-hi` 采样显示侧幕向右缘连续收回；关闭后没有第二次自动展开。收回期间未出现中心内容反复重排或闪烁。
- 第二个活动完成后的后续录屏保持无侧幕的完整宽布局；`Toggle panel` 仍存在，未发生自动抢屏。后续 ROI 变化来自新消息正文流式渲染，而非侧幕状态变化。

## Five-channel cross-check

- frames: 同一正式 session 的窗口专属录屏与 Computer Use 观察覆盖自动打开、手动关闭、关闭后第二个活动；最终 AX 同时显示第二篇文档和 `Toggle panel`，没有 Activity 面板。
- backend: `backend.log` 214 行；无应用级 `WARN`、`ERROR`、`panic`、`FATAL`。
- SSE: `sse.jsonl` 166 行；`entities` durable seq=`1..2`、`messages`=`1..30`、`notifications`=`1..4` 均单调无 gap；3 次 disconnect 为正常收台。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 文本为已分类 macOS IMK 宿主诊断。
- LLM wire: `llm.jsonl` 25 行；challenge/install/models 与 15 次 chat completion 交换的响应均为 HTTP `200`，无非 2xx。

## Judgment

- L3 `pass (B2)`: 用户手动关闭是稳定的单次收回；之后新活动不会再次自动抢屏，且入口仍可发现。没有观察到重复开合、反复重排或闪烁。
- 本证据只判定手动关闭后的状态保持与过渡稳定性，不把侧幕内容的视觉 craft 或设置的可发现性冒充为 L4/L5。
