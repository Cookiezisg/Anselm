// Agent wire types for testend. The frontend has no src/entities/agent slice yet, so unlike
// function/handler/workflow views (which deep-import @frontend types), these mirror the backend
// domain JSON shapes (backend/internal/domain/agent/agent.go) directly. Keep in sync with backend.

export interface ModelRef {
  apiKeyId: string;
  modelId: string;
  options?: Record<string, unknown>;
}

export type OutputSchemaKind = "free_text" | "enum" | "json_schema";

export interface OutputSchema {
  kind: OutputSchemaKind;
  schema?: Record<string, unknown>;
  enums?: string[];
}

export interface ToolRef {
  ref: string; // fn_xxx | hd_xxx.method | mcp:server/tool
  name: string;
}

export interface AgentVersion {
  id: string;
  agentId: string;
  userId: string;
  prompt: string;
  skill?: string;
  knowledge: string[];
  tools: ToolRef[];
  outputSchema?: OutputSchema;
  modelOverride?: ModelRef;
  version?: number;
  status: "pending" | "accepted";
  acceptedAt?: string;
  changeReason?: string;
  forgedInConversationId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Agent {
  id: string;
  userId: string;
  name: string;
  description: string;
  tags: string[];
  activeVersionId?: string;
  needsAttention: boolean;
  createdAt: string;
  updatedAt: string;
  activeVersion?: AgentVersion;
  pending?: AgentVersion;
}

export interface AgentExecution {
  id: string;
  userId: string;
  status: "ok" | "failed" | "cancelled" | "timeout";
  triggeredBy: "chat" | "workflow" | "http" | "test";
  input: Record<string, unknown>;
  output?: unknown;
  errorCode?: string;
  errorMessage?: string;
  elapsedMs: number;
  startedAt: string;
  endedAt: string;
  conversationId?: string;
  messageId?: string;
  toolCallId?: string;
  flowrunId?: string;
  flowrunNodeId?: string;
  agentId: string;
  versionId: string;
  modelId?: string;
  createdAt: string;
}

export interface ExecutionAggregates {
  okCount: number;
  failedCount: number;
  cancelledCount: number;
  timeoutCount: number;
  avgElapsedMs: number;
  p95ElapsedMs: number;
}

export interface SearchExecutionsResult {
  count: number;
  executions: AgentExecution[];
  nextCursor?: string;
  hasMore: boolean;
  aggregates: ExecutionAggregates;
}

// :invoke response (app/agent/invoke.go ExecutionResult).
export interface InvokeResult {
  executionId: string;
  ok: boolean;
  output: unknown;
  status: string;
  stopReason?: string;
  steps: number;
  tokensIn: number;
  tokensOut: number;
  errorMsg?: string;
  elapsedMs: number;
}
