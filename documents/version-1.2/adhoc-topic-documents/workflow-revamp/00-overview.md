# 00 — Overview

脑爆纲领(2026-05-27)。本文件统领 01-07 各份子设计,是整个 workflow-revamp 的核心心智事实源。

---

## 总原则:Mechanism vs Policy 分离

> **平台只提供机制(mechanism),策略(policy)由 workflow 编排者(AI / 用户)在编排时决定。**
>
> 平台不知道业务,**永远不猜默认值,永远不替用户做决定**。

派生:
- ❌ 无 timeout / retry / cap / 错误分类 等任何平台默认值
- ✅ 所有行为参数由 AI 在编排时拍(或用户在 UI 拍),不填 = 不做
- ✅ **安全 / 资源兜底**(防平台自己崩,跟业务无关 — 如 CEL 表达式评估超时 / sandbox 内存上限)平台必须保留
- ✅ **通知是 mechanism**(平台保证)— 节点 retry 用尽时平台必推 SSE 通知;**Trigger 节点 retry 用尽时平台自动 deactivate workflow**——这不是"替用户暂停",是诚实呈现"入口已废"。详 [`07-error-handling.md`](./07-error-handling.md)

跟 Dify / n8n 差异化:他们靠平台 hardcode 默认值弥补"用户拖拽时不会想细节",Forgify **AI 编排时主动问 / 显式画**,不需要平台兜底业务。

详 [`07-error-handling.md`](./07-error-handling.md)。

---

## 产品定位 — 不是 workflow engine,是 message queue + actor 编排

| 业界类别 | 代表 | 图模型 | Forgify |
|---|---|---|---|
| 数据 pipeline | Airflow / Prefect / Dagster | 严格 DAG | ❌ |
| No-code 自动化 | n8n / Dify / Coze | 严格 DAG | ❌ |
| LLM agent 框架 | **LangGraph**(state graph + cycles) | **有环图** | **✅ 同类** |

Forgify 是**本地版的 actor + message queue 编排系统**:

- 节点 = actor(单一职责,接消息 → 处理 → emit)
- 边 = 持久化 message queue
- 触发 = emit 第一条消息进 workflow 入口 queue
- 所有控制流(if-else / loop / retry / approve)= 不同的 emit 策略
- case 回边 = "复制消息进上游 queue",节点被反复激活(详 [04-case-node.md](./04-case-node.md))
- 重试 / 回边 / 重放 = **同一个底层机制**(详 [07-error-handling.md](./07-error-handling.md))

跟微服务架构**心智同源**(choreography 而非中央 orchestration / actor 解耦 / 消息驱动 / 因果链追踪),但**单进程** SQLite-backed 实现,无 distributed transaction / service discovery / load balancer。

---

## 核心抽象:Message Queue 模型

workflow 重新建模:**节点是 actor,边是持久化 message queue,所有信息流动都是消息传递**。

消息形态:

```
Message {
  id:               msg_<16hex>,
  queueName:        <producer→consumer 边标识>,
  flowrunId:        fr_<16hex>,
  ctx: {
    workflowId:      wf_<16hex>,
    triggerNodeId:   <被触发的 trigger 节点 ID>,
    triggerKind:     cron | fsnotify | webhook | polling | manual,
    isFromListener:  true | false,                   # 决定 handler Owner 模式
    path:            [trigger, nodeA, nodeB, ...],   # audit trail
    iterationIdx:    0,                              # case 回边 +1
    parentId:        <msg_yyy>,                      # 因果链
    scheduledAt?:    <RFC3339>,                      # 延迟投递(可空)
    timestamps:      { produced, consumed, ... }
  },
  payload: <业务数据>
}
```

**ctx = 元信息(只读)**,**payload = 业务数据**。模板插值跨整条消息:`{{ ctx.triggerKind }}` / `{{ payload.foo }}`。

---

## 5 个节点全集

砍 14 → 留 5:

| 节点 | 角色 | 详设计 |
|---|---|---|
| `trigger` | workflow 入口,emit 首条消息进 workflow | [01-triggers.md](./01-triggers.md) |
| `agent` | thin wrapper,引用 forge 出来的 agent entity | [02-agent-node.md](./02-agent-node.md) + [09-agent-domain.md](./09-agent-domain.md) |
| `tool` | 调用 forge 出来的 callable(function/handler/mcp/**agent** 之一);编排时静态 args | [03-tool-node.md](./03-tool-node.md) |
| `case` | 多路 switch 路由 + 可回边形成 loop | [04-case-node.md](./04-case-node.md) |
| `approval` | 异步等用户决策(yes/no + markdown prompt + 可选 reason) | [05-approval-node.md](./05-approval-node.md) |

### 砍掉的 9 个 + 原因

| 砍 | 原因 |
|---|---|
| `llm` | 合到 agent(空 tool 自动 single-shot 退化) |
| `function` / `handler` / `mcp` | 合到 tool |
| `skill`(独立节点) | 改 agent 的挂载 |
| `condition` | 合到 case |
| `loop` | 合到 case + 回边 |
| `variable` | 跟消息流重叠 + 隐式全局状态反 actor 模型;真要跨节点状态用 handler |
| `parallel` | 并发是 infra 行为,图里平行边自然并发,不需要节点表达 |
| `wait` | 延迟是消息 metadata(`scheduledAt`),不是节点类型 |
| `http` | 用 forge function 包装,跟"能力源自 forge"原则一致 |

---

## 三条总纲

### 1. 员工思维

> **workflow 节点 = 员工**:接收固定任务 + 用配好的方法和工具 + 执行 + 输出。**不改变流程结构,不调度其他人**。

派生约束:

- agent 节点不能 spawn subagent / 不能调其他 workflow
- skill 编排时预激活,不让 LLM 临场 search/activate
- tool 必须 forge,不挂平台黑盒(fs / shell / web / memory / ask 等一律不挂)

### 2. 能力源自 forge

所有外部能力接入**只有一个来源**——forge。无平台黑盒 escape hatch。

| 层 | 来自 forge 的能力 |
|---|---|
| trigger 层 | polling function(AI 帮造,对接 SaaS / 复杂判断 / 第三方无 webhook 服务) |
| tool 层 | function / handler / agent 都是用户/AI 锻造;mcp 是 marketplace 装 |
| 状态层 | 跨节点状态用 handler stateful class,而非 variable |

### Quadrinity — Forgify 的 4 类 forge 实体

| | function | handler | **agent** | workflow |
|---|---|---|---|---|
| 性质 | 纯函数 | stateful class | **LLM ReAct loop 配置** | 编排 |
| 版本管理 + pending/accept | ✅ | ✅ | ✅ | ✅ |
| AI 锻造工具(对齐) | 9 个 | 10 个 | **11 个** | 9 个 |
| 可作 callable 被引用 | ✅ `fn_xxx` | ✅ `hd_xxx.method` | ✅ `ag_xxx` | ❌(员工思维,不能调其他 workflow) |
| ID 前缀 | fn_/fnv_/fne_ | hd_/hdv_/hcl_ | **ag_/agv_/agx_** | wf_/wfv_/fr_ |

mcp 是从 marketplace 装,不算 forge。Quadrinity 严格指 forge 体系的 4 元 = **function / handler / agent / workflow**。

### 3. 永远 prod

> 所有"X 引用 Y"的关系,**Y 永远是 active version**。无 version pinning,没有 `@v3` 这种语法。

派生:
- **改 Y → 所有引用 X 自动跟新**(没有"老 workflow 仍用老版本"这种事)
- **revert Y → 所有引用 X 跟着回滚**
- 改坏了 → 用户/AI 主动 deactivate workflow + 修 + 重新 activate
- forge entity 加 kind 字段(如 function 的 `normal` / `polling`)— **kind 是 version 级**,可在新 pending version 改
- Workflow accept 时 capability check 校验"引用需要 vs active version 实际 kind",不匹配 → workflow accept 失败 / 标 needs_attention
- AI 工程师角色:改 entity 之前主动告诉用户"这影响 workflow A/B/C,确定吗?"

跟 K8s deployment "所有 pod 用同一 image" 心智一致 — **简单 > 灵活**。Forgify 本地单用户场景,无 SaaS 级 version pinning 必要(无 enterprise 合规 / 无 dev-staging-prod 隔离 / 无多租户)。

---

## Message Queue Mini Infra

边的具体实现:**SQLite-backed 持久化 queue**,单进程 / 同步消费 / 因果链。

### Scope

| 要 | 不要 |
|---|---|
| 持久化(SQLite) | Kafka 全套(consumer group / partition / replication) |
| 因果链(parentId) | 高吞吐 / 跨进程 / 跨机器 |
| 延迟投递(scheduledAt) | 真 distributed transaction |
| 历史 query(audit / debug / replay) | Service discovery / load balancer |

### Schema 草案

```sql
CREATE TABLE messages (
  id              TEXT PRIMARY KEY,           -- msg_<16hex>
  queue_name      TEXT NOT NULL,              -- producer→consumer 边
  flowrun_id      TEXT NOT NULL,
  ctx             TEXT NOT NULL,              -- JSON
  payload         TEXT NOT NULL,              -- JSON
  produced_by     TEXT,
  produced_at     DATETIME NOT NULL,
  consumed_by     TEXT,
  consumed_at     DATETIME,                   -- NULL = 未消费
  parent_id       TEXT,                       -- 因果链
  iteration_idx   INTEGER DEFAULT 0,
  scheduled_at    DATETIME                    -- NULL = 立即可消费
);

CREATE INDEX idx_messages_queue_pending
  ON messages (queue_name, scheduled_at)
  WHERE consumed_at IS NULL;
```

消息**永不删**(retention 按时间过期 GC,见下)。

### App 层 API

```go
interface MessageQueue {
  Enqueue(queueName, ctx, payload, parentMsgID?, scheduledAt?) → messageID
  Dequeue(queueName, consumerNode) → Message              // 阻塞或带 timeout
  History(flowrunID) → []Message                          // 调试 / replay
  Trace(messageID) → []Message                            // parent_id 链回溯
}
```

`infra/messagequeue/` ~300 行 SQLite-backed Service。

### Retention

平台不设默认值。**用户/AI 在 workflow 或全局配置里拍 retention 天数**。GC 任务跑用户配的规则。

### 消息原子性

节点处理消息 = **接 + 跑 + 传下游** 三步。"跑"几秒不能放进 SQL 事务,**crash 在中间会出"半完成"消息**(已 consume 但没 emit 下游)。

平台保证:
- consume 是原子(单 UPDATE)
- emit 多条下游 + 标 processed 在同一个 SQL transaction(全成或全失败)
- 中间"跑" crash → 半完成消息留在表里(`consumed_at != NULL AND processed_at = NULL`)

半完成消息怎么处理 — **tool 节点 config 拍**:

```yaml
type: tool
config:
  onInfraCrash: retry | dead_letter      # 不填 = dead_letter
```

- `retry` → 重跑该消息(handler 作者**必须 idempotent**,用 message ID 或 idempotency key 防重复副作用)
- `dead_letter`(默认) → 进死信,人工 / AI 决定要不要 replay

跟 Kafka / SQS / RabbitMQ 一样,**Forgify 不保证 exactly-once**(分布式经典 trade-off,单进程也遵循)。编排者选 `retry` + handler idempotent = 业务层达成 exactly-once 效果。

`onInfraCrash` 字段覆盖所有进程 crash 场景(handler 子进程死 / Forgify 主进程死 / 强杀)— 详 [`03-tool-node.md`](./03-tool-node.md) Handler 生命周期段。

---

## 执行模型

从 Forgify 现有 `driveLoop` 拓扑驱动 → message queue 驱动:

1. **trigger Service emit 首条消息**到 workflow 入口 queue,ctx 带 triggerNodeId + flowrunId
2. **入口节点 consume → 处理 → emit 下游消息**
3. 下游节点同样 consume → 处理 → emit...
4. **case 节点**按 expression 选 branch,emit 消息进对应 branch queue;支持回边
5. **终止条件**:无新消息可消费 / workflow timeout 到 / 用户 cancel

### 资源 / 安全兜底(防平台自己崩,跟业务无关)

| 兜底 | 谁定 |
|---|---|
| Workflow timeout(整体跑多久强杀) | **用户/AI 编排时拍**;不填 = 永不超时 |
| Sandbox 内存上限 / 文件描述符上限 | 平台保留(防进程崩) |
| CEL 表达式评估超时 | 平台保留(防恶意表达式 CPU 卡死) |
| Message queue 单 flowrun 总消息上限 | **用户/AI 编排时拍**;不填 = 无上限 |
| 死循环 | **编排者责任**(case expression 自己写合理终止 + workflow timeout 兜底) |

平台**不**有"hard cap 100 次激活"这种业务相关的硬阈值。

---

## Workflow lifecycle

**没有独立的 "Deployment" 抽象层。**用 `Workflow.active: bool` 一个字段表达"上线 / 下线",`FlowRun.IsFromListener: bool` 一个 flag 表达"触发来自 listener 自动还是用户/AI 显式"。

### Workflow.active 语义

| 状态 | 含义 |
|---|---|
| `active = true` | 扫 workflow graph 中所有 listener 类型的 trigger 节点(cron / fsnotify / webhook / polling),注册到对应 listener,**listener 开始监听** |
| `active = false` | 撤所有 listener,销毁 `Owner={Kind:"workflow"}` 的 handler instance。**Manual 节点仍可被显式触发**(workflow 还在就能调) |

**Activate / Deactivate 只管 listener,不管 manual trigger 节点**。Manual 节点本来就没 listener,语义跟 active 状态无关。

### 触发的统一入口

```
scheduler.StartRun(workflowId, triggerNodeId, payload, isFromListener)
```

3 套入口汇聚:
- listener 自动:`isFromListener=true`
- UI 用户点 trigger 节点 / AI `trigger_workflow` 工具:`isFromListener=false`
- HTTP `:trigger`:`isFromListener=false`

`IsFromListener` 决定 handler instance Owner:`true → {Kind:"workflow"}`(active workflow 内跨触发复用);`false → {Kind:"flowrun"}`(per-flowrun)。

详见 [`06-workflow-lifecycle.md`](./06-workflow-lifecycle.md) 和 [`03-tool-node.md`](./03-tool-node.md) handler 生命周期段。

---

## 跟 chat 的产品对照

| | chat agent | workflow agent 节点 |
|---|---|---|
| 角色 | **老板** | **员工** |
| 任务来源 | 用户对话 / 探索 | 上游 queue 的消息 |
| skill | 自己 search + activate | 编排时配死 |
| tool | 自己挑 + 临场 forge | 编排时配死 |
| subagent | 可 spawn | 不能 |
| 改流程 | 自由探索 | 不能 |

**Forgify 产品 narrative**:**chat 是探索 / 设计 / 锻造的地方;workflow 是沉淀 / 自动化 / 规模化的地方**。锻造完的能力 → 沉淀进 workflow,员工 actor 无人值守干活。

---

## 待继续脑爆的大块

按依赖顺序:

1. ~~Approval 节点详设计~~ ✅ [`05-approval-node.md`](./05-approval-node.md)
2. ~~Workflow lifecycle~~ ✅ [`06-workflow-lifecycle.md`](./06-workflow-lifecycle.md)
3. ~~编排 UI~~ ✅ [`08-orchestration-ui.md`](./08-orchestration-ui.md)(沿用现有 WorkflowEditor,5 节点 + 滴答 + 触发按钮)
4. ~~错误处理 + 重试 + 死信~~ ✅ [`07-error-handling.md`](./07-error-handling.md)(已重写,Mechanism vs Policy 分离)
5. ~~case 表达式语言~~ ✅ CEL,详 [`04-case-node.md`](./04-case-node.md)
6. ~~iterationIdx 谁设~~ ✅ 砍掉概念(用户原则:平台不替业务做决定;业务"第几次"语义放 payload)
7. ~~handler crash + state 持久化~~ ✅ 详 [`03-tool-node.md`](./03-tool-node.md) Handler 生命周期段
8. ~~消息原子性~~ ✅ 详上方 Message Queue Mini Infra 段

---

## 跟旧 01/02/03 doc 的关系

01/02/03 在 message queue 心智之前写就。**具体决策全部仍成立**,只是术语层面 mapping:

| 旧表达 | 新心智下 |
|---|---|
| trigger 节点 `out` 端口透传 event | trigger emit 消息进 workflow 入口 queue |
| 节点 `out` 端口 | 节点 emit 消息到下游 queue |
| `{{ nodes.X.out }}` 模板插值 | `{{ payload.* }}` / `{{ ctx.* }}` |
| Outputs map | 消息流 + parent_id 链 |

旧 doc 内文先不动,本 overview 作为新心智事实源。实施时统一改写。
