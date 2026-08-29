# EDGE-314 编辑器唯一光标铁律：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`
- data: `/private/tmp/anselm-data-edge314-physical-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- recording: `screen.mov`, `222.475000s`, 60fps
- stable frames: `evidence/EDGE-314-l3-post-undo-stable.png`, `evidence/EDGE-314-l3-code-and-table-stable.png`, `evidence/EDGE-314-l3-restored-stable.png`
- L2 foundation: `testend/rig/formal-evidence/EDGE-314-editor-single-caret-real-app-20260828.md`

## Product path

1. 在真实 App 的 Library 打开含正文、Dart 代码块和两列表格的 fixture，先在正文建立 caret。
2. 用户点击代码块并输入 `Y`，再点击表格单元格并输入 `X`；两个嵌入字段分别接收输入。
3. 用 fixture 恢复原始 Markdown，离开并重新打开文档，确认编辑器回到稳定的原始结构。

## Frame review and measurement

对 60fps 录屏抽取全程 1fps 样本，并对正文/代码块/表格内容区使用 ROI `820,430,1250,950` 复测；通道容差为 8、阈值 `0.0005`。

- 全屏测量只出现两次低面积变化：`000014→000015=0.00080`、`000020→000021=0.00080`，均发生在页面进入/编辑准备阶段，未形成持续重排。
- 内容区 ROI 仅出现 `000103→000104=0.02827`、`000201→000202=0.02848`、`000206→000207=0.02825` 三次动作关联变化；每次之后均回到稳定画面。
- 代码字段稳定帧显示 `var x = 1;` 与代码字段自身的 caret/输入；表格稳定帧显示 `plaincellX` 与表格字段自身的 caret。没有正文 caret 和嵌入字段 caret 同时出现。
- 恢复后的稳定帧显示完整正文、代码块和表格，连续约 20 秒无超过阈值的变化；没有输入后第二根 caret、焦点回弹、布局跳位或闪烁。

## Five-channel cross-check

- **frames / Computer Use**: 正文、代码字段、表格字段和恢复重载四种状态均由真实坐标操作和 AX/录屏确认；固定帧已封存。
- **backend**: backend journal 共 `168` 行；无 `WARN`、`ERROR`、`panic` 或 `FATAL` 应用红线。
- **SSE**: ssetap 连接三条 workspace 流；notifications durable seq `16,17,18,19` 单调，无 gap。
- **frontend**: frontend journal 共 `4` 行；无 Flutter、Dart、RenderFlex、RenderBox、Unhandled 或应用级异常，唯一系统文本为已分类的 macOS IMK 诊断。
- **LLM wire**: llmtap challenge/install/models 均为 `200`；本格不触发模型 completion，不虚构 LLM 证据。
- **durable truth**: 真实 App 输入后的内容由 fixture 恢复；REST/SQLite 最终回到 `86 B` 原始 Markdown，未留下验收污染。
- **rig lifecycle**: 录屏可读，App、backend、ssetap、llmtap 正常收台，无残留进程。

## Judgment

- **L3 `pass (B2)`**：焦点从正文切入嵌入代码字段或表格字段时，画面稳定、输入只落在当前字段，恢复后无非用户触发的 caret 或布局跳变。
- 本证据只覆盖唯一光标行为的动态稳定性；不把 caret 的视觉 craft 或从零盲走可发现性冒充 L4/L5。
