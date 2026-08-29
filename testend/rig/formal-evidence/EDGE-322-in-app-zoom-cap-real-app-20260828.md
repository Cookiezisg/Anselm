# EDGE-322 · 应内缩放到顶 · 真实 App L2

## 结论

真实 Flutter macOS App 在正式 conductor 会话中完成应内缩放边界验证：从 `1.0×` 点到 `1.1×` 后，整套 UI 发生一致的重排；再点 `1.25×`，控件保持禁用且当前值仍为 `1.1×`，没有把窗口或内容推入不可容纳的档位；最后恢复 `1.0×`。没有观察到布局溢出、截断、白带或状态卡死。

本轮只新增 L2 五通道裁决。L3-L5 仍保持 `na`：没有独立的动作帧到首反馈帧测量、ROI craft 数字或从零盲走，不把一次边界成功冒充为完整顺滑、视觉 craft 或可发现性通过。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-022508`
- workspace：`ws_cc83f5e7903c9dec`
- data：`/private/tmp/anselm-data-edge322-20260828-r1`
- 录屏：`screen.mov`，`163.741667s`；窗口 `2784×1808 / 60fps`；五通道由同一 manifest 归属
- 网关：`https://api.anselm.website`；managed challenge/install/models 均经 llmtap 返回 200

## 产品路径

1. 真实 App 启动后打开「设置 → 通用」，初始界面缩放为 `1.0×`。
2. 点击 `1.1×`：设置面板和左侧导航同步放大，截图 `zoom-11.jpg` 显示中心内容仍完整落在窗口内，控件间距与文本没有被压扁。
3. 点击 `1.25×`：截图 `zoom-125-attempt.jpg` 显示当前选择仍为 `1.1×`，`1.25×` 保持灰置；实现中的屏幕容量 cap 阻止越界档位。
4. 点击 `1.0×`：截图 `zoom-reset-click.jpg` 显示界面回到默认密度，后续状态没有残留放大布局。

## 五通道证据

- **画面**：`screen.mov` 与 `zoom-before.jpg`、`zoom-11.jpg`、`zoom-125-attempt.jpg`、`zoom-reset-click.jpg`；真实窗口连续帧覆盖放大、拒绝越界和恢复全过程。
- **后端**：backend journal 无 `WARN|ERROR|panic|FATAL`；缩放只写本机偏好，不产生业务错误。
- **SSE**：notifications/messages/entities 三流均建立连接并在收台时正常 EOF；本机偏好路径无业务 durable 帧是预期行为。
- **前端 console**：frontend journal 无 `Unhandled exception`、Dart/Flutter、RenderFlex、RenderBox 或 overflow 红线；已知系统宿主提示未出现应用级异常。
- **LLM wire**：managed challenge/install/models 全部经过 llmtap；本场景不调用 chat completion。

## 收台与裁决

`rig-check` 与 `rig-down` 通过，录屏正常 finalize，收台后无 Anselm、Flutter、tap 或 recorder 残留。L2 使用 `G2` 写入；L3-L5 按证据边界保持 `na`。
