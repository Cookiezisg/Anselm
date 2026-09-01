# EDGE-038 · L3 账本警报独立复审

## 复审对象

- `gap-too-fast`: L2/L3 是同一产品格的连续现场收口，账本写入间隔触发了节奏阈值。
- `discovery-collapse`: 近 50 条裁决没有 fail，属于分布告警，不是把产品变干净的证据。

## 独立复读

- 复读正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-161502` 的
  `screen.mov`、`manifest.json`、`startup-gate.jsonl`、`backend.log`、`frontend.log`、
  `sse.jsonl`、`llm.jsonl` 和收台结果；录屏 `3104x1844 / 60fps / 135.640000s` 可读，
  `rig-down.sh` 后 App、backend、ssetap、llmtap、recorder 均归零。
- 重算动作附近 60fps ROI：`threshold=0.00005` 的首反馈 `100.0ms`；`threshold=0.001`
  的明显内容变化 `2000.0ms`，期间 AX/录屏均显示 `thinking`，不是静默等待。完成后的
  `80s..100s` 稳定尾段 40 帧在 `0.0005` 阈值下无 diff 输出。
- REST 复读确认 `msg_18211364958d9608.retryOf=msg_e95d53244b2fd3fe`，且旧版本的
  `supersededBy` 指向新版本；没有新增 user turn。SSE messages durable seq=`1..26`
  单调，13 组 `open/close`，无 SSE error。
- `go test ./internal/app/chat -count=1` 与目标 `-race` 回归均通过；锚点重新校准为
  `10/10`；`gen_coverage.py --check`=`848/848/0`。没有修改 CODEX、阈值、锚点、
  顺序门或把其它未完成 L4/L5 改成通过。

## 处置

两条警报是裁决节奏与近期结果分布的机械控制信号；本复审确认 L3 的独立画面和测量证据
真实存在，未发现新的产品缺陷。按既定流程串行 ack，保留本记录，后续批次仍受同一组三曲线
约束。
