# SURF-104 · 账本与警报独立复审

- 首轮字符串化 `ops` 误分类已保留为红事实；修复后 focused suite=`41/41`，绿色 session 的五通道证据同一封闭 session，不混用首轮资料。
- 五级裁决均引用 CODEX 法条并绑定非空证据；L2 绑定 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-080352` 内的五通道文件。
- 告警复审不改阈值、算法、法典、锚点或 gate；若本次集中写账触发 gap/discovery 告警，只能以本记录说明其为写账统计形状并逐条 ack，最终 `alarms.py check` 必须 clean。
