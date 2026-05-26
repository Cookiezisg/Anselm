// errorMap — backend error code → i18n key table, aligned with errmap.go.
// Caller is responsible for calling t(errorText(code)) with the "errors" namespace.
//
// 错误码 → i18n key 映射表；调用方负责用 t(errorText(code)) 翻译成用户文案。

const CODE_TO_KEY: Record<string, string> = {
  // Auth
  UNAUTH_NO_USER: "errors:UNAUTH_NO_USER",

  // Conversations
  CONVERSATION_NOT_FOUND: "errors:CONVERSATION_NOT_FOUND",

  // Chat / LLM
  STREAM_IN_PROGRESS: "errors:STREAM_IN_PROGRESS",
  LLM_PROVIDER_ERROR: "errors:LLM_PROVIDER_ERROR",
  LLM_AUTH_FAILED: "errors:LLM_AUTH_FAILED",
  LLM_RATE_LIMITED: "errors:LLM_RATE_LIMITED",
  LLM_BAD_REQUEST: "errors:LLM_BAD_REQUEST",
  LLM_MODEL_NOT_FOUND: "errors:LLM_MODEL_NOT_FOUND",

  // Model / API key
  MODEL_NOT_CONFIGURED: "errors:MODEL_NOT_CONFIGURED",
  API_KEY_NOT_FOUND: "errors:API_KEY_NOT_FOUND",
  API_KEY_PROVIDER_NOT_FOUND: "errors:API_KEY_PROVIDER_NOT_FOUND",

  // Function / Handler / Workflow
  FUNCTION_NOT_FOUND: "errors:FUNCTION_NOT_FOUND",
  FUNCTION_RUN_FAILED: "errors:FUNCTION_RUN_FAILED",
  HANDLER_NOT_FOUND: "errors:HANDLER_NOT_FOUND",
  WORKFLOW_NOT_FOUND: "errors:WORKFLOW_NOT_FOUND",

  // Internal
  INTERNAL_ERROR: "errors:INTERNAL_ERROR",

  // Network / HTTP (client-side)
  NETWORK: "errors:NETWORK",
};

const FALLBACK_KEY = "errors:fallback";

// Returns the i18n key for the given error code. Caller calls t(key).
//
// 返回对应 code 的 i18n key；调用方用 t() 翻译。
export function errorKey(code: string): string {
  return CODE_TO_KEY[code] ?? FALLBACK_KEY;
}

// kindForCode — CONVERSATION_NOT_FOUND warrants a warn (not error) to match
// the original self-heal UX. All other codes default to "error".
//
// CONVERSATION_NOT_FOUND 用 warn 种类（与原自愈 UX 一致）；其余默认 error。
export function kindForCode(code: string): "error" | "warn" {
  if (code === "CONVERSATION_NOT_FOUND") return "warn";
  return "error";
}
