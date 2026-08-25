# EDGE-178 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-178-search-embedder-off-fallback-20260825.md`。
- 复审结论：focused provider-failure/off 路径与真实设置、跨 workspace、词法命中和死 Ollama 软降级均通过；fixture 中刻意关闭的 free-tier 端口 warning 已在证据中隔离，L2-L5 保持 `na`。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
