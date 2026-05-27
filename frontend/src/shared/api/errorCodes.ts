// Source-of-truth for backend error codes. Used by errorMap.ts (frontend
// i18n mapping) and shared cross-app (testend V3 imports for raw display).
//
// 错误码事实源。frontend 经 errorMap 翻 i18n；testend 直接读 code 展示。

export const ERROR_CODES = {
  // Auth
  UNAUTH_NO_USER: "UNAUTH_NO_USER",

  // Conversations
  CONVERSATION_NOT_FOUND: "CONVERSATION_NOT_FOUND",

  // Chat / LLM
  STREAM_IN_PROGRESS: "STREAM_IN_PROGRESS",
  LLM_PROVIDER_ERROR: "LLM_PROVIDER_ERROR",
  LLM_AUTH_FAILED: "LLM_AUTH_FAILED",
  LLM_RATE_LIMITED: "LLM_RATE_LIMITED",
  LLM_BAD_REQUEST: "LLM_BAD_REQUEST",
  LLM_MODEL_NOT_FOUND: "LLM_MODEL_NOT_FOUND",

  // Model / API key
  MODEL_NOT_CONFIGURED: "MODEL_NOT_CONFIGURED",
  API_KEY_NOT_FOUND: "API_KEY_NOT_FOUND",
  API_KEY_PROVIDER_NOT_FOUND: "API_KEY_PROVIDER_NOT_FOUND",

  // Function / Handler / Workflow
  FUNCTION_NOT_FOUND: "FUNCTION_NOT_FOUND",
  FUNCTION_RUN_FAILED: "FUNCTION_RUN_FAILED",
  HANDLER_NOT_FOUND: "HANDLER_NOT_FOUND",
  WORKFLOW_NOT_FOUND: "WORKFLOW_NOT_FOUND",

  // Internal
  INTERNAL_ERROR: "INTERNAL_ERROR",

  // Network / HTTP (client-side synth)
  NETWORK: "NETWORK",
} as const;

export type ErrorCode = keyof typeof ERROR_CODES;
