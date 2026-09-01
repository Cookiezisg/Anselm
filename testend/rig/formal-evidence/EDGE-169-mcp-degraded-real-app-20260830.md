# EDGE-169 MCP degraded 态：真实 App L2

- 正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-173628`，workspace=`ws_d50804cf97c46002`，App、backend、ssetap、llmtap 和窗口录屏均由同一 manifest 归属。
- 通过真实 `PUT /api/v1/mcp-servers/edge169` 接入本地受控 stdio MCP。该 server 提供 `boom`（稳定返回 MCP `isError`）和 `echo`（成功回显），不访问外部账户或网络服务。
- 连续三次真实产品工具调用 `boom` 均返回 HTTP `MCP_RPC_ERROR`，调用台账累计 `3 failed`；entities SSE 记录三个完整 `open→close(error)`，随后记录 ephemeral status `ready→degraded`，包含真实错误原因。真实 App MCP servers 面板显示 `degraded · 2 tools · 3 calls`、橙色状态点和可读错误文案。
- 在 degraded 状态下真实调用 `echo({text:"recovered"})` 返回 `edge169:recovered`；REST 状态变为 `ready`、`consecutiveFailures=0`、`totalCalls=4`、`totalFailures=3`，entities SSE 记录 `degraded→ready`。App 面板随后显示 `1 servers · 1 ready` 与 `ready · 2 tools · 4 calls`。
- 五通道对账：`rig-check.sh` 全绿；SSE 共 `23` 帧且包含 messages/entities/notifications 三流，status signal 顺序为 `disconnected→connecting→ready→degraded→ready`；LLM tap 完成 managed challenge/install/models；backend journal 无应用级 WARN/ERROR/panic/FATAL；frontend console 只有已知 IMK/TSM 宿主诊断，无 Flutter/Dart/RenderFlex/unhandled/assertion；`screen.mov` 为 `3104x1844 / 60fps / 122.45s` 且 ffprobe 可读，收台后进程组归零。
- 本证据仅支持 L2“真实 App 与后端/SSE 状态事实一致”；L3-L5 继续保留清册既有未收口状态，不把本次状态验证扩张为顺滑、视觉 craft 或从零发现性通过。
