# EDGE-305 侧幕尊重手动关：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-162006`
- data: `/private/tmp/anselm-data-edge305-l5-real-20260901`
- workspace: `ws_fb7ea890d544b440`
- app/window: `28649/13184`
- backend/ssetap/llmtap: `28174/28225/28143`
- screen: `screen.mov`, 1440x810 window capture, 60fps, 133.196667s
- final frame: `evidence/EDGE-305-manual-close-final.png`

## Product path

1. 从隔离 workspace 的干净 Chat 开始，用户只提出创建文档的自然目标；首个活动完成后 Activity 侧幕自动出现。
2. Computer Use 观察到侧幕右上角清晰的 `X` 关闭入口，同时 AX 暴露可操作的 `Toggle panel`；用户不需要知道设置项名称或内部的 sidestage 概念。
3. 点击关闭入口后，侧幕消失但 `Toggle panel` 保留在顶栏，用户仍能随时找回活动。
4. 同一对话再创建 `EDGE305 after close`；第二个活动完成后侧幕保持关闭，中心 transcript 增加结果但不强行打开侧幕。

## Discoverability judgment

- 关闭动作使用常见的右上 `X`，位置、形状和顶栏留白符合用户对可关闭浮层的预期；AX 的 Toggle 语义与视觉入口一致。
- 关闭不是永久隐藏或数据丢失：入口继续可见，Activity 内容只改变呈现状态，用户可以明确地重新打开。
- “我关掉了就别再打扰我”的用户意图跨越第二个真实活动仍然成立；中心内容、活动结果和 Library 编辑路径没有被牺牲。
- 同一会话中第二个活动不再自动弹出，证明系统尊重的是用户动作而非只在单一静态帧中看起来像关闭。

## Five-channel cross-check

- frames: Computer Use 观察首个活动、右上 X、关闭后 Toggle、第二活动完成后的稳定态；录屏和最终截图归属于同一 session。
- backend: `backend.log` 507 行；未发现应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 201 行；三流 tap 记录两个 document activity 的 durable 事件，第二个活动没有触发错误或异常 UI 状态。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 是已分类的 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断。
- LLM wire: `llm.jsonl` 25 行；managed challenge/install/models/chat 均成功，两个文档正文均原样进入请求。

## Judgment

- L5 `pass (G1)`: 普通用户能从常见的 `X` 找到关闭动作，关闭后的入口仍可发现，且后续活动持续尊重该选择；真实画面、 transcript、SSE、后端和 LLM 数据一致。
- 本证据不把设置页选项或已有 L4 视觉证据重复计算为本格结论。
