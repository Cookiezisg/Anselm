# EDGE-316 行内代码 CJK 断盒：L4 真实 App 视觉 craft

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-205403`
- data: `/private/tmp/anselm-data-edge316-l4-20260901.wYHzNo`
- result: **pass (C1)**
- recording: `screen.mov`, `40.410000s`, 60fps
- stable frames: `/private/tmp/edge316-l4-frames-20260901.R4MhXP/f0021.png`,
  `f0035.png`, `f0040.png`

## Product path

从 Library 打开 `EDGE-316 inline code fixture`，阅读一行包含中文行内代码的普通文档；随后打开
`上手指南` 离开，再从 Library 重新打开该文档。路径只使用真实 App 的 Library 文档入口，不依赖
内部渲染函数或调试面板。

## Visual craft judgment

行内代码 `中文注释：计算总数并返回结果` 的灰底连续包住整段 CJK 文本，左右普通文字保持清晰，
没有 script-run 边界的白缝、灰底断裂、背景粘连、文字遮挡或二次宽度抖动。首次打开、离开后的
稳定状态和重新打开后的稳定状态视觉几何一致；右侧 Properties inspector 也保持同一位置和层级。
这满足 CODEX `C1` 的连续高亮/背景几何要求：被包裹的同一视觉行没有断盒，边界只随真实文本内容
结束，不因中文字符切换 script run 而产生不可见空隙。

## Frame measurement

以内容 ROI `900,500,1250,320`、每通道容差 8、阈值 `0.0005` 抽取 1fps 进行 diff。变化只落在
用户打开、离开或重新打开文档的动作窗口：

- `f0020→f0021`: `changedFrac=0.06703`, box=`(900,500)-(2098,580)`，内容首次出现。
- `f0027→f0028`: `changedFrac=0.06398`, box=`(900,500)-(2098,580)`，离开文档。
- `f0028→f0029`: `changedFrac=0.02350`, box=`(900,500)-(1342,725)`，导航过渡。
- `f0033→f0034`: `changedFrac=0.02350`, box=`(900,500)-(1342,725)`，重开过渡。
- `f0034→f0035`: `changedFrac=0.06398`, box=`(900,500)-(2098,580)`，文档内容恢复。

稳定帧没有超过阈值的持续 ROI 变化；动作产生的整块内容切换未被误报成非用户跳变。

## Five-channel and durable evidence

- **frames / Computer Use**: 真实 Library 打开、离开、重开连续录屏；稳定帧确认灰底连续且前后文字可读。
- **backend**: journal `181` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录三路 `notifications`、`entities`、`messages` 连接，共 `10` 行；收台 EOF 为主动断开。
- **frontend**: journal `3` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；本地 Library 阅读不触发 completion，未将空 completion 当成视觉证据。
- **durable truth**: SQLite 文档内容精确为 `普通文本：请检查 \`中文注释：计算总数并返回结果\` 的灰色背景是否连续，前后文字不能被遮挡。`，
  `length(content)=46`，`size_bytes=130`，未发生重开后内容漂移。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口录屏并收台全部 owned processes。

## Verdict

L4 通过 `C1`。本结论同时要求真实 App 的视觉稳定帧、动作窗口测量、durable 原文和五通道健康，
不是由既有 L2/L3 或单元测试推导出的静态通过。
