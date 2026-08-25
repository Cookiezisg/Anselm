# EDGE-314 · 编辑器唯一光标铁律

## L1 focused evidence

- `frontend/test/core/editor/an_editor_caret_test.dart` 通过：点击表格单元格时文档 caret 被清除，只保留一个嵌入字段 caret。
- `frontend/test/core/editor/an_editor_table_test.dart` 通过：表格单元格输入落入 serialized Markdown，焦点与 ReplaceNode seam 一致。

## 判定

L1=`A5`：后代字段持焦时不会与文档选区双重闪烁。L2-L5 本批未启动真实 App，记 `na`。
