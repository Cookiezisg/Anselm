# EDGE-327 workspace 热切换三拍：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260901-12/sessions/20260901-231217`
- recording: `screen.mov`, `248.018333s`
- law: `G1`（普通用户路径可发现）
- verdict: `pass` for L5

## Blind product path

以普通用户目标“把当前对话切到另一个 workspace，并确认目标 workspace 没有带入当前对话”为验收目标，不使用 workspace ID、后端 API、内部工具名或实现术语。真实 App 的 Chat 壳底部持续显示当前 workspace 控件；点击后菜单直接列出可读的 workspace 名称，并用当前态标识当前项。用户无需知道路由、`go('/')`、post-frame 或任何实现细节即可选择目标。

选择目标后，App 清楚落到目标 workspace 的空 Chat landing：目标名称在壳层生效，composer 和空态标题可见，源对话正文、源列表状态及旧活动岛没有残留。目标空态等待约 `6s` 后仍稳定；切回 source 后，原对话重新出现在 Recents，用户能理解“切换 workspace”而不是“删除/移动对话”。

## Five-channel cross-check

- **frames / Computer Use**: 同一真实录屏包含可发现的 workspace 控件、菜单当前态、目标选择、目标空态和 source 回访；窗口中没有内部 ID 或实现术语作为用户要求。
- **backend**: `backend.log` 共 `793` 行；source/target 的 workspace、conversation 和 activation 读取正常，无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: `sse.jsonl` 共 `69` 帧，`entities`、`messages`、`notifications` 三流均连接；messages durable seq=`1..8` 单调无重复。
- **frontend console**: `frontend.log` 共 `3` 行，仅正常启动诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 错误。
- **LLM wire**: managed gateway 的 challenge/install/models 和 source 对话 completion 均为 HTTP `200`；切换动作没有多余 LLM 请求。
- **durable truth**: source 对话只属于 source workspace，target 初始无对话；切换和回访结果与 REST/持久化状态一致。
- **rig lifecycle**: 操作前 `rig-check.sh` 全项通过，`rig-down.sh` 正常封口，App/backend/ssetap/llmtap 均被 conductor 收台，session 保留完整录屏与 journals。

## Verdict

`L5 pass (G1)`。workspace 切换入口、当前态、目标选择和结果反馈无需内部知识即可理解和完成；本结论只覆盖发现性，不把视觉 craft 或动态稳定性重复计入本格。
