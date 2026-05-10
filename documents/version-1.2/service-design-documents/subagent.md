# Subagent — V1.2 详设计

**Phase**：Phase 4 准备件（已交付 + 2026-05 schema 统一）
**状态**：✅ 已实施

**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../event-log-protocol.md`](../event-log-protocol.md) — 事件日志协议事实源（subagent 走与 chat 同一协议；嵌套消息靠 `parentBlockId` 串）
- [`../service-contract-documents/database-design.md`](../service-contract-documents/database-design.md) — 无独立 subagent 表；sub-run 是 `messages` 行（attrs.kind=subagent_run），sub blocks 是 `message_blocks`
- [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md) — subagent sentinel
- [`./chat.md`](./chat.md) — chat domain 详设计；subagent 共享 `app/loop` 引擎与同一 Repository
- [`./skill.md`](./skill.md) —（未来）`context: fork` 复用本服务

---

## 1. 一句话

LLM 通过 **`Subagent(prompt, subagent_type)` 一个 system tool**，在主对话之外起一个 **独立 context、过滤后 tool 列表** 的子 LLM loop；跑完只回 last assistant message 给主 LLM 当 tool_result。**复用 `app/loop` 共享 ReAct 引擎**，不复制流式/重试/工具调度逻辑。

> **注**：原本对齐 Claude Code 叫 `Task`，但 Forgify 已有 `task` mini-domain（TaskCreate/List/Get/Update 管 TODO），改名 `Subagent` 明确区分。

---

## 2. 端到端推演（设计原则 #5）

```
触发源：LLM 在 chat agent 循环里调 Subagent 工具
  → transport 层：无（system tool 不走 HTTP）
    → app 层：app/tool/subagent.SubagentTool.Execute
        → ValidateInput：subagent_type / prompt 非空（trim）
        → reqctxpkg.GetSubagentDepth(ctx) >= 1 → 立即返 ErrRecursionAttempt（双保险防递归）
        → subagentapp.Service.Spawn(parentCtx, type, prompt, opts)
            → registry.Get(type) → SubagentType（找不到 → ErrTypeNotFound）
            → llmclientpkg.Resolve → bundle{ModelID, Key, BaseURL, Client}
            → maxTurns = opts.MaxTurns ?? typ.DefaultMaxTurns（registry 兜底 25）
            → mint subMsgID = msg_<16hex>（充当 RunID + 占位 sub-Message PK）
            → 若 parentToolCallID + parentMsgID 都有 →
                 mint msgBlockID = blk_<16hex>
                 em.EmitBlockStart(msgBlockID, parent=parentToolCallID, parentMsgID, BlockTypeMessage,
                   attrs={messageId:subMsgID, type:typ.Name})
                 em.EmitMessageStart(subMsgID, "assistant", parentBlockId=msgBlockID,
                   attrs={kind:"subagent_run", type, maxTurns})
              否则（直接 Service.Spawn 测试调用）→ 跳过这两步
            → subCtx = parentCtx
                + WithSubagentDepth(parentDepth+1)
                + WithMessageID(subMsgID) + WithParentBlockID("")  // sub blocks 顶层挂在 subMsgID 下
                + With(emitter) + WithTimeout(5min)
            → host = subagentHost{svc, subMsgID, parentConvID, msgBlockID, uid, typ.Name, maxTurns,
                       tools=filterTools(typ), userPrompt=prompt, systemPrompt=composeSystemPrompt(...)}
            → defer recover：panic → runErr = "subagent panic: %v"
            → result = loopapp.Run(subCtx, host, bundle.Client, baseReq, maxTurns, log)
                · loop.Run 内部 streamLLM 实时 emit text/reasoning/tool_call block_start/delta/stop
                · runOneTool 每 tool 跑完 emit tool_result block
                · 终态走 host.WriteFinalize → SaveMessage（messages 行）+ em.StopMessage(subMsgID, ...)
            → 映射 loop.Result → SpawnResult.Status (4 桶：Completed / MaxTurns / Cancelled / Failed)
            → reconcileCtx 重写 sub-Message.Status（loop 写 chatdomain.Status*，这里覆盖为 subagent 桶）
            → em.StopBlock(msgBlockID, mappedStatus, nil)  关父对话 placeholder（用 detached stopCtx）
        → 回到 SubagentTool.Execute：按 res.Status 转友好 tool_result
            · Completed → return res.Result
            · MaxTurns / Cancelled → appendNote(res.Result, "subagent hit max turns / was cancelled")
            · Failed → appendNote 或裸 "Subagent <type> failed: <err>"
        → 返字符串给主 LLM 作为 tool_result（chat loop 的 runOneTool 写回 tool_result block）
  → 主 LLM 收到 tool_result，继续主 loop
```

**端到端跨 domain 依赖**：
- `app/loop`：通用 ReAct 引擎，subagent 通过 `loop.Run + Host 接口` 接入，不复制流式/工具调度/历史扩展
- `app/chat`：**无直接依赖**——chat 与 subagent 都是 loop 的调用方
- `domain/chat`：subagent 直接持 `chatdomain.Repository`，写 sub-Message 行 + 用 chat 的 `messages` / `message_blocks` 表（无独立 subagent 表）
- `pkg/eventlog`：emitter 在 `parentCtx` / `subCtx` 上传递，自动嵌套 emit
- `pkg/reqctx`：`SubagentDepth` / `ParentBlockID` ctx key

---

## 3. 领域模型

`internal/domain/subagent/subagent.go` 仅承载 **SubagentType 注册表形状 + 防递归 sentinel**——subagent 没有独立 entity / 独立表。

### 3.1 数据归属（统一 messages + message_blocks）

事件日志协议统一后（2026-05-08），sub-run 数据形态：

| 概念 | 落在哪 |
|---|---|
| **sub-run 总账** | `messages` 表的一行（`role=assistant`，`parent_block_id=msg-block-placeholder`，`attrs.kind=subagent_run + type/runId/maxTurns`，`status` 走 chatdomain 4 值） |
| **sub-run 转录**（user prompt + reasoning / text / tool_call / tool_result blocks）| `message_blocks` 表，挂在 sub-run message 下（顶层 block 的 parent_block_id = sub-Message.ID）；经 `eventlog.Emitter` 实时写 |
| **sub-run 的"在父对话哪？"** | 父对话 message 的 `tool_call` block 下加一个 `type=message` 占位 block（attrs.messageId=sub-Message.ID）；前端递归渲染 |

具体落库形状 → `internal/app/subagent/host.go::WriteFinalize` + `spawn.go::Spawn` 的 EmitBlockStart / EmitMessageStart 序列。Message + Block schema 详见 [`./chat.md` §6.1-6.2](./chat.md#6-消息存储message--block-模型)。

**无 `subagent_runs` / `subagent_messages` 表**；**无 `sar_` / `smm_` ID 前缀**。Sub-Message 用 `msg_<16hex>`，sub blocks 用 `blk_<16hex>`，placeholder block 也用 `blk_<16hex>`。

### 3.2 SubagentType（注册表项）

```go
// internal/domain/subagent/subagent.go
type SubagentType struct {
    Name            string   `json:"name"`            // "Explore" / "Plan" / "general-purpose"
    SystemPrompt    string   `json:"systemPrompt"`    // sub-runner 的 system prompt
    AllowedTools    []string `json:"allowedTools"`    // tool 白名单（按 Tool.Name() 匹配）；nil = 继承父注册表 minus Subagent
    DefaultMaxTurns int      `json:"defaultMaxTurns"` // Registry 装载时 0 兜底为 25
}
```

### 3.3 Sentinel（2 个）

```go
var (
    ErrTypeNotFound     = errors.New("subagent: type not found")
    ErrRecursionAttempt = errors.New("subagent: nested spawn not allowed")
)
```

**没有** `ErrMaxTurnsExceeded` / `ErrCancelled`——两者是终态 string，不是 sentinel error。max_turns / cancelled / failed 终态由 `SpawnResult.Status` 承载（4 个 string 常量），由 SubagentTool.Execute 转友好 tool_result 字符串返主 LLM，**不**抛 handler。

---

## 4. 内置 SubagentType（V1 三种）

实现位于 `internal/app/subagent/registry.go`。Tool 名匹配各 Tool.Name() 返回值。

### 4.1 `Explore`（参考 Claude Code）

```go
{
    Name:            "Explore",
    SystemPrompt:    "You are Explore, a code reconnaissance agent. ...",
    AllowedTools:    []string{"Read", "Glob", "Grep", "LS", "search_forges"},  // read-only 白名单
    DefaultMaxTurns: 30,
}
```

### 4.2 `Plan`（参考 Claude Code）

```go
{
    Name:            "Plan",
    SystemPrompt:    "You are Plan, an architectural advisor. ...",
    AllowedTools:    []string{"Read", "Glob", "Grep", "LS", "WebFetch", "WebSearch"},
    DefaultMaxTurns: 25,
}
```

### 4.3 `general-purpose`

```go
{
    Name:            "general-purpose",
    SystemPrompt:    "You are a general-purpose subagent. ...",
    AllowedTools:    nil,                                       // nil = 继承父 registry 但去掉 Subagent
    DefaultMaxTurns: 25,
}
```

**`AllowedTools` nil 的语义**：`Service.filterTools` 里 `allowed == nil` 时只过 Subagent，不进白名单环节——继承父注册表 minus Subagent 自身。其他类型用显式白名单。

---

## 5. 数据持久化（无独立 Repository）

**subagent 不需要独立 Repository 接口。** Sub-run 数据全部写到 `chatdomain.Repository`（同 chat 用同一份 store + 同一组方法）：
- `chatRepo.SaveMessage(ctx, msg)` — 写 sub-Message 行（带 ParentBlockID + Attrs JSON）
- `chatRepo.GetMessage(ctx, id)` — Spawn 内 reconcile 读回
- 子 blocks 经 `pkg/eventlog.Emitter` 走 `chatRepo.SaveBlock / AppendDelta / FinalizeStop`（与 chat 主对话 block 共用同一写入路径）

**没有 `infra/store/subagent/` 目录**——不存在。

---

## 6. Service 层（`internal/app/subagent/`）

### 6.1 文件结构（4 文件）

```
app/subagent/
  subagent.go  ← Service struct + New + SetTools + filterTools + composeSystemPrompt
  spawn.go     ← SpawnOpts + SpawnResult + Status* 常量 + defaultRunTimeout + Spawn 全生命周期
  host.go      ← subagentHost 实现 loop.Host：LoadHistory / Tools / WriteFinalize + mapEventLogStatus
  registry.go  ← SubagentType registry（builtInTypes 切片 + Get/List + sync.Once 索引）
```

### 6.2 Service struct

```go
type Service struct {
    chatRepo    chatdomain.Repository  // 写 sub-Message 行（无独立 subagent 表）
    registry    *Registry              // 具体类型，非 map[string]subagentdomain.SubagentType
    tools       []toolapp.Tool         // 全局 tool 列表（每次 Spawn 内部按 type 过滤一份子集）
    modelPicker modeldomain.ModelPicker
    keyProvider apikeydomain.KeyProvider
    llmFactory  *llminfra.Factory
    log         *zap.Logger
}

func New(
    chatRepo chatdomain.Repository,
    registry *Registry,
    modelPicker modeldomain.ModelPicker,
    keyProvider apikeydomain.KeyProvider,
    llmFactory *llminfra.Factory,
    log *zap.Logger,
) *Service
```

ctor 6 参数；`log==nil` 立刻 panic（同 chat.NewService）。`tools` 由 `SetTools` 后置注入（与 chat 同模式，避全局 tool 列表与 SubagentTool 自身的循环依赖）。

**为什么 chatRepo 而不是独立 Repository**：sub-run 的"行"和 chat assistant message 的"行"在 schema 上完全一致（`messages` + `message_blocks` 同表），区别仅在 `Message.ParentBlockID` + `Message.Attrs.kind`——直接复用 chat Repository 接口即可，没有独立 store 的必要。

### 6.3 SpawnOpts / SpawnResult / Status

```go
const (
    StatusCompleted = "completed"
    StatusMaxTurns  = "max_turns"
    StatusCancelled = "cancelled"
    StatusFailed    = "failed"
)

type SpawnOpts struct {
    MaxTurns int // 0 = 用 typ.DefaultMaxTurns
}

type SpawnResult struct {
    RunID     string // = sub-Message.ID = msg_<16hex>（兼作 LLM 可见 "subagent run id"）
    Type      string
    Status    string // 4 状态之一
    ErrorMsg  string // 仅 Status==Failed 时填
    Result    string // last assistant text — 返主 LLM 作 tool_result
    TokensIn  int
    TokensOut int
    StepsUsed int
}

func (s *Service) Spawn(parentCtx context.Context, typeName, prompt string, opts SpawnOpts) (*SpawnResult, error)
```

**Service 公开 API 仅 Spawn + ctor + SetTools 后置注入**——没有 `Get` / `ListTypes` / `ListByConversation` / `Cancel`。父 ctx cancel 经派生自然级联到 sub-run。Type 列表通过 `Registry.List()` 暴露（仅契约测试消费；HTTP API 不暴露——见 §11）。

**defaultRunTimeout = 5 分钟**（spawn.go 顶常量）——单次 Spawn 总超时，sub-run 唯一抢占机制；防 stuck tool 让 sub-runner 永挂。

### 6.4 loop.Host 实现：subagentHost

`loop.Host` 接口只有 **3 个方法**（详 [`chat.md` §5.2](./chat.md#52-react-loopapploop)）：

```go
type Host interface {
    LoadHistory(ctx) ([]llminfra.LLMMessage, error)
    Tools() []toolapp.Tool
    WriteFinalize(ctx, blocks, status, stopReason, errCode, errMsg, in, out)
}
```

subagent 实现：

```go
type subagentHost struct {
    svc           *Service
    subMsgID      string // sub-Message ID（messages 表 PK + event-log 协议 msgID）
    parentConvID  string // sub-Message.ConversationID（与父对话相同）
    parentBlockID string // 父对话 type=message 占位 block 的 ID
    uid           string
    typeName      string
    maxTurns      int
    tools         []toolapp.Tool  // per-spawn 过滤后的 tool 列表
    userPrompt    string
    systemPrompt  string
}

func (h *subagentHost) LoadHistory(_ context.Context) ([]llminfra.LLMMessage, error) {
    return []llminfra.LLMMessage{
        {Role: llminfra.RoleUser, Content: h.userPrompt},
    }, nil
}

func (h *subagentHost) Tools() []toolapp.Tool { return h.tools }

func (h *subagentHost) WriteFinalize(ctx, blocks, status, stopReason, errCode, errMsg, in, out) {
    saveCtx := context.Background()
    if uid, err := reqctxpkg.RequireUserID(ctx); err == nil {
        saveCtx = reqctxpkg.SetUserID(saveCtx, uid)
    } else if h.uid != "" {
        saveCtx = reqctxpkg.SetUserID(saveCtx, h.uid)
    }
    attrs, _ := json.Marshal(map[string]any{
        "kind": "subagent_run", "type": h.typeName, "runId": h.subMsgID, "maxTurns": h.maxTurns,
    })
    msg := &chatdomain.Message{
        ID: h.subMsgID, ConversationID: h.parentConvID, UserID: h.uid,
        ParentBlockID: h.parentBlockID, Role: chatdomain.RoleAssistant,
        Status: status, StopReason: stopReason,
        ErrorCode: errCode, ErrorMessage: errMsg,
        InputTokens: in, OutputTokens: out, Attrs: string(attrs),
    }
    h.svc.chatRepo.SaveMessage(saveCtx, msg)  // 错误 log Error，不 panic

    // 用 detached saveCtx 发 message_stop（同 chat/host.go 的 §S9 模式）
    em := eventlogpkg.From(ctx)
    em.StopMessage(saveCtx, h.subMsgID, h.mapEventLogStatus(status), stopReason, errCode, errMsg, in, out)

    _ = blocks  // unused — sub blocks 已经经 emit 实时落 message_blocks
}
```

`mapEventLogStatus` 做 `chatdomain.Status*` → `eventlogdomain.Status*` 翻译，default 分支 Warn log 让 chatdomain 增加新 Status* 但未更新 switch 的漂移可见（与 chat/host.go 同模式）。

**为什么 subagent 不需要 `OnInitialPublish` / `OnStreamCheckpoint` / `OnStepComplete` 这些钩子**：事件日志协议接管了所有"中间态推送"——streamLLM 实时 emit 每 token / 每 tool / 每 block 状态变化，无 host 侧 hook 需求。loop 简化为 3 方法接口（旧设计 6+ 方法已废）。

---

## 7. Tool 实现（`internal/app/tool/subagent/agent.go`）

```go
type SubagentTool struct {
    svc *subagentapp.Service
}

func SubagentTools(svc *subagentapp.Service) []toolapp.Tool {
    return []toolapp.Tool{&SubagentTool{svc: svc}}
}

// Identity
func (t *SubagentTool) Name() string                { return "Subagent" }
func (t *SubagentTool) Description() string         { return subagentDescription }  // 含 Use-for 列表
func (t *SubagentTool) Parameters() json.RawMessage { return subagentSchema }       // 3 字段：subagent_type / prompt / max_turns

// Static metadata
func (t *SubagentTool) IsReadOnly() bool        { return false }  // sub-runner 可写
func (t *SubagentTool) NeedsReadFirst() bool    { return false }
func (t *SubagentTool) RequiresWorkspace() bool { return false }

// Args-dependent hooks
func (t *SubagentTool) ValidateInput(args json.RawMessage) error {
    // 解 args，subagent_type / prompt 必须 trim 后非空
    // 失败返 ErrEmptyType / ErrEmptyPrompt
}
func (t *SubagentTool) CheckPermissions(_ json.RawMessage, _ toolapp.PermissionMode) toolapp.PermissionResult {
    return toolapp.PermissionAllow
}

func (t *SubagentTool) Execute(ctx context.Context, argsJSON string) (string, error) {
    // 1. 运行时递归守卫（双保险 layer 2）
    if depth := reqctxpkg.GetSubagentDepth(ctx); depth >= 1 {
        return "", fmt.Errorf("SubagentTool.Execute: %w (depth=%d)", subagentdomain.ErrRecursionAttempt, depth)
    }
    // 2. 解析 args
    var args struct {
        SubagentType string `json:"subagent_type"`
        Prompt       string `json:"prompt"`
        MaxTurns     int    `json:"max_turns"`
    }
    if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
        return "", fmt.Errorf("SubagentTool.Execute: parse args: %w", err)
    }
    // 3. Spawn
    res, err := t.svc.Spawn(ctx, args.SubagentType, args.Prompt, subagentapp.SpawnOpts{MaxTurns: args.MaxTurns})
    if err != nil {
        return "", err  // ErrTypeNotFound / persist failure / LLM resolve failure 已用 %w 包好
    }
    // 4. 终态文案（4 桶）
    switch res.Status {
    case subagentapp.StatusMaxTurns:
        return appendNote(res.Result, "subagent hit max turns; consider re-spawning with more turns or refining the prompt"), nil
    case subagentapp.StatusCancelled:
        return appendNote(res.Result, "subagent was cancelled"), nil
    case subagentapp.StatusFailed:
        if strings.TrimSpace(res.Result) != "" {
            return appendNote(res.Result, fmt.Sprintf("subagent failed: %s", res.ErrorMsg)), nil
        }
        return fmt.Sprintf("Subagent %s failed: %s", res.Type, res.ErrorMsg), nil
    default:  // Completed
        return res.Result, nil
    }
}
```

`appendNote(body, note)`：把 `[note: …]` 行加到 body 后，用空行分隔，让 LLM 区分自身 assistant 文本与框架注释。空 body 时返单独的 `[note: …]`。

---

## 8. 防递归机制（双保险）

### 保险 1：tool registry 物理排除（结构性防御）

`Service.filterTools(typ)`：

```go
for _, t := range s.tools {
    if t.Name() == "Subagent" {
        continue  // 子 agent 永远看不到 Subagent 工具
    }
    if allowed != nil {  // typ.AllowedTools 设了
        if _, ok := allowed[t.Name()]; !ok { continue }
    }
    out = append(out, t)
}
```

**主防线**——LLM 看不到工具就不可能调用它。`AllowedTools` 即使错误地包含 "Subagent"，filterTools 也强制剥掉。

### 保险 2：ctx depth 检查（运行时兜底）

`SubagentTool.Execute` 第一行 `reqctxpkg.GetSubagentDepth(ctx) >= 1` → 拒绝。理论上不会触发（保险 1 已挡住），但兜底捕获 bridge bug 或测试场景。

### 8.1 Cancellation 级联（parent → subagent）

- `Service.Spawn` 内部 `subCtx, cancel := context.WithTimeout(parentCtx, defaultRunTimeout)`——parent ctx cancel 自动级联（因为 subCtx 派生自 parentCtx）
- sub-runner 检测到 ctx.Done → loop.Run 走 cancelled 分支 → host.WriteFinalize 写终态
- 无外部 `Service.Cancel` API——父 ctx cancel 是唯一抢占机制（5 min 总超时是兜底）
- 已发出的 tool 调用走各自 tool 的 cancel 链

### 8.2 Subagent 总超时

`defaultRunTimeout = 5 * time.Minute`（spawn.go 顶常量）——固定值，**不**通过 SubagentType override（domain 没有 Timeout 字段；运行时无配置入口）。超时 → ctx cancel → loop 走 cancelled 桶 → SpawnResult.Status = StatusCancelled。

### 8.3 Panic 恢复

`Service.Spawn` 包 `loop.Run` 的 defer recover：

```go
func() {
    defer func() {
        if r := recover(); r != nil {
            runErr = fmt.Errorf("subagent panic: %v", r)
            s.log.Error("subagent run panicked", zap.String("sub_msg_id", subMsgID), zap.Any("panic", r))
        }
    }()
    result = loopapp.Run(subCtx, host, bundle.Client, baseReq, maxTurns, s.log)
}()
```

panic → `runErr != nil` → SpawnResult.Status = StatusFailed + ErrorMsg。**不**直接 publish 一个 panic event（事件流靠 `WriteFinalize` 与后续 `StopBlock` 自然收尾——如果 panic 发生在 WriteFinalize 之前，重对齐 ctx 写盘 + StopBlock 仍然执行）。

### 8.4 Sub-Message 状态重对齐

`loop.Run` 的 `host.WriteFinalize` 写 `chatdomain.Status*`（4 值）；`Spawn` 在 loop 返后 re-map 到 subagent 4 桶（`StatusMaxTurns / Failed / Cancelled / Completed`）。重对齐用 detached `reconcileCtx`：

```go
if spawn.Status != StatusCompleted {
    reconcileCtx := reqctxpkg.SetUserID(context.Background(), uid)
    reconcileCtx = reqctxpkg.WithConversationID(reconcileCtx, parentConvID)
    if existing, _ := s.chatRepo.GetMessage(reconcileCtx, subMsgID); existing != nil {
        existing.Status = spawn.Status
        if spawn.ErrorMsg != "" { existing.ErrorMessage = spawn.ErrorMsg }
        s.chatRepo.SaveMessage(reconcileCtx, existing)  // 失败 Warn log
    }
}
```

### 8.5 Placeholder Block 关闭

Spawn 末尾用 detached `stopCtx` 关父对话 placeholder message-block（防 parent cancel 在 sub-run 结束到 StopBlock emit 之间触发——否则前端留 dangling block_start，§S21 违规）：

```go
if msgBlockID != "" {
    closeStatus := eventlogdomain.StatusCompleted
    switch spawn.Status {
    case StatusFailed:    closeStatus = eventlogdomain.StatusError
    case StatusCancelled: closeStatus = eventlogdomain.StatusCancelled
    }
    stopCtx := reqctxpkg.SetUserID(context.Background(), uid)
    stopCtx = reqctxpkg.WithConversationID(stopCtx, parentConvID)
    em.StopBlock(stopCtx, msgBlockID, closeStatus, nil)
}
```

### 8.6 并发 subagent 隔离

- 各 subagent 用独立 subMsgID + 独立 ctx（共享 parent ctx 但有自己的 cancel）
- 每 sub-Message 行独立持 InputTokens / OutputTokens，DB 层天然按 subMsgID 分桶
- chat loop 的 `partitionByExecutionGroup` 已能正确并行调度（LLM 用同 `execution_group` 把多个 Subagent 调用并行）

### 8.7 Conversation 删除时数据处理

**决策**：sub-run messages **跟随 chat 软删机制**——`messages` 表用 `gorm.DeletedAt`（§D1 软删）。conversation 软删后查询自然过滤；DB 行仍在（DBA / 历史回查可用）。无独立级联策略。

---

## 9. Token Accounting

### 9.1 实时累计（loop.Result）

`loop.Run` 的 `Result` 携带 `TokensIn / TokensOut / Steps`，Spawn 透传到 SpawnResult。WriteFinalize 也把 `in / out` 写到 sub-Message.InputTokens / OutputTokens。

### 9.2 主对话内 agentstate 累计

**已删（2026-05-11，dead-2 EDGE-1 / dead-8 MED-1）**：原 `pkg/agentstate.AddSubagentTokens` / `SubagentTokenLog` write-only API 已删。Service.Spawn 不再写 token log——UI/cost panel 从未消费该 slice。Per-run 统计仍走 zap log（§9.3）+ `SpawnResult.TokensIn/Out` 回主 LLM。未来需要对话级 token budget 可基于 `chatRepo` 聚合 sub-Message 行（attrs.kind=subagent_run）的 `InputTokens` / `OutputTokens` 计算。

### 9.3 日志（zap）

每 SubagentRun 终态 INFO 级日志：

```go
s.log.Info("subagent run terminated",
    zap.String("sub_msg_id", subMsgID),
    zap.String("type", typ.Name),
    zap.String("status", spawn.Status),
    zap.Int("tokens_in",  spawn.TokensIn),
    zap.Int("tokens_out", spawn.TokensOut),
    zap.Int("steps",      spawn.StepsUsed))
```

**v1 不强制预算上限**，但日志使任何 runaway loop 都可被发现 + retro 加 budget 简单（log 行就是 budget 决策依据）。

---

## 10. SSE 事件（事件日志协议）

**subagent 不发自己的 SSE 事件类型**——与 chat 共用同一份事件日志协议（5 events × 6 block types）。详见 [`../event-log-protocol.md`](../event-log-protocol.md) 与 [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md)。

### 10.1 Sub-run 在父对话事件树的位置

```
父 chat 主 msg (msg_main)
└─ tool_call block (tc_spawn_subagent)            ← 父 LLM 调 Subagent 工具
   ├─ message block (blk_msg_placeholder,         ← Service.Spawn 推
   │                  attrs.messageId=msg_sub,
   │                  attrs.type=Explore)
   │   └─ Sub message (msg_sub,                   ← Service.Spawn 推 message_start
   │                    parentBlockId=blk_msg_placeholder,
   │                    attrs.kind=subagent_run, type, maxTurns)
   │       ├─ block: reasoning / text / tool_call / ...   ← sub loop streamLLM 实时 emit
   │       │   └─ block: tool_result                       ← sub runOneTool 实时 emit
   │       └─ message_stop                                 ← subagentHost.WriteFinalize 推
   └─ tool_result block (parent=tc_spawn_subagent)         ← chat runOneTool 写父 tool_result
```

前端递归渲染：每个 `block_start` 按 `parentId` 挂到树里；`message` 类型 block 触发"嵌套小窗"渲染，子 message 与子 blocks 在小窗内继续递归——**前端只懂一种事件流，subagent UI 自动 emerge**。

### 10.2 Service.Spawn 接入点

```go
em := eventlogpkg.From(parentCtx)
subMsgID := idgenpkg.New("msg")
msgBlockID := ""
if parentToolCallID != "" && parentMsgID != "" {
    msgBlockID = idgenpkg.New("blk")
    em.EmitBlockStart(parentCtx, msgBlockID, parentToolCallID, parentMsgID,
        eventlogdomain.BlockTypeMessage,
        map[string]any{"messageId": subMsgID, "type": typ.Name})
    em.EmitMessageStart(parentCtx, subMsgID, chatdomain.RoleAssistant, msgBlockID,
        map[string]any{"kind": "subagent_run", "type": typ.Name, "maxTurns": maxTurns})
}

// subCtx 派生：清继承的 parent_block_id（让 sub blocks 用 subMsgID 作顶层 parent）
subCtx := reqctxpkg.WithMessageID(parentCtx, subMsgID)
subCtx = reqctxpkg.WithParentBlockID(subCtx, "")
// ... loop.Run(subCtx, host, ...)

// 返后（detached stopCtx 防 parent cancel 丢 StopBlock）：
em.StopBlock(stopCtx, msgBlockID, closeStatus, nil)
```

### 10.3 subagentHost 接入点（message_stop）

`subagentHost.WriteFinalize` 内：

```go
em := eventlogpkg.From(ctx)
em.StopMessage(saveCtx, h.subMsgID, h.mapEventLogStatus(status),
    stopReason, errCode, errMsg, in, out)
```

走 detached saveCtx（同 chat/host.go 的 §S9 模式），防 parent cancel 在 SaveMessage 与 StopMessage 之间触发把前端的 sub-message 卡在 streaming。

### 10.4 §S21 invariants 在 subagent 视角

- **`block_start.parentId` 链路**：`msgBlockID` 的 parent = parent_tool_call_id（已在 chat loop emit 过）；`msg_sub` 的 parent_block_id = `msgBlockID`；sub 顶层 blocks 的 parent = `msg_sub`；sub 内部 tool_result blocks 的 parent = sub 内 tool_call 的 ID。每条都先于自身 emit 过——dangling parentId 会是 producer bug。
- **Block.status 单向流转**：sub 内 blocks 由 streamLLM / runOneTool 控制；placeholder block 由 Spawn 末尾 StopBlock 关；sub-Message 由 WriteFinalize StopMessage 关。
- **Per-conversation seq 单调**：父对话 + 嵌套 sub-run 共享同一个 conversation 的 seq——递归事件全部按全局 seq 顺序 emit，前端拿一条流回放就还原全树。

---

## 11. HTTP API

**无独立 HTTP 端点**——sub-run 数据通过 chat 标准的 `GET /api/v1/conversations/{id}/messages` 端点读出（带 `parentBlockId` + `attrs` 字段的 message 行 = sub-run）。前端按 `attrs.kind=="subagent_run"` 过滤渲染嵌套小窗。

Type 列表（Explore / Plan / general-purpose）通过 `Subagent` 工具自身的 `Description()` 暴露给 LLM，**不**单独 HTTP endpoint。

API contract → [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md)（subagent 行）。

---

## 12. 错误码（`transport/httpapi/response/errmap.go`）

| Sentinel | HTTP | Wire Code |
|---|---|---|
| `subagentdomain.ErrTypeNotFound` | 404 | `SUBAGENT_TYPE_NOT_FOUND` |
| `subagentdomain.ErrRecursionAttempt` | 422 | `SUBAGENT_RECURSION` |

**只有这 2 个 sentinel**——max_turns / cancelled / failed 是 `SpawnResult.Status` 的 string 值，由 `SubagentTool.Execute` 转友好 tool_result 注脚返主 LLM，**不**抛 handler。errmap 不收录。

---

## 13. 测试覆盖

实际测试文件：

| 层 | 文件 | 覆盖 |
|---|---|---|
| domain/subagent | （无独立 test）| sentinels 通过上层测试隐式覆盖 |
| app/subagent | `internal/app/subagent/subagent_test.go` | Registry / filterTools / composeSystemPrompt |
| app/tool/subagent | `internal/app/tool/subagent/agent_test.go` | Identity / 静态元数据 / ValidateInput / CheckPermissions / 运行时递归守卫 / Execute 状态分支 |
| pipeline | `backend/test/subagent/subagent_test.go` | 端到端 spawn（parent → SubagentTool → Service.Spawn → loop.Run → tool_result 回 parent；事件日志验证）|

**已删除测试**（schema 统一前的旧测试，文件不存在）：
- ~~`internal/infra/store/subagent/subagent_test.go`~~（无独立 store dir）
- ~~`internal/domain/events/types_test.go`~~（events 包已删）
- ~~`handlers/subagent_test.go`~~（无独立 HTTP handler）
- ~~`internal/pkg/agentstate/` subagent 测试~~（agentstate 测试转到通用 helper 测试）

---

## 14. 与其他 domain 的关系

| 关系 | 说明 |
|---|---|
| **loop** | 共享 ReAct 引擎；subagent 直接调 `loop.Run(ctx, subagentHost{...}, client, req, maxTurns)` |
| **chat** | **无直接依赖**——双方都是 loop 的调用方；subagent 反向持有 `chatdomain.Repository` 写 messages（subagent → chatdomain，chatdomain ← chat）|
| **chatdomain** | subagent 写 sub-Message 走 `chatRepo.SaveMessage / GetMessage`；sub blocks 走 chat 的 `message_blocks` 表（emitter dual-write） |
| **eventlog** | Bridge / Emitter 在 ctx 透传；sub-run 与父对话共享同一 event stream（per-conversation） |
| **reqctx** | `SubagentDepth` / `ParentBlockID` ctx key |
| **skill** | （未来）Skill 的 `context: fork` 字段调 Service.Spawn 复用 |
| **catalog** | **不实现 CatalogSource**——Subagent tool 自身 description 已覆盖 subagent 类型说明，catalog 不重复 |

### 包依赖方向（无循环 import）

```
internal/app/loop/                （通用 ReAct 引擎，不依赖任何业务 service）
        ↑                    ↑
        ├── chat 调用         ├── subagent 调用
        │                     │
internal/app/chat/      internal/app/subagent/
   (chatHost)               (subagentHost + Spawn → chatRepo)
        ↓                          ↓
        └─── 共同依赖：loop / domain/* / pkg/eventlog / pkg/notifications / 各 store
```

无 port 接口、无 DI 注入：两个 service 各自构造自己的 Host 实现，调同一个 `loop.Run` 函数。chat 不知道 subagent 存在；subagent 知道 `chatdomain.Repository`（因为要写共享表）但不知道 `app/chat`。Workflow（Phase 4）/ Skill `context: fork` 未来同样直接接 `loop.Host`。

---

## 15. 演化方向

- **跨厂 subagent 定义**：从代码内置改文件加载（`~/.forgify/subagents/<name>.md` YAML frontmatter，类似 Skill）
- **token budget 强约束**：基于 `chatRepo` 聚合 sub-Message 行（attrs.kind=subagent_run）的 InputTokens/OutputTokens 实时累计 + 用户配的对话级上限触发拒绝
- **subagent 内嵌套**：当前禁；未来如有强需求，加可配的 `MaxDepth=N`，但默认仍是 1
- **Cancel HTTP 端点**：v1 无外部 cancel API——主对话 cancel 通过 ctx 级联自然 cancel 所有 sub；5 min 总超时是兜底。未来如有"局部 cancel 某个 sibling"需求再加 HTTP + 重新引入 activeRuns 注册表

---

## 16. 关键决策与历史背景

### 16.1 schema 统一（2026-05-08）

事件日志协议落地前，subagent 走"借壳 chat.message" 模式：独立 `subagent_runs` + `subagent_messages` 两表，通过 `eventsdomain.ChatMessage` 事件加 3 个 optional 字段塞 SubagentRun 快照推前端。schema 统一后：
- 两表删除（migration SQL → [`../event-log-protocol.md`](../event-log-protocol.md) §6）
- sub-run 写 `messages` 行（attrs.kind=subagent_run），sub blocks 写 `message_blocks`
- 协议层无独立 subagent 事件——递归 emit 自动产出嵌套结构
- 旧 `sar_<16hex>` / `smm_<16hex>` ID 前缀作废；统一用 `msg_<16hex>` / `blk_<16hex>`
- `domain/events` 包随之删除

### 16.2 loop 共享而非独立 SubRunner

V1 早期设计有 `SubRunner` port 接口让 chat 与 subagent 互调；后改为 `app/loop` 抽出共享引擎，chat 与 subagent 均为 loop 的调用方，互不依赖。Host 接口从 6+ 方法（OnInitialPublish / OnStreamCheckpoint / OnStepComplete 等）简化到 3 方法（LoadHistory / Tools / WriteFinalize）——事件日志接管了所有"中间态推送"，host 仅负责终态写盘 + history 加载 + tool 列表。

### 16.3 不复制 chat 状态机（OpenCode 教训）

OpenCode 47-session 嵌套事故：subagent 内还能调 spawn，无结构性防御。Forgify 双保险：
- 物理排除（filterTools 剥 SubagentTool）
- 运行时 ctx depth 检查
两者都是 fail-safe 默认；单纯 max_depth 计数允许"depth=2 但每个 200 turns"的等效灾难，不采纳。
