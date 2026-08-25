# SURF-109 ledger/alarm re-audit

- 本格五级裁决使用同一个已经收台的真实 session 证据包；不是用历史截图或 synthetic fixture 代替。
- `gap-too-fast` 与 `discovery-collapse` 若因同批五级写入而开启，只能逐条核对该证据包后串行 ack；不得改阈值、算法、CODEX、锚点或 gate，也不得吞掉本轮三条错误工具路径。
- 错误 create/edit 的 backend WARN、SSE error close、前端失败卡均保留；正向 v2 由 frame、REST/backend、SSE、frontend log、LLM wire 五通道独立支持。
- 本复审不把“模型自纠”当作无错误；它只证明失败可解释、无副作用且最终版本满足用户目的。
