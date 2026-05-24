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

  // /users drives both fresh-install detection AND activeUserId self-heal.
  // Backend no longer auto-seeds local-user, so users.length===0 means
  // genuine fresh install (no username sniffing).
  //
  // /users 同时驱动 fresh-install 检测和 activeUserId 自愈。后端不再
  // 自动 seed local-user，users.length===0 就是真的 fresh install。
  const usersQ = useQuery({
    queryKey: qk.users(),
    queryFn: () => apiFetch("/users"),
    select: pickList,
  });
  const users = usersQ.data || [];

  // Self-heal: if activeUserId points at a user that no longer exists, clear
  // it. Then auto-select when exactly one user remains — single-user installs
  // should not be forced into a picker after a localStorage wipe.
  //
  // 自愈：activeUserId 指向已删除的 user 就清掉；只剩 1 个用户时直接选上，
  // 避免单用户 install 在 localStorage 被清后还要走 picker。
  useEffect(() => {
    if (usersQ.isLoading || usersQ.isError) return;
    const activeId = settings.activeUserId;
    if (activeId && !users.find((u) => u.id === activeId)) {
      settings.set({ activeUserId: null });
      return;
    }
    if (!activeId && users.length === 1) {
      settings.set({ activeUserId: users[0].id });
    }
  }, [usersQ.isLoading, usersQ.isError, users, settings.activeUserId]);

  // Fresh install: zero users in DB → onboard. Pre-loaded data → don't flash
  // onboarding while /users is still resolving on first render.
  //
  // Fresh install：DB 0 user 走 onboarding；usersQ 还没出结果时不闪烁。
  const isFreshInstall = !usersQ.isLoading && users.length === 0;
  const showOnboarding = forceShowOnboarding || isFreshInstall;

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
