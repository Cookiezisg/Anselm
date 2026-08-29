# EDGE-311 归队重钉贴底：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-091845`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_9b56dd0fba1a7efe`
- App/window: `81847/5138`
- recording: `screen.mov`, duration `66.156667s`
- frame evidence: `evidence/edge311-deep-jump.png`, `evidence/edge311-back-to-live.png`

## User-purpose walkthrough

1. 在真实 App 打开长对话，展开 Scenes，选择当前头部窗口之外的老消息，进入深跳窗口。
2. 深跳窗口显示老消息一次、目标高亮和 `Jump to present`；不等待额外分页、不切换海洋，立即点击归队入口。
3. 归队后历史窗口被替换为最新 head，`Jump to present` 消失，最新消息回到可见尾部，垂直滚动条重新贴近底部。整个动作没有新增对话、没有改变持久化消息，也没有把读者留在历史窗口。

## Five channels

- **frames / Computer Use**: `edge311-deep-jump.png` 是深跳目标帧，显示目标单行高亮和 `Jump to present`；`edge311-back-to-live.png` 是快速归队帧，显示最新头部内容、入口消失和贴底视口。AX 读取在深跳态确认 `Jump to present` 存在，归队后确认该控件消失。
- **backend**: 同一 session 的 backend journal 共 129 行；真实 App 的会话消息、anchors、touchpoints、workdir、todos 和场次导航请求均完成，未发现 WARN、ERROR、panic 或 FATAL。
- **SSE**: ssetap 在同一 workspace 连接 notifications、messages、entities 三条流，收台时三流均以 EOF 正常断开；本格是已落盘历史导航，不需要伪造消息写入或把无关流量当成业务证据。
- **frontend**: frontend journal 共 4 行，仅包含 Dart VM 启动和已知 macOS `IMKCFRunLoopWakeUpReliable` 系统提示；没有 Flutter、RenderFlex、Unhandled 或应用级异常。
- **LLM wire**: llmtap 在真实受管配置下启动并 ready；本格只导航已落盘 transcript，未触发 LLM，因此没有伪造 completion 成功。
- **rig lifecycle**: `rig-check` 在 App 运行期间全项通过，明确无外部窗口覆盖录屏区；`rig-down` 完成 66.156667 秒录屏并停止 App、backend、ssetap、llmtap，无残留进程。

## Verdict

- **L1 pass**: 归队动作沿既有 back-to-live 路径退出历史窗口、重拉 head 并重置滚动锚点，符合 F5 归队重钉契约。
- **L2 pass**: Computer Use 关键帧、AX 状态、真实 REST/backend journal、三路 SSE、frontend journal、LLM tap 生命周期和同一 rig session 对齐；快速重拉没有留下历史态或漂移视口。
- **L3-L5 na**: 本格证明归队后的窗口与贴底状态，不冒充独立顺滑度测量、视觉 craft 审查或从零盲走可发现性通过。
