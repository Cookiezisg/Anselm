# EDGE-173 · MCP name-or-id 双键 purge：真实 App 五通道验收

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260905-edge293/sessions/20260905-032135`
- workspace=`ws_9c6defd281bd5957`
- fixture MCP=`edge173_mcp`；fixture agent=`ag_8cbf4532e1e6219a`；挂载=`mcp:edge173_mcp/echo`
- 录屏=`screen.mov`，`3104x1846 / 60fps / 107.891667s`
- renderer workaround=`RIG_ENGINE_SWITCHES=enable-impeller=false`；这是台架采集开关，不宣称 Impeller 官方构建已修复

## 用户路径与产品结果

真实 App 的 Settings → MCP servers 页面展示了 `edge173_mcp` 的 ready 状态和 1 个 tool。通过该行的 More actions 打开菜单，选择 Delete，确认框明确写出服务器名称、配置会被移除以及软删除语义；点击最终 Delete 后，页面先进入可见 loading 过渡，随后回到无服务器的 marketplace 空态。没有残留旧卡片、遮挡或未解释的空白。

## 五通道证据

- **Channel 1 / Computer Use 与录屏**：确认前截图=`EDGE-173-delete-confirmation.png`；删除后截图=`EDGE-173-delete-after.png`。AX 树实际走过 More actions → Delete → Delete confirmation，录屏显示确认框稳定、删除后的 loading 过渡以及最终空态。局部 30fps 半栅格分析记录在 `EDGE-173-visual-measurement.txt`：确认框保持到 `frame-0142`，首个状态变化发生在 `frame-0142 → frame-0143`，变化包围盒集中在 App 内容区。
- **Channel 2 / backend journal**：DELETE `/api/v1/mcp-servers/edge173_mcp` 返回 `204`，关系 purge 日志为 `removed=1`；删除后 MCP GET 返回 `404 MCP_SERVER_NOT_FOUND`，MCP 列表为空，按 ID 与按 name 查询的 relations/neighborhood 均为空。backend journal 无未解释的应用级 WARN/ERROR 或 panic。
- **Channel 3 / independent SSE witness**：notifications 流记录连续 durable `seq=1 relation.dependency_broken`，内容包含被删 MCP、挂载 Agent 和 `equip` 边；随后 `seq=2 mcp.removed`，内容包含 `edge173_mcp`。messages 与 entities 流均在同一场景连接并由 rig-check 见证，未伪造额外帧。
- **Channel 4 / frontend console**：frontend journal 只有 App 启动行和 Dart VM service 行，没有 `FlutterError`、`DartError`、`RenderFlex`、`RenderBox` 或未处理异常。删除后真实 App 落到稳定空态，列表与 marketplace 入口重新可用。
- **Channel 5 / LLM wire**：llmtap 已连接真实受管网关并完成 proof challenge/quota 请求；本场景是 Settings 的确定性删除路径，不应触发模型调用，因此没有伪造 completion 或把无模型路径误报为模型成功。

## 判定

- L1=`pass`：focused relation purge 回归与本场景真实删除结果共同证明 ID/name 双键清边要求。
- L2=`pass(F1)`：真实 App、backend、SQLite/REST 真相、三路 SSE、frontend console 与 LLM tap 均有同场记录；删除对象、关系边和依赖告警闭合。
- L3=`pass(A4)`：删除等待期间没有静默无响应；真实界面保留确认态并进入可见 loading 过渡，随后落到终态空态。服务端删除日志耗时 `3ms`，视觉过渡的局部测量见上述文件；未把 HTTP 耗时冒充用户输入首帧。
- L4=`pass(C4)`：确认框与最终空态的圆角、层级、遮罩和空态回收经过真实录屏/截图复核，没有裁切、残留旧卡片或布局跳变；局部变化没有扩散为无关页面抖动。
- L5=`pass(G1)`：不依赖内部 API 名称即可从 Settings → MCP servers → More actions → Delete 找到删除入口，确认框的对象身份和后果足够明确，删除后空态保留下一步 Add manually / Import 入口。

## 外部边界

未使用真实 MCP OAuth、第三方 tenant 或模型 completion；该边界不影响本 edge 的本地 MCP 删除、关系清理和真实 App 产品路径。受管网关仅用于真实台架 bootstrap，未消费生成配额。
