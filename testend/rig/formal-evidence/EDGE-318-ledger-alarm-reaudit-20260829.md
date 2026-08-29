# EDGE-318 · 账本警报独立复审

- 触发：本次 L2 写入后 `discovery-collapse` 提示近 50 次裁决 fail 占比为 0%。
- 复审对象：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-000303`，不是旧 session。
- `anchors.py check`：10/10，通过；锚点 hash 未变。
- 本次新增裁决由真实 App 五通道 session 支撑，录制已通过 `rig-down.sh` 封存；backend、SSE、frontend、LLM journal 均存在且非空。
- 近 50 次 fail=0 不能证明产品没有缺陷；本次不修改警报阈值、算法、CODEX、锚点或账本 gate，保留警报并按既定流程独立销账。
- EDGE-318 L3-L5 仍为 `na`，没有用“安全交互通过”替代美学、动效或发现性判断。
