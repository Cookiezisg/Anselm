# EDGE-300 L5 可发现性证据（2026-09-01）

正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-144816`。

Computer Use 读取的真实 AX 树直接暴露 `Awaiting approval`、`Approve`、`Reject`、`Dismiss`；用户不需要知道 workflow 内部 API 或队列实现即可知道如何处理。普通事件显示 `Skill ... created · View`，积压时显示 `Clear all N top notifications`，且只有当前卡承担操作，不把隐藏的 backlog 假装成可操作列表。两次公平接班都在真实 App 中观察到，非 demo route、非单测模拟。

前端日志仅有已知 macOS IMK 诊断，无应用级 Dart/Flutter/布局红线；五通道 session 已正常收台。法条：G1。
