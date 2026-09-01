# EDGE-038 · 账本警报独立复审

## 复审对象

- `gap-too-fast`: 本格的五通道现场裁决和同一格的账本写入间隔触发了机械阈值。
- `discovery-collapse`: 最近窗口没有 fail，属于分布异常提示，不是产品正确性证明。

## 独立复读

- 重新读取 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-160521` 的
  `screen.mov`、`manifest.json`、`startup-gate.jsonl`、`backend.log`、`frontend.log`、
  `sse.jsonl`、`llm.jsonl` 和收台状态；五通道均有同一 session 归属，收台后进程归零。
- REST 重读 conversation messages，确认 `msg_e95d53244b2fd3fe` 的 `retryOf` 指向真实
  assistant `msg_a47649d7e916d11b`，后者的 `supersededBy` 指向新版本；compaction marker
  `msg_f18dfc7b6702beaf` 未被本轮 retry 改写。
- `go test ./internal/app/chat -count=1` 通过；目标 `-race` 回归通过，包含
  `TestRetryTargets_IgnoresSyntheticMarkers` 与
  `TestRetry_RegenerateSupersedesTheAnswerAndKeepsItReadable`。
- `gen_coverage.py --check` 在复审前通过，COVERAGE 仍为 848/848 行；没有修改阈值、法典、
  锚点集或账本 gate 来消除警报。

## 处置

两条警报都只是本批次裁决节奏与适用性分布的控制信号；本复审确认没有伪造现场、没有把
`na` 改写成 pass，也没有发现新的产品缺陷。按既定流程串行 ack 两条警报，保留本复审记录，
后续批次继续接受同一组三曲线约束。
