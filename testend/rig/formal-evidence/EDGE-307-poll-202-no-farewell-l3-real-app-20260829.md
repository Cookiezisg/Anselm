# EDGE-307 poll 型 202 不谢幕：L3 真实帧顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-163519`
- data: `/private/tmp/anselm-data-edge307-l3-20260829-r1`
- screen: `screen.mov`, 2784x1808, 60fps, 225.138333s
- frame samples: `evidence/EDGE-307-l3-live.png`, `evidence/EDGE-307-l3-terminal.png`, `evidence/EDGE-307-l3-settled.png`
- workflow: `wf_55277fc9489a4143`, `edge307_poll_202_l3`
- flowrun: `fr_9bd1ea1577bb2426`

## Product path

1. 真实 App 首次 onboarding 后，通过真实 Chat 请求先发现 `trigger_workflow`，再只触发一次目标 workflow。
2. workflow 的 action function 故意等待 12 秒，制造足够长的异步 `202` 窗口；期间 Activity 侧幕保持 `Live`，中心 stage 保持 `Triggering workflow...`，没有把入队回执当作完成。
3. durable `run_terminal` 到达后，Activity 转为 `Ran`；随后在收尾阶段清理活动现场，没有第二次开合、永久 Live 行或残留活动。

## Frame review

- 录屏视频时间约 `t=183.0s` 对应 `trigger_workflow` 执行入口；`t=185s` 的固定帧显示右侧 `Activity` 条目为 `Live`，中心仍显示 `Triggering workflow...`。
- 从 `t≈185s` 到 `t≈195s` 的长执行窗口中，侧幕保持同一布局和同一活动对象，只有合法的运行秒数/流式内容更新；没有非用户触发的既有内容跳位。
- backend/SSE 显示 `run_terminal` 于 `16:39:04.164951` 到达，之后 `tool_result` 于 `16:39:04.167110` 收口；`t=199s` 固定帧显示同一活动为 `Ran`，而不是提前谢幕。
- `t=206s` 固定帧显示活动现场已清理。清理是单向终态收口，不是 Live/Ran 之间的往返闪烁。
- 终态助手正文中的 opaque ID 被显示为 `the requested item`，与仓内 context-aware redaction 规则一致；真实 workflow/flowrun ID 在 durable tool result、Activity 卡和本证据中保留，未把该既定脱敏行为误判为本格视觉缺陷。

## Five-channel cross-check

- frames: 窗口专属 `screen.mov` 与三张固定帧覆盖 Live、中间 durable terminal 后的 Ran、最终清理。
- backend: `backend.log` 322 行；无 `panic`、`FATAL` 或应用级 `WARN`/`ERROR`。
- SSE: `sse.jsonl` 208 行；`messages` durable seq=`1..23`、`entities`=`1..6`、`notifications`=`1..6`，均连续无 gap；entities 顺序为 `run_started → run open → node completed → run_terminal`。
- frontend: `frontend.log` 5 行；只有 Dart VM 启动和已知 macOS IMK/TSM 系统诊断，无 Flutter/Dart/RenderFlex/Unhandled 红线。
- LLM wire: `llm.jsonl` 22 行；managed challenge/install/models 与 4 次 chat completion 请求均为 HTTP `200`，真实 tool call 参数含目标 workflow ID，tool result 含真实 flowrun ID。
- durable truth: SQLite 中 flowrun `fr_9bd1ea1577bb2426` 为 `completed`，`start` 与 `slow` 两个节点均 `completed`，`origin=chat`，conversation=`cv_5d4e3cdce8dabd14`。
- rig lifecycle: `rig-check` 与 `rig-down` 均通过；录屏、后端、ssetap、llmtap 和 App 均由本 session 归属并正常收台。

## Judgment

- L3 `pass (B2)`: 异步 `202` 只表示已入队，Activity 在真实执行期间持续可见；durable `run_terminal` 后才进入 Ran/收口，转场单向、可解释、无跳变或残留 Live 幽灵。
- 本证据只判定该 poll 生命周期的帧级稳定性，不把 workflow 内容视觉 craft 或用户发现路径冒充为 L4/L5。
