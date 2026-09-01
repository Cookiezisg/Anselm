# EDGE-316 行内代码 CJK 断盒：L5 真实 App 可发现性边界

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-205403`
- result: **applicability `na`, not a discovery waiver**
- recording: `screen.mov`, `40.410000s`, 60fps
- final frame: `/private/tmp/edge316-l4-frames-20260901.R4MhXP/f0040.png`

## Ordinary-user path

从 Library 找到并打开包含中文行内代码的文档，阅读其正文，再离开文档并重新打开。真实 App 的
Library、文档标题、正文和灰底代码均可直接理解；重开后同一内容仍在，用户无需知道 script run、
`getBoxesForSelection` 或内部渲染实现。

## Applicability boundary

G1 要求某项用户能力有能被新用户自行找到的入口。`行内代码 CJK 断盒` 是排版正确性不变量：
产品没有“修复灰底连续性”、专门开关、命令、tooltip、快捷键或独立设置。用户可发现和使用的是
文档阅读/编辑及行内代码本身，这些表面已在本格 L4 的真实视觉 craft 中验收；把内部绘制不变量
包装为 discoverability pass 会降低标准。因此 L5 是明确适用性 `na`，不是未完成的测试占位。

## Five-channel boundary evidence

- **frames / Computer Use**: 真实 App 从 Library 打开文档、离开、重开，最终帧显示 CJK 灰底连续且前后
  文本清晰；无独立“修复”入口需要发现。
- **backend**: session journal `181` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录三路连接，共 `10` 行；收台 EOF 是 conductor 主动断开。
- **frontend**: journal `3` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；本地 Library 阅读不触发 completion，不把空 wire 当作发现性证据。
- **durable truth**: SQLite 正文保持 fixture 的 46 字、130 bytes 原文，重开后无漂移。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口并收台全部 owned processes。

## Verdict boundary

L5 记录为合法适用性 `na (G1)`，不替代 L4 的 `pass (C1)`。如果未来增加显式排版修复或显示设置，
该新入口出现时必须重新评估本项 L5。
