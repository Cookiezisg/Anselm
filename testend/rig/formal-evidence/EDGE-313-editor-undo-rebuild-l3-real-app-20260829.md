# EDGE-313 编辑器 undo 全量重建：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`
- data: `/private/tmp/anselm-data-edge313-physical-20260828-r3`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_edge313_undo`
- recording: `screen.mov`, `75.101667s`, 60fps
- stable frames: `evidence/EDGE-313-l3-post-undo-stable.png`, `evidence/EDGE-313-l3-late-stable.png`
- L2 foundation: `testend/rig/formal-evidence/EDGE-313-undo-real-app-20260828.md`

## Product path

1. 在真实 App 的 Library 打开带有正文的文档；正文初始为 `Original paragraph for undo.`。
2. 用户粘贴 `EDITED`，确认正文变为 `Original paragraph for undo.EDITED`，右侧元数据随之变为 `31 chars`、`34 B`。
3. 用户物理按下 macOS `Command+Z`；编辑器回到原正文，右侧恢复为 `25 chars`、`28 B`，随后保持稳定。

## Frame review and measurement

对同一份 60fps 录屏抽取 1fps 样本，并对撤销附近再抽取 10fps 局部样本；`measure diff` 使用通道容差 8、阈值 `0.0005`。

- 输入前后的稳定态清晰可读；编辑态只出现一次，撤销后只保留原正文，没有重复段落、空白替身或错误的元数据。
- 1fps 变化集中在用户编辑和撤销动作窗口：`000024→000025=0.06483`、`000027→000028=0.06502`、`000030→000031=0.63155`、`000031→000032=0.63164`；`000039` 之后直到录屏结束无超过阈值的变化。
- 10fps 局部样本在两次动作窗口分别出现 `0.06202/0.26829/0.33504` 与 `0.13348/0.33061/0.19777` 的连续过渡，之后回到稳定全尺寸窗口；这些变化与粘贴、撤销的用户操作窗口重合。
- 录屏另出现两次约 `0.8s` 的 macOS 窗口整体缩放：窗口从 `2560×1584` 缩至约 `1216×752` 后恢复，中心对称、内容不丢失。前端源码没有对应的主动 resize/fullscreen 路径，frontend journal 也没有应用 resize/error；该现象按宿主/手动操作观测边界记录，不冒充 App 的产品动画，也不把它计为编辑器内容跳变。
- 撤销完成后固定帧持续显示原正文；没有非用户触发的二次归账、回跳或重排。

## Five-channel cross-check

- **frames / Computer Use**: 真实用户粘贴和物理 `Command+Z` 的编辑态、撤销态及后续稳定态均可读；窗口缩放已单独标注为宿主边界。
- **backend**: backend journal 共 `168` 行；无 `WARN`、`ERROR`、`panic` 或 `FATAL` 应用红线。
- **SSE**: ssetap 连接 `messages`、`entities`、`notifications` 三条流；notifications durable seq `16,17,18` 单调，覆盖对应的 `document.updated`。
- **frontend**: frontend journal 共 `4` 行；无 Flutter、Dart、RenderFlex、RenderBox、Unhandled 或应用级异常，唯一系统文本为已分类的 macOS IMK 诊断。
- **LLM wire**: llmtap challenge/install/models 请求均为 `200`；本格不触发模型 completion，不虚构 LLM 证据。
- **durable truth**: REST/SQLite 和右侧元数据对齐，正文字节由基线 `256` → 编辑后 `262` → 撤销后 `256`；最终只保留原正文。
- **rig lifecycle**: 录屏可读，App、backend、ssetap、llmtap 正常收台，无残留进程。

## Judgment

- **L3 `pass (B2)`**：用户编辑和撤销动作均有连续可观察的收尾；撤销后正文和元数据稳定，没有非用户触发的内容跳变、重复或回跳。
- 本证据只覆盖 undo 全量重建的动态稳定性；不把编辑器视觉 craft 或快捷键可发现性冒充 L4/L5。
