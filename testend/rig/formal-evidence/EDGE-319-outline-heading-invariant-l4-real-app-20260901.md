# EDGE-319 大纲下标不变式：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-212449`
- data: `/private/tmp/anselm-data-edge319-l4-20260901.RF8XLW`
- workspace: `ws_fa6a39a9ff1d74b0`
- document: `doc_f16562dfd5048abd` (`EDGE-319 大纲不变式夹具 2`)
- recording: `screen.mov`, `95.250000s`, window `13970`, `1440x810` bounds
- frame set: `/private/tmp/edge319-l4-frames-20260901.me5bj1`
- Computer Use captures: `/private/tmp/edge319-l4-initial.png`, `/private/tmp/edge319-l4-h6.png`, `/private/tmp/edge319-l4-reopen.png`, `/private/tmp/edge319-l4-outline-59.png` through `/private/tmp/edge319-l4-outline-66.png`

## Product path

真实 App 从 Library 打开包含 h1-h6、深层 h3、围栏内伪标题和引用内伪标题的文档。检查右侧 Outline 的结构、缩进、行距和长文本呈现，逐项点击 8 个目录项（包含最深 H6 与深层之后的 H3），观察正文滚动落点，最后离开文档并重新打开。

## Frame and measurement review

- 初始稳定帧显示 Outline 恰好 8 项：真实 h1、h2、h3、h4、h5、h6 和后续 h3；围栏与引用中的 `#` 伪标题没有混入。
- 目录缩进呈现清晰的三档层级：根项/一级项、二级项、三级项；源码规则 `level.clamp(1, 3)` 明确规定 h4-h6 视觉折叠为第 3 层，实拍结果与该规则一致，没有制造不可兑现的七层目录。
- 目录行高度和间距连续，8 项在右岛内完整可读；没有文本截断、重叠、计数闪烁、选中条残留或右岛宽度跳变。点击 8 个项后，正文只在动作窗口内滚动并落定，目录本身不重排。
- 内容 ROI `800,300,1500,1100`、阈值 `0.0005` 的 95 张 1fps 复核只发现初次呈现、目录跳转和重开窗口：`f0014→f0015=0.00620`、`f0015→f0016=0.04758`、`f0031→f0032=0.07463`、`f0084→f0085=0.03486`、`f0085→f0086=0.01011`、`f0086→f0087=0.05268`；稳定段没有持续自发变化。
- H6 跳转后及最终重开帧均保留同一 8 项 Outline 和一致的 0/1/2 档缩进；正文标题、代码围栏和引用视觉没有被跳转破坏。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 逐项点击 8 个目录项、深层跳转、离开/重开均被录屏；代表帧和即时截图已封存。
- **backend**: `backend.log` 共 `348` 行；无 `WARN`、`ERROR`、`panic`、`FATAL` 或应用级红线。
- **SSE**: `sse.jsonl` 共 `8` 行；messages、entities、notifications 三流均连接，收台由 conductor 主动 EOF。
- **frontend console**: `frontend.log` 共 `3` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception。
- **LLM wire**: `llm.jsonl` 共 `1` 行，记录 llmtap ready；本地文档导航不伪造模型 completion。
- **durable truth**: SQLite 文档最终仍为 `339` chars、`429` bytes，围栏、引用和所有标题原文逐字一致。
- **rig lifecycle**: `rig-check.sh`、`rig-down.sh`、D1 归属和 owned process 收台均通过。

## Judgment boundary

- **L4 `pass (C4)`**：Outline 的层级、间距、可读性、跳转反馈和重开稳定态达到产品视觉 craft 标准；深层标题与伪标题边界清楚，不出现布局跳变或残留。
- L5 另行判断普通用户从零是否能发现 Outline 入口和理解其用途；本证据不把已知夹具标签当作盲走发现性证据。
