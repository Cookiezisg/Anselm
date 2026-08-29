# EDGE-347 账本与警报独立复审

## 复审范围

- 本次只新增 `EDGE-347` 的 L2 一个 pass，未批量生成裁决。
- 该裁决在写入前已完成真实 Flutter App + 真实 managed gateway + Computer Use
  的 stop-and-fix 重跑，并已封存 session
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-235829`。
- `anchors.py check`=`10/10`；`gen_coverage.py --check`=`848/848/0`；`rig-check`
  和 `rig-down` 均通过。

## 警报复核

- `gap-too-fast`：当前尾窗的 0 秒间隔来自真实观察完成后单条账本动作的进程级
  时间戳，不是跳过录屏或证据的批量橡皮章。该格的录屏、AX 状态、backend、SSE、
  frontend、LLM wire、SQLite 证据均已独立读取，且先于 `judge.py` 写入。
- `discovery-collapse`：当前尾窗没有 fail 不被解释为产品无缺陷；本格真实红场
  （网关 404、本地保行、前端失败提示缺失）已保留，修复后才以 204 绿场重跑。
  L3-L5 明确保持 `na`，没有把未覆盖等级算作通过。
- 未修改报警阈值、算法、CODEX、锚点集、账本 gate 或覆盖顺序。

## 结果

按机制完成两项 ack；后续新裁决仍会重新计算三条曲线并受同一 gate 约束。
