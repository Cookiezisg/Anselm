# EDGE-306 导演器清 Live 幽灵：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-043601`
- data: `/private/tmp/anselm-data-edge306-20260828-r4`
- workspace: `ws_1cea6a28a68ee7e3`
- replacement App: PID `64532 -> 66967`，window `4782 -> 4830`；替换后重新绑定录屏
- fixed frame: `evidence/edge306-fixed.png`
- fixed recording: `screen-rebind-66967.mov`

## Red reproduction

1. 真实 App 发送两轮真实 Bash 对话，第二轮包含 `sleep 30 && printf ...`。
2. `appproxy` 在收到真实 messages 流后断开连接，并在下一次重连返回一次 HTTP 410；直接对后端带 `Last-Event-ID: 15` 请求也得到真实 `410 SEQ_TOO_OLD`。
3. 修复前，Computer Use 的 AX 与屏幕同时显示同一个第二条命令的两个状态：已完成的 durable 输出，以及仍显示 `Running command... 152 s` 的 stale live 卡片。
4. REST 读取 `cv_afb2d90f1434e3d3` 显示该工具调用与对应 tool result 均为 `completed`，证明问题是前端 live layer 重复，不是后端仍在运行。
5. `appproxy.jsonl` 分别记录了受控 `drop` 和随后注入的 410；不是把普通网络失败误判成产品行为。

## Stop-and-fix

- `ConversationTranscript.applyFrame` 现在对每一种 frame（包括 ephemeral `open`/`delta`）先检查 settled tree 中是否已有同一 block ID。
- 已水化为终态的 block 不再被迟到 ephemeral frame 重建为 live duplicate。
- durable user echo 仍会针对 settled node 做 pending bubble reconciliation，避免修复重复时丢掉回声归并。
- 回归测试：`late ephemeral frames for a hydrated terminal block cannot create a live duplicate`。

## Fixed App walkthrough

修复后的 Flutter 构建重新启动并绑定到替换窗口后，打开同一会话只显示一个 `Ran sleep 30 ... · exit 0` 终态卡片；输出文本只出现一次，没有 `Running command...` stale 行。`edge306-fixed.png` 是已检查的 `2784x1808` 终帧，清楚显示两轮命令均已完成。替换录屏片段时长为 `190.983333s`；原始 `screen.mov` 总时长为 `1037.451667s`，其中包含红场与收尾过程。

## Five channels

- frames: `screen.mov` 与 `screen-rebind-66967.mov`；`rig-check` 已验证录制窗口归属，固定终帧位于 `evidence/edge306-fixed.png`。
- backend: `backend.log` 共 1929 行；包含可归因的 410 证据，未发现 panic 或 FATAL 应用崩溃。
- SSE: `sse.jsonl` 共 4760 行；messages/entities/notifications 三路均连接，messages durable seq 到 788，并记录断开与恢复。
- frontend: `frontend.log` 共 26 行；其中 connection closed、503、connection refused 均来自本次刻意注入的断流/收台扰动，未发现 Flutter、Dart、RenderFlex 或 Unhandled runtime 红线。
- LLM: `llm.jsonl` 共 391 行；记录 managed proof/install/models 与真实聊天流量穿过 tap，未暴露凭证。
- rig lifecycle: `rig-check` 与 `rig-down` 均通过，录屏和五通道 journal 在收台后仍保留。

## Verdict

- L1 `pass`: durable 历史为 completed 时，realignment 清除 stale live activity，正常终态渲染保留。
- L2 `pass`: 真实 App、后端、三路 SSE、frontend journal、LLM wire 与录屏相互一致；修复后不存在第二张 running 卡片。
- L3-L5 `na`: 本证据不虚构顺滑度、视觉 craft 或从零可发现性结论；后续按独立测量和盲走要求处理。
