# EDGE-178 · L3 ledger/alarm re-audit

- `judge.py` 已以 `B2` 写入 `搜索 embedder 缺席降级` 的 L3；法条存在于 `CODEX.md`，证据文件
  位于同一 formal session，且 `anchors.py check` 为 `10/10`。
- `discovery-collapse` 的触发原因是近 50 个裁决的 fail share 为 `4.0%`，低于 `5%`；这不是
  “产品更干净”的证明，不能通过降低标准或把未测的 L4/L5 当作已完成来消警报。
- 本格的独立证据为真实 App 的 `60fps / 171.086667s` 绑定录屏、`measure latency` 的
  `feedbackFrame=169 / latencyMs=1400.0`，以及稳定尾段 `32` 帧 `measure diff` 无输出；REST/DB、
  messages/notifications/entities SSE、backend、frontend console 和 LLM wire 均来自同一 session。
- 复审确认结论边界：L3 只证明 lexical fallback 在真实 App 中有可见反馈且收敛后无异常跳变；当前
  没有 search/embedder Settings 控件的事实没有被写成 discoverability 通过，L4/L5 仍开放。
- 没有修改 alarm 阈值、算法、CODEX 法条、anchor set、ledger sequence 或 coverage generator。
  这是对本次真实证据和统计解释的复审，故允许 ack `discovery-collapse` 并继续前线。
