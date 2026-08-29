# EDGE-319 · 账本警报独立复审

- 触发：本次 L2 写入后 `discovery-collapse` 提示近 50 次裁决 fail 占比为 0%。
- 复审 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`，录制已由 `rig-down.sh` 封存，五通道文件齐全。
- 锚点重新校验：`anchors.py check` 10/10，通过；锚点 hash 未变。
- EDGE-319 的新增裁决由真实 App 的 8 项 Outline 与正文顺序核验支撑；L3-L5 保持 `na`，没有扩大结论。
- 近 50 次 fail=0 不是产品无缺陷证明；不修改警报阈值、算法、法典、锚点或账本 gate，按既定流程销账。
