// Handler entity types — mirrors backend domain/handler/*.go json tags,
// camelCase per API contract.
//
// 对齐后端 domain/handler json tag 字段名（camelCase）。

export type EnvStatus = "pending" | "syncing" | "ready" | "failed" | "evicted";
export type VersionStatus = "pending" | "accepted" | "rejected";
export type ConfigState = "unconfigured" | "partially_configured" | "ready";

export interface ArgSpec {
  name: string;
  type: string;
  description?: string;
  required: boolean;
  default?: unknown;
}

export interface InitArgSpec {
  name: string;
  type: string;
  description?: string;
  required: boolean;
  sensitive: boolean;
  default?: unknown;
}

export interface MethodSpec {
  name: string;
  description?: string;
  args: ArgSpec[];
  returnSchema?: Record<string, unknown>;
  body: string;
  streaming: boolean;
  timeout?: number;
}

export interface HandlerVersion {
  id: string;
  handlerId: string;
  status: VersionStatus;
  version?: number;
  imports: string;
  initBody: string;
  shutdownBody: string;
  methods: MethodSpec[];
  initArgsSchema: InitArgSpec[];
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

export interface Handler {
  id: string;
  userId: string;
  name: string;
  description: string;
  tags: string[];
  activeVersionId: string;
  createdAt: string;
  updatedAt: string;
  // Computed fields (filled server-side, omitempty)
  pending?: HandlerVersion;
  envStatus?: EnvStatus;
  envError?: string;
  envSyncedAt?: string;
  envSyncStage?: string;
  envSyncDetail?: string;
  configState?: ConfigState;
  liveInstances?: number;
}

export interface HandlerConfig {
  configState: ConfigState;
  config: Record<string, unknown> | null;
}

export interface CallHandlerVars {
  id: string;
  method: string;
  args: Record<string, unknown>;
}

export interface CallHandlerResult {
  result: unknown;
}
