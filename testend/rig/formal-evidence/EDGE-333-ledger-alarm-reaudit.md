# EDGE-333 账本警报复审

本次 `EDGE-333` 的 `L2/F1` 是在真实台架收台、证据封存后写入的单个新判决。它触发
`gap-too-fast`，因为上一条账本时间与本条相邻且间隔中位数低于 25 秒；同时，近 50 条新判决暂时没有
失败项，触发 `discovery-collapse`。两者是裁决节奏/发现率的统计信号，不是对 EDGE-333 产品行为的绿判。

复审依据：

- 本条有独立 sealed session，包含 `manifest.json`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl`
  和可读的 `screen.mov`；`rig-check` 前后均通过，`rig-down` 已收台。
- Computer Use 真实观察了 `90 天 → 30 天 → 90 天`，并看到了更新反馈；backend 的 PATCH/GET、最终 REST 值、
  SQLite 完整性和前端日志相互吻合。
- 没有跳过失败路径，也没有把设置路径不存在的 LLM completion 或业务 SSE 事件伪造为证据。

处置：接受本次两个统计信号为已复审的真实短窗口，不修改阈值、算法、法典、锚点或产品判决；继续保留
后续新证据触发警报的能力，并在警报复审后恢复账本写入。
