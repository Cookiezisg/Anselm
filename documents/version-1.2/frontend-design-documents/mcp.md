# entities/mcp — 前端 slice 详细设计

**所属层**：entities（对位后端 domain/mcp）
**状态**：✅ 已实现
**职责**：查询 MCP Server 列表（运行时状态 + 工具列表）+ 重连 + 移除。MCP server 以 name 为主键，配置来自磁盘，前端不创建。

**关联文档**：
- [`../frontend-design.md`](../frontend-design.md) — FSD 总规范
- 后端 `service-design-documents/mcp.md`

---

## 1. 职责边界

- 列表查询（含运行状态 + tools）
- 重连（:reconnect）
- 移除（DELETE）

不含 MCP 配置文件编辑（文件系统操作，超出前端范围）。

---

## 2. 类型（`model/types.ts`）

```ts
interface ToolDef {
  serverName; name; description; inputSchema: unknown;
}

interface McpServer {
  name: string;   // 主键（无 id 前缀）
  status: "disconnected" | "connecting" | "ready" | "degraded" | "failed";
  pid?: number;
  connectedAt?; lastError?; lastErrorAt?; lastSuccessAt?;
  consecutiveFailures: number;
  totalCalls: number; totalFailures: number;
  tools: ToolDef[];
}

interface ReconnectMcpResult { name: string; status: string }
```

`status` 枚举与后端 `mcp.ServerStatus` const 对齐。`tools` 是运行时从 server 动态获取的，服务端断连时为空数组。

---

## 3. API hooks（`api/mcp.ts`）

| Hook | 方法 + 端点 | 说明 |
|---|---|---|
| `useMcpServers()` | GET `/mcp-servers?limit=100` | 列表；select pickList |
| `useReconnectMcp()` | POST `/mcp-servers/{id}:reconnect` | 重连；invalidate mcpServers |
| `useRemoveMcp()` | DELETE `/mcp-servers/{id}` | 移除；invalidate mcpServers |

---

## 4. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/entities/mcp/model/types.ts` | McpServer / ToolDef / ReconnectMcpResult 类型 |
| `frontend/src/entities/mcp/api/mcp.ts` | 3 个 hooks |
| `frontend/src/entities/mcp/index.ts` | public API |
