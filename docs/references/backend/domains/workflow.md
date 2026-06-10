---
id: DOC-128
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-09
review-due: 2026-09-09
audience: [human, ai]
---
# Workflow — 静态编排图实体（wf_/wfv_，「function 范式套图」）

> **核心地位**：Workflow 是 Forgify「四项全能」(Quadrinity) 的**编排者**——一张静态的「DAG + 回边」typed 图，按 id 引用其它实体（trg_/fn_·hd_·mcp_/ag_/ctl_/apf_）并用每个节点的 CEL 接线其 I/O。版本化、ops 编辑、图以 JSON 存于版本行。本模块**只 STORE + VALIDATE + PIN 这张图——不执行它**：执行（durable 解释器 + scheduler + flowrun/journal）是后续波次，import 同一批纯 helper（`ValidateGraph`/`BackEdges`）走 pin 的版本。设计源头见 [`18-graph-model-redesign.md`](../../../working/workflow-revamp/18-graph-model-redesign.md) / [`20-unified-entity-workflow-model.md`](../../../working/workflow-revamp/20-unified-entity-workflow-model.md)。

---

## 1. 版本模型：线性历史 + 自由指针（无 accept）

与 function/control 同构的最轻版本化——**版本是 pin 所必需**（在途 flowrun 不漂移），去掉 function 的 sandbox/env/executions：

| 概念 | 语义 | 谁能动 |
|---|---|---|
| **版本号 `version`** | 写入顺序（单调计数器，只增不改） | 写新版本时 = `max+1` |
| **版本内容** | 不可变的 graph 快照（append-only） | 永不修改既有版本 |
| **active 指针 `active_version_id`** | 「现在用哪个图」 | edit 前移 / revert 自由移动 |

- **create** = 套 ops 建 v1，立即 active。**新 workflow 起始停泊**：`active=false`、`lifecycle=inactive`（作者待图无误后显式 `:activate`）。
- **edit** = 基于 active 当前图套 ops → 写 `v(max+1)` → 指针前移。立即生效、无断点。**空 ops 被拒**（edit 须改动；与 function 不同，workflow 无「重建 env」空 ops 路径）。
- **revert(N)** = **只挪指针**到 vN，不产生版本、不删「更新的」版本。
- 历史超 `VersionCap=50` 裁最老——**但绝不裁 active**（revert 后它可能很老）。
- **无 pending/accept 状态机**（与 function/handler/agent/control 一致）。「编辑活 workflow」靠把它停泊 `inactive`（§5 lifecycle）安全，而非靠 pending 草稿态。

---

## 2. 物理模型（两表）

### 2.1 `workflows`（`wf_`，软删）
`id` · `workspace_id`(orm 自动隔离) · `name`(workspace 内 partial-UNIQUE，软删后释放) · `description` · `tags`(json) · **`active`**(bool，镜像 lifecycle==active) · **`lifecycle_state`**(active|draining|inactive，CHECK) · **`concurrency`**(serial|Skip|BufferOne|BufferAll|AllowAll，CHECK) · `needs_attention`(bool) · `attention_reason` · `last_action_by`(user|system) · **`active_version_id`**(指针) · 时间戳 · `deleted_at`。

> `lifecycle_state`/`concurrency`/`needs_attention`/`last_action_by` 治理（未来）durable 调度器如何对待本流——放在**头表**上，因为它们比任何单个图版本更长寿。`active` 是 `lifecycle_state == 'active'` 的镜像列（建索引用）。

### 2.2 `workflow_versions`（`wfv_`，append-only + cap 裁剪，无软删）
`id` · `workspace_id` · `workflow_id` · **`version`**(单调号) · **`graph`**(JSON `{nodes,edges}`，`TEXT NOT NULL DEFAULT '{}'`) · `change_reason` · `forged_in_conversation_id`(relation 边用) · 时间戳。`UNIQUE(workflow_id, version)`。**无 `deleted_at`**——超 cap 由硬删裁剪（`TrimOldestVersions` 始终放过 active）。

### 2.3 Graph 结构（存于 `graph` json）
```go
type Graph struct {
    Nodes []Node `json:"nodes"`
    Edges []Edge `json:"edges"`
}
type Node struct {
    ID    string            `json:"id"`             // 图内局部 id；也是下游 Input CEL 里引用本节点结果的名字
    Kind  string            `json:"kind"`           // trigger|action|agent|control|approval
    Ref   string            `json:"ref"`            // 被引用实体（pin 时解析为 active 版本，不在此）
    Input map[string]string `json:"input,omitempty"`// field → 读上游结果的裸 CEL（trigger 无）
    Retry *RetryConfig      `json:"retry,omitempty"`// action 的 durable 重试（原样存，scheduler 后续解释）
    Pos   *Position         `json:"pos,omitempty"`  // 画布坐标（编排元数据，执行忽略）
    Notes string            `json:"notes,omitempty"`
}
type Edge struct {
    ID       string `json:"id"`
    From     string `json:"from"`
    FromPort string `json:"fromPort,omitempty"` // control 源=Branch.Port / approval 源=yes|no / 其它=空
    To       string `json:"to"`
}
type RetryConfig struct {
    MaxAttempts int    `json:"maxAttempts"`
    Backoff     string `json:"backoff,omitempty"`
    DelayMs     int    `json:"delayMs,omitempty"`
}
```

---

## 3. 心智模型：5 节点 × 两轴

**5 种节点 kind**，每种按 ref 前缀恰引用一个实体族：

| kind | ref 前缀 | 引用什么 | Input |
|---|---|---|---|
| **trigger** | `trg_` | 图的入口信号源 | 空 |
| **action** | `fn_` / `hd_<id>.method` / `mcp:server/tool` | 一个 durable activity | 接线（每字段非空 CEL） |
| **agent** | `ag_` | 配置好的 LLM worker | 接线 |
| **control** | `ctl_` | 路由逻辑（when/emit 分支组，详 [control.md](control.md)） | 接线 |
| **approval** | `apf_` | 人工审批门（详 [approval.md](approval.md)） | 接线 |

**两根独立轴**：
- **数据轴 = 节点 `Input`**：`map[field]→CEL`。把被引用实体声明的每个 input 字段，映射到一条读**上游节点结果**的裸 CEL。每个节点的结果用它的 **node id 具名**（`reviewer.score`）。
- **控制轴 = 边 + 端口**：Edge 是控制骨架，**不携带数据**。control 出边的 `fromPort` 是该 `ctl_` 的某个 `Branch.Port`；approval 出边的 `fromPort` ∈ `{yes, no}`；其它 kind 的出边 `fromPort` 必须空。

### 3.1 Model B：node-addressable scope（节点 Input 按 node id 寻址）

节点 `Input` 的 CEL **按 node id 引用上游结果**（`reviewer.score`、`fetch.body`），而非某个全局 payload。create/edit 时，每条 Input CEL 用一个 **ScopedEnv** 编译，其根 = **本图全部 node id（+ 恒有的 `ctx`）**（`compileGraphCEL`）。

- ⇒ **引用不存在的 node id 在 create/edit 即编译失败**——白送一个「表达式只引用存在节点」的 lint（无需额外校验代码）。
- ⇒ 语法错 / 未知函数（如 `now()`）同样编写期快速失败。
- **更严的「祖先可见性」lint**（只可引用**祖先** node id、而非任意存在节点）是 **deferred TODO**：需逐节点从 CEL AST 抽标识符（`cel.ReferencedRoots`），`pkg/cel` 暂未暴露——推迟到 scheduler 波次；在此之前节点可引用非祖先（但存在）的节点，解释器运行时上呈。

---

## 4. 锻造（Forge）：7 个图编辑 op

create/edit 接收 **ops 数组**，按声明序逐个应用到图。`ParseOps` **不修 JSON**（workflow ops 来自结构化编辑器 / 工具，非自由 LLM 文本，故畸形体是该上呈的真错误）。

```
set_meta      {"op":"set_meta","name":"snake_case","description":"one line","tags":[...]}   // 只改头部身份，不动图
add_node      {"op":"add_node","node":{"id","kind","ref","input":{...}}}
update_node   {"op":"update_node","id":"<nodeId>","patch":{...}}   // 顶层字段 merge-patch；id 不可变；input/retry 整体替换
delete_node   {"op":"delete_node","id":"<nodeId>"}                 // 级联：触及该节点的每条边一并删，无悬挂边残留
add_edge      {"op":"add_edge","edge":{"id","from","to","fromPort"}}
update_edge   {"op":"update_edge","id":"<edgeId>","patch":{...}}   // id 不可变
delete_edge   {"op":"delete_edge","id":"<edgeId>"}
```

> `set_meta` 由 app 层折成 `MetaPatch` 应用到 Workflow **头行**（`ApplyOps` 只管图）。`ApplyOps` 在 base 的**克隆**上做（绝不改输入），畸形 op / 令图不一致的 op（未知 id、重复 id）返 `WORKFLOW_INVALID_OPS`；最终结构合法（`ValidateGraph`）是另设的闸。

---

## 5. 校验（结构 domain + 能力 app）

create/edit 核心 `buildGraph` 三步：**ApplyOps → ValidateGraph（结构）→ compileGraphCEL（每条 Input CEL）**。**ref 解析不在此**（需 catalog，是 `CapabilityCheck` 的事）。

| 层 | 管什么 | 何时 |
|---|---|---|
| **① domain 结构** (`ValidateGraph`，纯·无依赖) | 形状（逐节点 kind 已知 / ref 非空且前缀配 kind / action 每条 input 非空 CEL）· 良构（node·edge id 唯一、无悬挂端点、无自环、**≥1 trigger**、**可达性**：每节点从某 trigger 正向可达）· **环纪律**（每条**回边**须出自 control/approval 节点）· **结构性端口**（approval 源 fromPort ∈ yes/no；control 源 fromPort 非空；其它源留空） | create/edit + 未来解释器运行前 |
| **② app CEL** (`compileGraphCEL`，pkg/cel ScopedEnv) | 每条 `node.Input` 表达式语法 + 引用的根是否 node id（见 §3.1）→ 失败映射 `WORKFLOW_INVALID_GRAPH`（违例 node/field 在 `details`） | create/edit（快速失败） |
| **③ app 能力** (`CapabilityCheck`，需注入 RefResolver) | ref 存在 + kind 匹配 + control/approval 端口与解析出的分支集**调和**（handler `.method` 须存在）；收集**所有**问题进 report，**绝不**返 transport 错误 | 手动 `:capability-check` / activate 前 |

> **`BackEdges` 是共享纯函数**：返回图的可归约回边（DFS 递归栈判定）。`ValidateGraph` 用它做环纪律检查；未来 durable 解释器 import **同一函数**在运行时同样分类边——系统里「回边」只有一个定义。它跳过引用缺失端点的边，故对未校验图调用也安全。

### 5.1 CapabilityReport（能力检查结果）

```go
type CapabilityReport struct {
    StructurallyValid bool     `json:"structurallyValid"`
    Resolved          bool     `json:"resolved"`           // false → 仅结构（未注入 resolver）
    Problems          []string `json:"problems,omitempty"` // 解析出的所有 ref/端口问题
}
```
`CapabilityCheck` **容忍 nil resolver**：届时跑**仅结构**报告（`Resolved=false`）并说明——结构非法的图短路（在畸形图上解析 ref 是噪声）。`RefResolver` 实现在本模块外（**M7 `bootstrap.NewRefResolver`** ✅：直查 7 个实体 Service〔fn/hd/ag/ctl/apf/trigger/mcp〕——**非** catalog（catalog 是纯菜单、刻意不带 ref 句柄，不能解析）。**版本无关实体（trigger/mcp）：存在=可用** → `HasActiveVersion=true`、空 `ActiveVersionID`（pin 记空 no-op；下面 `false` 仅指**可锻造实体尚无 active 版本**这一不可用态）），测试里 fake：

```go
type RefResolver interface { Resolve(ctx, ref string) (RefInfo, error) }   // miss → ErrRefNotFound
type RefInfo struct {
    Kind             string   // relationdomain.EntityKind*
    HasActiveVersion bool     // false → 图引用了无版本实体
    ActiveVersionID  string   // pin 目标（entity_id → this）
    BranchPorts      []string // control only：ctl_ active 版分支端口名
    MethodNames      []string // handler only：hd_ active 版方法名
    AgentCallables   []string // agent only：该 agent 挂载的 fn_/hd_ ref（供深度 2 pin 递归）
}
```

---

## 6. Pin：在途 flowrun 不漂移

`BuildPinClosure(graph)` 走图里每个 node ref，解析每个被引用实体的 active 版本 id，并**递归进 agent 挂载的 fn_/hd_ 可调用项**（深度 ≤ 2：agent 自身→其直接 callable；agent 不能挂 agent，故两层是天然下界），返回 `{entity_id: active_version_id}` map。未来 scheduler 在 `StartRun` 调它**冻结** flowrun 执行所依的确切实体版本——使运行中对任何被引用实体的编辑无法改变运行中的流（**确定性 / 重放安全**）。它在 workflow 模块而非 scheduler，因为 workflow 最懂「图 + ref 解析」。需 resolver；无则返空 map（scheduler 视作不可 pin 而拒启——但那接线是 scheduler 的）。

> **`WorkflowReader`（scheduler 的 DIP 读面）**：`GetActiveVersion`（含解码图）· `GetWorkflow`（裸头）· `ListActive`（active=true 候选集）。未来调度器 import **此接口**、非具体 Service。

---

## 7. 生命周期 + 执行动作（D1，R0066）

- **lifecycle_state**（治理调度参与）：
  - `active`：接受触发、持续监听（`:activate` 设此，`active=true`）。
  - `draining`：跑完在途、不再起新（`:deactivate` 在仍有在途 run 时落此；scheduler 在最后一个 run 结算时 `MarkInactiveIfDrained` 翻 inactive——见 scheduler §4.4）。
  - `inactive`：完全停泊（`:deactivate`〔无在途 run〕/ `:kill` 设此）。
- **concurrency**：`serial`(等) / `Skip`(丢新) / `BufferOne`(仅留最新) / `BufferAll`(全排队) / `AllowAll`(并发)。
- **needs_attention** / **last_action_by**：scheduler 运行不可重试失败拉横幅 + reason；区分 user/system 发起的状态变更。

**执行生命周期 5 动作**——workflow.Service 是单一拥有者，经两 DIP 端口驱动（**bootstrap 注入、无 import 环**：workflow app → scheduler/trigger app；scheduler app 只 import workflow **domain**）：
- **`Binder`**（→ `*triggerapp.Service`）：`Attach` / `AttachOnce` / `Detach`——挂/摘 trigger 监听。
- **`Runner`**（→ `*schedulerapp.Service`，bootstrap `runnerAdapter` 把原生参数桥成 `StartInput`）：`StartRun` / `KillWorkflow` / `CountRunning`。

| 动作 | 做什么 |
|---|---|
| **`Trigger(id, payload)`** | `runner.StartRun` 立即跑一次（不改监听态）；无 active 版本/trigger 入口由调度器报 422 |
| **`Stage(id)`** | 入口 trigger 逐个 `binder.AttachOnce`（一次性、不改 lifecycle）；已 active→`ErrAlreadyActive` |
| **`Activate(id)`** | 入口 trigger 逐个 `binder.Attach` + `SetLifecycle(active)` |
| **`Deactivate(id)`** | 逐个 `binder.Detach` + `SetLifecycle(有在跑 run→draining 否则 inactive)`（在途 run 不杀）|
| **`Kill(id)`** | 逐个 `binder.Detach` + `runner.KillWorkflow`（取消在途 run）+ `SetLifecycle(inactive)`→`killed` 数 |

- **`entryTriggerRefs`**：解 active 图、收 `NodeKindTrigger` 节点的去重 ref（trg_）。无 active 版本→`ErrNoActiveVersion`；无 trigger 节点→`ErrNoTriggerEntry`（纯手动图只能 `Trigger`/`Kill`）。
- **`ReattachActive(ctx)`**：boot 调——监听注册表是内存的、重启后空，故为每个 active workflow 重 `Attach`（App.Boot 在 trigger.Start 后调，按 ctx workspace，同 handler/mcp Boot）。
- **`MarkInactiveIfDrained`**：实现 scheduler 的 `LifecycleReconciler`（draining→inactive 条件更新）。

---

## 8. LLM 工具（12，懒加载）

**Forge/Query（7）**：`search_workflow`（子串找 name/description/tags）· `get_workflow`（含 active 版完整图 nodes+edges）· `create_workflow`（ops 建 v1，起始 deactivated）· `edit_workflow`（ops 套 active 图写新版本，非空 ops）· `revert_workflow`（按号移指针）· `delete_workflow` · `capability_check_workflow`（结构 + ref 能力报告，activate 前用）。

**执行生命周期（5，R0066/D1）**：`trigger_workflow`（现在跑一次，可带 payload）· `stage_workflow`（待命接下一次真实触发、跑一次自动撤防）· `activate_workflow`（上线持续监听）· `deactivate_workflow`（优雅下线，在途跑完）· `kill_workflow`（硬停 + 取消所有在途 run）。各落 §7 对应 Service 方法。

全 S18 五方法接口、danger 由 LLM 逐次自报（kill 自然被标 dangerous → 走 R0064 确认门）；进 `Toolset.Lazy`，经 `search_tools` 浮现。

---

## 9. HTTP 端点

`POST /workflows`（扁平创建，body `{name,description,tags,ops,changeReason}`，返 `{workflow,version}`）· `GET /workflows`（分页）· `GET /workflows/{id}`（含 activeVersion + 解码图）· `PATCH /workflows/{id}`（UpdateMeta：name/description/tags，不升版本）· `DELETE /workflows/{id}`（软删 + 清边）· `POST /workflows/{id}:edit|:revert|:capability-check|:iterate` · **执行生命周期 `POST /workflows/{id}:trigger|:stage|:activate|:deactivate|:kill`（R0066/D1，§7）** · `GET /workflows/{id}/versions`(分页) · `GET /workflows/{id}/versions/{version}`(整数号或 version id)。

> `:trigger` 返 **202** `{flowrunId}`；`:kill` 返 `{killed}`；`:activate`/`:deactivate` 返 workflow。**无 execution-history 端点**（run 列表/详情消费 durable scheduler，另见 flowrun）；**无 pending 端点**（无 accept 状态机）。`:iterate`(AI 编辑，R0065)。`draining` 由 `:deactivate` 落、scheduler reconcile 清，无专门用户动词。

---

## 10. 跨域集成

- **relation**：workflow 是第 **12** 个 EntityKind（前缀 `wf_`，**已登记**）。图的 node.Refs **产出向**引用边 `workflow → {trg_, fn_/hd_/mcp_, ag_, ctl_, apf_}`（全 `KindEquip`，去重——多节点引用同一实体则拓扑边相同），+ 锻造 active 版的对话**入向** `create`(v1)/`edit`(v>1) 边。每次 active 变更（create/edit/revert）重算。读时 `Namer.NamesByIDs` hydrate 名字。
- **catalog**：进（name + description，无描述则回退 tags / `(no description)`）。
- **notification**：`workflow.created/edited/reverted/updated/deleted/lifecycle_changed/attention_changed` 经 `Emitter`。
- **mention**：不进（配置/编排实体，非内容快照）。
- **生命周期**：删 workflow **不级联**删它引用的实体（同 function/agent/control）；孤儿（relation `refCount=0`）按需清理。

---

## 11. 错误字典

| Sentinel | Wire Code | HTTP |
|---|---|---|
| `ErrNotFound` | `WORKFLOW_NOT_FOUND` | 404 |
| `ErrDuplicateName` | `WORKFLOW_NAME_DUPLICATE` | 409 |
| `ErrVersionNotFound` | `WORKFLOW_VERSION_NOT_FOUND` | 404 |
| `ErrNoActiveVersion` | `WORKFLOW_NO_ACTIVE_VERSION` | 422 |
| `ErrInvalidGraph` | `WORKFLOW_INVALID_GRAPH` | 422 |
| `ErrInvalidOps` | `WORKFLOW_INVALID_OPS` | 422 |
| `ErrRefNotFound` | `WORKFLOW_REF_NOT_FOUND` | 422 |
| `ErrInvalidLifecycle` | `WORKFLOW_INVALID_LIFECYCLE` | 422 |

> 工具失败软返 tool-result 串（不冒泡 HTTP）；上表是 HTTP 端点冒泡的 domain 错误。`ErrInvalidGraph` 的人类原因在 `details["reason"]`。

---

## 12. Deferred 到后续波次

**本模块只 STORE + VALIDATE + PIN，不执行。** 推迟的：
- **执行**：durable 解释器 / scheduler（走 pin 的图，import `ValidateGraph`/`BackEdges`/`BuildPinClosure`/`WorkflowReader`）。
- **flowrun / journal**：执行实例 + 持久化流水账 + 重放（`fr_`/`fre_`/`apv_` 表尚未建——仅 `wf_`/`wfv_` 本轮落地）。
- **ancestor-only CEL lint**：§3.1 的更严祖先可见性校验（需 `pkg/cel` 暴露 AST 标识符抽取）。
- **M7 中央装配**：`RefResolver` 接真（✅ `bootstrap.NewRefResolver` 直查 7 实体 Service，非 catalog）、`WorkflowTools` 进 `Toolset.Lazy`、`WorkflowHandler` 注册、`workflowstore.Schema` 进 migrate。
- **`:trigger` / `:iterate`**：执行入口（scheduler 波次）/ AI 编辑（askai 波次 6）。
