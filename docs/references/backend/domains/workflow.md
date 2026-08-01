---
id: DOC-014
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-08-02
review-due: 2026-10-29
audience: [human, ai]
---

# Workflow

## 1. 定位

Workflow 保存、版本化和校验编排图；Scheduler 解释执行。主行持有 active
version 指针，version 行不可变。Workflow 通过 Runner/Binder 端口与
Scheduler/Trigger 协作，不直接依赖具体实现。

## 2. 图模型

图由五类节点和数据边组成：

| Node kind | Ref |
|---|---|
| trigger | `trg_` |
| action | `fn_`、`hd_.method`、`mcp:server/tool` |
| agent | `ag_` |
| control | `ctl_` |
| approval | `apf_` |

Node ID 是图内局部名，也是下游 CEL 读取结果的根。每个 Input 字段保存一条
CEL。Action 返回对象时字段直接成为 result；标量回落 `text`。Agent 在只有
一个声明 output 时可包到该字段，多字段声明要求结构化对象。

`FromPort` 只用于 control branch 与 approval `yes|no`。分支汇合读取不一定
执行的节点时，表达式必须使用 `has(node.field)` 提供 fallback；静态祖先关系
不能证明某分支在每次 run 都执行。

## 3. 主行状态

### Lifecycle

| 状态 | 语义 |
|---|---|
| `active` | 正在监听 trigger |
| `draining` | 已摘 listener，仍排空 accepted firing 或 running run |
| `inactive` | 不监听且无 outstanding work |

### Concurrency

| 策略 | 自动 firing 重叠时 |
|---|---|
| `serial` | 保持 pending，等当前 run 完成 |
| `skip` | 新 firing → skipped |
| `buffer_one` | 只保留最新 pending |
| `replace` | 取消在途 run，再运行新 firing |
| `allow_all` | 允许并发 |

策略只作用于真实 Trigger firing。显式 `:trigger` / `StartRun` 表示用户要求
立即运行，不经过 overlap policy。

Firing drain 的 overlap/claim/seed phase 保持顺序，使同一批后续 firing
能够看见前一个已经创建的 running run；Advance 由 Scheduler pool 执行。

`needs_attention`、`attention_reason`、`last_action_by` 是比 graph version
更长寿的运行治理状态，因此存在主行。

## 4. 校验

### Domain graph validation

`ValidateGraph` 检查：

- node kind 与 ref 形状；
- node/edge ID、悬挂边、自环；
- 至少一个 trigger，且所有节点从 trigger 可达；
- back edge 只能从 control/approval 闭合；
- port 结构。

失败返回 `WORKFLOW_INVALID_GRAPH` 与 reason。

### CEL compilation

App 层先以全图 node roots 编译，再以当前节点祖先集合编译。后者保证节点只读
结构上先于它的 result。Domain 不导入 cel-go；校验与执行共用 graph
`BackEdges`/ancestor helper。

### Capability check

Resolver 汇总为 `problems` 与 `warnings`：

Problems：

- ref 不存在或 kind 不符；
- control/approval edge port 无效；
- Handler method 或已连接 MCP tool 不存在；
- Function/Handler/Agent/Control/Approval 的声明 input 未接线。

Warnings：

- CEL 读取 producer 未声明的 output field。

Output 声明是 advisory，运行结果可能包含额外字段，因此该项不阻断。`.text`
fallback、`has()` 守卫、无声明 output 的 producer 跳过。Resolver miss
转换为 problem，不作为 transport error 提前中断整份报告。

Create/Edit 允许增量构建，不要求 capability report 全绿；`:stage` 和
`:activate` 在承诺监听前调用 `ensureRunnable`，有 problem 时返回
`WORKFLOW_NOT_RUNNABLE` 且不 Attach。显式单次 `:trigger` 直接运行，失败在
本次 run 中可见。

## 5. 编辑与版本

Edit 使用判别式 ops：

```text
set_meta
add_node / update_node / delete_node
add_edge / update_edge / delete_edge
```

Update 是顶层 merge patch；嵌套 `input` 对象整体替换。Node ID 不可变；
delete node 级联删边。公开工具 schema 仍只声明原生数组与嵌套 `node`/`edge`。
应用工具边界仅为已观测的托管模型形状提供两种窄兼容：精确 JSON 编码的数组字符串，或
`add_node`/`add_edge` 把 body 字段放在 op 顶层；冲突、畸形字符串、对象和非数组值仍拒绝。
归一化之后进入 domain 的 `ParseOps` 仍是严格的，结构化编辑器与 HTTP 路径不自动修复非法 JSON。

Active workflow Edit/Revert 改变入口 trigger 时，以旧/新 graph diff
Detach/Attach。Staged 的 once binding 由 Binder 保持。包含 `set_meta` 时，
保存主行前必须先把 active version pointer 更新为新版本，避免 meta upsert
覆盖刚激活的指针。

Pin closure 在 run 创建前解析 graph refs。Function、Agent、Control、
Approval 固定 version；Agent 递归一层解析其挂载。Handler 与 MCP 活态绑定。
解析不到 ref 由 capability/runtime 失败处理，不伪造 pin。

## 6. 执行动作

- `:trigger`：立即启动一次，不改变 listener；
- `:stage`：等待一次真实 firing 后撤防，active 时拒绝；
- `:activate`：校验可运行后 Attach 所有入口；
- `:deactivate`：Detach，排空 accepted firing/running run 后 inactive；
- `:kill`：Detach、shed pending firing、取消 running run、转 inactive。

没有 trigger entry 的 graph 只能手动 trigger，不能 activate/stage。

Delete 先摘 active/staged listener，再取消该 workflow 的所有 running run，
之后软删主行并清 relation。不可变 version、activation、firing、flowrun
保留审计；残余 pending firing 被 scheduler 收为 shed。

Boot 在逐 workspace detached ctx 下 `ReattachActive`。

## 7. API 与工具

HTTP：

- CRUD、versions；
- `:edit`、`:revert`、`:capability-check`、`:iterate`；
- `:trigger`、`:stage`、`:activate`、`:deactivate`、`:kill`。

精确端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)。ID：`wf_`、`wfv_`。

LLM 工具覆盖构建、生命周期与运行观测：

- `create_workflow` 的 LLM schema 要求显式携带 `description`、`tags`、`changeReason` 三个
  metadata 槽位；用户未提供时传空字符串/空数组，提供时原样传递。Hosted model 若将 `tags`
  整体 JSON 编码成字符串，工具边界只接受精确 JSON 数组字符串，不接受逗号分隔文本。这样可
  阻断模型静默丢失用户意图；`ValidateInput` 在写库前再次要求三个键实际出现，HTTP create
  仍可省略这些可选字段。

- `get_flowrun` 对节点结果设输出上限，优先保留非 completed 和最新尾部，并
  返回 summary；REST/数据库不受该投影上限；
- `search_flowruns` 按稳定过滤器查历史；
- `replay_flowrun` 使用原 pin 从断点重走；
- `list_approval_inbox` 返回 slim parked 行；
- `decide_approval` 走与 HTTP 相同的 first-wins app service。

Parked 是 node status，不是 run status，因此 approval inbox 是发现待审事项
的权威入口。

## 8. 跨域

- Scheduler 通过 WorkflowReader 读取冻结 version 和 refs；
- Workflow 通过 Binder Attach/AttachOnce/AttachReplay/Detach；
- Workflow 通过 Runner Start/Kill/CountOutstanding；
- Runner adapter 根据 ctx 是否含 conversation id 盖 manual/chat origin；
- Catalog、Mention、Relation、Search 使用标准实体投影；
- `:iterate` 通过 AISpawn 打开普通 Conversation。
