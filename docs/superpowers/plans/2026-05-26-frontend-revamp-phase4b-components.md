# 前端 Revamp 阶段 4b:组件物理迁移 + props 化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development 逐 task 执行。步骤用 `- [ ]` 勾选。

**Goal:** 把组件从过渡目录(`panes/`、`components/`、`App.jsx`/`main.jsx`)物理迁移到 FSD 正式层(`pages/`、`widgets/`、`features/*/ui`、`entities/*/ui`、`app/`),并 **props 化**解掉阶段 4a 遗留的组件→app 残留反向依赖(组件直接读 `@app/model` pane/overlay store)。**行为/UI 零改动**(vitest 全程绿 + 渲染/交互 1:1)。完成后 `panes/`、`components/`、旧 `store/*` shim 清空。

**Architecture(最规范 FSD,零反向依赖):**
- `pages`/`widgets`/`features`/`entities` **不能 import `app`**。pane/overlay/sidebar 编排状态在 `app/model`,**只 `app/AppShell` 读写**;AppShell 渲染 pages/widgets 时传 **props(数据)+ 回调(动作)**。pages/widgets 零 app 依赖。
- 迁移目标层(见 §映射表):pane 容器→`pages/<kind>`;pane 子组件→`pages/<kind>/ui` 或对应 feature/entity 的 ui;overlay→`features/*/ui`(用例)或 `widgets`(组合块);layout→`app`(AppShell)+ `widgets/sidebar`;detail 视图→`entities/*/ui`;通用展示→`widgets` 或留 `shared/ui`;hooks→对应 slice 的 `lib` 或 `shared/lib`。
- 旧路径 import 随迁移**直接更新**(不留新 shim);迁移后删空的过渡目录 + 旧 `store/*` re-export shim。

**Tech Stack:** TypeScript、React、zustand、TanStack Query、vitest、steiger、eslint-plugin-boundaries。

> **范围**:纯**物理组织 + props 化**,行为/UI 不变。不改业务逻辑(已在 4a 收口)。组件可顺手 `.jsx → .tsx`(若低风险)或保持 `.jsx`(allowJs)——优先保持 `.jsx` 减少风险,`.tsx` 化留阶段 5 strict 时。

---

## 通用纪律(每个 task 都遵守)

- 独占 main,**严禁开新分支**;**精确 git add**(只本 task 产物,严禁 `git add -A`——工作树有 probe 探针 + backend audit 残留);commit 前 `git status` 核对;**绝不碰 backend/**;commit 中文无 AI attribution;commit 后 `git push`;撞 `index.lock` 先 `ps aux | grep -E "[g]it (commit|add)"` + 看 mtime 确认孤儿(很可能 Zed 编辑器后台短锁)才 `rm -f`,绝不盲删。
- 用 `git mv` 迁移(保 history)。命令在 `frontend/` 内跑(除非注明仓库根)。
- **每 task 末**:`npx tsc --noEmit`(0)/ `npx vitest run`(基线不减,当前 760)/ `npm run build` / `npx eslint <改动>`(0 error)/ `npm run fsd`(干净)。组件迁移后**渲染/交互 1:1 不变**(测试随组件迁移,co-located)。

## props 化 SOP(解组件→app 反向 —— 4b 核心)

阶段 4a 后,组件直接读 `@app/model`(`usePaneStore`/`useOverlayStore`/`useSidebarStore`),带 `// TODO(4b)` + eslint-disable。物理迁移到 pages/widgets 后,这变成 **pages/widgets→app 正式反向**(必须解)。规范解法:

1. **AppShell(app/AppShell.tsx)是 pane/overlay/sidebar 的唯一读写者**:读 `usePaneStore`/`useOverlayStore`/`useSidebarStore`,决定渲染哪些 page/widget。
2. **渲染 pages/widgets 时传 props + 回调**:数据(`activeConv`/`openPanes`/...)作 props;动作(`onSelectConv`/`onOpenPane`/`onToggleSidebar`/...)作回调(回调内部调 app/model store action)。
3. **pages/widgets 只用 props/回调**,**零 import `@app/model`**。深层子组件需要的,page/widget 继续往下传(props drilling)或用 page 本地 context(若太深)。
4. **overlay**(cmdk/notifs/ask/settings open + pendingAsk):AppShell 读 overlayStore 决定挂载哪个 overlay widget/feature-ui,传 open 状态 + onClose 回调。
5. 迁移每个组件时**同步 props 化**(删 `@app/model` import + disable,改收 props);AppShell 补对应注入。**行为不变**(数据流从"组件读 store"变"AppShell 读+传 props",渲染结果一致)。

## 迁移映射表(来自阶段4 调研,实现时以实际为准)

| 现状 | 目标 | props 化 |
|---|---|---|
| `App.jsx` / `main.jsx` | `app/App.tsx` / `app/main.tsx`(或保 .jsx) | App 已读 session(顺向);挂 AppShell |
| `components/layout/AppShell.jsx` | `app/AppShell.tsx` | **核心**:读 pane/overlay/sidebar store,传 props 给 pages/widgets |
| `components/layout/{PaneFrame,PaneResize,NarrowSwitch,PaneCollapseToggle}` | `app/shell/*` | app 层,可读 app/model |
| `components/layout/Sidebar.jsx` + `SidebarSection`/`ChatListItem` | `widgets/sidebar/*` | 收 props(activeConv/onSelectConv/collapsed/onToggle...) |
| `panes/chat/ChatPane.jsx`(容器) | `pages/chat/ChatPage.tsx` | 收 props(activeConv 等) |
| `panes/chat/{ChatHeader,MessageView,BlockRenderer,NoApiKeyGate,NoModelGate}` | `pages/chat/ui/*` | 经 page 传 props |
| `panes/chat/Composer.jsx` | `features/send-message/ui/Composer.tsx` | feature ui |
| `panes/forge/ForgePane.jsx` | `pages/forge/ForgePage.tsx` | 收 props |
| `panes/forge/{ForgeList,CapabilityCheckPanel}` | `pages/forge/ui/*` | |
| `panes/forge/{FunctionDetail,HandlerDetail,WorkflowDetail}` | `entities/{function,handler,workflow}/ui/*` | entity 视图 |
| `panes/forge/WorkflowEditor.jsx` | `features/workflow-edit/ui/*` | feature ui |
| `panes/execute/{ExecutePane,ExecuteOverview,ApprovalBanner}` | `pages/execute/*` | ExecutePane→ExecutePage;子组件 ui |
| `panes/execute/FlowRunDetail.jsx` + `RunDrawer` | `entities/flowrun/ui/*` | |
| `panes/library/{Documents,Skills,Mcp,Memory}Pane` | `pages/library/*` | 各 Page |
| `panes/library/{DocEditor,CodeBlockNode}` | `entities/document/ui/*` + `pages/library/ui` | |
| `panes/observe/ObservePane` | `pages/observe/ObservePage` | |
| `panes/dashboard/{Dashboard,WelcomeInput}` + `useGreeting`/`useContextStrip`/`greetings` | `pages/dashboard/*` + `pages/dashboard/lib/*` | |
| `panes/PlaceholderPane` | `pages/shared/` 或 `widgets/` | |
| `components/overlays/Onboarding` | `features/onboarding/ui/Onboarding.tsx` | |
| `components/overlays/SettingsModal` + `components/config/*` | `features/settings/ui/*` | |
| `components/overlays/AskUserModal` | `features/ask-user/ui/AskUserModal.tsx` | 收 props(pending/onClose,4a 已上移) |
| `components/overlays/{CommandPalette,NotificationsDrawer}` | `widgets/{command-palette,notifications-drawer}/*` | 收 props(open/onClose) |
| `components/overlays/ToastTray` | `widgets/toaster/*` | 读 shared/ui toastStore(顺向) |
| `components/shared/{RelGraph}` | `widgets/entity-graph/*` | |
| `components/shared/{AskAiTrigger}` | `widgets/ask-ai-trigger` 或 `features/forge-iterate/ui` | |
| `components/shared/{VersionRail,EntityRelMeta,EntityLink,ActionMenu,StatusBadge,KindChip,RelTime,FloatingInspector,BottomSheet,MarkdownView,HighlightedCode}` | `widgets/*`(组合块)或 `shared/ui`(纯展示原语) | 按"组合多实体=widget,纯展示=shared/ui"归 |
| `components/shared/lowlightInstance.js` | `shared/lib/highlight` | |
| `hooks/useDisplayName` | `entities/user/lib/` | |
| `hooks/{useEntityName,useCollapsible}` | `shared/lib/` | |
| `hooks/useKeyboardShortcuts` | `app/lib/` | app 层(全局快捷键) |

## 不变量(行为/UI 不变)

- **渲染输出 + 交互 1:1**:迁移 = `git mv` + import 更新 + props 化(数据流换 AppShell 注入);JSX/className/样式/事件**不动**。
- **props 化语义等价**:组件原来读 `usePaneStore(s=>s.activeConv)`,现在收 `props.activeConv`(AppShell 从同一 store 读后传);写 `setActiveConv(x)` 改 `props.onSelectConv(x)`(回调内调同一 action)。结果一致。
- **测试随迁移**:co-located 测试 `git mv` 同迁;import 路径更新;断言不变(行为不变)。
- **不改业务逻辑**(4a 已收口);**不做 .tsx strict 化**(保 .jsx,strict 留阶段5)。

---

## Task 4b.1:app 骨架(App/main/AppShell/layout → app)+ props 化中枢 ✅

**Files:** `git mv` `App.jsx`/`main.jsx` → `app/`;`components/layout/*` → `app/AppShell.tsx` + `app/shell/*`;改 AppShell 为 props 化中枢;eslint boundaries(layout 不再是 feature-tmp)。

- [x] Step 1:读 `components/layout/{AppShell,PaneFrame,PaneResize,NarrowSwitch}.jsx`
- [x] Step 2:`git mv` App.jsx→`app/App.jsx`、main.jsx→`app/main.jsx`
- [x] Step 3:**AppShell props 化中枢**
- [x] Step 4:`hooks/useKeyboardShortcuts` → `app/lib/`
- [x] Step 5:eslint boundaries 更新。commit + push ✅

---

## Task 4b.2:widgets(sidebar / overlays-as-widgets / shared 组合块) ✅

**Files:** `git mv` `components/layout/Sidebar*` → `widgets/sidebar/`;`components/overlays/{CommandPalette,NotificationsDrawer,ToastTray}` → `widgets/*`;`components/shared/{RelGraph,VersionRail,EntityRelMeta,...}` → `widgets/*` 或 `shared/ui`。

- [x] Step 1-4: 完成。导航 DIP(shared/lib/navigation)解 widgets→app 反向;commit + push ✅

---

## Task 4b.3:pages(6 个 pane → pages)+ props 化 ✅

**Files:** `git mv` `panes/{chat,forge,execute,library,dashboard,observe}/*` → `pages/*`。

- [x] Step 1-N: 全 6 个 pane 迁 pages,SSE health props 化(sseHealth→props),commit + push ✅

---

## Task 4b.4:features ui + entities ui ✅

**Files:** `git mv` overlay/detail/editor 组件 → 对应 `features/*/ui` 或 `entities/*/ui`。

- [x] features ui: Onboarding/SettingsModal/AskUserModal/Composer/WorkflowEditor/AskAiTrigger 全迁。
- [x] entities ui: FunctionDetail/HandlerDetail/WorkflowDetail/FlowRunDetail/RunDrawer/DocEditor 全迁。
- [x] import 更新 + barrel + props 化。commit + push ✅

---

## Task 4b.5:hooks 归位 + 清空过渡目录 + 删旧 shim ✅

**Files:** `hooks/*` 归位;删空的 `panes/`/`components/`;删旧 shim。

- [x] useDisplayName→entities/user/lib;useEntityName/useCollapsible→shared/lib。
- [x] panes/components/api/sse/store/bridge/motion/hooks 全清空/删除。
- [x] 恢复 12 测试到 FSD 新位置。commit + push ✅

---

## Task 4b.6:阶段 4b 收口(boundaries 全 error + props 化核查 + steiger) ✅

**Files:** `frontend/eslint.config.js`、`steiger.config.js`、`session/@x/user.ts`、plan 文档。

- [x] **Step 1 临时 element 清理**: `eslint.config.js` 全重写 — 移除 shared-tmp/feature-tmp 临时 element(对应目录已删)。boundaries 现在是正式 6 层(app/pages/widgets/features/entities/shared)全 error 单向规则。
- [x] **Step 2 props 化核查**: `grep @app/lower-layers` — 空。pages/widgets/features/entities 零 import app。
- [x] **Step 3 boundaries 全 error**: `npx eslint src` — 0 errors(44 warnings 全是 react-hooks warn 级);零 eslint-disable boundaries 在 prod 代码。
- [x] **Step 4 steiger**: `steiger.config.js` 全重写 — 删迁移期 ignore,改为 test 文件全局 ignore + entities/features/shared 结构违规标 TODO(阶段5)。`npm run fsd` ✔ No problems found!。**解了的**:FunctionDetail/HandlerDetail/WorkflowDetail 的 RunDrawer sidestep(改用 barrel);WorkflowDetail 的 WorkflowEditor sidestep(改用 barrel);Onboarding 的 settings ui sidestep(补 settings/index.ts barrel 暴露 ProviderGrid/KeyVerifyField/ModelSelect);ChatPage/Dashboard/SearchSection 的 @shared/api 子路径 sidestep(改用 @shared/api barrel);useDisplayName→session 跨 slice(创 session/@x/user.ts 并改用该路径)。**留阶段5**:entities→features/pages 反向依赖(RunDrawer 跨 entity-slice、Detail 组件用 forge-review feature、pages 中 CapabilityCheckPanel 等)，已在 steiger.config.js 内 TODO(阶段5) 注释。
- [x] **测试差 4 个说明**: 756 是正确新基线(≠ 760)。差值来自旧 store/settings.js shim 测试文件中 4 个专属测试旧 `useSettings()` hook API 的 it()(`useSettings_defaults_matchSpec`、及两个对老 hook 的 `set_mergesPartialPatch`/`reset_restoresDefaults`/`persist_writesToLocalStorage` 重复测)。旧 shim 已删,对应测试合理删除。新 settingsStore.test.ts 11 个测覆盖全部迁移后功能点。
- [x] **Step 5 验证**: tsc 0 / vitest 756 / build 2.52s / make lint-frontend exit 0 / (make dev 冒烟待人工确认)。
- [x] **Step 6 文档**: plan 勾选完成。

---

## Self-Review

**Spec 覆盖**(spec §11 目录 + §13 阶段4「组合块归 widgets;pane 退化 pages 薄容器」):
- ✅ 组件全迁 FSD 层(pages/widgets/features-ui/entities-ui/app);hooks 归位。
- ✅ props 化解组件→app 反向(AppShell 中枢,pages/widgets 零 app 依赖)。
- ✅ 过渡目录(panes/components)+ 旧 store/api/sse shim 清空。
- ✅ 临时 element 移除,boundaries 全正式层 error。

**风险点**:① props 化改数据流(组件读 store→收 props),行为不变靠 vitest + make dev 逐 page 冒烟 + 严格 1:1 渲染;② 大批量 git mv + import 更新,易漏 import,靠 tsc + build 兜底;③ 入口 main.jsx 位置变,确认 index.html/vite 入口;④ 拆细 task(per-page/per-widget 批),每步可验证。

**Placeholder 扫描**:映射表来自阶段4 调研(文件:层级明确);props 化 SOP 给了等价规则;组件迁移是机械 git mv + import + props 化,不逐组件展开代码(同阶段2/3 批量风格)。

**依赖顺序**:4b.1 app/AppShell 先(props 化中枢)→ 4b.2/4b.3/4b.4 逐层迁 + 接 props → 4b.5 清空 → 4b.6 收口。subagent-driven 按序。
