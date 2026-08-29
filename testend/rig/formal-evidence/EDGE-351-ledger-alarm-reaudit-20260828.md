# EDGE-351 ledger alarm re-audit

本次 `EDGE-351` 写入 L2 后，`alarms.py check` 按既定阈值打开 `gap-too-fast` 与 `discovery-collapse`。
这是裁决节奏/近期失败发现率的统计信号，不是对 EDGE-351 产品证据的否定；不修改阈值、算法、法典或锚点。

- **gap-too-fast**：近窗包含历史集中落账，间隔中位数低于 25s。已逐项核对本格实际经过代码审查、前端回归、真实 App、配额前后快照、SSE、LLM tap、backend/frontend journal 和录屏，不是无证据橡皮章。
- **discovery-collapse**：近窗 fail 占比低于 5%。本格首轮真实 App 确实发现错误文案并停止推进，修复后才重新跑绿；该 fail→fix→retest 链条保留在 `EDGE-351-rate-limit-no-spend-20260828.md`。
- **独立结论**：两条警报均按原门槛复审后销账；没有用降低门槛或改算法消除信号。
- **正式 session**：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-011403`。
