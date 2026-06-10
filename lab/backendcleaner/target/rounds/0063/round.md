# Round 0063 — SSE-C：entities 流 = 实体活动流（forge + run + fire）

类型 / 目标：SSE 收尾的 C 层。entities 流（A 层已接订阅端点、零生产者=空流）接上生产侧，成为**每个实体的活动流**，喂前端**实体面板**：锻造时内容哗啦填、运行时小终端跑中间信息、trigger fire 时点信号。

## 三流 → 三界面（产品定位）

- **messages** → 对话窗口（agent 在对话里：思考/正文/tool_call + 进度/锻造/运行）
- **entities** → 实体面板（每实体活动：forge 内容流 + run 小终端 + fire 信号）
- **notifications** → 通知中心（耐久里程碑）

## entities 承载三种活动（scope = 实体）

| 活动 | 哪些实体 | 内容 | 产出方 |
|---|---|---|---|
| **forge** | fn/hd/ag/wf/ctl/apf/doc/skill（8）| create/edit 的内容 delta（代码/图/字段哗啦填）| **loop**（外层 LLM 写 args，chat；REST 编辑手敲不流）|
| **run** | fn/hd/ag/wf/**mcp**（5）| 执行中间信息（stdout/yield/ReAct 轨迹/节点推进/mcp progress）| **Service/scheduler**（沙箱/handler/agent-loop/调度器，**全 caller**）|
| **fire** | trigger（1）| fire 点信号（刚 fired → 起了 X）| **trigger Service** |

> document/skill/control/approval 只 forge 不 run；mcp 只 run 不 forge（外部 server）；trigger 只 fire。

## 核心架构

**dual-write，调用方做**：同一份中间信息，messages（chat，B 层已有）+ entities（全 caller，C 层）。
- **run 产出方 = Service**（与谁触发无关——chat/REST/workflow 节点/**sensor-poll** 全自动覆盖，因 Service 跑得一样）。Service `io.MultiWriter(caller 的 messages sink〔B 层 ToolProgress〕, entities writer)`。
- **forge 产出方 = loop**（args delta 只在 chat LLM 生成时存在）。loop 对 forge tool_call 双发：messages tool_call（B/已有）+ entities forge 节点。
- **B/C 统一**：B 层的 ToolProgress（仅 messages）保留给**无实体工具**（Bash/WebFetch…）；有实体归属的 run/forge 走 entities（+ messages dual）。B 层不白做——progress 块型/sink 接线全复用。

**entities = live-only**：durable 真相在实体行（functions/…）+ 执行表（function_executions / agent_executions〔transcript〕/ flowrun_nodes / **新 mcp_calls**）。刷新从 REST 重建，entities 只管「此刻哗啦」。不需 B0.5 那种持久化。

## entitystream 原语（C0 keystone）

`entitystream.Writer`：包 (bridge, scope, nodeType)，发流式节点——`New` / `Write`(io.Writer：懒 open + delta) / `Close`(快照) / `Signal`(点信号，给 fire)。**单一职责**：往一个 bridge+scope 发节点；dual-write 由调用方组合（不在原语里 fan-out，保持简单）。loop（forge）+ Service（run）+ trigger（fire）共用。

## 分期（全部 ✅ as-built）

| 期 | 内容 | as-built 备注 |
|---|---|---|
| **C0** ✅ | stream domain 补 `KindControl`/`KindApproval`/`KindTrigger` + `entitystream` 原语 + WithBridge ctx 接缝 + 测 | + `NodeForge/NodeRun/NodeFire` 常量、`WithRunScope`（C3a 加） |
| **C1 forge** ✅ | `ForgeTool` 接口 + loop 对 forge tool_call 双发 entities；16 工具实现 Forge() | **简化**：ForgeSpec 只 `{Kind, Op}`（无 TargetID——loop 不解析 args，scope=tool_call id 的 forge 会话，前端经 args/tool_result 关联实体）；**C2a 补 chat seed**（EntitiesBridge 进 chat.Deps，否则 inert） |
| **C2 run fn/hd** ✅ | function stdout / handler yield → entities run 终端（全 caller） | fn=adapter ctor 注入 + MultiWriter；hd=Service.Call setter 注入 + 包 OnProgress 双发 + 一律 StreamCall |
| **C3 run ag/wf** ✅ | agent ReAct 轨迹 / workflow 节点推进 → entities | ag=**loop emitter mirror**（WithRunScope，整轨迹每帧、off-chat 也流）；wf=Advance 每节点 Signal |
| **C4 mcp 补全** ✅ | `mcp_calls` 表 + 记录 + run→entities + sensor mcp 目标 | `mcl_` 前缀；CallTool 签名 += triggeredBy（4 调用点显式：HTTP=manual/dispatcher=workflow/sensor=workflow/动态工具=""推 ctx）；**砍 aggregates/get-by-id/LLM 检索工具**（无消费者不预建）；`GET /mcp-servers/{name}/calls`；infra 导出 `ProgressFrom`（Service 包既有 sink） |
| **C5 trigger fire** ✅ | fanOut（所有 fire 路径唯一咽喉）每扇出发 fire Signal | content={activationId, kind, fired, firingCount, error} |

## 验证 + 文档
- go build ./... + 各 phase 测试 + 全模块 0 FAIL。
- events.md §3 转 as-built（forge/run/fire 节点 open/delta/close/signal + scope，删旧 forge_started 里程碑模型）+ database.md（mcp_calls 表 + 3 scope kind）+ contract-changes + 各 domain doc。
