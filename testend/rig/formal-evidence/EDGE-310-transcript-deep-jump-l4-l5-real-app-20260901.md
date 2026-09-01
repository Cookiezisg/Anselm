# EDGE-310 深跳 `?around=`：L4/L5 真实 App 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-193428`
- data: `/private/tmp/anselm-data-edge310-l4-20260901`
- workspace: `ws_b8f0453cd7c4c0c0`
- conversation: `cv_8036e85c1fb2eac8`
- recording: `screen.mov`, duration `87.915000s`, 60fps
- frame samples: `sessions/20260901-193428/evidence/edge310-frames/t40.jpg`, `t50.jpg`, `t60.jpg`, `t70.jpg`

## Product path

1. 在真实 App 打开包含 64 条消息的长对话，打开 `Scenes` 场次导航。
2. 选择最早场次和中段场次，真实请求 `?around=<messageId>`，整窗替换为目标附近的历史内容。
3. 深跳后显示 `Jump to present`，历史态入口和当前内容同时可见；继续向前滚动后，窗口追加更近的历史页，没有重复消息或视口跳回现场。

## L4 · 视觉 craft

- 最早目标跳转后的 Computer Use 帧显示 `edge310_msg_00` 到 `edge310_msg_06` 的连续内容，目标行位于窗口首行并带整行浅蓝锚定高亮；`Jump to present` 是独立、可辨识的胶囊入口。
- 中段目标跳转后的帧显示 `edge310_msg_28` 到 `edge310_msg_42`，`edge310_msg_32` 位于首行高亮区域；对应样帧为 `t60.jpg`。行间距、左右对齐、消息气泡圆角与 composer 几何保持稳定，没有旧窗口与新窗口叠加。
- 通过滚动窗口向前续翻后，界面显示最新追加的历史行，仍保持单一列顺序；没有重复行、半行、溢出或非用户触发的二次定位。
- 视觉判定援引 `C4`：pill、消息卡片、岛壳与 composer 的圆角层级和同心内缩清晰，目标高亮没有破坏行几何；录屏封口后抽查稳定帧，静止画面没有漂移。

## L5 · 可发现性

- 从普通用户视角，场次入口直接标为 `Scenes`，位于对话头部；打开后每个场次以用户可读的首行摘要和相对时间列出，不要求用户知道 `?around=` 或内部消息 ID。
- 深跳后 `Jump to present` 直接出现在对话底部，标签说明返回现场，不依赖隐藏快捷键或开发术语。
- Computer Use 的 AX 树同时暴露 `Scenes` 与 `Jump to present` button；场次菜单在跳转后自动收起，入口仍可再次打开。
- 可发现性判定援引 `G1`：普通用户不读内部文档即可从可见命名和位置走到历史场次与返回现场。

## Five-channel cross-check

- **frames / Computer Use**: 同一 session 的录屏和 AX 观察覆盖场次打开、最早目标、中段目标及向前续翻；样帧保存在 session evidence 目录。
- **backend**: 同一 session 的 backend journal 记录真实 workspace、anchors 和 messages 请求；无 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: ssetap 同一 workspace 连接 `notifications`、`entities`、`messages` 三路并在收台时正常断开；本格没有伪造 LLM 回合。
- **frontend**: frontend journal 只有 Dart VM 启动和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断；没有 Flutter、Dart、RenderFlex、Unhandled 或应用级红行。
- **LLM wire**: llmtap 在同一 session ready；本格只验证历史导航，不触发模型调用，不虚构 completion 证据。
- **rig lifecycle**: `rig-check` 在动作后通过五通道物理归属检查，`rig-down` 封口录屏并停止 App、backend、ssetap、llmtap，无残留进程。

## Data truth

校正后的隔离数据库使用生产驱动写出的 `2026-09-01 10:23:31+00:00` 时间格式。REST 对最早、中段、最晚三个目标分别返回 `16/31/16` 条窗口数据，目标 id 各出现恰好一次；中段向前续翻返回严格更新的页，最晚窗口无 `hasNewer`。第一次用无时区 SQLite 文本准备夹具时目标重复，首轮画面保留为伪红并明确排除；未修改产品代码，也未用 fixture 回放代替真实 App。

## Verdict

- **L4 `pass (C4)`**: 目标窗口、历史态 pill 和滚动续翻的真实界面几何稳定，视觉层级清楚，没有非用户触发跳变。
- **L5 `pass (G1)`**: `Scenes` 与 `Jump to present` 的命名、位置和结果对普通用户可直接理解并操作。
