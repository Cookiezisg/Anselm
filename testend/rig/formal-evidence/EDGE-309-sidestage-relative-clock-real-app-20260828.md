# EDGE-309 侧幕分档时钟：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`
- data: `/private/tmp/anselm-data-edge309-20260828-r1`
- workspace: `ws_628fab9117677c0b`
- conversation: `cv_9f5ef152d481c274`
- function: `edge309_activity_probe` (`fn_c263952897d930e9`)
- recording: `screen.mov`, duration `891.081667s`, App/window `75340/5002`
- frame evidence: `evidence/edge309-initial.png`, `evidence/edge309-migrated.png`

## User-purpose walkthrough

1. 通过真实 App 的实体提及选择 `edge309_activity_probe`，发送一次真实请求并等待工具完成；中心 transcript、Activity 侧幕和真实 function 返回值一致。
2. 初始状态中，右侧 Activity 显示 `Just now (1)`，目标活动 `edge309_activity_probe` 位于该档；另有一个前一天的历史参照活动，显示在 `Earlier (1)`。
3. 保持 App 前台静置约 10 分钟，不点击、不切换海洋、不重新加载数据。每分钟读取一次 AX 状态，仅由侧幕内部分钟时钟触发重算。
4. 越过 10 分钟窗后，右侧 Activity 自动变为 `Earlier today (1)`；前一天参照仍为 `Earlier (1)`。目标记录没有冻结在 `Just now`，也没有通过突兀的用户动作才刷新。

## Five channels

- **frames / Computer Use**: 录屏和固定帧保留前后画面。`edge309-initial.png` 显示右侧 `Just now` 与 `Earlier` 两档；`edge309-migrated.png` 显示 `Earlier today` 与 `Earlier` 两档。最终 AX 树进一步确认右侧容器内的两个标题，排除了左侧对话列表同名文本造成的误判。
- **backend**: `backend.log` 共 965 行；没有 WARN、ERROR、panic 或 FATAL。真实 App 请求、触点台账和收台均在同一 session 下归属。
- **SSE**: `sse.jsonl` 共 82 条记录，消息流 durable seq 从 1 到 16 单调推进，包含真实消息 open/close/signal/delta；最终 tool result 的 close 帧包含 `edge309` 返回值和 `ok:true`。
- **frontend**: `frontend.log` 只有 App 启动、Dart VM 和 macOS `IMKCFRunLoopWakeUpReliable` 系统提示；没有 Flutter、Dart、RenderFlex、Unhandled 或应用级错误。
- **LLM wire**: `llm.jsonl` 记录 managed proof challenge 和真实 `/v1/chat/completions` 请求；两次 completion 返回 HTTP 200，最终 tool chain 由真实网关驱动，不是 transcript fixture 回放。
- **rig lifecycle**: `rig-check` 已在 App 前台运行期间通过；`rig-down` 正常停止 recorder、App、backend、ssetap、llmtap，并完成 891.081667 秒录屏，无残留进程。

## Verdict

- **L1 pass**: 侧幕以每分钟时钟安静重算相对时间档；目标记录从 `Just now` 自然迁移到 `Earlier today`，跨日参照保持 `Earlier`。
- **L2 pass**: 修复后的真实 App、Computer Use/录屏、backend、SSE、frontend journal、managed LLM wire 和统一 rig session 对同一真实活动一致；没有依赖用户操作或无关重建来制造迁移。
- **L3-L5 na**: 本格证明相对时钟与数据真相，不冒充独立顺滑度测量、视觉 craft 审查或从零盲走可发现性通过。

## Test-data note

为了让两个时间档同时可见，历史参照是通过真实文档化 API 建立触点后，在本次隔离测试数据目录中回拨到前一天的 setup 数据；没有修改产品代码，也没有回放前端 fixture。此前用“15 分钟前但仍是同一天”的参照进行的两轮观察不计入本格，因为按产品反目录规则，两条记录同属当天时不应保留两个档位标题。
