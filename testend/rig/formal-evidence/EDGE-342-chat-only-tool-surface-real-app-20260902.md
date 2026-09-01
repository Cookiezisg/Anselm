# EDGE-342 · chat-only 模型的工具面 · real App L3/L4/L5

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-06/sessions/20260902-015651`
- 真实 App 由当前 checkout 构建并由 conductor 启动；`screen.mov` 为连续窗口录制，
  时长 `346.335000s`，录制结束后正常封存。
- workspace 为隔离 acceptance 数据目录；模型 fixture 只在本机监听，未使用真实
  外部供应商凭证或发送用户数据。

## Stop-and-fix

首轮真实操作发现：当前 workspace 默认模型是受管 Anselm Auto 时，切换到 External
model 后，`ModelPickerPanel` 仍收到受管模型作为 `initial`。由于外部模型目录不含该
凭证，页面显示了凭证但模型阶段为空，用户无法完成选择。已在
`frontend/lib/features/settings/ui/panels/models_keys_panel.dart` 增加归属校验：只有
当前初始模型同时存在于外部 capability 列表时才传入 picker，否则从空选择开始。
同时在聊天模型菜单为 `tools=false` 模型显示 `Chat only — no tools`，避免用户误以为
该模型能够执行工具。修复后重新构建并完成以下完整路径。

## 产品路径

1. 在 Settings → Models & keys 刷新模型目录，进入 Dialogue → Change → External model。
2. 选择隔离凭证 `EDGE342 local chat-only`，模型阶段出现
   `edge342-chat-only`，并显示 `Chat only — no tools`；点击模型后 Apply，设置摘要
   正确回显模型与凭证。
3. 回到 Chat，打开模型菜单，普通用户可直接看到 `edge342-chat-only` 和同一条
   `Chat only — no tools` 说明；选择后聊天头回显该模型。
4. 连续发送两轮普通文本。两轮都在真实 App 中产生用户消息和 assistant 回复，回复
   为隔离 fixture 的 `EDGE342 chat-only reply`，Composer 在每轮结束后恢复可用。

## L3 顺滑判定（A1）

设置页从凭证阶段到模型阶段不再出现空选择死路；Apply 后回到 Chat，模型选择、发送、
流式回复和 Composer 复位均连续完成。最终稳定帧约在录屏 `265s`、`325s`、`335s`
处抽查，未见整页闪烁、字段跳变、回复完成后输入框失焦或发送按钮残留。两次消息
POST 都在提交后立即进入流式收尾：backend 记录的请求状态均为 `202`，对应 SSE
durable 序列分别为 `1..6` 与 `7..12`，每轮均有 user open/close、assistant open、
text delta、text close、assistant close。

## L4 视觉 craft 判定（C4）

模型菜单同时呈现模型名、凭证上下文和能力边界，chat-only 徽标没有挤压选择控件或
改变菜单层级。最终帧中两轮消息的气泡、回复正文、底部 Composer 和模型头部均保持
稳定间距，没有遮挡、裁切、重叠或异常空白；“Chat only — no tools”是明确的能力
说明，而不是含糊的失败色块。设置页的外部模型表单在修复后模型选择控件有真实可选
内容，未留下凭证已选但模型为空的视觉死态。

## L5 可发现性判定（G1）

普通用户的目标是“选择一个只能聊天的外部模型并开始对话”。不需要了解 capability
字段、`tools=false`、内部模型 ID 或后端路由：用户能从 Settings 的 External model
路径完成凭证和模型选择，再从 Chat 的模型菜单识别该模型；能力限制在选择前和聊天中
都被明示。聊天仍可完成，限制没有被伪装成可执行工具，也没有用隐藏失败让用户自行
猜测为什么工具不出现。

## 五通道交叉证据

- **帧 / Computer Use**：上述设置、模型菜单、两轮消息和稳定收尾均来自同一连续
  `screen.mov`；录制窗口归属于 conductor 启动的 Anselm App。代表稳定画面为录屏
  `265s`、`325s`、`335s` 附近的抽帧。
- **Backend journal**：session 的 `backend.log` 记录两次
  `POST /api/v1/conversations/{id}/messages` 为 `202`。两次 `llm context sampled`
  均为 `tool_schema_bytes=0`；日志没有应用级 panic、FATAL 或 ERROR。
- **SSE witness**：独立 `ssetap` 在同一 workspace 连接 messages、entities、
  notifications 三流；messages durable 序列为 `1..6` 和 `7..12`，每轮包含两次
  delta 与完整 close，结束时三流均正常断开。
- **Frontend console**：AX 观察到模型菜单中的
  `edge342-chat-only` 与 `Chat only — no tools`，最终 transcript 包含两轮用户
  消息和两轮 assistant 回复。`frontend.log` 没有 Flutter/Dart/RenderFlex/
  Unhandled/Exception 应用级红线；其中 macOS IMK/TSM 输入法诊断归类为宿主噪声。
- **LLM wire**：本地 fixture 独立 journal=`/private/tmp/anselm-edge342-wire.jsonl`
  记录真实 `POST /v1/chat/completions`，请求 `model=edge342-chat-only`，第二轮请求
  含四条消息且没有工具调用字段。session 的 `llm.jsonl` 同时记录了受管 Anselm
  Auto 的 challenge/install/models 和自动标题请求；对话 completion 走隔离外部
  fixture，因此不把受管自动标题误读为本格的对话模型请求。

## 台架收口

`rig-check.sh` 在运行中确认 backend 归属、App/window 归属、三流 SSE、managed
llmtap wiring、LLM recorder 和屏幕录制均正常；`rig-down.sh` 正常封口，录屏可读，
conductor-owned backend、App、tap、recorder 均已停止。

Computer Use 的 `type_text` 对中文输入出现字符丢失、一次 `set_value` 没有触发真实
发送，是测试主机输入路径限制；后续用可观察的 ASCII fixture 文本重新完成发送，未将
该 harness 现象归因于产品，也未据此修改产品行为。
