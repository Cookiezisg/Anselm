# EDGE-314 · 编辑器唯一光标铁律真实 App L2

## 台架

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225931`
- data: `/private/tmp/anselm-data-edge314-physical-20260828-r1`
- App: conductor-owned macOS App PID 6366, window 5642, recorded bounds `80,40,1280,792`
- recording: `222.475000s`, finalized by `rig-down.sh`
- frontend build: `mise exec -- flutter build macos --debug -t lib/main.dart`
- fixture: `EDGE-314 editor fixture`, seeded through the local acceptance API with a paragraph, a Dart code block, and a two-column table

## 用户可见动作与结果

1. 打开真实文档后点击正文“正文段落”，建立文档侧的 caret。
2. 用真实坐标点击代码块内容并输入 `Y`。AX 树把代码块暴露为 focused text field；录屏帧显示代码字段 caret，正文侧没有第二根 caret。
3. 用真实坐标点击表格 `plaincell` 并输入 `X`。AX 树显示 `plaincellX`，证明表格单元格确实获得键盘焦点；录屏帧显示单元格 caret，正文和代码块没有残留文档 caret。
4. 用 HTTP fixture 操作恢复原始 Markdown，再离开并重新打开文档；真实 App 重新显示 `var x = 1;` 和 `plaincell`，持久化内容没有被验收输入污染。

结论：嵌入代码字段和表格单元格获得键盘时，文档选区/caret 被清除；每个嵌入编辑器只保留自身的一根 caret。代码字段与表格字段两条产品路径均在真实 App 中走通。

## 五通道证据

- **Frame / Computer Use**: `get_app_state` 在每个动作后重新取 AX 树；录屏覆盖正文聚焦、代码字段聚焦、表格字段聚焦、恢复重载全过程。画面没有双 caret、布局溢出或遮挡。
- **Backend**: 文档创建 `201`；输入产生更新 `200`；恢复产生更新 `200`；HTTP 日志无应用 WARN/ERROR/panic/fatal。最后一次持久化大小回到 `86 B`。
- **SSE**: `sse.jsonl` 三条 workspace 流均连接；notifications durable 序列 `16,17,18,19` 单调，无 gap，分别对应 document.created 与 document.updated。
- **Frontend console**: 没有 `flutter error`、Dart exception、`RenderFlex`、overflow、null-check 或未处理错误。唯一文本是 macOS `IMKCFRunLoopWakeUpReliable` 宿主提示，已在既有台架规则中分类，不属于 App 运行时红线。
- **LLM wire**: llmtap 记录受管网关 challenge/install/models 均为 `200`；本格不需要发送模型请求，未伪造 chat 成功。
- **Rig**: 收台前 `rig-check.sh` 五通道通过；`rig-down.sh` 正常停止所有归属进程并完成录屏。

## 判定

- CODEX: `F1`（五通道事实一致性）
- Level 1: 已有 `A5` 静态/组件证据
- Level 2: 本证据支持真实 App 通过，允许写入 `judge.py`
- Level 3-5: 未测首反馈时间、ROI craft/像素阈值和从零盲走，保持 `na`

## 复现验证

- `mise exec -- flutter test test/core/error/error_boundary_test.dart test/core/editor/an_editor_caret_test.dart test/core/editor/an_presenter_differential_test.dart test/features/library/library_test.dart` -> `126 tests passed`
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 ./testend/rig/rig-check.sh` -> five channels passed
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/gen_coverage.py --check` -> `848/848/0`
