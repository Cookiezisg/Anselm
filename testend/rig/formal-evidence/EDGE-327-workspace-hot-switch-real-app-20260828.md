# EDGE-327 · workspace 热切换三拍 · 真实 App L2

## 结论

真实 Flutter macOS App 在一条已打开的深链对话中切换到另一工作区。切换后旧对话立即离开视图，应用进入目标工作区的空 Chat landing；目标工作区名册、对话列表和三路 SSE 均切换到目标 workspace，未出现旧对话残留、跨 workspace 404、卡死或旧右岛活动泄漏。

本轮只新增 L2 五通道裁决。L3-L5 保持 `na`：没有独立动作帧到首反馈帧测量、ROI craft 数字或从零盲走，不把热切换正确冒充为完整顺滑、视觉 craft 或可发现性通过。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-023548`
- 源 workspace：`ws_8dc815e248eb19e2`（含 `演示对话`）
- 目标 workspace：`ws_3222527f383249be`（`热切换目标`）
- data：`/private/tmp/anselm-data-edge327-20260828-r1`
- 录屏：`screen.mov`，收台后 finalize；五通道由同一 manifest 归属
- 网关：`https://api.anselm.website`；managed challenge/install/models 均经 llmtap 返回 200

## 产品路径

1. 通过真实工作区菜单确认源 workspace `演示工作台`，点击其中已有的 `演示对话`，进入 `/chat/:id` 深链；证据 `deep-link-before-switch.jpg`。
2. 在深链页面打开工作区菜单，直接点击目标 workspace `热切换目标`。
3. 切换完成后，中心不再显示源对话，左侧 workspace 名称变为 `热切换目标`，页面回到“想从哪里开始？”空 Chat landing；证据 `landing-after-switch.jpg`。
4. 后端真实请求记录先读取源对话，再对目标 workspace 执行 `:activate`，随后目标 workspace 下的 conversations/workdir-groups 读取均成功，无旧 workspace 资源请求回流。

## 五通道证据

- **画面**：`screen.mov` 及 `deep-link-before-switch.jpg`、`landing-after-switch.jpg`，覆盖深链、菜单选择和目标 landing。
- **后端**：backend journal 无 `WARN|ERROR|panic|FATAL`；源 `conversation` 读取与目标 `workspace:activate`、列表重取均为 200。
- **SSE**：ssetap 同时观察全部 workspace，源与目标三路 messages/entities/notifications 均连接；workspace 切换后目标 workspace 的观察面仍在，未丢三流。
- **前端 console**：frontend journal 无 `Unhandled exception`、Dart/Flutter、RenderFlex、RenderBox 或 overflow 红线；唯一 `IMKCFRunLoopWakeUpReliable` 是 macOS 输入法宿主提示，未伴随 Flutter/Dart/布局异常，按既有宿主噪声分类记录。
- **LLM wire**：managed challenge/install/models 全部经过 llmtap 且为 200；本场景不调用 chat completion。

## 收台与裁决

`rig-check` 与 `rig-down` 通过，录屏正常 finalize，收台后无 Anselm、Flutter、tap 或 recorder 残留。L2 使用 `G2` 写入；L3-L5 按证据边界保持 `na`。
