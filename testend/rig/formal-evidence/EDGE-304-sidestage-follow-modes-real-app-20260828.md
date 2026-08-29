# EDGE-304 侧幕 Follow 三档：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-040938`
- data: `/private/tmp/anselm-data-edge304-20260828-r1`
- workspace: `ws_d5c4ad151a941be7`
- app PID: `59497`; window: `4643`; recorder: `59540`
- backend PID: `59044`; ssetap: `59066`; llmtap: `59020`

## Product walk

1. 真实 onboarding 创建 `EDGE-304 follow modes` 工作区。空 Chat 没有 Activity 内容，右岛入口不存在。
2. 真实创建 `EDGE-304 default follow note` 后，首条 `create_document` 活动使 Activity 侧幕展开；打开侧幕的 More actions，三档菜单 `Never`、`First per conversation`、`Every time` 均可发现。
3. 选择 `Never`，先明确收起已经打开的侧幕，再开全新对话并创建 `EDGE-304 never clean note`；活动到达后侧幕保持收起，头部只显示 `Toggle panel`，没有自动弹出。
4. 选择 `First per conversation`，关闭侧幕后开全新对话并创建 `EDGE-304 first-per-conversation note`；首次活动自动展开。手动关闭后在同一会话创建 `EDGE-304 first-per-conversation second note`，侧幕保持收起，入口仍在。
5. 选择 `Every time`，关闭当前侧幕后开全新对话并创建 `EDGE-304 every-time fresh note`；首次活动再次自动展开，画面显示 `Activity`、`1 touched`、文档名和 `Created`。
6. 额外验证了手动关闭优先于自动模式：在已有活动会话中切到 `Every time` 后手动关岛，后续活动没有强制弹窗；这是与 EDGE-305 手动关闭规则一致的组合行为，不是模式失效。

## Five channels

- frames: `screen.mov` 由 conductor 绑定窗口 `4643` 录制；覆盖空态、三档菜单、Never 收起态、First 首次/再次活动和 Every time 新会话展开态。
- backend: `backend.log` 513 行；无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- SSE: `sse.jsonl` 864 行；messages durable seq `1..105`，entities `1..4`，notifications `1..17`，包含多个 conversation/message close 与 document `touchpoint` signal。
- frontend: `frontend.log` 4 行；无 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- LLM wire: `llm.jsonl` 67 行；challenge/install/models 各真实通过，38 次 chat completion 均为 200。

## Verdict

- L1 `pass`: 三档入口可发现且行为差异符合产品规则，满足 G1。
- L2 `pass`: 三档行为、Activity 触点、中心 transcript、SSE 与真实网关执行相互一致，满足 F1。
- L3-L5: `na`，本格聚焦 Follow 模式语义与门控，不把本次路径冒充独立顺滑、视觉 craft 或可发现性深评。
