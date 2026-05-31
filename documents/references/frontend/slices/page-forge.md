# pages/forge — 前端 slice 详细设计

**所属层**：pages（聚合 entities/function + entities/handler + entities/workflow + widgets/version-rail + widgets/ask-ai-trigger + widgets/entity-rel-meta）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：function / handler / workflow 的列表 ↔ 详情路由器。`focusEntity.forge` 驱动从外部（EntityLink、cmdk）预打开指定实体；三种类型共用一套 list → probe → detail 跳转逻辑。

---

## 1. 职责边界

| 子职责 | 说明 |
|---|---|
| list ↔ detail 路由 | 内部维护 `open: OpenEntity | null`；null = 列表，非 null = 对应详情 |
| focusEntity 消费 | 接收 `focusEntity.forge` → 并发 probe 3 个 detail 端点 → 哪个有 data 就 open 对应 kind |
| 动画 | `fadeIn`（列表）/ `slideUp`（详情）；AnimatePresence mode="wait" |
| FunctionDetail | 函数代码 + 版本轨（pending/current/deployed）+ AI 迭代 + 关系 meta |
| HandlerDetail | HTTP 处理器配置 + 版本轨 + AI 迭代 + 关系 meta |
| WorkflowDetail | 工作流 YAML/可视化 + 版本轨 + 触发执行 → onOpenExecute |

---

## 2. Props 接口

```ts
interface ForgePageProps {
  focusEntity?: { forge?: string; [key: string]: unknown };
  onConsumeFocusEntity: (pane: string) => unknown;
  onOpenExecute?: (id: string) => void;   // 触发 WorkflowDetail "运行" → execute pane
}
```

AppShell 从 paneStore 提取 `focusEntity` / `consumeFocusEntity` / `setActiveFlowRun` 后传入。

---

## 3. focusEntity 解析流程

```
focusEntity.forge = id
  ↓
并发: useFunction(id) / useHandler(id) / useWorkflow(id)
  ↓
首个 data 非 null:
  → setOpen({ ...entity, kind })
  → onConsumeFocusEntity("forge")   // 清除 focusEntity.forge 防重复触发
```

后端无统一 /entities 端点，因此需三路并发 probe。useEffect 监听三个 data 字段，任一命中即消费。

---

## 4. UI 子组件

| 组件 | 文件 | 职责 |
|---|---|---|
| `ForgeList` | `ui/ForgeList.tsx` | 三 tab（Function/Handler/Workflow）列表 + 创建按钮 |
| `FunctionDetail` | `ui/FunctionDetail.tsx` | 函数详情：代码 + VersionRail + AskAiTrigger + EntityRelMeta |
| `HandlerDetail` | `ui/HandlerDetail.tsx` | 处理器详情：配置 + VersionRail + AskAiTrigger + EntityRelMeta |
| `WorkflowDetail` | `ui/WorkflowDetail.tsx` | 工作流详情：YAML/图 + VersionRail + AskAiTrigger + EntityRelMeta + 触发执行 |

---

## 5. 数据流

```
列表:
  useFunction/Handler/Workflows()  → 三 tab 列表数据

详情:
  useFunction/Handler/Workflow(id)           → 实体元数据
  useFunctionVersions / HandlerVersions /
  WorkflowVersions (id)                      → VersionRail 数据
  onAccept → PATCH /versions/{id}            → 接受 pending
  onRevert → DELETE /pending-versions/{id}   → 丢弃 pending
  onDeploy → POST /handlers/{id}:deploy      → 部署 Handler

SSE forge 事件:
  useForgeProgress                (shared/model)
  → 详情头部 "锻造中..." 进度指示
```

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/pages/forge/ForgePage.tsx` | 主路由组件 |
| `frontend/src/pages/forge/ui/ForgeList.tsx` | 三 tab 列表 |
| `frontend/src/pages/forge/ui/FunctionDetail.tsx` | 函数详情 |
| `frontend/src/pages/forge/ui/HandlerDetail.tsx` | 处理器详情 |
| `frontend/src/pages/forge/ui/WorkflowDetail.tsx` | 工作流详情 |
| `frontend/src/pages/forge/index.ts` | public API export |
