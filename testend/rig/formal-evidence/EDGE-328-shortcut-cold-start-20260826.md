# EDGE-328 · 快捷键冷启动

## L1 focused evidence

- `frontend/test/core/shortcuts/global_shortcuts_test.dart` 通过：仅依靠 autofocus、不点击任何控件，默认 ⌘B 即可折叠左岛。
- 同文件通过：所有声明快捷键均抵达对应 handler，包含右岛、设置和缩放三组。

## 判定

L1=`G2`：快捷键入口在冷启动即有效且由目录驱动，产品不要求用户先猜测或点击一个隐形焦点。L2-L5 本批未启动真实 App，记 `na`。
