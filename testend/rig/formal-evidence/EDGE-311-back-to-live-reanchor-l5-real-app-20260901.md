# EDGE-311 归队重钉贴底：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-195659`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_8036e85c1fb2eac8`
- recording: `screen.mov`, `70.713333s`, 60fps
- frame samples: `evidence/edge311-l5-png/f027.png` ... `f047.png`

## Ordinary user goal

在不使用内部 API、消息 ID、窗口模式或实现术语的情况下，用户目标是：“我想回到很久以前的一段讨论，查看那条消息，然后回到最新内容继续。”

## Walkthrough

1. 从 Chat 的 Recents 打开目标讨论；侧栏的 `Scenes` 入口在对话头部可见，不需要猜 URL 或内部名称。
2. 打开 `Scenes` 后，场次按用户可读的消息摘要和时间排列；选择很久以前的目标后，画面显示目标消息、整行高亮和 `Jump to present`。
3. `Jump to present` 直白表达回到最新内容的动作；点击后历史窗口消失、最新内容恢复、入口消失，用户目标完成。

## Product judgment

- 入口和状态变化形成完整闭环：Recents → Scenes → 历史目标 → Jump to present → 最新内容。
- 用户不需要知道 `?around=`、`retryOf`、`windowMode`、消息 ID 或后端分页；产品表面给出了下一步动作。
- 历史态没有把用户困在旧窗口；归队后的画面没有残留按钮，也没有要求再次手动滚动寻找最新内容。
- 归队动作后的稳定录屏样本未出现持续变化；整窗 diff 的高变化只发生在打开场次、深跳和点击归队动作窗口，`f047` 后至录屏结束没有超过 `0.0005` 的变化输出。

## Five-channel cross-check

- **frames / Computer Use**: AX 依次确认可见 `Scenes`、场次摘要、`Jump to present`；归队后 AX 树移除该按钮并恢复最新 head，截图和录屏来自同一 session。
- **backend**: backend journal 共 274 行，无 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 连接 `notifications`、`entities`、`messages` 三条流并全部以 EOF 正常断开。
- **frontend**: frontend journal 无 Flutter、RenderFlex、RenderBox、Unhandled 或应用级异常；仅保留已知 macOS IMK 宿主诊断。
- **LLM wire**: llmtap 已真实接管受管 key 生命周期；本格是历史导航，不触发 completion，不伪造模型结果。
- **durable truth**: 归队前后只改变读取窗口和视口状态，不新增或修改持久化消息；既有 REST/SQLite 证据保持一致。
- **rig lifecycle**: `rig-check.sh` 在操作前全项通过；`rig-down.sh` 封口录屏并停止 App、backend、ssetap、llmtap，session journal 完整。

## Verdict

- **L5 `pass (G1)`**: 普通用户只凭产品表面即可发现历史场次和回到最新内容的入口，且反馈闭环清晰、不会被留在旧窗口。
