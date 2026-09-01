# EDGE-189 L4 账本告警复审

- **告警：** `discovery-collapse`
- **触发：** 最近 50 条 live judgment 中 2 条 fail，fail share=`4.0%`，低于既定 `5%` floor
- **结论：** 复审通过，允许保留 EDGE-189 L4 判断并继续

## 独立核对

- 重新查看 `/private/tmp/edge189-l3-0831/final.png` 及其来源 session 的尾段，确认 L4 只依据稳定完成态画面：消息、活动行、引用块、Composer 与 island/card/pill 层级均可见且无 clipping、overlap、残留 loading 或系统遮挡。
- 重新确认 L4 evidence 未借用数据库、SSE 或 LLM 事实作为视觉通过理由；这些事实只用于确认截图对应的真实恢复路径，视觉结论来自实际 App 尾帧。
- 最近两条 fail 均有真实 red evidence，未被抹除或改判；本次 EDGE-189 L4 也没有因发现率告警而降低视觉标准。
- 未改变 `WINDOW=50`、`DISCOVERY_FLOOR=0.05`、告警算法、CODEX、anchors、五级标准或 ledger sequence；仅 ack 当前复审水位。
