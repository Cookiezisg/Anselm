# EDGE-332 · MCP 面板帧不可信 · 真实 App 五通道 L2

## 结论

通过。真实 App 的 MCP 名册不采信 entities 帧内容，只把它们当作刷新提示：短时间内多组
`connecting/failed` 状态帧被 300ms 合并为一次 `GET /mcp-servers`；entities 流收到 410 后，
已建立的 MCP provider 立即重取名册。面板最终以 REST 真相显示失败 server，删除后又收敛为空态，
没有帧驱动的请求风暴或永久陈旧。

## 运行边界

- 日期：2026-08-28
- formal session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-025843`
- workspace：`ws_b9340bcec80b9b35`
- data：`/private/tmp/anselm-data-edge332-20260828-r2`
- 录屏：`screen.mov`，时长 `54.981667s`
- 410 注入：App 的 `/api/v1/entities/stream` 首次响应 410，延迟 12s，确保 MCP provider 已订阅

## 产品路径与可证伪结果

1. 启动真实 App，直接进入 Settings → MCP 服务器，等待真实市场与空名册落定。
2. entities stream 首次被代理返回 410；代理日志记录随后重连，backend 在 `13.172s` 处收到
   MCP 名册重取，证明 410 不是被某个尚未建立的 provider 吞掉。
3. 通过真实 REST 创建一个无法连接的 stdio MCP server `edge332-real-burst`，随后连续三次
   `:reconnect`。四次动作在约 100ms 内产生多组 entities `mcp` status 帧；backend 只在
   300ms 合并窗口后新增一次 `GET /api/v1/mcp-servers`，面板显示“1 台 · 失败 1”和该 server。
4. 删除测试 server；删除通知再次触发一次权威重取，面板回到市场空态，没有残留测试对象。

## 五通道证据

- **画面**：Computer Use 逐帧确认 MCP 面板从 loading/空态到失败 server，再回到删除后的空态；
  状态由 REST 返回的失败结果呈现，不由某一帧 payload 直接改写。
- **后端**：backend PID `47445` 持有 `:8742`；MCP PUT、三次 reconnect、DELETE 均成功返回，
  相关名册 GET 的时间点对应 410 resync 和 300ms coalescer；无 panic/ERROR/FATAL。
- **SSE**：ssetap PID `47510` 连接 messages/entities/notifications 三路；entities 日志记录
  410 场景外的连续 MCP status 帧，notifications `mcp.installed/reconnected/removed` 序列完整。
- **前端 console**：真实 App PID `47999` 与窗口录制归属一致；无 Flutter/Dart/RenderFlex/
  RenderBox/overflow 红线；唯一 `IMKCFRunLoopWakeUpReliable` 是已分类 macOS 输入法宿主提示。
- **LLM wire**：llmtap PID `47427` 归属 `:8788`，managed challenge/install/models 均为 200；
  本场景不调用模型。

## 收台与裁决

`rig-check` 与 `rig-down` 通过，录屏已 finalize，收台后无 Anselm、Flutter、tap 或 recorder 残留。
L2 使用 `G2`；L3-L5 保持 `na`，没有把 300ms 合帧正确冒充为独立时延、视觉 craft 或可发现性
通过。
