---
id: DOC-124
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-06
review-due: 2026-09-01
audience: [human, ai]
---
# Todo Domain — Agent 工作记忆清单（TodoWrite 式）

> **核心地位**：Todo 是 Agent 的 **“常驻草稿本”**。长跨度、多步骤任务里，LLM 用它显式记录计划、维持一致性，用户实时看到“它正在做什么”。它的价值在于**常驻模型眼前**且**对用户可见**——不是持久存档。
>
> **形态对标 Claude Code 的 `TodoWrite`**：单工具、整列一把替换、无逐项 id、无 CRUD 记账。旧的「4 工具 CRUD + 依赖图 + owner」是错误抽象（把工作草稿本当项目管理数据库），已重铸。

---

## 1. 物理模型 (Data Anatomy)

清单是**值**，不是实体集。一个执行作用域持有**一张** `List`，`Items` 整体替换。

```go
type List struct {
    ScopeID        string     `db:"scope_id,pk"`         // = subagent_id ?? conversation_id（多态 owner 键）
    WorkspaceID    string     `db:"workspace_id,ws"`     // orm 自动隔离
    ConversationID string     `db:"conversation_id"`     // subagent 行 = 父对话
    SubagentID     *string    `db:"subagent_id"`         // nil = 主对话清单
    Items          []Item     `db:"items,json"`          // 整张清单作 JSON 列
    CreatedAt      time.Time  `db:"created_at,created"`
    UpdatedAt      time.Time  `db:"updated_at,updated"`
    DeletedAt      *time.Time `db:"deleted_at,deleted"`
}

type Item struct {
    Content    string `json:"content"`    // 祈使标题 "Run the tests"
    ActiveForm string `json:"activeForm"` // 进行时 "Running the tests"（in_progress 时展示）
    Status     string `json:"status"`     // pending | in_progress | completed
}
```

**砍掉的旧字段**（无人消费的投机抽象）：`blocked_by`（依赖 DAG）、`owner`（多 agent，被 scope 取代做对了）、`metadata`、`description`、逐项 `td_` id、`deleted` 状态（整列替换=移除项不在新列里、无需软删项）。

---

## 2. 核心原理 (Principles)

### 2.1 整列替换 (Whole-List Replace)
每次写入发**整张当前清单**，后端整行 upsert。无逐项 id、无 create/update/delete 逐条操作——LLM 永远只发完整状态，零 ID 记账负担。这正是 `TodoWrite` 的心智。

### 2.2 作用域 = (conversation, subagent?) · scope_id 多态键
清单归属一个**执行上下文**：主对话，或嵌在其中的 subagent run。
- `scope_id = subagent_id ?? conversation_id`——多态 owner 引用（kind ∈ {conversation, subagent}，同 `relation.from_id`），两种 id 都全局唯一故是天然 PK。
- **subagent 隔离**：subagent 写自己的清单（`scope_id = subagent_id`），**永不污染父对话看板**。每个 subagent run 各自一张。
- 执行作用域经 `reqctx` 从 ctx 读（`GetConversationID` + `GetSubagentID`）——todo 因此是叶子模块，不 import conversation / subagent 业务包。chat/agent loop 埋 conversation 种子，subagent loop（波次 3）埋 subagent 种子。

### 2.3 「LLM 真用」= 双层可见性
旧设计最致命的漏洞：清单写完 LLM 就看不见了（要再花一次 tool call 调 List）。重铸后**两层保证常驻**：
1. **工具结果回显**：`TodoWrite` 执行后返回渲染好的清单 → 写完立刻在上下文里。
2. **每轮 system-reminder 注入**：loop 每次迭代调 `Service.SystemReminder(ctx)`，把**未完成**清单作为 reminder 块注入 → 计划持续顶在模型眼前。（loop 接线 = 波次 2/3 M2.2。）

### 2.4 「前端真看见」= REST 初值 + messages 流 live
旧设计的看板是假的（前端 `todo` 通知 handler 返 `[]`、testend 调死链）。重铸后：
- **初值**：`GET /api/v1/conversations/{id}/todos`（`?subagentId=` 可选）。
- **live**：写入时往 **messages 流**推一条 durable `signal`（`scope={kind:conversation, id:<convId>}`、`node.type="todo"`、payload `{conversationId, subagentId?, todos}`）→ 前端任务看板实时跳。
- 锚定**对话**（非 subagent），故查看该对话的前端必收到；subagent 清单的 `subagentId` 入 payload、前端据此嵌到对应子树。**不走 notifications 收件箱**（那是持久 inbox，会刷屏）。
- messages-bridge 实接 = boot 装配（M7）；前端真看板 = 覆盖回 `backend/` 后的前端兼容期。

---

## 3. 生命周期 (Lifecycle)

1. **规划**：LLM 收到复杂指令，调 `TodoWrite` 写下整张计划（全 `pending`）。
2. **执行**：开始某步前，整列重写、把该项设 `in_progress`（约定**恰一项** in_progress）。
3. **完成**：该步结束，整列重写、把它设 `completed`（做完立刻标）。
4. **收尾**：全 `completed` → reminder 不再注入（无未完成项）。移除项只是不出现在下次写入里。

---

## 4. 跨域集成 (Interactions)

- **TodoWrite 工具**（波次 2/3）：唯一写入面，`Service.Write(ctx, items)` → upsert + broadcast + 回显。**写入是 LLM 专属**，前端只读不写（不编辑 agent 的计划）。
- **Loop**（M2.2）：每轮调 `SystemReminder` 注入未完成清单。
- **Messages 流**：写入推 `todo` signal（见 `events.md` §1）。
- **reqctx**（M0.1 扩展）：`conversation_id` + `subagent_id` 双种子；todo 是首个对话级消费者。

---

## 5. 错误处理 (No Wire Codes)

todo **不持 HTTP 错误码契约**。校验（content 必填 `ErrEmptyContent`、status 白名单 `ErrInvalidStatus`、超量 `ErrTooManyItems`）只发生在 `TodoWrite` 工具路径，被渲染成 **tool-result 字符串**供模型自纠、**永不冒泡 HTTP**；REST 读只读不校验。故为 plain `errors.New` sentinel（无 Kind / wire code），不同于 `errorsdomain.New` 构造的 HTTP-bound 错误（S20）。`error-codes.md` 中**无 `TODO_*` 码**。
