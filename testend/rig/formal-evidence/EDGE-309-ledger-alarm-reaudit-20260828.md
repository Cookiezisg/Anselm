# EDGE-309 账本与警报复审

- target: `EDGE-309 / 侧幕分档时钟 / L2`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`
- primary evidence: `EDGE-309-sidestage-relative-clock-real-app-20260828.md`

本格在统一 session 收台、五通道证据齐全、锚点 `10/10` 且不超过 4 小时后，才由 `judge.py` 写入。没有修改 CODEX 法条、警报阈值、覆盖顺序或锚点答案。

本次 `discovery-collapse` 是尾部 50 条裁决中 fail 占比为 0 的统计提醒，不是本格证据缺失。已重新核对本格的真实红场历史、录屏前后帧、最终 AX 树和五通道 journal；EDGE-309 仍只写 L2 pass，L3-L5 保持 `na`，未把未测维度算作通过。按既有机制，该报警在本次新证据之后完成复审并销账，阈值和算法保持不变。
