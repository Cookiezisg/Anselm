# EDGE-322 · 应内缩放到顶

## L1 focused evidence

- `frontend/test/core/platform/window_zoom_test.dart` 通过：步进不会超过屏幕容量传入的 cap，处于上限时保持不变，向下与 reset 均夹在合法 stops 内。
- `frontend/test/core/shortcuts/global_shortcuts_test.dart` 通过：真实快捷键 handler 驱动同一个 `WindowZoom.factor`，⌘−、⌘=、⌘0 均生效；测试使用真实尺寸视口避免小夹具误判。

## 判定

L1=`C4`：缩放行为有明确上限且不突破布局，圆角与层级仍由 token 阶梯控制。L2-L5 本批未启动真实 App，记 `na`。
