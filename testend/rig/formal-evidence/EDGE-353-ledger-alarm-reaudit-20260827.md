# EDGE-353 账本与警报独立复审

- 复审对象：本次真实 App stop-and-fix 后写入的 `EDGE-353` L2 裁决。
- 真实证据：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-002414/evidence/EDGE-353-workflow-deactivate-drains-both-20260827.md`。
- 台架事实：录屏 `181.991667s`；真实 App、backend journal、三路 SSE、LLM tap 全部同一 session；五通道收台前 `rig-check` 通过，`rig-down` 无残留。
- 账本事实：`gen_coverage.py --check`=`848 rows / 848 carried judgments / 0 tombstones`；`EDGE-353=✓✓~~~`，L3-L5 为明确 `na`。
- 警报事实：新增一条真实裁决后，近 50 条裁决的时间间隔中位数触发 `gap-too-fast`，且 fail share 为 0 触发 `discovery-collapse`。这是写账节奏统计信号，不是替代真实观察的产品结论。
- 复审结论：证据确实覆盖产品路径、REST 状态、SSE inactive durable 帧、App 终态、停用后 404 和日志健康；没有修改警报阈值、算法、CODEX、锚点或覆盖顺序。两项警报按原规则销账，后续新裁决仍重新计算。
