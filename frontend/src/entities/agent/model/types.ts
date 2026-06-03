// Agent entity types — mirrors backend domain/agent/*.go json tags,
// camelCase per API contract. Agent is the 4th Quadrinity member: an LLM
// loop bound to a prompt + skill + knowledge + tools, with the same version
// lifecycle as function/handler.
//
// 对齐后端 domain/agent json tag 字段名(camelCase)；Agent 是四项全能第四元。

export type VersionStatus = "pending" | "accepted";
export type OutputSchemaKind = "free_text" | "enum" | "json_schema";
export type ExecutionStatus = "ok" | "failed" | "cancelled" | "timeout";
export type TriggeredBy = "chat" | "workflow" | "http" | "test";

// ModelRef points at a configured model: apiKeyId + modelId (+ tuning options).
// nil on a version means "use the default agent model".
export interface ModelRef {
  apiKeyId: string;
  modelId: string;
  options?: Record<string, unknown>;
}

// ToolRef binds a tool the agent may call. ref prefix is fn_ / hd_ / mcp: —
// never ag_ (agents cannot invoke other agents as tools).
export interface ToolRef {
  ref: string;
  name: string;
}

// OutputSchema constrains the agent's final answer shape.
export interface OutputSchema {
  kind: OutputSchemaKind;
  enums?: string[];
  schema?: Record<string, unknown>;
}

export interface AgentVersion {
  id: string;
  agentId: string;
  status: VersionStatus;
  version?: number;
  prompt: string;
  skill: string;
  knowledge: string[];
  tools: ToolRef[];
  outputSchema?: OutputSchema;
  modelOverride?: ModelRef;
  changeReason?: string;
  forgedInConversationId?: string;
  acceptedAt?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Agent {
  id: string;
  name: string;
  description: string;
  tags: string[];
  activeVersionId: string;
  needsAttention: boolean;
  createdAt: string;
  updatedAt: string;
  // Computed fields (filled server-side, omitempty)
  activeVersion?: AgentVersion;
  pending?: AgentVersion;
}

// AgentExecution — one terminal record of an InvokeAgent call (mirrors
// function.Execution). Surfaced in the detail "Runs" tab + execution drawer.
export interface AgentExecution {
  id: string;
  userId: string;
  status: ExecutionStatus;
  triggeredBy: TriggeredBy;
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

// CreateAgentVars — POST /agents body (forge a brand-new agent + v1).
export interface CreateAgentVars {
  name: string;
  description?: string;
  tags?: string[];
  prompt: string;
  skill?: string;
  knowledge?: string[];
  tools?: ToolRef[];
  outputSchema?: OutputSchema;
  modelOverride?: ModelRef;
  changeReason?: string;
}

// UpdateAgentMetaVars — PATCH /agents/{id} body (name/description/tags only).
export interface UpdateAgentMetaVars {
  name?: string;
  description?: string;
  tags?: string[];
}

// EditAgentVars — POST /agents/{id}:edit body (produces a pending version).
export interface EditAgentVars {
  prompt?: string;
  skill?: string;
  knowledge?: string[];
  tools?: ToolRef[];
  outputSchema?: OutputSchema;
  modelOverride?: ModelRef;
  changeReason?: string;
}

// InvokeAgentVars — POST /agents/{id}:invoke body.
export interface InvokeAgentVars {
  id: string;
  version?: number | string;
  input?: Record<string, unknown>;
}

// InvokeAgentResult — synchronous invoke response.
export interface InvokeAgentResult {
  executionId: string;
  ok: boolean;
  output: unknown;
  status: string;
  steps: number;
  tokensIn: number;
  tokensOut: number;
  elapsedMs: number;
}

// AgentExecutionsResult — the executions list envelope (custom shape, not
// the standard §N4 paged list: backend wraps with count + aggregates).
export interface AgentExecutionsResult {
  count: number;
  executions: AgentExecution[];
  nextCursor?: string | null;
  hasMore: boolean;
  aggregates?: Record<string, unknown>;
}
