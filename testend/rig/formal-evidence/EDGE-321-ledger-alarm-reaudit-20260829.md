# EDGE-321 · 账本警报独立复审

- 触发警报：`discovery-collapse`。
- 触发原因：写入 EDGE-321 后，最近 50 条 live judgment 的 fail share 仍为 `0.0%`，低于 `5%` 地板。
- 复审依据：本轮重新执行 `anchors.py check`，10 个锚点全部通过；EDGE-321 使用全新真实 App session `20260829-135745`，录屏 `145.613333s`，收台前 `rig-check` 五通道全绿且录制区域无外部遮挡。
- 复审结论：警报是统计机制的预期停闸，不是放宽通过标准。L2 只在空稿负向探针、单次 POST、后续同 id PATCH、切出重开后的 UI/REST 一致性和五通道证据齐全后写入；L3-L5 仍明确为 `na`，没有把未测量质量冒充通过。
- 处理：保留 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、锚点有效期和 ledger gate 逻辑不变；以本次独立复审说明 ack `discovery-collapse`。
