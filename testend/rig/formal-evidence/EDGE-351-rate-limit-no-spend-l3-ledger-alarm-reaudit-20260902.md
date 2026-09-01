# EDGE-351 | 429 不动钱 | L3 账本与警报复审

本次 L3 判定引用 `A4`，该法条存在于 `docs/working/acceptance-loop/CODEX.md`；主证据
`EDGE-351-rate-limit-no-spend-l3-real-app-20260902.md` 已落盘且非空。正式 session 的五通道文件、真实 App
录屏、受管网关 wire、backend journal 和三路 SSE 均可追溯，旧错误 fixture 已独立标为红证据。

复审步骤：先运行 `anchors.py check`，10/10 校准通过；确认本次 429 语义不是额度耗尽且配额快照不变；确认
`judge.py` 没有无证据或 provisional-na 判绿。随后按原阈值接受 `discovery-collapse` 警报并记录本复审，未修改
警报算法、阈值、法典、锚点或五级标准。
