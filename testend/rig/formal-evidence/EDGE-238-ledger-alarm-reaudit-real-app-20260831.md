# EDGE-238 · ledger/alarm 独立复审

本复审不新增产品结论，只核对本格每次写账后的机械门禁：

- 复读正式会话 `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-160154` 与
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-161135` 的 manifest、录屏、backend、
  frontend、三路 SSE 和 LLM journal，确认它们属于 conductor 且已封口。
- 复核 `settings.json`、`GET /limits`、`GET /network`、`GET /retention` 与 App 画面：三段均存在，
  limits=`26`、retention=`180`、network=`{}`，重启后相同。
- 固定锚点仍为 `10/10`；不修改 CODEX、阈值、曲线算法、顺序门或五级标准。
- 仅对该次新写账触发的统计告警逐条执行 `alarms.py ack`，销账说明绑定本复审文件与最新 journal 水位。
