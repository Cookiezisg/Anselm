---
# Round 0031 — loop（波次 2 · M2.2）ReAct 引擎重写

类型 / 目标：M2.2 loop 重写——共享 ReAct 引擎接 stream 统一协议（eventlog→messages）、danger 纯标记、删 interceptor（M1.9）、todo SystemReminder 注入。连带新建 `domain/messages`（Block 无家可归）+ reqctx messageID 种子。

## 核心方针（一句话）
**loop = 共享 ReAct 引擎（流 LLM → 派发工具 → 扩历史 → 终态）；本轮把 eventlog→stream、permissions 解散、danger 自报、todo 注入四件落地，并把 Block 从 chat 拆到中立 `domain/messages`（修正共享引擎依赖具体消费者的耦合反向）。**

## 考古发现
- 旧 loop 9 文件 1865 行（核心 5 文件 1042），被 chat/agent/subagent/scheduler 四方共享，却依赖 `domain/chat`（Block/ToolCallData/Status/StopReason）——**耦合反向**。
- backend-new **无 chat、无 messages domain、无 Block**——M0.4 把三流统一成纯传输 `domain/stream`（Envelope/Frame/Node），词表下放业务。Block 无家可归。
- `interceptor.go`（ToolInterceptor = permissions gate + hook runner）= M1.9 解散的中央门控 + hooks 花活。
- `agentstate`（511 行）= 对话级工具共享黑板，4 块职责（SeenFiles 读追踪 / cwd / activeSkill 预授权 / activatedGroups 懒加载激活）——**没一块属于 loop**：skill pre-approval 随 CheckPermissions 删而失靶，activate_tools 激活状态归 host（AutoActivator 是 host 钩子）。loop 重写后**零 agentstate 依赖**（比旧版更干净）。

## 关键决策（用户拍板 + 深入后细化）
1. **建 `domain/messages`**：Block（纯 struct + db tag）/ ToolCallData（`Destructive`→`Danger` 纯字符串，domain 不沾 app/tool）/ 词表（BlockType/Status/StopReason/ContextRole）+ node content 形状。loop 依赖它而非 chat。本轮只立**类型契约**，message_blocks 表 store/落盘/History 留 chat M5.2。
2. **danger 纯标记**（M2.2 纯信任）：tool_call 节点带 danger/summary（close result + 落库 Attrs），前端标记 cautious/dangerous；**不阻塞**，dangerous 确认留接口位等 ask（波次 6）。
3. **todo 注入走 Host 通用钩子** `ReminderProvider.SystemReminders(ctx)`：loop 每步把 reminder 作临时 `<system-reminder>` user 消息注入（不污染持久历史）；loop 不直接依赖 todo app。
4. **eventlog→stream**：`emit.go` 新增（ctx 携带 `stream.Bridge` + emitter 封装 open/delta/close）；best-effort（无 bridge/conv 自禁用）。close 带 **Result 快照**（delta ephemeral 不入 buffer，buffer 内重连重建）。
5. **interceptor.go 整删** + **executeTool 极简**：删 CheckPermissions/skill-preapproval（M1.9/M2.1）+ **删 sanitizeToolErr/enrichWithNextStep**（深入后改判——它们硬编码具体工具名 + 旧 §S16 wrap 规约，违反 loop 中立；新架构工具自负 error 质量，loop 透传）。tools.go 323→~150 行。
6. **agentstate 不在 loop 重建**：随各消费者后续重建（SeenFiles→filesystem 2.3、cwd→shell 2.3、activatedGroups→chat M5.2、activeSkill→skill M3.5）；创建者 chat。

## 新实现（`domain/messages` + `app/loop` 6 文件 + reqctx 种子）
- `domain/messages/messages.go`：Block + ToolCallData + 4 词表 + IsValid* helpers。
- `app/loop/loop.go`：Run（主循环 + 双熔断 TOOL_ERROR_STORM/MAX_STEPS）+ Host + ReminderProvider/AutoActivator/StepRecorder 可选钩子 + Result + injectReminders。
- `app/loop/stream.go`：streamLLM（eventlog→emitter open/delta/close）+ node content 形状（text/reasoning/tool_call）+ assembleBlocks/collectToolCalls（DangerLevel→string 转换）。
- `app/loop/tools.go`：runTools（execution-group 并行批，index 对齐无锁）+ runOneTool + executeTool（极简）+ partitionByExecutionGroup。
- `app/loop/history.go`：BlocksToAssistantLLM（去死 log/error，HISTORY_EXTEND_FAILED 死分支随之消失）+ projectToolResultContent（ContextRole hot/warm/cold）+ ExtractTextContent。
- `app/loop/emit.go`：WithBridge + emitter（ctx 携带 Bridge，best-effort 推流）。
- `reqctx/conversation.go`：补 messageID 种子（host 在 Run 前埋，emitter 锚 block 到 message）。
- **删** interceptor.go（不迁）。

## 测试（全离线，0 token）
17 个：Run（单文本/工具→文本 ReAct/MAX_STEPS/TOOL_ERROR_STORM/LoadHistory错/reminder 注入+持久历史不变/AutoActivator 激活）· 派发（partition 分组/并行批 index 保序/tool not found）· streamLLM（组装 + danger 解析 + business args 剥离）· history（BlocksToAssistantLLM/ContextRole 投影/无 provider 原样）· messages（IsValid* 词表对账，progress/message 确认砍）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet` 0 · `go test -race` ok（loop 1.6s/messages 1.1s/reqctx 0.7s）· `go mod tidy` 无新增。

## 契约
domains/messages.md（新建 DOC-301）；contract-changes #11（messages 流 node 词表 + tool_call danger）；database.md `blk_` 前缀已登记（不改，message_blocks 表 DDL 留 M5.2）；events.md 全量重写留覆盖阶段。**无新 HTTP 端点 / 无 DB 表**（loop 是 app 引擎）。

## 跨波次接线
- **danger 阻塞确认**（dangerous → 暂停等用户同意）→ 波次 6（ask 通道）；loop 留接口位。
- **agentstate 重建** → filesystem/shell（2.3）+ chat（M5.2）+ skill（M3.5）；创建者 chat。
- **message_blocks store/落盘/History + Message 实体** → chat M5.2；loop 经 host.WriteFinalize 外包。
- **WithBridge 注入 + messageID 种子写入** → chat/agent host（M5.2/M3.4）；workflow-agent 不注入（非流式）。
- **StepRecorder（ADR-010 子步重放）** → workflow-agent（波次 4）实现。
- **events.md 全量重写 + 前端 messages 流重渲** → 覆盖阶段（contract-changes #2/#11）。

## 波次 2 进度
M2.1 tool ✅ → M2.2 loop ✅ → 下一 **M2.3 叶子工具**（filesystem/search/web/toolset）。
