# SURF-101 · 账本与警报复审

## 触发

SURF-101 的五级裁决写入后，`alarms.py check` 按原机制打开
`gap-too-fast` 与 `discovery-collapse`：本格五次裁决连续执行，使近尾
裁决间隔中位数为 0 秒；最近 50 条裁决中没有 fail。两项均是裁判过程的
漂移信号，不是 SURF-101 的产品结论。

## 独立复核

- 五条真实裁决均为 pass，法条依次为 `E2`、`F2`、`B2`、`C4`、`G1`；
  `SURF-101 i18n/markdown` 已在 COVERAGE 形成 `✓✓✓✓✓`。
- L2 绑定正式 session
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-072409`，
  并使用该 session 内的五通道证据，不以仓库调查文档替代。
- session 的 screen、backend、frontend、SSE、LLM 证据齐全；三路 SSE
  各连接一次，messages durable `1..24`、notifications durable `1..4`
  单调无 gap，实体流没有可伪造的业务 durable 帧。
- anchor 校准仍为 `10/10`，`anchor-check.json` SHA256=
  `e5f1899af88a71a5c16989e88a5bf188ad3e1c0379f901e525718d70366b6b08`，
  与 `testend/rig/anchors.json` 一致，未改动锚点集。
- `gen_coverage.py --check`、focused Flutter suite、`rig-check.sh`、
  `rig-down.sh` 和 `git diff --check` 均在收口时复核；未改阈值、统计
  算法、CODEX 法条、锚点或 ledger gate。

## 处置

`gap-too-fast` 与 `discovery-collapse` 按本记录串行 ack。ack 只关闭已复核
的 alarm evidenceThrough，不把通过率或裁决间隔曲线伪装成绿色；下一格仍须
经过同一三曲线机制。
