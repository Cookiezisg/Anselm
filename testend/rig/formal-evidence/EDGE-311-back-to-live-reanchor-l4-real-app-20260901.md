# EDGE-311 归队重钉贴底：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-194553`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_9b56dd0fba1a7efe`
- recording: `screen.mov`, `72.765000s`, 60fps
- frame samples: `evidence/edge311-l4-png2/f018.png` ... `f073.png`

## Product path

1. 真实 App 打开 `EDGE-310 深跳验证长卷`，从 Scenes 选择老的目标消息。
2. 深跳窗口显示目标消息、整行浅蓝高亮和 `Jump to present`；目标没有重复，读者明确知道自己已离开现场。
3. 点击 `Jump to present` 后，历史窗口整体替换为最新 head，入口消失，最新消息回到可见尾部，滚动条贴底。

## Visual craft review

- 深跳态的高亮覆盖目标行的完整视觉行高，圆角、内边距和正文对齐一致；不遮挡目标文字，也没有出现第二个目标副本。
- `Jump to present` 是独立、居中的浮动入口，与消息内容保持足够间距；它只在 detached window 出现，归队后消失，不留下幽灵控件。
- 归队后的最新 head 与 composer 之间保持稳定留白，消息气泡、侧栏、标题和滚动条没有二次布局回弹；贴底状态在录屏末尾仍保持。
- 逐帧测量使用通道容差 8、阈值 `0.0005`。用户动作窗口的变化为：`f018→f019=0.01680`、`f019→f020=0.05182`、`f025→f026=0.04941`、`f035→f036=0.04235`、`f036→f037=0.15905`、`f037→f038=0.06133`、`f045→f046=0.06042`、`f046→f047=0.05268`；这些分别对应打开/场次展开/深跳/归队动作。
- 归队完成后的稳定段 `f047→f073` 没有任何超过 `0.0005` 的整窗变化；没有二次重建、视口回弹、旧窗口叠加或入口反复出现。ROI `760,120,2200,1450` 的超过阈值变化同样只落在上述动作窗口。

## Five-channel cross-check

- **frames / Computer Use**: AX 确认深跳态有 `Jump to present`，点击后 AX 树移除该按钮并恢复最新 head；关键帧显示高亮、入口、归队后贴底三种状态。
- **backend**: 同一 session 的 backend journal 共 289 行，无 WARN、ERROR、panic 或 fatal；收台走 graceful shutdown。
- **SSE**: ssetap 连接 `notifications`、`entities`、`messages` 三条流并全部以 EOF 正常断开；本格只导航已落盘 transcript，没有伪造业务事件。
- **frontend**: frontend journal 只有 Flutter 启动信息和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主诊断；没有 Flutter、RenderFlex、Unhandled 或应用级异常。
- **LLM wire**: llmtap 已真实接管受管 key 的生命周期；本格不触发 completion，不把空 completion 当作产品证据。
- **durable truth**: SQLite 中 conversation `cv_9b56dd0fba1a7efe` 保持 64 个已完成消息、64 个有序 text block，没有 pending/streaming/error/cancelled 消息；归队是视图重定锚，不新增或修改消息。
- **rig lifecycle**: `rig-check.sh` 在操作前全项通过；`rig-down.sh` 封口 72.765000 秒录屏并停止 App、backend、ssetap、llmtap，session journal 完整。

## Verdict

- **L4 `pass (C4)`**: 归队动作前后的视觉层级、间距、对齐、状态入口和稳定贴底均达到 craft bar；所有整窗变化都能归因于明确用户动作，稳定段无隐藏跳变。
- 本证据不替代 L5 可发现性判断；L5 仍按既有顺序门单独处理。
