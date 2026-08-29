# EDGE-007 · 账本警报独立复核（2026-08-30）

本次 `discovery-collapse` 是在写入 EDGE-007 L2 后按机制自动打开的统计保护，不是对该场景的产品失败判定。复核重新检查了同一个封存 session `20260830-013849` 的真实 App 画面、SQLite 终态、三路 SSE、LLM tap、backend/frontend journal 和录屏收台结果；L3/L5 没有被错误写绿。

- EDGE-007 L2 只按 `F1` 写入，随后 L3 只按 `B2` 写入，清册 `✓✓✓✓~` 与证据边界一致；L5 仍未结算。
- messages durable seq 连续 `1..40`，SQLite `integrity_check=ok`，assistant 为 `TOOL_ERROR_STORM`，三张失败 tool_result 均为 `error`。
- 录屏为 `138.893333s / 3104x1844 / 60fps`；实时与切换后重新水化画面均展示同一终态提示。
- 录屏 1fps 抽样共 139 帧；返回会话后的末 13 秒没有超过 `0.0005` 的非用户变化，支持 L3 的 B2 判定。
- 本复核不修改 `alarms.py` 阈值、算法、法典或锚点；确认警报来自历史通过率统计后，按现有机制 ack。

结果：anchors `10/10`，警报已销账，`alarms.py check`=`clean (2035 live judgments; 2300 baseline judgments excluded from drift curves)`。
