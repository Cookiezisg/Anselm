# EDGE-310 深跳 `?around=` 整窗替换：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-062450`
- data: `/private/tmp/anselm-data-edge310-20260828-r1`
- workspace: `ws_628fab9117677c0b`
- conversation: `cv_9b56dd0fba1a7efe`
- App/window: `77687/5044`
- recording: `screen.mov`, duration `80.973333s`
- frame evidence: `evidence/edge310-deep-jump.png`, `evidence/edge310-back-to-present.png`

## User-purpose walkthrough

1. 在真实 App 打开一条包含 64 条消息的长对话，打开 Scenes/场次条，选择一条不在当前头部窗口的老消息。
2. App 通过真实 `?around=m_edge310_48` 路径请求整窗，替换当前 transcript 窗口；目标消息只出现一次，并落在目标锚位，画面显示整行的浅蓝高亮。
3. 深跳后显示 `Jump to present`，说明当前处于历史窗口而不是假装仍在实时尾部；点击后恢复最新头部窗口，按钮消失。

## Five channels

- **frames / Computer Use**: 关键帧由 Computer Use 直接保存。`edge310-deep-jump.png` 显示老消息一次、整行高亮和 `Jump to present`；`edge310-back-to-present.png` 显示最新消息头部且无回现场按钮。最终 AX 读取 `targetCount=1`、`hasJumpToPresent=true`，回现场后 `hasJumpToPresent=false`。
- **backend**: 同一 session 的 backend journal 共 142 行；真实 App 的 messages、anchors、touchpoints、workdir、todos 和场次导航请求均返回 200，无 WARN、ERROR、panic 或 FATAL。
- **SSE**: 三路 SSE witness 在同一 workspace 建立并在收台时正常断开；本格是 transcript 导航，不需要伪造一轮 LLM 对话或额外写入消息，未把无关缺帧当成产品失败。
- **frontend**: frontend journal 只有 Dart VM 启动和已知 macOS `IMKCFRunLoopWakeUpReliable` 系统行；没有 Flutter、Dart、RenderFlex、Unhandled 或应用级错误。
- **LLM wire**: llmtap 在同一 session 已启动并处于 ready；本格仅测试历史窗口导航，没有触发模型调用，因此没有虚构 completion 证据。
- **rig lifecycle**: App 运行期间 `rig-check` 全项通过；`rig-down` 完成录屏并停止 App、backend、ssetap、llmtap，无残留进程。

## Test-data note

测试长卷通过真实 API 建立会话，并在隔离数据目录中补齐消息与 blocks。第一次准备数据误用了不带时区的 SQLite 时间格式，导致时间游标把目标错误地同时落入 newer 半和显式目标，第一次画面不计入结论；随后将全部时间修正为真实 Go 持久化使用的 `...+00:00` 格式，并以同一隔离数据重新启动 App 完成干净复跑。修正后 REST `?around=` 返回 31 条窗口数据，目标 id 恰出现一次；没有修改产品代码，也没有用前端 fixture 回放。

## Verdict

- **L1 pass**: 深跳整窗替换、目标锚位、高亮、历史态回现场入口和返回头部均符合实现契约。
- **L2 pass**: Computer Use 关键帧、AX 状态、真实 REST、backend journal、三路 SSE、frontend journal、LLM tap 生命周期和统一 rig session 对齐；目标只出现一次，回现场状态正确。
- **L3-L5 na**: 本格证明深跳数据与窗口状态正确，不冒充独立顺滑度测量、视觉 craft 审查或从零盲走可发现性通过。
