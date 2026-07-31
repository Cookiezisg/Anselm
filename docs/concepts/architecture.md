---
id: DOC-001
type: concept
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Anselm 架构

> 本文解释系统为什么这样组成以及主要数据如何流动。工程纪律与契约宪法见
> [`CLAUDE.md`](../../CLAUDE.md)；精确端点、表、错误码和事件见
> [`references/backend/`](../references/backend/)。

## 1. 产品边界

Anselm 是本地优先的 Agentic Workflow Platform。Flutter 桌面 app 负责
交互，Go sidecar 负责业务、执行和持久化，SQLite 是本地真相。产品按单进程、
单用户设计，不引入 SaaS 控制面；workspace 是同一安装内的数据隔离单元，
不是远端租户。

用户可以在对话中调用能力，也可以把能力构造成实体、编排进持久工作流。系统
同时支持文本与多模态输入、媒体生成及媒体在对话、实体和工作流之间流动。

两个心智贯穿全局：

- **Quadrinity**：Function、Handler、Agent、Workflow 是四种可构建执行体。
- **Durable Execution**：节点结果写入数据库，解释器通过幂等重走恢复，
  而不是重放一份事件日志。

## 2. 系统边界

```text
Flutter desktop app
        │ localhost HTTP + SSE
        ▼
Go sidecar ───────────────► local SQLite / files / sandbox runtimes
        │
        ├── optional BYOK ─► provider APIs
        │
        └── managed route ─► deployed Anselm API ─► provider APIs
```

本地 sidecar 拥有 workspace、实体、运行记录、附件、install/device proof 和
用户 BYOK 配置。已部署 Anselm API 拥有受管 provider secret、路由、计量和
部署运维；主仓不复制这些内部配置。精确边界见
[`managed-gateway.md`](../references/backend/managed-gateway.md)。

默认受管路径不要求用户在本机配置 provider key。BYOK 是用户主动选择的本地
路径，不是默认产品路径的启动前置。

## 3. 后端分层

依赖单向流动：

```text
transport → app → (domain ∪ infra/store) → infra/db
```

| 层 | 职责 | 边界 |
|---|---|---|
| `transport/httpapi` | HTTP、SSE、middleware、wire 翻译 | 不承载业务规则 |
| `app/<domain>` | 用例与跨实体协调 | 通过端口注入具体能力 |
| `domain/<domain>` | 实体、Repository、领域错误与规则 | 不导入外部实现包 |
| `infra/store` | Repository 的 SQLite 实现 | 服从 domain 接口 |
| `infra/*` | DB、LLM、sandbox、MCP、stream、trigger 等技术实现 | 不反向定义业务语义 |
| `pkg/*` | ORM、上下文、ID、分页、路径、schema 等跨层机制 | 不含业务实体 |
| `bootstrap` | 装配、启动、恢复与关停 | 唯一全局组合根 |

`pkg/orm` 在 `database/sql` 上提供 workspace 隔离、软删除、时间戳和查询
机制；纯 Go SQLite 使 sidecar 不依赖 CGO。LLM、CEL、sandbox 等地基由
infra/pkg 提供，业务层只依赖抽象。

## 4. 能力与实体

### 4.1 四种执行体

| 实体 | 作用 | 执行形态 |
|---|---|---|
| Function | 一次性无状态代码 | sandbox 进程，运行后退出 |
| Handler | 保持状态的类与方法 | sandbox 长驻实例，逐调用记账 |
| Agent | 带模型、指令和挂载工具的 LLM worker | ReAct loop |
| Workflow | 引用其他实体的静态编排图 | durable scheduler |

执行体采用不可变版本行与可移动 active 指针。运行开始后钉住拓扑与引用版本，
因此编辑不会改变在途执行。

### 4.2 Workflow 图

Workflow 用五类节点表达编排：

| 节点 | 引用 | 作用 |
|---|---|---|
| trigger | Trigger | 接收 cron、webhook、文件或 sensor 信号 |
| action | Function、Handler method、MCP tool | 执行一个 activity |
| agent | Agent | 运行一个配置好的 LLM worker |
| control | Control | 用 CEL 选择出口并变换数据 |
| approval | Approval | 渲染人审内容并等待决定 |

边是 payload 数据管道。回边进入下一 iteration；control/approval 的已落库
选择决定当前活跃子图。

### 4.3 对话与知识

Conversation 是持久化 Chat 主机，Messages 保存回合和 block；Subagent 把
嵌套执行写回同一消息树。Skill 提供文件式指令，MCP 接入外部工具，
Document 提供树状内容，Memory 保存跨对话事实，Todo 保存当前行动状态。

@提及注入的是冻结快照，不隐式改写为检索。Search 为人和 agent 提供显式统一
检索；向量能力缺席时可退化为词法检索，不改变业务数据真相。

Relation 保存实体之间的结构关系，Touchpoint 保存某次对话实际接触过什么。
前者回答“系统怎样连接”，后者回答“这段交互发生过什么”。

## 5. Durable Execution

一次 workflow 执行由 `flowruns` 头和 `flowrun_nodes` 节点结果组成。
`(flowrun_id, node_id, iteration)` 唯一约束实现 record-once：

```text
读取冻结图和已落库节点
→ 推导 ready 节点
→ 执行并记录结果
→ 再次推导
→ 完成、失败或停在 approval
```

进程崩溃后再次调用 `advance()` 即可恢复。completed 节点直接复用结果，不再
触发外部副作用。版本 pin 保证在途图稳定；per-run guard 保证同一 run 单飞；
后台 run 进入有界执行池，避免慢节点阻塞整个 firing drain。

Trigger 采用 persist-before-act：信号先成为 durable firing，再 claim、建
run、执行。多个 workflow 可共享一个 listener；引用归零时 listener 才退出。
Approval 是持久节点状态，人工决定或超时策略使其继续推进。

精确状态、并发、恢复、replay 与 retention 语义见
[`scheduler-flowrun.md`](../references/backend/foundation/scheduler-flowrun.md)。

## 6. 多模态是系统级数据流

媒体不是 Chat 的局部插件，而是横跨产品的统一数据类型。其核心约束由
[ADR 0014](../decisions/0014-mediaref-one-currency.md) 定义：

1. **一种引用**：媒体以含 `attachmentId` 的 MediaRef receipt 流动；
   文档正文使用同一语法族的 `anselm://media/<id>`。
2. **一间存储**：用户上传、受管生成、MCP 二进制、Function/Handler
   sandbox 产物和朗读结果最终都成为 Attachment。
3. **统一消费**：进入模型前根据目标模型能力与请求信封转换为 content
   parts；不能消费该模态时保留可解释的文本引用。
4. **统一呈现**：前端按 Attachment 的真实 MIME 分发媒体卡，Chat、
   flowrun 检查器、实体调试、approval 和文档编辑器复用同一媒体层。

媒体生成仍是 Tool，不是新实体。可用 capability 决定工具是否被挂载到 Chat、
Agent 和 Subagent；无路由时工具诚实缺席。媒体字节不穿过 tool result、
workflow result 或 SSE 反复复制，只传播 receipt。

受管上传与生成经 device proof 到 Anselm API；本地附件行和 MediaRef 仍由
sidecar 持有。BYOK 可按模型能力消费多模态输入，受管生成与 BYOK 读取互不
冒充。后端接缝见 [`attachment.md`](../references/backend/domains/attachment.md)
和 [`loop.md`](../references/backend/foundation/loop.md)，前端接缝见
[`contract.md`](../references/frontend/contract.md) 与各 feature reference。

## 7. 主要端到端路径

### 7.1 对话

```text
composer input + mentions + attachments
→ Conversation/Message 落库
→ assemble model context and capability tools
→ LLM stream / tool loop / subagent
→ blocks + attachments + touchpoints
→ messages SSE
→ transcript and side stage
```

数据库行是 reload 真相；SSE 只负责把正在发生的过程及时送到界面。重试以版本
指针标出被取代回合，被取代行仍可读，但不会重新进入模型上下文。

### 7.2 Workflow

```text
trigger or manual invocation
→ durable firing / flowrun
→ pin graph and referenced versions
→ scheduler advances ready nodes
→ node results and approval states persist
→ entities SSE
→ scheduler matrix and run inspector
```

Agent 节点、action 节点和 approval 都可携带 MediaRef，因此多模态不在进入
workflow 后降格成 Chat 私有格式。

### 7.3 前端运行

```text
desktop host starts sidecar
→ health gate
→ REST snapshot
→ three persistent SSE streams
→ Riverpod server state
→ AppShell islands and feature views
```

前端采用 `lib/core → lib/features → lib/app` 的 feature-first 分层。Chat、
Entities、Library、Scheduler、Settings 和 Notifications 共享唯一装配根；
具体路由与宿主机制见
[`references/frontend/architecture.md`](../references/frontend/architecture.md)。

## 8. 实时协议与平台

系统只使用 `messages`、`entities`、`notifications` 三条 workspace 级 SSE：

- durable 帧带正 `seq`，进入 replay buffer 并推进游标；
- delta、tick 等瞬时帧使用 `seq=0`，只更新临时视图；
- messages 通过 `parentBlockId` 表达 subagent 树。

Function、Handler 和部分本地能力运行在按需安装的 sandbox runtime 中。
runtime 下载、校验和生命周期由 sidecar 管理；发布二进制不内嵌这些大型产物。
桌面平台差异留在宿主与依赖适配层，不进入业务 domain。

## 9. 明确非目标

- 远端账号、密码、session 与多租户 SaaS；
- 分布式 worker fleet、sharding、lease 或外部 task queue；
- 把 @提及隐式替换成 RAG；
- 为本地单用户规模引入外部向量数据库；
- 在 current 架构文档保存施工路线、战役溢出 TODO 或历史快照。

未完成工作只进入有生命周期的 [`working/`](../working/)；当前产品与工程入口
分别以 backend/frontend overview 为准，历史只从 ADR、`archive/` 和 git
追溯。
