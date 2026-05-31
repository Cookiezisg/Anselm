# app/App — 前端 slice 详细设计

**所属层**：app（根组件；消费 app/model/useSessionBootstrap + entities/session + entities/settings + app/sse/SSEProvider）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：启动状态机 + 主题/语言传播 + SSE 挂载 + 账号切换清理。根据 `useSessionBootstrap()` 返回的状态决定渲染哪个子树。

---

## 1. 启动状态机

```
useSessionBootstrap() 返回:
  "loading"      → <SSEProvider><div class="app-booting" /></SSEProvider>
  "onboarding"   → <SSEProvider><Onboarding /></SSEProvider>
  "ready"        → <SSEProvider><AppShell /></SSEProvider>
```

SSEProvider 始终包裹所有状态（包括 onboarding），确保 SSE 在用户完成 onboarding 后不需要重新建立连接。

---

## 2. 主题/语言 effects

```ts
// 主题应用
useEffect(() => { applyTheme(prefs); }, [prefs.theme, prefs.accent, prefs.density, prefs.lang]);

// i18n 切换
useEffect(() => { i18n.changeLanguage(prefs.lang); }, [prefs.lang]);

// system 主题跟随 OS
useEffect(() => {
  if (prefs.theme !== "system") return;
  const mql = window.matchMedia("(prefers-color-scheme: dark)");
  mql.addEventListener("change", () => applyTheme(prefs));
  ...
}, [prefs.theme]);
```

`applyTheme` 设置 `document.documentElement.dataset.theme` + `--accent` CSS 变量等。

---

## 3. 账号切换清理

```ts
const currentUserId = useSessionStore((s) => s.currentUserId);
useEffect(() => {
  if (prevUid.current === currentUserId) return;
  prevUid.current = currentUserId;
  useChatStore.getState().resetAll();       // 清旧用户消息树
  pane.setActiveConv(null);
  pane.setActiveFlowRun(null);
  pane.setActiveDocument(null);
  qc.invalidateQueries();                  // 所有 cache 失效
}, [currentUserId, qc]);
```

保证 onboarding 切换到新账号后，旧用户的 chatStore / pane 残留不污染新会话。

---

## 4. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/app/App.tsx` | 根组件：boot 状态机 + theme/i18n effects + 账号切换清理 |
| `frontend/src/app/main.tsx` | Vite 入口：QueryClient 配置 + I18nextProvider + strict mode + render |
