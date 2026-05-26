// McpServer entity types — mirrors backend domain/mcp/*.go json tags, camelCase per API contract.
// MCP uses name as primary key (no id prefix). json:"-" fields omitted.
//
// 对齐后端 domain/mcp json tag 字段名(camelCase)；mcp server 以 name 为主键。

export interface ToolDef {
  serverName: string;
  name: string;
  description: string;
  inputSchema: unknown;
}

export interface McpServer {
  name: string;
  status: "disconnected" | "connecting" | "ready" | "degraded" | "failed";
  pid?: number;
  connectedAt?: string;
  lastError?: string;
  lastErrorAt?: string;
  lastSuccessAt?: string;
  consecutiveFailures: number;
  totalCalls: number;
  totalFailures: number;
  tools: ToolDef[];
}

export interface ReconnectMcpResult {
  name: string;
  status: string;
}
