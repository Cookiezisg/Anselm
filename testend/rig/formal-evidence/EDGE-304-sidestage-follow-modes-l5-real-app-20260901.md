# EDGE-304 侧幕跟随三档：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-160554`
- data: `/private/tmp/anselm-data-edge304-l5-real-20260901`
- workspace: `ws_77ffb045140bc901`
- app/window: `26799/13143`
- backend/ssetap/llmtap: `26297/26347/26266`
- screen: `screen.mov`, 1440x810 window capture, 60fps, 65.526667s
- final frame: `evidence/EDGE-304-l5-final.png`

## Product path

1. 从隔离 workspace 的干净 Chat 开始；Activity 侧幕在没有活动时没有抢占画面。
2. 用户不使用产品内部术语，只输入：`Please make a document called A small launch note with the body Ship one careful step at a time. Then tell me where I can see what you changed and where I can edit it.`
3. 真实受管网关完成 `create_document` 后，右侧 Activity 侧幕自动打开，显示 `Activity`、`1 touched`、文档名称和 `Created`。
4. 助手明确告诉用户：在 Chat 右侧 Activity 查看本次改动；到左侧 Library 找到文档并打开编辑。用户不需要预先知道 Activity、touchpoint 或 Library 这些实现概念。
5. 中心工具结果、Activity 条目和助手文案指向同一文档；LLM wire 确认正文 `Ship one careful step at a time.` 没有被名称替换或丢失。

## Discoverability judgment

- 入口发现是由用户目标自然触发，不依赖设置页、教程或内部术语；侧幕出现后其标题、计数和实体行可直接解释发生了什么。
- “查看改动”和“编辑结果”被分成两个正确的产品路径：近期活动先指向 Activity，资源浏览/编辑指向 Library，没有把可见导航误称为 Documents。
- 最终画面中 Activity 侧幕、中心正文、工具卡和助手说明互相印证；无重复操作、错误路径、内部调试词或需要用户猜测的下一步。
- 三档行为的范围仍由既有真实路径覆盖：`Never` 不自动打开但保留 Toggle，`First per chat` 首次活动打开，`Every time` 每次活动打开；本证据专门补充“不知道内部词汇的普通用户”能找到正确入口这一层。

## Five-channel cross-check

- frames: Computer Use 读取真实 App AX 树并观察最终帧；录屏封存于同一 session，截图为 `EDGE-304-l5-final.png`。
- backend: `backend.log` 298 行；未发现应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 93 行；三流 tap 记录真实活动的 durable 事件，Activity 的文档条目与中心结果一致。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 是已分类的 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断。
- LLM wire: `llm.jsonl` 19 行；managed challenge/install/models/chat 均成功；chat body 保留用户正文，未发生额外的纠错调用。

## Judgment

- L5 `pass (G1)`: 普通用户从自然语言目标出发，能够发现“哪里查看改动”和“哪里编辑文档”的正确入口；真实画面、助手指引、Activity 条目和后端/LLM 数据一致。
- 本证据不把设置页标签本身冒充为发现性，也不把已有 L3/L4 证据重复计算为本格结论。
