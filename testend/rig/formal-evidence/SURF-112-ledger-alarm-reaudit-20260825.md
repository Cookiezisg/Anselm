# SURF-112 ledger and alarm re-audit

## Evidence decision

本轮绿判覆盖真实 App 的 read/write memory 舞台、AI 更新保留用户 pin/source、以及 REST-only pin/unpin。Computer Use、受管网关、三路 SSE、backend/frontend journal 和 LLM tap 均来自同一 session；临时 fixture 的 REST 写入只用于构造可重复真相，不替代产品路径。

## Ledger integrity

- `anchors.py check`: 10/10 calibration passed。
- SURF-111 已在本轮之前五级通过；本轮没有修改阈值、法典、锚点集或账本顺序。
- session 收台前 `rig-check` 通过，收台后 App、backend、ssetap、llmtap、recorder 均无残留。

## Alarm handling

五格写入期间若出现 `gap-too-fast`、`pass-burst` 或 `discovery-collapse`，必须只用本 session 的最终录屏、五通道日志、REST 真相和 focused tests 复核，再串行 ack。清洁结果只能说明统计曲线已复核，不得抹掉本轮任何负向或 instrumentation 事实。
