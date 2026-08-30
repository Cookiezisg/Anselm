# EDGE-195 不可交付格式（HEIC/AVIF）：真实 App 收口

本次正式 session 为 `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-032349/`。台架真实启动 Anselm macOS App，接入 Anselm managed gateway，同时记录窗口录屏、后端 journal、三路 SSE、Flutter console 与 LLM wire。使用 `sips` 生成的真实 HEIF/HEVC 文件 `edge195-iphone-photo-20260831.HEIC` 通过原生 macOS 文件选择器进入产品。

真实 App 先显示 `Media prep failed` 与 `Retry media preparation`，发送后没有中断：助手明确说明无法检查 HEIC 像素，解释 `image/heic` 无法预处理，并建议转换成 JPEG、PNG 或 WebP，另给出 iPhone“兼容性最佳”设置。LLM wire 的 user content 为格式占位，`image_url` 数量为 0，未发送 HEIC 字节；SSE 记录完整 completed 回合。后端唯一 warning 是预期的 derivative decoder `unknown format`，没有异常级错误或崩溃；前端只有已知 macOS 输入法宿主 warning。

四级独立证据：`EDGE-195-L2.md`（F2）、`EDGE-195-L3.md`（A4）、`EDGE-195-L4.md`（C4）、`EDGE-195-L5.md`（G1）。
