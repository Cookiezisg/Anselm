# EDGE-235 · ledger/alarm 独立复审

## 复审对象

本复审对应 `RIG_HOME=/private/tmp/anselm-rig-formal-20260831-11`，以及
`sessions/20260831-145945` 与 `sessions/20260831-150438` 两轮真实 App 现场。复审在
继续写入 Edge235 的后续等级前完成，目的只是验证账本指针、证据归属和报警处置，没有修改
报警阈值、曲线算法、CODEX、锚点或顺序门。

## 事实核对

- 初轮由同一 conductor 启动真实 App、backend、三路 SSE、frontend console、llmtap 和
  窗口录屏；真实 Scheduler 显示 3 个在途 workflow。SIGTERM 后 backend 正常收台，三路
  SSE clean EOF，owned process 归零且无 SIGKILL。
- 初轮 SQLite 保留三条 `running` flowrun，符合“关停不伪造节点结果、下次 boot Recover”
  的设计；没有用伪造的 completed/failed 状态替代 durable truth。
- 初轮发现 App 文案把“backend 已运行后失联”错误说成“backend didn't start”。该红线已
  停止推进并修复为 `BackendFailureReason`；复验轮重新编译真实 App，并在相同失联动作后
  显示“本地引擎已停止响应。点击重试以重新连接。”，没有 startup hint。
- `anchors.py check` 为 `10/10`；本次报警的 `gap-too-fast` 与 `discovery-collapse`
  是新增裁决后按既有规则自动开启，复审没有通过调阈值、删日志或重写历史来消除它们。
- 两个报警的销账理由均指向本文件和上述真实 session；每次后续等级写入前重新运行
  `alarms.py check`，再次触发则再次独立复审，不以批量命令绕过 gate。

## 结论

本次报警可以在不改变标准的前提下销账：证据是真实 App 的两轮现场，红线被发现、修复并
复验，清册与 journal 指针一致。Edge235 的 L2/L3/L4 仍按各自法条和证据单独裁决，L5
仍以明确适用性理由记录 `na`；本文件不替代任何一级产品证据，也不把预算-focused 测试
冒充真实 App 的最坏预算耗尽。
