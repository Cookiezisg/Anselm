# EDGE-343 · 工具参数双线缆形 · L4 账本与警报独立复审

## 复审范围

- 复审本格 `L4=pass (A4)`，对应证据
  `testend/rig/formal-evidence/EDGE-343-tool-arguments-real-app-l4-20260902.md`。
- 正式账本根目录=`/private/tmp/anselm-rig-formal-20260801-3`；真实 App session=
  `/private/tmp/anselm-rig-formal-20260902-11/sessions/20260902-024745`。
- 复审前重新执行 `anchors.py check`，结果为 `10/10`；没有修改警报阈值、算法、CODEX
  法条、锚点答案、五级标准或顺序门。

## 证据复核

- 证据文件、`screen.mov`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和
  `manifest.json` 均存在且非空；manifest 的 App、backend、ssetap、llmtap、recorder
  归属与 session 一致。
- 真实 App 在慢 function 超过 1 秒期间显示 Live 状态，真实 tool result close 后显示
  Ran；Activity 的 `2 touched · 2 executed` 与 SSE 的 function entity、tool result、
  touchpoint 和 assistant close 相互吻合。该观察直接支持 `A4`，不是从静态代码或 focused
  test 推断。
- 前一轮旧对话中的疑似 Live 残留在本轮冷启动和可重复慢调用中没有复现；证据明确保留
  该边界，没有把旧状态误报当成已修复的产品缺陷。
- `rig-check.sh` 与 `rig-down.sh` 均通过；backend 没有应用级 panic/FATAL/ERROR/WARN，
  frontend 只有已分类的 macOS IMK 宿主诊断和已撤回诊断构建的 stage-trace，不构成产品
  红线。

## 警报处置

本次写账后 `alarms.py check` 按原阈值打开 `discovery-collapse`：最近 50 条 live
裁决的 fail 占比为 `4.0%`，低于 `5%` 发现率下限。该信号表示需要复审判断质量，不能
被当作产品通过，也不能通过改阈值消除。锚点自校、独立五通道证据和本复审确认本格确实
完成了所声明的 L4 检查；随后仅用 `alarms.py ack discovery-collapse` 记录本次证据水位
的处理结果。未来新证据仍须重新经过同一警报门。
