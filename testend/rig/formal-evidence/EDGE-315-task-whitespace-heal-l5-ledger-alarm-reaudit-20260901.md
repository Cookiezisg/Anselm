# EDGE-315 空 task 尾空格腐化：L5 ledger/alarm 独立复审

- judgment: `EDGE|空 task 尾空格腐化|L5|na|G1`
- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-204918`
- primary evidence: `testend/rig/formal-evidence/EDGE-315-task-whitespace-heal-l5-real-app-boundary-20260901.md`

## Independent re-audit

- `CODEX.md` 中存在 `G1`，但本次裁决使用的是法条适用性边界，不是把 G1 变成默认豁免。
- 真实 App 的 Library 入口、空 task 画面、稳定终帧和录屏均可复查；主证据不是空 note，也不是仅有
  单元测试的声明。
- backend、SSE、frontend、LLM journal 均为非空，`rig-check.sh` 五通道通过，`rig-down.sh` 已封口并
  收台 owned processes；LLM 无调用的事实被明确记录，没有用它冒充产品证据。
- durable 文档与画面保持同一三行结构；不存在临时字符、字面量 `[ ]` 或结构丢失。
- 锚点集已重新校准 `10/10`，当前判断未修改法典、阈值、顺序门或五级标准。

## Applicability and alarm disposition

`discovery-collapse` 因最近 50 条裁决 fail-share 为 `0.0%` 而打开。独立复审确认本项的 L5 确实
不适用：尾空格修复是用户不应感知的编辑器正确性不变量，没有独立入口、设置、命令、tooltip 或
快捷键；真实现场已证明产品入口本身可用，但不能把内部行为伪装成发现性 pass。该解释只适用于本项，
不推广为全产品“没有 fail 就正常”。因此在复审记录落盘后 ack 警报。
