// Workflow entity types — mirrors backend domain/workflow/*.go json tags,
// camelCase per API contract.
//
// 对齐后端 domain/workflow json tag 字段名（camelCase）。

export type VersionStatus = "pending" | "accepted" | "rejected";

export interface VariableSpec {
  name: string;
  type?: string;
  description?: string;
  default?: unknown;
}

export interface EdgeSpec {
  id: string;
  from: string;
  fromPort?: string;
  to: string;
  toPort?: string;
}

export interface NodeSpec {
  id: string;
  type: string;
  label?: string;
  config?: Record<string, unknown>;
}

export interface Graph {
  name: string;
  description?: string;
  tags?: string[];
  variables?: VariableSpec[];
  nodes: NodeSpec[];
  edges: EdgeSpec[];
}

export interface WorkflowVersion {
  id: string;
  workflowId: string;
  status: VersionStatus;
  version?: number;
  graph: string;
  graphParsed?: Graph;
  changeReason: string;
  forgedInConversationId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Workflow {
  id: string;
  userId: string;
  name: string;
  description: string;
  tags: string[];
  enabled: boolean;
  concurrency: string;
  needsAttention: boolean;
  attentionReason: string;
  activeVersionId: string;
  createdAt: string;
  updatedAt: string;
  // Computed fields (filled server-side, omitempty)
  pending?: WorkflowVersion;
  liveRuns?: number;
  lastFiredAt?: string;
  nextFireAt?: string;
}

// WorkflowEditOp — one item in the ops array sent to POST :edit or POST (create).
// Each op has a type string; the rest of the fields depend on the op.
export interface WorkflowEditOp {
  op: string;
  [key: string]: unknown;
}

export interface EditWorkflowVars {
  ops: WorkflowEditOp[];
  changeReason?: string;
}

export interface RunWorkflowVars {
  id: string;
  input?: Record<string, unknown>;
}

export interface CapabilityIssue {
  nodeId: string;
  kind: string;
  ref: string;
  reason: string;
}

export interface CapabilityCheckResult {
  ok: boolean;
  issues: CapabilityIssue[];
}
