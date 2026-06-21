---
id: DOC-031
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# loop —— 共享 ReAct 引擎

## 1. 定位 + 心智模型

流式调 LLM → 派发工具 → 扩展历史 → 终态，循环至模型停手或触顶。**四消费者一引擎**（chat/agent/subagent/workflow-agent 经 `Host` 接口，物理上 3 个 Host 实现：`chatHost`/`agentHost`/`subagentHost`——agentHost 同时服务独立 agent 调用与 workflow-agent 节点），只依赖中立件（messages 内容模型 / tool 契约 / llm 端口 / stream）。**Host 三必选**：LoadHistory / Tools（**每步重算**——`search_tools` 发现的 lazy 工具扩张后续步集合）/ WriteFinalize（恰一次收尾，block 落盘是 host 的事——loop 只内存产 block + 实时推流）。**三可选能力（type-assert）**：`ReminderProvider`（每步把 live 状态注入为临时 `<system-reminder>`，历史副本上追加、持久历史不污染）/ `AutoActivator`（LLM 直接点名某未发现的 lazy 工具时，把该**单个**工具标记 discovered 并重建工具集，免去先跑 `search_tools` 那一步——不在任何 lazy 组则返回 nil、loop 按普通 miss 处理）/ `StepRecorder`（子步重放记账——仅在工具跑完+历史扩展后调，at-least-once）。

## 2. 关键行为

- **熔断**：连续 3 轮全部 tool_result 带 error → `TOOL_ERROR_STORM` 终止（burn-in 见过 LLM 连建 4 个废 handler——早停钻牛角尖）。
- **诚实终态**：maxSteps 耗尽但模型还想动 → `MAX_STEPS_REACHED` + StopReason=max_steps（非成功终态、不冒充 completed；UI 凭此给"继续"）。
- **回合内上下文预算软守卫**（F58）：`maxSteps` 限**步数**、不限 token **增长**——单个长回合累积 tool_result 可在压缩（只在**回合边界**跑）之前逼近模型 context window。每步拿到**实际** input token 后，若 `InputBudgetTokens`（= window − maxOutput，由 resolver bundle 时盖在 Request 上、未知则 0 禁用）已被本步越过 `loopStopRatio`（0.92，结构性常量、高于压缩 TriggerRatio 0.80）且模型仍想动作 → `CONTEXT_BUDGET_REACHED` + StopReason=`context_budget`（非成功终态、部分结果），赶在**下次**更大的调用撞 provider 上下文长度硬失败 + 白烧那次 token 之前。
- **danger gate**（tools.go）：ctx 有 humanloop broker 时自报 dangerous 的调用先阻塞等人批（active skill 的 allowed-tools / approve_always 会话白名单可预授权跳过）；broker 仅 chat 注入（含其 ctx 内嵌套调用的 agent/subagent-as-tool）——独立 agent invoke / 顶层 subagent / workflow 节点无 broker = 纯信任直接跑。
- **执行组并行**：同 `execution_group` 的调用 goroutine 并发，**每调用写预分配下标**（无共享槽、无锁），末尾按调用序拍平 block。
- **结果封顶**（tools.go `capToolResult`）：任何 tool_result 硬限 256 KiB（保头部 + 收窄提示）——结果会整段落库、整段上 durable SSE open 帧、整段进同回合下一步 LLM 请求（warm/cold 投影只裁后续回合），无界结果（不带 head_limit 的大 Grep、话痨 MCP 工具）会同时打爆三处。与 Bash 自身 cap 同值；Grep 两后端（rg/stdlib）另有同值的内存累积界。
- **build 镜像**：tool_call 是 BuildTool 时，流式 arg delta 同步镜像到 entities 流（实体面板随 LLM 打字填充）。
- **标准字段协议**（tool 契约）：`summary`/`danger`/`execution_group` 由框架注入 schema（ToLLMDefs）+ 从 args 剥离（StripStandardFields）——工具只声明/接收业务参数（S18）。

## 3. 契约（引用）

无表无端点。回合级错误码（MAX_STEPS_REACHED / TOOL_ERROR_STORM / CONTEXT_BUDGET_REACHED / LLM_STREAM_ERROR；LoadHistory 失败走通用 INTERNAL_ERROR）落 message.error_code（与 HTTP wire code 两个命名空间，见 [chat.md](../domains/chat.md)#6）。StopReason 词表：end_turn / max_tokens / max_steps / **context_budget**（F58）/ cancelled / error。ToolProgress（ctx 注入的进度 writer）是工具流 progress 块的唯一通道。
