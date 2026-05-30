# 12 — 深挖发现(8 subagent 并行盘点 patch 11)

脑爆结论笔记(2026-05-29)。

依赖:00-11 全部。本 doc patch [11-integration-chains.md](./11-integration-chains.md) 的初版盘点 — 深挖出 doc 11 漏掉的:**Memory 给 agent 节点的 严重员工思维漏洞 / Forge SSE 现有协议状态 / Relations 9 种新 kind / Catalog 已天然 "永远 prod" 合规 / Lazy 11 组细化方案 / Frontend 5 新 feature slice**。

---

## 1 个实现期注意点

### Agent 节点不接 memory — 产品决策,链路隔离

**产品决策(2026-05-29 拍)**:**agent 节点不支持 memory**,跟 subagent / 临场 skill search / 临场 forge 一致 — 员工思维不给"老板能力"。

实现期注意点:**不能复用 chat 老板的 `SystemPromptProvider` 注册表**(它默认带 memory + 临场 skill 等),否则 agent 跑时 memory 会自动注入。

**修法**:在 `app/agent/dispatch.go` 走**独立 system prompt 装配链**,只组装 agent.prompt + skill(挂载的)+ knowledge(挂载文档)+ tools(挂载 callables)。从根上不接 memory / subagent / 临场 skill search 这些老板能力。

跟 chat 老板系统 prompt 完全两套机制,**不靠 flag suppress,靠链路隔离**。

---

## Subagent 各自关键发现

### S1. Lazy 分组细化 — 11 组方案

当前 6 lazy group 总 ~4,400 tokens。Subagent 实测 + 提案:

| 当前 | 实测 tokens | 提议拆分 |
|---|---|---|
| function (7) | ~950 | **forge-mutate** (3) + **forge-inspect** (4) |
| handler (8) | ~1,050 | **handler-mutate** (4) + **handler-inspect** (4) |
| workflow (8) | ~900 | **workflow-craft** (3) + **workflow-deploy** (3) + **workflow-debug** (~7,并入错诊 + 观察) |
| mcp (6) | ~700 | **mcp-tools** (3) + **mcp-admin** (3) |
| document (7) | ~600 | **document-tree**(整体保留) |
| skill (2) | ~200 | 现状保留 |

**新增建议**:`catalog-query`(所有 `search_*`)放 **Resident**,LLM 一开始就能搜任何 entity。这样:

- "AI 帮我看一下错诊" → activate `workflow-debug`(7 工具 ~600 tokens)
- "AI 改一个 function" → activate `forge-mutate`(3 工具 ~450 tokens)
- 错诊场景从 22 工具 → 7 工具,**省 73%**

**拍 11 lazy group + catalog-query 入 Resident**(详 S1 结尾推荐)。

### S2. Forge SSE 现状 + 改动

**好消息**:协议 `kind` 字段开放(实际验证只有 3 kind: function/handler/workflow)。扩 kind 集合就行,4 event 类型(started/op_applied/env_attempt/completed)不动。

**Kind 集合扩到 6**(2026-05-29 拍):

| Kind | 现状 | 用意 |
|---|---|---|
| function | ✅ 已支持 | — |
| handler | ✅ 已支持 | — |
| workflow | ✅ 已支持 | — |
| **agent** | ❌ 新 | Quadrinity 一致 |
| **document** | ❌ 新 | 用户编辑文档 — UI 支撑"锻造历史 / sidebar 实时编辑反馈" |
| **skill** | ❌ 新 | skill 编辑也算锻造 |

**emit 点漏了一大堆**:

| 事件 | function | handler | workflow | document | skill |
|---|---|---|---|---|---|
| create | ✅ | ✅ | ✅ | ❌ | ❌ |
| edit | ✅ | ✅ | ✅ | ❌ | ❌ |
| accept_pending | ❌ | ❌ | ❌(都只 notifications) | n/a(无版本) | n/a |
| revert | ❌ | ❌ | ✅ | n/a | n/a |
| delete | ❌ | ❌ | ✅ | ❌ | ❌ |
| move | n/a | n/a | n/a | ❌ | n/a |
| 试跑结果 | ❌ | ❌ | ❌ | n/a | n/a |
| `ForgeOpApplied` 逐 op 进度 | 协议声明**从未 emit** | 同 | 同 | 同 | 同 |

**改动**:

1. `internal/infra/forge/protocol.go::IsValidScopeKind` 加 3 个 kind(agent / document / skill)— 3 行
2. function/handler 的 `accept_pending` / `revert` / `delete` 补 emit(8-10 行)
3. document 的 create / edit / delete / move 补 emit(~6 行)
4. skill 的 create / edit / delete 补 emit(~4 行)
5. `ForgeOpApplied` 真 emit(每 op apply 时,~3-5 site)
6. 试跑结果 emit(已拍 Emit,详 决策 #4)

**env_attempt** 只 function/handler 有(其他 kind 没 Python venv)。

**协议本身不动**:仍 4 event 类型,6 kind 共享。

### S3. Relations — 9 种新 kind + DB CHECK migration

**好消息**:`relations` 表**当前无 version_id 列** — 永远 prod 天然合规 ✅。

**坏消息**:加 agent 需要 9 种新 relation kind:

```
workflow_uses_agent              # workflow 节点 ref agent
agent_uses_function              # agent 工具挂载 fn_xxx
agent_uses_handler               # agent 工具挂载 hd_xxx.method
agent_uses_agent                 # agent 工具挂载 ag_xxx
agent_uses_mcp                   # agent 工具挂载 mcp:server/tool
agent_uses_document              # agent knowledge 挂载
agent_uses_skill                 # agent skill 挂载
conversation_forged_agent        # chat 老板锻造的 agent
conversation_edited_agent        # chat 老板编辑的 agent
```

**改动**(`backend/internal/domain/relation/relation.go`):

- 加 `EntityKindAgent = "agent"`(line 74+)
- 加 9 个 kind 常量
- 改 `IsValidKind` switch (line 54)
- 改 `IsValidEntityKind` switch (line 81)
- 改 DB CHECK constraint 列举(line 26)
- DB migration 加 9 个 kind 到 CHECK

**新加 reader**(`app/relation/relation.go`):AgentReader 接口 + GetRelgraph 加 agent reader 调用。

**Sync hooks**:agent CRUD/Accept/Revert 调用 SyncOutgoing(9 种 kind 的 edge 由 agent.mounts 计算)。

**capability check 不走 relation**(走 workflow graph walk 已足够;relation 只服务 relgraph / UI)。

### S4. Catalog — 已天然 prod-only,只需要加新字段 + agent reader

**好消息**:catalog `Item` 结构很简洁(Source/ID/Name/Description/Category),无 version 字段 — "永远 prod" 天然合规 ✅。

**改动**:

1. 加 `internal/app/agent/catalog_source.go`(~50 LoC)
2. `Item` 加 `Kind` 字段(function 透出 normal/polling)
3. `Item` 加 `Active` 字段(workflow 透出 active 状态;mechanical 渲染加 `[INACTIVE]` 前缀)
4. `runner.go::categoryLabels` 加 `"agent": "..."` 行
5. main.go `catalog.RegisterSource(agentService.AsCatalogSource())`

**token cost**:agent 10-20 个 + function kind 字段 + workflow active 标 ≈ 增加 650-2190 tokens 进 chat 老板的 system prompt。**100+ entity 时考虑 pagination**,目前不急。

**开放问题**:agent 是否进 catalog?Subagent 提了"agent 是 system-level orchestrator 可不进 catalog 省 token"。**我倾向进**(因为 agent 是可被引用的 callable,跟 function/handler 同 lift)— **待用户拍**。

### S5. 跨域涟漪 — 7 个 domain 受影响

| Domain | 改动 | 备注 |
|---|---|---|
| **memory** | 走独立 system prompt 装配链 | agent 不接 memory(产品决策,详上方) |
| **skill** | 加 `AgentID` 到 ExecutionLog + 锻造编辑 op emit forge SSE | skill.Agent 字段已有 ✅ |
| **document** | 锻造编辑 op(create/edit/delete/move)emit forge SSE | 走 relation 即可;delete 受 PurgeEntity 自动清 |
| **mcp** | 无 schema 改 | 走 relation;uninstall 时 audit 是否还有 agent mount |
| **model** | 0 改 | `ScenarioAgent` 已就绪(line 42-44) ✅ |
| **workflow node** | 0 改 | `NodeTypeAgent` 已声明(line 58)+ `IsCapabilityNode` 包括 ✅ |
| **idgen** | 加 `ag_/agv_/agx_` | §S15 注释更新 |
| **conv** | 加 `EntityKindAgent` 到 conv 受 relation 影响 | 用于 :iterate 跟踪 |
| **sandbox** | 0 改 | agent 不在 sandbox 跑;agent 工具挂载的 function/handler 走现有 sandbox ✅ |

**好新闻**:model + workflow node domain 已经预备好了 agent — 不用大改。

### S6. HTTP API — 22 新端点 + 1 改造

**Agent domain 13 端点**:CRUD 6 + version 3 + pending action 2 + run 1 + iterate 1。文件:`backend/internal/transport/httpapi/handlers/agent.go` ~400 lines,mirror `function.go`。

**Workflow lifecycle**:
- 新 `POST /workflows/{id}:activate` / `:deactivate`
- 改造 `POST /workflows/{id}:trigger`,body 加 `triggerNodeId` **必填**(breaking)

**FlowRun**:
- 新 `GET /flowruns/{id}/trace`
- 新 `POST /flowruns/{id}:cancel`
- 已有 `GET /flowruns/{id}/nodes` ✅

**死信 / events 5 端点**:
- `GET /dead-letters?workflowId=...`
- `GET /dead-letters/{messageId}`
- `POST /dead-letters/{messageId}:replay`
- `POST /dead-letters:clear`
- `GET /events?type=...&workflowId=...&since=...`(或扩 `/eventlog`)

**testend 受影响**:`/workflows/{id}:trigger` body 加 triggerNodeId 是 breaking。testend 调用全要 patch。详 [`testend/CLAUDE.md`](../../../testend/CLAUDE.md)。

### S7. 测试基建 — 4 新 pipeline + 9 新 errcode + 6 新 seam

| 类型 | 新增 | 文件 |
|---|---|---|
| Pipeline test | 4 文件 ~850-1100 LoC | `api/agent/` + `api/workflow_lifecycle/` + `cross/flowrun_observe_*` + `cross/diagnosis_*` |
| Errcode sentinel | 9 个 | `AGENT_NOT_FOUND` / `AGENT_VERSION_NOT_FOUND` / `AGENT_NAME_DUPLICATE` / `CAPABILITY_CHECK_FAILED` / `TRIGGER_EXHAUSTED` / `DEAD_LETTER_EXISTS` / `DEAD_LETTER_NOT_FOUND` / `FLOWRUN_NOT_CANCELLABLE` / `INVALID_TRIGGER_NODE` |
| SSE truth | 7 个新 notif type + **3 个新 forge kind** | sse_truth.go 加 forge kind `agent` / `document` / `skill` + notif `workflow_activated/deactivated` / `trigger_exhausted` / `handler_crash` / `dead_letter_created` / `flowrun_node_status_changed` |
| Cross seam | 6 个新 | `workflow:activate_register_listener` / `:deactivate_destroy_listener` / `:trigger_sync_acceptance` / `agent:skill_mount` / `:document_mount` / `scheduler:message_queue_driven` |

`make matrix` 加 1 新 agent section + workflow section 加 2 行 + flowrun section 加 1 行。

### S8. Frontend FSD — 1 新 entity + 5 新 feature + ~1660 LoC

| 类型 | 新增 / 改动 |
|---|---|
| **entities/agent/**(新) | ~300 LoC(types/api/ui card) |
| **entities/workflow/**(改) | +40 LoC,加 activate/deactivate hooks + triggerNodeId param |
| **entities/function/**(改) | +20 LoC,types 加 `kind: 'normal' \| 'polling'`,filter param |
| **entities/flowrun/**(改) | +60 LoC,加 trace / nodes / cancel hooks |
| **features/workflow-deploy/**(新) | ~120 LoC(activate/deactivate 按钮 + 状态 badge) |
| **features/workflow-trigger/**(新) | ~200 LoC(trigger node picker + payload form) |
| **features/flowrun-debug/**(新) | ~300 LoC(trace viewer + 死信 inbox + replay) |
| **features/agent-ui/**(新) | ~250 LoC(agent node config UI + case CEL + approval markdown) |
| **features/workflow-edit/**(改) | +180 LoC(palette 14→5,新节点 config UI) |
| **widgets/canvas-runtime/**(新) | ~140 LoC(画布滴答 overlay) |
| **shared/**(改) | +80 LoC(queryKeys 6 新 + errorMap 5 新 + SSE dispatcher) |
| **i18n** | ~45 新 key |
| **总计** | **~1660 LoC** |

---

## doc 11 需要 patch 的点

| doc 11 段 | 现状 | 改 |
|---|---|---|
| Lazy 划分(C1)| 提议 7 组(workflow 膨胀到 22) | 改 11 组方案 + catalog-query 入 Resident(详 S1) |
| Forge SSE(G1) | 只说 "加 agent kind" | kind 扩到 6(加 agent / document / skill)+ 各 kind 的 emit 点补漏 + ForgeOpApplied 真 emit + 试跑结果 emit |
| 错诊工具放哪 | 待用户拍 | **已答**:Lazy `workflow-debug` 组(7 工具) |
| Relations 改造 | **doc 11 完全没提** | 新加段落:9 种 kind + DB migration + AgentReader |
| Catalog 改造 | doc 11 只提 source 加 reader | 补 `Kind` / `Active` 字段加进 Item + token cost 估算 |
| Memory 给 agent | **doc 11 完全没提** | 新加段:agent 不接 memory(产品决策),dispatch 走独立 system prompt 装配链 |
| categoryLabels | doc 11 提了 | ✅ 跟 S4 一致 |
| HTTP API delta | 散落各处 | 集中到一节 — 22 新 + 1 改 |
| FSD delta | 笼统说"改 workflow-edit" | 1660 LoC 拆细 |

我会回头改 doc 11 这些点(单独 commit 标 `[doc-fix]`)。

---

## 综合改造规模(修订版)

| 块 | doc 11 估时 | 修订 | 修订理由 |
|---|---|---|---|
| 1. DB schema(含 relations migration) | 1.5 天 | **2 天** | 加 relation CHECK migration + agent table 新建 |
| 2. Agent domain + 11 工具 | 2 天 | 2 天 | 不变 |
| 3. Message queue infra | 1.5 天 | 1.5 天 | 不变 |
| 4. driveLoop → message queue | 3-4 天 | 3-4 天 | 不变 |
| 5. Lifecycle(activate/deactivate/trigger)| 2 天 | 2 天 | 不变 |
| 6. Polling 系统 + capability check | 1.5 天 | 1.5 天 | 不变 |
| 7. 教学 prompt + catalog + toolset + SSE 补 emit | 2 天 | **3 天** | + forge emit 补全(~10 处) + agent system prompt 独立链路 + 11 lazy 重组 |
| 8. Frontend(平行块 4 后)| 2-3 天 | **5-6 天** | doc 11 低估;~1660 LoC + 滴答 widget 复杂 |

**总(后端 + 前端) ~21-25 天**(doc 11 原估 13-14 天纯写 + 18-20 含测,**低估了 30-40%** — 主要在 frontend + relations + forge emit 补漏)。

---

## 已拍决策(2026-05-29)

| # | 决策点 | 结论 |
|---|---|---|
| 1 | Lazy 分组细化 | **11 组**(每 forge entity 拆 *-edit / *-use,workflow 额外 *-debug);7 个 `search_*` + 3 skill + 3 memory + meta + chat 基础 入 **Resident** |
| 2 | Agent 进 catalog | **进**(callable 同 lift,与 function/handler 一致) |
| 3 | Memory 给 agent | **不接**(产品决策,员工思维)。实现走独立 system prompt 装配链 |
| 4 | 试跑结果 emit forge SSE | **Emit**(支撑未来"试跑结果时间线"UI) |
| 5 | `ForgeOpApplied` 现在补 emit | **现在补**(协议已声明,~5 行,UI 渐进反馈直接受益) |
| 6 | Agent 带 `:triage` | **带**(对齐 flowrun,反正没坏处) |

剩下的小决策(各种 default 值 / 字段命名)我自己拍,不打扰你。
