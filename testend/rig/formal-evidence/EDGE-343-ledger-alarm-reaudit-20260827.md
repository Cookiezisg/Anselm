# EDGE-343 账本/警报独立复审

本次只登记 `EDGE-343` 的 L2 一个新格，且在登记前完成了真实 App 五通道复核。有效 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-215555/`；录屏为 H.264、60fps、
`2784x1808`、`175.438333s`。证据文件已复制到该 session 的 `evidence/` 目录。

## 复核证据

- UI：真实选择 `qwen-plus`，两轮用户消息分别触发 object 与 JSON-string 参数，函数各执行一次，
  两轮均在 Composer 可继续使用的完成态结束。
- LLM wire：`/private/tmp/edge343-provider-wire.jsonl` 的两次 tool-result 请求分别保留原生
  `args` 对象和 JSON 字符串；不是静态 fixture transcript。
- SSE：messages durable 区间为第一轮 `4..10`、第二轮 `15..21`，tool call/result 与助手完成帧
  成对落盘；entities 记录 function completed，touchpoint 计数为 `2`。
- backend/frontend：对应 session 无应用级 `WARN`/`ERROR`/panic/fatal，也无 Flutter/Dart/
  RenderFlex/Unhandled/Exception 红线；`rig-check.sh` 在运行中通过，`rig-down.sh` 封口无残留。
- `anchors.py check` 为 `10/10`，`gen_coverage.py --check` 为 `848/848/0`。

## 警报处置

`alarms.py check` 在新裁决后按原规则打开 `gap-too-fast` 与 `discovery-collapse`。前者来自本次
单格裁决与前一批账本写入时间相邻，后者来自本批没有 fail；两者都是统计信号，不等于跳过证据。
本复审不修改阈值、算法、法典、锚点或覆盖范围，只确认本格具有独立、完整的五通道证据，并在
复审完成后按原机制串行 ack。后续新格仍重新计算两条曲线。
