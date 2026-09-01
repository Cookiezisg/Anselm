# EDGE-314 编辑器唯一光标：L5 真实 App 可发现性边界

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-203612`
- result: **applicability `na`, not a discovery waiver**
- recording: `screen.mov`, `85.763333s`, 60fps
- frame samples: `/private/tmp/edge314-l5-r2-frames-20260901.pheJgV/f0019.png`, `f0048.png`, `f0060.png`, `f0086.png`

## Ordinary-user path

从 Library 打开现有文档，普通用户目标是修改代码示例和表格中的数据。Computer Use 通过真实
点击/输入完成以下路径：代码块输入 `Y` 后立即原位 `BackSpace`；重新从 AX 树定位表格单元格，
输入 `X` 后立即原位 `BackSpace`；等待保存稳定。

整个路径无需用户知道“唯一光标”“后代焦点”或任何内部实现术语。代码块与表格切换时，AX 焦点
始终只有一个 text field，截图没有第二根 caret、幽灵选区或视口跳变；最终 SQLite 与 UI 均恢复
为基线 `var x = 1;`、`plaincell | 1`。

## Applicability boundary

CODEX 的 G1 要求一个用户能自行找到的产品入口。唯一 caret 是编辑器的正确性/视觉不变量，
不是可单独打开、配置、执行或学习的功能：产品没有一个“打开唯一光标”入口、独立 tooltip、
命令或快捷键。它已在本格 L4 的真实 App craft 取证和本次普通编辑路径中被观察；把同一不变量
再包装成一个虚构的 discoverability pass，会把不可发现的实现细节冒充产品能力并降低门槛。

## Five-channel boundary evidence

- **frames / Computer Use**: 真实 Library 编辑路径、代码与表格焦点切换、两次原位撤回和稳定收尾均有录屏；
  AX 在表格阶段显示唯一 text field。
- **backend**: session backend journal `324` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录 `notifications`、`entities`、`messages` 三路连接，共 `12` 行。
- **frontend**: frontend journal `5` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；Library 编辑不触发 completion，不把空 wire 当成发现性证据。
- **durable truth**: SQLite 文档最终正文为基线内容，未留下临时字符。
- **rig lifecycle**: `rig-check.sh` 五通道通过，`rig-down.sh` 封口 `85.763333s` 录屏并收台所有 owned processes。

## Verdict boundary

L5 记录为合法适用性 `na`，理由是没有独立的用户可发现入口；这不是缺少真实 App 证据的临时
占位，也不替代 L4 的 `pass (C1)`。
