// errorMap — code → user-facing text table, aligned with backend errmap.go.
// Only the table lives here; wiring to TanStack global onError is deferred
// to a later phase.
//
// 错误码 → 用户文案表，对位后端 errmap.go。本文件只建表，不接 TanStack。

const ERROR_MESSAGES: Record<string, string> = {
  // Auth
  UNAUTH_NO_USER: "未找到用户，请重新选择账号",

  // Conversations
  CONVERSATION_NOT_FOUND: "对话不存在或已删除",

  // Network / HTTP
  NETWORK: "网络错误，请检查连接",
};

const FALLBACK = "操作失败，请稍后重试";

export function errorText(code: string): string {
  return ERROR_MESSAGES[code] ?? FALLBACK;
}
