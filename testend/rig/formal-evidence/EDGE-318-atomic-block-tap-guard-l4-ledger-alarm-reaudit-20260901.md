# EDGE-318 L4 账本与警报独立复审

- subject: `EDGE-318 / 原子块双/三击 / L4`
- source evidence: `testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-211151`
- judgment: `EDGE|原子块双/三击 L4 = pass (C4)`

## Re-audit

- `gen_coverage.py --check`: `848 rows, 848 carried judgments, 0 tombstones`。
- 本次证据确实来自 conductor 所有的真实 App session，包含录屏、backend、SSE、frontend、LLM 五通道和 SQLite 最终真相；不是 focused test、旧 session 或空占位。
- `anchors.py check`: `10/10` 通过，锚点答案与 hash 未改变；没有因为 discovery 警报而降低视觉标准、改阈值或修改法典。
- `alarms.py check` 在 ack 前按既定规则打开 `discovery-collapse`：近 50 次 fail share 为 `0.0%`。该警报保留为质量信号，不能被 pass 判断隐式吞掉。
- 复审结论：本格的 C4 证据独立成立；警报属于既定统计护栏，不是本格产品失败。按既定协议完成 ack 后才可继续顺序门。
