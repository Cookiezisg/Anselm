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
import { useUIStore } from "./store/ui.js";
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

  // Account switch / first-account-set: drop the old user's chat tree,
  // invalidate every REST cache, AND clear any cross-user pane state
  // (activeConv / focusEntity) that would otherwise point at a stale
  // entity that doesn't belong to the new user — backend would return
  // CONVERSATION_NOT_FOUND on send, surfaced as "发送失败" toast.
  //
  // 切账号:清 chat store + 失效所有 query 缓存 + 清掉 cross-user 残留的
  // activeConv / focusEntity(否则 backend 找不到那条 conv → 发送失败)。
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
  // it. Then auto-select the first user whenever any exist — local-first is
  // single-user, so a null/stale id (e.g. DB rebuilt, localStorage wiped, or
  // 401 UNAUTH_NO_USER cleared the id) must resolve to SOME real user, not
  // dead-end. Without `>= 1`, a 2+ user DB with no active id rendered the
  // shell with no valid identity → every user-scoped call 401'd.
  //
  // 自愈：activeUserId 指向已删除 user 就清掉；只要 DB 有用户就选第一个。
  // 本地单用户，空/失效 id 必须落到某个真实 user(否则多用户+空 id 时
  // shell 带着无效身份渲染 → 所有 user 作用域请求 401)。
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

  // Fresh install: zero users in DB → onboard. Pre-loaded data → don't flash
  // onboarding while /users is still resolving on first render.
  //
  // Fresh install：DB 0 user 走 onboarding；usersQ 还没出结果时不闪烁。
  const isFreshInstall = !usersQ.isLoading && users.length === 0;
  const showOnboarding = forceShowOnboarding || isFreshInstall;

  // Hold the shell until a user is resolved: while /users loads, or for the
  // one render between "users arrived" and the self-heal effect setting
  // activeUserId. Rendering AppShell with a null id makes child hooks fire
  // user-scoped requests that 401 (and flash "发送失败"-style toasts).
  //
  // 在拿到有效 user 前不渲染 shell:/users 加载中,或"用户已到达但自愈
  // effect 还没设 activeUserId"的那一拍。否则子 hook 带空 id 发请求 401。
  const resolvingUser =
    !showOnboarding && (usersQ.isLoading || (users.length >= 1 && !settings.activeUserId));

  if (showOnboarding) {
    return (
      <SSEProvider>
        <Onboarding onFinish={() => setForceShowOnboarding(false)} />
      </SSEProvider>
    );
  }

  if (resolvingUser) {
    return <SSEProvider><div className="app-booting" /></SSEProvider>;
  }

  return (
    <SSEProvider>
      <AppShell />
    </SSEProvider>
  );
}
