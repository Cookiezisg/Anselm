// FunctionEntity entity types — mirrors backend domain/function/*.go json tags,
// camelCase per API contract. Named FunctionEntity to avoid clash with JS built-in.
//
// 对齐后端 domain/function json tag 字段名(camelCase)；用 FunctionEntity 避开 JS 内置 Function。

export type EnvStatus = "pending" | "syncing" | "ready" | "failed" | "evicted";
export type VersionStatus = "pending" | "accepted" | "rejected";

export interface ParameterSpec {
  name: string;
  type: "string" | "number" | "integer" | "boolean" | "object" | "array";
  description?: string;
  required: boolean;
  default?: unknown;
  enum?: unknown[];
}

export interface FunctionVersion {
  id: string;
  functionId: string;
  status: VersionStatus;
  version?: number;
  code: string;
  parameters: ParameterSpec[];
  returnSchema: Record<string, unknown>;
  dependencies: string[];
  pythonVersion: string;
  envId: string;
  envStatus: EnvStatus;
  envError: string;
  envSyncedAt?: string;
  envSyncStage: string;
  envSyncDetail: string;
  changeReason: string;
  forgedInConversationId?: string;
  createdAt: string;
  updatedAt: string;
}

export interface FunctionEntity {
  id: string;
  userId: string;
  name: string;
  description: string;
  tags: string[];
  activeVersionId: string;
  createdAt: string;
  updatedAt: string;
  // Computed fields (filled server-side, omitempty)
  pending?: FunctionVersion;
  envStatus?: EnvStatus;
  envError?: string;
  envSyncedAt?: string;
  envSyncStage?: string;
  envSyncDetail?: string;
}

export interface RunFunctionVars {
  id: string;
  inputs: Record<string, unknown>;
}

export interface RunFunctionResult {
  output: unknown;
  elapsedMs: number;
}
