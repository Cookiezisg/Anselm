# EDGE-199 账本警报复审：真实回退 session

- **警报**：`gap-too-fast`
- **复审对象**：`代理图未 ready` L2-L5，登记时间为 `00:47:46` 至 `00:48:02 UTC`
- **真实证据**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-084340/evidence/EDGE-199-attachment-proxy-not-ready-green.md`
- **真实录屏**：同 session `recording.mov`，`116.865000s`

## 复审结论

警报由四个等级裁决在同一 session 内连续写账触发，属于写账速率信号，不是证据观看时长信号。该 session 在写账前已经完成真实文件选择器、真实 App、真实 managed gateway、backend journal、三路 SSE、LLM wire、frontend console 和录屏的交叉核对；`rig-check` 与 `rig-down` 均通过。

关键事实不是裁决调用的秒级间隔，而是现场时序：

- user attachment durable close：`08:45:25.507680+08:00`
- 原图内容读取：`08:45:25.778+08:00`，`2995581` bytes
- managed upload create：`08:45:27.519486+08:00`
- 原图分片：`00005_v1_media_uploads_mup_60a7c8049fd2e03b277bb7379d7df21c.bin`，`2995581` bytes
- chat request：`08:45:28.383785+08:00`
- derivative ready：`08:45:37.727510+08:00`，`943140` bytes、`2048x2048`
- assistant completed message close：`08:46:16.272981+08:00`

这证明四格来自已完成、可回放的同一真实证据包，不是无证据橡皮章。复审不改变警报阈值、法条、锚点或覆盖边界，仅按记录销账本次已观察的 journal 水位。
