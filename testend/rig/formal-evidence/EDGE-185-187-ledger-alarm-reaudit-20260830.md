# EDGE-185..187 账本警报独立复审

## 触发

本次连续写入 `EDGE-185` 的三项适用性裁决和 `EDGE-186`、`EDGE-187` 各四项
适用性裁决后，`alarms.py check` 按原阈值打开 `pass-burst`。这是裁决写入
密度的统计信号，不是产品行为结论。

## 复审

- `EDGE-185` L3-L5：统一搜索 REST cursor 当前没有 Flutter 操作控件、视觉状态
  或导航入口；L2 已由真实 App、sidecar 和五通道 session 验收，三项适用性依据
  已记录在 `EDGE-185-applicability-boundary-20260830.md`。
- `EDGE-186` L2-L5：reindex 是无用户产物的内部维护 API，focused/真实黑盒已覆盖
  single-flight、跨 workspace 隔离、就地 reconcile 与 `204/409` 合同；适用性依据
  已记录在 `EDGE-186-applicability-boundary-20260830.md`。
- `EDGE-187` L2-L5：schema mismatch 是 boot 阶段的派生索引迁移 seam，Flutter
  只消费迁移后的搜索结果，不接收迁移状态；focused boot 回归和适用性依据已记录在
  `EDGE-187-applicability-boundary-20260830.md`。

每一项均由 `judge.py` 顺序 gate 写入，`na` 的理由具体且包含未来公开产品表面时的
重开条件；没有用连续写账替代测试，也没有把任何未测 UI 维度写成 `pass`。

## 处置

按原机制仅 ack 当前 `pass-burst` 实例；不调整 `339s`、`3143s/10`、`3x` 或任何
警报算法、CODEX 法条、锚点、顺序 gate 和五级标准。下一格仍须重新通过相同的告警
检查，批次达到 `50` 格前不执行统一长门禁。
