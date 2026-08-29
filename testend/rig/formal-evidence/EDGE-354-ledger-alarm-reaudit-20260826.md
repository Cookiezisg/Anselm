# EDGE-354 账本/警报独立复审

## 范围

- 本次追加 `generate_image` 2 格、`edit_image` 3 格、`core/media-viewer` 3 格，均为已收口旧格的
  `--revalidate`，不是新的清册行；`COVERAGE` 仍为 `848 rows / 848 carried judgments / 0 tombstones`。
- 所有 pass 在正式台架 session
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260826-230803` 封口后写入；L2 evidence
  与该 session 的 manifest、backend、SSE、frontend、LLM、screen.mov 同源。锚点复核为 `10/10`，
  hash 未变化。
- 追加前 formal ledger 为 `2300 baseline + 1941 live`；追加后为 `2300 baseline + 1949 live`。

## 警报处置

- `gap-too-fast` 是脚本连续写入 8 个已完成复审格造成的统计信号。每个格子的真实 App、录屏、
  五通道或产品证据均在 `EDGE-354-media-generation-edit-red-green-20260826.md` 中有定位；它不代表
  观察发生在 0 秒内。
- `discovery-collapse` 只说明最近窗口没有新增 fail。红场问题被保留、修复后新二进制重建并重新
  观察；没有把绿色回合推广成所有媒体路径通过，也没有跳过未覆盖的语音、视频、动画路径。
- 独立复审不修改报警阈值、算法、CODEX、锚点、覆盖顺序或产品标准。两项警报可按原命令 ack，
  后续新裁决仍重新计算。
