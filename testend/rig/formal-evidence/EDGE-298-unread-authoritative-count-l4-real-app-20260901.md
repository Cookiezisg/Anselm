# EDGE-298 · 未读徽标绝不据帧 +1：真实 App L4

## 判定范围

本证据判定未读徽标与通知托盘的视觉 craft，使用 CODEX `C4` 的圆角尺度阶梯和稳定帧目视核对。它只判定
完成态的层级、边界、对齐和视觉重量，不把静态帧扩大成动态时序结论。

## 现场与实现核对

- 稳定关键帧=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051/evidence/EDGE-298-unread-badge.jpeg`。
- 同场正式录屏为 `2784x1808`、`60fps`、`90.176667s`，封存文件由 `ffprobe.log` 验证可读。
- 左岛底部通知按钮是独立 `controlSm` 方格，按钮 hover/active 使用 `AnRadius.button=8`；未读点使用
  `AnSize.dot`，以 `AnSize.ring` 宽度的 `c.surface` 环隔离 `c.danger`，定位于按钮右上角 `s2`。托盘本体
  继续使用 island 级圆角与统一 rail 行几何，不另造第二套 badge chrome。
- 稳定帧中通知按钮、红色未读点、托盘搜索行、Today 组头和通知行的层级可一眼区分；红点没有贴边
  吃进铃铛或漂在按钮外，托盘边界、组头和行之间没有重叠、裁切、非对称空隙或未完成的 loading 状态。
- 未读行采用既定“整行状态 + tone icon”规则，不再叠加行首红点；因此画面没有两个不同红点同时声称
  同一件未读事实，避免与全局铃铛产生视觉歧义。

## 五通道交叉核对

- **Channel 1 / Computer Use + 录屏**：稳定关键帧和录屏尾段显示通知按钮、badge 与托盘均完整落位，
  文字没有越出 rail，面板没有悬空或截断。
- **Channel 2 / backend journal**：同场 create、update、pin 与 mark-read 成功；视觉状态对应权威
  unread count，不是前端自行累加出的装饰。
- **Channel 3 / SSE tap**：Emit 与 Broadcast 的分流事实与 L2/L3 证据一致；画面只呈现一个全局未读
  提示点，没有为 Broadcast 回声再制造第二个视觉标记。
- **Channel 4 / frontend 错误面**：同场 `frontend.log` 与 `rig-check` 没有 Flutter、Dart、RenderFlex、
  Unhandled 或布局溢出红线；静止尾段没有继续重绘或布局抖动。
- **Channel 5 / LLM wire**：本场不调用 LLM；managed challenge/install/models 为 `200`，不将后台
  通知操作冒充模型输出。

## 结论

视觉完成态遵循现有 token：通知按钮为 button 级 8pt 圆角，未读点由 danger 色和 surface 环形成清晰
小型提示，托盘维持 island/rail 的统一层级；稳定帧无重叠、裁切、错位或重复未读标记。因此 L4=`C4`
通过。L5 的入口命名和从零发现路径仍单独判定。
