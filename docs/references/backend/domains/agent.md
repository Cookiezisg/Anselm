---
id: DOC-007
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# agent —— 配置好的 LLM worker（Quadrinity 第四元）

## 1. 定位

Agent **自己不写代码**：靠**按引用挂载**能力（fn_/hd_/mcp 工具 ref、skill 名、文档 IDs、model 覆盖），以 ReAct loop（共享 `app/loop.Run`）运行。版本模型与 function/handler 同构：线性只增 Version + 自由移动 `ActiveVersionID` 指针，**无 pending/accept**——edit 写新版（max+1）立即生效、revert 只移指针、Trim cap 50 放过 active。

## 2. 实体模型

| 实体 | 前缀 | 关键字段 |
|---|---|---|
| **Agent** | `ag_` | name / description / tags / activeVersionId；软删 |
| **Version**（不可变） | `agv_` | prompt · **skill**(0-1) · **knowledge**(docIDs) · **tools**([]ToolRef) · inputs/outputs(schema.Field) · modelOverride · changeReason · forgedInConversationID |
| **Execution**（log 表，D1 不删） | `agx_` | versionID / modelID / status(ok·failed·cancelled·timeout) / triggeredBy(chat·workflow·manual，**无 agent**——员工不调员工) / input / output / **transcript**(完整 block 序列，自包含耐久记录、不入 message_blocks) / conversationID / messageID / toolCallID / flowrunID / flowrunNodeID |

`ToolRef{Ref, Name}`：Ref 合法集 = `fn_<id>` / `hd_<id>.<method>` / `mcp:<server>/<tool>`；**禁 `ag_`**（domain `ValidateTools`）。Name 是挂载时的展示名——运行时一律按**现名**重新解析。

## 3. 五类挂载的运行时语义（invoke 时逐项生效）

| 挂载 | 运行时 | 机制 |
|---|---|---|
| **fn_** | 一个以 function 命名的绑定工具 | `tool/mount`：description/inputs 来自活实体，Execute → `RunFunction`(TriggeredBy=agent) |
| **hd_…method** | `<handlerName>__<method>` 绑定工具 | method spec → schema；Execute → `handler.Call`(agent)，yield 流进 tool_call progress |
| **mcp:server/tool** | `mcp__server__tool` 绑定工具 | 经在线 server 解析（离线即失败）；Execute → `mcp.CallTool`(agent) |
| **skill** | **执行指南**注入 system prompt（`## Execution guide`段） | `skillapp.Guide`：渲染正文、**不**设 active-skill、**不** fork |
| **knowledge** | 知识前缀拼进 user 消息 | `BuildKnowledgePrefix(docIDs)` |

**核心设计**：agent **永不**见通用系统工具表（无 `run_function`/`Read`/`Bash`）——其工具宇宙**恰是其挂载**，每个工具预绑定目标（LLM 无自由 id 参数可乱走）。挂载解析 **fail-fast**：目标被删/server 离线/ref 格式坏/合成名撞名 → invoke 失败（worker 缺声明能力绝不静默降级跑）；错误带具体码（`FUNCTION_NOT_FOUND` 等），mount 自身问题 = `AGENT_MOUNT_INVALID`。合成在 `app/tool/mount`（DIP 三窄端口：FunctionPort/HandlerPort/MCPPort）。

## 4. Invoke 生命周期

`InvokeAgent`（所有路径唯一执行方法，对标 `RunFunction`）：取 version（空→active）→ `runLoop`（knowledge 前缀 + mount 合成 + skill 指南 + LLM resolve(modelOverride) + `loop.Run`，maxTurns 默认 10）→ `recordExecution`（**Detached ctx** best-effort，被取消的运行仍落账；ctx 取 conversation/message/toolCall id、InvokeInput 取 flowrun ids）。

- **InvokeDeps**（DIP 后注入）：Resolver / **Mounts** / **Skill** / Knowledge / EntitiesBridge——「需要却 nil」= 装配 bug，invoke 大声失败。
- **三条触发路径**：chat 的 `invoke_agent` 工具（chat）/ HTTP `:invoke`（manual）/ workflow agent 节点 `dispatch.RunAgent`（workflow；粗粒度 activity，只记忆化最终 result，sub-step replay 字段 ADR-010 预留）。
- **呈现**：chat 内嵌套在 invoke_agent tool_call 下（E3）；entities 流 agent scope 镜像全轨迹（SSE-C）；durable 记录 = Execution.transcript。
- **人在环**：ctx 带 humanloop broker 时，危险工具在共享 loop 的 danger 门阻塞至 resolve（嵌套不冒泡）。

## 5. 契约

- **错误码（9）**：见 [error-codes](../error-codes.md) `domain/agent` 段（含 `AGENT_MOUNT_INVALID` 422）。
- **HTTP**：`POST/GET /api/v1/agents` · `GET/PATCH/DELETE /{id}` · `POST /{id}:invoke|:revert|:edit|:iterate` · `GET /{id}/versions[/{version}]` · `GET /{id}/executions`。N5 执行动词 = **`:invoke`**。
- **DB**：`agents` / `agent_versions`(UNIQUE agent_id+version) / `agent_executions`(CHECK status·triggered_by；ws+agent/conversation/flowrun 索引)。
- **SSE**：无新流（E1）；entities 流 agent scope + notifications `agent.*`。
- **Tools（LLM 面）**：search/get/create/edit/revert/delete_agent · invoke_agent · executions 查询（`tool/agent`）。

## 6. 跨实体定位 / 有意分化

与 function/handler 同构：版本模型 / CRUD / catalog·mention·relation 三适配器 / recordExecution(Detached)。**有意分化**：① AI 编辑用**全量 Config 快照**而非 forge op 数组（agent 是声明式配置、无代码体，整体替换语义清晰）；② **name 不强制 slug**（function/handler 名是代码标识符（入口函数/类名），agent 名是展示身份，可中文/空格）；③ 无 sandbox 依赖。subagent 与 agent 实体**无关**（chat 内 spawn 的隔离 loop 运行，非实体）。
