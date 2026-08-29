# EDGE-308 侧幕失败行清除：真实 App 五通道证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-052018`
- data: `/private/tmp/anselm-data-edge308-20260828-r2`
- workspace: `ws_27fd45b628db82f9`
- function: `fn_7fee60dd47364610`
- conversation: `cv_75dc98d94a79b353`
- recording: `screen.mov`, duration `110.498333s`, App/window `71289/4911`
- failed frame: `evidence/edge308-57s.png`
- cleared frame: `evidence/edge308-100s.png`

## Stop-and-fix

首轮真实 App 复现出产品错误：transcript 已显示 `ok:false`、红色 traceback 和 `failed`，但 Activity 侧幕把同一执行显示为 `Ran`，因此失败行没有清除出口。根因是 `tool_result` 的传输层 close status 为 `completed`，而 `run_function` 的执行失败藏在正文 JSON 的 `ok:false`。

修复 `StageDirectorController` 的终态判断：保留 `error/cancelled` 外层状态判断，同时读取执行正文；执行类正文 `ok:false`、`invoke_agent` 的 `status=failed|timeout` 均进入 `failedHold`。新增 provider 回归测试覆盖正文失败和 `clearActivity` 后回到 idle。

## User-purpose walkthrough

1. 通过真实 App 的实体提及选择 `edge308_failure_probe`，发送“运行函数并清晰报告失败”。真实 function 主动抛出 `RuntimeError("edge308 intentional failure")`。
2. 修复版 App 的中心 transcript 明确呈现执行结果表：状态 `失败`、类型 `RuntimeError`、错误信息和 72 ms；完整 traceback 仍可读。
3. 修复版 Activity 侧幕同步呈现 `Failed`、红点和 `Run failed · inspect the error below`，失败活动不被正常成功状态覆盖。
4. 鼠标移到失败行后，AX 树出现独立按钮 `Clear this row`；点击后红色失败驻留消失，历史触点仍保留为普通 `Ran` 记录，中心 transcript 的失败审计不被删除。

## Five channels

- **frames**: `screen.mov` 的 `edge308-57s.png` 显示失败行、红点和失败提示；`edge308-100s.png` 显示清除后的普通历史行，中心失败详情仍存在。
- **backend**: `/sessions/20260828-052018/backend.log` 记录真实 function 建立、App 请求和三路 stream 正常收台；未发现 panic、FATAL 或应用错误红线。
- **SSE**: `/sessions/20260828-052018/sse.jsonl` 保留真实 conversation `cv_75dc98d94a79b353` 的 `run_function` tool call、function execution error、`tool_result` completed + `ok:false` 正文和 executed touchpoint；这正是修复要覆盖的线缆形态。
- **frontend**: `/sessions/20260828-052018/frontend.log` 只有 App 启动、Dart VM 和 macOS IMK 系统行，没有 Flutter/Dart/RenderFlex/Unhandled runtime 红线。
- **LLM wire**: `/sessions/20260828-052018/llm.jsonl` 中 managed proof/install/models 与 chat requests 均为 200；成功对话通过真实 `run_function` 触发该 function，非 fixture 回放。
- **rig lifecycle**: recorder、App、backend、ssetap、llmtap 均由同一 session 归属并由 `rig-down.sh` 正常收台；录屏和 journals 保留。

## Verdict

- **L1 pass**: Activity 对执行正文失败与正常成功分流，失败行显示 Failed/红点/失败提示，并提供行级清除出口。
- **L2 pass**: 修复后的真实 App、backend、SSE、frontend journal、managed LLM wire 与录屏对同一失败执行一致；清除只移除侧幕失败驻留，不抹掉 transcript 审计。
- **L3-L5 na**: 本格证明失败真相和清除行为，不冒充顺滑度、视觉 craft 或盲走可发现性通过。
