# EDGE-319 大纲下标不变式：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-212449`
- data: `/private/tmp/anselm-data-edge319-l4-20260901.RF8XLW`
- workspace: `ws_fa6a39a9ff1d74b0`
- starting condition: Library 已打开但未依赖内部实现说明；打开文档后从可见 UI 判断下一步。

## Blind product path

普通用户目标是“查看这篇文档的结构，并跳到最深的标题”。打开文档后，右侧检查器直接出现命名清楚的 `Outline` 和数量 `8`，下面列出标题；不需要知道 `extractDocOutline`、node id、下标或任何内部术语。目录项具备普通可点击行的视觉 affordance，点击 H6 和其它标题后正文滚动到对应内容，回到文档时目录仍然存在且可继续使用。

围栏内 `#`、引用内 `#` 和普通正文里的 `#` 没有进入目录，因此用户看到的目录不是“把所有井号都当标题”的噪声列表。h4-h6 在产品约定的三级目录中保持可读缩进，深层标题名称完整显示；这让用户可以理解目录结构，而无需额外解释折叠规则。

## Five-channel cross-check

- **frames / Computer Use**: 初始文档帧、逐项点击帧、H6 跳转帧和离开/重开帧均在正式录屏；AX 树直接暴露 `Outline 8` 与 8 个标题按钮。
- **backend**: 同一 session 的 backend journal 无应用级错误。
- **SSE**: 三路 SSE witness 已连接并在 conductor 收台时正常 EOF。
- **frontend console**: 无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception。
- **LLM wire**: 本路径无模型调用，llmtap ready 已记录，不伪造 completion。
- **durable truth**: 文档原文包含 8 个真实标题及明确的围栏/引用伪标题边界，重开后保持 `339` chars、`429` bytes。

## Judgment boundary

- **L5 `pass (G1)`**：用户无需阅读内部文档，能从命名明确、位置稳定的 `Outline 8` 入口理解用途并完成从打开文档到深层标题跳转的目标。
