# EDGE-318 原子块双/三击：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-211151`
- data: `/private/tmp/anselm-data-edge318-l4-20260901.Ecr7nv`
- workspace: `ws_7dab956978704245`
- recording: `screen.mov`, `154.140000s`, window `13948`, `1440x810` bounds
- frame set: `/private/tmp/edge318-l4-frames-20260901.BLUB0N`
- Computer Use captures: `/private/tmp/edge318-l4-code-triple-stable.png`, `/private/tmp/edge318-l4-code-drag-stable.png`, `/private/tmp/edge318-l4-table-drag-stable.png`, `/private/tmp/edge318-l4-divider-drag-stable.png`, `/private/tmp/edge318-l4-reopen.png`

## Product path

真实 App 从 Library 打开原子块夹具。对 Dart 代码块、表格和水平分隔线分别执行双击、三击和拖动；代码块继续使用其嵌入编辑器的文本选择，表格继续使用单元格编辑，分隔线不产生虚假的文字选择。随后点击离开文档，再返回原夹具，确认选择态和编辑焦点干净收口。

## Frame and measurement review

- 代表性稳定帧：`f0013.png` 为夹具打开后的完整基线，`f0043.png` 为代码行选择稳定态，`f0087.png` 为表格操作后的稳定态，`f0154.png` 为重开后的最终稳定态。
- 对录屏抽取的 154 张 1fps 帧，以内容 ROI `800,400,2400,1500`、像素阈值 `0.0005` 复核。可见变化仅为打开 `f0012→f0013=0.03566`、离开/导航 `f0138→f0139=0.02768`、过渡 `f0139→f0140=0.00700`、重开 `f0140→f0141=0.03278`；其余局部变化为动作窗口内的选择/焦点反馈，稳定段没有持续漂移。
- 代码块三击/拖动的蓝色反馈只覆盖被选代码字形所在视觉行，不改变代码块外框、行号槽、语言标记或上下文正文的几何；没有半行高亮、白缝、溢出或遮挡。
- 表格双/三击与拖动后，单元格焦点仍在单元格内部，表格边框、列宽、行高和下方分隔线保持一致；没有把表格拉伸成外层文档选区。
- 分隔线双/三击与拖动后仍是单一水平 hairline，上下正文保持原位；没有错误的选区矩形、残留 overlay 或相邻正文吞字。
- 重开最终帧恢复完整夹具；右侧属性岛与中心正文边界稳定，且没有因手势留下第二根 caret 或滚动位置跳变。

本次判断的产品标准不是“没有崩溃”而是三类块各自反馈清楚、反馈边界连续、手势后布局不变，并且从操作态回到阅读态时不留下视觉残骸。现有设计中代码块和表格是嵌入式编辑器，故不强行要求不符合其语义的整块蓝色高亮；分隔线则以无文字选择和邻接内容不受损为正确视觉结果。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 双击、三击、拖动、离开、重开均在 `screen.mov` 中；稳定帧与即时 Computer Use 截图已封存。
- **backend**: `backend.log` 共 `527` 行；`rig-check` 通过 D1 归属和健康检查，无 `panic`、`FATAL` 或应用级红线。
- **SSE**: `sse.jsonl` 共 `8` 行；messages、entities、notifications 三流均连接并由 conductor 主动 EOF 收台。
- **frontend console**: `frontend.log` 共 `4` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception；仅有已分类 macOS IMK 宿主诊断。
- **LLM wire**: `llm.jsonl` 共 `1` 行，记录 llmtap ready；本地编辑器场景不伪造 chat completion。
- **durable truth**: SQLite 文档 `doc_b202c03c26a70ca4` 最终仍为 `186` chars、`312` bytes，内容与夹具原文逐字一致，探针未污染持久化数据。
- **rig lifecycle**: `rig-check.sh` 与 `rig-down.sh` 通过；backend、ssetap、llmtap、App、录屏均为本次 conductor 所有，录屏已正常停止且无残留进程。

## Judgment boundary

- **L4 `pass (C4)`**：代码块、表格、分隔线在双/三击与拖动后的视觉反馈符合各自编辑语义，几何连续、无布局跳变或残留；离开/重开后回到干净稳定态。
- L5 另行判断是否存在一个普通用户可发现的“原子块双/三击”独立入口；本证据不把内部手势实现冒充为可发现能力。
