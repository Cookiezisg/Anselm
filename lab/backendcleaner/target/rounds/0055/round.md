# Round 0055 — chat 引擎核心（波次 5 · M5.2 chat 子轮 2/3）

类型 / 目标：建 chat runner 的**对话引擎核心**——`chatHost`（实 `loop.Host` 三法 + `AutoActivator` + `ReminderProvider`）+ `convQueue`（per-conv 串行）+ `Send` 入口 + **SSE message 节点**（message_start/stop）+ **System Prompt builder**（Section 容器，静态段**重写**）+ **model resolve**（conv.ModelOverride → workspace 默认 → Client）。**fake LLM 端到端测**。HTTP handler / auto-title / cancel 端点 / mention 整套 / tokensUsed 富化 → **R0056**（用户拍板「两轮」）。

依赖扫描（三路 Explore 考察结论，2026-06-09）：
- **可直接复用（当前签名已核实）**：
  - System Prompt 源：`memory.ForSystemPrompt(ctx) string` / `document.ResolveAttached(ctx, conv.AttachedDocuments)` + `documentapp.RenderAttachedAsXML(docs)` / `catalog.GetForSystemPrompt(ctx) string` / `todo.SystemReminder(ctx) (string, bool)`（ReminderProvider）/ `reqctxpkg.GetLocale(ctx)`（zh-CN/en）。
  - model resolve 链（**`agent/invoke.go` 逐行范本**）：`model.Resolve(ctx, ScenarioDialogue, conv.ModelOverride, picker) → ModelRef` → `apikey.ResolveCredentialsByID(ctx, apiKeyID) → Credentials{Provider,Key,BaseURL,APIFormat}` → `factory.Build(Config) → (Client, baseURL)`；workspace 默认 `workspace.Service.Pick(ctx, scenario)`（实现 `ModelPicker`，3 列 dialogue/utility/agent）。
  - ReAct：`loop.Run(ctx, host, client, req, maxSteps, log) Result` + `loop.WithBridge(ctx, bridge)` + `toolapp.ToLLMDefs(tools)`。
  - ctx 种子：`SetConversationID/SetMessageID/WithAgentState/SetWorkspaceID/SetLocale` + `agentstate.New()`。
  - 持久化（R0054）：`messages.Repository` 5 法（`CreateMessage`/`FinalizeMessage`/`LoadThread`/...）。
  - attachment（R0051-53）：`attachment.ToContentParts(ctx, ids, Capabilities{Vision,NativeDocs}) ([]llm.ContentPart, error)`。
  - SSE：`stream.Bridge.Publish(ctx, Event{Scope, ID, Frame})`，Frame ∈ `Open{ParentID,Node}` / `Delta{Chunk}` / `Close{Status,Result *Node,Error}` / `Signal`。
- **本轮新建**：①`app/chat` 包（Service/convQueue/Send/chatHost/runner/System Prompt builder）②messages 流 **"message" 节点类型**（契约增量）。
- **R0056 外围**：HTTP handler（Send 202 / List / Cancel 204 / Export / llm-trace / system-prompt-preview）、auto-title（detached + utility 模型）、cancel/stop 端点、**mention**（注册表 + `<mentions>` 渲染 + freeze-on-send + 补 `workflow`/`agent` 两个缺失 resolver）、conversation tokensUsed 富化。
- **考古「不搬」**（已确认废）：`interceptor.go`（M1.9 permissions/hooks 解散）、`infra/chat/extractor.go`（attachment R0053 取代）、`permissionsgate`、整套 GORM/旧 eventlog。

设计要点：

1. **chatHost 实 loop.Host（骨架照 agentHost、两处改写）**：
   - `LoadHistory(ctx) ([]llm.LLMMessage, error)`：`messages.LoadThread(convID)` → 逐回合转 LLM 消息——user 回合：text block + `attachment.ToContentParts`（按 model 能力传 Capabilities）拼 `Parts`；assistant 回合：`loop.BlocksToAssistantLLM(blocks)`（hot/warm/cold 投影、archived/compaction 丢）。`conv.Summary` 非空 → 前置为一条 system/context 消息（已压缩的旧历史）。**mention `<mentions>` 渲染留 R0056**（本轮 user 消息只拼 text + attachment）。
   - `Tools(ctx) []toolapp.Tool`：`toolset.Resident` ∪ agentstate 已 discovered 的 lazy 工具（每步重算，loop 契约）。
   - `WriteFinalize(ctx, blocks, status, stopReason, errCode, errMsg, in, out)`：**Detached**（`context.Background()` 重新埋 workspace/conversation/bridge，防上游 cancel 留 streaming 孤儿块）→ `messages.FinalizeMessage(asstMsg 终态, blocks)` → 发 **message_stop**（`Close{Status, Result: message 节点快照〔tokens/stopReason〕}`）。
   - 可选 `AutoActivator.TryActivateForTool(ctx, name)`：在 toolset.Lazy 找含该工具的组 → 记入 agentstate.discoveredTools → 返新工具集。
   - 可选 `ReminderProvider.SystemReminders(ctx) []string`：`[todo.SystemReminder(ctx)]`（仅 shouldInject 时）。
   - **不实现 `StepRecorder`**（那是 workflow agent host）。
2. **convQueue（必留核心，照旧机制重建）**：per-conv `chan task`（容量 5）+ idle GC 5min timer + `STREAM_IN_PROGRESS`（channel 满 → 拒）+ `agentState` 挂 queue（跨 task 共享 SeenFiles/discoveredTools）+ `cancel context.CancelFunc` 存储（R0056 Cancel 用）。`getOrCreateQueue` 用 `sync.Map.LoadOrStore` 原子建 + 起 `runQueue` goroutine；idle 过期自删 + goroutine 退出。
3. **Send(ctx, convID, SendInput{Content, AttachmentIDs}) (msgID, error)**（mention 入参留 R0056）：
   - 取 conv（`conversation.Get`）；空内容 + 无附件 → `EMPTY_CONTENT`（domain 错误，handler R0056 拦）。
   - `CreateMessage(userMsg{role:user, status:completed, attrs:{attachments}}, [textBlock])` → 发用户消息节点（`Open{Type:"message"}` + `Close`，即时完整）。
   - `CreateMessage(asstMsg{role:assistant, status:streaming}, nil)` → 拿 asstMsgID → 发 **message_start**（`Open{ParentID:"", Node{Type:"message", Content:{role:assistant}}}`）。
   - 入队 task（带 asstMsgID + 输入）→ 返 asstMsgID（202 语义，handler R0056）。
4. **processTask（runner）**：建 agentCtx（`SetConversationID/SetMessageID(asstMsgID)/WithAgentState(queue.state)/SetWorkspaceID/SetLocale` + `loop.WithBridge(messagesBridge)`）→ 拼 System Prompt → model resolve（`Resolve(ScenarioDialogue, conv.ModelOverride, picker)`→creds→`factory.Build`）拿 Client + `Request{ModelID,Key,BaseURL,Options,System}` → `loop.Run(ctx, chatHost, client, req, maxSteps, log)`（maxSteps 默认 **25**）。
5. **System Prompt builder（Section 容器，静态段重写）**：`<section name="...">` 包装，cache-friendly 顺序 = identity → how_to_work → tools → capabilities(`catalog.GetForSystemPrompt`) → memory(`memory.ForSystemPrompt`) → documents(`RenderAttachedAsXML`) → user_system_prompt(`conv.SystemPrompt`) → environment(date + locale 语言) → architecture_rules → critical_rules（殿后，DeepSeek 末尾遵从最高）。**静态段重写**（按 AI-prompt-writing：高密度 / 去产品 fluff / 去 safety theater，旧文案仅作结构参照）。
6. **SSE "message" 节点（messages 流契约增量）**：顶层节点 `Type:"message"`、id=msgID、`Scope{conversation:<id>}`、`ParentID` 空（block 挂其下、E3 subagent message 挂 tool_call 下）。message_start=`Open`、message_stop=`Close{Status, Result: Node{Type:"message", Content:{role,status,stopReason,inputTokens,outputTokens,errorCode,errorMessage}}}`——**token/终态作 message 元数据进 Close.Result，不进 block 快照**。
7. **DIP 端口**：chat Service 注入 `messages.Repository` / `conversation.Repository` / `Toolset` / `ModelResolver`（封 Resolve+credentials+factory）/ attachment `ToContentParts` / System Prompt providers（memory/document/catalog）/ todo / stream Bridge / logger。照 agent `InvokeDeps` 范式（端口在 chat 定义、各 Service 结构化满足）。

强化地基：无（全是已建能力接线 + 新 app 包）。

修改后完整逻辑（= domains/chat.md DOC-104 引擎部分 as-built）：
- **app/chat/chat.go**：Service + DIP 端口 + SendInput + Send + convQueue + getOrCreateQueue（cancel 存储留 R0056 Cancel 消费）。
- **app/chat/host.go**：chatHost（LoadHistory/Tools/WriteFinalize + AutoActivator + ReminderProvider）+ loopHostType pin（编译期校验不漂移）。
- **app/chat/history.go**：LoadThread → []LLMMessage（user parts / assistant blocks / summary 前置）。
- **app/chat/prompt.go**：Section 容器 + assemble + 重写静态段 + 动态段拼装 + locale。
- **app/chat/runner.go**：processTask（agentCtx 种子 + System Prompt + model resolve + loop.Run）+ runQueue goroutine + idle GC。
- **app/chat/emit.go**：message_start/stop（stream.Bridge Open/Close on msgID）+ 用户消息节点。
- **domain/messages（或 stream 词表）**：登记 "message" node 的 content 形状（messages.md §3）。

删除 / 合并：无（纯增）。

契约变更（→ contract-changes #37）：domains/chat.md DOC-104 引擎部分 as-built 重写（ReAct via loop / convQueue / System Prompt Section / SSE message 节点 / model resolve；旧文档的 ReAct「loop.Run」「convQueue 容量 5」描述对齐 backend-new、删 interceptor/permissions/eventlog）；messages.md §3 加 "message" 顶层节点 + content 形状；events.md messages 流加 message 节点说明。**无新 REST / error-code**（EMPTY_CONTENT/STREAM_IN_PROGRESS 已在 error-codes §2.4，handler/cancel 端点 R0056 接）。

新测试（全离线，fake LLM）：
- Send 端到端：fake client → Send → 入队 → loop 跑 → blocks 落 message_blocks（GetMessage 验）+ message_start/stop 经 fake/捕获 Bridge 发出（验帧序：用户节点 Open+Close → assistant Open → block open/delta/close → assistant Close 带 tokens）。
- `STREAM_IN_PROGRESS`：队列满（连发 > 容量）→ 拒。
- System Prompt：各 Section（identity/memory/documents/environment locale/critical_rules）在场 + `<section name>` 包装。
- model resolve：conv.ModelOverride 优先 / 无 override → workspace Pick（fake picker）。
- LoadHistory：LoadThread → LLMMessages（user text+parts / assistant blocks 投影 / summary 前置）。
- WriteFinalize Detached：上游 ctx cancel 后仍落终态 + 发 message_stop（无 streaming 孤儿）。

验证：gofmt / `go build ./...` / vet / `go test ./...` 全绿。

是否更干净（自证）：① chatHost 复用 loop（共享 ReAct 引擎）、只加「持久化 + SSE」两条改写——不重写循环；② System Prompt 各源调现成 provider（memory/document/catalog/todo），chat 只做 Section 编排；③ model resolve 完全照 agentHost 范式（无新链路）；④ convQueue 串行使 seq 单调无需 DB 锁（承 R0054）；⑤ Detached finalize 防孤儿块（旧 chat 血泪、必留）；⑥ 范围克制——mention/HTTP/auto-title/cancel 留 R0056，本轮只交付可 fake 端到端跑通的引擎。

遗留 / 下一步：**R0056 chat 外围收官**——HTTP handler（Send 202 / List〔ListMessages 分页〕/ Cancel 204 / Export / llm-trace / system-prompt-preview）+ auto-title（detached + utility 模型 + 首回合 + 10s + 通知）+ cancel/stop（convQueue.cancel + drain）+ **mention 整套**（注册表 + `<mentions>` 渲染 + freeze-on-send，补 `workflow`/`agent` 两个 backend-new 缺失 resolver）+ conversation tokensUsed 富化（R0050 deferred）。之后 subagent（贴本轮 host，递归子对话）、contextmgr（M5.3 压缩写 context_role）。
