# EDGE-020 `approve_always` 真实 App 复验

正式证据副本：
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260826-234717/evidence/EDGE-020-approve-always-real-app-20260826.md`

本复验确认：修复后二进制的 App 原生「新对话」路径第一次 `run_function` 调用展示危险
确认卡，点击「总是允许」后成功；模型准确说明人工审批已批准；同一对话第二次同工具
调用生成新 tool call 和成功回执，期间没有第二个 interaction signal。首结果带
`humanApproval=true`，次结果不带该属性，触点 count=2。录屏为新 session 的
`screen.mov`（93.046667s），五通道 journal 与排除项详见 session evidence。
