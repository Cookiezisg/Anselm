# EDGE-196 受管 remote media lease：真实 App 收口

本次正式 session 为 `/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-033112/`。台架真实启动 Anselm macOS App，接入 Anselm managed gateway，同时记录窗口录屏、后端 journal、三路 SSE、Flutter console 与 LLM wire。通过原生 macOS 文件选择器选入真实 PNG 图片，并发送自然语言请求，助手返回 `RECEIVED`。

LLM wire 清楚显示受管媒体的 resumable 链路：创建 upload、分片 `PUT`、complete；随后 chat user content 仅包含一个 `/v1/media/leases/.../content?token=...` 相对路径。请求中没有绝对 URL、`data:image`、base64 或图片字节。backend、SSE、frontend 和最终窗口录屏均与该回合一致。

最终帧中图片缩略图、用户消息、助手结果和 Composer 均完整可见，无溢出、遮挡或内部 lease 信息泄漏。四级独立证据：`EDGE-196-L2.md`（F2）、`EDGE-196-L3.md`（A4）、`EDGE-196-L4.md`（C4）、`EDGE-196-L5.md`（G1）。

已知边界：本次证明的是受管上传到模型 wire 的相对 lease 交付与产品可见闭环；未将远端 lease 内容下载另行计为独立行为，也没有降低五级标准。
