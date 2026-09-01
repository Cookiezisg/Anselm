# EDGE-233 账本警报复审

本格的 `gap-too-fast` / `discovery-collapse` 只反映近期裁决统计窗口，不能因为真实
Scheduler 重启证据看起来清晰就跳过复审。复审重新核对 formal session 的 `screen.mov`、
`backend.log`、`frontend.log`、`sse.jsonl`、`llm.jsonl`、SQLite 结果以及
`rig-check`/`rig-down` 封口：录屏可读，三路 SSE 各连接一次并 clean EOF，backend/frontend
没有应用红线，2 条 `missed` 均无 `flowrun_id`，workflow 没有被补跑。

警报复审不修改阈值、曲线算法、CODEX、锚点、顺序门或五级标准。没有 fail-share 不能
自动当作绿色；本格同时保留 setup→真实停机→正式重启的完整证据和 Scheduler 终帧，故
每次新裁决后的告警可按原阈值 ack，后续裁决仍会重新计算并可能重新打开。
