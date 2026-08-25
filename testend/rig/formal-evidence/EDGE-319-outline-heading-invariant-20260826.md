# EDGE-319 · 大纲下标不变式

## L1 focused evidence

- `frontend/test/features/library/outline_alignment_test.dart` 通过：围栏/引用/六级 heading 的刁钻 Markdown 下，`extractDocOutline` 与 `headingNodeIds` 数量和顺序完全一致。
- `frontend/test/features/library/library_test.dart:outline jump keeps the target heading below the fixed shell band` 通过：大纲跳转目标与 shell 几何保持一致。

## 判定

L1=`F1`：大纲索引与编辑器 heading identity 使用同一标题判定，不发生整表错位。L2-L5 本批未启动真实 App，记 `na`。
