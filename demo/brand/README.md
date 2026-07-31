# Anselm — 品牌图标（app icon）

本目录保存 Web demo onboarding 使用的品牌图标副本。当前 Flutter 资产位于
[`frontend/assets/brand/anselm-icon.svg`](../../frontend/assets/brand/anselm-icon.svg)，
两份文件应保持逐字节一致；原生打包图标由各平台宿主目录持有。

图形是**像素 F**：6 个方块（上排 3 · 中排 2 · 底 1）拼成字母 F。

- **黑白**：纯白底 `#ffffff` 圆角方（squircle，`rx 114`）+ 近黑 `#141414` 方块。无渐变、无第二色、无文字。
- **几何**：方块 88px、间距 18px；黑块包围盒 300×300，四周白边各 106px，**正中对齐**。
- **文件**：[`anselm-icon.svg`](anselm-icon.svg)（512×512 Web demo 副本）。

修改品牌图形时必须同步 Flutter SVG、demo 副本和三平台打包图标，并做可见验收。
