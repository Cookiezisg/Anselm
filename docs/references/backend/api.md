---
id: DOC-008
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# HTTP API

本文登记 `/api/v1` 的公开 method、path 与关键 wire 语义。路由代码是物理事实，
`make -C docs verify` 检查路由资源词覆盖。

## 1. 通则

- 成功：`{"data": ...}`；错误：
  `{"error":{"code","message","details"}}`。
- Wire 字段使用 camelCase；Path variable 也使用 camelCase。
- 无界集合使用 keyset `cursor` + `limit`，返回顶层 `nextCursor`、`hasMore`。
- 明确有界批查、静态枚举和单对象派生投影不使用 cursor。
- Create/单读/Patch 的 `data` 是实体；复合响应使用具名 keys。
- 创建新资源的异步动作返回 `202 {"data":{"id":"..."}}`。
- 同步 `:run`、`:call`、`:invoke` 的 `data` 直接是结果，不增加同义外壳。
- 状态变更动作返回动作后的实体/运行快照；无返回值的 mutation 与 DELETE
  返回 `204 No Content`。
- 非 CRUD 动作使用 `:action`。

详细字段、封闭词表与错误码分别以域 reference、[`database.md`](database.md)
和 [`error-codes.md`](error-codes.md) 为准。

## 2. Streams

| Method · Path | 语义 |
|---|---|
| `GET /messages/stream` | Conversation message/block 流 |
| `GET /entities/stream` | Entity build/run/status 流 |
| `GET /notifications/stream` | Notification durable/ephemeral 流 |

三条都是 workspace 常驻 SSE，frame 契约见 [`events.md`](events.md)。

## 3. Callable entities

### Function

| Method · Path | 语义 |
|---|---|
| `POST /functions` | 创建 v1，201 |
| `GET /functions` | 分页；`search` 按 name 子串 |
| `GET /functions/{id}` | 单读，含 activeVersion |
| `PATCH /functions/{id}` | 更新 metadata，不铸版本 |
| `DELETE /functions/{id}` | 软删主行并回收 sandbox；不可变版本历史保留供审计，主实体与动作随后按 not-found 处理 |
| `POST /functions/{id}:run` | `{args,version?}`，manual run |
| `POST /functions/{id}:edit` | ops；空 ops 重建 active env |
| `POST /functions/{id}:revert` | 移 active pointer |
| `POST /functions/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /functions/{id}/versions` | 版本分页 |
| `GET /functions/{id}/versions/{version}` | 按号或 ID 单读版本 |
| `GET /functions/{id}/executions` | Execution 分页与 aggregates |
| `GET /function-executions/{id}` | 单条 Execution，含 logs |

### Handler

| Method · Path | 语义 |
|---|---|
| `POST /handlers` | 创建 v1，不立即 spawn |
| `GET /handlers` | 分页；`search` 按 name 子串 |
| `GET /handlers/{id}` | 含 activeVersion、config/runtime state |
| `PATCH /handlers/{id}` | metadata；不重启 |
| `DELETE /handlers/{id}` | 停实例并软删主行；不可变版本历史保留供审计，环境尽力回收，relation 边清理，主实体与动作随后按 not-found 处理 |
| `POST /handlers/{id}:call` | `{method,args}`，manual call |
| `POST /handlers/{id}:restart` | 重启常驻实例 |
| `POST /handlers/{id}:edit` | ops；代码/schema 变化后重启 |
| `POST /handlers/{id}:revert` | 移 pointer 并重启 |
| `POST /handlers/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /handlers/{id}/versions[/{version}]` | 版本分页/单读 |
| `GET /handlers/{id}/config` | masked config |
| `PUT /handlers/{id}/config` | JSON Merge Patch 并重启 |
| `DELETE /handlers/{id}/config` | 清 config 并停实例 |
| `GET /handlers/{id}/calls` | Call 分页与 aggregates |
| `GET /handler-calls/{id}` | 单条 Call，含 logs |

### Agent

| Method · Path | 语义 |
|---|---|
| `POST /agents` | identity + Config snapshot 创建 v1 |
| `GET /agents` | 分页；`search` 按 name 子串 |
| `GET /agents/{id}` | 含 activeVersion |
| `PATCH /agents/{id}` | metadata |
| `DELETE /agents/{id}` | 删除 |
| `POST /agents/{id}:invoke` | `{input,version?}`，manual invoke |
| `POST /agents/{id}:edit` | 全量 Config snapshot 替换 |
| `POST /agents/{id}:revert` | 移 active pointer |
| `POST /agents/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /agents/{id}/versions[/{version}]` | 版本分页/单读 |
| `GET /agents/{id}/mount-health` | 全部 tool/knowledge 挂载健康 |
| `GET /agents/{id}/executions` | Execution 轻量分页与 aggregates（列表不带 transcript；`nextCursor` 原样续传） |
| `GET /agent-executions/{id}` | 单条 Execution，含 transcript |

## 4. Workflow execution

### Workflow

| Method · Path | 语义 |
|---|---|
| `POST /workflows` · `GET /workflows` | 创建 / 分页 |
| `GET /workflows/{id}` · `PATCH /workflows/{id}` · `DELETE /workflows/{id}` | 单读 / metadata / 删除 |
| `POST /workflows/{id}:edit` · `:revert` | Graph ops / 移 pointer |
| `POST /workflows/{id}:capability-check` | 返回阻断 problems 与 advisory warnings |
| `POST /workflows/{id}:trigger` | 显式 run-now，返 flowrun ID |
| `POST /workflows/{id}:stage` | 一次性待命；成功返回 workflow 实体快照（含名称与生命周期） |
| `POST /workflows/{id}:activate` · `:deactivate` · `:kill` | 上线 / 排空下线 / 硬停；均返回动作后的 workflow 实体快照 |
| `POST /workflows/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /workflows/{id}/versions[/{version}]` | 版本分页/单读 |

### Flowrun

| Method · Path | 语义 |
|---|---|
| `GET /flowruns` | 过滤列表；keyset 或 offset 二选一 |
| `POST /flowruns` | `{workflowId,entryNode?,payload?}` 手动起 run |
| `GET /flowruns/{id}` | run + newest-first 节点首页；节点可翻页 |
| `GET /flowruns/{id}/activity` | Function/Handler/Agent/MCP 执行活动分页 |
| `POST /flowruns/{id}:replay` | 仅 failed run 从断点重放，202 |
| `POST /flowruns/{id}:cancel` | 仅 running，first-wins，202 |
| `POST /flowruns/{id}/approvals/{node}:decide` | `{decision,reason?}`，202 |
| `GET /flowrun-inbox` | parked approval inbox |
| `GET /flowrun-stats` | 有界 workflow 批查 + workspace totals |
| `GET /flowrun-matrix` | 有界 flowrun IDs 稀疏格阵 |

List filters：`workflowId`、`triggerId`、`status`、`origin` 与 started/completed
RFC3339 半开窗口。Cursor/offset 同时出现或非法 filter 大声失败。

Stats 的 `workflowIds` 去重后最多 50，时间窗为 `[since,until)`；
`totals.missed` 来自 Firing。Matrix 的 `flowrunIds` 必填且去重后最多 50；
unknown IDs 缺席，cells 按 `(flowrun,node)` 聚合 iterations。

### Trigger

| Method · Path | 语义 |
|---|---|
| `POST /triggers` · `GET /triggers` | 创建 / 分页 |
| `GET /triggers/{id}` · `PATCH /triggers/{id}` · `DELETE /triggers/{id}` | 单读 / 热编辑 / 删除 |
| `POST /triggers/{id}:fire` | 手动 fan-out |
| `POST /triggers/{id}:pause` · `:resume` | 持久暂停 / 恢复 |
| `POST /triggers/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /triggers/{id}/activations` | Activation 分页 |
| `GET /trigger-activations/{id}` | 单 Activation |
| `GET /firings` · `GET /triggers/{id}/firings` | workspace / trigger Firing 分页 |
| `GET /trigger-schedule` | 有界 schedule window，截断时 `truncated=true` |
| `ANY /webhooks/{triggerId}/{path...}` | webhook source 入口（catch-all 前缀挂载一次、registry 派发；可选 secret/HMAC、10MB body 上限；bearer 豁免）；成功 `202` 表示 Activation/Firing 已耐久写入，scheduler 排空异步——完整形状见 [`domains/trigger.md`](domains/trigger.md) |

## 5. Graph authoring entities

### Control / Approval

两类均提供：

```text
POST /controls|approvals
GET /controls|approvals
GET|PATCH|DELETE /controls|approvals/{id}
POST /controls|approvals/{id}:edit
POST /controls|approvals/{id}:revert
POST /controls|approvals/{id}:iterate
GET /controls|approvals/{id}/versions[/{version}]
```

`DELETE /approvals/{id}` 与 `delete_approval` 均为软删除：普通实体读/搜索返回 not-found、关系边
被清理，但 `approval_form_versions` 作为不可变审计历史保留；工具调用必须先查关系并经
`danger="dangerous"` 的人闸批准。

### Skill

| Method · Path | 语义 |
|---|---|
| `GET /skills` · `POST /skills` | 列表 / 创建 |
| `GET /skills/{name}` · `PUT /skills/{name}` · `DELETE /skills/{name}` | 单读 / replace / 删除 |
| `POST /skills/{name}:activate` | 激活到 Conversation |
| `POST /skills/{name}:update` | 更新已安装 Skill |
| `POST /skills/{name}:approve-tools` | 更新授权工具 |
| `POST /skills:inspect-source` | 检查安装源 |
| `POST /skills:install` | 安装 |
| `GET /skills/{name}/files` | 文件树 |
| `GET|PUT|DELETE /skills/{name}/files/{path...}` | Skill 文件单读/写/删 |

### MCP

| Method · Path | 语义 |
|---|---|
| `GET /mcp-servers` | Server 状态列表 |
| `GET|PUT|DELETE /mcp-servers/{name}` | 单读 / upsert / 删除 |
| `POST /mcp-servers/{name}:reconnect` | 重连 |
| `GET /mcp-servers/{name}/stderr` | 有界 stderr tail |
| `GET /mcp-servers/{name}/calls` | Call 分页 |
| `POST /mcp-servers/{name}/tools/{tool}:invoke` | manual smoke call |
| `POST /mcp-servers:import` | 导入配置；可选择覆盖 |
| `GET /mcp-calls/{id}` | 单 Call |
| `GET /mcp-registry` | Registry 列表 |
| `POST /mcp-registry:install` | 安装 registry item |
| `POST /mcp-registry:plan` | 无副作用预检 |

## 6. Knowledge and conversations

### Document

| Method · Path | 语义 |
|---|---|
| `GET /documents` · `GET /documents/tree` | 分页列表 / 树投影 |
| `POST /documents` | 创建 |
| `GET|PATCH|DELETE /documents/{id}` | 单读 / 更新 / 删除 |
| `POST /documents/{id}:iterate` | 打开 AI 编辑 Conversation |
| `POST /documents/{id}:move` | 移动 |
| `POST /documents/{id}:duplicate` | 复制 |

### Conversation / Chat

| Method · Path | 语义 |
|---|---|
| `POST /conversations` · `GET /conversations` | 创建 / 分页 |
| `GET|PATCH|DELETE /conversations/{id}` | 单读 / 配置更新 / 删除 |
| `POST /conversations/{id}/messages` | Send |
| `GET /conversations/{id}/messages` | older/newer keyset 或 `around` 窗 |
| `POST /conversations/{id}:cancel` | 取消 running/queued turns |
| `POST /conversations/{id}:seen` | 清 unread |
| `POST /conversations/{id}:fork` | 复制 durable prefix 创建 thread |
| `POST /conversations/{id}:retry` | regenerate 或 edit-resend |
| `GET /conversations/{id}/anchors` | Scene anchors 分页 |
| `GET /conversations/{id}/usage` | token 汇总 |
| `GET /conversations/{id}/system-prompt-preview` | 真实 prompt builder 预览 |
| `GET /conversations/{id}/interactions` | pending HumanLoop |
| `POST /conversations/{id}/interactions/{toolCallId}` | resolve interaction |
| `GET /conversations/{conversationId}/todos` | live Todo |
| `GET /conversations/{conversationId}/touchpoints` | Conversation touch ledger |

### Workdir

| Method · Path | 语义 |
|---|---|
| `GET /conversations/{id}/workdir` | 文件系统/git 活投影 |
| `GET /conversations/workdir-groups` | workspace 全量有界分组 |
| `POST /conversations:archive-workdir` | 批量归档未置顶 threads |
| `POST /conversations:delete-workdir` | 批量删除未置顶 threads |
| `POST /conversations/{id}/workdir:switch-branch` | 切已有本地 branch |
| `POST /conversations/{id}/workdir:create-branch` | 从 HEAD 建 branch |
| `POST /conversations/{id}/workdir:add-worktree` | 派生 sibling worktree 并迁移 residency |

## 7. Media and memory

### Attachment

| Method · Path | 语义 |
|---|---|
| `POST /attachments` | multipart upload |
| `GET /attachments/{id}` | metadata |
| `GET /attachments/{id}/content` | 受权原始内容 |
| `POST /attachments/{id}/playback-lease` | 创建短期播放 lease |
| `GET /attachment-playback/{token}` | lease 内容 |
| `POST /attachments/{id}/preparation/cancel` | 取消派生准备 |
| `POST /attachments/{id}/preparation/retry` | 重试派生准备 |
| `DELETE /attachments/{id}` | 删除 |

### Speech / Voice

| Method · Path | 语义 |
|---|---|
| `GET /speech/asr` | ASR streaming transport |
| `GET /read-aloud/availability` | 当前朗读可用性 |
| `POST /read-aloud:read` | 文本朗读 |
| `GET /voices` | 可用 voice 列表 |
| `DELETE /voices/{id}` | 删除用户 voice |

### Memory

| Method · Path | 语义 |
|---|---|
| `GET /memories` · `GET /memories/{name}` | 列表 / 单读 |
| `PUT /memories/{name}` · `DELETE /memories/{name}` | upsert / 删除 |
| `POST /memories/{name}/pin` · `/unpin` | pin 状态 |

## 8. Discovery, search and relations

| Method · Path | 语义 |
|---|---|
| `GET /catalog` | Entity/capability 概览 |
| `GET /tools` | 可授权内建工具目录；不含逐请求 capability tools |
| `GET /search` | 统一搜索；keyset 分页 |
| `POST /search:reindex` | 异步 force reconcile，就地覆盖并清孤儿；无可轮询产物，204 |
| `GET /search/settings` · `PATCH /search/settings` | 搜索设置 |
| `GET /relations` | 边分页 |
| `GET /relations/neighborhood` | 邻域有界投影 |
| `GET /relgraph` | 关系图投影 |
| `POST /executions/{id}:triage` | 为执行记录打开诊断 Conversation |

## 9. Workspace, models and managed service

### Workspace

| Method · Path | 语义 |
|---|---|
| `GET /workspaces` · `POST /workspaces` | 列表 / 创建 |
| `GET|PATCH|DELETE /workspaces/{id}` | 单读 / 更新 / 删除 |
| `GET /workspaces/{id}/stats` | workspace 统计 |
| `POST /workspaces/{id}:activate` | 更新最近使用并返回实体 |
| `PUT|DELETE /workspaces/{id}/default-models/{scenario}` | 设置/清除 scenario ModelRef |
| `PUT|DELETE /workspaces/{id}/default-search` | 设置/清除 WebSearch key |

### API key and model catalog

| Method · Path | 语义 |
|---|---|
| `POST /api-keys` · `GET /api-keys` | 创建 / 列表 |
| `PATCH|DELETE /api-keys/{id}` | 更新 / 删除；引用中 key 拒删 |
| `POST /api-keys/{id}:test` | probe |
| `GET /providers` | Provider metadata |
| `GET /model-capabilities` | Model catalog/capabilities |
| `GET /scenarios` | Scenario metadata |

### Managed free tier

| Method · Path | 语义 |
|---|---|
| `GET /freetier/quota` | 受管配额投影 |
| `POST /freetier:provision` | install/device-proof provision |

默认受管路径与部署责任边界见
[`managed-gateway.md`](managed-gateway.md)。

## 10. Sandbox

| Method · Path | 语义 |
|---|---|
| `GET /sandbox/runtimes` | 已安装 runtime |
| `GET /sandbox/runtimes/available` | 可安装 runtime |
| `POST /sandbox/runtimes` · `DELETE /sandbox/runtimes/{id}` | 安装 / 删除 |
| `GET /sandbox/envs` · `GET /sandbox/envs/{id}` | Env 列表 / 单读 |
| `DELETE /sandbox/envs/{id}` | 销毁 env |
| `GET /sandbox/disk-usage` | disk audit |
| `GET /sandbox/bootstrap-status` | bootstrap 状态 |
| `POST /sandbox:gc` | 回收派生 env/runtime 文件 |
| `POST /sandbox:retry-bootstrap` | 重试 bootstrap |
| `GET /conversations/{id}/sandbox-envs` | Conversation scratch envs |
| `POST /conversations/{id}/sandbox-envs/{kind}:reset` | 重置一种 scratch env |
| `POST /conversations/{id}/sandbox-envs:reset-all` | 重置全部 scratch env |

## 11. Notifications and runtime settings

### Notifications

| Method · Path | 语义 |
|---|---|
| `GET /notifications` | newest-first 分页 |
| `GET /notifications/unread-count` | badge count |
| `POST /notifications/{id}:mark-read` | 单条已读 |
| `POST /notifications:mark-all-read` | 可选 `[after,before)` 窗 |
| `POST /notifications:mark-all-unread` | 同窗语义 |

### Limits, network and retention

| Method · Path | 语义 |
|---|---|
| `GET /limits` · `GET /limits/schema` | 当前 limits / 可编辑 schema |
| `PATCH /limits` · `POST /limits:reset` | 热更新 / 重置 |
| `GET /network` · `PATCH /network` | 网络设置 |
| `GET /retention` · `PATCH /retention` | terminal Flowrun retention |

## 12. System and storage

| Method · Path | 语义 |
|---|---|
| `GET /health` | liveness；不要求 workspace header |
| `GET /version` | build/version metadata |
| `GET /system/data-dir` | 本地数据根投影 |
| `GET /storage-stat` | 数据库与派生存储统计 |
| `POST /storage:compact` | 执行 SQLite compact |
