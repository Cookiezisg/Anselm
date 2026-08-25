# EDGE-332 · MCP 面板帧不可信

## L1 focused evidence

- `frontend/test/features/settings/s4_mcp_test.dart` 通过：MCP loading 不伪装为空、失败保留可解释错误、市场安装与重试状态都落在正确面；列表不把瞬时帧当作实体真相。
- `frontend/lib/features/settings/state/mcp_providers.dart` 契约复核：entities stream 的 MCP 帧只触发 300ms 单次 coalesce refetch，410 resync 走强制重取；`s4_mcp_test.dart` 与实时 provider 测试集合通过。

## 判定

L1=`F2`：MCP 面板以服务端实体读为真相，SSE 仅作刷新提示，密集帧不会造成请求风暴，缺口不会让面板永久陈旧。L2-L5 本批未启动真实 App，记 `na`。
