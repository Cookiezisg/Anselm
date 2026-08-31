# EDGE-268 · L2 账本与警报复审

L2 使用已封存真实 App session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-233736`，
证据=`EDGE-268-archive-idempotent-real-app-20260831.md`，法条=`F2`。L3-L5 没有提前写入。

写账后 `alarms.py check` 若打开统计警报，必须逐项复核真实录屏、backend journal、SSE、frontend
console 和 LLM tap 的同场归属，再按原阈值 ack；不得改阈值、法典、锚点或五级标准。
