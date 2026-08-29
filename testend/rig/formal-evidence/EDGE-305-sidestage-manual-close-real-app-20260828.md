# EDGE-305 侧幕尊重手动关：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-041819`
- data: `/private/tmp/anselm-data-edge305-20260828-r1`
- workspace: `ws_dbbedcb79986113`
- app PID: `60542`; window: `4681`; recorder: `60587`
- backend PID: `60086`; ssetap: `60110`; llmtap: `60060`

## Product walk

1. 真实 onboarding 创建 `EDGE-305 manual close` 工作区，创建 `EDGE-305 manual close first`，首条 `create_document` 活动使 Activity 侧幕出现。
2. 直接点击 Activity 侧幕右上角关闭按钮；侧幕收起，但头部 `Toggle panel` 入口保留。
3. 切到 Entities 空 Overview，再返回 Chat；原会话和其已关闭状态恢复，侧幕没有被海洋切换重新弹出。
4. 在同一会话创建 `EDGE-305 manual close second`，中心真实结果完成，侧幕仍保持关闭，入口仍可用；没有强制弹窗或丢失活动数据。

## Five channels

- frames: `screen.mov` 由 conductor 绑定窗口 `4681` 录制，覆盖首条活动、手动关闭、切换海洋、返回 Chat 和第二次活动。
- backend: `backend.log` 201 行；无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 233 行；messages durable seq `1..30`，entities `1..2`，notifications `1..4`。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- LLM wire: `llm.jsonl` 25 行；challenge/install/models 和全部 16 个上游响应均为 200。

## Verdict

- L1 `pass`: 手动关闭后入口仍保留、切换海洋不误重开，满足 A5。
- L2 `pass`: 手动关闭状态、第二次真实活动、中心结果和五通道数据真相一致，满足 F1。
- L3-L5: `na`，本格只判定手动关闭持久性与活动门控，不冒充独立顺滑、视觉 craft 或可发现性深评。
