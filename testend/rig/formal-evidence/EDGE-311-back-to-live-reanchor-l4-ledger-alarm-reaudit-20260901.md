# EDGE-311 归队重钉贴底：L4 账本与警报独立复审

- target: `EDGE-311 / 归队重钉贴底 / L4`
- primary evidence: `testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-194553`

## Re-audit

- `judge.py` 已通过 `C4` 法条存在性、证据非空、正式 session 归属、六件台架证据和同一清册连续性校验，并只写入 EDGE-311 L4 一格。
- `COVERAGE.md` 目标行当前为 `✓✓✓✓~`；既有 L1-L3 证据未被覆盖或改写，L5 仍保持未结算。
- 复核主证据中的 60fps 录屏、Computer Use/AX 状态、backend/SSE/frontend/LLM journal、SQLite 计数与 `rig-check`/`rig-down` 生命周期；所有结论均来自同一 session。
- `anchors.py check` 重新通过 `10/10`，锚点内容和法典未改变；`gen_coverage.py --check` 仍为 `848/848/0`。
- 新开的 `discovery-collapse` 仅由近 50 条 live 裁决 fail 占比低于 5% 触发，属于需要审计的统计信号，不是本格产品失败，也没有证据表明法条或阈值失效。

## Resolution

本次独立复审确认 L4 证据完整、法条引用正确、没有漏记失败；按既有警报机制对 `discovery-collapse` 写入本复审说明并 ack。阈值、法典、锚点、顺序门和五级标准均不变。
