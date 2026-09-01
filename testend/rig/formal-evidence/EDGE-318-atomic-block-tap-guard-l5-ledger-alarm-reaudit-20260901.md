# EDGE-318 L5 账本与警报独立复审

- subject: `EDGE-318 / 原子块双/三击 / L5`
- source boundary: `testend/rig/formal-evidence/EDGE-318-atomic-block-tap-guard-l5-real-app-boundary-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-211151`
- judgment: `EDGE|原子块双/三击 L5 = na (G1)`

## Re-audit

- L5 使用 `note:` 证据按 gate 成功记账；第一次传入文件路径被 gate 拒绝，拒绝没有产生判断写入，第二次提交严格使用了适用性说明。
- 适用性说明由真实 App 现场支持：Library、编辑器、代码块、表格、分隔线和重开路径均已实际观察；不存在独立入口、设置、命令、tooltip、帮助条目或快捷键。
- `gen_coverage.py --check`: `848 rows, 848 carried judgments, 0 tombstones`。
- `anchors.py check`: `10/10` 通过；没有改动 G1 含义、阈值、法典或顺序门。
- `alarms.py check` 在 ack 前打开 `discovery-collapse`，原因是近 50 次 fail share 为 `0.0%`。该警报仍作为统计护栏保留，不把合法 `na` 改写成 pass。
- 复审结论：L5 的 `na (G1)` 是真实产品边界，不是缺证据的 provisional NA；警报按既定独立复审协议销账后继续顺序门。
