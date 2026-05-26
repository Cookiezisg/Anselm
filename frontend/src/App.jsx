// Root component — boot-state machine (onboarding/booting/ready), theme
// propagation, SSE bootstrap, AppShell.
//
// 根组件 —— 启动状态机；theme dataset 同步;挂 SSE;渲染 AppShell。

import { useEffect, useRef, useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { AppShell } from "./components/layout/AppShell.jsx";
import { Onboarding } from "./components/overlays/Onboarding.jsx";
import { SSEProvider } from "./sse/SSEProvider.jsx";
import { useSettings } from "./store/settings.js";
import { useSettingsStore, applyTheme } from "@entities/settings";
import i18n from "@shared/lib/i18n";
import { computeBootState } from "./store/boot.js";
import { useChatStore } from "./store/chat.js";
import { usePaneStore } from "@app/model";
import { apiFetch, qk, pickList } from "./api/client.js";

// Honor `?onboarding=1` for tests / manual reruns. Production never sets it.
function urlForceOnboarding() {
  if (typeof window === "undefined") return false;
  try { return new URLSearchParams(window.location.search).get("onboarding") === "1"; }
  catch { return false; }
}

export default function App() {
  const session = useSettings();
  const prefs = useSettingsStore();
  const qc = useQueryClient();
  const prevUid = useRef(session.activeUserId);
  const [forceOnboarding, setForceOnboarding] = useState(urlForceOnboarding);
  const [onboardingActive, setOnboardingActive] = useState(false);

  useEffect(() => {
    applyTheme(prefs);
  }, [prefs.theme, prefs.accent, prefs.density, prefs.lang]);

  useEffect(() => {
    i18n.changeLanguage(prefs.lang);
  }, [prefs.lang]);

  // Account switch / first-account-set: drop old user's chat tree, invalidate
  // every REST cache, clear cross-user pane state (stale activeConv would 404
  // on send). Fires when activeUserId changes (incl. set during onboarding).
  //
  // 切账号:清 chat store + 失效所有 query + 清 cross-user 残留 pane 状态。
  useEffect(() => {
    if (prevUid.current === session.activeUserId) return;
    prevUid.current = session.activeUserId;
    useChatStore.getState().resetAll();
    const pane = usePaneStore.getState();
    pane.setActiveConv(null);
    pane.setActiveFlowRun(null);
    pane.setActiveDocument(null);
    qc.invalidateQueries();
  }, [session.activeUserId, qc]);

  useEffect(() => {
    if (prefs.theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const fn = () => applyTheme(prefs);
    mql.addEventListener?.("change", fn);
    return () => mql.removeEventListener?.("change", fn);
  }, [prefs.theme]);

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
    const activeId = session.activeUserId;
    if (activeId && !users.find((u) => u.id === activeId)) {
      session.set({ activeUserId: null });
      return;
    }
    if (!activeId && users.length >= 1) {
      session.set({ activeUserId: users[0].id });
    }
  }, [usersQ.isLoading, usersQ.isError, users, session.activeUserId]);

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
    activeUserId: session.activeUserId,
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
