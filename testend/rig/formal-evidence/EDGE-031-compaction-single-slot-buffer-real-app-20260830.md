# EDGE-031 · 回合收尾期单槽缓冲 · 真实 App 修复后复验

正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-140457`，由同一
conductor 归属 backend、Anselm App、录屏、SSE witness、frontend journal 和 LLM tap。
`rig-check` 在操作前通过五通道物理门槛，`rig-down` 封口后 `screen.mov` 可由 ffprobe 读取，
锚点校准为 `10/10`。

真实 App 在已含 context-compaction checkpoint 的 `Formal EDGE-031 compaction buffer` 会话中提交
`EDGE031-FIXED-APP-FIRST`，后端返回 `202`，assistant turn 正常完成。该 turn 在途期间，同一
conversation 的直接 HTTP submit `EDGE031-DIRECT-SECOND` 返回 `409 STREAM_IN_PROGRESS`。

本次 stop-and-fix 针对的缺陷是：拒绝路径此前只落库 assistant error，没有发送与已发送 open
配对的 message close，导致前端可能永久显示 thinking。修复后，SSE `messages` 记录拒绝 assistant
`msg_d3d8b9effab4c1f4` 的 `open → close(error)`（close durable seq `28`）；SQLite 记录
`status=error`、`stop_reason=error`、`error_code=STREAM_IN_PROGRESS`；LLM tap 没有为拒绝请求
产生第二次模型请求。接受请求随后以 assistant close `msg_8742a9f6ec2973b1`（durable seq `32`）
收尾。

Computer Use 最终稳定帧显示拒绝请求的 `Something went wrong · STREAM_IN_PROGRESS`，Composer
恢复可用，不再存在拒绝回合的 thinking 气泡。backend 只有本轮刻意构造的 missing attachment
warning，无 panic/FATAL；frontend journal 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；
SQLite `integrity_check` 和 `foreign_key_check` 保持健康。

关键帧=`sessions/20260830-140457/evidence/EDGE-031-fixed-close.jpeg`；会话内完整证据=`sessions/20260830-140457/evidence/EDGE-031-fixed-close.md`。
L4 craft 与 L5 discoverability 尚未由本轮顺带放行。
