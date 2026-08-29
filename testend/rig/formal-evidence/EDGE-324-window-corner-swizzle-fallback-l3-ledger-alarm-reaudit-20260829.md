# EDGE-324 · 账本与警报独立复审

- subject: `EDGE-324 / 窗角半径 swizzle 失效 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-324-window-corner-swizzle-fallback-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231353`
- law: `B2`

## 复审结论

本格的 L2 故障注入和 L3 真实动态稳定性分开取证：L2 session 模拟四个 `NSThemeFrame` getter 不存在，证明 nil guard 能回落系统圆角并启动；L3 session 使用正式构建创建工作区并完成 Chat、Entities、Library、Settings 往返，证明该降级路径在真实产品运行中不会导致导航重挂或持续视觉跳变。

L3 源录像 `105.198333s` 的黑帧检测为零，1fps 样本、Computer Use AX 和 5 秒静置态互相一致。五通道 journal、启动/收台 gate 和前端错误分类均已在源证据中列明；唯一 IMK 行是宿主诊断，不被误报成 Flutter 产品错误。

锚点校准为 `10/10`，`judge.py` 应使用 CODEX 中存在的 `B2` 和上述非空证据写入 `EDGE-324 L3 pass`。本复审不修改标准、阈值、法典、锚点或 ledger gate；统计警报只能按真实复审结果 ack，不能通过放宽阈值消除。
