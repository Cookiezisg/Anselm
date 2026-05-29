// ModelConfig entity types — mirrors backend domain/model/model.go fields,
// camelCase per API response contract (json tags on the Go struct).
//
// 对齐后端 domain/model ModelConfig struct 的 json tag 字段名(camelCase)。

// Scenario is the closed 3-set whitelist of LLM-using scenarios. provider is
// implicit via the api_key referenced by apiKeyId.
//
// 关闭 3-set scenario 白名单;provider 由 apiKeyId 引用的 api_key 隐含。
export type Scenario = "dialogue" | "utility" | "agent";

// ThinkingSpec — flat thinking config mirroring backend domain/model ThinkingSpec.
// mode drives which field is active: "auto"/"off" use neither; "on" with effort
// string or budget integer depending on provider support.
//
// 对齐后端 ThinkingSpec；mode 决定激活字段：effort 是字符串等级，budget 是整数 token 上限。
export interface ThinkingSpec {
  mode: "auto" | "off" | "on";
  effort?: string;
  budget?: number;
}

// ThinkingShape — how a model exposes thinking control. "none" = no thinking
// support; "toggle" = on/off only; "effort" = effort-level string; "budget" = token budget.
//
// 模型的 thinking 控制形态：none/toggle/effort/budget 四种。
export type ThinkingShape = "none" | "effort" | "budget" | "toggle";

// ModelCapability — one item from GET /model-capabilities, camelCase.
// Represents backend-computed + user-overridable capability row per (provider, modelId).
//
// GET /model-capabilities 返回的单条能力描述；含可覆盖字段和 thinking 形态。
export interface ModelCapability {
  provider: string;
  modelId: string;
  thinkingShape: ThinkingShape;
  effortValues: string[];
  budgetMin: number;
  budgetMax: number;
  contextWindow: number;
  maxOutput: number;
  contextMode: string;
}

// CapabilityOverrideBody — PUT /model-capabilities/:provider/:modelId body.
// Fields absent = keep current value.
//
// PUT body；缺省字段保持不变。
export interface CapabilityOverrideBody {
  thinkingShape?: ThinkingShape;
  contextWindow?: number;
  maxOutput?: number;
}

export interface ModelConfig {
  id: string;
  scenario: Scenario;
  apiKeyId: string;
  modelId: string;
  thinking?: ThinkingSpec;
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

export interface UpsertModelConfigBody {
  apiKeyId: string;
  modelId: string;
  thinking?: ThinkingSpec;
}
