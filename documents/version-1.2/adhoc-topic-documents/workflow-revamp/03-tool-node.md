# 03 — Tool 节点

脑爆结论笔记(2026-05-27)。

---

## 3 → 1 合并

废弃 `function` / `handler` / `mcp` 三个独立节点,合并成一种 **tool 节点**:统一"调用一个被命名的可执行能力 + 传 args + 拿结果"。

跟 `02-agent-node.md` 里 agent 节点的 tool 挂载 **完全同源** — 同一个 callable 注册表,两种调用方式:

| 调用方式 | args 谁组装 | 谁决定调用 |
|---|---|---|
| **tool 节点(流程直接调)** | 编排时静态填(支持模板插值) | workflow 流程 |
| **agent 节点 tool 挂载(LLM 调)** | LLM 临场组装 | LLM 自治 |

---

## 节点结构

```
type: tool
config:
  callable: <ref>          # 见下方 ref 语法
  args: {...}               # 支持 {{ payload.* }} / {{ ctx.* }} 模板插值
  retry: { maxAttempts: 3, backoff: "exponential" }  # 可选,不填 = 0 次,失败立即通知
  onInfraCrash: retry | dead_letter                  # 可选,默认 dead_letter
  timeout: <duration>                                # 可选,不填 = 永不超时
```

**retry 行为**(跟 [`07-error-handling.md`](./07-error-handling.md) 一致):
- retry 次数内失败 → 只记录,不通知
- retry 用尽 → 平台主动推 SSE 通知;**workflow.active 不变**(tool 节点不是入口)
- `retry` 字段不填 = 0 次重试,失败立即通知

---

## Callable ref 语法

跟 00 总纲 3 "永远 prod" 一致:**ref 永远指 active version**,无 pin 语法。

| Callable | ref 形式 |
|---|---|
| function | `fn_xxx`(永远 active version) |
| handler 方法 | `hd_xxx.methodName`(永远 active version) |
| mcp 工具 | `mcp:serverName/toolName`(MCP 无版本概念) |
| **agent** | **`ag_xxx`**(永远 active version)— 详 [`09-agent-domain.md`](./09-agent-domain.md) |

引用 entity 的 active version 改了 / revert 了,**所有 tool 节点自动跟新 / 跟着回滚**。Workflow accept 时 capability check 校验 active version 是否符合引用上下文(如 trigger 节点要求 function kind=polling)。

---

## Handler 生命周期跟 workflow active 状态走

**`workflow.active = true`** 时,listener 自动触发的 flowrun 共享 handler instance;其他情况(用户/AI 显式触发 / inactive workflow)per-flowrun 独立 instance。

由 `FlowRun.IsFromListener` flag 决定 Owner key:

| 触发来源 | `IsFromListener` | Handler Owner | instance 生命周期 |
|---|---|---|---|
| Active workflow 的 listener 自动触发(cron / fsnotify / webhook / polling) | true | `{Kind: "workflow", ID: workflow.id}` | **跟 workflow.active 同寿,跨触发复用** |
| 用户 UI 点 trigger 节点 / AI `trigger_workflow` 工具 / inactive workflow 的任何触发 | false | `{Kind: "flowrun", ID: flowrun.id}` | 跟 flowrun 同寿,跑完销毁 |

意思是:
- cron 每小时触发 active workflow → **复用同一个 handler instance**(connection pool / counter / cache 跨触发持续)
- 用户在 UI 上点 manual trigger 节点测试 → **独立 instance**,跑完销毁,不污染 active workflow
- AI 调 `trigger_workflow` 跑一次 → **独立 instance**,同上

Handler 作为 **stateful object** 的对象能力 ✓ 保留(active workflow 内 state 跨触发持续)。

### Crash 处理

**Handler 子进程死了**(Python OOM / 未捕获异常 / 外部依赖死):

- 平台 detect(stdio EOF / pipe broken)
- 平台**自动 respawn 新 instance**(`handlerRegistry.Acquire` 现状已经如此)
- **无重启次数硬上限** — 跟 Mechanism vs Policy 原则一致,平台不替用户决定"几次后放弃"

**跑到一半的 message 怎么办** — tool 节点 config 拍:

```yaml
type: tool
config:
  callable: hd_xxx.method
  onInfraCrash: retry | dead_letter      # AI 编排时拍;不填 = dead_letter(放弃)
  retry: { ... }                          # 业务层 retry(callable 返业务错误时)
```

`onInfraCrash`(基础设施死)跟 `retry`(业务返错)分开 — 一个是 Python 进程死,一个是 method 调用返错误。

### State 持久化 — handler 作者完全责任

**平台不提供 state 持久化 helper API**。按"能力源自 forge"原则,handler 作者自治:

| handler 类型 | 怎么做 |
|---|---|
| 完全无状态 | crash 无影响 |
| in-memory state + 丢了不要紧(连接池 / 缓存) | crash 接受丢,新 instance 重建 |
| **in-memory state + 要紧(counter / 业务状态)** | **handler 内部自己写到 file / SQLite**(如 `~/.forgify/handler_state/{handler_id}/`) |

forge 系统在锻造 handler 时,**教学 prompt 必须明示**:

> handler 是 stateful Python class。
> **in-memory state 在 crash 时会丢**。
> 业务状态需要 survive crash 时,自己写到 file / SQLite。
> 平台不提供 state API。

跟 trigger function / function / mcp 的模式一致 — **作者完全自治,平台不当保姆**。

### Workflow 改 / handler config 改时

- 用户改 workflow version 后 `:accept` → 如果 workflow active,撤旧 `{Kind: "workflow"}` instance + 撤旧 listener + 注册新 listener
- 新 instance **lazy** 等首次 listener 触发时 `Acquire` 时 spawn
- 详见 [`06-workflow-lifecycle.md`](./06-workflow-lifecycle.md)

### Forgify 本体重启

```
Forgify 启动
  ↓
扫所有 workflow.active = true 的 row(详 06-workflow-lifecycle.md)
  ↓
re-register 所有 listener
  ↓
handler instance 不预先 spawn(lazy,等首次 listener 触发时 Acquire 时 spawn)
  ↓
handler 内部业务 state(如果作者持久化了)在新 instance init 时从 file/SQLite 读回
```

第一次触发延迟略高(handler 启动 ~5s),本地单用户场景可接受。

### 通知 / 监控

平台**不主动通知**(跟 [`07-error-handling.md`](./07-error-handling.md) 一致)。平台暴露 events API:

```
GET /events?type=handler_crash&workflowId=wf_xxx&since=24h
GET /flowruns/{id}/dead_letters
```

用户/AI 在 chat 里查 + 主动聚合分析:

```
用户:"昨天 cron 跑挂了"
   ↓
AI 调 events / dead_letters API → 查到 handler crash 5 次 + OOM 痕迹
   ↓
AI:"handler 调 Gmail API 时 OOM 了,你的 cache 没限制大小。要改吗?"
   ↓
用户:"好"
   ↓
AI:edit_handler → :accept → replay dead_letters
```

主动聚合 / 诊断 / 修复是 **AI 工程师**的事,不是平台的事。

---

## 并发归 handler 内部

平台**不**给 handler instance 强制串行化。handler 作者自己保证 thread safety。

> Forgify 现状改动:**砍 `infra/handler/client.go` 的 `sync.Mutex` per-instance 串行**。让 handler method 调用真并发。

理由:
- 关注点分离 — 平台管调度,handler 作者管业务并发
- 平台无法做对 — 全锁丢并行,不锁出 race;只有 handler 作者知道自己的 critical section
- **出 race 改 handler,不改平台**

forge 系统在锻造 handler 时,template / 教学 prompt 应明示"stateful class,要考虑线程安全"。

---

## 累计节点数减负

跟前两份共识合算:

| 现状 | 重设计后 |
|---|---|
| llm + agent(2) | agent(1) |
| function + handler + mcp(3) | tool(1) |
| skill(独立节点) | 砍掉(改 agent 挂载) |

**6 个节点 → 2 个节点**。剩 `trigger` / `condition` / `loop` / `approval` / `wait` / `variable` / `parallel` / `http` 待审。
