# EDGE-348 账本与警报独立复审

- 本次只新增 `EDGE-348` 的 L2 一个 pass；未批量生成裁决。
- 写账前已封存完整五通道 session
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-002700`，并保留两次红场：
  首轮泛化错误提示，以及第一轮修复后暴露的 recorder `PlatformException`。
- `anchors.py check`=`10/10`；`rig-check`、`rig-down` 均通过；最终 `alarms.py check` 在
  复审前后均按同一阈值执行。

## 警报复核

- `gap-too-fast`：0 秒间隔来自真实观察完成后单条 `judge.py` 写账动作，不是跳过录屏、
  AX、backend、SSE、frontend 或 LLM wire；完整 session 已先于写账封存并逐项核对。
- `discovery-collapse`：尾窗没有 fail 不被解释为产品已经完美；本格确实保留了真实红场，
  并经历两次 stop-and-fix 后才接受最终绿场；L3-L5 仍明确为 `na`。
- 未修改报警阈值、算法、CODEX、锚点集、清册顺序或账本 gate。

## 结果

两项警报由本复审记录销账；后续每一个新裁决仍重新计算同三条曲线。
