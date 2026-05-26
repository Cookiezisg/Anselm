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
    setOnAuthFailure(() => { void resolveSession().catch(() => {}); });
    // Resolve on boot. If /users fetch fails (Wails cold-start race: frontend
    // mounts before the backend port is ready) retry with backoff so status
    // never gets stuck at "loading" forever. Replaces the old useQuery retry.
    //
    // 启动解析身份;/users 失败(Wails 冷启动竞态)时退避重试,避免 status 卡死在 loading。
    let cancelled = false;
    let attempt = 0;
    const run = () => {
      void resolveSession().catch(() => {
        if (cancelled) return;
        attempt += 1;
        setTimeout(() => { if (!cancelled) run(); }, Math.min(1000 * attempt, 5000));
      });
    };
    run();
    return () => { cancelled = true; };
  }, []);
  return useSessionStore((s) => s.status);
}
