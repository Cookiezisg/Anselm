// ApiKey entity types — mirrors backend domain/apikey/apikey.go fields,
// camelCase per API response contract (json tags on the Go struct).
//
// 对齐后端 domain/apikey APIKey struct 的 json tag 字段名(camelCase)。

export interface ApiKey {
  id: string;
  userId: string;
  provider: string;
  displayName: string;
  keyMasked: string;
  baseUrl: string;
  apiFormat: string;
  testStatus: "pending" | "ok" | "error";
  testError: string;
  lastTestedAt: string | null;
  modelsFound: string[];
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CreateApiKeyBody {
  provider: string;
  displayName: string;
  key: string;
  baseUrl?: string;
  apiFormat?: string;
}

export interface UpdateApiKeyPatch {
  displayName?: string;
  baseUrl?: string;
  key?: string;
  isDefault?: boolean;
}

export interface TestApiKeyResult {
  ok: boolean;
  message: string;
  latencyMs: number;
  modelsFound: string[];
}
