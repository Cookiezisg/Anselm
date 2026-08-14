---
id: DOC-030
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 支撑服务——十二个横切微域

> 本篇登记没有独立长篇的支撑域。HTTP 形状见 [`api.md`](../api.md)，表与索引见 [`database.md`](../database.md)，事件见 [`events.md`](../events.md)。

## Workspace

Workspace 是所有业务隔离的根，也是唯一不带 `workspace_id` 的业务实体。HTTP middleware 解析 workspace 并把 id/locale 放入 ctx；store 通过 reqctx 自动过滤。异步任务必须用 `reqctx.Detached(wsID)` 重新播种。

- CRUD，最后一个 workspace 不可删除；`GET /workspaces` 返回机器级有界全量名册，不分页，按创建时间升序、同一时间按 id 升序，保证冷启动首行与切换器顺序稳定；
- `POST /workspaces/{id}:activate` 是切换器的记账动作：只刷新目标 workspace 的 `lastUsedAt` 并返回后置快照；客户端切换必须调用它，但不得等待它完成才呈现新 workspace；
- 保存语言、六类 scenario 默认（`dialogue`、`utility`、`agent`、`image`、`speech`、`video`）、默认搜索与 web fetch mode；
- 删除先停止 workflow/handler/MCP/search 等活资源，再移除 workspace；
- stats 为删除确认提供内容计数、在飞状态与 blob bytes；无法在预算内统计磁盘时返回诚实未知。

## API Key

API key 以 AES-GCM 加密存储，普通读形态只返回掩码元数据。Create/Patch 后 probe 能力；删除前扫描 scenario、Agent override 等引用。
删除是保留主行身份的软删，但用户确认的“永久删除”会在同一条数据库更新中清空加密 secret、掩码、连接配置和 probe 回执；因此审计身份可留存，凭证不可恢复。

- managed `anselm` 行由后端创建，用户不可编辑或删除；
- managed 行存公开 install id，认证由 device proof 完成；
- custom provider 必须声明受支持 api format；
- secret 不进入 provider 目录、日志、Dump、诊断或前端 state。

## Free Tier

Provisioner 在 boot 与 workspace 创建后 best-effort 确保 managed 行和未配置 scenario 默认。机器级 Ed25519 私钥加密落盘，只由 sidecar 使用。

- 没有 managed 行时登记 install 并创建；
- 已有行只在网关明确 `INVALID_INSTALL` 时原位修复；
- 瞬时网络/限流/5xx 不轮换身份；
- quota 由 sidecar 带 proof 代理；
- 失败不阻塞本地启动/onboarding。

公开接缝和 API Serve 责任边界见 [`managed-gateway.md`](../managed-gateway.md)。

## Model

`ModelRef` = apiKeyId + modelId + native options。六个 scenario 默认的 PUT/DELETE 以 path workspace 为资源 owner；解析遵循 override 优先、workspace scenario 默认兜底；options 必须匹配该 key/model 已探测的 knob 与值。

CapabilityService 从 probe 与目录聚合上下文、输出、工具、多模态、文档与 media envelope 能力。模型存在、能聊天、能当 Agent、能读某模态分别表达，不相互推导。

## Web Search

Websearch domain 只定义 provider 词汇与 key picker。执行在 web tool；每次使用 workspace 默认搜索 key，不遍历 provider 猜可用性。

## Catalog

Catalog 按请求聚合 Function、Handler、Agent、Skill、MCP、Document、Attachment 等 source，生成 system prompt 摘要与结构化 coverage。它不持久化、不缓存；当前实体真相是唯一来源。

## Mention

Mention 是发送时冻结的引用快照。多数类型注入只读内容；`@skill` 额外激活 skill 并预授权其 allowed-tools。实体后续变化不改写历史消息的快照。

## Notification

Emitter 有两档：

- Emit：写 durable notification 行并广播；
- Broadcast：只广播对账信号，真相留在实体自身。

feed、mark read/all 与 unread count 只针对 durable 行；逐事件档位见 [`events.md`](../events.md)。

## AI Spawn

`:iterate` 与 `:triage` 都创建一条预置上下文的普通对话，再交给标准 chat loop。前者携实体快照与修改目标，
并明确要求模型调用与被 @ 实体匹配的 `edit_function`、`edit_handler`、`edit_agent`、`edit_workflow`、
`edit_trigger`、`edit_control`、`edit_approval` 或 `edit_document`，不得把编辑误变成 create。
所有编辑立即生效且没有 pending/review 闸；版本化实体通常生成新的 active version，trigger/document 则原地编辑、
没有版本指针。对 Function/Handler 的“重建或重试失败环境但不改变定义”，引导必须选择对应的 edit 工具并传
`ops: []`；Handler 的 `restart_handler` 只重置 resident process，不会重建或重装环境。后者携失败执行证据；
两者都不另建第二套 AI 执行引擎。Triage 输出必须原样保留执行证据中的 opaque id；如果以 Markdown 引用字面量，
必须使用成对反引号，发送前校对代码 span 与语法，不能把 id 截断成自然语言残片或凭空造出占位 id。

## Human Loop

进程内 broker 按 toolCallId 阻塞等待 danger/ask/approval 决议，并把 pending request 经 ephemeral 信号表面化。`approve_always` 与 active skill 预授权只作用于当前对话运行时；重连同步通过专用 pending read。

## Context Manager

回合边界读取最后一次 prompt 的真实 budget 使用率，先把旧 tool result 从 hot 降到 warm/cold，仍超预算才增量摘要。summary 水位是幂等键；最近用户/assistant 回合与原始用户文字保持诚实边界。被 supersede 的消息不得重新流入摘要。

## Entity Stream

`entitystream` 是 entities SSE 的生产 helper：open/delta/close 或 signal，scope 锚定实体。Function/Handler/Agent/Workflow/MCP 等实时执行与 build 镜像共用它；没有 Bridge 时业务仍正常落 durable 真相。
