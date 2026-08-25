# EDGE-317 · 选区跨块缝隙

## L1 focused evidence

- `frontend/test/core/editor/an_editor_selection_test.dart` 通过：跨 block selection 按视觉行合并，块间 padding 由 overlay gap layer 补齐。
- `frontend/test/core/editor/an_editor_caret_test.dart` 通过：caret/selection geometry 使用同一测量基准，不引入额外跳变。

## 判定

L1=`C1`：跨块蓝色选区连续、等高规则有可执行 geometry 守卫。L2-L5 本批未启动真实 App，记 `na`。
