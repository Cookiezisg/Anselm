# EDGE-317 选区跨块缝隙：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-235053`
- data: `/tmp/anselm-data-edge317-physical-20260828-r7`
- workspace: `ws_89eb5841c48ec008`
- recording: `screen.mov`, `424.336667s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-317-selection-block-gaps-real-app-20260828.md`
- stable frames: `EDGE-317-l3-selection-stable.png`, `EDGE-317-l3-selection-reopened-stable.png`

## Product path and prior red

真实 App 从 Library 打开三段文档，先离开到另一资源，再重开 fixture；随后在真实焦点下用三次 `Shift+Down` 从第一段跨到第三段。此前版本的真实画面已经观察到块间白缝，作为红证据保留；本 session 使用修复后二进制复走同一离开/重开和跨块选区路径。

## Frame review and measurement

对 `screen.mov` 抽取全程 1fps，并用 `threshold=0.0005` 对内容 ROI `900,450,1500,900` 复核。全屏测量没有发现超过阈值的稳定期额外变化；ROI 中的较大变化均绑定用户打开、离开、重开和拖选动作：

- `000112→000113` 的 `changedFrac=0.00429` 是进入文档前后的局部状态收敛。
- `000113→000114` 为 `0.02113`，`000169→000170` 为 `0.06464`，`000198→000199` 为 `0.11085`，`000204→000205` 为 `0.05754`；它们分别对应文档打开、用户跨块拖选、离开到 Chat 和重开/恢复选区，不是静止期自发跳位。
- 稳定选区帧 `000170` 与重开后的 `000424` 都显示三段蓝色选区通过块间 padding 连续桥接，首段/中段保持等高，末段按文字宽度自然收束，浮动工具条稳定在选区下方。
- `regions` 在 `000424` 以目标选区色 `#cde0f8`、通道容差 `24`、最小区域 `16` 检出主连续组件 `x=832,y=530,w=540,h=216,pixels=68884`；该组件覆盖三段选区及块间桥接，没有白色断带将其切成独立的跨块区域。

修复后二进制没有观察到 selection layer 晚一帧重建、桥接层闪回白色、整扇内容二次重排或选区落定后的持续抖动。本判定允许用户主动改变选区造成内容变化，只把非用户触发的既有内容位移判为 B2 问题。

## Five-channel cross-check

- **frames / Computer Use**: 真实点击、焦点建立、`Shift+Down`、离开和重开均在连续录屏中；稳定选区帧已封存，Computer Use 无外部遮挡。
- **backend**: journal `539` 行；文档 GET `200`，最终正文与 fixture 逐字一致，`sizeBytes=124`；无应用级 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16` 为 document.created，单调且无 gap；收台 EOF 是 conductor 主动关闭。
- **frontend console**: `5` 行；无 Flutter/Dart、RenderFlex/RenderBox、overflow、Unhandled 或应用异常；IMK/Caps Lock 为已分类 macOS 宿主诊断。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格为 Library 本地编辑器路径，不伪造 chat completion。
- **rig lifecycle**: startup gate 确认屏幕权限、backend health、ssetap、App 和录屏启动；`rig-check`/`rig-down.sh` 通过并无残留。

## Judgment boundary

- **L3 `pass (B2)`**：修复后的真实 App 在跨块选区首次建立、稳定状态和重开恢复后保持连续几何；历史红点已被修复后二进制消除，用户动作造成的整块 diff 不计作非用户跳变。
- 本证据支持动态稳定性和 C1 几何测量，不把单次稳定截图冒充全场景审美或从零可发现性；L4/L5 仍为 `na`。
