# Testend V3 — React Rewrite + Backend Dev Infra Cleanup

**创建于**: 2026-05-27
**类型**: brainstorming spec(brainstorming → writing-plans → executing-plans 链上第一环)
**关联**:
- 现状文档:[`documents/version-1.2/adhoc-topic-documents/testend/testend-design.md`](../../../documents/version-1.2/adhoc-topic-documents/testend/testend-design.md)(V2 重写完工记录,2026-05-14)
- 后端 issue log:[`documents/version-1.2/adhoc-topic-documents/testend/testend-rewrite/testend-rewrite-backend-issues.md`](../../../documents/version-1.2/adhoc-topic-documents/testend/testend-rewrite/testend-rewrite-backend-issues.md)
- 后端总规:[`documents/version-1.2/backend-design.md`](../../../documents/version-1.2/backend-design.md)
- 工程纪律:[`CLAUDE.md`](../../../CLAUDE.md) §S14 后端文档同步 + §F1 前端文档同步

---

## 1. Context — 为什么再做

V2 testend(Vue 3 + Pinia + Vite,4 列布局,33 view)在 2026-05-14 完工。此后 13 天后端持续高速迭代——document 域 / relation 域 / memory + compaction / @-mention / 身份重做 / settings redesign / capability disclosure / chat prompt rewrite 等——testend 又一次"基本上用不了"。

根因不是栈选错,而是 **testend 没有和 frontend 共享类型源**:每次后端改 entity / endpoint / SSE protocol,frontend 和 testend 必须各 mirror 一次。13 天就 drift 到"用不了"的根本原因正在这里。

V2 的修补只能短期止痛;不切栈 + 不共享类型,下一个 2 周还会再来一次。本次决策切到 **React 19 + TS + TanStack Query v5 + Zustand v5 + Vite 6**(对齐 frontend 5/27 FSD revamp 后的栈),通过 vite path alias 共享 frontend 的 entity TS 类型,让"backend 改一次字段两边自动跟"。

同时,2 周内后端积累的 testend-only 设施(YAML collections / `/dev/invoke` / 手维护路由清单 / tester.html fallback)在 V3 不再被消费,顺手清理 + 替换为可维护形态(mux 反射自动路由)。

## 2. Goals + Non-Goals

### Goals(本 plan 必交付)

1. **新 testend(React)44 view 完整跑通**(V2 实际 45 view,V3 删 TestCollections 后 44):全部对齐 5/27 后端 entity / endpoint / SSE protocol 现实形态
2. **entity 类型共享机制**:testend 通过 vite path alias 从 `frontend/src/entities/<x>/model/types.ts` import,backend 改字段两边自动跟
3. **backend dev 设施清理**:删 YAML collections / tools+invoke 端点 / tester.html fallback / `Deps.Tools` 字段;改 `/dev/routes` mux 反射自动生成;rename `--integration-dir` → `--testend-dir`
4. **文档全同步**:testend-design.md V3 重写 / api-design.md 删过时端点 / progress-record dev log / 新增 `testend/CLAUDE.md` 子项目工程纪律 / CLAUDE.md 项目根文档地图同步
5. **Verification 全绿**:typecheck 0 / build 0 / staticcheck 0 / `make test-backend` 174 包 / 44 路由 smoke / 真 LLM 跑完整 chat 流

### Non-Goals(本 plan 明确不做)

- 不引入 FSD layered 架构(testend 是 tool,扁平 view-driven)
- 不引入单元测试(typecheck + build + 44 路由 smoke + 真 LLM E2E = 门禁)
- 不重写后端 chat domain(issue #4 Block.Attrs 双形态长期未修,继续 testend 侧 workaround;留独立 plan)
- 不动后端核心思想 / 不引新后端域重构
- 不改 4 列布局 / 不重排 6 section / 不重命名任何 view
- 不引 i18n(testend = dev tool,中英混排即可;不复用 frontend 的 react-i18next)

## 3. Strategy

### 3.1 栈选择(R 方案,对齐 frontend)

| 层 | testend V3 选型 | 同 frontend? |
|---|---|---|
| 框架 | React 19 | ✅ |
| 语言 | TypeScript strict | ✅ |
| 构建 | Vite 6 | ✅ |
| Server state | TanStack Query v5 | ✅ |
| Client state | Zustand v5 | ✅ |
| 路由 | react-router-dom 6 hash mode | ✅(frontend 不用 router,但同包) |
| 样式 | vanilla CSS + CSS 变量 | ✅(frontend 也用 styles/) |
| DAG 渲染 | react-flow 优先 / cytoscape + `react-cytoscapejs` 回退 | frontend 不渲 DAG |
| 代码 / SQL 编辑器 | Monaco editor | frontend `DocEditor` 用 Tiptap,不复用 |
| 图标 | Lucide React | ✅ |

### 3.2 共享边界(frontend ↔ testend)

| 共享层 | 方法 | 理由 |
|---|---|---|
| **entity TS 类型** (`@frontend/entities/<x>/model/types.ts`) | vite resolve.alias + tsconfig paths | drift 唯一源,共享一次根治。**这是切 R 的核心收益。** |
| **错误码常量** | 抽出 `frontend/src/shared/api/errorCodes.ts`(配套小修)| testend 直接显示 code,frontend 走 errorMap → i18n |
| `frontend/src/shared/lib/motion.ts` 动效参数 | alias 共享 | 视觉风格一致(同色 token / 同 easing) |
| **不共享**:React 组件 / hooks / Zustand stores / queryKeys / httpClient / errorMap / SSE 解析 | — | testend UI 密度 + debug 视角 + 错误码原码展示需求差异化;共享会拖重 |

### 3.3 testend 不进 FSD 的明确声明

frontend 在 5/27 完成了 FSD 6 层重构(app/pages/widgets/features/entities/shared),其原因是产品级 SPA 长生命周期需要 layer 解耦。

testend 是开发工具,不是产品。它的视图就是视图,数据就是数据,没有 product feature 层 / widget 组合层这种区分。强行套 FSD = 拖重。

**testend 唯一规则**:
- 扁平 `views/<section>/<View>.tsx`
- 数据访问通过 testend 自己的 `api/*.ts` + `hooks/*.ts`(基于 TanStack Query)
- 状态通过 testend 自己的 `stores/*.ts`(Zustand)
- 跨 view 的可复用 UI 进 `testend/src/ui/`
- **共享 frontend 只通过 type-only 深引**:`import type { Conversation } from "@frontend/entities/conversation/model/types"`。**不经 barrel `index.ts`**(barrel 会把 React hook 运行时一并拉入 testend bundle,破坏 testend 独立 node_modules 假设)。FSD 的 barrel-only 规则只在 frontend 内部生效;testend 是外部消费者,可深引 type 文件。

## 4. 新 testend 目录结构

```
testend/
├── package.json                # React 19 + TanStack v5 + Zustand v5 + Vite 6,版本号手动对齐 frontend
├── vite.config.ts              # resolve.alias 指向 ../frontend/src/<entities|shared|lib>
├── tsconfig.json               # paths 同步 alias
├── index.html
├── CLAUDE.md                   # 新增:testend 子项目工程纪律
└── src/
    ├── main.tsx
    ├── App.tsx                 # 4 列布局,QueryClientProvider 包裹
    ├── router.tsx              # createHashRouter,6 section × 44 route
    ├── style.css               # 4 列布局 + dense UI tokens
    ├── api/                    # testend 独有的 API 客户端
    │   ├── devClient.ts        # 基于 frontend httpClient 模式,但本地实现(testend 不复用 frontend httpClient)
    │   ├── logs.ts             # /dev/logs SSE
    │   ├── sql.ts              # POST /dev/sql
    │   ├── mockllm.ts          # /dev/mock-llm/* 控制
    │   ├── trace.ts            # /dev/llm/trace
    │   ├── info.ts             # /dev/info / runtime / forgify-home / bash-processes
    │   ├── routes.ts           # /dev/routes(反射后简化)
    │   └── sse.ts              # 3 流共享订阅(单 EventSource 模式,沿用 V2)
    ├── stores/                 # zustand,testend 独有
    │   ├── ui.ts               # col widths / expanded / palette / rawJsonModal / toast queue
    │   ├── conv.ts             # 当前 conv 选择 + filter / 列表(testend 自管,不依赖 frontend chatStore)
    │   ├── chat.ts             # raw block tree(debug 视角)
    │   ├── notifications.ts    # /api/v1/notifications 累积
    │   ├── forge.ts            # /api/v1/forge 累积(4 events × 3 kinds)
    │   ├── users.ts            # multi-profile 选择
    │   └── catalog.ts          # /api/v1/catalog(只读快照)
    ├── hooks/                  # TanStack Query hooks
    │   ├── queryKeys.ts        # testend 自管 queryKeys
    │   ├── useConversations.ts / useFunctions.ts / useHandlers.ts / ...
    │   └── useNormalizedBlock.ts  # 兜底 issue #4 Block.Attrs JSON 字符串双形态
    ├── layout/
    │   ├── TopBar.tsx          # build / port / git / 3 SSE pills / ⌘K / expand
    │   ├── ConvSidebar.tsx     # col1
    │   ├── ChatPanel.tsx       # col2(debug 视角,显示 raw block JSON 可选)
    │   ├── TabNav.tsx          # col3
    │   ├── ResizableSplit.tsx
    │   └── UserPicker.tsx
    ├── views/                  # 扁平,**6 section × 44 view**
    │   ├── current/   # 9 view
    │   ├── forge/     # 7 view(删 TestCollections)
    │   ├── execute/   # 5 view
    │   ├── observe/   # 5 view
    │   ├── config/    # 10 view
    │   └── dev/       # 8 view
    └── ui/                     # testend 独有 UI
        ├── RawJsonModal.tsx
        ├── CommandPalette.tsx
        ├── ToastTray.tsx
        ├── EmptyView.tsx
        ├── BlockView.tsx       # raw block 递归 viewer
        ├── KindChip.tsx / StatusBadge.tsx / RelTime.tsx / Pill.tsx
        └── MonacoEditor.tsx    # SQL / 代码编辑器
```

## 5. View Inventory(全部 React 重写,44 view)

▲ = 补缺失字段 / 缺失逻辑;⚠ = 之前漂移厉害;**▲▲** = 大幅功能新建

### 5.1 current/ (9 view)

| view | 处置 | 关键改动 |
|---|---|---|
| Notifications | 重写 | 对齐开放词表 + 5/25 settings/relation/document 新 type |
| Compaction ⚠ | 重写 | 补 `contextRole` 渲染(hot/warm/cold/archived);compaction block 显示 |
| Todos | 重写 | — |
| ToolCalls ▲ | 重写 + 补 resident+lazy 可视化 | 显示当前 active toolset(28 resident + 已激活 lazy 组) |
| WireTrace | 重写 | raw block sequence,parentId chain |
| EventlogRaw | 重写 | raw SSE event dump |
| Attachments | 重写 | — |
| AsksPending | 重写 | ask_user 工具弹自由输入框 |
| SubAgents | 重写 | subagent_run 统一 messages 行展现(attrs.kind=subagent_run) |

### 5.2 forge/ (8 → 7 view)

| view | 处置 | 关键改动 |
|---|---|---|
| Functions / FunctionDetail | 重写 | versions / pending / accept-reject / executions(D22)|
| Handlers / HandlerDetail | 重写 | config state(unconfigured / partially / ready)+ per-call vs Instance 模型 |
| Workflows / WorkflowDetail | 重写 | DAG 试 react-flow(回退 cytoscape);13 节点类型展示;CapabilityChecker 结果 |
| ToolsRegistry ⚠▲ | 重写,**新形态** | resident 28 + lazy 6 组(function/handler/workflow/mcp/document/skill);activate_tools meta-tool 状态 |
| ~~TestCollections~~ | **整删** | 配套删后端 `/dev/collections` + `--collections-dir` |

### 5.3 execute/ (5 view)

| view | 处置 | 关键改动 |
|---|---|---|
| Triggers | 重写 | 4 kind(cron / fsnotify / webhook / manual);FireManual 入口 |
| FlowRuns | 重写 | 列表 + 5 status 过滤 |
| FlowRunDetail ▲ | 重写 + 补 RehydrateOnBoot | 跨进程重启后状态展示 |
| ApprovalsQueue | 重写 | pause/resume + nodeApprove |
| Executions | 重写 | function executions(D22)+ handler calls(D22)+ mcp calls(D22)+ skill executions(D22) |

### 5.4 observe/ (5 view)

| view | 处置 | 关键改动 |
|---|---|---|
| LiveSSE | 重写 | reset-to-0 + Last-Event-ID 重连可视化 |
| NotificationHistory | 重写 | — |
| Catalog | 重写 | 对齐单端点 `GET /catalog`(5/25 已对齐,V3 沿用) |
| Usage | 重写 | input/output token 总账(从 message.inputTokens/outputTokens 聚合) |
| MockLLM ⚠ | 重写 | 对齐 `/dev/mock-llm/scripts` POST/DELETE / `queue` GET / `last-prompt` GET |

### 5.5 config/ (10 view)

| view | 处置 | 关键改动 |
|---|---|---|
| ApiKeys ⚠ | 重写 + 补 is_default | per-category 单选(5/25 settings-redesign) |
| ModelConfigs | 重写 | scenario 白名单从 `GET /scenarios` 拉(5/24 新端点) |
| Skills ▲ | 重写 + 补 frontmatter 全字段 | Anthropic SKILL.md spec cross-vendor 字段(whenToUse / allowedTools / userInvocable 等) |
| MCPServers ⚠ | 重写 | marketplace V3 形态;5 status(disconnected/connecting/ready/degraded/failed);health 历史 |
| Sandbox ⚠ | 重写 | sr_ runtime + se_ env(5 类 owner);LRU N=3;EnvStatus 5 态 |
| Memory | 重写 | 4 type(user/feedback/project/reference)× 2 source(user/ai);pinned 控件 |
| **Documents ▲▲** | 重写 + **补 Notion 树 + Monaco 编辑器**(5/16 推迟的 §14.5)| 树形导航 + 拖拽 + position / parentId / 子树包含切换 |
| Permissions ⚠ | 重写 | 5/8 §3 final-sweep 后形态(permission rules + hooks system) |
| LLMHealth | 重写 | provider 连通性 / 历史 |
| Profile | 重写 | user CRUD(multi-profile,5/24 user-identity cleanup 后) |

### 5.6 dev/ (8 view)

| view | 处置 | 关键改动 |
|---|---|---|
| SQL | 重写,**改 Monaco** | textarea → Monaco;快捷表名按钮保留 |
| Info | 重写 | 对齐 `/dev/info` 当前字段 |
| Routes ⚠ | 重写,**后端反射自动**后大幅简化 | 直接显示后端返回的路由清单,无客户端逻辑 |
| BackendLogs | 重写 | `/dev/logs` SSE + level filter / 关键词 / auto-scroll |
| Processes | 重写 | bash 子进程列表 |
| Metrics | 重写 | `/dev/runtime`(uptime / goroutine / mem / GC / dbSize) |
| Errors | 重写 | errmap 全表 + 历史 |
| **Prompts ⚠⚠** | **重写,段名全变**(5/27 chat prompt rewrite)| identity / how_to_work / tools / environment;删 multi_agent_forging 段 |

## 6. Backend 清理(配套同 PR)

### 6.1 删

| 路径 | 删除项 |
|---|---|
| `backend/internal/transport/httpapi/handlers/dev.go` | `collectionsHandler` + `toolsHandler` + `invokeHandler` 三个 handler 及其挂载 |
| `backend/internal/transport/httpapi/handlers/dev.go::ServeIndex` | 删 tester.html 双 fallback(v1 tester.html 已不存在),只读 index.html |
| `backend/internal/transport/httpapi/router/deps.go` | 删 `Deps.Tools []agentapp.Tool` + `Deps.CollectionsDir` 字段 |
| `backend/cmd/server/main.go` | 删 `--collections-dir` flag 解析 + Tools 注入 |
| `testend/collections/` | 整目录删(当前已空)|

### 6.2 改

| 路径 | 改动 |
|---|---|
| `backend/internal/transport/httpapi/handlers/dev_routes.go` | 整重写为**注册时记录**自动生成路由清单。**实施细节**:stdlib `*http.ServeMux` 没有 Walk API,不能事后反射;改用**包装层** `router.Recorder` 在 deps 里替代 `*http.ServeMux`,`Recorder.HandleFunc(pattern, h)` 调底层 mux + 同时 append 到 `[]Route{Method, Path, Handler}`。`/dev/routes` handler 读 `Recorder.List()` 直接返。消除手维护 drift(testend-rewrite issue #3 根治)。 |
| `backend/cmd/server/main.go` + Makefile + 文档 | `--integration-dir` rename → `--testend-dir`(更明确) |
| `frontend/src/shared/api/errorCodes.ts` | **新增**:从 `errorMap.ts` 抽出 code 常量集,供 testend 通过 alias 复用 |

### 6.3 保留

| 路径 | 状态 |
|---|---|
| `backend/internal/infra/logger/broadcast.go` + `/dev/logs` | 保留(真有用) |
| `POST /dev/sql` | 保留 |
| `GET /dev/info` / `runtime` / `forgify-home` / `bash-processes` | 保留 |
| `/dev/mock-llm/scripts` / `queue` / `last-prompt` + `DELETE /dev/mock-llm/scripts` | 保留 |
| `GET /dev/llm/trace` | 保留 |

## 7. 已知 Issue 处理

### 7.1 issue #4 — Block.Attrs REST/SSE 双形态

后端 `infra/store/chat` repo GetMessages/ListMessages 出口处 `Block.Attrs` 是 JSON 字符串;SSE `block_start` payload `Block.Attrs` 是对象。同 entity 两条传输路径两种形态。

**本 plan 不修后端**(留独立 plan 给 chat domain 重写)。testend 写一个 hook `useNormalizedBlock(block)`,内部 `parseMaybeJSON(block.attrs)`,所有 view 经此 hook 拿 block。

issue log 续记:在 `testend-rewrite-backend-issues.md` 加 V3 段,标注 "long-term 后端 fix still pending"。

### 7.2 issue #5(新)— `sse.ts` 注释 `5×6` block types

V2 sse.ts 注释说 `5 events × 6 block types`,实际 5/14 后 `compaction` block 已加入,7 block types。

**行动**:V3 testend 内不存在此 drift(新写);issue log 记录 V2 sse.ts 历史漂移,作为"为什么需要共享 type"的实证。

### 7.3 issue #6(新)— ID prefix 列表不全 + 已废

V2 testend `types/api.ts::IDPrefix` 缺 `hdi_` / `rel_` / `mch_` / `sr_` / `se_` / `u_`;有已废的 `sar_` / `smm_`(subagent 改为 messages 行 attrs.kind=subagent_run)。

**行动**:V3 testend 不维护自己的 IDPrefix 联合类型,改从 frontend 共享的 entity 类型 import(因为前缀语义嵌在每个 entity 的 `id` field 注释里)。issue log 记录。

### 7.4 issue #7(新)— `dev_routes.go` 手维护清单 drift

testend-rewrite issue #3 已指出,但只是改了一次清单内容。手维护清单天然 drift,5/14 后又 drift 了。

**行动**:`dev_routes.go` 改用 mux 反射(遍历后端 mux 注册表,自动列出所有 `mux.HandleFunc` / `mux.Handle` 注册的 path + method)。**根本性消除 drift**。

## 8. Verification 三层

| 层 | 命令 / 动作 | 通过条件 |
|---|---|---|
| 静态 | `cd testend && npm run typecheck && npm run build` | 0 error / 0 warning;dist 产物 < 1 MB gzip(cytoscape lazy chunk 不算) |
| 静态 | `cd backend && go build ./... && staticcheck ./...` | 0 error |
| 静态(回归) | `make test-backend` | 174 包全绿 |
| 动态 | `make testend` 起来,浏览器自动打开 `http://localhost:8742/dev/` | health 200 + 44 路由不 404 |
| 动态(手动) | 终端 walk 44 view + 触发完整 chat 流 | 0 console error / SSE 三流连接 / 真 LLM 跑完整 user → assistant streaming → tool call → tool result → message_stop 链路 |

## 9. 实施工作流(5 phase)

| Phase | 内容 | 估时 |
|---|---|---|
| **P0** | Backend 清理 + Recorder PR:删 collections / tools / invoke handler / Deps.Tools / `--collections-dir` flag / tester.html fallback;**新建 `router.Recorder` 包装 `*http.ServeMux`**(同时记录注册的 Method+Path+Handler);改 `/dev/routes` 读 Recorder;rename `--integration-dir` → `--testend-dir`。frontend 抽 `shared/api/errorCodes.ts` 常量集。`make test-backend` 全绿。一 commit。 | 0.5-0.75 d |
| **P1** | testend 原地推倒。`git rm -rf testend/src/ testend/collections/ testend/package.json testend/package-lock.json testend/vite.config.ts testend/tsconfig.json testend/tsconfig.node.json testend/eslint.config.js`(如有)+ 任何 V2 残留;保留 `testend/.gitignore`(若存在)。新写 `package.json`(React 19 + TanStack v5 + Zustand v5 + Vite 6 + react-router-dom 6 + lucide-react + monaco-editor + reactflow + zod 视需要)、`vite.config.ts`(`resolve.alias` 指 `../frontend/src/{entities,shared,lib}`)、`tsconfig.json`(`paths` 同步 alias)、`index.html`、`src/main.tsx`、`src/App.tsx`(4 列骨架 + QueryClientProvider)、`src/router.tsx`(44 route,view 全用占位 `<div>TODO {name}</div>`)、`src/style.css`(4 列布局 + tokens 抄 frontend)。`npm run typecheck` 0 / `npm run build` 0,空白 44 view 占位。 | 0.5 d |
| **P2** | 基础设施:`api/devClient.ts`(本地实现 httpClient pattern,基于 fetch + envelope unwrap + ApiError)/ `api/sse.ts`(3 流单 EventSource 订阅,fan-out)/ 7 zustand stores(ui+conv+chat+notifications+forge+users+catalog)/ 共享 entity types 通过 alias 深引 type 文件接上 / TanStack QueryClient + testend 自管 queryKeys / 4 layout 组件(TopBar/ConvSidebar/ChatPanel/TabNav/ResizableSplit)/ testend ui kit(RawJsonModal/CommandPalette/ToastTray/EmptyView/BlockView/MonacoEditor lazy chunk) | 1 d |
| **P3** | 44 view 实现。建议 section 顺序:先 `dev/`(8;最少依赖,先打通 SQL/logs/Monaco 助调试其他 view)→ 再 `current/`(9;chat 主链路,带动 BlockView 完善)→ 再 `config/`(10;多但简单)→ `forge/`(7;复杂)→ `execute/`(5;依赖 forge entity)→ `observe/`(5)。section 顺序非硬约束,implementation plan 可调整。提交粒度:每 view 1 commit 或邻近 2-3 view 1 commit;每 commit 立即 push。共 ~25-40 commits。 | 2-3 d |
| **P4** | Verification 全跑通;文档同步:testend-design.md V3 重写 + api-design.md 删过时端点 + progress-record dev log + 新增 testend/CLAUDE.md + 项目根 CLAUDE.md 文档地图 + issue log V3 段。最后 1 commit. | 0.5 d |
| **合计** | | **5-6.5 d** |

**Commit 纪律**:
- 小步、push 跟每次 commit(per memory `feedback_auto_push.md` 投资人可见)
- 不开分支(per memory `feedback_main_only_no_branches.md`)
- 不在 commit message 加 `Co-Authored-By: Claude`(per memory `feedback_commit_attribution.md`)
- 原 Vue testend 通过 git 历史可查(`git show HEAD~N:testend/src/...`),不留 `testend-vue-legacy/` 旁副本

## 10. 文档同步(§S14 + §F1)

| 文档 | 行动 |
|---|---|
| `documents/version-1.2/adhoc-topic-documents/testend/testend-design.md` | **完整重写为 V3 React 形态**(目录结构 / 共享策略 / view inventory / verification) |
| `documents/version-1.2/service-contract-documents/api-design.md` | 删 `/dev/collections` / `/dev/tools` / `/dev/invoke` 端点段;`/dev/routes` 标注"反射自动生成";`--integration-dir` 旧名 → `--testend-dir` |
| `documents/version-1.2/progress-record.md` | 一条 dev log:`[feat] testend V3 React 重做 + backend dev 设施清理`(~30-100 字 §S19) |
| `documents/version-1.2/adhoc-topic-documents/testend/testend-rewrite/testend-rewrite-backend-issues.md` | 续 V3 段:append issue #5/#6/#7;V2 issues #1-#4 加历史说明 |
| `testend/CLAUDE.md` | **新增**:子项目工程纪律(共享 alias 规则 / view 扁平不进 FSD / 不引单测 / 与 frontend 版本号同步 / commit / push 纪律) |
| `CLAUDE.md`(项目根) | 末节"前端开发守则"加一段链接到 `testend/CLAUDE.md`;文档地图加 V3 testend-design 链接 |
| `frontend-contract-documents/*.md` | **不动**(testend 不进 FSD) |
| `service-design-documents/*.md` | **不动**(testend 不属于任何后端 domain) |

## 11. 风险 + Known-Unknowns

| 风险 | 影响 | 对策 |
|---|---|---|
| testend 与 frontend 的 React/TanStack/Zustand 版本号 drift → 运行时 "Multiple React instances" | 中 | `testend/CLAUDE.md` 强制声明"deps 版本号手动从 frontend 抄";每次新 testend build 前 `npm ls react` 检查;若两 node_modules 都拿到同版本则无冲突 |
| frontend 未来重命名 `entities/<x>/model/types.ts` 路径 | 低 | `CLAUDE.md §F1` 加一条:"重命名 entity types 路径需同步 testend vite/tsconfig alias" |
| cytoscape → react-flow 功能差距(WorkflowDetail DAG) | 中 | 真做的时候确认 react-flow 覆盖 V2 用到的功能(loop body subgraph / dry-run 等);不够用就继续 cytoscape via `react-cytoscapejs`。本 plan 默认尝试 react-flow,fallback 已就绪 |
| **issue #4 Block.Attrs 双形态长期未修** | 低(workaround 一直在) | 不在本 plan 修后端;testend hook `useNormalizedBlock` parseMaybeJSON;issue log 续记 long-term 后端 fix |
| backend dev 设施清理可能拽出 hidden 依赖(比如 dev tool 被某个 doc 引用 / 某 dev curl 脚本依赖) | 低 | 删之前 grep 全仓 + doc 同 PR 删除 |
| **mux 反射:backend 用 stdlib `*http.ServeMux`(无 Walk API)** | 中 | **已定方案**:写 `internal/transport/httpapi/router/recorder.go`——`Recorder` 包装 `*http.ServeMux`,提供 `HandleFunc(pattern, h)` 调底层 + append 到 `[]Route{Method, Path}`;`List() []Route` 给 `/dev/routes` 用。所有 router 注册改走 Recorder。预计 0.25 d。 |
| testend 切栈后 5/14 V2 投入"丢失" | 低-中 | 5/14 V2 主要交付是布局 + view 列表 + 数据流模式。这些**作为设计输入**完整继承到 V3,只是实现代码重写。视觉细节通过对照 git 历史 `testend/src/views/...` 完成 |
| Monaco 体积大(~3-5 MB) → testend bundle 膨胀 | 低 | lazy chunk(只 SQL view 和 Prompts view 加载);CDN 加载 monaco-editor 也是选项,本 plan 默认 bundle |

## 12. 完成的硬定义

- 44 view 全部能加载、不 404、无 console error
- 三 SSE 流(eventlog / notifications / forge)连接 + 收到事件 + view 反映
- 发一条真消息从 user message → assistant streaming → tool call → tool result → message_stop,所有 block 显示完整、状态对、parentId 链可视化
- `npm run typecheck` 0 / `npm run build` 0
- `cd backend && go build ./... && staticcheck ./...` 0
- `make test-backend` 174 包全绿
- 9 处文档同步全 done(testend-design / api-design / progress-record / issue log / testend/CLAUDE.md / 项目根 CLAUDE.md + 任何顺手发现的 doc drift)

## 13. 此 spec 之后

→ 用 `superpowers:writing-plans` skill 生成 phase 化 implementation plan(把 §9 的 5 phase 拆到 step 粒度,每 step 含命令、文件、验证、commit message 模板)。
→ 然后 `superpowers:executing-plans` skill 执行 plan,与本 spec 对账。
