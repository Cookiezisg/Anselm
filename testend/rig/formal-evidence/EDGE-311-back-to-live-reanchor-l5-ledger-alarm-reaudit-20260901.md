# EDGE-311 归队重钉贴底：L5 账本与警报独立复审

- target: `EDGE-311 / 归队重钉贴底 / L5`
- primary evidence: `testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-l5-real-app-20260901.md`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-195659`

## Re-audit

- `judge.py` 已通过 `G1` 法条存在性、证据非空、正式 session 归属、五通道证据和清册连续性校验，并只写入 EDGE-311 L5。
- `COVERAGE.md` 目标行当前为 `✓✓✓✓✓`；L1-L4 的既有裁决和证据指针保持不变。
- 独立复核普通用户目标、AX 的入口与归队状态、录屏稳定段、backend/SSE/frontend/LLM journal 及 rig lifecycle；结论均来自同一正式 session。
- `anchors.py check` 重新通过 `10/10`，法典、阈值、锚点和顺序策略均未改变。
- 新开的 `discovery-collapse` 只表示近 50 条 live 裁决 fail 占比低于 5%，不表示本格缺失可发现性证据；本格的 G1 证据已明确证明从 Recents 到 Scenes、历史目标和 `Jump to present` 的完整产品闭环。

## Resolution

本次复审未发现漏记失败或发现性标准降低，按既有机制对 `discovery-collapse` 写入本说明并 ack；继续保留五级标准和人工队列，不把统计警报改成静默阈值。
