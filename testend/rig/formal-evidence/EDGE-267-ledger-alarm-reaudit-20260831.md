# EDGE-267 · 账本与警报复审

## 账本动作

真实 App session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-233046` 已正常收台，
录屏封存=`98.133333s`。按序写入：`L2=F2`、`L3=B2`、`L4=C5`、`L5=G1`；四格均绑定正式
真实 App 画面或正式证据，没有使用 provisional `na`，没有修改法典、阈值、锚点集或顺序门。

## 警报复审

四格写入后，`alarms.py check` 按原规则打开 `gap-too-fast` 与 `discovery-collapse`。逐项复审
确认本次是已封存录屏后的真实现场证据，空历史/无 marker 的结果由 App、REST、SQLite 和 SSE
共同证明，不是因“没有可见变化”而跳过观察。两项均保留规则和原阈值后串行 ack；最终
`alarms.py check` 回到 clean。
