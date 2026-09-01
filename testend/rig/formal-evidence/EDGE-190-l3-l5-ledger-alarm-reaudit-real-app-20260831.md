# EDGE-190 L3-L5 ledger alarm re-audit · 2026-08-31

本次 L3、L4、L5 连续写入同一真实 session 后，`gap-too-fast` 与 `discovery-collapse` 按原算法打开。
复审结论不是放宽规则，而是确认每一格的证据对象不同且真实存在：

- L3=`A4`：独立证据只判断 `thinking`/`Stop generating` 的长操作反馈、SSE 时间线和 Composer 收尾；不把后端成功或视觉截图重复当作等待证据。
- L4=`C4`：独立证据只判断展开结果卡的圆角、行距、mono ref、表格和 Composer 的成品关系；引用 `edge190-final.png`，不把 SSE 一致性当视觉通过。
- L5=`G1`：独立证据只判断普通用户语言从 Composer 进入 `search_blocks`、结果卡可展开、精确 ref 可定位；不把工具脚本入口当用户发现性。
- 三个证据文件都属于真实 session=`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-011939`，该 session 的五通道和封存状态已由 `rig-check`/`rig-down` 验证；历史 fail 未删除或覆盖。
- 本轮唯一的 `gap-too-fast` 原因是同一完整观察后的分层裁决按账本顺序连续落盘，不是无证据橡皮章；`discovery-collapse` 的 `2/50=4.0%` 仍保留为质量警报。
- anchor 10/10、hash 未变；未修改报警阈值、算法、CODEX、锚点、五级标准或顺序 gate。

处置：按原机制复审并 ack 两个 alarm；后续 judgment 仍从新水位重新计算。
