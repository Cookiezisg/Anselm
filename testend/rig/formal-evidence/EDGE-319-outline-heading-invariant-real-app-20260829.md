# EDGE-319 · 大纲下标不变式真实 App L2

## 场景

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-002006`
- workspace：`ws_fa6a39a9ff1d74b0`
- 文档：`EDGE-319 大纲不变式夹具 2` / `doc_f16562dfd5048abd`
- 夹具同时包含两个真实 h1、h2、h3、h4、h5、h6、后续 h3，围栏内 `#`/`##` 伪标题、引用内 `#` 伪标题和普通正文 `#`。

## 五通道证据

1. **Frame / Computer Use**：真实 Flutter App 显示正文标题、引用、代码块和深层标题；右侧 Outline 显示恰好 8 项，顺序为 `EDGE-319 Outline Matrix`、`H1`、`H2`、`H3`、`H4`、`H5`、`H6`、`H3 after deep levels`。代码围栏中的两个 `#` 和引用中的 `#` 均未进入目录。8 个 Outline 入口逐个点击完成，界面无异常、无重复或卡死。
2. **Backend journal**：同 session 无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
3. **SSE tap**：三条流均连接；文档创建 durable notification 从 `seq=16` 起单调到本批夹具的 `seq=23`，无断流错误。
4. **Frontend console**：无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 红线；仅保留 Dart VM service 启动信息。
5. **LLM wire**：managed gateway challenge/install/models 全部 HTTP `200`；本确定性 Library 路径不需要 completion，不伪造模型调用。

## 判定

- `extractDocOutline(markdown)` 与编辑器 `headingNodeIds` 的共享文档序在真实画面上对齐：8 项标题逐项出现，围栏/引用伪标题被排除，h4-h6 被保留且不使后续 h3 下标漂移。
- 右侧 Outline 计数、标题文本和正文结构与 REST 夹具一致；本格 L2 采用 `F1`。
- L3-L5：`na`。本格证明的是数据/下标真相和入口可用性，不把静态目录路径提升为动效、美学或全新用户发现性结论。

## 文件

- `EDGE-319-initial-outline.jpeg`
- `EDGE-319-after-h6-jump.jpeg`
- `EDGE-319-outline-final.jpeg`
- `frontend/test/features/library/outline_alignment_test.dart`
- `frontend/lib/features/library/model/doc_outline.dart`
- `frontend/lib/core/editor/an_editor.dart`
