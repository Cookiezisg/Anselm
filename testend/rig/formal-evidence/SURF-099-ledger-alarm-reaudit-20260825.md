# SURF-099 账本与警报复审

## 触发

SURF-099 五级裁决写入后，`alarms.py check` 按机制打开 `gap-too-fast` 与 `discovery-collapse`。这是速度/发现率曲线的控制反应，不是对 SURF-099 证据内容的判定。

## 独立复核

- 五条裁决均有真实法条：`E2`、`F2`、`B2`、`C4`、`G1`，且 COVERAGE 已为 `✓✓✓✓✓`。
- L2 证据仍绑定同一正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-065746`；manifest 的绝对 session identity、backend、SSE、frontend、LLM、screen 六项均齐全，`rig-check` 与 `rig-down` 均通过。
- 锚点校准未漂移：`anchor-check.json` 的 10 anchors SHA256 与 `testend/rig/anchors.json` 一致，检查时间仍在四小时有效窗口内。
- `gen_coverage.py --check`：848 rows、482 carried judgments、0 tombstones。
- 本格没有修改警报阈值、算法、法典、锚点或裁决；复审只核对证据与机制状态。

## 处置

两个警报已按 re-audit note 串行 ack。ack 不把通过率或裁决间隔曲线改绿，只关闭本轮已复核的 alarm evidenceThrough；后续新裁决仍会重新经过同一三曲线。
