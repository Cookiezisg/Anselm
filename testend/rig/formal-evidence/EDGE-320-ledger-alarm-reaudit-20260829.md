# EDGE-320 · 账本警报独立复审

- 触发警报：`discovery-collapse`
- 触发原因：写入 EDGE-320 后，最近 50 条 live judgment 的 fail share 仍为 `0.0%`，低于 `5%` 地板。
- 复审依据：锚点集已于本 session 重新 quiz/check 通过；本次 EDGE-320 使用新的真实 App session `20260829-134830`，录屏约 `94.406667s`，收台前 `rig-check` 五通道全绿且无外部窗口遮挡。
- 复审结论：警报是统计机制的预期停闸，不是通过率阈值放宽；L2 仅在真实 UI 重进结果与 REST body/frontmatter 逐字段一致后写入，L3-L5 仍保持未判定，不存在橡皮章式整行放行。
- 处理：保留 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、锚点有效期和 gate 逻辑不变；以本次独立复审说明 ack `discovery-collapse`。
