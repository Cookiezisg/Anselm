# EDGE-323 · 进全屏白带 · 真实 App L2

## 结论

真实 Flutter macOS App 在正式 conductor 会话中点击原生全屏按钮，完成窗口态到原生全屏态，再退出恢复窗口态。录屏覆盖整个过渡；全屏画面铺满屏幕，未观察到 toolbar 残留、白带、外部窗口遮挡、布局溢出或状态卡死。

本轮只新增 L2 五通道裁决。L3-L5 保持 `na`：没有独立动作帧到首反馈帧测量、ROI craft 数字或从零盲走，不把全屏切换成功冒充为完整顺滑、视觉 craft 或可发现性通过。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-023137`
- workspace：`ws_a114ee93b190ceef`
- data：`/private/tmp/anselm-data-edge323-20260828-r1`
- 录屏：`screen.mov`，`51.830000s`；窗口态 `1280×792`，全屏段 `2696×1720`，60fps；五通道由同一 manifest 归属
- 网关：`https://api.anselm.website`；managed challenge/install/models 均经 llmtap 返回 200

## 产品路径

1. 真实 App 启动后位于普通窗口态，设置页内容完整可见；证据 `fullscreen-before.jpg`。
2. 直接点击原生 macOS 全屏按钮，等待过渡结束；证据 `fullscreen-full.jpg` 显示窗口控制条撤下、内容铺满全屏，没有白色过渡带或旧窗口边缘。
3. 使用原生全屏切换快捷键退出；证据 `fullscreen-after.jpg` 显示标题栏、交通灯和普通窗口布局恢复，设置状态没有丢失。

## 五通道证据

- **画面**：`screen.mov` 及 `fullscreen-before.jpg`、`fullscreen-full.jpg`、`fullscreen-after.jpg`，连续覆盖进入与退出全屏。
- **后端**：backend journal 无 `WARN|ERROR|panic|FATAL`；窗口状态变化未产生业务错误。
- **SSE**：notifications/messages/entities 三流均建立连接并在收台时正常 EOF；本场景无业务 durable 帧是预期行为。
- **前端 console**：frontend journal 无 `Unhandled exception`、Dart/Flutter、RenderFlex、RenderBox 或 overflow 红线。
- **LLM wire**：managed challenge/install/models 全部经过 llmtap 且为 200；本场景不调用 chat completion。

## 收台与裁决

`rig-check` 与 `rig-down` 通过，录屏正常 finalize，收台后无 Anselm、Flutter、tap 或 recorder 残留。L2 使用 `G2` 写入；L3-L5 按证据边界保持 `na`。
