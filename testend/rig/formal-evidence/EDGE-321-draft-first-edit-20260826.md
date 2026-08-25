# EDGE-321 · 草稿文档首次编辑

## L1 focused evidence

- `frontend/test/features/library/library_test.dart` 通过：无选区进入 Library 时显示未创建 draft；未改标题、正文、简介、标签并离开不会创建文档。
- 同文件通过：首次正文编辑 POST 创建后采用新 id，编辑器保持同一 State，不因 URL 转正而 remount，内容与光标状态保留。

## 判定

L1=`G1`：新用户从 Library 空选区可以直接进入可编辑草稿，首次真实编辑自然转正；空草稿不会制造幽灵文档。L2-L5 本批未启动真实 App，记 `na`。
