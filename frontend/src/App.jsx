// Root component — boot-state machine (onboarding/booting/ready), theme
// propagation, SSE bootstrap, AppShell.
//
// 根组件 —— 启动状态机；theme dataset 同步;挂 SSE;渲染 AppShell。

import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AppShell } from "./components/layout/AppShell.jsx";
import { Onboarding } from "./components/overlays/Onboarding.jsx";
import { SSEProvider } from "./sse/SSEProvider.jsx";
import { useSettings, applyTheme } from "./store/settings.js";
import i18n from "./i18n";
import { computeBootState } from "./store/boot.js";
import { useChatStore } from "./store/chat.js";
import { useUIStore } from "./store/ui.js";
import { apiFetch, qk, pickList } from "./api/client.js";

// Honor `?onboarding=1` for tests / manual reruns. Production never sets it.
function urlForceOnboarding() {
  if (typeof window === "undefined") return false;
  try { return new URLSearchParams(window.location.search).get("onboarding") === "1"; }
  catch { return false; }
}

export default function App() {
  const settings = useSettings();
  const qc = useQueryClient();
  const prevUid = useRef(settings.activeUserId);
  const [forceOnboarding, setForceOnboarding] = useState(urlForceOnboarding);
  const [onboardingActive, setOnboardingActive] = useState(false);

  useEffect(() => {
    applyTheme(settings);
  }, [settings.theme, settings.accent, settings.density, settings.lang]);

  useEffect(() => {
    i18n.changeLanguage(settings.lang);
  }, [settings.lang]);

  // Account switch / first-account-set: drop old user's chat tree, invalidate
  // every REST cache, clear cross-user pane state (stale activeConv would 404
  // on send). Fires when activeUserId changes (incl. set during onboarding).
  //
  // 切账号:清 chat store + 失效所有 query + 清 cross-user 残留 pane 状态。
  useEffect(() => {
    if (prevUid.current === settings.activeUserId) return;
    prevUid.current = settings.activeUserId;
    useChatStore.getState().resetAll();
    const ui = useUIStore.getState();
    ui.setActiveConv?.(null);
    if (ui.setActiveFlowRun) ui.setActiveFlowRun(null);
    if (ui.setActiveDocument) ui.setActiveDocument(null);
    qc.invalidateQueries();
  }, [settings.activeUserId, qc]);

  useEffect(() => {
    if (settings.theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const fn = () => applyTheme(settings);
    mql.addEventListener?.("change", fn);
    return () => mql.removeEventListener?.("change", fn);
  }, [settings.theme]);

  // /users drives fresh-install detection AND activeUserId self-heal.
  const usersQ = useQuery({
    queryKey: qk.users(),
    queryFn: () => apiFetch("/users"),
    select: pickList,
  });
  const users = usersQ.data || [];

  // Self-heal: stale activeUserId (points at a deleted user) → clear; no
  // active id but users exist → select the first. Runs every render until it
  // converges; the boot state holds AppShell back until it does.
  //
  // 自愈:脏 id 清掉;无 id 且有 user 选第一个。收敛前 boot state 不放行 AppShell。
  useEffect(() => {
    if (usersQ.isLoading || usersQ.isError) return;
    const activeId = settings.activeUserId;
    if (activeId && !users.find((u) => u.id === activeId)) {
      settings.set({ activeUserId: null });
      return;
    }
    if (!activeId && users.length >= 1) {
      settings.set({ activeUserId: users[0].id });
    }
  }, [usersQ.isLoading, usersQ.isError, users, settings.activeUserId]);

  // Latch: once there's a reason to onboard (fresh install or ?onboarding=1),
  // stay in onboarding until the wizard calls onFinish — even though creating
  // the workspace mid-wizard makes users.length>0 (which would otherwise flip
  // us out and unmount the half-finished wizard).
  //
  // latch:一旦该引导(fresh install 或 ?onboarding=1)就锁住,直到 onFinish。
  // 否则向导中途建了 user → users>0 → 被卸载。
  const wantOnboarding =
    forceOnboarding || (!usersQ.isLoading && !usersQ.isError && users.length === 0);
  useEffect(() => {
    if (!onboardingActive && wantOnboarding) setOnboardingActive(true);
  }, [onboardingActive, wantOnboarding]);

  const boot = computeBootState({
    onboardingActive,
    usersLoading: usersQ.isLoading,
    usersError: usersQ.isError,
    users,
    activeUserId: settings.activeUserId,
  });

  const finishOnboarding = () => {
    setForceOnboarding(false);
    setOnboardingActive(false);
  };

  if (boot === "onboarding") {
    return (
      <SSEProvider>
        <Onboarding onFinish={finishOnboarding} />
      </SSEProvider>
    );
  }
  if (boot === "booting") {
    return <SSEProvider><div className="app-booting" /></SSEProvider>;
  }
  return (
    <SSEProvider>
      <AppShell />
    </SSEProvider>
  );
}
