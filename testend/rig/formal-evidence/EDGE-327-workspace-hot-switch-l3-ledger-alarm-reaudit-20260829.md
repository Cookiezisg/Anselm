# EDGE-327 · 账本与警报独立复审

- subject: `EDGE-327 / workspace 热切换三拍 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-327-workspace-hot-switch-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-231929`
- law: `B2`

## 复审结论

源深链和目标空 landing 均由真实 App 和真实网关产生。切换瞬间的可见状态符合协议：先离开旧深链，随后目标 workspace 名称和空 Chat landing 出现；目标静置 `6s` 无二次重排，切回源后原对话仍可回访。录屏黑帧检测为零，101 个 1fps 样本已封存。

五通道证据与持久真相一致：backend 记录源消息读取、目标 activation 和目标列表重取均为 `200`；SSE 覆盖两个 workspace，messages=`1..64`、notifications=`1..2` 单调；LLM 线缆有真实 chat completion `200`；前端无未解释应用红线。该证据不把目标空态误判为源数据丢失，也不把“切换正确”扩大为 L4/L5。

锚点校准为 `10/10`，`judge.py` 应使用 CODEX 中存在的 `B2` 和上述非空证据写入 `EDGE-327 L3 pass`。本复审不修改标准、阈值、法典、锚点或 ledger gate；统计警报只能按真实复核结果 ack，不能调阈值绕过。
