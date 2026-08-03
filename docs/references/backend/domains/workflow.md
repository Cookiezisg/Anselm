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

工具回执始终包含 `problems` 与 `warnings` 两个数组；没有问题时返回 `[]` 而不是 `null`，
这样模型报告、Chat 工具卡和后续自动化都能把「已检查且为空」与「字段缺失」区分开。

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

- `:trigger`：立即启动一次，不改变 listener；LLM 的 `trigger_workflow` 传入的 `payload` 必须符合入口
  trigger 的 fire-payload shape（webhook 的用户数据在 `body` 下）。公开 schema 是 object；执行边界兼容
  hosted model 将同一 object 编码为 JSON 字符串，数组、数字和畸形字符串仍拒绝。工具只返回新的
  `flowrunId`/`workflowId`，run 的节点结果和终态经 `get_flowrun` 读取。
- `:stage`：等待一次真实 firing 后撤防，active 时拒绝；成功返回当前 workflow 实体快照（包括名称、`lifecycleState` 与 `active`），不返回只有 ID 的裸动作回执；
- `:activate`：校验可运行后 Attach 所有入口；
- `:deactivate`：Detach，排空 accepted firing/running run 后 inactive；
- `:kill`：Detach、shed pending firing、取消 running run、转 inactive。

没有 trigger entry 的 graph 只能手动 trigger，不能 activate/stage。

Delete 先摘 active/staged listener，再取消该 workflow 的所有 running run，
之后软删主行并清 relation。该工具具有不可绕过的静态 `dangerous` 下限；即使模型自报
`safe`，Chat 也必须先出现 HumanLoop approval，且不能由 skill 或 `approve_always` 预授权
绕过。主行**不可恢复**，当前没有 restore 操作；产品文案不得向用户承诺可以恢复。工具的 canonical 参数是 `workflowId`；执行边界仅为
兼容 hosted model 偶发的精确 `id` 别名，若两者同时出现且冲突则拒绝。不可变
version、activation、firing、flowrun 保留审计，残余 pending firing 被 scheduler 收为 shed。

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
- `revert_workflow` 的公开 `version` 仍为 integer；执行边界额外接受 hosted model 发出的精确
  十进制整数字符串，浮点、布尔、数组和畸形字符串继续拒绝。一次调用必须同时带上真实的
  `workflowId` 与 `version`，不得先 `get_workflow`、漏字段或自动 retry；工具结果本身就是失败
  版本不存在时的权威事实。它只移动 active pointer，较新的 immutable version 保留在历史中，
  不会被重编号或删除。

- `trigger_workflow` 是一次性的手动 run：payload 直接喂给入口 trigger node，返回新的
  `flowrunId`；它不改变 workflow 的 listener 状态，也不走 `serial`/`skip`/`buffer_one`/`replace` overlap
  policy。公开 payload 是 object，执行边界额外接受同一对象的精确 JSON 字符串编码，错误形状不得猜测或修复。
- `stage_workflow` 是一次性的真实触发试跑布防：成功回执同时携带 `staged`、`workflowId`、
  `workflowName`、`lifecycleState` 与 `active`，让模型能用真实名称确认用户刚刚布防的对象；workflow
  仍保持 inactive，下一次真实 firing 后自动撤防。
- `activate_workflow` 是持续上线动作：成功回执同时携带 `workflowId`、`workflowName`、
  `lifecycleState=active` 与 `active=true`，让模型能用真实名称确认真正上线的对象；它会持续监听
  入口 trigger，直到 deactivate/kill。
- `deactivate_workflow` 与 `kill_workflow` 同样返回动作后的 `workflowName`、`workflowId`、
  `lifecycleState` 与 `active`；前者可能落在 `draining`，后者保证落在 `inactive`，另带 `killed`
  计数。生命周期动作不能只返回 opaque ID，否则用户无法确认哪一个 workflow 被改变。

- `get_flowrun` 返回仍可读取的 workflow 的 `workflowName` 便利投影，同时保留 `flowrun.workflowId`
  作为唯一身份；workflow 已软删或解析失败时名称诚实缺席。它对节点结果设输出上限：80 行以内全量返回，超过 80 行时保留全部非
  `completed` 行与最新 completed 尾部，并返回带真实总数的 `nodeSummary`；需要完整节点集时，
  通过 `GET /api/v1/flowruns/{id}` 分页读取。REST/数据库不受该 LLM 投影上限影响；不存在的 `flowrunId`
  在 LLM 工具面保留稳定的 `FLOWRUN_NOT_FOUND`，并补充确认 ID 正确且属于当前 workspace 的 reason，REST 404 message 不变。
  若 hosted model 把明确的 `fr_...` run ID 错放进 `file_path`，或把同值同时放入 `file_path` 与 `flowrunId`，loop 只在执行和落盘前做这一种无歧义的别名修复，逐字保留 ID，并在 tool-call attrs 记录修复来源；显式 `flowrunId` 与冲突的 `file_path`、普通文件路径和其他模糊值不修复而明确拒绝，不做近似 ID 查找；schema 同时关闭额外字段；
- `search_flowruns` 按稳定过滤器查历史；结果行在 workflow 仍存在时带人话 `workflowName`，并带 status、error 与 timing，模型不得把列表查询自动升级成逐条 `get_flowrun`，只有用户明确要节点详情或选定一条 run 诊断时才继续取详情；其 schema 关闭额外字段并把 status 限定为 `running`、`completed`、`failed`、`cancelled`；
- `replay_flowrun` 使用原 pin 从断点重走；
- `list_approval_inbox` 返回 slim parked 行；
- `decide_approval` 走与 HTTP 相同的 first-wins app service；LLM 侧必须先调用 `list_approval_inbox`，
  从同一行逐字复制 `flowrunId` 与 `nodeId`，不能用 `search_flowruns` 发现 parked 节点（parked 是节点状态，
  run 头仍为 `running`）。

Parked 是 node status，不是 run status，因此 approval inbox 是发现待审事项
的权威入口。

## 8. 跨域

- Scheduler 通过 WorkflowReader 读取冻结 version 和 refs；
- Workflow 通过 Binder Attach/AttachOnce/AttachReplay/Detach；
- Workflow 通过 Runner Start/Kill/CountOutstanding；
- Runner adapter 根据 ctx 是否含 conversation id 盖 manual/chat origin；
- Catalog、Mention、Relation、Search 使用标准实体投影；
- `:iterate` 通过 AISpawn 打开普通 Conversation。
