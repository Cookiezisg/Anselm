# EDGE-312 · 版本组走 retryOf

## 用户目的

用户重试同一个回答后，时间线仍应呈现一个连贯回合，而不是把同一个问题的多个答案误显示成多轮对话；用户可以回看旧答案，并且在查看旧答案时知道线程后续实际基于哪一版。

## 真实 App 验收

- 隔离数据：`/private/tmp/anselm-data-edge312-20260828-r1`
- workspace：`ws_46e90cfad6788e9a`
- conversation：`cv_edge312_retryof`
- durable 数据包含一个 user 回合和三个 assistant 版本；`m312_a1.attrs.retryOf=m312_a0`、`m312_a2.attrs.retryOf=m312_a1`，旧版本的 `superseded_by` 分别指向下一版。
- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`
- App/window：PID `83133` / window `5155`
- 录屏：`screen.mov`，`91.045000s`
- 关键帧：`edge312-current-3of3.png`、`edge312-middle-2of3.png`、`edge312-oldest-1of3.png`、`edge312-restored-3of3.png`

真实操作路径：从 Recents 打开 `EDGE-312 retryOf 版本组`，默认看到当前回答且只有一行，pager 为 `3/3`；点击 `Previous version` 两次，依次看到 `2/3`、`1/3`，旧文本可读，并出现 `the thread continued from version 3`；点击 `Next version` 回到 `3/3` 后旧版提示消失。AX 树中始终只有一个 assistant 回合容器，没有三条重复回答。

## 五通道证据

- channel 1：Computer Use 逐步 AX 状态与关键帧已保存；录屏无外部遮挡，真实 App 窗口归属 conductor。
- channel 2：backend journal 157 行，无应用 `WARN`、`ERROR`、`panic`、`FATAL`。
- channel 3：SSE witness 连接 `entities`、`notifications`、`messages` 三路并正常 EOF 收台；本格是 durable 历史读取，无需伪造模型事件。
- channel 4：frontend journal 仅 Flutter VM 和 macOS `IMKCFRunLoopWakeUpReliable` 系统输入法日志，无 Flutter/Dart/RenderFlex/Unhandled 错误。
- channel 5：llmtap 已启动并通过 channel-5 wiring；本格纯历史 UI 操作，没有模型请求，`llm.jsonl` 保留 `ready` 作为在线证据。

## 判定

`L1=F1`（前端 model/UI focused tests 66 项全绿）；`L2=F1`（真实 App + 五通道台架 + 录屏）；`L3-L5=na`，不把未执行的更高层级伪装成通过。版本链行为正确，无产品缺陷，无产品代码修改。
