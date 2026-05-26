# 前端 Revamp 阶段 4a:身份层 + 横切收口(最规范 FSD) 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 逐 task 执行。步骤用 `- [ ]` 勾选。

**Goal:** 落地最规范身份层(`entities/session` + 依赖倒置注入)**根治原 401 风暴 bug**;横切关注点全部收口到规范层(toast→shared/ui + 全局 onError、偏好→entities/settings、UI 编排→app/model);**解掉阶段 0-3 累积的全部 ~22 处 `TODO(阶段4)` 越界债**。除 bug 修复外**行为/UI 零改动**(vitest 全绿 + make dev 复现验证)。

**Architecture(见 spec D6 + §8,最规范、零反向依赖):**
- 身份 = `entities/session`(currentUserId/status + resolve);**不在 app/model**(否则 shared/entities 反向)。
- `httpClient`/`sse` 注入 userId 用 **DIP 注册点**(`setUserIdProvider`/`onAuthFailure`),app 启动注入 —— = 后端 domain 定 port、main.go wire。
- toast:`shared/ui` 队列 + app 全局 `onError` + `errorMap`;feature 抛 `ApiError`,**不直接 pushToast**。
- enabled gate:**去掉**(entity 纯净);boot gate 在 app/page 级(status≠ready 不挂载 → query 不发)。
- 导航:feature 返回意图,组件执行;feature 不碰 pane。
- 偏好 → `entities/settings`;UI 编排(pane/overlay/sidebar)→ `app/model`(只 AppShell 读,pages 收 props,本 plan 不迁组件——组件迁目录是 4b)。

**Tech Stack:** TypeScript、zustand(+persist)、TanStack Query、react-i18next、vitest、steiger、eslint-plugin-boundaries。

> **范围**:本 plan(4a)只做**逻辑层**(store/身份/SSE/错误/解债),**组件留原位不迁目录**(迁 pages/widgets/features-ui 是 4b)。旧 `store/*` 拆走后留 re-export shim,组件零改;组件 import 路径更新到新 store 位置留 4b。

---

## 通用纪律(每个 task 都遵守)

- 独占 main,**严禁开新分支**;**精确 git add**(只本 task 产物,严禁 `git add -A`——工作树有 probe 探针 + backend audit 残留);commit 前 `git status` 核对;**绝不碰 backend/**;commit 中文无 AI attribution;commit 后 `git push`;撞 `index.lock` 先 `ps aux | grep "[g]it"` + 看 mtime 确认孤儿才 `rm -f`,绝不盲删。
- 命令在 `frontend/` 内跑(除非注明仓库根)。
- **每 task 末 vitest 不得减少**(当前基线以实际 `npx vitest run` 为准,约 752+);tsc 0;eslint 对改动文件 0 error;steiger 干净。

## 实现顺序(依赖图)

```
4a.1 entities/session(骨架+resolve+单测,独立建)
  ↓
4a.2 shared/api DIP 注册点(默认 provider 读旧 settings,行为不变)
4a.3 shared/ui toastStore(toast 下沉)        ← 可与 4a.2 并行思路,串行执行
4a.4 entities/settings(偏好迁移)
  ↓
4a.5 app 层骨架 + useSessionBootstrap(注入 session 到 provider + 拆 store/ui→app/model)
  ↓
4a.6 App.jsx 接入 session(boot=status,删 boot.js + 2 自愈 effect,provider 切 session,删 settings.activeUserId)  ← bug 根治点
  ↓
4a.7 去 entity enabled gate(解 6 entity→settings 债)
4a.8 errorMap + 全局 onError(feature 抛 ApiError 不直接 toast,解 feature→toast 债)
4a.9 feature 导航返回意图(解 feature→pane 债)
4a.10 SSE 迁 app/sse(读注入 + 401→onAuthFailure)
  ↓
4a.11 收口(boundaries 全 error 解所有债 + steiger + make dev 复现 bug 根治验证)
```

---

## Task 4a.1:entities/session(身份实体 + resolve + 单测)

**Files:** Create `frontend/src/entities/session/{model/sessionStore.ts, model/resolve.ts, api/session.ts, model/resolve.test.ts, index.ts}`。

> 独立建,本 task 不接入任何现有代码(无人用)。下一步才注入/接管。

- [ ] **Step 1**:读 `frontend/src/store/settings.js`(看 activeUserId 现状)、`frontend/src/store/boot.js`(`computeBootState` 逻辑,resolve 要复刻其判定)、`frontend/src/entities/user/index.ts`(useUsers / User 类型)、`frontend/src/shared/api`(apiFetch/pickList)。
- [ ] **Step 2**:`model/sessionStore.ts` —— zustand+persist:
```ts
interface SessionState {
  currentUserId: string | null;          // persist
  status: 'loading' | 'onboarding' | 'ready';
  setCurrentUser(id: string | null): void;
  setStatus(s: SessionState['status']): void;
}
```
persist name `forgify-session`,只持久化 `currentUserId`。
- [ ] **Step 3**:`api/session.ts` —— `fetchUsers()`:`apiFetch("/users").then(pickList<User>)`(从 `@entities/user` 复用 User 类型;或 @x)。这是 resolve 用的 fresh 取数(不走缓存)。
- [ ] **Step 4**:`model/resolve.ts` —— `resolve()`:
```ts
// 复刻 boot.js computeBootState 的判定,但永远基于 fresh /users。
export async function resolveSession() {
  const s = useSessionStore.getState();
  s.setStatus('loading');
  const users = await fetchUsers();              // fresh
  if (users.length === 0) { s.setStatus('onboarding'); return; }
  const valid = s.currentUserId && users.some(u => u.id === s.currentUserId);
  if (!valid) s.setCurrentUser(users[0].id);     // stale/null → 选 users[0]
  s.setStatus('ready');
}
```
- [ ] **Step 5**:`model/resolve.test.ts`(**覆盖 bug 场景**):
  - `resolveSession_staleUserId_selectsFirstAndReady`:currentUserId="u_gone",fresh users=[u_real] → currentUserId 变 u_real + status ready(**不循环**)。
  - `resolveSession_emptyUsers_onboarding`。
  - `resolveSession_validUserId_keepsAndReady`。
  - `resolveSession_nullUserId_selectsFirst`。
  fake fetchUsers(mock `api/session`)。
- [ ] **Step 6**:`index.ts` barrel:export `useSessionStore`、`resolveSession`(+ 类型)。
- [ ] **Step 7**:验证门(tsc/vitest 含新单测/build/eslint src/entities/session/steiger)。commit `feat(frontend): entities/session 身份实体 + resolve(阶段4a)` + push。

---

## Task 4a.2:shared/api DIP 注册点(setUserIdProvider / onAuthFailure)

**Files:** Modify `frontend/src/shared/api/httpClient.ts` + `frontend/src/shared/api/sse.ts`。

> 加注册点,**默认 provider 暂时读 `store/settings.activeUserId`(保持现状,行为不变)**,onAuthFailure 默认 noop(暂留旧 401 清除逻辑直到 4a.6 切换)。这样注册点就位但本步零行为改动。

- [ ] **Step 1**:`httpClient.ts` 顶部加模块级注册点:
```ts
let _userIdProvider: () => string | null = () => null;
let _onAuthFailure: () => void = () => {};
export function setUserIdProvider(fn: () => string | null) { _userIdProvider = fn; }
export function setOnAuthFailure(fn: () => void) { _onAuthFailure = fn; }
```
- [ ] **Step 2**:`activeUserHeader()` 改为读 `_userIdProvider()`(而非直接读 settings)。**但本步**:在模块初始化时设默认 provider `setUserIdProvider(() => useSettings.getState().activeUserId)`(暂保现状,inline disable 暂留)——这样未注入时行为不变。401 段暂时**两者都做**:既调 `_onAuthFailure()`(默认 noop)又保留旧 `useSettings.set({activeUserId:null})`(4a.6 删旧)。
- [ ] **Step 3**:`sse.ts` 同理:userID query 参数读 `_userIdProvider()`(默认读 settings);401/断连自愈暂留 + 加 `_onAuthFailure()` 调用。
- [ ] **Step 4**:验证门。eslint:`setUserIdProvider` 等是新导出,确认无未用警告(steiger public-api:加到 `shared/api/index.ts` barrel)。commit `feat(frontend): shared/api 加 userId/authFailure DIP 注册点(默认读旧 settings,阶段4a)` + push。

---

## Task 4a.3:shared/ui toastStore(toast 下沉)

**Files:** Create `frontend/src/shared/ui/toastStore.ts`;Modify `frontend/src/store/ui.js`(toast 部分转 re-export)+ `frontend/src/shared/ui/index.ts`(barrel)。

- [ ] **Step 1**:读 `store/ui.js` 的 toast 部分(`toasts` 字段 + `pushToast`/`dismissToast`,约 L45/L139-150)。
- [ ] **Step 2**:`shared/ui/toastStore.ts` —— zustand:`toasts` + `pushToast(t)`(自动 id + 5000ms 自动清)+ `dismissToast(id)`。**逐字搬 store/ui 的 toast 逻辑**(自动清定时器、id 生成不变)。
- [ ] **Step 3**:`store/ui.js` 的 toast 字段/action 改为从 `@shared/ui` re-export(`useUIStore` 仍暴露 toasts/pushToast/dismissToast 给现有调用点,内部委托 toastStore;或让 store/ui 的 toast selector 代理 toastStore)。**保证现有 `useUIStore(s=>s.pushToast)` 调用点零改**(行为不变;真正改 import 留 4a.8/4b)。
- [ ] **Step 4**:`shared/ui/index.ts` export toastStore。验证门。commit `feat(frontend): toast 队列下沉 shared/ui/toastStore(阶段4a)` + push。

> 注:本步只是把 toast **状态**搬到 shared(让 widgets/onError 可读);feature 仍通过 store/ui shim 调 pushToast(行为不变)。feature 改抛 ApiError 走 onError 在 4a.8。

---

## Task 4a.4:entities/settings(偏好迁移)

**Files:** Create `frontend/src/entities/settings/{model/settingsStore.ts, index.ts}`;Modify `frontend/src/store/settings.js`(转 shim,activeUserId 暂留)。

- [ ] **Step 1**:读 `store/settings.js` 全部字段。**偏好**(theme/accent/density/lang/reasoningDefault/leftPct)迁 `entities/settings/model/settingsStore.ts`(zustand+persist,逐字搬默认值 + set/reset + applyTheme/detectLang 相关)。**`activeUserId`/`onboarded` 暂留 store/settings**(activeUserId 归 session 在 4a.6 接管;onboarded 4a.6 处理)。
- [ ] **Step 2**:`store/settings.js` 转**部分 shim**:偏好字段从 `@entities/settings` re-export(`useSettings` 仍暴露偏好给现有调用点,内部委托);activeUserId/onboarded 原地保留。保证现有调用点零改。
- [ ] **Step 3**:`index.ts` barrel。验证门。commit `feat(frontend): 用户偏好迁 entities/settings(阶段4a)` + push。

---

## Task 4a.5:app 层骨架 + useSessionBootstrap + 拆 store/ui 编排状态

**Files:** Create `frontend/src/app/{model/useSessionBootstrap.ts, model/paneStore.ts, model/overlayStore.ts, model/sidebarStore.ts, model/index.ts, index.ts}`;Modify `frontend/eslint.config.js`(注册 app element)、`frontend/src/store/ui.js`(pane/overlay/sidebar 转 re-export)、`frontend/steiger.config.js`(app insignificant 若需)。

- [ ] **Step 1**:读 `store/ui.js` 的 pane/overlay/sidebar 分组(调研:pane=openPanes/activeConv/activeFlowRun/activeDocument/leftPct/focusEntity/narrow/activeNarrowPane;overlay=cmdk/notifs/ask/settingsOpen/pendingAsk;sidebar=collapsed/tools/recent/archived expanded)。读 `eslint.config.js`(加 app element)。
- [ ] **Step 2**:`app/model/{paneStore,overlayStore,sidebarStore}.ts` —— 各 zustand,**逐字搬** store/ui 对应分组(localStorage 持久化逻辑、togglePane MAX_PANES=2、openEntity/consumeFocusEntity 一次性逻辑等全保留)。`baseUrl` 死字段丢弃(spec §15 顺带清死代码)。
- [ ] **Step 3**:`app/model/useSessionBootstrap.ts` —— app 启动 hook:
```ts
// 注入 session 到 shared/api 的 DIP 注册点 + 启动 resolve。
export function useSessionBootstrap() {
  useEffect(() => {
    setUserIdProvider(() => useSessionStore.getState().currentUserId);
    setOnAuthFailure(() => { resolveSession(); });
    resolveSession();                                  // 启动解析
  }, []);
  return useSessionStore(s => s.status);
}
```
(import `@entities/session` + `@shared/api`;app→entities/shared 顺向)
- [ ] **Step 4**:`store/ui.js` 的 pane/overlay/sidebar 转 re-export from `@app/model`(`useUIStore` 委托各新 store,现有调用点零改)。**注意**:`store/ui` 在 shared-tmp,re-export `@app/model` 是 shared-tmp→app 反向——但 store/ui 是**过渡 shim**(4b 删),且只 re-export;若 eslint 报错,本步把 store/ui 排除出 boundaries 检查(它即将消亡)或标记。报告说明。
- [ ] **Step 5**:`eslint.config.js` 加 `{ type: "app", pattern: "src/app/**" }` element;规则 app 可 import 全部下层。`@app/*` alias(tsconfig)。验证门。commit `feat(frontend): app 层骨架 + useSessionBootstrap + 拆 store/ui 编排状态(阶段4a)` + push。

---

## Task 4a.6:App.jsx 接入 session(bug 根治核心)

**Files:** Modify `frontend/src/App.jsx`;Modify `frontend/src/shared/api/httpClient.ts` + `sse.ts`(删旧 settings 自愈);Delete `frontend/src/store/boot.js`;Modify `frontend/src/store/settings.js`(删 activeUserId)。

> **这是 bug 根治点。** make clean 后:启动 `useSessionBootstrap` → `resolveSession()` 基于 fresh /users 定 status,stale currentUserId 被 fresh 判定替换为 users[0]、**绝不从 stale 喂回**。401 → onAuthFailure → resolve(单次,基于 fresh)。

- [ ] **Step 1**:读 `App.jsx` 全部(boot state machine L96-129、2 自愈 effect L45-54/L77-87、/users query)。
- [ ] **Step 2**:App.jsx 改造:
  - 挂载 `const status = useSessionBootstrap();`。
  - boot 渲染改 `status`:`'onboarding'`→Onboarding;`'loading'`→booting div;`'ready'`→AppShell。**删 `computeBootState` + boot.js import**。
  - **删两个自愈 effect**(L45-54 账号切换 + L77-87 stale 检测)——resolve 接管。**但账号切换清 cross-user 状态(resetAll + 清 activeConv/Run/Doc)**:这个副作用移到 session.currentUserId 变化的订阅(在 useSessionBootstrap 或 app 一处),逐字保留清理逻辑(行为不变)。
  - lang→i18n、theme→dataset 的 effect 保留(读 entities/settings,app 驱动 i18n/applyTheme)。
  - 删 App.jsx 自己的 /users useQuery(resolve 内部 fetch;若 onboarding 判定需要 users,从 session.status 取)。
- [ ] **Step 3**:httpClient/sse 删旧 settings 401 自愈(4a.2 暂留的)——现在 onAuthFailure 已注入 resolve,旧 `useSettings.set({activeUserId:null})` 删掉 + 删默认 provider 的 settings 读取(provider 已被 bootstrap 注入 session)。删对应 inline disable。
- [ ] **Step 4**:`store/boot.js` 删除(grep 确认无残留 import;detectLang 若被 settings 用,迁 entities/settings)。`store/settings.js` 删 `activeUserId`(grep 确认无人再直接读——都走 session 了;onboarding/useAccountManager 改写 session)。
- [ ] **Step 5**:**onboarding/useAccountManager 改写 session**:`features/onboarding`(finish 设 currentUser)、`features/settings/useAccountManager`(switchTo)从写 `settings.activeUserId` 改为写 `session.setCurrentUser` + `resolveSession`(或直接 setCurrentUser + status)。逐字保留语义(切户清缓存等)。
- [ ] **Step 6**:验证门 + **新增 App/session 集成测试**(stale currentUserId + fresh users → ready 收敛,无 401 循环)。commit `fix(frontend): App 接入 entities/session,删 5 处散落自愈根治 401 风暴(阶段4a)` + push。

---

## Task 4a.7:去 entity enabled gate(解 6 entity→settings 债)

**Files:** Modify `entities/{conversation,function,handler,workflow,flowrun,document}/api/*.ts`。

- [ ] **Step 1**:6 个 entity 的 list hook 去掉 `enabled: !!uid` + 删读 `store/settings` 的 import + inline disable(boot gate 已保证 status==='ready' 才挂载组件 → query 不会在非 ready 发)。
- [ ] **Step 2**:确认无其它逻辑依赖该 enabled(纯删 gate)。验证门(**vitest 重点**:确认去 gate 后这些 query 的测试仍绿——测试环境下它们可能直接发,需确认 mock 覆盖)。`grep -rn "eslint-disable.*boundaries" src/entities` 应减少 6 处。commit `refactor(frontend): 去 entity enabled gate(boot gate 接管,解 entity→settings 债,阶段4a)` + push。

---

## Task 4a.8:errorMap + 全局 onError(解 feature→toast 债)

**Files:** Modify `frontend/src/shared/api/errorMap.ts`;Modify `frontend/src/app/providers`(QueryClient onError)或 `main.jsx`;Modify 8 个 `features/*/model/*.ts`(改抛 ApiError 不直接 pushToast)。

- [ ] **Step 1**:`errorMap.ts` 扩展:补齐各业务 error code → 文案(i18n key)的映射表(对照后端 error-codes + 现有 feature toast 文案)。
- [ ] **Step 2**:app QueryClient 配全局 `onError`(mutation/query):读 `ApiError.code` → errorMap → `toastStore.pushToast`。在 app/providers(QueryClientProvider 配置处)。
- [ ] **Step 3**:8 个 feature hook:把"调 mutation + catch + pushToast 错误"改为**依赖全局 onError**(feature 不再 catch 通用错误 toast;特殊业务 toast——如 CONVERSATION_NOT_FOUND 自愈的 warn、iterate 无 conversationId 的 warn——保留但 toast 来源改 shared/ui/toastStore)。**逐字保留每条 toast 文案/触发**;只是改"谁 push"(全局 onError vs feature)。删 feature→store/ui 的 toast import + disable。
- [ ] **Step 4**:验证门(**重点 vitest**:各 feature 的错误路径测试仍绿——toast 现在可能来自全局 onError,测试断言调整)。commit `feat(frontend): errorMap + 全局 onError 收口 toast(解 feature→toast 债,阶段4a)` + push。

> 若 feature 还读 store/ui 的非 toast(如导航 setActiveConv)→ 留到 4a.9。

---

## Task 4a.9:feature 导航返回意图(解 feature→pane 债)

**Files:** Modify `features/send-message/model/useSendMessageFlow.ts` + `features/forge-iterate/model/useForgeIterate.ts`(及读 pane store 的其它 feature);Modify 对应组件(ChatPane/AskAiTrigger)。

- [ ] **Step 1**:grep `features` 里读 `store/ui`/`@app/model` pane action 的(setActiveConv/openPane 等)。
- [ ] **Step 2**:这些 feature hook 改为**返回意图**(不直接操作 pane):
  - `useSendMessageFlow`:CONVERSATION_NOT_FOUND 自愈的 `setActiveConv(null)` → 改为返回/回调通知组件,或暴露 `onConvGone` 回调由 ChatPane 处理导航。
  - `useForgeIterate`:成功跳转 `setActiveConv + openPane` → 返回 `{ conversationId }`,由 AskAiTrigger(组件)导航。
- [ ] **Step 3**:组件(ChatPane/AskAiTrigger,在 panes/components 原位)接收意图后调 pane action(组件→app/model 或经 props;本阶段组件可暂时直接调 store/ui shim,4b 迁移时规范)。**行为不变**(导航效果一致)。删 feature→pane 的 disable。
- [ ] **Step 4**:验证门。commit `refactor(frontend): feature 导航改返回意图(解 feature→pane 债,阶段4a)` + push。

---

## Task 4a.10:SSE 迁 app/sse

**Files:** Move `frontend/src/sse/*` → `frontend/src/app/sse/*`;Modify import 路径 + 旧 `sse/` 留 shim(组件 import 零改,4b 更新)。

- [ ] **Step 1**:`git mv frontend/src/sse/{useEventLog.js,useForge.js,useNotifications.js,SSEProvider.jsx} frontend/src/app/sse/`(保 history)。`sse/shared.js`(已是 @shared/api/sse shim)留原位或一并理顺。
- [ ] **Step 2**:app/sse 的 hook:userID 已通过 4a.2 注入读 session(createSSE 内部);确认 SSE 读注入的 session.currentUserId、断连走 onAuthFailure。
- [ ] **Step 3**:旧 `src/sse/` 路径留 re-export shim(`SSEProvider` 等被 App.jsx import,零改);App.jsx import 可直接更新到 `@app/sse`。
- [ ] **Step 4**:验证门 + `make dev` 冒烟(SSE 三流正常连)。commit `refactor(frontend): SSE 迁 app/sse(阶段4a)` + push。

---

## Task 4a.11:阶段 4a 收口(boundaries 全 error + steiger + bug 根治验证)

**Files:** Modify `frontend/eslint.config.js`(boundaries 收紧)、`frontend/steiger.config.js`、plan 文档。

- [ ] **Step 1 债清零核查**:`grep -rn "eslint-disable.*boundaries\|TODO(阶段4)" frontend/src` —— 确认 ~22 处债**已全解**(entity→settings 去 gate 解、feature→toast 走 onError 解、feature→pane 返回意图解、shared→settings 的 httpClient/sse/i18n 改注入/驱动解)。残留的逐条说明为何还在(理想为 0;若有 store/ui shim 的过渡 re-export,标记 4b 删)。
- [ ] **Step 2 boundaries 收紧**:`shared` 不再有 →store 越界(已改注入);`entities` 不再 →store;`features` 不再 →store/app。app element 规则就位。`npx eslint src`(全量)确认 0 error(迁移期 warn 可接受)。
- [ ] **Step 3 验证**:tsc 0 / vitest 全绿(含 session 单测 + App 集成测试)/ build / 仓库根 `make lint-frontend` 三段过。
- [ ] **Step 4 bug 根治验证(关键)**:仓库根复现原 bug 场景——`make clean` 清后端 DB → `make dev` → **后端日志应无 401 风暴**(启动 resolve 基于 fresh /users 收敛;onboarding 正常)。用 `frontend/tests/manual/probe-*.mjs` 思路或手动验证 onboarding→进主界面 key 正常。记录验证结果(这是整个 revamp 的初心)。
- [ ] **Step 5 文档**:本 plan Task 4a.1-4a.11 勾 `[x]` + 完成说明(身份层落地、5 自愈收敛、22 债清零、bug 根治验证结果)。**不动 PRD/CLAUDE.md**(留阶段5)。commit `chore(frontend): 阶段4a 身份层收口 — 债清零 + bug 根治验证(阶段4a)` + push。

---

## Self-Review

**Spec 覆盖**(对照 spec D6 + §8 最规范):
- ✅ 身份 = entities/session(4a.1)+ DIP 注入(4a.2/4a.5)+ 删 5 自愈(4a.6)+ gate 上移(4a.7)。
- ✅ toast → shared/ui + 全局 onError(4a.3/4a.8);偏好 → entities/settings(4a.4);UI 编排 → app/model(4a.5)。
- ✅ 导航返回意图(4a.9);SSE → app/sse(4a.10)。
- ✅ 22 债清零(4a.11 核查);bug 根治验证(4a.11 复现)。
- 组件迁目录(panes→pages 等)**不在 4a**,留 4b。

**零反向依赖自检**:session 在 entities(下层不读、上层 import);httpClient/sse 注入(不 import session);toast 在 shared(widgets/onError 读);偏好在 entities(组件读);pane/overlay 在 app(只 AppShell 读,4a 不迁组件故组件暂经 store/ui shim 读——4b 改 props)。

**风险点(最高风险阶段)**:① 身份接入(4a.6)动 boot + 删自愈,行为不变靠 vitest + App 集成测试 + make dev 复现;② store 拆分(4a.3/4a.4/4a.5)逐字搬 + shim 保调用点零改;③ 全局 onError(4a.8)改 toast 来源,逐字保留文案,测试断言调整;④ 顺序严格(session→注册点→app注入→App接入→解债),每步可验证。

**类型一致性**:`SessionState`/`resolveSession` 在 4a.1 定;`setUserIdProvider`/`setOnAuthFailure` 在 4a.2 定 4a.5 用;errorMap code→i18n key 对齐后端 error-codes。

**Placeholder 扫描**:身份三核心(4a.1/4a.5/4a.6)给代码骨架;其余给 files + 步骤 + 验证门。无占位。
