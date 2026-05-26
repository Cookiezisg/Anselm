// Wires session store into the shared/api DIP slots on mount.
// Called once at app root; subsequent renders are no-ops.
//
// 启动时把 session store 注入 shared/api 的 DIP 注册点，覆盖 4a.2 的空默认值。
// 同时把 auth failure 重定向到 resolveSession，确保 401 后自动刷新身份。

import { useEffect } from "react";
import { useSessionStore, resolveSession } from "@entities/session";
import { setUserIdProvider, setOnAuthFailure } from "@shared/api/authProvider";

export function useSessionBootstrap(): "loading" | "onboarding" | "ready" {
  useEffect(() => {
    setUserIdProvider(() => useSessionStore.getState().currentUserId);
    setOnAuthFailure(() => { void resolveSession(); });
    void resolveSession();
  }, []);
  return useSessionStore((s) => s.status);
}
