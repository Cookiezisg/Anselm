// ModelConfig entity types — mirrors backend domain/model/model.go fields,
// camelCase per API response contract (json tags on the Go struct).
//
// 对齐后端 domain/model ModelConfig struct 的 json tag 字段名(camelCase)。

// Scenario is the closed 3-set whitelist of LLM-using scenarios. provider is
// implicit via the api_key referenced by apiKeyId.
//
// 关闭 3-set scenario 白名单;provider 由 apiKeyId 引用的 api_key 隐含。
export type Scenario = "dialogue" | "utility" | "agent";

export interface ModelConfig {
  id: string;
  scenario: Scenario;
  apiKeyId: string;
  modelId: string;
  createdAt: string;
  updatedAt: string;
}

// Provider entry from GET /api/v1/providers — static whitelist from the
// apikey registry; used by model-config UI to populate provider dropdowns.
//
// GET /api/v1/providers 返回的 provider 白名单条目;用于 model-config UI 的下拉。
export interface Provider {
  name: string;
  displayName: string;
  category: string;
  defaultBaseUrl?: string;
  baseUrlRequired: boolean;
}

// ScenarioEntry — entry from GET /api/v1/scenarios (backend authoritative).
//
// GET /api/v1/scenarios 返回的后端权威 scenario 白名单条目。
export interface ScenarioEntry {
  name: Scenario;
}

export interface UpsertModelConfigBody {
  apiKeyId: string;
  modelId: string;
}
