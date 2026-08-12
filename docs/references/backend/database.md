---
id: DOC-009
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 数据库 —— 表与 ID 前缀

> 当前物理 schema 的登记。DDL 全文以各 `infra/store/<domain>` 的 `Schema`
> 和 `infra/search` 为准；`make -C docs verify` 双向检查代码中的表名与本文
> 表格。

## 1. 全局约束

- 业务实体表带 `workspace_id`、`created_at`、`updated_at` 和
  `deleted_at`；`pkg/orm` 根据 ctx 自动加 workspace 与软删除谓词。
- 全局表与明确的系统级 manifest 不带 `workspace_id`，见 §9。
- 版本表以 `UNIQUE(<entity>_id, version)` 保存不可变快照。
- name 唯一性通常使用 `WHERE deleted_at IS NULL` 的 partial unique index，
  使软删释放名称。
- execution/call/activation 等审计行没有 `deleted_at`，只带创建或执行时间。
- 日志溯源统一保存 conversation/message/tool call，以及
  flowrun/node/iteration；iteration 使 loop 的每轮审计可与节点真相对齐。
- 时间按 UTC 的规范文本格式写入；时间窗使用裸列比较，不对索引列包
  `julianday()`。

SQLite 增列使用幂等 `ALTER TABLE ADD COLUMN`。修改 `CHECK` 封闭集时使用
`db.MigrateRebuild`：读取现行 DDL，只在 marker 缺席时于单事务重建表和索引。
当前重建对象包括 `trigger_firings.status`、`flowrun_nodes.status` 与
`message_blocks.type`。

## 2. Quadrinity

### Function

| 表 | 关键列与约束 |
|---|---|
| `functions` | name、description、tags、active_version_id；软删；ws/name partial unique |
| `function_versions` | function_id、version、code、inputs/outputs、dependencies、python_version、env 镜像、change_reason、built_in_conversation_id |
| `function_executions` | version_id、status、triggered_by、input/output、error_message、logs、elapsed_ms、started/ended_at、统一溯源；执行日志 |

ID：`fn_`、`fnv_`、`fne_`；infra env：`fnenv_`。

### Handler

| 表 | 关键列与约束 |
|---|---|
| `handlers` | name、description、tags、active_version_id、config_encrypted；软删 |
| `handler_versions` | imports、init_body、shutdown_body、methods、init_args_schema、dependencies、python_version、env 镜像 |
| `handler_calls` | method、status、triggered_by、input/output、logs、instance_id、统一溯源；调用日志 |

ID：`hd_`、`hdv_`、`hcl_`；infra env：`hdenv_`；内存实例：`hdi_`。

### Agent

| 表 | 关键列与约束 |
|---|---|
| `agents` | name、description、tags、active_version_id；软删 |
| `agent_versions` | prompt、skill、knowledge、tools、inputs/outputs、model_override、change_reason、built_in_conversation_id |
| `agent_executions` | model_id、api_key_id、provider、status、triggered_by、input/output、transcript、统一溯源；执行日志 |

Agent execution 的 transcript 是该次运行的自包含记录，不写入
`message_blocks`。ID：`ag_`、`agv_`、`agx_`。

### Workflow、Control、Approval

| 表 | 关键列与约束 |
|---|---|
| `workflows` | active_version_id、active、lifecycle_state、concurrency、needs_attention、attention_reason、last_action_by；软删 |
| `workflow_versions` | workflow_id、version、graph；不可变 |
| `control_logics` | active_version_id 与 identity/meta；软删 |
| `control_logic_versions` | control_id、version、inputs、branches |
| `approval_forms` | active_version_id 与 identity/meta；软删 |
| `approval_form_versions` | approval_id、version、inputs、template、allow_reason、timeout、timeout_behavior |

Workflow concurrency 封闭集为
`serial|skip|buffer_one|replace|allow_all`；lifecycle 为
`active|draining|inactive`。ID：`wf_`/`wfv_`、`ctl_`/`ctlv_`、
`apf_`/`apfv_`。

## 3. Trigger 与 Durable Run

| 表 | 关键列与约束 |
|---|---|
| `triggers` | kind、config、outputs、paused、missed_checked_at；软删；ws/name partial unique |
| `trigger_activations` | trigger_id、kind、fired、return_value、payload、error、detail、firing_count；日志 |
| `trigger_firings` | trigger_id、workflow_id、activation_id、payload、dedup_key、status、flowrun_id；durable inbox |
| `flowruns` | workflow_id、version_id、pinned_refs、trigger_id、firing_id、origin、conversation_id、status、replay_count、error、started/completed_at |
| `flowrun_nodes` | flowrun_id、node_id、iteration、kind、ref、status、result、error、ready_at、started_at |

Trigger kind 为 `cron|webhook|fsnotify|sensor`。cron 的
`misfirePolicy` 存在 config 中；`missed_checked_at` 是单调推进的 misfire
水位，不修改用户可见的 `updated_at`。

`trigger_firings.status` 为
`pending|claimed|started|skipped|superseded|shed|missed`。
`idx_trf_dedup(workflow_id,trigger_id,dedup_key)` 保证同一刻度只入账一次；
workspace 时间、status、trigger 三类读各有对应索引。`missed` 行以原调度
刻度作为 `created_at`，不创建 flowrun；需要补跑时原行守卫式转回 pending。

`flowruns` 钉住 graph version 与引用闭包，状态为
`running|completed|failed|cancelled`。运行历史以 workspace、workflow、
status/completed_at 等索引支持当前 API 过滤；跨 workspace 的 running 偏
索引只服务 boot 恢复。

`flowrun_nodes.status` 为 `completed|failed|parked|cancelled`。
`idx_frn_once(flowrun_id,node_id,iteration)` 是 record-once 真相；
ready_at 是首次 ready，started_at 是引擎开始处理节点。

ID：`trg_`、`tra_`、`trf_`、`fr_`、`frn_`。

### D1 物理删除边界

durable 业务与日志真相只有两个物理删除例外：

1. `:replay` 通过 `DeleteFailedNodes` 删除 failed 节点。failed 是未产生
   可复用结果的尝试；completed 结果继续保留。
2. retention 通过 `PurgeTerminalRunsBefore` 删除 cutoff 之前的终态
   flowrun、节点和该 run 产生的 function/handler/agent/MCP 审计行。

Retention 只按非空 `completed_at` 删除
`completed|failed|cancelled`；`running` 与 parked obligation 永不删除。
删除按 workspace 分批并在删除事务内再次守卫终态，避免与 replay 竞态。Trigger
firing、notification 和 touchpoint 具有独立真相轴，不随 run 清理；其中的
flowrunId 允许成为可识别的悬挂引用。

Search 索引、媒体 derivative/perception、speech cache 等明确标为“可再生
派生数据”的表不属于 durable 业务真相；它们按自己的重建或淘汰规则硬删，
不增加 D1 例外。SQLite vacuum 只回收已空页面，也不构成逻辑删除。

## 4. Skill、MCP 与 Document

| 表 | 关键列与约束 |
|---|---|
| `mcp_servers` | transport、runtime、command/args、url、config_enc、timeout_sec、source、registry_id；软删 |
| `mcp_calls` | server_id、tool、status、triggered_by、input/output、logs、elapsed_ms、统一溯源；调用日志 |
| `documents` | parent_id、name、content、path、position、size_bytes、tags；软删 |

Skill 无表，目录
`workspaces/<workspace>/skills/<name>/SKILL.md` 是真相。Document position 在
同父节点内由事务分配；移动和复制可重排，因此不设 position unique。

ID：`mcp_`、`mcl_`、`doc_`；Skill 以 slug 为身份。

## 5. Conversation 与媒体

| 表 | 关键列与约束 |
|---|---|
| `conversations` | title、auto_titled、system_prompt、summary、水位、attached_documents、archived/pinned、model_override、last_message_at、unread、fork 血缘、work_dir；软删 |
| `messages` | conversation_id、subagent_id、role/status、stop/error、token/provider/model 溯源、attrs、superseded_by；append-only |
| `message_blocks` | message_id、parent_block_id、seq、type、attrs/content、status、context_role；append-only |
| `attachments` | sha256、filename、mime_type、kind、size_bytes、source、origin_conversation_id、origin_flowrun_id、origin_tool_call_id；软删 |
| `attachment_derivatives` | attachment/source/params identity、status、派生 blob 元数据与媒体维度；可再生 |
| `attachment_perceptions` | attachment/source/task/provider/model/params identity、status、capsule、token 与错误元数据；可再生 |
| `speech_cache` | cache_key、attachment_id、size_bytes、last_used_at；workspace 内 key 唯一；派生 LRU |
| `todos` | scope_id、conversation_id、subagent_id、items；按 scope 整体替换 |
| `conversation_touchpoints` | conversation/item/verb 聚合键、item_name、last_actor、count、first/last_at、last_message_id |
| `voices` | name、provider、upstream_id、source_attachment_id、created_at；workspace/name unique |

Conversation 有 active/title/created 三种列表排序索引，以及 work_dir 分组和
组内分页索引。fork 血缘只读；`work_dir` 保存规范化绝对路径，空串表示未挂，
路径存在性由读投影实时判断。

`messages.superseded_by` 是版本指针，不是软删除：旧回合仍从 REST 返回并可
寻址；LLM 装配、压缩和 anchor 只读取现行版本。反向指针存于新回合 attrs 的
`retryOf`。

`message_blocks.type` 为
`text|reasoning|tool_call|tool_result|compaction|progress|marker`。
marker 的 payload 存在 attrs；当前 workdir marker 为
`{kind:"workdir",from,to}`，content 为空以便客户端本地化。Marker 不进入
LLM 类型白名单。

Attachment blob 按 sha256 存在 workspace 文件树。`origin_tool_call_id`
限制 tool-result 展开为本次工具自己铸造的附件；agent payload 与用户附件
注入不使用该限制。Derivative 与 perception 使用 identity unique constraint
使并发准备收敛，原始任务只保存 hash，不保存上游原文。

Touchpoint 以
`(workspace,conversation,item_kind,item_id,verb)` 唯一聚合；删除 conversation
时硬删其派生台账，删除实体不清除历程。Voice 行是上游资源指针，删除顺序必须
先删除上游资源、再删除本地行。

ID：`cv_`、`msg_`、`blk_`、`att_`、`mdr_`、`mpr_`、`spc_`、`tp_`、
`vce_`。Memory 无表；Subagent 运行结果写入父 conversation 的 messages。

## 6. Search

| 表 | 关键列与约束 |
|---|---|
| `search_docs` | workspace_id、entity_type、entity_id、chunk_no、anchor、title、body、tags、archived；实体/chunk unique |
| `search_fts` | external-content FTS5，content=`search_docs`，trigram tokenizer；触发器同步 |
| `search_meta` | key/value：schema version 与机器级 embedder 设置 |
| `search_embeddings` | doc_id、model、dims、float32 vector blob；doc_id primary key |

Search 是派生索引，实体删除与 reindex 可物理删行。FTS raw SQL 明确携带
workspace 谓词；workspace 隔离由专项测试覆盖。ID：`sd_`。

## 7. 支撑域

| 表 | 关键列与约束 |
|---|---|
| `workspaces` | 全局 identity、语言、聊天/生成场景默认、默认搜索、web_fetch_mode |
| `api_keys` | provider/model 配置与加密 secret、probe 元数据；软删，删除时清空凭证与配置材料 |
| `model_runtime_profiles` | model identity、不可逆 endpoint/credential/config 指纹、overflow 学习边界与 expiry |
| `relations` | from/to kind+id 与 edge；派生结构边，实体 purge 时硬删 |
| `notifications` | type、payload、read_at；只保存 Emit 档 |
| `sandbox_runtimes` | 系统级 runtime manifest；kind/version unique；硬删 |
| `sandbox_envs` | 系统级 owner/runtime/status manifest；硬删 |

`workspaces` 自身不带 workspace_id。`sandbox_runtimes` 与 `sandbox_envs`
描述全机文件实体，也不带 workspace_id。`model_runtime_profiles` 不保存
prompt、媒体、上游原文错误、明文 endpoint 或 credential。

ID：`ws_`、`aki_`、`mrp_`、`rel_`、`noti_`、`sr_`、`se_`。

Catalog、Mention、WebSearch、AISpawn、HumanLoop、ContextMgr 与 EntityStream
无独立表。

## 8. ID 前缀全集

| 范围 | 前缀 |
|---|---|
| Function | `fn_` · `fnv_` · `fne_` · `fnenv_` |
| Handler | `hd_` · `hdv_` · `hcl_` · `hdenv_` · `hdi_` |
| Agent | `ag_` · `agv_` · `agx_` |
| Workflow / Control / Approval | `wf_` · `wfv_` · `ctl_` · `ctlv_` · `apf_` · `apfv_` |
| Trigger / Flowrun | `trg_` · `tra_` · `trf_` · `fr_` · `frn_` |
| MCP / Document | `mcp_` · `mcl_` · `doc_` |
| Conversation / Media | `cv_` · `msg_` · `blk_` · `att_` · `mdr_` · `mpr_` · `spc_` · `tp_` · `vce_` |
| Search / Platform | `sd_` · `ws_` · `aki_` · `mrp_` · `rel_` · `noti_` · `sr_` · `se_` |
| Runtime only | `sig_` · `bsh_` · `subagt_` |

Infra 运行时 ID 使用自己的前缀，不从消费实体 ID 派生。
