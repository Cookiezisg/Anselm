# EDGE-307 poll 型 202 不谢幕：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-050413`
- data: `/private/tmp/anselm-data-edge307-20260828-r1`
- workspace: `ws_ff78f6e43e9f3f50`
- workflow: `wf_10e5d09d369a952c`
- function: `fn_225c631722ef13ce`
- conversation: `cv_d89f690a9ad45749`
- flowrun: `fr_a40e4146fcdc2fb1`
- recording: `screen.mov`, duration `291.895000s`, App/window `68891/4858`
- live frame: `evidence/edge307-live.png`
- terminal frame: `evidence/edge307-terminal.png`

## User-purpose walkthrough

1. 真实 App 通过实体提及选择 `edge307_poll_202_probe`，用户请求立即运行并只返回 run id，不等待完成。
2. 真实 managed LLM 的成功请求调用 `trigger_workflow`，wire 与 messages SSE 都保留精确的 workflow id；工具结果返回同一 flowrun id。
3. workflow 的真实 function 节点故意等待 12 秒。在这段时间内，App 中间态保持 `Triggered workflow ... · 3 s`、Activity 中的 `Mentioned · Live` 和 `Listening live · settle follows the truth`，没有提前谢幕。
4. entities SSE 先发 `run_started`，再发节点完成，最后才发同一 flowrun 的 durable `run_terminal`；录屏终态随后显示 `Ran` 和 `1 touched · 1 executed`。
5. 只有 durable terminal 到达后才收口，未出现提前 farewell 或残留 live 行。

## Five channels

- **frames**: `screen.mov` 及本证据中的 live/terminal PNG。live 帧显示活动仍为 Live，terminal 帧显示同一活动已 Ran；`rig-check` 确认窗口归属、录屏生命周期和无外部覆盖窗口。
- **backend**: `/sessions/20260828-050413/backend.log` 与真实 REST 查询确认 `fr_a40e4146fcdc2fb1` 的 status 为 `completed`，节点 `slow` 完成，`origin=chat`，并固定了 workflow/function 版本。backend 中唯一 warning 是更早一次 Computer Use 输入桥接探针把下划线丢失后产生的 `workflow not found`，不属于成功会话 `cv_d89f690a9ad45749`，不纳入产品结论。
- **SSE**: `/sessions/20260828-050413/sse.jsonl` 中三路 stream 均有归属；entities 依次记录 `run_started`（05:09:10.432234）、node completed（05:09:22.563173）、`run_terminal`（05:09:22.563469），messages 的 `trigger_workflow` tool result 紧随其后（05:09:22.564002）。
- **frontend**: `/sessions/20260828-050413/frontend.log` 只有 Dart VM 启动和 macOS IMK/TSM 系统行，没有 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- **LLM wire**: `/sessions/20260828-050413/llm.jsonl` 中 managed proof/install/models 与成功对话请求均为 HTTP 200；成功 tool call 为 `{"workflowId":"wf_10e5d09d369a952c"}`，工具结果为 `{"flowrunId":"fr_a40e4146fcdc2fb1","workflowId":"wf_10e5d09d369a952c"}`。
- **rig lifecycle**: `rig-check.sh` 与 `rig-down.sh` 均通过；recorder、App、backend、ssetap、llmtap 均有明确归属并正常收台。

## Verdict

- **L1 pass**: 202/run-start receipt 打开 poll 型 stage，stage 在真实运行期间保持 live，并在 durable terminal 后收口。
- **L2 pass**: 真实 App、backend、三路 SSE、frontend journal、managed LLM wire 与录屏对同一 workflow/run 达成一致。
- **L3-L5 na**: 本单格只证明异步真相与收口时序，不冒充顺滑度、视觉 craft 或盲走可发现性通过。
