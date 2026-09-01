# EDGE-303 侧幕 Activity 门控：L5 真实用户可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-154301`
- data: `/private/tmp/anselm-data-edge303-l5-real-20260901-r2`
- workspace: `ws_85b0f01209d953e4`
- app PID: `23120`; window: `13061`; recorder: `23165`
- backend PID: `22655`; ssetap: `22708`; llmtap: `22631`
- recording: `screen.mov`, `89.446667s`; final frame: `session-local evidence/EDGE-303-activity-discoverability-fixed.png`

## Product path

1. 真实 App 从干净工作区启动，进入没有任何工具/触点记录的空 Chat；Computer Use AX 树和画面均未显示 Activity 入口。
2. 以一个不使用产品内部术语的普通用户目标发送：`Create a document named EDGE303 discoverability test with body one line. Then show me where I can check what the app changed.`
3. 受管 Anselm 网关真实执行 `create_document`，中心结果显示文档已创建；右侧 Activity 侧幕自动出现并显示 `1 touched`、文档名和 `Created`。
4. 修复前回归曾将实际可见的 `Library`/`Activity` 错称为 `Documents`，且没有指向近期变更面板；该路径因此冻结，不计为通过。补入模型产品面导航词汇硬约束后，以全新 session 重跑同一目标。
5. 修复后的助手明确告诉用户：查看本次变化看聊天界面右侧的 `Activity` 面板；要浏览或编辑结果，去左侧导航的 `Library`。这两个名称与同一帧 AX 树、Activity 面板和左侧导航完全一致，用户无需阅读文档或预先知道内部术语。

## Five channels

- frames: conductor 绑定窗口 `13061` 的专属 `screen.mov`；Computer Use 观察了空态、Activity 揭示后的稳定态和最终助手文案。固定画面证据为 `EDGE-303-activity-discoverability-fixed.png`。
- backend: `backend.log` 369 行；真实 document create 记录存在；无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 114 行；`messages`、`entities`、`notifications` 均连接；notifications durable frame 含 `document.created`，与中心和 Activity 的文档一致。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线；唯一 `error` 为已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断，不是 Flutter 应用错误。
- LLM wire: `llm.jsonl` 19 行；challenge/install/models 与三次真实 chat completion 请求均经 `llmtap` 到 `https://api.anselm.website`，响应为 HTTP `200`。

## Product judgment

- `G1` 通过：入口在首条真实活动完成后自动出现，且 `Activity` 这个可见标题、`1 touched` 计数、文档名和 `Created` 状态共同解释了“发生了什么”；用户不需要知道 `sidestage`、`touchpoint` 或任何内部名称。
- 助手引导与界面词汇一致：近期变化走 `Activity`，资源浏览/编辑走 `Library`；不存在把用户引向的幽灵 `Documents` 导航项。
- 本证据只判 L5 发现性，不把同一条路径冒充 L2 数据真相、L3 动效或 L4 视觉 craft；这些等级由同格独立证据承担。
