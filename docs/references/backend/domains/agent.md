---
id: DOC-129
type: reference
status: active
owner: @weilin
created: 2026-06-01
reviewed: 2026-06-02
review-due: 2026-09-01
audience: [human, ai]
---
# Agent Domain — 实体化 AI Worker 与 Quadrinity 规格

> **核心地位**：Agent 是 Forgify 的“第四支柱” (Quadrinity)。与临时生成的 Chat Agent 不同，本域定义的 Agent 是 **“持久化、版本化、可重用”** 的专业 AI Worker。它可以独立存在，也可以作为 Workflow 节点被引用。

---

## 1. 物理模型 (Data Anatomy)

### 1.1 `Agent` (实体主表)
```go
type Agent struct {
    ID              string         `gorm:"primaryKey;type:text" json:"id"` // ag_<16hex>
    UserID          string         `gorm:"not null;index" json:"-"`
    Name            string         `gorm:"not null;type:text" json:"name"`
    Description     string         `gorm:"type:text;default:''" json:"description"`
    Tags            []string       `gorm:"serializer:json;type:text;default:'[]'" json:"tags"`

    NeedsAttention  bool           `gorm:"not null;default:false" json:"needsAttention"`
    AttentionReason string         `gorm:"type:text;default:''" json:"attentionReason,omitempty"`

    ActiveVersionID string         `gorm:"type:text;default:''" json:"activeVersionId"`
    CreatedAt       time.Time      `json:"createdAt"`
    UpdatedAt       time.Time      `json:"updatedAt"`
    DeletedAt       gorm.DeletedAt `gorm:"index" json:"-"`
}
```

### 1.2 `AgentVersion` (配置快照)
```go
type AgentVersion struct {
    ID            string         `gorm:"primaryKey;type:text" json:"id"` // agv_<16hex>
    AgentID       string         `gorm:"not null;index" json:"agentId"`
    Status        string         `gorm:"not null;default:'pending'" json:"status"` // pending|accepted
    Version       *int           `gorm:"type:integer" json:"version,omitempty"`

    // 挂载件 (Mounts)
    Prompt        string         `gorm:"type:text;default:''" json:"prompt"` // System Prompt
    Skill         string         `gorm:"type:text;default:''" json:"skill"`  // 引用的 Skill 名
    Knowledge     []string       `gorm:"serializer:json;type:text" json:"knowledge"` // doc_ID 列表
    Tools         []ToolRef      `gorm:"serializer:json;type:text" json:"tools"`     // 引用的实体列表

    // 约束
    OutputSchema  *OutputSchema  `gorm:"serializer:json;type:text" json:"outputSchema"`  // invoke 时注入 systemPrompt（enum/json_schema）
    ModelOverride *ModelRef      `gorm:"serializer:json;type:text" json:"modelOverride"` // apiKeyId+modelId；nil=默认 agent scenario

    ChangeReason           string     `gorm:"type:text;default:''" json:"changeReason,omitempty"`
    ForgedInConversationID *string    `gorm:"index;type:text" json:"forgedInConversationId,omitempty"` // relation forged/edited 边
    AcceptedAt             *time.Time `json:"acceptedAt,omitempty"`

    CreatedAt     time.Time      `json:"createdAt"`
    UpdatedAt     time.Time      `json:"updatedAt"`
}
```

---

## 2. 核心原理 (Principles)

### 2.1 挂载件架构 (Mounts Architecture)
Agent 不直接编写逻辑代码，而是通过 **“挂载”** 其它领域的实体来定义能力：
- **Knowledge Mount**：挂载 `document` 实体。系统在执行该 Agent 时，会自动将这些文档的内容展开为 XML 注入 Context。
- **Tool Mount**：显式授权该 Agent 可用的工具（`fn_`, `hd_`, `mcp:`）。禁止 Agent 递归引用另一个 Agent ID（ADR-010）。
- **Output Schema**：若配置，`invoke` 时把约束注入 system prompt（`enum` 列出可选值 / `json_schema` 给 schema 并要求纯 JSON 输出）；`enum` 模式对最终输出做 best-effort 规整（trim + 匹配回允许值），方便下游 workflow `case` 节点稳定命中。
- **Model Override**：`*ModelRef`（apiKeyId+modelId+options）。`invoke` 经 `ResolveAgentWithOverride` 解析——设了就用那把 key+model，nil 走默认 `agent` scenario；execution 记录实际 resolve 出的 modelId。缺 apiKeyId/modelId 在 create/edit 即被 `ErrInvalidModelOverride` 拦下（对标 workflow 节点 override 校验）。

### 2.2 Sub-step Replay (子步重放 - ADR-010)
当 Agent 作为 Workflow 的一个节点执行时：
- **问题**：一个 Agent 回回合可能包含 5 次工具调用。如果 Workflow 在第 3 次调用后崩溃，重启后不应重新消耗前 2 次 Token。
- **方案**：解释器通过 `AgentSubSteps` 句柄，将 Agent 内部的每一轮 LLM 响应和工具结果都记入 `flowrun_events`。
- **效果**：重放时，Agent 会“快进”到最后一个未完成的子步。

---

## 2.5 工具面 + HTTP 端点（1:1 对标 function）

Agent 的工具/端点面与 function **完全对称**（一文件一工具，`app/tool/agent/`）：

| function | agent | 说明 |
|---|---|---|
| `create_function` | `create_agent` | v1 自动 accept |
| `edit_function` | `edit_agent` | 产 pending（iterate-same-pending）|
| `delete_function` | `delete_agent` | 软删 |
| `get_function` | `get_agent` | 详情 |
| `search_function` | `search_agents` | 库内搜索（LLM 相关性排序，对标 search_function）|
| `revert_function` | `revert_agent` | active 切回旧 accepted 版本号 |
| `run_function` | **`invoke_agent`** | **真跑** ReAct loop（真调 LLM/工具），返 `{ok,output,status,steps,tokens,executionId}`，**落一条 AgentExecution** |
| `get_function_execution` | `get_agent_execution` | 单条执行详情 + hints |
| `search_function_executions` | `search_agent_executions` | 执行日志分页 + 聚合 |

> **无 accept LLM 工具**（同 function）：v1 自动 accept；pending 的 accept/reject 走 UI/HTTP（`pending:accept` / `pending:reject`），不给 LLM。

**HTTP 端点**（对标 function handler，完全对称）：`POST /agents`、`GET /agents`、`GET/PATCH/DELETE /agents/{id}`（PATCH=UpdateMeta，改 name/description/tags 不升版本）、`POST /agents/{id}:invoke`（真跑）/`:edit`/`:revert`/`:iterate`（AI 编辑对话→conversationId，经 askai spawner）、`GET /agents/{id}/versions` + `/versions/{version}`（单版本，数字号或 versionId）、`GET /agents/{id}/pending` + `pending:accept|reject`、`GET /agents/{id}/executions`、`GET /agent-executions/{execId}`。

**执行落表**：`InvokeAgent` 是唯一执行方法（invoke_agent 工具 / HTTP :invoke / workflow agent 节点都经它），每次跑完写一条 `agent_executions`（`agx_` 前缀，字段对标 `function_executions`：status/triggeredBy/input/output/elapsedMs/conversationId/flowrunId 等）。Service 持有 LLM 依赖（picker/keys/factory/toolsFn/knowledge），经 `SetInvokeDeps` 注入——正如 function service 持有 sandbox 端口。

> **Workflow agent 节点**：`dispatch_agent` 见 `config.agentRef` 即路由进 `InvokeAgent`（`triggeredBy=workflow` + `flowrunId/flowrunNodeId`），workflow 触发的执行同样落 `agent_executions`——对标 function workflow 节点经 `RunFunction` 落表。ADR-010 子步重放经 `InvokeInput.ReplaySteps`+`Recorder` 透传，崩溃重放仍快进到最后一个未完成子步。（裸 `config.prompt` 内联节点无实体，沿用旧内联 loop，不落表。）

## 3. 生命周期 (Lifecycle)

1. **锻造 (Forging)**：用户或 AI 调 `create_agent` 工具，填入 Prompt 和 Mounts。
2. **待审 (Pending)**：生成 `agv_` 记录。此时该 Agent 尚不可被 Workflow 引用。
3. **试跑 (Invoke)**：调 `invoke_agent` 真跑一次验证配置（对标 run_function 试跑），结果落 `agent_executions`。
4. **转正 (Accepting)**：用户确认配置，Pending -> Accepted。
5. **嵌入 (Embedding)**：在 Workflow 图中通过 `agentRef: "ag_xxx"` 进行引用。
6. **执行 (Execution)**：Scheduler 唤起 `chatHost`，加载 Agent 配置，启动 ReAct 循环。

---

## 4. 跨域集成 (Interactions)

- **Workflow**：通过 `agent` 节点类型引用。
- **Document**：解析 `Knowledge` 列表。
- **Capability Catalog**：Agent 实体会作为一类特殊的“能力”出现在系统的全局 Catalog 中，供主对话 Agent 发现。
- **Relation**：`agentService` 实现 `SetRelationSyncer` + `AgentReader`（对标 7 个兄弟实体）。Create/Accept/Revert 时从 active version 扫出 outgoing 边 `agent_uses_function|handler|mcp|document|skill`（无 `agent_uses_agent`，员工不调员工），并按 `ForgedInConversationID` 写 conversation `forged`/`edited` 边；Delete 级联 purge；relgraph 经 `ListAllMeta` 把 agent 列为节点。

---

## 5. 错误字典 (Sentinels)

| Sentinel | Wire Code | 备注 |
|---|---|---|
| `ErrNotFound` | `AGENT_NOT_FOUND` | |
| `ErrNoActiveVersion`| `AGENT_NO_ACTIVE_VERSION` | 尝试运行一个未转正的 Agent。 |
| `ErrToolsAgentRef` | `AGENT_TOOLS_AGENT_REF_FORBIDDEN` | 安全红线：禁止 Agent 互相调用。 |
| `ErrNoPending` | `AGENT_NO_PENDING` | accept 动作前提不符。 |
| `ErrExecutionNotFound` | `AGENT_EXECUTION_NOT_FOUND` | get_agent_execution 查无。 |
| `ErrVersionNotFound` | `AGENT_VERSION_NOT_FOUND` | revert 目标版本号不存在/未 accepted。 |
| `ErrInvalidModelOverride` | `AGENT_INVALID_MODEL_OVERRIDE` | modelOverride 缺 apiKeyId 或 modelId。 |
