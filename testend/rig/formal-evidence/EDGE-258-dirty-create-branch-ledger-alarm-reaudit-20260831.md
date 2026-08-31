# EDGE-258 · 账本 / 警报复核

本格只在真实 App session 完整收台后写入 L2-L5。L2 使用 session-local witness，L3-L5 使用
仓库内正式证据；四格分别引用 `F2 / B2 / C5 / G1`，没有用 focused 回归替代真实产品证据。

每次写账后的统计窗口均按原机制检查。`discovery-collapse` 在 L2-L4 后打开，L5 后与
`gap-too-fast` 一起打开；每次均独立复核真实录屏、最终帧、backend/SSE/frontend/LLM journal、
focused 回归和 `rig-check`/`rig-down`，随后逐项 ack。没有修改阈值、曲线算法、CODEX、锚点、
五级标准或顺序 gate。

最终命令：

`RIG_HOME=/private/tmp/anselm-rig-formal-20260831-11 python3 testend/rig/alarms.py check`

最终结果为 clean；本格的四个 pass 来自可复查的真实证据，不是由低 fail-share 或过快写账自动
放行。锚点校准仍为 `10/10`，清册生成检查为 `848 rows / 848 carried judgments / 0 tombstones`。
