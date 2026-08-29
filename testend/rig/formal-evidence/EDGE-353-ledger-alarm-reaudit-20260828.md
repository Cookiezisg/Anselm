# EDGE-353 账本与警报独立复审

- 复审对象：当前版本 `workflow 停用排空双类` 的真实 App 五通道 L2 裁决。
- 主证据：`testend/rig/formal-evidence/EDGE-353-workflow-deactivate-drains-both-20260828.md`；正式 session=
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-014157`。
- 台架事实：`rig-check` 首次拒绝了未审阅 AXTree churn；session review 明确分类为固定 tooling signature，
  静置 3 秒不增长，无 Flutter/Dart/布局异常；补 review 后 `rig-check` 通过，`rig-down` 成功，录屏
  `350.406667s`，无残留进程。
- 数据事实：workflow 经真实 App 下线后保持 `draining`，中间确有一个 running run 与一个 pending firing；
  两次 App 审批后两条 run 均 completed、两条 firing 均 started，最终 inactive；停用后 webhook 404 且无新增行。
- 警报事实：写入本次 L2 后脚本打开 `gap-too-fast`、`pass-burst`、`discovery-collapse`。这些是账本写入时间窗口的
  统计信号，不能替代也没有否定本 session 的产品证据；它们来自集中裁决节奏，不是 screen/backend/SSE/LLM 的运行时错误。
- 复审结论：三项均按既有规则 ack；未修改算法、阈值、法典、锚点或覆盖顺序。`anchors.py check`=`10/10`，
  `gen_coverage.py --check`=`848 rows / 848 carried judgments / 0 tombstones`。后续裁决仍会重新计算警报。
- 范围边界：本轮只证明目的达成与五通道真相；L3 顺滑、L4 视觉 craft、L5 从零可发现性不因 L2 证据自动绿。
