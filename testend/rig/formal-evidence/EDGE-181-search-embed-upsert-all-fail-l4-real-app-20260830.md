# EDGE-181 整批 embed upsert 全失败：L4 真实 App craft

- 结论：`pass`。
- 视觉载体：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-220606/screen.mov` 的 `frames-edge181/normal-001.png` 至 `normal-025.png`。

向量写入故障是后台不可见的基础设施异常，不应把内部错误文本、重复 retry 卡片或半成品 loading 泄漏到用户主路径。Computer Use 逐帧复核录屏稳定段：Chat 空态的侧栏、标题、Composer、输入框和空白留白保持同一布局；没有 clipping、overlap、错位、抖动、重复提示或索引失败专属噪声。

故障发生时用户仍可以使用已有的 lexical search，界面没有把“语义向量暂时不可写”伪装成“整个 App 不可用”。这是该后台降级场景的成品标准；本级不声称后台错误在 UI 中有额外可见提示，也不把日志当作视觉证据。

判定依据：`CODEX C4`。
