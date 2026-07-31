---
id: DOC-006
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Request Context

## 1. 定位

`pkg/reqctx` 用标准 `context.Context` 携带横切身份和本次执行配置。它只依赖
stdlib，使用私有 key，避免把 workspace/chat/workflow 概念倒置到 infra API
参数中。

## 2. 值

| 值 | 主要注入者 | 主要消费者 |
|---|---|---|
| workspace ID | HTTP middleware、background workspace seeding | ORM、所有 workspace services |
| conversation ID | Chat/Subagent | Loop、审计、stream |
| message/tool-call/subagent ID | Chat/Loop/Subagent | 嵌套 stream 与执行溯源 |
| flowrun/node/iteration | Scheduler dispatch | callable Execution/Call audit |
| locale | middleware，workspace language 覆盖 | AI 生成内容 |
| AgentState | Chat/Subagent runner | lazy tools、Skill |
| workdir | Chat turn | filesystem tools、Subagent、write gate |

Workflow fields 只有 Get，无 Require；缺席表示不是 Workflow 调用。Locale 总有
可用默认值。

Stream bridge、HumanLoop broker 与 ToolProgress 由各自 package 的 context key
管理，不并入 reqctx，保持依赖方向。

## 3. Workspace 隔离

HTTP `IdentifyWorkspace` 从 header（SSE 可用 query）识别 workspace，随后
`RequireWorkspace` 在受保护边界拒绝缺失身份。ORM 从 context 自动写/过滤
workspace。

两个错误不可混用：

| 错误 | HTTP | 含义 |
|---|---:|---|
| `UNAUTH_NO_WORKSPACE` | 401 | 客户端没有有效 workspace 身份 |
| `MISSING_WORKSPACE_ID` | 500 | 已越过边界的内部接线漏埋 workspace |

`MISSING_CONVERSATION_ID` 同样表示内部前置条件失败。

## 4. Detached

需要比请求活得久的 finalize、audit 与后台工作使用
`reqctx.Detached(workspaceID)`：

- 从 `context.Background()` 开始，真正脱离已取消请求；
- 重新播种 workspace，保证 ORM 隔离；
- 只按需追加 conversation 等身份。

Trigger/Scheduler 等无原始请求的工作从 durable row 获得 workspace。可取消的
后台循环不能把 loop context 换成 Background；应在调用方 context 上为每个
workspace 派生 seeded context，使 Shutdown 信号继续传播。

## 5. 契约

所有跨层调用继续传 context。ORM 隔离见 [`orm.md`](orm.md)，后台播种见
[`bootstrap.md`](bootstrap.md)，错误见
[`error-codes.md`](../error-codes.md)。
