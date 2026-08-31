# EDGE-237 · 账本警报独立复审

本次 EDGE-237 真实 session 为 `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-154826`。

- `gap-too-fast`：警报只反映裁决写入间隔，不代表证据观看时长。复审了同一 session 的录屏、Computer Use 失败/恢复帧、backend/frontend/SSE/LLM journal、`rig-check` 和 `rig-down`；负向启动格明确记录了不存在的 SSE/LLM 连接，未以空文件冒充绿证据。
- `discovery-collapse`：本格不是“自动全通过”，而是一个明确的坏配置负向场景；失败事实由 sidecar fatal journal 和 App 错误态共同证明。L2 使用专门的 `F6` 负向启动法条，未改警报阈值、算法、法典或锚点。

结论：两条警报均为统计信号的预期触发，当前 session 证据完整且可复核，可以在下一格前按 `alarms.py ack` 销账。
