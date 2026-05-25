// Boot-state machine + device-language detection. Pure, no heavy imports,
// so the readiness logic is unit-testable without rendering the app.
//
// 启动状态机 + 设备语言探测；纯函数,可独立单测,不渲染整个 app。

// computeBootState — single source of truth for "what do we render at the
// root". `ready` REQUIRES activeUserId to actually exist in `users`; a stale
// (non-null but unknown) id is NOT ready — that was the 401-flood root cause.
//
// 根渲染状态唯一裁决处。ready 必须 activeUserId 确在 users 里;脏 id(非空但
// 不在列表)不算 ready —— 那正是 401 洪水的根因。
export function computeBootState({ onboardingActive, usersLoading, usersError, users, activeUserId }) {
  if (onboardingActive) return "onboarding";
  if (usersLoading) return "booting";
  if (!usersError && users.length === 0) return "onboarding";
  const valid = !!activeUserId && users.some((u) => u.id === activeUserId);
  return valid ? "ready" : "booting";
}

// detectLang — first-run language from the device. zh* → zh, else en.
// Only consulted when settings has no persisted lang (see settings DEFAULTS).
export function detectLang() {
  if (typeof navigator === "undefined") return "zh";
  const l = (navigator.language || navigator.userLanguage || "").toLowerCase();
  return l.startsWith("zh") ? "zh" : "en";
}
