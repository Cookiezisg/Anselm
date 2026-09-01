# EDGE-299 · 账本警报独立复审

## 复审对象

本复审对应正式台架 `/private/tmp/anselm-rig-formal-20260831-11` 在 EDGE-299 L2 写账后
打开的 `gap-too-fast` 与 `discovery-collapse`。两者都按原阈值处理，没有修改算法、窗口、法典、
锚点或五级标准。

## 复审动作

- 重新执行 `anchors.py check`：`10/10`，anchor set hash 未变，judge 在四小时窗口内解锁。
- 独立读取同一封存 session
  `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-141545` 的
  `manifest.json`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和 `screen.mov`；
  session 已在正式 `RIG_HOME/sessions` 下，manifest 的绝对 session identity 与目录一致。
- 独立 `ffprobe` 验证录屏为可读的 H.264 `3104x1844`、`60fps`、`313.828333s`；
  SSE 三流存在，通知 durable seq=`16..10015` 连续且无 gap；backend/frontend 应用红线扫描均为 0。
- 回看正式证据 `EDGE-299-notice-backlog-real-app-20260901.md` 及其 session-local 副本，确认
  10000 条压力请求、实时顶带固定投影和五通道边界均有具体证据，不以无 completion 的 LLM wire
  冒充聊天完成。

## 警报结论

- `gap-too-fast` 的触发原因是连续写账间隔确实低于 25 秒；它是“需要复审”的质量信号，不是
  证据无效。复审已确认本次 L2 只写一格、证据来自同一 sealed session，故可以销本次水位，未来新
  裁决仍会重新计算。
- `discovery-collapse` 的触发原因是近 50 格 fail share 为 0%；这不能证明产品整体没有缺陷。
  本格是独立的通知压力验证，复审未把成功样本外推为全局健康，故只销本次水位，保留原阈值。

结论：两条警报均已按独立证据复审，可以串行 ack；下一格前仍必须再次运行 `alarms.py check`。
