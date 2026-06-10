# Round 0064 — 波次6：ask + danger 人在环（内存阻塞 humanloop）

类型 / 目标：给 ReAct 循环接上人在环——agent 主动问用户（**ask**）、危险工具执行前等批准（**danger**）。

## 为什么是内存阻塞、不是 durable（回退记录）

第一版（durable park：释放 goroutine + 持久化 parked + 续跑回合 + transcript 重放 + ParkSignal 嵌套冒泡）已**整体回退**（`5137cd46` 回退 `a8a602ac..bd0885df`）。原因：durable 是**服务器级机器，对单进程桌面 app 是 overkill**——「跨重启存活」对桌面≈「跨崩溃」（app 关了就没 agent 在跑），收益极低却带来大量复杂度（尤其嵌套的 ParkSignal/级联/重放）。deep-research 也确认内存阻塞是合法的业界变体（只是非分布式那套）。

**内存阻塞的关键好处**：工具就地阻塞等 resolve，**嵌套天然就对**——子 agent 的工具阻塞 → 一路 hold 住上面的 goroutine，无需任何传播/级联/重放。可抽成**一个干净的 `humanloop` 包**。

## 机制

```
ask_user.Execute / danger 门控  ──►  humanloop.Broker.Request(ctx, req)
                                       │  注册 pending（按 toolCallId）
                                       │  surface：发一条 interaction signal（messages 流，对话 scope）
                                       └─ 阻塞 select { <-resp chan | <-ctx.Done() }
前端看到 signal → 渲提示 → POST /conversations/{id}/interactions/{toolCallId} {action, answer?}
                                       │
Broker.Resolve(toolCallId, resp) ──► 送 chan → Request 返回 → 工具/门控接着跑
```

- **`humanloop` 包**（`internal/app/humanloop`）：`Broker`（`pending map[toolCallId]chan Response` + `allow` 会话白名单 + 注入的 `surface` func）。`Request(ctx, Request)(Response,error)` 注册+surface+阻塞；`Resolve(toolCallId, Response)`；`IsAllowed/Allow`（always-allow）；ctx `WithBroker/From`。
- **ask**：`ask_user` 工具的 `Execute` 调 `humanloop.From(ctx).Request({kind:ask, message, options})` → 阻塞 → 返回答案当 tool_result。**loop 零改动**（它就是个会阻塞的普通工具）。
- **danger**：loop `runOneTool` 执行前的门——`if b := humanloop.From(ctx); b != nil && tc.Danger=="dangerous" && !b.IsAllowed(...)` → `Request({kind:danger, ...})` → approve 落 executeTool / deny 出「拒绝」tool_result / approve_always 顺带 `b.Allow(...)`。无 broker（subagent/workflow/standalone）→ 不门控、纯信任（现状）。
- **嵌套**：broker 在 chat 的 processTask ctx 里 seed，**随 ctx 流进子 agent**；子 agent 的工具/门控阻塞 → invoke_agent.Execute 阻塞 → chat 回合的 goroutine 阻塞。surface 用 ctx 里的 conversationId → 信号落到 chat 对话（用户就地看到子 agent 的待批准）。**零额外机制**。
- **surface = messages 流 signal**（对话内联，最佳常用 UX）：`signal` + `node{type:"interaction", content:{toolCallId, kind, tool, prompt}}`。（跨对话提醒用通知是个易加的增强，先不做。）
- **resolve 端点**：`POST /conversations/{id}/interactions/{toolCallId}` → `Broker.Resolve`。
- **cancel**：用户取消（现有 `DELETE /stream` → q.cancel）→ ctx.Done → Request 返 ctx 错 → 工具/loop 收尾。**复用现有 cancel，零新增**。
- **always-allow**：broker 的会话白名单（按 conversationId+tool），approve_always 时 Allow。deny-first 平凡成立。
- **回合不 parked**：阻塞期间 message 一直 streaming（开着），整回合是**一条连续 message**（中间停一下）——「统一暂停」手感天然。无 parked 状态、无续跑回合、无 transcript 重放。
- **重连/刷新**：broker 的 pending map 是内存真相；加一个 `GET /conversations/{id}/interactions`（列本对话 pending）供前端重连重新同步。

## 范围

- **chat + 嵌套 agent（chat 里 invoke_agent 委托的子 agent）**：覆盖（都在 chat 的后台 goroutine 里跑、阻塞安全）。
- **standalone agent REST `:invoke`**：暂不门控（同步 HTTP 阻塞会挂请求；要支持需改异步——**缓做**，无 broker = 纯信任）。
- **workflow/sensor agent**：不门控（自动语境、纯信任；人工门用 workflow 的 approval 节点）。

## 与 durable 版的对比（删掉了什么）

删：parked 状态（message/agent_executions）· 续跑回合（driveContinuation）· transcript 重放（ResumeExecution）· ParkSignal + 末尾扫描 · AgentResumer 端口/适配器 · UpdateExecution · executeApprovedTool（两份）· 5 处散落的 resolve 逻辑。
留（业界标准内核，内存版照样在）：interrupt-before-side-effect（danger approve 前不执行）· deny 当 tool_result 反馈 · ask 三态（accept/decline/cancel）· always-allow + deny-first。

## 分期

| 期 | 内容 |
|---|---|
| **H0** | `humanloop` 包：Broker + Request/Resolve/IsAllowed/Allow + ctx + 类型 + 测 |
| **H1 danger** | loop runOneTool 门控（broker 在 ctx 时）+ chat seed broker/surface + resolve 端点 + always-allow + 测 |
| **H2 ask** | `ask_user` 工具（Execute 调 Request）+ 测 |
| **H3 列表/重连** | `GET /conversations/{id}/interactions`（列 pending）+ 测 |
| 文档 | events.md（interaction signal + resolve）+ api.md（2 端点）+ humanloop 设计 + contract-changes + lab |

研究对标（保留有效结论）：interrupt-before-side-effect、deny-as-tool_result、MCP elicitation 三态、deny-first——内存版全保留；durable 那套基础设施（checkpointer/replay/signal 路由）对单进程桌面是 overkill，删。
