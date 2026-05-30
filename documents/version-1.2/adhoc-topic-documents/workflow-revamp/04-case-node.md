# 04 — Case 节点 + 控制流

脑爆结论笔记(2026-05-27)。

依赖纲领:[`00-overview.md`](./00-overview.md) 的 message queue 模型 + parentId 因果链。

---

## 一个节点覆盖所有控制流

废弃 `condition` / `loop` / `variable` 三个节点。合并成一种 **case 节点**:

- **多路 switch** 取代二元 if-else
- **回边** 形成 loop,取代嵌套 body 子图
- **变量完全砍** — 状态用 handler / 消息流显式表达,不再有隐式全局变量

---

## case 节点形态

```yaml
type: case
config:
  expression: <CEL 表达式>       # 例: payload.category / payload.attempt > 5
  branches:                     # N 路命名分支,每个是输出端口
    invoice:
      to: handle_invoice_node
      # 不写 emit → 完全透传 payload
    inquiry:
      to: lookup_faq_node
      emit:                     # 可选:CEL 表达式构造下游 payload
        question: payload.text
    spam:
      to: end_node
    _default:
      to: notify_human_node
```

每个 branch 端口:

- `to` — 下游节点 ID(可连**任意节点**,**包括上游已激活过的节点 → 形成 loop**)
- `emit`(可选)— 每字段一个 CEL 表达式,**构造下游 payload**;不写 = **透传上游 payload**

---

## 这不是 DAG — 是 message queue + actor 编排

workflow **不是 DAG**(Directed Acyclic Graph,有向无环图)。case 节点的回边能让消息进入上游节点的 inbox,**节点被反复激活**——这是 actor + message queue 编排模型的天然形态。

执行模型从拓扑驱动(Kahn)→ message 消费驱动:节点可被反复激活,每次激活对应一条独立消息。

行业对照:

| 类别 | 代表 | 模型 | Forgify |
|---|---|---|---|
| 数据 pipeline | Airflow / Prefect / Dagster | 严格 DAG | ❌ |
| No-code 自动化 | n8n / Dify / Coze | 严格 DAG | ❌ |
| LLM agent 框架 | **LangGraph**(state graph + cycles) | **有环图** | **✅ 同类** |

只允许 case 节点产生回边,其他节点出边仍单向。

---

## Loop 表达 — case + 回边

```
trigger → [tool init] → [agent process] ←─┐
                              ↓             │
                         [case continueExpr]│
                              ├─ yes ────────┘   ← 回边,emit 时 attempt+1
                              └─ no → [tool finalize]
```

业务"第几次"计数 **由编排者放 payload**(平台不管):

- case 回边时在 `emit` 里显式 `attempt: (payload.attempt || 0) + 1`
- 下游节点(agent prompt / 后续 case)读 `payload.attempt`

平台 ctx 只携带审计 / 因果元信息:

- `ctx.parentId` — 上一轮消息 ID(因果链回溯)
- `ctx.path` — 经过的节点序列

**没有 `ctx.iterationIdx` 这种平台层业务计数字段** — 跟 Mechanism vs Policy 原则一致,计数是业务的事。

---

## case 回边的精确语义 = "复制消息进上游 queue"

case 节点决定回边时,emit 一条**新消息**到上游节点的 inbox:

```
原消息 M0 → 走到 case 节点 → case 决定走"回边"分支(假设 branch 名 = "no")
            ↓
case emit 新消息 M1:
  M1.payload = branch.emit ? evalCEL(branch.emit, M0)    # 按 emit 表达式构造
              : M0.payload                                # 不写 emit 则透传
  M1.queueName = queueOf(branch.to)                       # 上游节点的 inbox
  M1.ctx = {
    ...M0.ctx,                                            # 大部分继承
    parentId: M0.id,                                      # 因果链
    path:     [...M0.ctx.path, "case"]
  }

upstream_node 自然 consume M1
```

机制特性:

| 特性 | 价值 |
|---|---|
| **节点不知道自己被重跑** | 它只是又收到一条 message。actor 逻辑无需处理"我是第几次跑" |
| **业务计数靠 payload** | case 在 emit 里显式 `attempt: payload.attempt + 1`;下游节点读 `payload.attempt`(平台不参与) |
| **因果链完整** | parentId 链可 trace 任何消息到来源,debug 一目了然 |
| **没有 undo / rollback** | 节点已有副作用就在那里;state 该在 actor 内部维持的继续保留(handler stateful) |
| **旧消息持久** | M0 仍在历史里,M1 是新消息物理实体,审计完整 |

**统一抽象**:所有"重跑"场景(case 回边 / 失败 retry / 用户 replay 死信)**都是同一个底层机制——复制 message 进对应 queue**。详 [`07-error-handling.md`](./07-error-handling.md)。

---

## 终止 / 死循环防护

平台**不**对"节点激活次数"设业务相关 hard cap。终止靠以下三层:

| 层 | 谁定 |
|---|---|
| **编排者责任**(主要)| case expression 自己写合理终止:`payload.confidence > 0.9` / `payload.attempt > 5` 等 |
| **Workflow timeout**(兜底)| 用户/AI 编排时拍 `workflow.timeout`;不填 = 永不超时 |
| **Flowrun 总消息上限**(可选兜底)| 用户/AI 拍 `workflow.maxMessages`;不填 = 无上限 |

跟 [`07-error-handling.md`](./07-error-handling.md) 的 Mechanism vs Policy 原则一致——平台**永远不猜**"100 次算异常"这种业务相关阈值。

---

## 表达式语言 = CEL

砍 Go text/template(模板渲染语言不是表达式语言)。

锁定 **CEL**(Google Common Expression Language,Go 实现 `google/cel-go`)。

理由:
- 业界标准 — K8s admission webhook / Istio / Tekton / OPA 全用 CEL,**LLM 训练数据见得最多**
- 强类型系统让 workflow accept 时能 validate expression(编排时报错优于运行时报错)
- Google 官方维护,长期可靠
- 设计就是沙箱 + null 安全

例子:

```cel
// 简单分类(意图识别场景)
payload.category == "invoice"

// 终止条件(case 回边场景,业务计数靠 payload)
payload.attempt > 5
payload.attempt > 5 || payload.confidence >= 0.9

// 字段判断
payload.items.size() > 0
payload.user.name.startsWith("admin")

// 复合条件
payload.score >= 0.8 && ctx.triggerKind == "polling"

// 包含判断
"important" in payload.tags
```

### 产品边界 — case 是"看牌发牌员",不是"分析师"

case 节点的职责**严格限定**:**对上游已经准备好的字段做简单判断 → 路由**。

| 不该塞进 case 表达式 | 应该走的路 |
|---|---|
| 计算 / 统计 / 数据转换 | 上游用 agent 节点(LLM)或 tool 节点(forge function)产出结果,case 只读 |
| 调用外部 API 判断 | 上游用 tool 节点 |
| 多步骤推理 | 拆成多个 case 串联 或 上游 agent 节点判断 |

跟员工思维一致 — case 是简单看牌的发牌员。要"分析"必须上游做完,case 只看结果。

反模式:

```
❌ [case 复杂 CEL 表达式硬塞业务逻辑]
```

正确模式(意图识别):

```
✅ [agent classifier outputSchema=enum] → [case payload.category]
```

### 平台约束(安全 / 资源兜底,跟业务无关)

| 项 | 值 | 类别 |
|---|---|---|
| 评估超时 | 100ms | **安全兜底**(防恶意表达式 CPU 卡死) |
| 可用变量 | 只 `payload` / `ctx`,不暴露 `env` 等隐式状态 | **机制层**(actor 模型) |
| 可调函数 | CEL 默认包(string / list / time);**不暴露 LLM 调用 / HTTP / 任意计算** | **安全兜底**(case 不该有副作用) |

表达式长度等"业务相关"约束**不在平台层**——AI 编排时自律(写太长就拆成 agent + case 组合)。

---

## 输出语义

case 节点**按 branch 的 emit 表达式构造下游 payload**(不写 emit 则透传):

- 评估 expression → 选中 branch X
- 取 branch X 的 `to`(下游节点)+ `emit`(可选)
- emit 消息:`payload = branch.emit ? evalCEL(branch.emit, msg) : msg.payload`
- `ctx.parentId = M0.id`(因果链)

case 节点**不做业务计算 / 推理** — `emit` 表达式只用于"构造下游需要的 payload 形状"(包括 attempt+1 这种简单计数),业务逻辑(分类 / 提取 / 推理)仍由上游 agent / tool 节点完成。case 是"看牌发牌员",不是"分析师"。

---

## 跟意图识别的天然对齐

agent 节点的 `outputSchema: enum` 输出 + case 节点的 switch 完美咬合:

```
trigger
  ↓
[agent classifier]              ← outputSchema: enum [invoice, inquiry, spam]
  ↓ emit message{ payload.category: <enum 值> }
[case payload.category]
  ├─ invoice → [tool: handle_invoice]
  ├─ inquiry → [tool: lookup_faq]
  ├─ spam    → 结束
  └─ _default → [tool: notify_human]
```

意图识别不需要"专门 intent 节点"——agent + case 自然组合。Forgify Phase 5 backlog 里那个 `intent` domain 不需要在 workflow 这边做。

---

## 跟 variable 砍除的关联

variable 节点砍除后,跨节点状态有两条路:

1. **走显式消息流**:节点 A emit 消息时把状态放 payload,下游节点读出来。**因果链可 trace**
2. **真持久化状态**:用 handler stateful class(per-deployment instance)

variable 想做的"workflow 级全局变量"完全被这两条覆盖,且**没有隐式状态污染**——任何节点拿到的值都能 trace 回它的产生节点。

---

## 累计节点数

跟纲领锁定的 5 节点:

| | |
|---|---|
| trigger / agent / tool / case / approval | 保留 |
| 砍 9 个 | llm / function / handler / mcp / skill(独立) / condition / loop / variable / parallel / wait / http |

**14 → 5**。控制流只剩 case 一种,其他控制能力(并发 / 延迟 / 状态)在 infra 层。
