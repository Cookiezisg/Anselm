# EDGE-333 · 保留面板无客户端默认 · 真实 App 复验记录

## 结论

本记录是对既有 `EDGE-333` L2 账本的当前版本复验，不新增账本格，也不把本次观察冒充为 L3-L5 通过。真实 App 中保留策略可以被发现、读取、修改并恢复；本次没有发现数据错位、布局溢出、红色运行时错误或状态卡死。

L3（顺滑反馈）、L4（视觉 craft）和 L5（从零可发现性）继续保持清册中的 `na`：本次记录了 Computer Use 的操作调用墙钟时间，但没有把它当作“动作帧到首个可见反馈帧”的独立测量；视觉只做了人工收台观察，没有 `measure` ROI/对比证据；可发现性也不是从零用户盲走的完整旅程。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-015950`
- manifest workspace：`ws_baa3dfe352395d8a`
- data：`/private/tmp/anselm-data-edge333-20260828-r1`
- 录屏：`screen.mov`，`2784x1808`，60fps，`164.161667s`
- 运行方式：标准 conductor；真实 Flutter App、sidecar、三路独立 SSE witness、LLM tap、窗口录屏均由 manifest 归属
- 网关：`https://api.anselm.website`；challenge/install/models/quota 均为 200

## 产品路径

1. 在真实 App 设置页进入“存储与日志”。
2. 看到机器级数据目录、磁盘使用、诊断、数据库和“运行历史保留”区域；当前值为 `90 天`，范围为“全机”。
3. 打开下拉菜单，四个选项均可见且可选：`30 天`、`90 天`、`180 天`、`永久保留`。
4. 选择 `30 天`，App 显示“保留策略已更新”，回读值为 `30 天`。
5. 再选择 `90 天`，App 再次显示“保留策略已更新”，回读值恢复为 `90 天`，没有留下测试改动。

## 五通道证据

- **画面**：录屏覆盖完整设置面板、菜单展开、两次选择和最终恢复；人工逐帧收台观察到面板结构稳定，范围徽标、标题和值未发生跳变或溢出。
- **后端**：`backend.log` 记录 `/api/v1/retention` 初始 GET、两次 PATCH 和两次 GET，全部 HTTP 200；两次 PATCH `elapsed_ms=1`，GET `elapsed_ms=0`。
- **SSE**：`ssetap` 对 notifications/messages/entities 三流均完成连接；本场景只改机器级设置，没有业务实体 durable 帧是预期行为。
- **前端 console**：`frontend.log` 无 `Unhandled exception`、`Dart/Flutter` 运行时红线、layout overflow 或 `RenderBox` 错误；唯一宿主级 IMK warning 已审阅，不属于 App 运行时错误。
- **LLM wire**：本场景不需要聊天模型调用；llmtap 仍记录并验证 managed challenge/install/models/quota 链路，未把“无模型调用”误报成缺证据。

## 测量边界

Computer Use 调用记录的打开菜单墙钟约 `1039ms`、选择并回读约 `456ms`；这是工具调用的端到端等待，不是法典 A1 要求的动作帧到首个可见反馈帧。因此不能据此宣称 `A1` 或 L3 通过。录屏虽可用于后续离线帧定位，但本次没有动作时间锚点和独立 `measure latency` 输出，故保持诚实缺口。

## 收台

`rig-check` 与 `rig-down` 均通过；录屏已正常 finalize，收台后未发现 Anselm、Flutter、tap 或 recorder 残留进程。此次复验不写 `judge.py`，当前批次仍为 `13/50`。
