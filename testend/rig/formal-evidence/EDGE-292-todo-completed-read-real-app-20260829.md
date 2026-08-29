# EDGE-292 · todo 全完成后被问清单：真实 App L2

## 目的

验证清单全部完成后，系统不会因为 `0-open` 而把清单从模型或用户视野中隐藏；`todo_read` 必须仍能读回已完成项，最终回答只能来自真实读回结果。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-150633`
- data=`/private/tmp/anselm-data-edge292-real-20260829-r1`
- workspace=`ws_8e85f7b70fb731d4`
- conversation=`cv_6105f53dc95842cb`
- App/window=`37240/6184`；录屏=`83.880000s`
- 关键帧=`sessions/20260829-150633/evidence/EDGE-292-todo-completed-read.jpeg`

## 场景与结果

1. 在真实 App 新建对话，发送一条消息，要求依次用 `todo_write` 建立两个任务、再次用 `todo_write` 将两项都标为 completed、最后调用 `todo_read` 后报告名称。
2. App 逐步显示 `Updated checklist · 2 items · 0 done`、`Updated checklist · 2 items · 2 done`、`Read checklist · 2 items · 2 done`。
3. 最终回答准确列出 `EDGE292 first task` 与 `EDGE292 second task`，没有在 0-open 时隐藏清单，也没有使用 memory 或其它工具。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：真实聊天画面同时呈现三张工具状态卡和最终两个任务名称；没有错误卡、残留 loading 或空白终态。
- **Channel 2 / backend journal**：真实回合完成，backend 无应用级 WARN/ERROR/panic；消息与工具块正常落盘。
- **Channel 3 / SSE tap**：messages 流记录三次工具调用及对应 durable close/result；`todo` signal 分别为 `0 done`、`2 done`，`todo_read` 结果为两条 `[x]`，durable seq 单调无 gap。
- **Channel 4 / frontend 错误面**：`rig-check` 通过真实 App/window 归属、录屏遮挡、SSE 三流连接和 recorder lifecycle；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。
- **Channel 5 / LLM tap**：challenge/install/models 与全部 chat-completions continuation 请求均为 `200`；LLM wire 的正式回合严格出现 `todo_write` 建立、`todo_write` 完成、`todo_read` 读回三步，未调用 memory 或其它工具。
- **耐久对账**：`GET /api/v1/conversations/cv_6105f53dc95842cb/messages` 返回两条消息；assistant blocks 同时保留三次 tool_call、三份真实 tool_result（前两份分别为 `[ ]` 与 `[x]`，末份为两条 `[x]`）及最终文本，SQLite `integrity_check=ok`、`foreign_key_check` 为空。

## 判定

本证据支持 L2 `F1`：真实 App 达成“全部完成后仍可读回并报告”的用户目的，且 SSE、消息行和工具结果共同证明不是模型凭记忆编造。L3-L5 不在本次证据中猜测，继续保持 `na`。
