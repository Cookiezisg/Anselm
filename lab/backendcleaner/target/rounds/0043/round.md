# R0043 — M3.6 agent（波次 3 压轴）：配置好的 LLM worker

> 波次 3 收官。agent 是 Quadrinity **第四元、最综合实体**——挂载 skill/mcp/document/function/handler/model 六件，跑 ReAct loop。前三站（function/handler/mcp）的挂载件这轮都已就位且实测能跑，故 agent 一次做完整。**全身唯一与 function/handler 范式的实质差异是 pending/accept，砍掉即对齐**；其余照搬。

## agent 是什么

agent = 「配置好的 LLM worker」。不写代码，**按引用挂载**六件能力（prompt / skill 名 / knowledge 文档IDs / tools fn_·hd_·mcp refs / outputSchema / modelOverride），跑一个 ReAct 循环。区别于 chat（给人看的自由对话）：agent 被编排（workflow 节点 / 被当工具 / HTTP），输出可消费（outputSchema）、留痕（execution）、入图谱（relation）。

## 数据结构（两层 + 版本线，去 GORM）

- **Agent**（`ag_`）：name/desc/tags + active_version_id 指针。
- **AgentVersion**（`agv_`，不可变快照）：挂载六件全 JSON 列（弱引用、非关联表）；version max+1 **无 status**、无 updated_at。
- **AgentExecution**（`agx_`）：1:1 对标 function_executions，**无 deleted_at（D1 log 表）**。

orm db 标签 + WorkspaceID 隔离 + errorsdomain（8 sentinel）。

## 核心设计

1. **砍 pending/accept**（与 function/handler 唯一实质差异）：create/edit 立即生效 max+1，revert 移指针。砍 GetPending/AcceptVersion/Status/NeedsAttention + 3 个 pending HTTP 端点 + edit 的 pending 语义。
2. **invoke 接 loop + InvokeDeps 端口**（用户选 A）：唯一执行入口（工具 / HTTP :invoke / workflow agent 节点都经它，落 agx_）。跑 `app/loop.Run`。三个外部依赖走 **DIP 端口注入**：`LLMResolver`（model→LLM bundle）/ `ToolsProvider`（全局工具池，按白名单过滤）/ `KnowledgeProvider`（doc 渲染前缀）——M7 装配注真实、测试注 fake。**agent 是 backend-new 第一个跑完整 ReAct loop 的实体**（function/handler 跑代码不调 LLM；envfix/web 用 LLM 但非实体 invoke）。
3. **SSE 白捡**：invoke 跑 loop，loop emitter 从 ctx stream scope 自动推 block（chat 内 = 嵌套 subagent 子树，E3）。agent 零 stream 代码——测试时 ctx 不接流 → emitter no-op → 非流式跑通。
4. **search 子串**（用户揪出的对齐点）：search_agent 按 name/desc/tags 大小写不敏感子串（内存 `strings.Contains`，**无 LLM rerank**）——对齐 backend-new 全实体统一范式（旧 agent 是 LLM 排序）。
5. **outputSchema 三态**：free_text（默认）/ enum（注入 prompt + coerceEnum 规整，方便下游 workflow case 命中）/ json_schema。agent 的「返回类型声明」，让输出可被程序消费——agent 不分三种，是输出形态这一格三选一。
6. **relation 5 出边**（全 KindEquip，OtherKind 区分 fn/hd/mcp/doc/skill）+ forged 入边（KindCreate v1 / KindEdit v>1，分 scope 共存）。**无 agent→agent**（员工不调员工，tools 禁 ag_）。
7. **execution 面对齐 function 简化版**：Aggregates 只 OK/Failed（无 p95/avg）。

## 9 工具 + REST

工具：search_agent(子串) / get / create(立即生效) / edit(全量替换) / revert / delete / invoke_agent / search_agent_executions / get_agent_execution。**无 accept 工具**。
REST：CRUD + :edit/:invoke/:revert + versions + executions。**砍 /pending + pending:accept + pending:reject**。:iterate 依赖 askai（波次6）。

## 测试（全离线）

- store：往返 + JSON 列 round-trip + 版本 max+1 + workspace 隔离 + name conflict + execution 分页/聚合。
- app（real store in-memory）：create/edit max+1/revert 移指针 + ValidateTools 拒 ag_ + **InvokeAgent 用 fake LLM 跑真 ReAct loop**（enum coerce "approve" + execution 落表 ok）+ 无 deps 报错。
- tool：9 工具命名 + create/invoke ValidateInput。

`TestService_InvokeRunsLoopAndRecords` 是「选 A」的核心保证——fake LLM 跑通完整 invoke→loop→execution 链，无需真网络。

## 砍掉的旧物

pending/accept 整套 · LLM rerank search → 子串 · AttentionReason（旧 doc 有代码无）· CheckPermissions（M1.9 中央门控残留）· p95/avg aggregates → OK/Failed · dispatch_agent 内联 prompt 路径（legacy）。

## 留 M7 装配

boot：`agentstore.New` + `agentapp.NewService` + `SetRelationSyncer` + **`SetInvokeDeps`（注真实 LLMResolver/ToolsProvider/KnowledgeProvider）** + catalog `RegisterSource` + relation `Namers['agent']` + `AgentTools` 进 `Toolset.Lazy` + `NewAgentHandler.Register` + `db.Migrate` 收 `agentstore.Schema`。

## 用户参与设计

本轮大量设计讨论（暂停聊清再动手）：① outputSchema 三态语义（不是 agent 分三种，是输出形态配置项三选一；free_text+json_schema 已覆盖「任意输出」，enum 是常用特例 + coerce）② search 子串机制（内存 Contains，把「智能」还给调用方 LLM）③ invoke 范围选 A（连 loop 做 + 端口注入，fake 测）④ SSE 白捡（loop 自带、ctx-driven）。

## 验证

gofmt clean · build ./... · vet · 全量 test ALL PASS（agent 纯新增、不破坏任何包）。
契约：agent.md（DOC-129 重写）+ database/api/error-codes + contract-changes。

## 波次 3 收官

function ✅ · handler ✅ · trigger ✅ · skill ✅ · mcp ✅ · **agent ✅（压轴）**。**波次 3 Quadrinity 执行体全部完成**。下一站 M3.7 tool 适配器组（lazy 实体工具进 `Toolset.Lazy`）→ 波次 4 编排核心（workflow / flowrun / scheduler）。
