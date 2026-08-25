# SURF-113 ledger and alarm re-audit

## Evidence decision

本轮绿判覆盖真实市场发现、危险安装确认、MCP ready 货架和一次重连；没有用普通 MCP 执行结果充当工具发现，也没有把用户一次性允许升级成永久授权。

## Ledger integrity

- `anchors.py check`: 10/10 calibration passed。
- SURF-112 已在本轮之前五级通过；未修改阈值、报警算法、CODEX、锚点集或账本顺序。
- `rig-check` 在收台前通过，`rig-down` 后 App、backend、ssetap、llmtap、recorder 全部退出，无孤儿进程。

## Alarm handling

五格写入期间若出现 `gap-too-fast`、`pass-burst` 或 `discovery-collapse`，只用本 session 的最终录屏、SSE/backend/frontend/LLM journals、REST MCP truth 和 focused tests 独立复核，再串行 ack；不会因安装成功而跳过危险闸或失败率审查。
