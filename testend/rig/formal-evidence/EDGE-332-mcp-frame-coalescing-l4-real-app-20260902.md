# EDGE-332 MCP 面板帧不可信：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- representative frames: session `evidence/edge332-transition-contact.png` and
  `evidence/frames-2fps/0038.png`, `evidence/frames-2fps/0070.png`
- law: `C4`（圆角与视觉尺度阶梯）
- verdict: `pass` for L4

## Visual craft review

失败态保留 MCP 服务器名称、状态点和失败状态，但错误区域使用产品化的 danger callout：标题是
`MCP server connection failed`，正文说明检查配置或运行环境并选择 Reconnect。原始
`mcp.Client.Initialize...EOF` 不在静息画面出现，避免技术异常破坏信息层级。

错误提示、卡片、按钮和技术详情披露的圆角、内距、颜色层级保持一致；状态从 marketplace 到失败卡、再到删除后的 marketplace 空态，没有重叠、截断、白闪、重复容器或残留详情。技术详情是稳定的显式 disclosure，不是把诊断文本突然插入主布局。

`measure diff` 的变化只落在中心面板对应区域；2fps 过渡接触表和 60fps 封口录像的静止尾段没有持续 reflow。正文对比抽样为 `6.61:1`，满足 WCAG AA 普通正文 `4.5:1` 门槛。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 逐帧看到失败 callout、折叠的 Technical details、展开后的原始异常和删除后的完整 marketplace 空态。
- **backend**: `backend.log` 无应用级红线；故意失败只来自本次 fixture 的不可启动命令，未被误判为后端崩溃。
- **SSE**: 三条 SSE 流真实连接并干净断开；entities 的 ephemeral 状态帧没有被当作 UI 实体真相。
- **frontend console**: 无 Flutter/Dart/layout/runtime 红线，仅正常 VM 启动信息和已知 macOS IMK 诊断。
- **LLM wire**: challenge/install/models 均真实 `200`，没有模型输出来替代视觉事实。
- **durable truth**: notifications 记录 `mcp.installed`、三次 `mcp.reconnected` 和 `mcp.removed`；UI 的失败卡和空态顺序与耐久事件一致。
- **rig lifecycle**: `rig-check`、录屏、frame extraction 和 `rig-down` 均通过，五通道归属完整。

## Verdict

`L4 pass (C4)`。失败、技术详情和空态三种界面都保持同一套视觉尺度与层级；异常的可诊断性没有以牺牲产品表面为代价。本格不重复结算 L3 的数据流顺滑或 L5 的入口发现。
