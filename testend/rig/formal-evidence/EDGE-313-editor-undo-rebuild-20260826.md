# EDGE-313 · 编辑器 undo 全量重建

## L1 focused evidence

- `frontend/test/core/editor/an_editor_markdown_test.dart` 通过：Markdown 文档在编辑/序列化往返中保持结构，增量变化不吞内容。
- `frontend/test/features/library/library_test.dart` 通过：编辑器 source 变化替换内容但不 remount 页面壳，保存/autosave 仍收口。

## 判定

L1=`F1`：无法从增量事件可靠推导的重置路径保持全量重建语义，不把 undo 差异当成可丢失事件。L2-L5 本批未启动真实 App，记 `na`。
