# EDGE-317 选区跨块缝隙：L5 真实 App 可发现性边界

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-210113`
- result: **applicability `na`, not a discovery waiver**
- recording: `screen.mov`, `72.976667s`, 60fps
- stable selection frame: `/private/tmp/edge317-l4-frames-20260901.sZthLs/f0042.png`
- stable reopened frame: `/private/tmp/edge317-l4-frames-20260901.sZthLs/f0066.png`

## Ordinary-user path

从 Library 打开包含三段正文的文档，用户在第一段建立焦点并连续按三次 `Shift+Down`，自然地
选择跨越三段和块间留白的连续内容；随后离开并重新打开文档。真实 App 中选区格式条在选区下方
出现，重开后正文和文档入口仍可正常使用。

## Applicability boundary

G1 要求用户能够自行找到某项独立产品能力的入口。`选区跨块缝隙` 不是独立能力，而是普通文本
选择跨越多个排版块时必须成立的渲染正确性不变量；产品没有“开启跨块选择”、专门设置、命令、
tooltip、快捷键或独立页面。用户可发现的是普通文本选择和格式条，这些表面已由真实 L4 视觉
craft 验收；把内部 selection overlay 的桥接实现包装成 G1 pass 会降低标准。因此 L5 记为明确
适用性 `na`，不是缺少现场证据的临时占位。

## Five-channel boundary evidence

- **frames / Computer Use**: 真实 App Library、焦点建立、三次 `Shift+Down`、稳定跨块选区、离开和重开
  均在连续录屏中；选区蓝色桥接连续且无白缝。
- **backend**: session journal `283` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录三路连接，共 `8` 行；收台断开为 conductor 主动操作。
- **frontend**: journal `5` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；本地 Library 选择不触发 completion，不把空 wire 当作发现性证据。
- **durable truth**: SQLite 文档仍为三段原文，`length(content)=46`、`size_bytes=124`，选择没有修改内容。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口并收台全部 owned processes。

## Verdict boundary

L5 记录为合法适用性 `na (G1)`，不替代 L4 的 `pass (C1)`。若未来增加独立的选择工具或入口，
该新增产品表面出现时必须重新评估本项 L5。
