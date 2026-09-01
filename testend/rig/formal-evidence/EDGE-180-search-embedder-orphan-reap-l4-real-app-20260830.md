# EDGE-180 embedder 孤儿回收：L4 真实 App craft

- 结论：`pass`。
- 错误态画面：第一段 `screen.mov` 的 `frames-edge180/crash-013.png`。
- 恢复态画面：第二段 `screen.mov` 的 `frames-edge180/recovered-017.png`。

Computer Use 逐帧复核错误门：危险图标、标题、解释、`Retry` 垂直居中，信息层级清楚，按钮是唯一明确动作；没有裁切、重叠、错位或后端崩溃后残留的 loading。恢复段回到正常三岛 Chat，侧栏、Composer、标题层级和留白稳定，没有重复的错误卡片或孤儿 embedder 状态污染主界面。

在各自 1fps 稳定抽帧目录中，第一段保留 `13` 张错误态帧，第二段保留 `17` 张恢复态帧。L4 只对稳定成品做 craft 判断，不声称像素完全相等，也不把 backend 日志当作视觉证据。

判定依据：`CODEX C4`。
