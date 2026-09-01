# EDGE-312 版本组走 retryOf：L4 账本与警报独立复审

- target: `EDGE-312 / 版本组走 retryOf / L4`
- primary evidence: `testend/rig/formal-evidence/EDGE-312-retry-version-groups-l4-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-195310`

## Re-audit

- `judge.py` 已通过 `C4` 法条、证据非空、正式 session 归属、六件台架证据和清册连续性校验，并只写入 EDGE-312 L4。
- `COVERAGE.md` 目标行保留 L1-L3 既有证据，只新增 `L4:C4`；L5 仍未结算，不因本次 L4 冒充完成。
- 独立复核当前/中间/最旧/恢复当前四个版本状态、单回合结构、pager 几何、关系说明、稳定帧和 backend/SSE/frontend/LLM journal；证据全部来自同一 session。
- `anchors.py check` 通过 `10/10`；法典、阈值、锚点与顺序策略未改变。
- 新开的 `discovery-collapse` 仅由近 50 条 live 裁决 fail 占比低于 5% 触发；L4 证据中没有漏记失败，统计信号不构成产品失败。

## Resolution

本次独立复审确认 L4 视觉 craft 证据完整、账本只增不改、标准未降级，按机制对 `discovery-collapse` 写入本说明并 ack。
