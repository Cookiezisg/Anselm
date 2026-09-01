# EDGE-332 MCP 面板帧不可信：L5 真实 App 可发现性证据

- session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- representative frames: session `evidence/edge332-transition-contact.png`
- law: `G1`（入口无需文档即可找到并完成）
- verdict: `pass` for L5

## Blind product path

以普通用户目标“查看、修复或移除一个 MCP 服务器”为目标，不依赖 endpoint、SSE、代理或内部错误码：

1. 从 Settings 导航直接进入 `MCP servers`，入口命名与内容一致。
2. 名册发生缺口并刷新后，失败服务器仍以名称和 `failed` 状态出现；用户不会被空列表误导。
3. 失败面直接给出检查配置/运行环境并 Reconnect 的下一步；诊断内容收在可理解的 `Technical details` 披露项中。
4. 完成删除后，列表回到 marketplace，用户能继续添加 MCP，而不是留在过期详情或无内容墓碑。

普通用户不需要知道 410、ephemeral、coalesce 或 `mcp.Client.Initialize`，也不需要重启 App 才能恢复可操作状态。

## Five-channel cross-check

- **frames / Computer Use**: 真实导航、失败状态、技术详情按需展开和删除回空态均在录像中可见。
- **backend**: roster 读取和删除请求成功；无应用级 WARN/ERROR/panic/fatal。
- **SSE**: messages/entities/notifications 三流真实连接，entities 410 后重连，删除事件真实到达 notifications。
- **frontend console**: 无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed challenge/install/models 为真实 `200`，设置页不以模型自述冒充成功。
- **durable truth**: MCP 安装、重连和删除的服务端状态与 UI 最终列表一致。
- **rig lifecycle**: 五通道 `rig-check`、录像封口和 `rig-down` 均通过。

## Verdict

`L5 pass (G1)`。入口、失败解释、恢复动作、技术诊断和删除后的下一目标均无需文档即可理解；本格不把内部观测工具的可见性冒充产品入口。
