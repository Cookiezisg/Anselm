# EDGE-328 · 快捷键冷启动 · 真实 App L2

## 结论

真实 Flutter macOS App 冷启动完成后，没有点击任何控件，直接发送 `⌘B`，左岛实际折叠；再次发送 `⌘B` 后恢复。AX 树仍保留折叠后的语义节点，这是可访问性保留，不代表视觉左岛没有折叠；前后原始截图确认了真实窗口几何变化。

本轮只新增 L2 五通道裁决。L3-L5 仍保持 `na`，没有把一次快捷键成功冒充为连续交互顺滑、视觉 craft 或从零可发现性通过。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-021456`
- workspace：`ws_04b87a593d2943b1`
- data：`/private/tmp/anselm-data-edge328-20260828-r1`
- 录屏：`screen.mov`，`51.711667s`；五通道由同一 manifest 归属
- 网关：`https://api.anselm.website`；managed challenge/install/models/quota 链路真实通过

## 产品路径

1. App 冷启动完成后，焦点仍在根容器，没有点击设置、按钮或输入框。
2. `⌘B`：截图 `EDGE-328-after-cmd-b.png` 显示左岛折叠为窄栏，中心内容稳定保留。
3. 再按 `⌘B`：截图 `EDGE-328-after-second-cmd-b.png` 显示左岛恢复，页面内容和设置值未被破坏。
4. Computer Use AX 读取、后端 console 和截图均没有运行时红线；AX 中保留 hidden semantic descendants，属于无障碍树设计，不作为视觉状态判据。

## 五通道证据

- **画面**：`EDGE-328-before-cmd-b.png`、`EDGE-328-after-cmd-b-settled.png`、`EDGE-328-after-second-cmd-b.png` 与 `screen.mov`；折叠/恢复均可见，无白闪、溢出或死状态。
- **后端**：backend journal 无 `WARN|ERROR|panic|FATAL`；本场景为本机快捷键，不产生业务 mutation。
- **SSE**：notifications/messages/entities 三流均连接并正常 EOF 收台；纯本地界面偏好路径无业务 durable 帧是预期行为。
- **前端 console**：frontend journal 无 `Unhandled exception`、Dart/Flutter、RenderFlex、RenderBox 或 overflow 红线；已知 macOS IMK 宿主提示已审阅。
- **LLM wire**：managed challenge/install/models/quota 均经过 llmtap 且为 200；快捷键场景不调用 chat completion。

## 收台与裁决

`rig-check` 与 `rig-down` 通过，录屏正常 finalize，收台后无 Anselm、Flutter、tap 或 recorder 残留。L2 依据 `G2` 写入；L3-L5 按证据边界保持 `na`，当前批次由 `13/50` 推进到 `14/50`。
