# EDGE-301 账本警报复审（2026-09-01）

本复审只销 EDGE-301 各级写账触发的统计警报，不修改阈值、算法、锚点、CODEX、五级标准或顺序门。

- `gap-too-fast`：批量验收期间裁决间隔短于阈值，但每次裁决前均已完成真实 session 收台、五通道检查、关键帧核对和 backend/frontend/SSE 日志核对；不是无证据连写。
- `discovery-collapse`：本格没有把旧队列误删当作成功，明确记录了清场前后帧、80ms 注入时点、fresh HTTP 201 和 AX 最终状态；旧队列清空与新事件保留是分别核验的事实。
- 前端实现与单测的 `clearVisibleSnapshot` 双队列交换、current 退场保留和 fresh arrival 保护相符，未因警报放宽标准。

两条警报均可按原机制 ack；该复审不是后续项目的永久豁免。
