# EDGE-343 · L3 账本与警报独立复审

## 复审对象

- 新增裁决：`EDGE|工具参数双线缆形|L3 = pass (A1)`。
- 正式账本根：`/private/tmp/anselm-rig-formal-20260801-3`。
- 实际证据：`EDGE-343-tool-arguments-real-app-l3-20260902.md`，session 为
  `/private/tmp/anselm-rig-formal-20260902-09/sessions/20260902-023042`。

## 复审结论

- 证据来自全新隔离 workspace 的真实 App 路径，不是旧 L2 transcript 的复制。
- 同一对话真实完成 object 与 JSON-string 两轮参数调用；用户输入的 `points=21/34`、
  函数返回值、LLM wire、SSE durable result 和 App 工具卡片逐一一致。
- session 具备连续 screen recording、backend journal、三路独立 SSE witness、frontend
  console 和 LLM wire 五类证据；`rig-check.sh` 与 `rig-down.sh` 均通过。
- 台架曾出现阶段判定、计数器和参数值三处问题，均在入账前停下修复并重新启动全新台架；
  修复前请求没有被用于本次裁决。
- `A1` 在 `CODEX.md` 中存在且明确对应 L3 顺滑性；没有用 L2、L4 或 L5 证据替代本格。
- anchor 校准仍为通过状态；未修改 anchor、警报阈值、算法、法典、五级标准或正式序列。

## 警报处置

`discovery-collapse` 仅因最近 50 条裁决的 fail share 为 `4.0%`，低于既定 `5%` 地板而
打开。该信号必须先复审，不能解释成产品通过，也不能通过放宽阈值消除。本复审确认本格
确有独立、可重取的五通道证据，故仅对本证据水位 ack；后续新裁决仍必须重新经过
`alarms.py check`。
