// Root component — first-run detection (Onboarding), theme propagation,
// SSE bootstrap, AppShell.
//
// 根组件 —— 首次启动 Onboarding；theme dataset 同步；挂 SSE；渲染 AppShell。

import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AppShell } from "./components/layout/AppShell.jsx";
import { Onboarding } from "./components/overlays/Onboarding.jsx";
import { SSEProvider } from "./sse/SSEProvider.jsx";
import { useSettings, applyTheme } from "./store/settings.js";
import { useChatStore } from "./store/chat.js";
import { apiFetch, qk, pickList } from "./api/client.js";

// Honor `?onboarding=1` query param for tests / manual reruns of the
// first-run flow. Production never sets this.
//
// `?onboarding=1` 强制显示向导（给测试 / 手工重跑首次启动用）。
function urlForceOnboarding() {
  if (typeof window === "undefined") return false;
  try { return new URLSearchParams(window.location.search).get("onboarding") === "1"; }
  catch { return false; }
}

export default function App() {
  const settings = useSettings();
  const qc = useQueryClient();
  const prevUid = useRef(settings.activeUserId);
  const [forceShowOnboarding, setForceShowOnboarding] = useState(urlForceOnboarding);

  useEffect(() => {
    applyTheme(settings);
  }, [settings.theme, settings.accent, settings.density, settings.lang]);

  // Account switch / first-account-set: drop the old user's chat tree and
  // invalidate every REST cache so the next render fetches fresh data
  // under the new X-Forgify-User-ID. SSE hooks reconnect on the same
  // activeUserId dep; this complements them on the REST side.
  //
  // 切账号 / 首次绑 user：清 chat store + 失效所有 query 缓存。SSE hook
  // 同时按 activeUserId 重连。
  useEffect(() => {
    if (prevUid.current === settings.activeUserId) return;
    prevUid.current = settings.activeUserId;
    useChatStore.getState().resetAll();
    qc.invalidateQueries();
  }, [settings.activeUserId, qc]);

  useEffect(() => {
    if (settings.theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const fn = () => applyTheme(settings);
    mql.addEventListener?.("change", fn);
    return () => mql.removeEventListener?.("change", fn);
  }, [settings.theme]);

  // First-run detection — show Onboarding when settings.onboarded is
  // false AND the only user in the backend is the auto-created default.
  // (Backend always seeds a local-user on first boot, so 1 user with
  // username==="default" === fresh install.)
  //
  // 首次启动检测：onboarded=false 且后端只有自动建的 default user → 显示。
  const usersQ = useQuery({
    queryKey: qk.users(),
    queryFn: () => apiFetch("/users"),
    select: pickList,
  });
  const users = usersQ.data || [];
  const isFreshInstall = !settings.onboarded
    && users.length <= 1
    && (users[0]?.username === "default" || !users[0]);
  const showOnboarding = forceShowOnboarding || (isFreshInstall && !usersQ.isLoading);

  if (showOnboarding) {
    return (
      <SSEProvider>
        <Onboarding onFinish={() => setForceShowOnboarding(false)} />
      </SSEProvider>
    );
  }

  return (
    <SSEProvider>
      <AppShell />
    </SSEProvider>
  );
}
