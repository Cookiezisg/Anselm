# EDGE-315 空 task 尾空格腐化：L4 ledger/alarm 独立复审

- judgment: `EDGE|空 task 尾空格腐化|L4|pass|C4`
- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-204203`
- primary evidence: `testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-l4-real-app-20260901.md`

## Independent re-audit

本次复审不重复使用主证据中的视觉结论作为唯一依据，而逐项核对 gate 所要求的完整性：

- `CODEX.md` 中存在并仍适用的法条是 `C4`，不是临时拼写或不存在的 law。
- 主证据指向真实 App 录屏、动作窗口和稳定收尾帧，并列出 measured diff；不是空 note 或静态 fixture 声明。
- backend、SSE、frontend、LLM 四份 journal 均有非空计数，且 frontend/backend 的红线扫描结果已写明。
- durable SQLite 原文与录屏复开后的三行结构一致，输入的临时 `temp` 没有进入最终文档。
- `rig-check.sh` 五通道通过，`rig-down.sh` 已封口并收台 owned processes；session 可被复查。
- 10-anchor calibration 已用当前 anchor set 重新通过，故本次 pass 没有绕过判断自校准。

## Alarm disposition

`alarms.py check` 在新增裁决后打开 `discovery-collapse`，原因是最近 50 条裁决的 fail-share 为 `0.0%`。
该警报的含义是要求复查“判断是否变松”，不是把本项降级为 fail。复审确认本项确有 C4 视觉证据、真实
五通道和 durable 交叉证据，且没有用 `na` 或旧 baseline 代替 pass。复审记录完成后才允许 ack；后续
主线继续由顺序门选择，不因警报自动跳格。
