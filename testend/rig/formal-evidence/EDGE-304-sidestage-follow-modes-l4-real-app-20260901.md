# EDGE-304 侧幕跟随三档：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-155611`
- data: `/private/tmp/anselm-data-edge304-l4-real-20260901-r3`
- workspace: `ws_85b0f01209d953e4`
- app/window: `25794/13122`
- backend/ssetap/llmtap: `25318/25373/25285`
- screen: `screen.mov`, 1440x810 window capture, 60fps, 329.678333s
- final frame: `evidence/EDGE-304-first-per-chat-final.png`

## Product path

1. 真实 App 的 Chat 设置选择 `First per chat`，新建干净对话。
2. 输入真实用户目标：`Create a document named EDGE304 first visual check with body one line.`
3. 首个 `create_document` 活动登台时，Activity 侧幕自动揭示；最终状态显示 `Activity`、`1 touched`、单条文档 `Created`。
4. 中心结果显示同一文档名称、路径和正文 `one line`；没有重复的 create/edit 卡，也没有模型把名称误写进正文。
5. 同一台架前序真实路径已覆盖 `Never`（不自动打开但保留 Toggle）和 `Every time`（活动时自动打开）；三档的开关语义和顺滑证据见 `EDGE-304-sidestage-follow-modes-l3-real-app-20260829.md`。

## Visual craft judgment

- Activity 侧幕使用既定 AnIsland 皮肤：外边距、内缩、圆角、阴影和主工作区的层级清楚，没有贴边、裁切或悬空的白带。
- 标题、`1 touched`、更多/关闭控件和活动行按同一内边距对齐；活动图标、文档名和 `Created` 状态在同一行，信息层级不互相争抢。
- 侧幕展开后中心工作区保持稳定，没有横向跳变、重排闪烁或重复面板；正文区域、输入框和左右岛之间留白连续。
- 长文档名在活动行中以省略处理，未侵入状态列；最终截图中无文字重叠、溢出或低对比度控件。
- `Never` 的空侧幕状态仍保留可发现的 `Toggle panel`，不是用视觉隐藏冒充关闭；`First per chat` 与 `Every time` 的入口和面板造型一致。
- 侧幕外圆角遵循 `AnRadius.chip=12` 的活动组件语义，未误用窗口级 `AnRadius.window=20`；这保持了组件与窗口的半径梯度。

## Five-channel cross-check

- frames: Computer Use 逐状态观察 + 同一 session 的窗口专属录屏；首个活动期间侧幕连续揭示，最终截图为真实 App 稳定态。
- backend: `backend.log` 1111 行；未发现应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 296 行；三流 tap 有连接和 durable 帧，Activity 的 `document.created` 与中心结果一致。
- frontend: `frontend.log` 5 行；无 Flutter/Dart/RenderFlex/Unhandled 红线，唯一 error 是已分类的 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断。
- LLM wire: `llm.jsonl` 34 行；managed challenge/install/models 与真实 chat 请求均成功，create 请求只携带正文 `one line`。

## Judgment

- L4 `pass (C4)`: 三档共用的 Activity 视觉系统在真实 App 中通过间距、层级、对比度、圆角、对齐、长文本省略和稳定布局检查；没有为某一档单独降低标准。
- 本证据只判视觉 craft，不把 L5 的用户发现性或 L3 的过渡测量重复冒充为本格结论。
