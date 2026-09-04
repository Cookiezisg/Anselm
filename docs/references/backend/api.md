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
- JSON request body 必须恰好包含一个完整 JSON 值；未知字段、尾随第二个 JSON 值或非空垃圾均返回
  `400 INVALID_REQUEST`。允许空 body 的 `:action` 端点仍把 EOF 解释为零值载荷，但一旦有 body 也遵守同一单值规则。
- 无界集合使用 keyset `cursor` + `limit`，返回顶层 `nextCursor`、`hasMore`。
- 八类实体 rail 列表（functions/handlers/agents/workflows/triggers/controls/approvals/conversations）另外在
  `X-Anselm-Total-Count` 响应头携带同 workspace、同 `search` 过滤下的精确总数；这是传输元数据，
  对 conversations 还包含 archived/pinned/workDir 过滤；它不改变 N4 JSON body，也不把游标分页伪装成 offset 分页。
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
| `GET /functions` | 分页；`search` 按 name 子串；响应头带精确过滤总数 |
| `GET /functions/{id}` | 单读，含 activeVersion |
| `PATCH /functions/{id}` | 更新 metadata，不铸版本 |
| `DELETE /functions/{id}` | 软删主行并回收 sandbox；不可变版本历史保留供审计，主实体与动作随后按 not-found 处理 |
| `POST /functions/{id}:run` | `{args,version?}`，manual run |
| `POST /functions/{id}:edit` | ops；空 ops 重建 active env |
| `POST /functions/{id}:revert` | 移 active pointer |
| `POST /functions/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /functions/{id}/versions` | 版本分页 |
| `GET /functions/{id}/versions/{version}` | 按号或 ID 单读版本；opaque version ID 必须属于路径中的 function |
| `GET /functions/{id}/executions` | Execution 分页与 aggregates（`totalCount`、`okCount`、`failedCount`） |
| `GET /function-executions/{id}` | 单条 Execution，含 logs |

### Handler

| Method · Path | 语义 |
|---|---|
| `POST /handlers` | 创建 v1，不立即 spawn |
| `GET /handlers` | 分页；`search` 按 name 子串；响应头带精确过滤总数；列表行附 `runtimeState`，与懒启动后的实例真相同步 |
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
| `DELETE /handlers/{id}/config` | 清 config 并停实例；幂等返回 204，已为空时不重复发 `handler.config_cleared` |
| `GET /handlers/{id}/calls` | Call 分页与 aggregates（`totalCount`、`okCount`、`failedCount`）；空页的 `data.calls` 固定为 `[]`（不为 `null`） |
| `GET /handler-calls/{id}` | 单条 Call，含 logs；Handler Logs 展开时懒取详情 |

### Agent

| Method · Path | 语义 |
|---|---|
| `POST /agents` | identity + Config snapshot 创建 v1 |
| `GET /agents` | 分页；`search` 按 name 子串；响应头带精确过滤总数 |
| `GET /agents/{id}` | 含 activeVersion |
| `PATCH /agents/{id}` | 更新 `name`、`description`、`tags` metadata；未提供的字段保持不变，不铸新版本、不改变 active pointer |
| `DELETE /agents/{id}` | 删除 |
| `POST /agents/{id}:invoke` | `{input,version?}`，manual invoke |
| `POST /agents/{id}:edit` | 全量 Config snapshot 替换 |
| `POST /agents/{id}:revert` | 移 active pointer |
| `POST /agents/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /agents/{id}/versions[/{version}]` | 版本分页/单读；父 Agent 不存在时返回 `404 AGENT_NOT_FOUND`，不伪装成空历史；opaque version ID 必须属于路径中的 Agent，否则 `404 AGENT_VERSION_NOT_FOUND` |
| `GET /agents/{id}/mount-health` | 全部 tool/knowledge 挂载健康；`data.mounts[]` 为 `{ref,name?,healthy,error?}`，健康 knowledge 挂载提供文档标题 `name`，缺失挂载诚实回退 `ref` 并带 `error` |
| `GET /agents/{id}/executions` | Execution 轻量分页与 aggregates（`totalCount`、`okCount`、`failedCount`；列表不带 transcript；`nextCursor` 原样续传）；父 Agent 不存在返回 `404 AGENT_NOT_FOUND`，不伪装成空历史 |
| `GET /agent-executions/{id}` | 单条 Execution，含 transcript |

所有实体的 `:iterate` 端点都接受 `{request}`。请求必须包含至少一个非空白字符；否则返回
`400 EMPTY_ITERATE_REQUEST`，不会创建 Conversation。

`:iterate` 创建的是**编辑工作对话**，不是直接 mutation：实体的当前定义以 @-mention 快照种入首条消息，
并把目标 type/id 作为不可变 target lock 注入 system prompt。模型必须逐字符复用该 opaque id；首轮若
`request` 只是“帮我用 AI 编辑”而没有具体修改，不得调用 `edit_*`，应先展示当前定义并追问修改意图。
真正的 edit 只在用户给出具体变更后执行，并仍遵守对应 `edit_*` 的完整替换/立即生效语义。
对 versioned full-replacement entity，首个 edit 调用必须复制当前定义的全部 required fields，不能只发送
用户改变的字段；Approval 特别要求 `approvalId`、`inputs`、`template`、`allowReason`、`timeout`、
`timeoutBehavior` 和非空 `changeReason`。后端仍严格拒绝 delta，不把 retry 成功当作首调用通过。

## 4. Workflow execution

### Workflow

| Method · Path | 语义 |
|---|---|
| `POST /workflows` · `GET /workflows` | 创建 / 分页；列表响应头带精确过滤总数 |
| `GET /workflows/{id}` · `PATCH /workflows/{id}` · `DELETE /workflows/{id}` | 单读 / metadata / 删除 |
| `POST /workflows/{id}:edit` · `:revert` | Graph ops / 移 pointer |
| `POST /workflows/{id}:capability-check` | 返回阻断 problems 与 advisory warnings |
| `POST /workflows/{id}:trigger` | 显式 run-now，body 可带 `entryNode`（多 trigger 图选择入口）与 `payload`，返 flowrun ID；多入口未选择时返回 `FLOWRUN_INVALID_ENTRY` |
| `POST /workflows/{id}:stage` | 一次性待命；成功返回 workflow 实体快照（含名称与生命周期） |
| `POST /workflows/{id}:activate` · `:deactivate` · `:kill` | 上线 / 排空下线 / 硬停；均返回动作后的 workflow 实体快照 |
| `POST /workflows/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /workflows/{id}/versions[/{version}]` | 版本分页/单读；数字版本号与 opaque 版本 ID 均必须属于路径中的 workflow `{id}`，跨父或未知版本统一 `WORKFLOW_VERSION_NOT_FOUND` |

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
| `POST /triggers` · `GET /triggers` | 创建 / 分页；支持 `?search=` 大小写不敏感的 name 子串过滤，列表响应头带同过滤条件的精确总数 |
| `GET /triggers/{id}` · `PATCH /triggers/{id}` · `DELETE /triggers/{id}` | 单读（含同列表派生字段）/ 热编辑 / 删除；`nextFireAt` 仅在可解析 cron 正在监听且未暂停时出现 |
| `POST /triggers/{id}:fire` | 手动 fan-out |
| `POST /triggers/{id}:pause` · `:resume` | 持久暂停 / 恢复 |
| `POST /triggers/{id}:iterate` | 打开 AI 构建 Conversation |
| `GET /triggers/{id}/activations` | Activation 分页；每行 `firingCount` 是该次 activation 的 workflow 扇出数，不是历史累计 fire 次数 |
| `GET /trigger-activations/{id}` | 单 Activation |
| `GET /firings` · `GET /triggers/{id}/firings` | workspace / trigger Firing 分页；每行保留精确 `workflowId`，并在 workflow 仍可读时读时补 `workflowName`；工具侧必须传精确 opaque triggerId（不是 name/pattern），`limit` 为整数，托管模型可用精确十进制字符串，错误形状拒绝 |
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

`GET /controls` 与 `GET /approvals` 均支持 `?search=` 的大小写不敏感 name 子串过滤；列表响应在
`X-Anselm-Total-Count` 携带同一过滤条件下的精确总数，分页 JSON body 仍遵守 N4。

六类带版本实体的单读（function/handler/agent/workflow/control/approval）必须把主行的
`activeVersionId` hydrate 成同一响应内的 `activeVersion`；active 指针为空返回对应的
`*_NO_ACTIVE_VERSION`，指向不存在版本返回对应的 `*_VERSION_NOT_FOUND`。数据损坏不得被
伪装成 `200` 且省略版本的“空详情”。

版本列表先解析路径中的父 Control/Approval；父实体不存在返回对应的 `*_NOT_FOUND`，不伪装成
`200` 空历史。父实体存在但历史为空时才返回空分页；父实体已软删时，普通实体读仍为 not-found，但其
immutable version history 仍可通过版本列表/单读端点审计。版本单读支持数字版本号或 opaque version ID；两种
形态都必须属于路径中的父实体，跨父或未知 opaque ID 返回对应的 `*_VERSION_NOT_FOUND`。

`PATCH /controls/{id}` 与 `PATCH /approvals/{id}` 只更新实际变化的 metadata 字段，且不铸造新版本。
空 patch 或所有提供的字段都已等值时仍返回 `200` 当前实体，但不写盘、不刷新 `updatedAt`、也不发
`*.updated` 生命周期通知；这保证重试或表单保存的 no-op 不伪造一次修改。

Control 的 HTTP `:edit` 端点若提供 `inputs`，必须是 field object JSON array；省略该字段不应抹掉当前
active version 的声明。仅 AI 工具边界另外兼容托管模型发出的完整 JSON 数组字符串，并在进入 domain
前解码为同一原生形状；该兼容不改变 HTTP/domain 契约，也不接受坏字符串、对象或其他非数组值。

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

`context=fork` 的 `agent` 必须是 runner 注册的区分大小写类型：`Explore`、`Plan` 或
`general-purpose`。未知值在创建/替换时返回 `422 SKILL_FORK_AGENT_TYPE_INVALID`；历史或安装文件
在激活时仍 fail-closed，详情见 Skill domain reference。

### MCP

| Method · Path | 语义 |
|---|---|
| `GET /mcp-servers` | Server 状态列表；`lastError` 是最近一次失败的历史诊断，当前 `status=ready` 不代表仍有活动故障 |
| `GET|PUT|DELETE /mcp-servers/{name}` | 单读 / upsert / 删除 |
| `POST /mcp-servers/{name}:reconnect` | 重连 |
| `GET /mcp-servers/{name}/stderr` | 有界 stderr tail |
| `GET /mcp-servers/{name}/calls` | Call 分页；`data` 内含 `calls` 与 `aggregates:{totalCount,okCount,failedCount}`，列表行省略 logs |
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
| `GET /documents` · `GET /documents/tree` | `GET /documents` 是 `?parentId&cursor&limit` 的直接子节点 cursor 分页（默认 50、最大 200，响应 `data/nextCursor?/hasMore`）；游标绑定铸造它的 `parentId`，跨父节点复用返回 `INVALID_REQUEST`；`tree` 是整树 metadata 投影 |
| `POST /documents` | 创建 |
| `GET|PATCH|DELETE /documents/{id}` | 单读 / 部分更新 / 删除；PATCH 只持久化实际变化，空或等值 patch 返回当前实体但不刷新 `updatedAt`、重建索引或发送 `document.updated` |
| `POST /documents/{id}:iterate` | 打开 AI 编辑 Conversation |
| `POST /documents/{id}:move` | `{parentId?: string|null, position?: non-negative integer}`；省略 `parentId` 移到根，省略 `position` 追加；显式位置必须在目标同级插入下标 `0..N`，否则 `DOCUMENT_INVALID_POSITION`；目标父级与解析后位置均未变化时成功 no-op，不刷新 `updatedAt`/不发 `document.moved`；自落/成环为 `DOCUMENT_INVALID_PARENT` |
| `POST /documents/{id}:duplicate` | 深拷整棵子树，返回 `201` 的新根实体；空 body 或 `{parentId:null}` 将副本放在源的同级并自动给根名加 ` 2`/` 3` 后缀，显式 `parentId` 放到指定父级；每个节点铸新 ID、重映射 `parentId/path`，正文/描述/标签/wikilink 出边复制；逐节点写入，非跨子树原子 |

### Conversation / Chat

| Method · Path | 语义 |
|---|---|
| `POST /conversations` · `GET /conversations` | 创建 / 分页；GET 默认只列 active、按 pinned-first + 最近活跃倒序，支持 `search`、`archived=true|1|archived|all`、`sort=activity|created|name`、`pinned=true|1|false|0`；`workDir` 按键 presence 区分缺席=不过滤、空值=仅未挂、非空=精确驻地。响应头 `X-Anselm-Total-Count` 是当前完整过滤轴的精确总数，供 rail 段头使用；游标是服务端 opaque keyset，内部携带当前 pinned 分区和完整查询 scope，置顶线程跨页也不会漏未置顶线程；复用到另一查询轴返回 `MALFORMED_CURSOR`，客户端仍必须在切轴时丢弃旧 cursor。 |
| `GET|PATCH|DELETE /conversations/{id}` | 单读 / 配置更新 / 删除；PATCH 是部分更新：`modelOverride` 缺键=不变、对象=设置、显式 `null`=清除，`workDir` 空字符串=卸载；空 patch 或所有字段都已等值时返回当前实体，但不写盘、不刷新 `updatedAt`、不发 `conversation.*` 生命周期通知 |
| `POST /conversations/{id}/messages` | Send |
| `GET /conversations/{id}/messages` | older/newer keyset 或 `around` 窗 |
| `POST /conversations/{id}:cancel` | 取消 running/queued turns |
| `POST /conversations/{id}:seen` | 清 unread |
| `POST /conversations/{id}:fork` | 复制 durable prefix 创建 thread |
| `POST /conversations/{id}:retry` | regenerate 或 edit-resend |
| `GET /conversations/{id}/anchors` | Scene anchors 分页 |
| `GET /conversations/{id}/usage` | token 汇总 |
| `GET /conversations/{id}/system-prompt-preview` | 真实 prompt builder 预览 |
| `GET /conversations/{id}/interactions` | 当前待决 HumanLoop 重连快照（broker 内存表；先校验会话归属，未知/跨 workspace → `404 CONVERSATION_NOT_FOUND`） |
| `POST /conversations/{id}/interactions/{toolCallId}` | 先在当前 workspace 校验会话归属，再决议该会话的 HumanLoop（`action`/`answer?`，204；跨 workspace/未知会话 → `404 CONVERSATION_NOT_FOUND`；tool id 不属于该会话或已决议 → `404 NO_PENDING_INTERACTION`） |
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
| `GET /speech/asr` | ASR streaming transport；客户端发送 16kHz、mono、PCM16 binary frame 与 `commit`/`finish`/`cancel` 控制帧，服务端返回 Qwen realtime 事件；部署网关的实时增量是 `conversation.item.input_audio_transcription.text`（`stash` 为累计快照），最终文本是 `.completed` 的 `transcript`。上游在 WebSocket 升级期间拒绝时，服务端先完成本地升级，再发送 `{"type":"error","code":"SPEECH_QUOTA_EXHAUSTED|SPEECH_RATE_LIMITED|SPEECH_ACCOUNT_BANNED|SPEECH_UNAVAILABLE"}` 并关闭；上游在已升级会话中途断线时发送 `{"type":"error","code":"SPEECH_UPSTREAM_CLOSED"}` 后收口；客户端空帧或超过 256 KiB 的音频帧收到 `SPEECH_AUDIO_FRAME_INVALID`，未知控制帧收到 `SPEECH_CONTROL_INVALID`，两者均不转发上游并关闭；只允许闭集 code，不转发上游 message。非 WebSocket 请求仍返回 N1 HTTP 错误信封。 |
| `GET /read-aloud/availability` | 当前朗读可用性 |
| `POST /read-aloud:read` | 文本朗读 |
| `GET /voices` | 可用 voice 列表 |
| `DELETE /voices/{id}` | 先删除受管网关登记、成功后删除本地 voice 指针；provider 明确报告该 `delete_voice` 目标已不存在时按幂等成功收敛；其他上游失败保留本地行并返回可重试错误 |

### Memory

| Method · Path | 语义 |
|---|---|
| `GET /memories` · `GET /memories/{name}` | 列表 / 单读 |
| `PUT /memories/{name}` · `DELETE /memories/{name}` | upsert / 删除 |
| `POST /memories/{name}/pin` · `/unpin` | pin 状态 |

Memory 以 markdown 文件保存。`description` 是 frontmatter 的用户文本，持久化层对含换行
的值使用可逆转义，避免内容被解释成 `pinned`/`source` 元数据；PUT 返回值与随后 GET
回读的策展字段必须一致。

## 8. Discovery, search and relations

| Method · Path | 语义 |
|---|---|
| `GET /catalog` | Entity/capability 概览 |
| `GET /tools` | 可授权内建工具目录；不含逐请求 capability tools |
| `GET /search` | 统一搜索；`q` 必填，`types`/`tags` 为 CSV；`updatedAfter`/`updatedBefore` 是包含端点的 RFC3339 时间窗；`includeArchived` 默认 `true`（只接受 `true`/`false`，大小写不敏感）；keyset 分页（默认 20、上限 50） |
| `POST /search:reindex` | 异步 force reconcile，就地覆盖并清孤儿；无可轮询产物，204 |
| `GET /search/settings` · `PATCH /search/settings` | 机器级搜索设置；PATCH 支持部分字段，空 Ollama 参数重置默认值，多字段原子提交 |
| `GET /relations` | 边分页 |
| `GET /relations/neighborhood` | 邻域有界投影；`kind`/`id` 必填，`depth` 缺席默认 2，出现时须为单个十进制整数；语法错误 `400 INVALID_REQUEST`，范围外 `400 REL_DEPTH_LIMIT` |
| `GET /relgraph` | 关系图投影 |
| `POST /executions/{id}:triage` | 为执行记录打开诊断 Conversation；body 可省略，或传可选 `{note}` 作为诊断关注点 |

## 9. Workspace, models and managed service

### Workspace

| Method · Path | 语义 |
|---|---|
| `GET /workspaces` · `POST /workspaces` | 列表 / 创建；GET 返回机器级有界全量名册，不分页，按 `createdAt` 升序、同值按 `id` 升序稳定排序 |
| `GET|PATCH|DELETE /workspaces/{id}` | 单读 / 更新 / 删除 |
| `GET /workspaces/{id}/stats` | workspace 统计 |
| `POST /workspaces/{id}:activate` | 更新最近使用并返回实体 |
| `PUT|DELETE /workspaces/{id}/default-models/{scenario}` | 设置/清除六个 scenario（`dialogue`、`utility`、`agent`、`image`、`speech`、`video`）的 ModelRef；校验与写入均以 path `{id}` 为 owner，不以可能不同的 workspace header 为准；已知 `tools=false` 模型对 `agent` 场景在写入时返 `MODEL_NOT_AGENT_CAPABLE`，对 `dialogue` 仍合法 |
| `PUT|DELETE /workspaces/{id}/default-search` | 设置/清除 WebSearch key；设置时 key 必须存在于 path `{id}` 所属 workspace，不能使用 header 指向的其他 workspace 或不存在的 key |

### API key and model catalog

| Method · Path | 语义 |
|---|---|
| `POST /api-keys` · `GET /api-keys` | 创建 / 列表 |
| `PATCH|DELETE /api-keys/{id}` | 更新 / 删除；引用中 key 拒删 |
| `POST /api-keys/{id}:test` | probe |
| `GET /providers` | Provider metadata |
| `GET /model-capabilities` | Model catalog/capabilities |
| `GET /scenarios` | Six fixed scenario slots in canonical order: `dialogue`, `utility`, `agent`, `image`, `speech`, `video` |

启动时使用仓内 vendored catalog；后台刷新在 boot 后约 30 秒开始，随后按日检查，运行时缓存优先于
vendored 快照。刷新失败只记录 warning 并保留上一份可用目录，绝不把模型选择器或能力描述降成空目录。
`ANSELM_RIG_MODEL_CATALOG_URL` 仅供 acceptance rig 将这条后台 fetch 指向受控故障端点，生产环境不得设置。

`DELETE /api-keys/{id}` 保留不可恢复的删除主行身份用于审计，但在同一条数据库更新中清空加密 secret、掩码、连接配置和 probe 回执；普通读随后返回 `API_KEY_NOT_FOUND`，不存在 restore 操作。

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
| `GET /sandbox/disk-usage` | machine-wide sandbox manifest projection |
| `GET /sandbox/bootstrap-status` | bootstrap 状态；成功返回 `{ok:true}`，degraded 返回 `200 {ok:false,error:"sandbox bootstrap failed"}`，内部路径与实现细节只写 backend journal |
| `POST /sandbox:gc?olderThanDays=N` | 按 `lastUsedAt` 回收空闲 env；缺省/负数/非法值为 30 天，显式 `0` 立即回收所有当前未运行的 env；返回 `{removed,olderThanDays}`，不删除 runtime manifest |
| `POST /sandbox:retry-bootstrap` | 重试 bootstrap；成功或 degraded 都以 `200 {ok}` 带内返回 |
| `GET /conversations/{id}/sandbox-envs` | Conversation scratch envs；先按当前 workspace 校验 conversation，跨 workspace/不存在均为 `404 CONVERSATION_NOT_FOUND` |
| `POST /conversations/{id}/sandbox-envs/{kind}:reset` | 重置一种 scratch env；先按当前 workspace 校验 conversation |
| `POST /conversations/{id}/sandbox-envs:reset-all` | 重置全部 scratch env；先按当前 workspace 校验 conversation |

Env manifest 的 `deps` 是集合字段，线上始终编码为 JSON 数组；没有依赖时为 `[]`，不返回 `null`。
`ownerName` 是设置页使用的可读所属实体名：Function/Handler 的复合 owner id 在读时按当前
workspace hydrate，兼容历史上没有持久名称的 env 行和实体改名；若所属实体已不存在则保留空值，
调用方回退到 `ownerId`。`GET /sandbox/envs/{id}` 与列表共用同一份完整 manifest，机器级资源不按
workspace 过滤。`DELETE /sandbox/envs/{id}` 成功返回 `204`，同时移除 manifest 行和对应本机目录；
运行中的 env（`runningPid > 0`）返回 `409 SANDBOX_ENV_IN_USE`，调用方必须先停止所属实体，
服务端不会静默杀掉常驻进程。未知 id 返回 `404 SANDBOX_ENV_NOT_FOUND`。

`POST /sandbox:gc` 只回收满足闲置阈值且没有运行 PID 的 env 行及其派生目录；运行中的 env 会被跳过并写入
backend journal，单个失败不会阻断其余 env。被回收的 Function/Handler 环境在下一次执行时懒重建；runtime
manifest 与 runtime 目录不是该动作的删除目标，仍需通过 `DELETE /sandbox/runtimes/{id}` 且无 env 引用时才可移除。

`GET /sandbox/disk-usage` 返回 `{"totalBytes": int64}`，其中 `totalBytes` 是机器级
runtime 与 env manifest 的 `sizeBytes` 之和；它不按 workspace 过滤，也不是每次请求重新扫描文件系统。
没有 runtime/env 时返回 `0`，这是合法成功值。

## 11. Notifications and runtime settings

### Notifications

| Method · Path | 语义 |
|---|---|
| `GET /notifications` | newest-first 分页 |
| `GET /notifications/unread-count` | badge count；其他方法返回 `405 METHOD_NOT_ALLOWED`（`Allow: GET, HEAD`） |
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
