# EDGE-314 编辑器唯一光标：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-201749`
- data: `/private/tmp/anselm-data-edge314-l4-20260901.AxSa04`
- recording: `screen.mov`, `181.328333s`, 60fps
- frame samples: `/private/tmp/edge314-l4-frames-20260901.QFIAtx/f100.png`, `f110.png`, `f120.png`
- measurement: `go run ./testend/cmd/measure/main.go diff -dir /private/tmp/edge314-l4-frames-20260901.QFIAtx -threshold 0.01`; only the initial action window exceeded the threshold (`f023→f024=0.02152`); the later focus changes and the final stable segment had no un-attributed drift at the 1fps sampling rate

## Product path

1. 在真实 App 的 Library 打开含正文、Dart 代码块和表格的文档。
2. 先把输入焦点放入代码块并输入一个可逆的临时字符，确认代码块拥有焦点。
3. 再通过语义 AX 点击把焦点切入表格的 `plaincell` 单元格并输入一个可逆的临时字符，确认焦点已经转移。
4. 删除临时字符并等待保存收敛；文档正文、代码块和表格恢复基线内容。

## Visual craft review

- 表格焦点帧 `f100.png` 中只有 `plaincell` 单元格 caret；代码块没有第二根可见 caret。
- 代码焦点帧 `f110.png` 中只有 `var x =Y 1;` 代码行 caret；表格回到无焦点的静态文本，没有第二根 caret。
- 收尾帧 `f120.png` 回到基线内容，未出现双光标、文档选区残留、焦点高亮幽灵或布局跳变。
- 代码块与表格都保持原有边界、行高和对齐；焦点切换没有改变正文块、右侧属性面板或左侧文档树的几何位置。
- 记录中的一次坐标输入偏移只影响 Computer Use 的插入位置，不是应用同时渲染两个 caret 的证据；临时字符已删除，最终 durable 文档为基线内容。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 中通过代码块与表格两个不同编辑后代形成连续焦点切换；AX 语义点击表格 `plaincell` 后焦点文本字段明确落在表格单元格，关键帧分别显示单一 caret。
- **backend**: session backend journal 共 613 行；无 WARN、ERROR、panic 或 fatal，收台走 graceful shutdown。
- **SSE**: ssetap 记录 `notifications`、`entities`、`messages` 三条流，共 12 行；操作期间无断线、缺口或错误终态。
- **frontend**: frontend journal 共 4 行，仅含启动信息和已知 macOS 宿主诊断；无 Flutter、RenderFlex、Unhandled 或应用级异常。
- **LLM wire**: llmtap journal 共 1 行；本格是 Library 编辑路径，不触发 completion，未把空 completion 当产品证据。
- **durable truth**: 操作结束后文档回到 fixture 基线：正文 `正文段落`、代码 `var x = 1;`、表格 `plaincell | 1`；未留下临时字符或错误状态。
- **rig lifecycle**: 操作前 `rig-check.sh` 五通道全通过；`rig-down.sh` 封口录屏并停止 App、backend、ssetap、llmtap，owned processes 已收尸。

## Verdict

- **L4 `pass (C1)`**: 编辑器在代码块字段与表格字段之间切换时始终只有一个可见主光标；选区状态在后代获得焦点后被清理，焦点切换没有双光标、幽灵选区或稳定段布局跳变。
