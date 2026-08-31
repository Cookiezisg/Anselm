# EDGE-205 账本警报复审：真实朗读缓存 LRU

- **警报**：`gap-too-fast`
- **复审对象**：`EDGE-205|朗读缓存 LRU 淘汰` L2-L5，登记于本正式 session 的连续裁决窗口
- **真实证据**：`testend/rig/formal-evidence/EDGE-205-real-app-readaloud-cache-lru-green-20260831.md`
- **正式 session**：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-094003`
- **真实录屏**：同 session `recording.mov`，`412.046667s`

## 复审结论

警报由四个等级裁决的写入间隔触发，属于裁决速率信号，不是证据观看时长信号。本次复审重新核对同一正式 session 的五通道证据和原始时序：四个独立的真实语音产物通过受管网关生成，SQLite 以真实字节证明 A→B→C→D 的 LRU 淘汰顺序；随后真实 App 又生成并播放第五个产物，证明淘汰活动后产品路径仍可用。

关键事实如下：

- 四次 API 读取均为真实 `cached=false` 产物，大小分别为 `3,176,684`、`3,422,444`、`3,522,284`、`3,361,004` 字节；受控台架预算是 `5,000,000` 字节，生产默认仍为 `50 MiB`。
- 同一数据目录的最终状态只保留 D 的 `speech_cache` 行；A、B、C 的附件均为软删除，D 仍存活，且 D+第五个 App 产物仍未超过受控预算。这与逐步 LRU 淘汰一致，不是伪造大小或只看内存状态。
- 真实 App 的可见朗读入口点击后产生第五个真实音频附件并取得 playback lease；录屏显示 settled answer、朗读入口、播放器状态与可用 composer。
- SSE 记录三条流连接及真实对话完成帧；LLM wire 记录受管握手与九条真实语音响应记录；frontend 无 Flutter/Dart 异常，backend 无 ERROR/panic，`rig-check`/`rig-down` 均通过。

这四格来自已完成、可回放的真实 App 证据包，不是无证据橡皮章。复审不修改告警阈值、算法、CODEX、锚点或顺序 gate，仅销账当前 journal 水位。
