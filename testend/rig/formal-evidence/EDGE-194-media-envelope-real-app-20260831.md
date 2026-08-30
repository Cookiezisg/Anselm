# EDGE-194 单回合媒体额度耗尽：真实 App 收口

本次正式 session 为 `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-031039/`，由台架真实启动 Anselm macOS App，连接 Anselm managed gateway，并同时记录窗口录屏、后端 journal、三路 SSE、Flutter console 与 LLM wire。

场景刻意附加 8 个编号文件和第 9 个不同命名的 `edge194-final-item.png`。第一次旧实现的相邻红场曾把第 9 个文件错误回答成按序号推导的名字；本次修复在 `prompt.go` 增加权威文件名规则，并让 `attachment.go` 的额度注记明确声明原始位置和不可臆造。真实 App 最终只回答：

> edge194-final-item.png

原始 wire `llm-bodies/00007_v1_chat_completions.bin` 显示 8 个 `image_url`，并在第 9 个原始位置保留精确文字注记；SSE 显示 9 个附件 touchpoint、assistant reasoning/text 两个 block 以及 completed close；末帧 `/private/tmp/edge194-fixed-final.png` 与 durable text 同名。后端无应用级错误，前端无 Flutter/Dart 异常，`rig-down` 正常收台并清零进程。

四级独立证据：`EDGE-194-L2.md`（F2）、`EDGE-194-L3.md`（A4）、`EDGE-194-L4.md`（C4）、`EDGE-194-L5.md`（G1）。
