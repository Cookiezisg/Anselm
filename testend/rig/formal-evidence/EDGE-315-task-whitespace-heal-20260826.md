# EDGE-315 · 空 task 尾空格腐化

## L1 focused evidence

- `frontend/test/core/editor/an_editor_markdown_test.dart` 通过：Markdown task 结构往返保持稳定，空 task 的合法形状不会被普通 trim 破坏。
- `frontend/test/features/library/library_test.dart` 通过：编辑器保存与重新打开的内容/结构状态保持一致。

## 判定

L1=`F1`：空 task 的尾空格处理是结构化自愈而非静默丢失用户意图。L2-L5 本批未启动真实 App，记 `na`。
