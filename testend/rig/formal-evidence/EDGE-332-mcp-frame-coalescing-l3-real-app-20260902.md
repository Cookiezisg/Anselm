# EDGE-332 MCP 面板帧不可信：L3 真实 App 顺滑证据

- session: `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`
- recording: `screen.mov`, `62.496667s`, `3104x1848`, 60fps
- law: `B2`（非用户触发的既有内容零跳变）
- verdict: `pass` for L3

## Product path

1. 真实 App 启动后进入 Settings → MCP servers；entities 流第一次由代理延迟 12 秒并返回 410。
2. App 没有把缺口帧当作 MCP 名册，也没有显示错误实体；entities 流随后重新连接并继续接受服务端名册。
3. 通过真实后端创建一个故意无法启动的 MCP server，随后快速连续执行三次 Reconnect。UI 始终收敛为一台失败服务器，而不是重复卡片或瞬时状态的错误叠加。
4. 删除该测试服务器后，真实 App 回到 marketplace 空态；没有残留失败卡、空白详情页或 stale roster。

## Measurement

从封口录像抽取 2fps 过渡帧及 60fps 原始录像。`measure diff` 的稳定段只有两次有意义的局部变化：

```text
stable roster → failed MCP card: bbox=(302,184)-(638,218), changedFrac=0.00574
technical-details disclosure: bbox=(302,97)-(638,416), changedFrac=0.0923
```

两次变化都发生在状态变更或用户显式展开后的中心面板区域；静止尾段没有持续 reflow、重复名册、闪回或视口夺取。MCP 失败卡的状态转换不把 entities 的 ephemeral frame 直接投影成错误实体，符合 B2 的零跳变要求。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 画面包含 410 重同步、失败 MCP 卡、人话错误提示、显式技术详情和删除后的 marketplace 空态。
- **backend**: `backend.log` 共 `282` 行，无 `WARN`、`ERROR`、`panic`、`fatal` 或 `FATAL`；创建、三次重连、删除和 roster 读取均可追溯。
- **SSE**: `sse.jsonl` 真实连接 messages/entities/notifications 三流；entities 410 后恢复，MCP 状态帧均为 `seq=0` ephemeral，notifications durable seq 单调递增至 22。
- **frontend console**: `frontend.log` 仅有正常 Flutter VM 行和 macOS IMK 诊断，无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow。
- **LLM wire**: managed gateway challenge/install/models 均 HTTP `200`；本场景没有把设置页变更伪装成模型调用。
- **app proxy**: `appproxy.jsonl` 精确记录 entities stream 一次 410 failure，随后一次 forward；MCP roster refresh 请求在三次重连后收敛。
- **rig lifecycle**: `rig-check.sh` 五通道和进程归属全通过；`rig-down.sh` 完成 `62.496667s` 录像并收台。

## Verdict

`L3 pass (B2)`。实体流缺口、密集 MCP 状态帧和删除后的空态都回到服务端真相，画面没有非用户触发的既有内容跳变；本格不重复结算 L4 craft 或 L5 discoverability。
