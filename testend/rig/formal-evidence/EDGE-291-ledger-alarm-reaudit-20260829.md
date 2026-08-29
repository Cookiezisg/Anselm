# EDGE-291 · 账本警报独立复审

- 复审对象：`discovery-collapse`。本次 `EDGE-291 L2` 入账后，近 50 条正式裁决的 fail 占比为 `0.0%`，按既定阈值打开警报。
- 复审方法：重新核对 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816/evidence/EDGE-291-memory-curation-real-app-20260829.md`、manifest、frontend/backend journals、SSE journal、LLM wire、两张真实 App 关键帧、SQLite 完整性结果和本次 judge 输入；确认一次错误 evidence 路径只被拒绝、没有产生账本行。
- 结论：正式 pass 有真实 App L2 证据，警报只是裁决分布的机械提示；未修改 fail-share 阈值、统计算法、法典、锚点答案或 gate，可以在复审后 ack。
