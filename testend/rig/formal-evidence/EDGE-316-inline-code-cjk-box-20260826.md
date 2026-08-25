# EDGE-316 · 行内代码 CJK 断盒

## L1 focused evidence

- `frontend/test/core/editor/an_editor_selection_test.dart` 通过：selection layout 经过视觉行合并，script run 边界不会制造断裂高亮。
- `frontend/test/core/editor/an_editor_markdown_test.dart` 通过：行内 Markdown/代码结构 round-trip 保持。

## 判定

L1=`C1`：高亮按视觉行连续并盒，CJK 与拉丁 script run 不产生不舒服的断盒。L2-L5 本批未启动真实 App，记 `na`。
