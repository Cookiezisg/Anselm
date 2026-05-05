# chat domain — 详细设计文档

**所属 Phase**：Phase 2 起（每个 Phase 都会升级）
**状态**：✅ 已实现到 Phase 3（含 chat 基础设施重构 2026-04-27 + pipeline → runner 二次重构）；Phase 4-5 时再升级
**地位**：**全系统最核心的 domain**——用户的每一次对话都从这里进入，一切能力都通过这里编排。

**关联文档**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../service-contract-documents/api-design.md`](../service-contract-documents/api-design.md) — API 索引
- [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md) — 事件索引

---

## 1. 核心思想：一切都是 Tool Call

### 1.1 为什么

Forgify 的终极形态是：用户一句话，AI 自主完成"创建工具→测试→组建工作流→挂知识库→部署"的完整链路，中间多次迭代，用户实时看到每一步。

这本质上是一个**自主 Agent 循环**，而不是简单的"识别意图→路由→执行一次"。

### 1.2 是什么

从 LLM 的视角，它只有两种输出：
- **直接回复**（= 任务完成）
- **调一个 Tool**（= 还有事情要做）

所有 Forgify 的能力——创建工具、运行沙箱、搜知识库、创建工作流——对 LLM 都是 Tool。Agent 每轮只做一个决策（调哪个 Tool 或直接回复），拿到结果后再想下一步，直到认为任务完成。

这就是 **ReAct 循环**（Reasoning + Acting），和 Claude Code 的工作方式完全一致。

### 1.3 关键约束

**每个小轮次只有一次 Tool Call。** 这不是限制，这是优点：
- 每一步都可观测（实时推事件给前端）
- 每一步都可中断
- LLM 的推理链清晰可追溯
- 不会一口气做完所有事情让用户措手不及

---

## 2. 两层工具体系

这是整个设计最关键的决策。

### 2.1 问题

用户最终可能创建数百个工具。如果把所有工具都塞进 LLM context，性能严重下降，LLM 会选错工具，最重要的系统工具会被淹没。

### 2.2 解法

```
┌─────────────────────────────────────────────────────┐
│                  Agent Context                       │
│                                                      │
│  System Tools（永远在 context，~8 个）               │
│  ┌────────────┐ ┌──────────┐ ┌────────────────────┐ │
│  │ create_forge│ │ edit_forge│ │     run_forge(id)    │ │
│  └────────────┘ └──────────┘ └────────────────────┘ │
│  ┌─────────────┐ ┌──────────────────────────────┐   │
│  │ search_forges│ │  create_workflow / run_workflow│   │
│  └─────────────┘ └──────────────────────────────┘   │
│  ┌──────────────────┐ ┌──────────┐                  │
│  │ search_knowledge  │ │ mcp_call │                  │
│  └──────────────────┘ └──────────┘                  │
└─────────────────────────────────────────────────────┘

用户工具库（不在 context，通过 search_forges 发现，run_forge 执行）
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ email_parser │ │ csv_processor│ │  ...（数百个）│
└──────────────┘ └──────────────┘ └──────────────┘
```

**System Tools** 是 meta-tools：用来创建/管理其他工具和工作流。永远可见。

**User Tools** 不直接注入 context。Agent 通过：
1. `search_forges(query)` → 语义搜索工具库，得到相关工具列表
2. `run_forge(id, input)` → 通用执行器，执行任意用户工具

这本质上是 **Tool RAG**——与知识库 RAG 同一个思路，检索对象是工具描述。

### 2.3 System Tools 完整目录

| 家族 | Phase | Tool | 描述 | 对接的 domain |
|---|---|---|---|---|
| forge | 3 | `search_forge` / `get_forge` / `create_forge` / `edit_forge` / `run_forge` | 用户工具库 CRUD + 执行 | forge sandbox |
| filesystem | 5 | `Read` / `Write` / `Edit` | 文件读写编辑（PathGuard 守敏感路径，Edit 走 must-Read-first 守卫 + 原子写）| `pkg/agentstate.SeenFiles` |
| search | 5 | `Grep` / `Glob` | 内容搜索 + 文件查找（rg 优先、stdlib 兜底；Glob 输出 type/size/mtime 替代 LS）| 文件系统 |
| web | 5 | `WebFetch` / `WebSearch` | URL 抓 + 摘要（Jina + 直 GET fallback）/ 3 层 fallback 搜索（SearXNG 池 → Bing → Bing CN）| model.PickForWebSummary（chat fallback）|
| shell | 5 | `Bash` / `BashOutput` / `KillShell` | 前后台 shell（cwd 状态机走 AgentState；后台 ProcessManager 注册 256 KB 环形缓冲）| `pkg/agentstate.Cwd` |
| task | 5 | `TaskCreate` / `TaskList` / `TaskGet` / `TaskUpdate` | 对话级 to-do 列表 | task domain（mini-domain，详 task.md）|
| ask | 5 | `AskUserQuestion` | 暂停 agent loop 等用户回答 | app/ask（in-memory 会合，POST /answers）|
| workflow | 4 | `create_workflow` / `edit_workflow` / `run_workflow` | 创建/执行工作流 | workflow + flowrun（未实现）|
| knowledge | 5 | `search_knowledge` | RAG 检索知识库 | knowledge（未实现）|
| mcp | 5 | `mcp_call` | 调用 MCP 服务器方法 | mcpserver（未实现）|

**Phase 5（2026-05-04）batch**：在 forge 5 工具基础上注入 15 个新 system tool（10 fs/search/web/shell + 4 task + 1 ask）。装配点：`cmd/server/main.go::tools = append(tools, ...)` 链。**总在线 20 个 system tools**。

**Phase 2**：tools 列表为空。Agent 就是一个没有工具的 ReAct Agent，行为等同于纯 LLM 流式对话，但架构已经是可扩展的。

---

## 3. LLM 客户端层（`infra/llm`）

> **Eino 已完全移除**（2026-04-27）。chat 管线使用完全自有的 LLM 流式客户端，
> 零框架依赖，完全掌控 SSE 解析和请求构建。

### 3.1 核心组件

```
chat.Service
    ↓ 依赖
llminfra.Factory          ← 按 provider dispatch，返回 Client
    ↓ Build(Config)
llminfra.Client           ← 唯一方法：Stream(ctx, Request) iter.Seq[StreamEvent]
    ├── openAIClient      ← 覆盖 OpenAI/DeepSeek/Qwen/Moonshot/Ollama 等 OpenAI-compat
    └── anthropicClient   ← Anthropic 原生 /v1/messages 协议
```

### 3.2 核心类型（`infra/llm/llm.go`）

```go
// StreamEvent 是 LLM 流式响应中一个带类型标签的事件
type StreamEvent struct {
    Type           StreamEventType
    Delta          string   // EventText: 文字增量
    ReasoningDelta string   // EventReasoning: 推理增量（DeepSeek-R1 等）
    ToolIndex      int      // EventToolStart / EventToolDelta
    ToolID         string   // EventToolStart: LLM 分配的 tool call id
    ToolName       string   // EventToolStart
    ArgsDelta      string   // EventToolDelta: arguments 片段
    FinishReason   string   // EventFinish
    InputTokens    int      // EventFinish
    OutputTokens   int      // EventFinish
    Err            error    // EventError
}

type StreamEventType string
const (
    EventText      StreamEventType = "text"
    EventReasoning StreamEventType = "reasoning"
    EventToolStart StreamEventType = "tool_start"  // tool name 已知，立刻可推 SSE
    EventToolDelta StreamEventType = "tool_delta"  // arguments 片段
    EventFinish    StreamEventType = "finish"
    EventError     StreamEventType = "error"
)

// Client 是唯一的 LLM 流式接口
type Client interface {
    Stream(ctx context.Context, req Request) iter.Seq[StreamEvent]
}

type Request struct {
    ModelID  string
    Key      string
    BaseURL  string
    System   string
    Messages []LLMMessage
    Tools    []ToolDef
}
```

**设计关键**：
- `iter.Seq[StreamEvent]` 替代 channel：拉式迭代，无 goroutine 泄漏，break 干净退出
- `EventToolStart` 在 tool name 首次出现时立刻 emit，不等 arguments 完整（让前端尽快展示"正在调用 X…"）
- `Generate()` helper 消费 Stream 实现非流式调用，不引入独立接口

### 3.3 OpenAI 兼容客户端（`infra/llm/openai.go`）

覆盖所有 OpenAI-compat provider：openai / deepseek / qwen / moonshot / doubao / openrouter / ollama 等。

- 自写 SSE line reader（`data: {...}\n\n` 格式）
- 解析 delta chunks：`choices[0].delta.content` / `reasoning_content`（DeepSeek-R1）/ `tool_calls`
- `classifyHTTPError` 区分 401/429/400/404/5xx 返回对应 Go error
- 畸形 chunk → emit EventError，不 panic

### 3.4 Anthropic 原生客户端（`infra/llm/anthropic.go`）

使用 Anthropic 原生 `/v1/messages` 协议（SSE 格式）：
- `content_block_start` → 识别 text / tool_use block
- `content_block_delta` → 分发 EventText / EventToolDelta
- `content_block_stop` → 关闭当前 block
- tool result 消息格式与 OpenAI 不同：按 Anthropic 协议将 tool results 合并为一条 `role="user"` 消息（`content = [{type:"tool_result", tool_use_id, content}...]`）

### 3.5 Factory（`infra/llm/factory.go`）

```go
// Factory.Build 按 provider 返回对应 Client
func (f *Factory) Build(cfg Config) (Client, string, error) {
    // anthropic → anthropicClient{baseURL}
    // 其余全部 → openAIClient{baseURL}（含 ollama 等）
}
```

Provider 基础 URL 由 `resolveBaseURL` 按 provider 名称给出，调用方传入的 `BaseURL` 会覆盖默认值。

---

## 4. Tool 接口 & 标准字段注入（`app/tool/tool.go`）

完整规约见 [`CLAUDE.md §S18`](../../../CLAUDE.md)。本节只讲 chat 层视角的关键交互。

### 4.1 Tool 接口（9 方法全必填）

```go
type Tool interface {
    // Identity（3 个）
    Name() string
    Description() string
    Parameters() json.RawMessage   // JSON Schema；禁止含 "summary" / "destructive" / "execution_group"

    // 静态元数据（3 个固有属性）
    IsReadOnly() bool              // 仅文档/语义参考；不再驱动并发调度
    NeedsReadFirst() bool          // Phase 5 Edit/Write 用 + 走 AgentState.SeenFiles
    RequiresWorkspace() bool       // PathGuard 守卫开关（Phase 5）

    // 钩子（args-dependent，2 个）
    ValidateInput(args json.RawMessage) error
    CheckPermissions(args json.RawMessage, mode PermissionMode) PermissionResult

    // 主入口（args 已剥除 summary / destructive / execution_group）
    Execute(ctx context.Context, argsJSON string) (string, error)
}
```

> **Phase 5（2026-05-04）框架重构**：删了 `IsConcurrencySafe(args) bool`（10→9 方法），并发分派改由 LLM 自报的 `execution_group` 标准字段驱动（详 §4.5 + CLAUDE.md §S18）。

### 4.2 标准字段注入机制（summary + destructive + execution_group）

```
ToLLMDef(tool)
  → injectStandardFields(tool.Parameters())
    → properties 加 "summary"（必填 string）/ "destructive"（可选 bool 默认 false）
                  / "execution_group"（可选 int ≥1）
    → required 把 "summary" 插到第一位
  → 返回发给 LLM 的 ToolDef（含三个标准字段）

runOneTool(ctx, t, tc)
  → ChatToolCall SSE 推（含 destructive 字段，UI 据此显示警示徽章）
  → t.ValidateInput(args) — 失败转失败 tool_result
  → t.CheckPermissions(args, PermissionModeDefault) — Deny 转失败；Ask 当前阶段当 Allow
  → t.Execute(ctx, argsJSON) — 此时 args 已剥除三个标准字段

parseToolArgs(rawArgs)
  → toolapp.StripStandardFields(rawArgs)
    → (StandardFields{Summary, Destructive, ExecutionGroup}, stripped)
  → 填进 ToolCallData 的三个一等字段；剩余 args 作为 Arguments map
```

**destructive 设计**：per-call AI 自报，比静态 IsDestructive() 精准（同一 tool 不同 args 可不同）。存进 `ToolCallData.Destructive` 一等字段 + ChatToolCall SSE，前端实时显示警示徽章。详见 progress-record.md Phase 3 决策。

**execution_group 设计**：LLM 自报的并行 batch 提示（≥1）。partition 层用它取代旧 `IsConcurrencySafe`：同 group 并行、不同 group 升序串行；缺失（≤0）的 call 自动分配 ≥1000 的唯一 group（fail-safe 默认 = 独自串行，排在所有显式 group 之后）。详见 §4.5。

### 4.3 Context Helpers（已搬到 `pkg/reqctx/agentrun.go`）

agent-run 标识符 helpers 不再属于 tool 包，统一归 `pkg/reqctx`（与 user 身份 / locale 同包）：

```go
// pkg/reqctx/agentrun.go
func WithConversationID(ctx, id) context.Context
func GetConversationID(ctx) (string, bool)
func WithMessageID(ctx, id) context.Context
func GetMessageID(ctx) (string, bool)
func WithToolCallID(ctx, id) context.Context
func GetToolCallID(ctx) (string, bool)
```

`chat/runner.go` 在 agent 循环开始注入 conversationID；`chat/tools.go::runOneTool` 在 Execute 前注入 messageID / toolCallID；`tool/forge/` 内 streamCode / CreateForge / EditForge 读取并填充 SSE 事件字段。

**Phase 5 新增**：runner 还在 ctx 注入每对话独立的 `*agentstatepkg.AgentState`（`reqctxpkg.WithAgentState`），由 filesystem (Read/Write/Edit) 读 SeenFiles 做 must-Read-first 守卫，由 shell (Bash) 读 Cwd 做 cd 状态机；queue idle 时与 conversation 一起 GC。详 [`task.md §10`](task.md) 与 `pkg/agentstate/agentstate.go` 包 doc。

### 4.4 System Tools 完整目录

5 个 forge tool 在 `app/tool/forge/` 子包（每文件一 tool，Phase 3 后优化轮重组）。Phase 0 删了 8 个旧通用 system tool；**Phase 5（2026-05-04）重建并扩展为 15 个新工具**：Read/Write/Edit + Grep/Glob + WebFetch/WebSearch + Bash/BashOutput/KillShell + TaskCreate/TaskList/TaskGet/TaskUpdate + AskUserQuestion。当前在线 **20 个** system tools。详细家族表见 §2.3。

| Tool | 实现文件 | Phase | 描述 |
|---|---|---|---|
| `search_forges` | tool/forge/search.go | 3+ | LLM 排序 forge 库 |
| `get_forge` | tool/forge/get.go | 3+ | 获取 forge 完整代码 |
| `create_forge` | tool/forge/create.go | 3+ | LLM 生成代码 + AST dry-run + 保存 |
| `edit_forge` | tool/forge/edit.go | 3+ | LLM 改写代码 + AST dry-run + 创建 pending（含元数据-only 路径推 forge.metadata_updated）|
| `run_forge` | tool/forge/run.go | 3+ | 运行 forge（sandbox + 50KB 输出截断）|
| `Read` | tool/filesystem/read.go | 5 | cat -n 行号格式读文本，2000 行默认 + offset/limit；标 SeenFiles 让 Edit/Write 通过 must-Read-first 守卫 |
| `Write` | tool/filesystem/write.go | 5 | 原子写（CreateTemp + Rename）；覆写需 must-Read-first；保留原 mode |
| `Edit` | tool/filesystem/edit.go | 5 | 字面量字符串替换（非 regex）；唯一性守卫 + replace_all；外部修改 size 检测 |
| `Grep` | tool/search/grep.go | 5 | rg 优先 + stdlib bufio+regexp 兜底；3 输出模式 + multiline + head_limit |
| `Glob` | tool/search/glob.go | 5 | doublestar 匹配 + 按 mtime 降序 + JSON(type/size/mtime)；pattern `*` 即 LS 替代（决策 D3）|
| `WebFetch` | tool/web/fetch.go | 5 | Jina r.jina.ai → 直 GET fallback；SSRF 守卫（loopback/私网/link-local + 重定向逐跳校验）；用 web_summary 模型场景摘要 |
| `WebSearch` | tool/web/search.go | 5 | 3 层 fallback（SearXNG 池随机洗牌 → Bing → Bing CN）；HTML visitor 解析（非 regex）|
| `Bash` | tool/shell/bash.go | 5 | 前/后台双模式；`cd <path>` 整命令短路更新 AgentState.Cwd；前台 timeout 默认 120s 上限 600s；输出截 256 KB |
| `BashOutput` | tool/shell/output.go | 5 | 轮询后台 shell 新增字节（环形缓冲读游标）+ 可选 regex filter + 状态尾注 |
| `KillShell` | tool/shell/kill.go | 5 | SIGKILL 幂等；从 ProcessManager 注册表删条目 |
| `TaskCreate` / `TaskList` / `TaskGet` / `TaskUpdate` | tool/task/{create,list,get,update}.go | 5 | 对话级 to-do（详 task.md）|
| `AskUserQuestion` | tool/ask/ask.go | 5 | 阻塞 5 分钟等用户答案；问题坐 chat.message tool_call block；答案走 POST /answers |

**Phase 5（2026-05-04）batch 设计要点**：
- **不实现独立 LS tool**——Glob 用 `pattern: "*"` 替代，决策 D3 见 `02-tools-deep/02-search.md`
- **Bash 故意不走 PathGuard**（`RequiresWorkspace=false`）——本地单用户场景下 Bash 是用户日常命令的代理，banned-list 没意义；详 `02-tools-deep/03-shell.md` 决策 D5
- **filesystem/search/web/shell 工具不向 errmap 注册**——失败以友好字符串返 LLM（吃在 tool_result 里），不到 handler。task / ask 例外因为有独立 HTTP endpoint（仅 ask `POST /answers`）

---

## 5. Pipeline 架构（`app/chat/`）

### 5.1 文件结构（6 文件）

```
app/chat/
  chat.go     ← 公开 API（Send / Cancel / ListMessages / UploadAttachment）+ Service struct + queue 管理常量
  runner.go   ← getOrCreateQueue / runQueue / processTask / agentRun（ReAct loop）/ writeAndPublish / publishMessageSnapshot / emitFatalError / stampBlocks / autoTitle
  stream.go   ← streamLLM（iter.Seq 驱动）+ assembleBlocks + extractToolCalls + parseToolArgs
  tools.go    ← runTools（并行）+ runOneTool + executeTool
  history.go  ← buildHistory + extendHistory + blocksToLLM + blocksToAssistantLLM + buildUserLLMMessage + attachmentToPart
  util.go     ← ID 生成器（newMsgID / newBlockID / newAttachmentID）+ readAndEncode + truncate
```

> 2026-04-27 重构后从 `app/chat/chat.go` 单文件拆为 5 文件；2026-04-27 后又把原 `pipeline.go` 替换为 `runner.go`（concept compaction 预留）。Phase 6（2026-05-02）entity-state 重构：原 `writeDB(fatal)` 改名 `writeAndPublish(fatal)` 并合一了"落库 + 推 chat.message"职责；额外加 `publishMessageSnapshot`（仅推不落）和 `emitFatalError`（pre-LLM 错误 stub message）两个 helper。runner.go 是 chat.message 唯一发布事实源。

### 5.2 ReAct Loop（`agentRun`，runner.go）

```
Send(userMsg) → 保存 user message → 入队 queuedTask{userMsgID}
  ↓ worker goroutine
processTask
  → modelPicker.PickForChat → keyProvider.ResolveCredentials → llmFactory.Build
  → 组装 baseReq（System / Tools 注入）
  → agentRun(ctx, uid, conv, userMsgID, client, baseReq)
      → buildHistory(ctx, convID, userMsgID)     // 加载历史，userMsgID 末尾追加
      → for step < maxSteps (=20):
          aBlocks, toolCalls, stopReason, iT, oT = streamLLM(ctx, client, req, convID, msgID)
          allBlocks = append(allBlocks, aBlocks...)
          totalInput += iT; totalOutput += oT

          if stopReason == cancelled / error:
              writeAndPublish(allBlocks, status=cancelled|error, fatal=true) → break

          if len(toolCalls) == 0:
              writeAndPublish(allBlocks, status=completed, stopReason, fatal=true) → break  // 最终答案

          rBlocks = runTools(ctx, toolCalls, convID, msgID, uid, allBlocks)
              // partitionByExecutionGroup 按 LLM 自报 group 分批；每个 tool 跑完推 chat.message
          allBlocks = append(allBlocks, rBlocks...)
          writeAndPublish(allBlocks, status=streaming, fatal=false)   // checkpoint，buildHistory 会跳过
          history = extendHistory(history, aBlocks, rBlocks)  // 把本步的 assistant + tool result 拼回历史
          // TODO: context compaction 钩子点

      if !finalWritten:                                       // 步骤上限
          writeAndPublish(allBlocks, status=completed, stopReason=max_tokens, fatal=true)

      // 终态本身就是最后一帧 chat.message（writeAndPublish 内部推快照），无 ChatDone 独立事件
      if conv.Title == "" && !conv.AutoTitled:
          go autoTitle(...)
```

**关键设计**：
- **allBlocks 累积**：所有步骤的 blocks 全部累积进一个 slice，最终一次性写入同一条 assistant 消息。一次用户发言对应一条完整的 DB 记录，工具调用链不丢失。
- **中间步 streaming checkpoint**：中间步用 `writeAndPublish(fatal=false)` 写 `status=streaming` + 推快照，`buildHistory` 跳过 streaming/pending 状态的消息，避免把未完成的步骤放进历史重建。失败只 warn，最终写会覆盖。
- **`fatal=true` 走 detached context**：终态写用 `reqctxpkg.SetUserID(context.Background(), uid)` 创建全新 context，不受取消影响，保证终态必然落库 + 最后一帧 chat.message 必然推达。

### 5.3 streamLLM（`stream.go`）

每个流事件到达时**重建当前 Message 快照**并推 `chat.message` 一帧（Phase 6 entity-state 模型；不再有 ChatToolCallStart / ChatToken / ChatReasoningToken / ChatDone 等独立事件）。

```go
// iter.Seq 拉式迭代：只要 for range 不 break，就一直消费
publish := func() {
    current := assembleBlocks(textBuf.String(), reasonBuf.String(), accums)
    s.publishMessageSnapshot(ctx, msgID, convID, uid,
        joinBlocks(parentBlocks, current),
        chatdomain.StatusStreaming, "", "", "",
        inputTokens, outputTokens)
}

for event := range client.Stream(ctx, req) {
    switch event.Type {
    case llminfra.EventText:
        textBuf.WriteString(event.Delta);     publish()
    case llminfra.EventReasoning:
        reasonBuf.WriteString(event.Delta);   publish()
    case llminfra.EventToolStart:
        accums[event.ToolIndex] = &toolAccum{id: event.ToolID, name: event.ToolName}
        publish()
    case llminfra.EventToolDelta:
        accums[event.ToolIndex].args.WriteString(event.ArgsDelta);   publish()
    case llminfra.EventFinish:
        if event.FinishReason == "length" { stopReason = StopReasonMaxTokens }
        inputTokens, outputTokens = event.InputTokens, event.OutputTokens
    case llminfra.EventError:
        if ctx.Err() != nil { stopReason = StopReasonCancelled } else {
            stopReason = StopReasonError; errMsg = event.Err.Error()
        }
    }
}
return assembleBlocks(...), extractToolCalls(blocks), stopReason, errMsg, inputTokens, outputTokens
```

`assembleBlocks` 把 buffers 组装为 blocks：顺序为 reasoning → text → tool_call blocks（按 ToolIndex 排）。`extractToolCalls` 从 blocks 抽出 tool_call 列表交给 runTools。`parseToolArgs` 通过 `toolapp.StripStandardFields` 剥三个标准字段（summary / destructive / execution_group）+ JSON 损坏兜底 `args["raw"]`。

### 5.4 Tool Call 分批执行（`tools.go`）

Phase 5（2026-05-04）框架重构：从"按 `IsConcurrencySafe(args)` 反推"改成 **按 LLM 自报的 `execution_group` 字段分批**——LLM 自己给每个 tool call 标 group 号，框架按 group 升序顺序执行，同 group 并行。`IsConcurrencySafe` 方法已从 Tool 接口删除（10→9 方法），tool 不再参与并发判断。

**分批语义**（`partitionByExecutionGroup`，详 CLAUDE.md §S18）：
- 同 group 号的 calls = 并行 batch（LLM 担保它们之间无依赖、无共享可变状态）
- 不同 group 号 = 升序串行（前 group 全跑完才进下 group）
- 缺省 / ≤0 = 自动分配唯一 group ≥1000，每个独自串行 batch，**排在所有显式 group 之后**——fail-safe 默认（LLM 不主动声明并行就不并行）

```go
func (s *Service) runTools(ctx, calls, convID, msgID, uid string,
    parentBlocks []chatdomain.Block) []chatdomain.Block {
    byName := s.toolsByName()
    batches := partitionByExecutionGroup(calls)
    blocks := make([]chatdomain.Block, len(calls))

    var mu sync.Mutex
    publishProgress := func() { /* 拼 parentBlocks + blocks 推 chat.message 快照 */ }

    for _, b := range batches {
        if len(b.items) > 1 {
            // 并行 batch（同 execution_group）
            var wg sync.WaitGroup
            for _, item := range b.items {
                wg.Add(1)
                go func(it indexedCall) {
                    defer wg.Done()
                    blk := s.runOneTool(ctx, byName[it.tc.Name], it.tc, msgID, it.idx)
                    mu.Lock(); blocks[it.idx] = blk; mu.Unlock()
                    publishProgress()
                }(item)
            }
            wg.Wait()
        } else {
            // 单项 batch（自动分配 group 或显式单 call group）—— 内联跑省 goroutine
            item := b.items[0]
            blk := s.runOneTool(ctx, byName[item.tc.Name], item.tc, msgID, item.idx)
            mu.Lock(); blocks[item.idx] = blk; mu.Unlock()
            publishProgress()
        }
    }
    return blocks
}
```

**例**：LLM 同 turn 发 `[A:1, B:1, C:0, D:2, E:0]`
→ 自动分配后 `[A:1, B:1, C:1000, D:2, E:1001]`（maxExplicit=2，autoBase=max(3, 1000)=1000）
→ 排序 `[1, 2, 1000, 1001]`
→ 4 个 batches: `[A, B 并行] [D 单跑] [C 单跑] [E 单跑]`

`runOneTool` 在调 `executeTool` 前注入 `reqctxpkg.WithMessageID` / `WithToolCallID` 到 ctx。`executeTool` 跑 **`ValidateInput → CheckPermissions(default) → Execute`** 三步钩子链：Validate 失败 / Permission Deny 直接转失败 tool_result，不进 Execute。每个 tool 跑完通过 mutex 守护后推一次 `chat.message` 快照（parentBlocks + 当前已收集 tool_result blocks）。

### 5.5 writeAndPublish 与取消安全

`runner.go` 现有三个发布 helper（chat.message 唯一发布事实源；stream.go / tools.go 通过 closure 调它们）：

| Helper | 用途 |
|---|---|
| `publishMessageSnapshot` | 仅推 SSE，不落库（流式中间状态） |
| `writeAndPublish(..., fatal bool)` | 落库 + 推 SSE。fatal=true 是终态、false 是 streaming checkpoint |
| `emitFatalError(code, message)` | 写 stub error message + 推 SSE（pre-LLM 错误如 MODEL_NOT_CONFIGURED 走这里） |

```go
func (s *Service) writeAndPublish(
    ctx context.Context, msgID, convID, uid string, blocks []chatdomain.Block,
    status, stopReason, errorCode, errorMessage string,
    inputTokens, outputTokens int, fatal bool,
) {
    saveCtx := ctx
    if fatal {
        // Fresh context: 已取消的流不能阻止终态写入
        saveCtx = reqctxpkg.SetUserID(context.Background(), uid)
    }
    msg := buildMessage(msgID, convID, uid, blocks, status, stopReason, errorCode, errorMessage, ...)
    if err := s.repo.Save(saveCtx, msg); err != nil {
        if fatal {
            log.Error("CRITICAL: final assistant message persist failed — message lost")
            // 持久化失败本身覆盖为新的 error 状态，前端仍能看到
            msg = buildMessage(msgID, convID, uid, blocks,
                StatusError, StopReasonError, "INTERNAL_ERROR", "failed to save assistant message", ...)
        } else {
            log.Warn("streaming checkpoint persist failed, continuing")
        }
    }
    s.bridge.Publish(ctx, convID, eventsdomain.ChatMessage{Message: msg})
}
```

取消流程：Cancel() → context cancelled → streamLLM break → agentRun 返回已有 blocks → `writeAndPublish(status=cancelled, fatal=true)`，终态必然落库 + 最后一帧 chat.message 推给前端。

---

## 6. 消息存储（Block 模型）

### 6.1 messages 表（精简为纯元数据；Phase 5 加错误信息字段）

```go
type Message struct {
    ID             string         `gorm:"primaryKey;type:text" json:"id"`
    ConversationID string         `gorm:"not null;index;type:text" json:"conversationId"`
    UserID         string         `gorm:"not null;type:text" json:"-"`
    Role           string         `gorm:"not null;type:text" json:"role"`            // user | assistant
    Status         string         `gorm:"not null;type:text" json:"status"`
    StopReason     string         `gorm:"type:text;default:''" json:"stopReason,omitempty"`
    ErrorCode      string         `gorm:"type:text;default:''" json:"errorCode,omitempty"`    // status="error" 时填
    ErrorMessage   string         `gorm:"type:text;default:''" json:"errorMessage,omitempty"` // status="error" 时填
    InputTokens    int            `gorm:"default:0" json:"inputTokens,omitempty"`
    OutputTokens   int            `gorm:"default:0" json:"outputTokens,omitempty"`
    CreatedAt      time.Time      `json:"createdAt"`
    UpdatedAt      time.Time      `json:"updatedAt"`                                 // GORM 自动维护
    DeletedAt      gorm.DeletedAt `gorm:"index" json:"-"`

    Blocks         []Block        `gorm:"-" json:"blocks"`  // 查询时填充，不存这列
}
```

**已移除**：`Content`、`ReasoningContent`、`ToolCalls`、`ToolCallID`、`AttachmentIDs`、`TokenUsage`（全部转为 `message_blocks`）。

**Phase 5 新增字段**：
- `ErrorCode` / `ErrorMessage` — 仅 `status="error"` 时填，承载结构化失败原因。前端从 SSE `chat.message` 事件读取，无需另行解析 trailing tool_result block。值见 `error-codes.md` chat 域 "Message.errorCode 字段值" 表（`MODEL_NOT_CONFIGURED` / `LLM_STREAM_ERROR` / `HISTORY_EXTEND_FAILED` / `INTERNAL_ERROR` 等）。
- `UpdatedAt` — GORM 自动维护，每次 message 状态变化（streaming → completed / error）都会更新。

**Role 值**：`user` | `assistant`（`tool` 角色已移除，tool result 变为 assistant 消息内的 block）。

**Status 常量**：`pending` | `streaming` | `completed` | `error` | `cancelled`

**StopReason**：`end_turn` | `max_tokens` | `cancelled` | `error`

### 6.2 message_blocks 表（新增，存所有内容）

```go
type Block struct {
    ID        string    `gorm:"primaryKey;type:text" json:"id"`   // blk_<16hex>
    MessageID string    `gorm:"not null;index;type:text" json:"-"`
    Seq       int       `gorm:"not null" json:"seq"`               // 消息内排序
    Type      BlockType `gorm:"not null;type:text" json:"type"`
    Data      string    `gorm:"not null;type:text" json:"data"`    // JSON，结构随 type
    CreatedAt time.Time `json:"createdAt"`
}
```

**Block 类型 & data 结构**：

| Type | data JSON 结构 | 说明 |
|---|---|---|
| `text` | `{"text":"..."}` | 普通文字（user 输入或 assistant 回复）|
| `reasoning` | `{"text":"..."}` | 推理型模型的 thinking 内容 |
| `tool_call` | `{"id":"call_xxx","name":"datetime","summary":"获取时间","destructive":false,"arguments":{...}}` | LLM 决定调用某工具；`destructive` 由 LLM 自报 |
| `tool_result` | `{"toolCallId":"call_xxx","ok":true,"result":"...","errorMsg":"...","elapsedMs":42}` | 工具执行结果；Phase 5 新增 `errorMsg`（仅 `ok=false` 时填，结构化错误原因）+ `elapsedMs`（wall time）|
| `attachment_ref` | `{"attachmentId":"att_xxx","fileName":"report.pdf","mimeType":"application/pdf"}` | 附件引用 |

### 6.3 chatstore.Save 的 ON CONFLICT 保护

```go
// infra/store/chat/chat.go
tx.Clauses(clause.OnConflict{
    Columns:   []clause.Column{{Name: "id"}},
    DoUpdates: clause.AssignmentColumns([]string{
        "status", "stop_reason", "input_tokens", "output_tokens",
    }),
}).Create(m)
```

`created_at` **不在** DoUpdates 列表里，保证首次 INSERT 写入的时间戳在后续 status 更新时不被覆盖。这解决了 GORM `Save()` upsert 会把零值 `created_at` 写回 DB 的问题。

### 6.4 attachments 表（Phase 5 重命名 + 加软删）

```go
type Attachment struct {
    ID          string         `gorm:"primaryKey;type:text" json:"id"`       // att_<16hex>
    UserID      string         `gorm:"not null;index;type:text" json:"-"`
    FileName    string         `gorm:"not null;type:text" json:"fileName"`
    MimeType    string         `gorm:"not null;type:text" json:"mimeType"`
    SizeBytes   int64          `gorm:"not null" json:"sizeBytes"`
    StoragePath string         `gorm:"not null;type:text" json:"-"`  // 不对外暴露
    CreatedAt   time.Time      `json:"createdAt"`
    UpdatedAt   time.Time      `json:"updatedAt"`
    DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`               // Phase 5 加软删
}
```

文件存 `{dataDir}/attachments/{att_id}/original.{ext}`，50MB 限制。
**Phase 5 重命名**：表名从 `chat_attachments` 改为 `attachments`，并加 `UpdatedAt` + `DeletedAt`（软删）。理由：用户删附件后旧对话仍持有 `attachment_ref` block，软删保留行让解引用不变 dangling reference。

### 6.5 历史重建（`history.go`）

#### buildHistory

```go
func (s *Service) buildHistory(ctx, convID, currentUserMsgID string) ([]llminfra.LLMMessage, error)
```

扫描所有非 streaming/pending 消息，跳过 `currentUserMsgID`，末尾显式追加当前用户消息。

**为什么要追加末尾**：同一对话快速连发两条消息时，第二条 user 消息的 `created_at` 可能早于第一条 assistant 回复（队列中并发写入），导致历史排序错乱，LLM 看到 `[user1, user2(current), assistant1]` 末尾是 assistant、无法确定回复对象。

#### extendHistory

```go
func extendHistory(history, aBlocks, rBlocks) ([]llminfra.LLMMessage, error)
```

ReAct 循环每步结束后被 `agentRun` 调一次，把本步的 assistant blocks（含 tool_call）+ tool_result blocks 转为 LLM wire 格式追加到 history，供下一步 LLM 读取。**这是 ReAct 多步对话的核心机制**——LLM 看到自己上一步调了什么、得到什么结果，才能决定下一步。

#### blocksToAssistantLLM / blocksToLLM

把一条 assistant 消息的 blocks 转为 OpenAI wire 格式：

```
[assistant{content, toolCalls, reasoningContent}] + [N × role=tool messages]
```

tool_call blocks → `assistant.ToolCalls[]`；tool_result blocks → 独立的 `role="tool"` 消息（OpenAI 协议要求）。`buildHistory` 加载历史时调用，`extendHistory` 中间步插历史时也调用——同一份转换逻辑统一在 `blocksToAssistantLLM`，避免重复实现漂移。

---

## 7. 附件与多模态支持

### 7.1 上传流程

```
POST /api/v1/attachments (multipart/form-data)
→ 写到 {dataDir}/attachments/{att_id}/original.{ext}
→ 201 { id, fileName, mimeType, sizeBytes }
```

### 7.2 内容提取（`infra/chat/extractor.go`）

`chatinfra.Extract(storagePath, mimeType)` 按 MIME 类型分派：

| 格式 | 实现 |
|---|---|
| `text/*` / `.go` / `.py` / `.json` / `.csv` 等 | `os.ReadFile` |
| `application/pdf` | `dslipak/pdf`（纯 Go）|
| `.docx` / `.odt` / `.rtf` | `lu4p/cat`（纯 Go）|
| `.xlsx` / `.xlsm` | `xuri/excelize`（纯 Go）|
| `.pptx` | stdlib zip + XML 解析 |
| `text/html` | HTML 标签剥离 |
| `image/*` | `IsImage()` → base64 Vision 路径 |

### 7.3 LLM 消息组装

```
图片附件
  → buildUserLLMMessage → attachmentToPart
      → readAndEncode(storagePath) → base64
      → ContentPart{type:"image_url", imageURL:"data:<mime>;base64,..."}

文本附件（提取成功）
  → ContentPart{type:"text", text:"[附件: report.pdf]\n{提取内容}"}

提取失败
  → 软失败：log.Warn + 跳过，其余 parts 正常发送

多 parts → msg.Parts = parts（OpenAI array content 格式）
单 text → msg.Content = text（简化格式，不用 array）
```

---

## 8. SSE 事件（Phase 6 重构 · entity-state 模型）

chat domain 现只用 **1 个 SSE 事件 `chat.message`**——载荷 = 完整 Message 实体（含所有 blocks 当前状态、status、stopReason、errorCode/errorMessage、token 计数、updatedAt）的 GET 形状。详见 [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md)。

### 8.1 传输机制

```
前端                                  后端
 │                                     │
 ├──GET /api/v1/events?convId=──────→  │  长连接，Bridge 订阅
 │                                     │
 ├──POST /conversations/{id}/messages→ │  202（异步），入队
 │                                     │  ↓ worker goroutine
 │←── event: chat.message ───────────  │  message slot 创建（status=streaming, blocks=[]）
 │←── event: chat.message ───────────  │  每个 LLM token（text/reasoning block 内容生长）
 │←── event: chat.message ───────────  │  tool call 出现（tool_call block 仅有 name）
 │←── event: chat.message ───────────  │  tool args 完整
 │←── event: chat.message ───────────  │  每个 tool result 完成（tool_result block 加入）
 │←── event: chat.message ───────────  │  最终（status=completed/error/cancelled）
```

Keep-alive ping：每 15 秒推 `: keep-alive\n\n` 防代理断连。

### 8.2 Event struct

```go
type ChatMessage struct {
    *chatdomain.Message
    // ── 以下三字段仅 subagent 上下文携带；主对话消息全部 omitempty ──
    SubagentRunID        string                       `json:"subagentRunId,omitempty"`
    ParentConversationID string                       `json:"parentConversationId,omitempty"`  // subagent 消息的主对话 ID
    SubagentRun          *subagentdomain.SubagentRun  `json:"subagentRun,omitempty"`            // 完整 run 快照
}

func (ChatMessage) EventName() string { return "chat.message" }

// MarshalJSON 委托给嵌入的 Message + 注入 subagent 字段（仅当存在时）。
// 主对话消息 wire shape 严格 = GET /api/v1/conversations/{id}/messages 单条（向后兼容）。
func (e ChatMessage) MarshalJSON() ([]byte, error) {
    if e.Message == nil { return []byte("null"), nil }
    base, err := json.Marshal(e.Message)
    if err != nil { return nil, err }
    // 主对话消息直接返
    if e.SubagentRunID == "" { return base, nil }
    // subagent 消息：注入 3 个 subagent 字段
    var m map[string]any
    json.Unmarshal(base, &m)
    m["subagentRunId"] = e.SubagentRunID
    m["parentConversationId"] = e.ParentConversationID
    if e.SubagentRun != nil {
        m["subagentRun"] = e.SubagentRun
    }
    return json.Marshal(m)
}
```

**字段语义**：
- 三字段全 omitempty → **主对话消息**（前端渲染到主对话区）
- 三字段全携带 → **subagent 消息**（前端按 subagentRunId 分流到流式小窗，并用 subagentRun 子对象渲染 lifecycle 状态条）

主对话 wire format **完全向后兼容**——已有前端代码不感知这三个字段，新前端按 `subagentRunId` truthy 检查决定分流。详见 [`./subagent.md`](./subagent.md) §10。

### 8.3 一条流承载两层信息

subagent 上下文的 chat.message 事件**同时承载 2 个 entity 快照**：
1. `Message` 本体（流式生长的对话消息）
2. `SubagentRun`（嵌套于 `subagentRun` 字段，run 级元数据：token 累计 / status / lastTool / 等）

每次推都带**最新版的两者**——前端拿一个事件就把"小窗的当前文字"和"小窗的状态条"同步刷新，**不会有对齐 lag**。**不再有独立的 `subagent` SSE 事件类型**——所有 subagent 信息都在这条流里。

### 8.3 触发点（chat 层是唯一发布事实源）

`runner.go` 三个 helper 是唯一发布入口；`stream.go` 与 `tools.go` 通过 closure 调它们，从不自己 `bridge.Publish`：

| Helper | 用途 |
|---|---|
| `publishMessageSnapshot` | 仅推 SSE，不写库（流式中间状态）|
| `writeAndPublish` | 写库（fatal=true 是终态、false 是 streaming checkpoint）+ 推 SSE |
| `emitFatalError` | 写 stub error message + 推 SSE（pre-LLM 错误如 MODEL_NOT_CONFIGURED 走这里）|

**触发场景**：
- agentRun 起始 — `publishMessageSnapshot(status=streaming, blocks=nil)` 打开前端 assistant slot
- streamLLM 内每个 EventText / EventReasoning / EventToolStart / EventToolDelta — 重建 blocks 并 publish
- runTools 内每个 tool 完成（mutex 守护并行批次）— publish 含新 tool_result block
- 每步 ReAct checkpoint — `writeAndPublish(streaming, fatal=false)`
- 终态（completed / cancelled / error）— `writeAndPublish(..., fatal=true)`
- pre-LLM 失败 — `emitFatalError(code, message)`

### 8.4 旧事件 → 字段对照（Phase 6 之前 12 个事件信息全在新 Message 里）

| 旧事件 | 现等价 |
|---|---|
| `chat.token` / `chat.reasoning_token` | text/reasoning block 内容生长 |
| `chat.tool_call_start` | tool_call block 出现（仅 name）|
| `chat.tool_call` | tool_call block 的 arguments / summary / destructive 填齐 |
| `chat.tool_result` | tool_result block 加入（含 ok / result / errorMsg / elapsedMs）|
| `chat.done` | message.status="completed" + stopReason + inputTokens + outputTokens |
| `chat.error` | message.status="error" + errorCode + errorMessage |
| `conversation.title_updated` | 走 `conversation` 事件（载荷 = 完整 Conversation 实体）|

---

## 9. HTTP API

### 9.1 端点

| Method | Path | 用途 | 状态码 |
|---|---|---|---|
| `POST` | `/api/v1/attachments` | 上传附件（multipart）| 201 |
| `POST` | `/api/v1/conversations/{id}/messages` | 发送消息，触发 Agent | 202 |
| `DELETE` | `/api/v1/conversations/{id}/stream` | 取消正在运行的 Agent | 204 |
| `GET` | `/api/v1/conversations/{id}/messages` | 消息历史（cursor 分页，含 blocks）| 200 |
| `GET` | `/api/v1/events` | SSE 事件流（`?conversationId=xxx`）| 200 |

### 9.2 GET /conversations/{id}/messages 响应格式

```json
{
  "data": [
    {
      "id": "msg_xxx", "role": "user", "status": "completed",
      "createdAt": "...",
      "blocks": [
        {"id":"blk_1","seq":0,"type":"text","data":"{\"text\":\"帮我...\"}", "createdAt":"..."},
        {"id":"blk_2","seq":1,"type":"attachment_ref","data":"{\"attachmentId\":\"att_xxx\",...}", "createdAt":"..."}
      ]
    },
    {
      "id": "msg_yyy", "role": "assistant", "status": "completed",
      "stopReason": "end_turn", "inputTokens": 1024, "outputTokens": 256,
      "createdAt": "...",
      "blocks": [
        {"id":"blk_3","seq":0,"type":"tool_call","data":"{\"id\":\"call_1\",\"name\":\"datetime\",...}","createdAt":"..."},
        {"id":"blk_4","seq":1,"type":"tool_result","data":"{\"toolCallId\":\"call_1\",\"ok\":true,\"result\":\"...\"}","createdAt":"..."},
        {"id":"blk_5","seq":2,"type":"text","data":"{\"text\":\"当前时间是…\"}","createdAt":"..."}
      ]
    }
  ],
  "nextCursor": "...",
  "hasMore": false
}
```

### 9.3 POST /conversations/{id}/messages

```json
{ "content": "帮我做一个处理 CSV 的工具", "attachmentIds": ["att_xxx"] }
```

→ 202 `{ "data": { "messageId": "msg_xxx" } }`（user 消息 ID，非 assistant）

**错误**：404 `CONVERSATION_NOT_FOUND` / 409 `STREAM_IN_PROGRESS` / pre-LLM 失败（API_KEY_PROVIDER_NOT_FOUND / MODEL_NOT_CONFIGURED / LLM_PROVIDER_ERROR）经 `emitFatalError` 推 `chat.message`（status=error + errorCode/errorMessage）

---

## 10. Service 设计

### 10.1 Struct

```go
// app/chat/chat.go
type Service struct {
    repo        chatdomain.Repository    // messages + blocks + attachments
    convRepo    convdomain.Repository    // 对话 CRUD
    modelPicker modeldomain.ModelPicker  // 拿 (provider, modelID)
    keyProvider apikeydomain.KeyProvider // 拿 (key, baseURL)
    llmFactory  *llminfra.Factory        // 自有 LLM 流式客户端工厂
    tools       []toolapp.Tool           // System Tools（实现 Tool 接口；SetTools 注入）
    bridge      eventsdomain.Bridge      // 推 SSE 事件
    dataDir     string                   // 附件存储根目录
    log         *zap.Logger
    queues      sync.Map                 // conversationID → *convQueue
}
```

### 10.2 Send 流程

```
HTTP 入口（同步部分）:
  1. convRepo.Get(conversationID)            → 验证对话存在
  2. buildUserBlocks(ctx, in)                → 从 DB 查附件完整元数据构建 user blocks
  3. repo.Save(userMsg with blocks)          → DB（user message）
  4. getOrCreateQueue(conversationID)        → 入队 queuedTask{userMsgID}
  5. 立刻返回 202 { messageId: userMsgID }

worker goroutine（runner.go::processTask）:
  6. llmclient.Resolve(ctx, picker, keys, factory) → bundle{ModelID, Key, BaseURL, Client}
       失败 → emitFatalError 推 chat.message stub（status=error, errorCode=
       MODEL_NOT_CONFIGURED / API_KEY_PROVIDER_NOT_FOUND / LLM_PROVIDER_ERROR）
  7. agentRun(ctx, uid, conv, userMsgID, msgID, client, baseReq)
       publishMessageSnapshot(streaming, blocks=nil)  // 打开 assistant slot
       buildHistory → for-step ReAct → writeAndPublish checkpoints + 终态

  8. 触发 auto-title goroutine（conv.Title 为空且 !AutoTitled）
```

### 10.3 并发控制与取消

每个 conversationID 拥有一个 `convQueue`（buffered channel cap=5 + 单 worker goroutine），保证同对话消息按序逐条执行；不同对话间并行。worker 在 5 分钟空闲后自行退出，下次 Send 时按需重建。

```go
type convQueue struct {
    ch     chan queuedTask
    mu     sync.Mutex
    cancel context.CancelFunc  // nil when idle
}
```

- **Send**：队列满 → 409 `STREAM_IN_PROGRESS`；否则入队后立即 202 返回
- **Cancel**：`q.cancel()` → ctx cancelled → streamLLM break → agentRun 走 `writeAndPublish(status=cancelled, fatal=true)` 推最终 chat.message 快照

### 10.4 System Prompt 组装

每次调用 Agent 前，`buildSystemPrompt(ctx, conv)` 按以下优先级组装：

```
[基础系统提示词（代码写死）]
+
[conversation.system_prompt（用户自定义，可为空）]
+
[locale 指令（从 reqctx 读）]
```

`conversation.system_prompt` 字段存在 `conversations` 表（由 conversation domain 管理），chat.Service 通过 `convRepo.Get(id)` 读取。

### 10.5 自动命名（Auto-Titling）

第一轮对话完成后（assistant 消息 status=completed），异步起一个 goroutine 调轻量模型生成标题：

```
条件：conversation.title == "" AND conversation.auto_titled == false
  → 调 modelFactory.Build（使用同 provider 的轻量模型，如 haiku / gpt-4o-mini）
  → System: "生成一个 5 字以内的对话标题，只返回标题本身"
  → Input: 前两条消息（user + assistant）
  → 写回 conversations.title + conversations.auto_titled = true
  → 推 conversation.title_updated SSE 事件
```

**非阻塞**：标题生成失败静默忽略，不影响主流程。`conversations` 表需新增 `auto_titled BOOLEAN NOT NULL DEFAULT false` 字段。

---

## 11. 完整调用链（Phase 5 当前形态）

### 11.1 用户发消息

```
POST /api/v1/conversations/cv_xxx/messages  body={content, attachmentIds}
  → middleware 链
  → ChatHandler.Send
      → convRepo.Get(conversationID)              → 验证对话存在
      → buildUserBlocks(ctx, in)                  → 查附件完整元数据 → []Block
      → repo.Save(userMsg with blocks)            → DB
      → getOrCreateQueue(conversationID).ch <- queuedTask{userMsgID}
      → response 202 {messageId: userMsgID}

--- worker goroutine（runner.go::processTask）---
  → ctx 注入 ConversationID + AgentState（per-queue 共享）
  → llmclient.Resolve(ctx, picker, keys, factory)  → bundle{ModelID, Key, BaseURL, Client}
      ↳ 失败映射 ErrPickModel → MODEL_NOT_CONFIGURED
                ErrResolveCreds → API_KEY_PROVIDER_NOT_FOUND
                其他 → LLM_PROVIDER_ERROR
      ↳ emitFatalError(code, msg) → writeAndPublish stub Message(status=error) + 推 chat.message
  → 构造 baseReq（System Prompt + 20 个 system tool 注入：toolapp.ToLLMDefs(s.tools)）
  → agentRun(ctx, uid, conv, userMsgID, msgID, client, baseReq):
      publishMessageSnapshot(status=streaming, blocks=nil) // 打开 assistant slot
      buildHistory(ctx, convID, userMsgID)        → []LLMMessage（末尾追加当前 user）
      for step < maxSteps:
          aBlocks, toolCalls, sr, em, iT, oT = streamLLM(ctx, client, req, convID, msgID, uid, allBlocks)
              每个 EventText/EventReasoning/EventToolStart/EventToolDelta → publish(chat.message 快照)
              EventFinish    → 累计 token usage
              EventError     → stopReason=error|cancelled
          allBlocks += aBlocks; totalInput += iT; totalOutput += oT
          if cancelled/error → writeAndPublish(fatal=true, errorCode/Message) → break
          if len(toolCalls)==0 → writeAndPublish(completed, fatal=true) → break
          rBlocks = runTools(ctx, toolCalls, convID, msgID, uid, allBlocks)
              // partitionByExecutionGroup 按 LLM 自报 group 分批；每个 tool 跑完推 chat.message
          allBlocks += rBlocks
          writeAndPublish(streaming, fatal=false)   // streaming checkpoint 落盘 + 推快照
          history = extendHistory(history, aBlocks, rBlocks)
      if !finalWritten → writeAndPublish(max_tokens, fatal=true)
  → if conv.Title=="" && !AutoTitled: go autoTitle(...)  // 终态本身就是最后一帧 chat.message
```

### 11.2 前端收事件（Phase 6 entity-state 模型）

```
GET /api/v1/events?conversationId=cv_xxx
  → ChatHandler.EventsSSE
      → Bridge.Subscribe(filter={conversationId: cv_xxx})
      → 每 15s 推 ": keep-alive\n\n" 防代理断连
      → 持续 write SSE: 仅 chat.message 一种事件
          event: chat.message  data: {...完整 Message 快照}   // slot 创建 (status=streaming, blocks=[])
          event: chat.message  data: {...}                    // 每个 LLM token (text/reasoning block 内容生长)
          event: chat.message  data: {...}                    // tool_call block 出现 (仅有 name)
          event: chat.message  data: {...}                    // tool_call args 完整
          event: chat.message  data: {...}                    // 每个 tool_result block 加入
          event: chat.message  data: {...}                    // 终态 (status=completed/error/cancelled)
```

旧事件 `chat.token` / `chat.reasoning_token` / `chat.tool_call_start` / `chat.tool_call` / `chat.tool_result` / `chat.done` / `chat.error` 已在 Phase 6 重构（2026-05-02）合并进 `chat.message` 单事件，全部信息携带在 Message 当前快照里。详 §8 + events-design.md。

---

## 12. Phase 4-5 扩展点

chat domain 在 Phase 4-5 主要通过 **追加 system tools** + **升级 system prompt** 来扩展，Service 本身代码改动很小：

### Phase 4（workflow 完成后）
- 追加 `create_workflow` / `edit_workflow` / `run_workflow` system tool
- Agent 获得"对话中创建/运行工作流"能力
- chat.Service 代码零改动，main.go 多注入 3 个 tool

### Phase 5（智能化完成后）
- 追加 `search_knowledge`（RAG）+ `mcp_call`（MCP 服务器）system tool
- System Prompt 升级为意图引导版（"可创建工具/工作流/搜知识库，自主决策"）
- 长对话 context compaction（runner.go::agentRun 已预留 TODO 钩子点）：超长时压缩历史，保留关键消息——这是 Claude Code 调研 [`claude-code-research-documents/03-context.md`](../claude-code-research-documents/03-context.md) 的吸收

---

## 13. 错误码

| Code | HTTP | Sentinel | 场景 |
|---|---|---|---|
| `STREAM_NOT_FOUND` | 404 | `chat.ErrStreamNotFound` | 取消不存在的流 |
| `STREAM_IN_PROGRESS` | 409 | `chat.ErrStreamInProgress` | 同一对话已有 Agent 在运行 |
| `LLM_PROVIDER_ERROR` | 502 | `chat.ErrProviderUnavailable` | 上游 LLM 故障（非 401）|
| `ATTACHMENT_TOO_LARGE` | 413 | `chat.ErrAttachmentTooLarge` | 附件超过 50MB |
| `ATTACHMENT_TYPE_UNSUPPORTED` | 415 | `chat.ErrAttachmentTypeUnsupported` | 无法处理的文件格式 |
| `ATTACHMENT_PARSE_FAILED` | 422 | `chat.ErrAttachmentParseFailed` | 文件损坏或解析失败 |
| `VISION_NOT_SUPPORTED` | 422 | `chat.ErrVisionNotSupported` | 当前 provider 不支持图片 |

**401 路径**：LLM 流响应中遇 401 → streamLLM 返 stopReason=error + errMsg → agentRun 走 `writeAndPublish(status=error, errorCode="LLM_STREAM_ERROR")`，前端从 chat.message 快照读 errorCode/errorMessage 即可。

---

## 14. 为什么这样设计（关键决策总结）

| 决策 | 选择 | 理由 |
|---|---|---|
| 用 ReAct Agent 还是固定 Graph | **ReAct Agent** | 任务序列是运行时 LLM 决定的，不能提前写死；Phase 2-5 的工具列表动态增长 |
| tools 全部注入 vs Tool RAG | **System Tools 注入 + Tool RAG** | System Tools 数量固定（~8 个）可全注入；用户工具无上限，靠 search_forges 动态检索 |
| 202 + SSE vs 直接 stream response | **202 + 独立 SSE** | Agent 跑多步需要持久连接；POST 语义是"接受请求"不是"等待结果"；events Bridge 已就绪 |
| messages 存哪 | **chat domain 自己管** | 消息历史是 chat 专有数据，不应跨 domain 共享；conversation domain 只管线程元数据 |
| LLM 客户端用现成框架 vs 自实现 | **自实现 `infra/llm`** | 流式 SSE 解析 / tool call 累积 / 错误分类需要完全可见可控；framework 抽象会丢信息（实测 framework callback 对流式 ChatModel 不触发，导致 DB content 空）|
| 不同 provider 协议适配 | **各自独立 client** | OpenAI 兼容 / Anthropic 原生 / Ollama 等都有协议差异（消息格式、tool result 包装、stream 边界），强行统一会失真 |
| System Prompt 的 locale | **buildSystemPrompt 动态注入** | 每次调用前动态拼接，locale 从 reqctx 读，Agent 不需要知道 locale 逻辑 |
| Message status | **message 级别字段** | 流式过程中消息状态需持久化；失败/取消场景前端需要准确知道每条消息的最终态 |
| SSE 可靠性 | **keep-alive ping + 内存 Bridge fan-out** | 网络抖动断连不丢事件；桌面应用场景常见 |
| Auto-titling | **异步 goroutine，失败静默** | 标题生成不是核心流程；用轻量模型节省费用；失败不影响用户体验 |
| 中间步 DB checkpoint | **streaming 状态 + buildHistory 跳过** | 多步 ReAct 中间态需持久化（崩溃恢复 / SQL Tab 调试可见），但不能进 LLM 历史避免循环 |
| 终态写 detached context | **`writeAndPublish(fatal=true)` 用 `context.Background()`** | 用户取消时 ctx 已 cancelled，但终态消息必须落库——否则下次打开对话看不到这次回复 |

---

## 15. 实现清单 ✅

### infra/llm 层（自有 LLM 流式客户端）
- [x] `infra/llm/llm.go` — StreamEvent / LLMMessage / ToolDef / Client 接口 / Generate helper
- [x] `infra/llm/openai.go` — OpenAI-compat SSE 客户端（iter.Seq），覆盖 OpenAI/DeepSeek/Qwen/Moonshot/Ollama 等
- [x] `infra/llm/anthropic.go` — Anthropic 原生 `/v1/messages` 客户端（content_block_start/delta/stop）
- [x] `infra/llm/factory.go` — Factory.Build(Config) provider dispatch + resolveBaseURL

### app/tool 层（framework + 7 家族子包，§S12 例外允许嵌套）
- [x] `app/tool/tool.go` — Tool 接口（9 方法）+ PermissionMode/Result + injectStandardFields（注入 summary/destructive/execution_group）+ StripStandardFields + ToLLMDef/ToLLMDefs
- [x] `app/tool/forge/{forge,search,get,create,edit,run}.go` — 5 个 forge system tool + 共享工厂 + streamCode helper + resolveAttachments
- [x] `app/tool/filesystem/{filesystem,read,write,edit}.go` — Read / Write / Edit；must-Read-first 守卫走 AgentState.SeenFiles；原子写 CreateTemp+Rename；Edit 字面量替换 + replace_all
- [x] `app/tool/search/{search,grep,grep_rg,grep_stdlib,glob}.go` — Grep（rg + stdlib 双后端）+ Glob（doublestar + mtime 降序 + JSON enrichment）
- [x] `app/tool/web/{web,fetch,search,search_bing}.go` — WebFetch（Jina + 直 GET fallback；SSRF 守卫 + 重定向逐跳校验）+ WebSearch（SearXNG/Bing/Bing CN 三层）+ Bing HTML visitor
- [x] `app/tool/shell/{shell,manager,bash,output,kill}.go` — Bash（前后台双模式 + cd 状态机）+ BashOutput（环形缓冲 + 读游标 + filter）+ KillShell（SIGKILL 幂等）+ ProcessManager
- [x] `app/tool/task/{task,create,list,get,update}.go` — TaskCreate / TaskList / TaskGet / TaskUpdate；scope 走 ConversationID
- [x] `app/tool/ask/ask.go` — AskUserQuestion；与 `app/ask` Service 配合（in-memory rendezvous）

### domain/chat 层
- [x] `domain/chat/chat.go` — Message（精简纯元数据 + errorCode/errorMessage）+ Block 实体 + 5 种 BlockType + ToolCallData（含 Summary/Destructive/ExecutionGroup 一等字段）+ ToolResultData（含 ErrorMsg/ElapsedMs）+ Attachment（Phase 5 加软删）+ sentinels + Repository
- [x] `domain/events/types.go` — Phase 6 entity-state 模型：ChatMessage / Forge / Conversation / Task 4 个事件，每个委托 MarshalJSON 给嵌入的 entity（与 GET 响应同形）；Phase 6 之前 12 个旧事件全删

### infra/db 层
- [x] `infra/db/schema_extras.go` — 按 table 分组的 extraGroup 结构；message_blocks 索引；tools partial UNIQUE（FTS5 当前未使用）
- [x] `infra/db/db.go` — modernc.org/sqlite 驱动；DSN 走 `_pragma=...` 语法

### infra/store/chat 层
- [x] `infra/store/chat/chat.go` — Save（ON CONFLICT upsert 保护 created_at，事务写 blocks）；ListByConversation（批量取 blocks 避 N+1）；GetAttachment；SaveAttachment

### infra/chat 层
- [x] `infra/chat/extractor.go` — Extract(storagePath, mimeType)：text/pdf/docx/xlsx/pptx/html 提取；IsImage 分派 Vision 路径

### app/chat 层（6 文件）
- [x] `app/chat/chat.go` — Service struct + Send / Cancel / ListMessages / UploadAttachment + queueCapacity + convQueue / queuedTask 类型
- [x] `app/chat/runner.go` — getOrCreateQueue / runQueue / processTask / agentRun（ReAct loop，含 context compaction TODO 钩子点）/ writeAndPublish（fatal 模式分支）/ publishMessageSnapshot / emitFatalError / stampBlocks / autoTitle
- [x] `app/chat/stream.go` — streamLLM（iter.Seq）+ assembleBlocks + extractToolCalls + parseToolArgs
- [x] `app/chat/tools.go` — runTools（sync.WaitGroup 并行）+ runOneTool（注入 msgID/toolCallID）+ executeTool
- [x] `app/chat/history.go` — buildHistory(currentUserMsgID) + extendHistory + blocksToLLM + blocksToAssistantLLM + buildUserLLMMessage + attachmentToPart
- [x] `app/chat/util.go` — newMsgID / newBlockID / newAttachmentID / readAndEncode / truncate

### transport 层
- [x] `handlers/chat.go` — 5 端点：POST attachments / POST messages / DELETE stream / GET messages / GET events SSE（keep-alive ping）

### 配套
- [x] `errmap.go` — chat sentinel 映射全部覆盖
- [x] `router/deps.go` — ChatService / EventsBridge 字段
- [x] `main.go` — chatRepo 共享变量；llmFactory；PathGuard；7 家族工厂装配链 ForgeTools → FilesystemTools → SearchTools → WebTools → NewShellTools（含 ProcessManager.Stop defer）→ TaskTools → AskTools → chatService.SetTools(tools)；Migrate messages + message_blocks + attachments + tasks
