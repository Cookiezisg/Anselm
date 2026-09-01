# EDGE-332 L3 账本警报独立复审

- alarm: `discovery-collapse`
- formal ledger: `/private/tmp/anselm-rig-formal-20260831-11/judgments.jsonl`
- product session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- judgment under review: `EDGE|MCP 面板帧不可信|L3|pass|B2`

## Independent checks

- 新证据来自第二次真实 App session，不是复用旧的 L2 录像：本次有实体流 410、密集 MCP 状态帧、真实失败卡、技术详情按需展开和删除后 marketplace 空态。
- `rig-check.sh` 与 `rig-down.sh` 均通过；录像 `62.496667s`，backend `282` 行，三路 SSE 与 LLM 线缆均在场。
- B2 不是主观顺滑印象：`measure diff` 的有意义变化均局限在中心面板，稳定尾段无持续 reflow；entities 状态帧保持 `seq=0` ephemeral，notifications durable seq 单调到 22。
- 失败异常没有被静默吞掉：UI 默认呈现人话 callout，显式打开 `Technical details` 才显示原始异常，满足 E1 的可行动错误面与可诊断性分层。
- `discovery-collapse` 仅说明近窗口没有失败 verdict，不能覆盖本次新证据；没有修改报警阈值、法典、锚点或判断标准。

## Resolution

本警报是统计机制的有效提醒。证据完整且可复核，允许按原规则 ack；后续真实失败仍会重新打开同类警报。
