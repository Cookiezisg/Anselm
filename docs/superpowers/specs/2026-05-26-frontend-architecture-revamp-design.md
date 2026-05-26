# 前端架构 Revamp 设计 — TypeScript + Feature-Sliced Design

> 状态:设计稿(brainstorming 产物),**已获用户批准方向** → writing-plans → 实现
> 日期:2026-05-26
> 范围:`frontend/` 整体架构 revamp(物理结构 + 逻辑分层 + 类型系统 + 横切收口)
> 关联:身份层重构(本 spec §8)是这次 revamp 的首个应用实例

---

## 1. 动机与目标

### 1.1 触发
起于一个生产 bug:`make clean` 后前端不刷新 → stale `activeUserId` + stale `usersQ` 缓存 → SSE/REST 401 → 多处自愈互相喂 → **401 死循环风暴**。根因不是某一行,是**身份自愈散在 5 处**(App.jsx 两个 effect + client.js + shared.js + boot.js)互相竞态。深查后确认:这是整个前端缺乏架构纪律的一个症状。

### 1.2 三份深度调研的共识诊断
- **缺一条纵向脊柱**:业务逻辑 100% 散在组件 `onClick`/`useEffect`(Onboarding 437 行是个没抽出来的 service;ChatPane.onSend 嵌着发送+自愈+toast)。没有后端 `app/service` 那样的用例层。
- **物理范式和后端相反**:后端纵向按 domain 切;前端横向按技术切(`api/`/`store/`/`sse/`)+ `panes/` 纵向,两种范式并存。一条 chat 链劈在 5 个目录。
- **横切关注点散落**:身份自愈 5 处、`pushToast` 71 处、`invalidateQueries` 76 处/13 文件(forge 失效重复 3 份)、enabled gate 7/14 不一致、`ui.js` 43 成员 God Store、`client.js::apiFetch` 一函数干 6 件事且反向依赖 store。
- **零边界强制**:前端无任何 lint,全靠自觉(后端有 staticcheck + 别名 + port 三重护栏)。
- **但地基已半成型 + 有质量标杆**:`bridge/api/store/panes` 事实上已是四层雏形;`chat store` 的 SSE 树算法、`qk` 工厂、`BlockRenderer` per-id memo、`primitives/`、近全覆盖 vitest —— 保留。

### 1.3 目标
让前端拥有和后端 Go clean arch **对等的低耦合高内聚**:TypeScript 定型 + 完整 Feature-Sliced Design 6 层 + 横切收口 + 机器强制的边界。**为长生命周期/持续迭代留满空间**(当前是 MVP)。

---

## 2. 决策记录(选型 + 为什么)

| # | 决策 | 理由 |
|---|---|---|
| **D1** | **引入 TypeScript**(推翻 PRD §1 "不引入 TypeScript") | FSD 的 public API / port 契约 / entity 形状的**真正编译期强制**锚定类型系统;和后端 Go 强类型对等;无 TS 谈 Clean Arch DIP 是 cargo cult。这是让"名实相符"立得住的地基 |
| **D2** | **完整 FSD 6 层,零裁剪** | Forgify 每层都有真实内容(6 pane=pages、Sidebar/RelGraph 等=widgets);FSD 为长生命周期设计,加能力=加 slice;官方 `steiger` 可机器强制 |
| **D3** | **不叠加 Clean Architecture 的 DIP/repository/use-case 对象** | FSD 的 `entities/api`(数据访问)+ `features/model`(用例)已分离关注点;DIP 的"业务核心脱离框架"价值在单 Wails app 不成立(不会换 React);避免 Java 味样板。未来真有多端需求再议 |
| **D4** | **身份层 = identity store**(phase 状态机 + fresh-only resolve + 401 只发信号),并入 `app` 层 | 单一真相 + 唯一 writer,根治 5 处自愈竞态;作为新架构第一个应用实例,把触发 bug 连根带走 |
| **D5** | **增量迁移,非大爆炸** | ~100 文件,有全覆盖 vitest 兜底;allowJs 让 .jsx/.tsx 共存,逐 slice 搬+定型,每步可验证/commit |
| **D6** | **最规范优先,横切关注点用依赖倒置 / 状态下沉 / 意图返回解反向依赖**(2026-05-26 升级,推翻 §8 的 app/model) | 用户定调:全程最规范、零务实妥协,后续所有决策按此。身份建模为 `entities/session`;`httpClient` 注入 userId 用 **DIP 注册点**(= 后端 domain 定 port、main.go wire);toast 走 `shared/ui` 队列 + app 全局 onError + errorMap;enabled gate 上移到 app/page boot gate;导航由 feature 返回意图、page 执行。零反向依赖。D3 拒绝的是"为脱离框架而堆 repository/use-case 对象",此处注入是 FSD 层级铁律(shared 不依赖上层)的内在必然,不冲突。详见 §8 |

---

## 3. 架构:完整 FSD 6 层(与后端同构)

### 3.1 层定义 + 后端对位 + 依赖规则

依赖**严格自上而下单向**(上层 import 下层;下层永不知上层存在;同层 slice 默认不互引)。

| FSD 层 | 职责 | Forgify 内容 | 后端对位 | 可 import |
|---|---|---|---|---|
| **`app`** | 应用组装:入口、providers、全局 store、SSE 单例、identity、boot、主题 | App.tsx / providers / uiStore / settingsStore / **identityStore** / SSEProvider | `transport` 组装 + main | 全部下层 |
| **`pages`** | 完整屏幕(一个 pane = 一个 page) | chat / forge / execute / library / dashboard / observe | (路由式入口) | widgets/features/entities/shared |
| **`widgets`** | 自包含组合 UI 块(组合多个 feature/entity) | Sidebar / NotificationsDrawer / CommandPalette / RelGraph / VersionRail / AskAiTrigger / EntityRelMeta | (组合层) | features/entities/shared |
| **`features`** | 用户用例/交互(带业务价值) | send-message / forge-iterate / forge-review / workflow-edit / onboarding / settings / ask-user / entity-link | `app/service` | entities/shared |
| **`entities`** | 单个业务实体(数据 + 模型 + 展示卡) | conversation / function / handler / workflow / flowrun / document / skill / mcp / memory / apikey / relation / user | `domain` | shared(+ `@x` cross-import) |
| **`shared`** | 零业务:传输底座、UI kit、工具 | api(httpClient/queryKeys/sse) / bridge / ui / lib / i18n | `infra` + `pkg` | 仅自身 |

### 3.2 FSD 标准规范(全套,不简化)
- **segments**(每个 slice 内固定):`ui / api / model / lib / config`。只建需要的段(`entity-link` 可能只有 `ui/`)。
- **public API**:每 slice 必有 `index.ts`,**外部只能 import 该 slice 的 index**,不准深引内部文件。= 后端 port"不暴露内部"。
- **cross-import**:同层 slice 默认禁互引;entity 间真需共享走 FSD 标准的 `@x` 机制(`entities/conversation/@x/user.ts` 暴露给 user 的专用片)。
- **import 方向**:`app → pages → widgets → features → entities → shared`,反向/越级禁止。

### 3.3 后端对位的精确性(给"为什么舒服"的锚点)
- 后端 `handler` 只"解 JSON→调 service→写 envelope"(S6)→ 前端 `pages`(pane)只"读 hook→渲染→调 mutation",零业务。
- 后端 SQL 只在 `store`(S8)→ 前端 `fetch` 只在 `shared/api/httpClient`,entity 的 api hook 只调它,组件禁直接 fetch。
- 后端 port 在 domain 定义、不暴露 entity → 前端 slice 经 `index.ts` 暴露契约、TS interface 强制。
- 后端别名暴露越界(S13)→ 前端 `steiger` + `eslint-plugin-boundaries` 让越界 CI 红灯。

---

## 4. TypeScript 化策略

### 4.1 配置
- `tsconfig.json`:`strict: true`(渐进:迁移期可 `strict: false` + 逐步开 `noImplicitAny`/`strictNullChecks`,收尾必须全 strict)。`allowJs: true` 让 .jsx/.tsx 迁移期共存。path alias(`@/shared`、`@/entities/*` 等)对齐 FSD 层。
- `vite`:原生支持 TS,装 `typescript` + `@types/react` 等;build 命令不变(`vite build`)。
- `wailsjs/` 生成目录:`tsconfig` 的 `exclude` 排除(Wails 拥有,自带 .d.ts)。

### 4.2 定型对象(优先级:契约边界先)
1. **entity 类型(= 后端 domain entity)**:集中在 `entities/<x>/model/types.ts`。如 `Conversation`、`Message`、`Block`(7 个 BlockType 联合 + status 4 态联合,对齐后端 `eventlog.go`)、`Function`/`Handler`/`Workflow` + Version、`FlowRun` + Node、`ApiKey`、`User` 等。**协议变更只改这里**(补当前最大短板:实体形状散在注释)。
2. **API 请求/响应**:`shared/api` 定 `Envelope<T>`(§N1 `{data}` / 分页 `{items,nextCursor,hasMore}` / `{error}`);各 entity api hook 标注 req/resp 类型。
3. **3 条 SSE payload**:`shared/api/sse` + 各 SSE 事件类型(对齐后端封闭枚举)。
4. **zustand store**:state + actions 接口。
5. **hook 契约**:feature hook 的返回意图 API(`{ submit, canSubmit, isStreaming }`)。

### 4.3 与后端类型的关系
后端是 Go,无法直接共享类型。前端 entity 类型**手写并对齐**后端 contract 文档(`api-design.md`/`events-design.md`)。F1 文档同步:后端 contract 变 → 前端 entity 类型跟改(spec 验收要求一致)。

---

## 5. 业务逻辑安置(核心修复)

**hook = 前端的 use-case 层**(= Clean Arch 的 interface-adapter,社区共识)。分两级:
- **实体级数据访问** → `entities/<x>/api/`(对位后端 `store` + 薄 service):`useConversation(id)`、`useDeleteFunction()`。只调 `shared/api/httpClient`。
- **用例级编排** → `features/<x>/model/`(对位后端 `app/service`):`useSendMessageFlow()` 把"检查 model→组装 body→调 mutation→`CONVERSATION_NOT_FOUND` 自愈→toast"从组件拔出。

**铁律(= S6):组件 `onClick` 里不准有业务决策。** 组件只调一个 feature hook 拿意图级 API。

样板对照:
```ts
// ❌ 现状 ChatPane.onSend(40 行业务嵌在组件)
// ✅ features/send-message/model/useSendMessageFlow.ts
export function useSendMessageFlow(convId: string) {
  // 组装 body / 调 entities 的 useSendMessage / NOT_FOUND 自愈 / toast
  return { submit, cancel, isStreaming, canSend };
}
// pages/chat/ChatPage.tsx 里只剩:const { submit, isStreaming } = useSendMessageFlow(activeConv);
```

---

## 6. 状态分层

| 状态 | 工具 | 归层 |
|---|---|---|
| 服务端缓存(列表/详情/版本) | TanStack Query | `entities/<x>/api/` |
| **身份**(currentUserId/status) | zustand+persist | `entities/session/model`(§8;唯一真相 + 唯一 writer) |
| **用户偏好**(theme/accent/density/lang/reasoningDefault) | zustand+persist | `entities/settings/model`(单例配置实体;下层组件直接读;app 驱动 i18n/theme 应用) |
| **toast 队列** | zustand | `shared/ui`(无业务通知原语;widgets/toaster 渲染 + app 全局 onError 写,均下层可读) |
| 应用 UI 编排(openPanes/activeConv/overlays/sidebar) | zustand | `app/model`(paneStore/overlayStore/sidebarStore;**只 AppShell 读,pages 收 props**,不下放避免反向) |
| **SSE 实时消息树**(特例) | zustand 投影 | `entities/conversation/model/chatStore` —— **rAF 合并 + tree 重建算法原样保留**,组件按 block id 细粒度订阅 |
| 局部 UI(展开/草稿/hover) | `useState` | 组件自身 |

`sse/useForge` 里逸出的第 5 个 store(`useForgeProgress`)→ 收进 `entities/`(forge 相关)或 `app/sse`。

---

## 7. 横切关注点收口(按"传输/身份/资源/展示"分责)

| 关注点 | 现状(散在) | 目标 | 收口方式 |
|---|---|---|---|
| 身份注入(`X-Forgify-User-ID`) | `client.js::activeUserHeader` 读 settings | `shared/api/httpClient`(读 identity store) | 唯一注入点(前端的 middleware) |
| 401 自愈 | client.js + App.jsx + ChatPane 三处 | 拆三责:传输级(httpClient 抛 ApiError)/ 身份级(identity store re-resolve)/ 资源级(feature flow hook 处理 NOT_FOUND) | 见 §8 |
| 错误→提示 | 71 处手写 pushToast | `shared/api` 的 `ApiError.code` + **集中 `code→文案/恢复动作` 表**(对位后端 `errmap.go`)+ TanStack QueryClient 全局 `onError` | feature hook 决定文案,组件不碰 |
| SSE 三连 | `sse/` + SSEProvider | `app/sse/`(SSEProvider 单例**保留**),事件分发到各 entity store | 前端也永不开第四条(对位 E1) |
| invalidate 散落 76 处 | 13 文件各写 | **单一"实体→失效集"映射**(对位 qk 工厂扩展),SSE/mutation 都查它 | 消除 forge 失效 3 份重复 |
| enabled gate | 7/14 不一致 | 所有 user-scoped query `enabled: identity.phase === 'ready'`,统一从 identity 读 | TS + 约定保证不漏 |

---

## 8. 身份层详设计(entities/session + 依赖倒置注入 —— 最规范 FSD)

> **决策升级(2026-05-26,见 D6):** 原 §8 把 identityStore 放 `app/model` 在 FSD 下不成立(`httpClient`(shared)+ entity gate 反向依赖 app)。改为**最规范形态**:身份建模为 `entities/session` 业务实体,横切注入用依赖倒置(与后端 clean arch 同构)。后续所有阶段按此规范。

### 8.1 身份 = `entities/session`
`entities/session/model/sessionStore.ts`(zustand)是身份唯一真相源 + 唯一 writer:
- `currentUserId: string | null`(persist localStorage)
- `status: 'loading' | 'onboarding' | 'ready'`

身份是业务概念(谁登录着)→ 归 **entities 层**(不是 shared,不是 app)。下层 shared 不可见;上层 features/widgets/pages/app 直接 import 合法(顺向)。

### 8.2 `resolve()`(entities/session/model)+ app 触发
- `resolve()`:基于**刚 fetch 的 fresh `/users`**(`entities/session/api` 调,或 @x `entities/user`)定 status:`/users` 空 → onboarding;`currentUserId` 在 fresh → ready;不在(或 null)→ users 非空则选 `users[0]` 并 ready,否则 onboarding。**永远基于 fresh,userId 不可能 stale。**
- 触发:`app/model/useSessionBootstrap`(启动 + 401 信号)调 resolve。app→entities 顺向。

### 8.3 横切注入:依赖倒置(= 后端 port / wire,解 shared→上层反向)
shared 不依赖上层(铁律)。横切用控制反转:
- **userId 注入 header**:`shared/api/httpClient` 暴露 `setUserIdProvider(fn)` 注册点;`app/model/useSessionBootstrap` 启动时注入 `() => sessionStore.getState().currentUserId`。httpClient 调注入 fn 取 userId,**完全不知 session 存在**。= 后端 domain 定 port、`main.go` wire 实现。
- **401 → 信号**:httpClient/sse 的 401 调注入的 `onAuthFailure()`(app 注入 → 触发 `resolve()`)。不各自清 store,**没有"清了又从 stale 喂回"的循环**。

### 8.4 删除的 5 处散落自愈 → 收敛
- `App.jsx` 两个 self-heal/account-switch effect → `entities/session.resolve()`(`app/model/useSessionBootstrap` 调)。
- `httpClient` 401 清除 + `sse` 401 自愈 → 注入的 `onAuthFailure()` → resolve。
- `store/boot.js` valid 判定 → **删除**,boot 直接 = `session.status`。

### 8.5 enabled gate:上移到 app/page boot gate(entity 纯净)
最规范:entity api hook **纯数据访问,不含 user gate**(去掉阶段2 的 `enabled: !!uid`)。"ready 才查"由 **app/page 级 boot gate** 保证:`session.status !== 'ready'` 时 app 渲染 loading/onboarding、**不挂载 AppShell/pages → user-scoped query 根本不发**(组件未挂载)。gate 不再散在每个 entity hook。

### 8.6 其余横切的规范层归属(零反向依赖)
| 关注点 | 规范归属 | 谁读 | 反向解法 |
|---|---|---|---|
| 身份(userId/status) | `entities/session/model` | feature/widget/page/app(顺向) | 下层不读 |
| userId/lang 注入 shared | shared 注册点 + app 注入 | httpClient/i18n 调注入 fn | **DIP** |
| toast 队列 | `shared/ui`(通知原语,无业务) | widgets/toaster + app onError(下层,顺向) | toast 无业务,shared 合理 |
| toast 触发 | feature 抛 `ApiError(code)` → app 全局 onError → `errorMap`(shared) → toast | — | feature 不直接 push |
| 用户偏好(theme/accent/density/lang/reasoningDefault) | `entities/settings`(单例配置实体) | 下层组件 import(顺向);app 驱动 i18n/theme 应用 | i18n/applyTheme 不读 store,由 app 驱动 |
| 导航 / pane / overlay / sidebar UI 编排 | `app/model`(paneStore 等) | **只** AppShell(app)读;pages 收 props | feature 返回意图;pages 不 import app store,从 props 拿 |

---

## 9. 强制手段(无 TS 痛点已被 D1 解决,这里是结构强制)

三道护栏,等价后端 staticcheck + 别名 + port:

1. **`steiger`**(FSD 官方 linter):校验层级依赖、slice public API、cross-import、no-orphan。
2. **`eslint-plugin-boundaries`**:把 6 层注册成 element,`element-types` 声明单向规则;`no-restricted-imports` 禁深引 slice 内部(只走 `index.ts`)。
3. **`tsc`**:类型契约门(public API / entity / port)。
4. **进门禁**:`package.json` 加 `"lint": "eslint src"`、`"typecheck": "tsc --noEmit"`、`"fsd": "steiger src"`,并入 `make lint-frontend`,和后端 `staticcheck` 同等地位 —— 违规 push 不过去。

**内聚衡量**:改一个 feature 应该只动它自己 slice 目录下的文件。

---

## 10. Wails 约束(确认不冲突,这里固化边界)

- **集成面只锁 `shared/bridge/wails.ts`**:`GetBackendPort()` binding + `apiUrl()`(Wails 绝对 URL / 浏览器相对)。其余前端通过 HTTP 连后端(不走 native binding)。
- **`wailsjs/` 生成目录**(Wails 拥有,每次 `wails dev/build` 重生成):排除出 FSD/steiger/eslint/tsconfig(像 `node_modules`)。`shared/bridge` import 它。
- TS 下 Wails 自动生成 `wailsjs/go/**/*.d.ts` → `GetBackendPort` 边界首次有类型保护。
- `wails.json` 的 frontend build/dev/install 命令**不变**(`vite build` / `vite` / `npm install`)。
- **每个迁移阶段末尾跑 `wails dev` 冒烟**(窗口起得来 + 能连后端),与 `make dev` 同级验证。

---

## 11. 完整目录结构(到 slice 级)

```
frontend/src/
├── main.tsx                          # 入口
├── app/                              # ── 第 6 层:组装 ──
│   ├── App.tsx                       # 根(boot=session.status,瘦身)
│   ├── AppShell.tsx                  # composition root:读 app/model 编排状态 → 渲染 pages 传 props
│   ├── providers/                    # QueryProvider(全局 onError→errorMap→toast)/ SSEProvider / I18nProvider
│   ├── model/
│   │   ├── useSessionBootstrap.ts    # 启动 resolve + 注入 userId provider/onAuthFailure 到 shared/api(§8.3)
│   │   ├── paneStore.ts              # openPanes/activeConv/activeFlowRun/activeDocument/leftPct/focusEntity
│   │   ├── overlayStore.ts           # cmdk/notifs/ask/settings open + pendingAsk
│   │   └── sidebarStore.ts           # collapsed/tools/recent/archived expanded
│   ├── sse/                          # SSEProvider + 3 hook(分发到 entity store)
│   └── index.ts
├── pages/                            # ── 第 5 层:屏幕(= pane) ──
│   ├── chat/ forge/ execute/ library/ dashboard/ observe/   (各 ui/ + index.ts)
├── widgets/                          # ── 第 4 层:组合块 ──
│   ├── sidebar/ command-palette/ notifications-drawer/ entity-graph/
│   ├── version-rail/ ask-ai-trigger/ entity-rel-meta/       (各 ui/ model/ index.ts)
├── features/                         # ── 第 3 层:用例 ──
│   ├── send-message/ forge-iterate/ forge-review/ workflow-edit/
│   ├── onboarding/ settings/ ask-user/ entity-link/         (各 ui/ model/ index.ts)
├── entities/                         # ── 第 2 层:实体 ──
│   ├── session/       { api/ model/(sessionStore + resolve) index.ts }  # 身份(§8),唯一真相
│   ├── settings/      { model/(settingsStore 偏好) index.ts }           # 单例配置实体
│   ├── conversation/  { api/ model/(chatStore+types) ui/ index.ts }
│   ├── function/ handler/ workflow/ flowrun/ document/ skill/
│   ├── mcp/ memory/ apikey/ relation/ user/                 (各 api/ model/types ui/ index.ts)
└── shared/                           # ── 第 1 层:基础设施 ──
    ├── api/       httpClient.ts(+ setUserIdProvider/onAuthFailure 注册点,§8.3) queryKeys.ts sse.ts errorMap.ts
    ├── bridge/    wails.ts
    ├── ui/        Button Badge Icon Kbd Spinner Select + toastStore.ts + index.ts
    ├── lib/       motion.ts i18n/
    └── config/    (eslint/steiger 配置可放仓库根)
```

---

## 12. 现状 → 新架构映射(writing-plans 的搬迁清单依据)

| 现状 | 新位置 |
|---|---|
| `bridge/wails.js` | `shared/bridge/wails.ts` |
| `api/client.js`(apiFetch/ApiError/pickList/qk) | `shared/api/{httpClient,envelope,queryKeys}.ts` |
| `sse/shared.js` | `shared/api/sse.ts` |
| `motion/tokens.js` / `i18n/` | `shared/lib/motion.ts` / `shared/lib/i18n/` |
| `components/primitives/*` | `shared/ui/*` |
| `api/conversations.js` | `entities/conversation/api/` |
| `store/chat.js` | `entities/conversation/model/chatStore.ts` |
| `api/forge.js`(256 行混装) | 拆 `entities/{function,handler,workflow}/api/` + `features/forge-iterate`、`features/forge-review` |
| `api/config.js` | `entities/apikey/api/` + `entities/model-config(并入 apikey 或独立)` |
| `api/library.js` | `entities/{document,skill,mcp,memory}/api/` |
| `api/flowruns.js` / `api/notifications.js` / `api/relations.js` / `api/users.js` | `entities/{flowrun,...}/api/` + `user`(+ settingsStore) |
| `store/ui.js`(God Store) | 拆进 `app/model/{uiStore...}` |
| `store/settings.js` | `app/model/settingsStore.ts`(+ identity 接管 userId,见 §8) |
| `store/boot.js` | 删(boot = identity.phase) |
| `App.jsx` self-heal | `app/model/identityStore` + `useIdentityBootstrap` |
| `panes/chat/*` | `pages/chat/` + `features/send-message`(Composer 等) |
| `panes/forge,execute,library,dashboard,observe/*` | `pages/*` + 抽业务到 `features/*` |
| `components/shared/{RelGraph,AskAiTrigger,VersionRail,EntityRelMeta}` | `widgets/*`(它们组合多实体,本就不是"shared 原子") |
| `components/layout/{Sidebar,AppShell,PaneFrame...}` | `widgets/sidebar` + `app/shell`(AppShell 现在合法 import pages) |
| `components/overlays/{CommandPalette,NotificationsDrawer,AskUserModal,Onboarding,SettingsModal}` | `widgets/*` 或 `features/*`(按"组合块"vs"用例"归) |
| `hooks/*` | 按用途散入对应 slice(useDisplayName→entities/user 等)或 `shared/lib` |

---

## 13. 增量迁移路线(阶段,每阶段独立可验证/commit)

> 原则:先立护栏 → 搭地基 → 自底向上搬 + 定型 → 抽用例 → 收口横切。每阶段末:`npm test`(vitest 全绿)+ `npm run typecheck` + `wails dev` 冒烟。

- **阶段 0 — 护栏 + TS 地基(零搬家)**:加 `tsconfig.json`(allowJs,宽松 strict)+ vite TS + `eslint.config.js` + `eslint-plugin-boundaries` + `steiger`(先把现有目录注册成临时 element 标 warning,量化违规)+ path alias。并入 `make lint-frontend`/`typecheck`。
- **阶段 1 — `shared/` 层**:搬 bridge/client/sse/primitives/motion/i18n → `shared/*`,改 .ts,定型 `httpClient`/`Envelope<T>`/`queryKeys`/`ApiError`/`errorMap`。建 public API。
- **阶段 2 — `entities/` 层(逐实体)**:每个 `api/*.js` → `entities/<x>/api/*.ts`,先定 `model/types.ts`(实体形状),再定型 api hooks,建 `index.ts`。`store/chat.js → entities/conversation/model/chatStore.ts`。拆 `api/forge.js`。违规 warning 逐个升 error 清零。
- **阶段 3 — `features/` 层(抽用例)**:把组件里的业务编排(ChatPane.onSend、Onboarding 全流程、forge accept/reject、RelGraph 数据聚合)抽进 `features/*/model` 的 hook。组件变薄。
- **阶段 4 — `widgets/` + `pages/` + `app/`**:组合块归 widgets;pane 退化成 `pages/*` 薄容器;**身份层落地**(identityStore + useIdentityBootstrap,删 5 处自愈、补 gate、错误表、SSE 移 app/sse)。
- **阶段 5 — 收尾 + 严格化**:`tsconfig` 开满 strict、清 allowJs(全 .tsx);steiger/boundaries 零违规;删所有旧死代码;**文档同步**:PRD §1(TS)/§2(目录)/§5(状态)/§17(API+类型)、CLAUDE.md 前端守则(新增 FSD 6 层 + 依赖规则 + lint 门禁 + TS 约定)。

---

## 14. 测试策略

- **vitest 全覆盖是安全网**:每阶段、每 slice 搬完即跑,绿才继续。测试随源码迁移(co-located `.test.tsx`)。
- **类型即测试**:tsc 在 CI 抓契约破裂。
- **steiger/boundaries**:抓架构破裂。
- **wails dev 冒烟**:每阶段末确认桌面壳 + 后端连通。
- **身份层**:补"stale userId + fresh /users → resolve 收敛、不循环"的单测(覆盖触发 bug 的场景)。

---

## 15. 范围边界

- **做**:架构组织(FSD 6 层)、TypeScript 化、横切收口、身份层重构、lint/类型门禁、文档同步。
- **不做**:业务功能变更、UI 视觉/交互变更(像素级保持)、后端任何改动、新增 feature。这是**纯架构/类型/组织重构**,行为不变(vitest 断言行为不变即证)。
- **顺带**(低风险随手):中文 workspace 名 → 400 的 username 生成修复(non-ASCII slug);死代码清理(`App.jsx` 重复 /users query、`ui.baseUrl` 死字段)。

---

## 16. 验收标准

- [ ] 全前端 `.tsx`/`.ts`,`tsconfig strict: true` 通过 `tsc --noEmit`,无 `any` 逃逸(边界类型完整)。
- [ ] FSD 6 层就位,`steiger src` + `eslint`(boundaries)零违规;4 处已知违规(AppShell 倒灌 / RelGraph 假 shared / forge.js 混装 / 零 lint)全消除。
- [ ] 每个 slice 有 `index.ts` public API,无跨 slice 深引。
- [ ] 业务逻辑全在 `features/*/model` 或 `entities/*/api` 的 hook;组件 `onClick` 零业务决策(抽查 ChatPage/Onboarding/Sidebar)。
- [ ] 身份:5 处自愈 → identityStore 一处;`make clean`+不刷新 不再风暴(单测 + 手动复现验证);所有 user-scoped query 有 `enabled: phase==='ready'`。
- [ ] 错误处理:集中 errorMap + TanStack 全局 onError;`pushToast` 不再散在 71 处手写。
- [ ] `wails dev` / `wails build` 正常,桌面壳连后端无异常。
- [ ] vitest 全绿(行为不变);`make lint-frontend` + `typecheck` 进门禁。
- [ ] 文档同步:PRD §1/§2/§5/§17 + CLAUDE.md 前端守则更新。
