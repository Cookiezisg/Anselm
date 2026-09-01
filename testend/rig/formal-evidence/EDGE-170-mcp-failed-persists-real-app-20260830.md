# EDGE-170 MCP 连接失败仍落盘：真实 App L2

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-174239`，workspace=`ws_7ba61827a40480e0`，App、backend、ssetap、llmtap 和窗口录屏均由同一 manifest 归属。
- 通过真实 `PUT /api/v1/mcp-servers/edge170` 配置一个不存在的本地 stdio 脚本。后端返回并持久化 `status=failed`、`lastError="mcp.Client.Initialize: connect edge170: mcp server not connected: calling \"initialize\": EOF"`，没有假装成功，也没有丢掉 server 行。
- 真实 App MCP servers 面板显示 `1 servers · 1 failed`，卡片显示 `edge170`、`failed` 和完整初始化错误。该状态在重读 workspace 与 MCP 列表后仍存在。
- 随后在原配置路径恢复受控脚本，调用真实 `POST /api/v1/mcp-servers/edge170:reconnect`；后端返回 `ready` 与一个 `echo` 工具，App 面板同步显示 `1 servers · 1 ready`，真实 `echo({text:"after-reconnect"})` 返回 `edge170:after-reconnect`。
- 五通道对账：`rig-check.sh` 全绿；SSE 共 `21` 帧，status 顺序包含启动失败两次与 reconnect 后 `connecting→ready`；LLM tap 完成 managed challenge/install/models；backend journal 无应用级 WARN/ERROR/panic/FATAL；frontend console 只有已知 IMK/TSM 宿主诊断，无 Flutter/Dart/RenderFlex/unhandled/assertion；`screen.mov` 为 `3104x1844 / 60fps / 65.176667s` 且 ffprobe 可读，收台后进程组归零。
- 本证据支持 L2 的“连接失败持久可见且 reconnect 可恢复”事实；L3-L5 不由本次 L2 扩张判定。
