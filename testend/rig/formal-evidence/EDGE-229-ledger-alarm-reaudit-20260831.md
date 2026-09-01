# EDGE-229 · ledger and alarm re-audit

本次复核独立重看主判定绑定的自然语言正式 session
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-130955-edge229-natural`，以及交叉
session `20260831-130336-edge229` 的五通道产物、两张 loading/final 关键帧、LLM 请求体/响应体、
SSE durable close、SQLite attachment 和 `rig-check`/`rig-down` 输出。

- `EDGE-229` 的 L2-L5 均绑定真实证据；L3 的 `A4` 只依据录屏中的长等待状态和 Stop 控件，L4 的
  `C4` 只依据音频卡及 loading/完成几何，L5 的 `G1` 只依据不含内部工具名的自然语言路径。
- 写账过程中触发的 `gap-too-fast` 与 `discovery-collapse` 已逐条独立复核并 ack。短间隔是本轮
  同一验收项的连续账本动作，不修改 `25s` gap 阈值；该场景没有失败样本不能
  外推为全产品 discovery rate，不修改 `5%` 地板。
- 本复核没有改动 CODEX、五级标准、anchors、alarm 算法、sequence policy 或 COVERAGE 既有历史；
  仅确认本次证据指针、session 身份和四个新判断可重取。
