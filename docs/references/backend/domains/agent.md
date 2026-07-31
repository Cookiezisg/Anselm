---
id: DOC-007
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Agent

## 1. 定位

Agent 是持久化的 LLM worker 配置，不是代码执行环境。它把 prompt、knowledge、
skill、模型覆盖与按引用挂载的 callable 交给共享 ReAct loop。

```text
Agent row
→ immutable Version(config + mounts + schemas)
→ one loop invocation
→ terminal Execution + transcript
```

Agent 与 Chat 内的 Subagent 不同：前者是可版本化实体并写
`agent_executions`；后者是父对话内的隔离 loop，trace 存在 sub-message。

## 2. 版本

主行保存 name、description、tags 与 active pointer。Version 保存：

- prompt；
- 0 或 1 个 Skill 名；
- knowledge document IDs；
- ToolRef 列表；
- inputs/outputs 声明；
- 可选 ModelRef override。

Edit 是完整 Config 快照替换，写单调新版本并立即激活；Revert 只移动 pointer。
LLM `edit_agent` 在工具层采用“只覆盖显式字段”的 merge 便利语义，显式空值才
清除字段。Metadata 使用 `update_agent_meta`，不进入版本 Config。

Agent name 是展示身份，可包含中文与空格。版本保留上限为 50，active version
不被 trim。

## 3. 挂载

ToolRef 支持：

| Ref | 运行时工具 |
|---|---|
| `fn_<id>` | 当前 Function 名，调用 `RunFunction(agent)` |
| `hd_<id>.<method>` | `<handler>__<method>`，调用 `Handler.Call(agent)` |
| `mcp:<server>/<tool>` | `mcp__server__tool`，调用在线 MCP |
| `sys:<name>` | 可用时注入的内建能力工具 |

`ag_` 被禁止；Agent 串联由 Workflow agent node 表达。Agent 看不到 Chat 的
通用工具注册表，工具宇宙严格等于本版本挂载，每个工具已预绑定目标。

每次 Invoke 都按活实体重新解析名称、description 与 schema。目标删除、
Handler method 消失、MCP 离线、sys capability 无路由、ref 非法或合成工具名
碰撞都会 fail-fast；缺少声明能力时不降级运行。

Create/Edit 使用同一 resolver 做 eager 检查。按需
`GET /agents/{id}/mount-health` 非 fail-fast 地返回全部 tool 与 knowledge
挂载状态；碰撞也必须呈现 unhealthy。MCP server 存在但离线时报告
server-down，而不是误报 tool-not-found。

Skill 通过 `Guide` 渲染后进入 system prompt，不写父对话 active-skill，也不
触发 fork。Knowledge 作为 user message 前缀；任何 document 缺失都大声失败。

## 4. Invoke

所有入口汇入 `InvokeAgent`：

1. 解析指定 version，未指定则取 active；
2. 构造 knowledge prefix、prompt 与 JSON input；
3. 解析绑定工具和 Skill guide；
4. 解析 model override 或默认 agent scenario 模型；
5. 展开 input 中的 MediaRef；
6. 在 Agent wall-clock 与 turn cap 内运行共享 loop；
7. 在 detached workspace context 写 Execution。

输入 MediaRef 与工具结果 MediaRef 都经过同一个 AttachmentRenderer 和模型
ContentCaps。模型支持对应模态时生成原生 content parts；不支持时保留文本
receipt。这样 Chat、Workflow agent node 与 HTTP Invoke 使用相同多模态消费
边界。

Agent host 不写 Chat message history：完整 text、reasoning、tool-call、
tool-result blocks 序列化进 Execution transcript。Chat 中的嵌套调用实时走
父 tool-call scope；重载时可从 transcript 恢复。

运行来源为 `chat|workflow|manual`。Execution 记录 model、API key、provider、
conversation、message、tool-call 与 flowrun 溯源，状态为
`ok|failed|cancelled|timeout`。挂载解析发生在模型解析前时，凭证溯源回落到
声明的 override。

## 5. 输出与人在环

没有 outputs 声明时，最终文本作为自由结果。声明 outputs 时，system prompt
要求单个 JSON object，终答再映射为字段：

- 正确 object 直接返回；
- 只有一个声明字段时，标量可包入该字段；
- 多字段却非 object 时返回 `AGENT_OUTPUT_NOT_STRUCTURED`；
- 非 OK 终态 output 置空，原始 blocks 仍留在 transcript。

这使 Workflow 能稳定读取 `node.field`。Function/Handler 的 output 声明仍是
advisory；它们必须实际返回 object 才产生同名字段。

若 context 带 HumanLoop broker，dangerous mounted tool 在共享 loop 的危险
门等待用户决定。Workflow approval node 属于 Scheduler durable 人在环，不与
此内存 broker 混用。

## 6. Workflow replay

Workflow Agent node 可以提供已完成 ReAct steps，并通过 recorder 逐步写新的
绝对 turn index。普通 Chat/HTTP Invoke 不提供这些 replay 字段。粗粒度节点
结果与 Execution transcript 同时保留，分别服务 graph resume 与 agent 调试。

## 7. 契约与投影

精确端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。ID：`ag_`、`agv_`、`agx_`。

- Catalog：name + description，不把挂载误作成员；
- Mention：name + description；
- Relation：equip edges 指向 Function、Handler、MCP、Skill 与 Document；
- Workflow：Agent node 调用同一 `InvokeAgent`；
- Chat：`invoke_agent` 使用父 tool-call scope；
- Delete：软删主行并清 relation，Execution 仍是耐久审计。

LLM 工具覆盖搜索、读取、构建、revert、删除、invoke 与 Execution 查询；
metadata 更新使用专用工具。Mount health 是按需 HTTP 投影。
