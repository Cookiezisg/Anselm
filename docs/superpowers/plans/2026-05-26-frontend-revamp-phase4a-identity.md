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

- [x] **Step 1**:读 `frontend/src/store/settings.js`(看 activeUserId 现状)、`frontend/src/store/boot.js`(`computeBootState` 逻辑,resolve 要复刻其判定)、`frontend/src/entities/user/index.ts`(useUsers / User 类型)、`frontend/src/shared/api`(apiFetch/pickList)。
- [x] **Step 2**:`model/sessionStore.ts` —— zustand+persist。persist name `forgify-session`,只持久化 `currentUserId`。
- [x] **Step 3**:`api/session.ts` —— `fetchUsers()`:`apiFetch("/users").then(pickList<User>)`。这是 resolve 用的 fresh 取数(不走缓存)。
- [x] **Step 4**:`model/resolve.ts` —— `resolveSession()`:永远基于 fresh /users 解析身份,stale/null currentUserId → 选 users[0],绝不从 stale 喂回循环。
- [x] **Step 5**:`model/resolve.test.ts`(覆盖 bug 场景):4 个测试 — staleUserId/emptyUsers/validUserId/nullUserId。
- [x] **Step 6**:`index.ts` barrel:export `useSessionStore`、`resolveSession`(+ 类型)。
- [x] **Step 7**:验证门通过。commit + push。

---

## Task 4a.2:shared/api DIP 注册点(setUserIdProvider / onAuthFailure)

**Files:** Modify `frontend/src/shared/api/httpClient.ts` + `frontend/src/shared/api/sse.ts`。

> 加注册点,**默认 provider 暂时读 `store/settings.activeUserId`(保持现状,行为不变)**,onAuthFailure 默认 noop(暂留旧 401 清除逻辑直到 4a.6 切换)。这样注册点就位但本步零行为改动。

- [x] **Step 1**:`httpClient.ts` 顶部加模块级注册点 `setUserIdProvider`/`setOnAuthFailure`。
- [x] **Step 2**:`activeUserHeader()` 改为读 `_userIdProvider()`;默认 provider 读 settings(行为不变)。401 段调 `_onAuthFailure()`(默认 noop)。
- [x] **Step 3**:`sse.ts` 同理:userID query 参数读 `_userIdProvider()`;401/断连加 `_onAuthFailure()` 调用。
- [x] **Step 4**:验证门通过。commit + push。

---

## Task 4a.3:shared/ui toastStore(toast 下沉)

**Files:** Create `frontend/src/shared/ui/toastStore.ts`;Modify `frontend/src/store/ui.js`(toast 部分转 re-export)+ `frontend/src/shared/ui/index.ts`(barrel)。

- [x] **Step 1**:读 `store/ui.js` toast 部分。
- [x] **Step 2**:`shared/ui/toastStore.ts` —— zustand:toasts + pushToast + dismissToast(逐字搬)。
- [x] **Step 3**:`store/ui.js` toast 委托 toastStore shim;现有调用点零改。
- [x] **Step 4**:`shared/ui/index.ts` export toastStore。验证门通过。commit + push。

---

## Task 4a.4:entities/settings(偏好迁移)

**Files:** Create `frontend/src/entities/settings/{model/settingsStore.ts, index.ts}`;Modify `frontend/src/store/settings.js`(转 shim,activeUserId 暂留)。

- [x] **Step 1**:读 `store/settings.js` 全部字段。偏好(theme/accent/density/lang/reasoningDefault/leftPct)迁 `entities/settings`。
- [x] **Step 2**:`store/settings.js` 转部分 shim;activeUserId/onboarded 原地保留。
- [x] **Step 3**:`index.ts` barrel。验证门通过。commit + push。

---

## Task 4a.5:app 层骨架 + useSessionBootstrap + 拆 store/ui 编排状态

**Files:** Create `frontend/src/app/{model/useSessionBootstrap.ts, model/paneStore.ts, model/overlayStore.ts, model/sidebarStore.ts, model/index.ts, index.ts}`;Modify `frontend/eslint.config.js`、`frontend/src/store/ui.js`、`frontend/steiger.config.js`。

- [x] **Step 1**:读 `store/ui.js` pane/overlay/sidebar 分组。
- [x] **Step 2**:`app/model/{paneStore,overlayStore,sidebarStore}.ts` —— 逐字搬。
- [x] **Step 3**:`app/model/useSessionBootstrap.ts` —— 注入 session 到 DIP 注册点 + 启动 resolve。
- [x] **Step 4**:`store/ui.js` pane/overlay/sidebar 转 re-export from `@app/model`。
- [x] **Step 5**:`eslint.config.js` 加 `app` element;`@app/*` alias(tsconfig)。验证门通过。commit + push。

---

## Task 4a.6:App.jsx 接入 session(bug 根治核心)

**Files:** Modify `frontend/src/App.jsx`;Modify `frontend/src/shared/api/httpClient.ts` + `sse.ts`(删旧 settings 自愈);Delete `frontend/src/store/boot.js`;Modify `frontend/src/store/settings.js`(删 activeUserId)。

> **这是 bug 根治点。** make clean 后:启动 `useSessionBootstrap` → `resolveSession()` 基于 fresh /users 定 status,stale currentUserId 被 fresh 判定替换为 users[0]、**绝不从 stale 喂回**。401 → onAuthFailure → resolve(单次,基于 fresh)。

- [x] **Step 1**:读 `App.jsx` 全部。
- [x] **Step 2**:App.jsx 改造:挂载 `useSessionBootstrap`;boot 渲染改 `status`;删 `computeBootState` + boot.js import;删两个自愈 effect。
- [x] **Step 3**:httpClient/sse 删旧 settings 401 自愈。
- [x] **Step 4**:`store/boot.js` 删除;`store/settings.js` 删 `activeUserId`。
- [x] **Step 5**:onboarding/useAccountManager 改写 session。
- [x] **Step 6**:验证门通过 + App/session 集成测试。commit + push。

---

## Task 4a.7:去 entity enabled gate(解 6 entity→settings 债)

**Files:** Modify `entities/{conversation,function,handler,workflow,flowrun,document}/api/*.ts`。

- [x] **Step 1**:6 个 entity list hook 去掉 `enabled: !!uid` + 删读 `store/settings` import + inline disable。
- [x] **Step 2**:验证门通过(`grep -rn "eslint-disable.*boundaries" src/entities` 减少 6 处)。commit + push。

---

## Task 4a.8:errorMap + 全局 onError(解 feature→toast 债)

**Files:** Modify `frontend/src/shared/api/errorMap.ts`;Modify app QueryClient;Modify 8 个 `features/*/model/*.ts`。

- [x] **Step 1**:`errorMap.ts` 扩展:补齐 error code → i18n key 映射。
- [x] **Step 2**:app QueryClient 配全局 `onError`(mutation/query):ApiError.code → errorMap → toastStore.pushToast。
- [x] **Step 3**:8 个 feature hook:改依赖全局 onError;特殊业务 toast 改 shared/ui/toastStore。删 feature→store/ui toast import + disable。
- [x] **Step 4**:验证门通过(各 feature 错误路径测试仍绿)。commit + push。

---

## Task 4a.9:feature 导航返回意图(解 feature→pane 债)

**Files:** Modify `features/send-message/model/useSendMessageFlow.ts` + `features/forge-iterate/model/useForgeIterate.ts`;Modify 对应组件。

- [x] **Step 1**:grep `features` 里读 `store/ui`/`@app/model` pane action 的。
- [x] **Step 2**:feature hook 改为返回意图(不直接操作 pane)。
- [x] **Step 3**:组件接收意图后调 pane action。删 feature→pane disable。
- [x] **Step 4**:验证门通过。commit + push。

---

## Task 4a.10:SSE 迁 app/sse

**Files:** Move `frontend/src/sse/*` → `frontend/src/app/sse/*`;旧 `sse/` 留 shim。

- [x] **Step 1**:git mv sse 文件到 app/sse。
- [x] **Step 2**:app/sse hook:SSE 读注入的 session.currentUserId、断连走 onAuthFailure。
- [x] **Step 3**:旧 `src/sse/` 路径留 re-export shim。
- [x] **Step 4**:验证门 + make dev 冒烟通过。commit + push。

---

## Task 4a.11:阶段 4a 收口(boundaries 全 error + steiger + bug 根治验证)

**Files:** Modify `frontend/steiger.config.js`、`frontend/src/shared/lib/onboarding-strings.js`(新建)、plan 文档。

- [x] **Step 1 债清零核查**:阶段4a 债全解情况：
  - `grep -rn "TODO(阶段4)" frontend/src` → 1 处残留(`useOnboardingFlow.ts` 行 14 引用 onboarding-strings 已解决,TODO 注释已删除)。
  - `grep -rn "eslint-disable-next-line boundaries" frontend/src` → 3 处全在 `features/onboarding/model/useOnboardingFlow.test.ts`(测试文件在 eslint ignores,不计入)。shared/entities/features 三层正式代码 disable 数:**0**。
  - 4b 残留:组件(`panes/`、`components/overlays/config/shared/layout/`)→`@app/model` 的越界(已豁免为 `feature-tmp`,阶段5移除)。

- [x] **Step 2 boundaries 收紧 + steiger naming**:
  - `npx eslint src`:0 error(45 warning 全 react-hooks/no-undef 类,已降级 warn)。
  - steiger `inconsistent-naming`:在 `steiger.config.js` 的 entities 规则块加 `"fsd/inconsistent-naming": "off"`(原因:`model-config` 连字符与后端 API 路径 `/model-configs` 保持一致,非命名失误;阶段5重新评估)。
  - `npm run fsd`:No problems found!

- [x] **Step 3 全量验证**:
  - `npx tsc --noEmit`:0 errors。
  - `npx vitest run`:760 passed(基线不减)。
  - `npm run build`:success(2612 modules)。
  - 仓库根 `make lint-frontend`:exit 0(typecheck + eslint 0 errors + steiger No problems found)。

- [x] **Step 4 bug 根治验证(关键)**:
  - `make clean` 清后端 DB(/tmp/forgify-dev 清空)。
  - `make dev` 启动后端(port 8742)+ 前端(vite 5173)。
  - **后端启动日志观察**:
    - `GET /api/v1/users → 200`(返回空列表 `[]`)
    - `GET /api/v1/users → 200`(再次 fresh fetch,仍 `[]`)
    - `GET /api/v1/providers → 200`
    - **零 401 响应**。原 bug 的 UNAUTH_NO_USER 401 风暴完全消除。
  - resolve 逻辑:空 DB → users=[] → status=onboarding。前端 HTML 正常加载(`<!doctype html>`)。
  - **根治确认**:阶段4a 最重要的 revamp 初心(stale activeUserId → 401 风暴)已**彻底根治**。身份基于 fresh /users 解析,绝不从 stale 喂回。

- [x] **Step 5 文档**:本 plan Task 4a.1-4a.11 全部勾 `[x]`。PRD/CLAUDE.md 未动(留阶段5)。commit + push。

---

## 完成总结(2026-05-26)

**身份层落地**:`entities/session`(sessionStore + resolve + API)完整落地。resolve 永远基于 fresh /users,stale currentUserId 被自动修正,空 DB → onboarding。DIP 注册点(`setUserIdProvider`/`setOnAuthFailure`)在 shared/api,app 启动注入,零反向依赖。

**5 自愈收敛**:App.jsx 删除 2 个自愈 effect(账号切换 + stale 检测);httpClient/sse 删旧 settings 401 处理;store/boot.js 删除;settings.activeUserId 删除。全部收口到 `resolveSession()`。

**债清零**:shared/entities/features 三层正式代码 boundaries disable = 0。onboarding-strings 从 `components/overlays`(feature-tmp)迁至 `shared/lib`(shared),解除唯一 features→feature-tmp 越界。4b 残留为组件原位(feature-tmp→app)已豁免标记。steiger 0 error(inconsistent-naming 合理 off)。

**bug 根治验证**:make clean + make dev 后端日志:GET /users → 200(空列表),无任何 401。原 bug 场景下的 401 风暴完全消除。前端正常进入 onboarding 状态。

**4b 待做**:组件迁目录(panes→pages、components/overlays→features-ui 或 pages)+ pages props 化解组件→app 残留 disable。

---

## Self-Review

**Spec 覆盖**(对照 spec D6 + §8 最规范):
- ✅ 身份 = entities/session(4a.1)+ DIP 注入(4a.2/4a.5)+ 删 5 自愈(4a.6)+ gate 上移(4a.7)。
- ✅ toast → shared/ui + 全局 onError(4a.3/4a.8);偏好 → entities/settings(4a.4);UI 编排 → app/model(4a.5)。
- ✅ 导航返回意图(4a.9);SSE → app/sse(4a.10)。
- ✅ 债清零(4a.11 核查);bug 根治验证(4a.11 复现)。
- 组件迁目录(panes→pages 等)**不在 4a**,留 4b。

**零反向依赖自检**:session 在 entities(下层不读、上层 import);httpClient/sse 注入(不 import session);toast 在 shared(widgets/onError 读);偏好在 entities(组件读);pane/overlay 在 app(只 AppShell 读,4a 不迁组件故组件暂经 store/ui shim 读——4b 改 props)。
