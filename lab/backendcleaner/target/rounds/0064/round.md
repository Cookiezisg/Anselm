# Round 0064 — 波次6：ask + danger（durable human-in-the-loop for the chat/agent loop）

类型 / 目标：给**内存 ReAct 循环**（chat + agent invoke）接上「人在环」——agent 主动问用户（**ask**）、危险工具执行前等批准（**danger**）。两者共享同一核心：循环 yield 给人 → 露出 → 等回应 → 恢复。

## 研究校准（deep-research R0063-followup，wq96oht5i）

我们选定的方向（park 半截回合成 durable 行、释放 goroutine、HTTP resolve 填 pending tool_result 驱动续跑）**正是业界标准 durable HITL，非重新发明**。横跨 Temporal / Restate / OpenAI Agents SDK / LangGraph / LangChain / Claude Code / MCP，三条不变量一致：(1) 等待期**释放执行进程**、由独立 durable 记录持暂停态；(2) **interrupt-before-side-effect**（pending 时不跑危险工具，非跑了再撤）；(3) **记忆化已完成步**使 resume 不重跑。

逐条确认 + 校准：

| 判定点 | 业界标准 | Forgify 现方向 |
|---|---|---|
| ① park/resume 模型 | resume = 把决议当 data 填进 pending execution（非起新顶层调用）；resume 模型有多种（replay / 反序列化态 / 重读历史），**重读历史是正经成员** | ✅ 填 tool_result 驱动续跑、循环重读历史——sound |
| ① 历史即 checkpoint | 记忆化完成步 = Temporal activity-history / Restate ctx.run（**正经变体**） | ✅ 完成的 tool_result 在 transcript 里、续跑重读不重跑 |
| ② exactly-once / 重跑坑 | LangGraph 真坑：node 含 interrupt 会从头重跑、之前副作用重复。**修法 = 记忆化完成步** | ✅ 天然绕开。**硬约束：danger 工具必须 resolve 时执行+落盘结果，续跑只重读** |
| ② at-least-once | Temporal 默认 at-least-once；"exactly-once 业务效果" = at-least-once + 幂等。任意外部副作用无人能真 exactly-once | ⚠️ execute→落盘有崩溃窗口（见 §6），单进程风险低，落盘用 tx，接受 |
| ③ 决议集 | approve / deny 普适；**always-allow 真标准**（OpenAI sticky）；**edit-args 非普适**（LangChain 有/OpenAI 无） | approve/deny v1；always-allow 选做；edit-args 缓做 |
| ③ deny 反馈 | deny → 不执行 → 解释性消息当 tool_result → agent 改道（LangChain 文档标准） | ✅ deny → tool_result="用户拒绝…" |
| ③ deny-first 优先级 | deny → ask → allow 首匹配胜（Claude Code）；always-allow 不能盖过 danger 门 | ✅ always-allow 不静默放行 danger 自报 |
| ④ ask 形态 | MCP elicitation：schema-typed 请求（扁平对象/原始类型）+ 三态 **accept / decline / cancel** | ✅ 镜像之；decline（真信号、反馈）vs cancel（放弃）区别对待 |
| ⑤ 本质 vs 偶然 | 独立 checkpointer 服务 / 分布式 signal / 任务队列 / worker 池 / 序列化执行图 = **overkill 该删**；durable 记录 / exactly-once / resume / 取消 = **本质** | ✅「复用 parked 行 + 重读历史」替代全部基础设施，无遗漏本质件 |

**驳回项（不据此建）**：idempotency-key 非唯一正解（记忆化同样 canonical）；Claude Code 不按危险度分层 always-allow 持久化；edit-args 非天生双执行；replay 非唯一 resume 模型。

## 核心模型：park → pending tool_result → resolve → 续跑

**一套机制，两个调用方（danger 门控 + ask 工具），两个落盘目标（chat messages / agent_executions）。**

```
loop 跑一步 → N 个 tool_call
  ├─ safe 调用：正常执行、出 tool_result
  └─ park 调用（danger==dangerous 或 InteractiveTool）：不执行，出 PENDING tool_result
若有 park 调用 → 回合以 status=parked 落盘（M1：safe 的 call+result + park 的 call+pending result）→ 循环停、释放 goroutine
                                  ↓ （durable，跨重启存活）
HTTP resolve（逐个 pending 决议）→ 填那条 tool_result → 当 M1 再无 pending → 驱动续跑回合 M2
                                  ↓
续跑 loop.Run（vanilla）重读历史（含已填 result）→ 继续 ReAct
```

- **不建新表**：「待办收件箱」= 查 status=parked 的 message / 含 pending tool_result 的行（正如 approval 收件箱 = parked 节点行）。
- **M1 + M2 两条 message**：LLM API 本就在 tool_call/tool_result 处强制边界；续跑是 vanilla loop.Run（无需 reopen M1）。前端按一个连续 agent 回合渲染（「统一暂停」手感，纯前端事）。
- **并行**：一步内 safe 全跑、park 全 pending（可多条 pending），**全部 resolve 后**才续跑（查无 pending 即续）。投影合法（每个 tool_call 都有 result 块）。

## danger（危险工具门控）

- **门**：`runTools` 里，`tc.Danger == "dangerous"` 且未 always-allow → park（出 pending tool_result，不执行）。cautious/safe 不门控（cautious 仅前端标记，维持 S18 现状）。
- **决议集**（resolve endpoint）：
  - **approve** → **resolve 时执行该工具**（resolve handler 取 toolset + 重建 ctx + 调 Execute）→ tool_result=输出 → 续跑重读（不重执行）。
  - **deny** → tool_result="用户拒绝执行此操作"（不执行）→ 续跑、LLM 改道（LangChain 标准）。
  - **always-allow**（选做，phase D4）：会话级工具名白名单（内存或 SQLite），命中则门直接放行（不 park）。deny-first：danger 自报仍是闸——白名单只是「这个工具别再问我」。edit-args 缓做。
- **interrupt-before-side-effect**：park 时绝不跑危险工具——执行只发生在 approve 后。

## ask（agent 主动问用户）

- **`ask_user` 工具**（新，`app/tool/ask`）：实现 `InteractiveTool` 标记 → loop 见之即 park（**从不调它的 Execute**——它无服务端执行，结果就是用户答案）。
- **请求 shape = MCP elicitation**：`ask_user(message, requestedSchema?)`——扁平对象 + 原始类型字段（string/number/bool/enum）；无 schema 即自由文本。args 即 park 的 prompt。
- **三态响应**（resolve endpoint）：
  - **accept** → tool_result = 提交的结构化数据 / 文本（用户明确作答）。
  - **decline** → tool_result = "用户拒绝作答"（真信号，agent 据此改道）。
  - **cancel** → 放弃整个回合（M1→cancelled、不续跑；等同现有 Cancel 语义）。

## 崩溃 / 幂等 / 取消（§6）

- **记忆化绕开重跑坑**：续跑是 vanilla loop.Run，已完成 tool_result 在历史里、绝不重执行（= Restate ctx.run / Temporal activity-history）。
- **danger execute→落盘崩溃窗口**：approve 后执行工具、落盘 result 之间崩溃 → 重启后仍 parked → 重 resolve 会重跑（at-least-once）。单进程无自动重试、窗口小；**落盘 result + 翻 parked 用单条 SQLite tx**（记录原子）。任意外部副作用（发邮件等）无人能真 exactly-once——这与 Temporal 同级，文档化接受。
- **取消**：parked 回合的 goroutine 已释放，故「取消 parked」= 一种 resolve（→ M1 cancelled、不续跑）。
- **超时**：v1 **不设**（单用户本地、用户即唯一审批人，parked-forever 良性；用 Cancel 放弃）。日后可加 danger=超时拒绝。
- **重复 resolve 幂等**：resolve record-once（pending→已决 first-wins，二次 resolve no-op，镜像 `ResolveParkedNode`）。
- **boot 清理**：重启后 parked message 仍在（durable，正确——收件箱该显示它）；半截 streaming（非 parked）孤儿沿用现有落 error 逻辑。

## chat vs agent invoke

| | 落盘目标 | park 形态 | resolve 入口 | 续跑 |
|---|---|---|---|---|
| **chat** | messages（M1 parked + pending tool_result 块） | assistant message status=parked | `POST /conversations/{id}/interactions/{toolCallId}` | 续跑回合（processTask 变体） |
| **agent invoke** | agent_executions.transcript（status=parked） | execution status=parked + transcript 含 pending | `POST /agents/{id}/executions/{execId}/interactions/{toolCallId}` | 续跑 execution（runLoop 变体） |

同一 loop 机制（park 信号 + Parked result + 续跑驱动）；差别仅落盘/续跑的 host 实现（chatHost vs agent runLoop）。

## SSE 露出

- **notifications 流**（durable 收件箱）：`ask`/`danger` 节点 `pending{toolCallId, conversationId|execId, kind, prompt}` / `resolved` / `cancelled`（对齐 events.md §2 既有 ask 设计、扩 danger）。
- **messages/transcript**：park 的 tool_call 已带 danger + summary（S18，前端显示）；pending tool_result 块标记「等待中」。
- 前端：收件箱 + 对话内内联（问题/批准提示）双呈现。

## loop 机制改动

- `runTools` 返回额外 `parked []ParkRequest{ToolCallID, Kind, Tool, Args}`；非空 → `loop.Run` 停、Result.Status=parked + ParkRequests。
- park 判定：`tc.Danger=="dangerous"`（且未 always-allow）OR `byName[tc.Name]` 实现 `toolapp.InteractiveTool`。
- park 调用出 **pending tool_result 块**（status=pending、content=空/请求），不调 Execute。
- host（chatHost / agent runLoop）：Result.Status=parked → WriteFinalize(status=parked)；否则照旧。
- 续跑：resolve 后 host 重新 enqueue 一个续跑任务（vanilla loop.Run，历史已含填好的 result）。

## 分期

| 期 | 内容 | 量 |
|---|---|---|
| **D0** | loop park 原语：`InteractiveTool` 接口 + `runTools` park 判定/返回 + Parked Result + pending tool_result 块 status；message/block CHECK 加 `parked`；domain status 常量 + 测 | loop + messages domain/store |
| **D1 danger（chat）** | danger 门控 park；resolve endpoint（approve 执行/deny 反馈）；续跑驱动；notification 露出 + 测 | chat Service + handler |
| **D2 ask（chat）** | `ask_user` 工具（InteractiveTool, MCP-elicitation shape）；三态 resolve（accept/decline/cancel）；续跑 + 测 | app/tool/ask + chat |
| **D3 agent invoke** | park/resolve 扩到 agent execution（transcript 落盘 + 续跑 runLoop）+ 测 | agent Service + handler |
| **D4（选做）** | always-allow 会话白名单（deny-first 优先级） | chat + tool framework |
| 文档 | events.md §1/§2（ask/danger 节点 as-built）+ api.md（resolve 端点）+ database（parked status）+ domains（chat/agent ask-danger）+ S18 更新 + contract-changes | PLAYBOOK ④ |

## 产品决策（已定 2026-06-10）

1. **always-allow 进 v1**（D4 不再「选做」，本轮做）——会话级工具名白名单、命中跳过 danger 提示、deny-first（danger 自报仍是闸）。
2. **超时 v1 不设**——本地单用户、用户即唯一审批人，parked-forever 良性；用现有 Cancel 放弃。（日后可加 danger=超时拒绝，先不做。）
3. **agent invoke 本轮一起做**（D3 在范围内）——park/resolve 扩到 agent execution（transcript 落盘 + 续跑 runLoop）。

edit-args 仍缓做（非普适）。
