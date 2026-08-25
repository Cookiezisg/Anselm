# SURF-107 · 账本与警报复审

SURF-107 的首轮红事实不是统计噪声：通用 ISO 脱敏器确实破坏了用户要求的 `nextFireAt`，并已在 `backend/internal/app/loop/redact.go` 修复；修复测试和修复后真实 session 均封存。四脸初始构建中的 malformed sensor target、malformed ID 与输入桥残缺请求均按负向事实保留，未计入绿。

本次五格裁决使用修复后 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-092425` 的完整 manifest、backend、SSE、frontend、LLM 和录屏证据；level-2 的 evidence 文件位于同一 session 目录。`anchors.py check` 仍为 10/10，anchor 文件未改；没有调整警报阈值、算法、CODEX 或 gate。写入集中 ledger 后若 `gap-too-fast`/`pass-burst`/`discovery-collapse` 打开，只能以本文件和上述红绿证据逐项复审、串行 ack，不能直接绕过。

复审标准：红路径已停止并修复；绿路径由五通道互证；`nextFireAt` 的字段级保护既恢复用户需要的准确值，又保留其它时间的脱敏边界。警报销账后必须再次运行 `alarms.py check`，结果应为 clean。
