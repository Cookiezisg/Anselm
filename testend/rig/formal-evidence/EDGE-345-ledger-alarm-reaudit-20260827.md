# EDGE-345 · 账本统计警报独立复审

本次 L2 写账后，既定 `alarms.py` 按原阈值打开 `gap-too-fast` 和 `discovery-collapse`。两项均按机制要求复审，不修改阈值、算法、法典或锚点。

- `gap-too-fast`：重新读取有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-222501/` 的录屏、Computer Use AX 状态、backend journal、三路 SSE、LLM wire 和前端日志；本次不是只读账本，真实回合跨越附件上传、上游登记等待、危险确认、语音生成等待、设置页复核和收台，证据完整。
- `discovery-collapse`：本次判定对象是已完成的正向音色登记与合成用户目的；没有把失败路径改成 pass，也没有删除或隐藏前置红事实。该警报反映当前窗口的样本组成，不足以否定这条已有完整证据的 L2 判断。
- 锚点：`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check /private/tmp/anselm-rig-formal-20260801-3/anchor-answers.json` 通过 `10/10`。
- 结论：两项警报均可在本复审证据下按原规则 ack；后续继续保留统计曲线，不因本次复审改变门禁。
