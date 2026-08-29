# EDGE-342 · chat-only 模型的工具面 · 真实 App 五通道复验

## 范围与环境

- 真实 Flutter macOS App，由 acceptance conductor 启动并录制；录屏封存于
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-213419/screen.mov`。
- 同一 session 托管 backend、三路独立 SSE witness、LLM witness 和 frontend console；
  收台后 `rig-check` 通过，`rig-down` 无残留。
- 为构造一个真实 `tools=false` 模型，dialogue 走本机隔离的 OpenAI-compatible provider，
  不消耗 managed gateway 配额；自动标题仍走工作区 utility/managed 路由。

## 正向路径：对话使用 chat-only 模型

1. App 的模型菜单显示 `qwen-vl-ocr` 与 `EDGE-342 local chat-only`，用户明确选择它。
2. App 发送 `Reply with exactly CHATONLYOK`，对话完成，界面显示用户消息、助手回答、
   `qwen-vl-ocr` 模型标签和可继续发送的 Composer。
3. provider wire `/private/tmp/edge342-provider-wire.jsonl` 的对应 chat request 明确为
   `model=qwen-vl-ocr`，消息数为 2，未出现 `tools` 或 `tool_choice`；因此“chat-only”
   不是 UI 自述，而是实际请求能力。
4. SSE messages durable sequence 为 `7..12`，包含 user open/close、assistant open、
   text open/close 和 assistant completed close；notifications 对应 conversation 创建、
   model override 与自动标题帧，均按流单调推进。`seq=0` 的文本 delta 未推进 durable 游标。
5. backend journal 的对应 chat 采样记录 `route=text`、`tool_schema_bytes=0`，无应用级
   WARN/ERROR/panic/fatal；frontend journal 无 Flutter/Dart/RenderFlex/Unhandled/Exception
   红线，仅有 macOS IMK 宿主通知。

## 负向路径：chat-only 模型不能保存为 Agent 默认

- App 设置页尝试把同一个 `tools=false` 模型应用到 Agent 默认，服务端真实返回 HTTP `422`，
  错误码为 `MODEL_NOT_AGENT_CAPABLE`。
- Agent 默认仍为原来的 `anselm-auto · Anselm Free`；dialogue 默认不受影响。
- App 将错误本地化为一行完整可读的 `不能当智能体：请改选支持工具的模型`，没有把后端
  英文错误或被截断的半句展示给用户。
- 同一行为由 targeted backend tests 和 `s2_models_keys_test.dart` 回归锁定；成功对话和
  失败 Agent 设置之间没有 retry、隐式替换或持久化副作用。

## 重要排除：自动标题不是对话模型证据

本 session 的 llmtap 还记录了 `anselm-auto` 的 `/v1/chat/completions` 请求，但其 system
prompt 是自动标题提示，发生在对话完成之后，不能用来推断本次 chat 的 dialogue model。
对话模型证据以本机 provider wire 为准，避免把 utility 路由和 dialogue 路由混为一谈。

## 五级裁决边界

- L1 focused 契约保留原证据：`EDGE-342-chat-only-tool-surface-20260826.md`。
- 本次新增 L2 真实 App + 五通道证据：界面选择、服务端拒绝、实际对话 wire、SSE、backend
  journal、frontend console 和最终录屏相互一致。
- L3-L5 不因同一 session 自动冒充独立的全局顺滑、craft 或可发现性结论；若后续把这些
  维度作为本条的独立验收目标，必须重新以对应法条和测量证据入账。
