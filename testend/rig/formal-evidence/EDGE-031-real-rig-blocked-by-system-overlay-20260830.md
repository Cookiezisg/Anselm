# EDGE-031 · 回合收尾期单槽缓冲 · 真实台架被系统遮挡阻断

## Autonomous verification

后端 `TestSendDuringCompactionUsesSingleBuffer` 普通与 race 模式均通过：慢速压缩期间
恰好接受一个 follow-up，压缩未结束前不启动，释放后按序启动；前端
`chat_composer_test.dart` 与 `chat_queue_test.dart` 相关套件通过，包含生成中 Enter
入队、队列 chip、停止不丢队列和 FIFO 顺序。

## Formal disposition

新的真实台架 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-022738`
已由 conductor 启动后收台，五通道进程归属、backend health、SSE、LLM tap、App PID 和
窗口录像均已建立；但 `rig-check` 发现 `SecurityAgent` 与 `CoreServicesUIAgent` 覆盖
Anselm 录屏区域并 fail-closed。该 session 的 `screen.mov` 仅 `17.463333s`，不能作为
正式 L2/L3 证据，未写 pass。

本条已加入人工队列；清除系统授权遮挡后必须重新录制并完成五通道、逐帧和产品判断。
标准、阈值、CODEX、锚点集和顺序 gate 未降低或修改。
