# EDGE-331 · 账本与统计警报独立复核

## 复核对象

- 新增裁决：`EDGE|限额面板载入失败|L2|pass|G2`
- 真实 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-024929`
- 证据：`EDGE-331-limits-load-failure-real-app-20260828.md`
- 红场先例：`EDGE-331-limits-load-failure-red-scene-20260828.md`

## 五通道独立复核

- 录屏时长 `59.141667s`，覆盖 503 错误态、可重试本地化文案、Retry 和恢复后的限额字段。
- `appproxy.jsonl` 证明 schema 首次 503，Retry 后一次 forward；backend 对 schema 与 limits 返回 200。
- `ssetap` 连接当前 workspace 的 messages/entities/notifications 三路并正常 EOF 收台。
- App PID、窗口录制 PID、backend `:8742`、ssetap `:8788`、llmtap 与代理均通过 `rig-check` 归属校验。
- frontend journal 无 Flutter/Dart/RenderFlex/RenderBox/overflow 红线；managed challenge/install/models 全部 200。

## 警报处置

- `gap-too-fast`：触发原因是正式重跑裁决集中写入，不代表跳过画面；已重新核对 session 录屏和五通道文件后 ack。
- `pass-burst`：同上，EDGE-331 先有独立红场、修复和专测，再有新 session 重跑；没有用批量脚本伪造证据；已 ack。
- `discovery-collapse`：本次是既有连续通过窗口的统计提示；红场证据仍保留且未计绿，覆盖顺序和 stop-and-fix 规则未放宽；已 ack。

三项警报均以本次 session 和本记录为 resolution，未修改阈值、算法或历史 journal。最终应由
`alarms.py check` 重新得到 clean 后，才允许继续下一格。
