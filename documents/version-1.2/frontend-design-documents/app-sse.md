# app/sse — 前端 slice 详细设计

**所属层**：app（被 App.tsx SSEProvider 消费；向下通过 context / props 暴露健康状态）
**状态**：✅ 已实现（FSD Revamp 阶段 0–4 完成）
**职责**：单例挂载后端三条 SSE 连接。eventlog → chatStore；notifications → query invalidate + pendingAsk；forge → forgeProgress store。合成健康状态通过 React context 向下传递。

---

## 1. SSEProvider

```tsx
export function SSEProvider({ children }: { children: React.ReactNode })
export function useSSEHealth(): { overall: string; eventlog: string; notifs: string; forge: string; unread: number; clearUnread: () => void }
```

内部调用三个 hook，useMemo 合并成一个 context value：

```ts
{
  eventlog: string;     // "connecting" | "connected" | "disconnected"
  notifs: string;
  forge: string;
  unread: number;
  clearUnread: () => void;
  overall: string;      // 派生：all connected → "ok"; any disconnected → "err"; else "warn"
}
```

挂在 App 根（包裹 Onboarding 和 AppShell），确保三条 SSE 在 boot 阶段就建立，不等到 AppShell 才订阅。

---

## 2. useEventLog（`sse/useEventLog.ts`）

**端点**：`GET /api/v1/eventlog`
**触发重连**：`activeUserId` 变化（切账号）→ 旧 EventSource 关闭，新 EventSource 建立。

| SSE event name | 处理 |
|---|---|
| `message_start` | `chatStore.ensureConv(convId)` + `onMessageStart(convId, ev)` |
| `message_stop` | `chatStore.onMessageStop(convId, ev)` |
| `block_start` | `chatStore.ensureConv(convId)` + `onBlockStart(convId, ev)` |
| `block_delta` | `chatStore.onBlockDelta(convId, ev)`（rAF batch）|
| `block_stop` | `chatStore.onBlockStop(convId, ev)` |

返回 `status: string`（连接状态），供 SSEProvider 聚合到 overall。

---

## 3. useNotifications（`sse/useNotifications.ts`）

**端点**：`GET /api/v1/notifications`
**触发重连**：`activeUserId` 变化。

SSE event name 固定为 `"notification"`，payload 格式：`{ type, id, data, conversationId }`。

| payload.type | 处理 |
|---|---|
| `ask`（action=pending 或无 action）| `setPendingAsk({ id, conversationId, toolCallId, ...data })` |
| `ask`（action=resolved）| `setPendingAsk(null)` |
| `conversation` | invalidate `qk.conversations()` + `qk.conversation(id)` |
| `function` | invalidate functions() + function(id) + functionVersions(id) |
| `handler` | invalidate handlers() + handler(id) + handlerVersions(id) + handlerConfig(id) |
| `workflow` | invalidate workflows() + workflow(id) + workflowVersions(id) |
| `flowrun` | invalidate flowruns() + flowrun(id) + flowrunNodes(id) |
| `mcp_server` | invalidate mcpServers() |
| `skill` | invalidate skills() |
| `compaction` | invalidate conversation(id)（对话元数据刷新） |
| `memory` / `todo` / `sandbox_env` | 无 invalidation |

非 ask 类型事件 → `setUnread((n) => n + 1)`，sidebar footer badge 反映计数。

返回：`{ status, unread, clearUnread: () => setUnread(0) }`。

---

## 4. useForge（`sse/useForge.ts`）

**端点**：`GET /api/v1/forge`
**触发重连**：`activeUserId` 变化。

事件写入 `useForgeProgress`（`shared/model/forgeProgress`），不写 entities 层 store，避免反向依赖。

| SSE event name | 处理 |
|---|---|
| `forge_started` | 创建 `active[scopeKey] = { scope, operation, conversationId, toolCallId, ops:[], status: "running" }` |
| `forge_op_applied` | `active[scopeKey].ops.push({ index, op })` |
| `forge_env_attempt` | `active[scopeKey].envAttempts.push({ attempt, status, stage, detail, error })` |
| `forge_completed` | 更新 status/versionId/envStatus/attemptsUsed/finishedAt；invalidate entity caches（functions/handlers/workflows + 对应 id）|

`scopeKey = "${scope.kind}:${scope.id}"`，用作 forgeProgress store 的 key。

---

## 5. createSSE（shared/api/sse）

三个 hook 都通过 `createSSE({ path, eventHandlers, onStatus })` 创建 EventSource：

- `path` 补全为 `/api/v1{path}`
- `eventHandlers`：事件名 → handler 映射
- `onStatus(status)`：连接状态回调（connecting / connected / disconnected）
- 返回 `{ close() }` 供 useEffect cleanup

---

## 6. 实现清单

| 文件 | 说明 |
|---|---|
| `frontend/src/app/sse/SSEProvider.tsx` | Provider + useSSEHealth context hook |
| `frontend/src/app/sse/useEventLog.ts` | eventlog SSE → chatStore dispatch |
| `frontend/src/app/sse/useNotifications.ts` | notifications SSE → query invalidate + pendingAsk |
| `frontend/src/app/sse/useForge.ts` | forge SSE → forgeProgress store + entity cache invalidate |
