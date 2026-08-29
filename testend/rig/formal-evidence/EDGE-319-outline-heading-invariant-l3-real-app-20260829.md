# EDGE-319 · 大纲下标不变式：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`
- data: `/private/tmp/anselm-data-edge319-physical-20260829-r1`
- workspace: `ws_fa6a39a9ff1d74b0`
- document: `doc_f16562dfd5048abd` (`EDGE-319 大纲不变式夹具 2`)
- recording: `screen.mov`, `165.106667s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-319-outline-heading-invariant-real-app-20260829.md`
- stable frames: `EDGE-319-l3-initial-outline-stable.png`, `EDGE-319-l3-after-outline-jump-stable.png`, `EDGE-319-l3-final-outline-stable.png`

## Product path

在真实 Flutter App 中打开包含 h1-h6、多层级后续 h3、围栏内伪标题和引用内伪标题的文档。先让文档和 Outline 完整落定，再依次点击右侧 8 个 Outline 入口，观察正文滚动、标题定位和目录本身，最后停留在最终稳定态。

## Frame review and measurement

对 `screen.mov` 抽取全程 `1fps`，用 `threshold=0.0005` 对内容 ROI `800,300,1500,1100` 复核。代表性变化为：

- `000071→000072=0.0654` 是文档首次呈现；
- `000085→000086=0.08596`、`000086→000087=0.01055` 是用户点击 Outline 后的预期滚动和收敛，不是静止态自发跳变；
- `000087` 以及最终 `000165` 均显示同一套 8 项 Outline，标题顺序和正文层级稳定，没有目录计数闪烁、重复重建或标题定位错位。

稳定帧显示：h1-h6 均可被目录承接，深层标题之后的 h3 仍在正确位置；围栏和引用中的 `#` 伪标题不进入目录。点击入口后正文只发生与导航相称的滚动，落定后没有晚到的二次滚动、视口抖动或选中标题漂移。

本格 L3 判断导航状态的动态收敛和稳定性。L2 已证明结构与下标真相；本证据不把已完成的动态结论扩大成 L4 美学或 L5 从零发现性结论。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 录屏覆盖打开文档、逐个点击 8 个 Outline 入口和最终稳定态；三张稳定帧已封存。
- **backend**: journal `264` 行；无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: messages/entities/notifications 三流均连接；notifications durable `seq=16..23` 单调，无缺口；收台为 conductor 主动关闭后的 EOF。
- **frontend console**: `3` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 红线。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是本地文档导航路径，不伪造 completion 调用。
- **rig lifecycle**: startup gate、`rig-check` 和 `rig-down.sh` 收台通过，App、backend、ssetap、llmtap、录屏归属一致，无残留。

## Judgment boundary

- **L3 `pass (B2)`**：Outline 点击后的滚动和标题定位收敛，8 项目录不闪烁、不重复、不漂移，用户动作之外没有持续视口变化。
- L4/L5：`na`。本证据不宣称目录视觉精修完成，也不宣称首次用户无需引导即可发现入口。
