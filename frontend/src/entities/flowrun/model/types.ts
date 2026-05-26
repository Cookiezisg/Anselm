// FlowRun entity types — mirrors backend domain/flowrun/*.go json tags,
// camelCase per API contract.
//
// 对齐后端 domain/flowrun json tag 字段名（camelCase）。

export type FlowRunStatus = "running" | "paused" | "completed" | "failed" | "cancelled";
export type FlowRunTriggerKind = "cron" | "fsnotify" | "webhook" | "manual";
export type FlowRunNodeStatus = "pending" | "running" | "ok" | "failed" | "cancelled" | "timeout" | "skipped";
export type ApprovalDecision = "approve" | "reject";

export interface PausedState {
  nodeId: string;
  variables: Record<string, unknown>;
  outputs: Record<string, Record<string, unknown>>;
  position: string[];
  pausedAt: string;
}

export interface FlowRun {
  id: string;
  userId: string;
  workflowId: string;
  versionId: string;
  triggerKind: FlowRunTriggerKind;
  triggerInput: Record<string, unknown>;
  status: FlowRunStatus;
  startedAt: string;
  endedAt?: string;
  elapsedMs: number;
  output?: unknown;
  errorCode?: string;
  errorMessage?: string;
  pausedState?: PausedState;
  dryRun: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface FlowRunNode {
  id: string;
  userId: string;
  status: FlowRunNodeStatus;
  triggeredBy: string;
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
  flowrunId: string;
  flowrunNodeId?: string;
  nodeId: string;
  nodeType: string;
  attempts: number;
  parentLoopNode?: string;
  iterationIndex?: number;
  createdAt: string;
}

export interface FlowRunsParams {
  workflowId?: string;
  status?: FlowRunStatus;
  triggerKind?: FlowRunTriggerKind;
  cursor?: string;
  limit?: string | number;
}

export interface ApproveNodeVars {
  runId: string;
  nodeId: string;
  decision?: ApprovalDecision;
  reason?: string;
}

export interface RejectNodeVars {
  runId: string;
  nodeId: string;
  reason?: string;
}
