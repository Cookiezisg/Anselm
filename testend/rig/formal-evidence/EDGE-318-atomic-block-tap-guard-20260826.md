# EDGE-318 · 原子块双/三击

## L1 focused evidence

- `frontend/test/core/editor/an_editor_caret_test.dart` 通过：原子块旁 caret 跨整块，表格字段持焦时文档 caret 立即清理。
- `frontend/test/core/editor/an_editor_table_test.dart` 通过：表格单元格交互不会把编辑器推入 NPE/失焦毒态。

## 判定

L1=`A5`：原子块点击由上游 tap guard 接管，不让拖动进入错误的字符级状态机。L2-L5 本批未启动真实 App，记 `na`。
