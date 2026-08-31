# EDGE-239 · ledger/alarm 独立复审

本复审对应正式 session `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-162419`。
复审不改变阈值、法典、锚点答案、五级标准或顺序门，只核对本次新增的 EDGE-239 账本动作。

- 重新核对 session manifest、封口 `screen.mov`、startup-gate、frontend/backend journal、三路
  SSE journal 和 LLM journal；五通道由同一 conductor 归属，`rig-check` 与 `rig-down` 均通过。
- 重新核对旧库副本在启动前的三张旧 CHECK、启动后的三张新 CHECK、`message_blocks=3`、
  `integrity_check=ok` 和空的 `foreign_key_check`；没有只看 UI 或只看模型自述。
- `anchors.py check` 保持 `10/10`；新写账触发的 `discovery-collapse` 只是统计保护信号，
  不代表该产品切片失败。复审完成后仅 ack 这一次新增水位，未修改告警算法。
- L2 的证据指针位于 session `evidence/` 内；L3-L5 的 `na` 是对后台迁移适用性的明确说明，
  不是缺少真实 App 证据的 waiver。
