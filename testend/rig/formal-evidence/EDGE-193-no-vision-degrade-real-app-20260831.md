# EDGE-193 无视觉能力诚实降级：真实 App 复核

本次验收使用真实 macOS App、Anselm managed gateway、独立 SSE tap、独立 LLM wire tap、后端 journal、Flutter console 和窗口录屏。最终会话证据位于 `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-024530/`。

首轮真实回合发现低参数无视觉模型只说“看不到图片”，没有给下一步；第二轮虽给出下一步，但出现第三人称 `ask the user` 和泛化 assistance 尾巴。修复将完整答案放到用户问题之前，并在附件降级说明中禁止重新上传、臆测和无关客套。第三轮最终画面给出：

> The current model cannot see or inspect the pixels in the attached image. To continue, switch to a vision-capable model or describe or paste the relevant content here.

LLM wire 的 user 内容仅包含 `[UNAVAILABLE IMAGE]` 文字占位和精确附件工具目录；无 `image_url` / `images`。SSE 记录一个用户附件、连续文本 delta 和 completed assistant close。后端无 panic/WARN/ERROR；前端无 Flutter/Dart 未处理错误，仅有已知 macOS 输入法 warning。

本条各层证据：`EDGE-193-L2.md`（F2）、`EDGE-193-L3.md`（A4）、`EDGE-193-L4.md`（C4）、`EDGE-193-L5.md`（G1）。
