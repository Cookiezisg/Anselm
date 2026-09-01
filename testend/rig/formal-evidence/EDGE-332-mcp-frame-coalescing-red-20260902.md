# EDGE-332 MCP 面板帧不可信：红场与 stop-and-fix

- red session: `/private/tmp/anselm-rig-formal-20260901-15/sessions/20260901-235448`
- trigger: 真实 App 中创建故意无法启动的 MCP server，并观察密集 entities 状态帧与三次快速重连
- violated law: `E1`（裸错误码/裸异常串上 UI = 违）
- status: fixed and revalidated in `/private/tmp/anselm-rig-formal-20260902-01/sessions/20260902-000524`

## Finding

红场的失败 MCP 卡直接显示：

```text
mcp.Client.Initialize: connect edge332-burst: mcp server not connected: calling "initialize": EOF
```

这把实现层异常当成了用户主文案，虽然状态点和 failed 标签正确，但不满足“出了什么事、当前状态、下一步怎么办”的人话错误三要素。该场景因此停止，不使用红场录像盖 L3-L5 绿格。

## Fix

`frontend/lib/features/settings/ui/panels/mcp_panel.dart` 新增共享 `_McpFailure`：失败面先显示产品化 danger callout，说明连接失败并指向检查配置/运行环境后重连；原始异常只在显式展开 `Technical details` 后显示。中英文 i18n 已同步，`s4_mcp_test.dart` 与 `p3_rebuild_test.dart` 锁定默认隐藏和按需展开行为。

## Revalidation

新构建在真实 App 中重走 entities `410` 重同步、密集 MCP 状态帧、失败卡、显式技术详情和删除回 marketplace 空态；新录像确认默认面不再泄露异常，组件测试 `32` 项全绿，随后 EDGE-332 L3/L4/L5 分别以 `B2/C4/G1` 入账。
