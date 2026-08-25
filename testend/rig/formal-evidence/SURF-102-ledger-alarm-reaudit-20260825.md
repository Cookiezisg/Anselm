# SURF-102 · 账本与警报独立复审

本复审独立检查 `SURF-102 stage/function` 的五条裁决，而不是重写产品结论。

- 五条 judgment 均指向已存在的 CODEX 法条：`E2/F2/B2/C4/G1`。
- L1/L3/L4/L5 指向仓内正式调查记录；L2 指向本次真实 session 内的五通道证据。
- focused Flutter suite 为 `+40`；真实短编辑落定 v5，无重复失败卡片；长代码 probe 的错误形状
  调用和三条后端 WARN 均在证据中明确列为负向事实，没有被计为绿色成功。
- 真实 session 的 Screen、backend、SSE、LLM wire、frontend 五通道都可定位；SSE 三条 durable
  序列单调唯一且无 gap，`rig-check`/`rig-down` 均已通过。

`gap-too-fast` 与 `discovery-collapse` 是 ledger gate 的统计保护，不是产品失败。它们由批次中
连续写入五级账本触发；本复审不修改阈值、算法、法典、锚点或 gate，只按本文件记录事实后独立
确认可以 ack。若后续批次再次出现同一信号，必须重新复审，不得沿用本 ack。
