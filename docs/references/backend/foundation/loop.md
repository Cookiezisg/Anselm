---
id: DOC-031
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# loop —— 共享 ReAct 引擎

## 1. 定位 + 心智模型

流式调 LLM → 派发工具 → 扩展历史 → 终态，循环至模型停手或触顶。**四消费者一引擎**（chat/agent/subagent/workflow-agent 经 `Host` 接口），只依赖中立件（messages 内容模型 / tool 契约 / llm 端口 / stream）。**Host 三必选**：LoadHistory / Tools（**每步重算**——activate_tools 扩张后续步集合）/ WriteFinalize（恰一次收尾，block 落盘是 host 的事——loop 只内存产 block + 实时推流）。**三可选能力（type-assert）**：`ReminderProvider`（每步把 live 状态注入为临时 `<system-reminder>`，历史副本上追加、持久历史不污染）/ `AutoActivator`（LLM 点名未激活的 lazy 工具时自动激活组）/ `StepRecorder`（ADR-010 子步重放记账——仅在工具跑完+历史扩展后调，at-least-once）。

## 2. 关键行为

- **熔断**：连续 3 轮全部 tool_result 带 error → `TOOL_ERROR_STORM` 终止（burn-in 见过 LLM 连建 4 个废 handler——早停钻牛角尖）。
- **诚实终态**：maxSteps 耗尽但模型还想动 → `MAX_STEPS_REACHED` + StopReason=max_steps（非成功终态、不冒充 completed；UI 凭此给"继续"）。
- **danger gate**（tools.go）：ctx 有 humanloop broker 时自报 dangerous 的调用先阻塞等人批（active skill 的 allowed-tools / approve_always 会话白名单可预授权跳过）；无 broker（subagent/workflow）= 纯信任直接跑。
- **执行组并行**：同 `execution_group` 的调用 goroutine 并发，**每调用写预分配下标**（无共享槽、无锁），末尾按调用序拍平 block。
- **结果封顶**（tools.go `capToolResult`）：任何 tool_result 硬限 256 KiB（保头部 + 收窄提示）——结果会整段落库、整段上 durable SSE open 帧、整段进同回合下一步 LLM 请求（warm/cold 投影只裁后续回合），无界结果（不带 head_limit 的大 Grep、话痨 MCP 工具）会同时打爆三处。与 Bash 自身 cap 同值；Grep 两后端（rg/stdlib）另有同值的内存累积界。
- **forge 镜像**：tool_call 是 ForgeTool 时，流式 arg delta 同步镜像到 entities 流（实体面板随 LLM 打字填充）。
- **标准字段协议**（tool 契约）：`summary`/`danger`/`execution_group` 由框架注入 schema（ToLLMDefs）+ 从 args 剥离（StripStandardFields）——工具只声明/接收业务参数（S18）。

## 3. 契约（引用）

无表无端点。回合级错误码（MAX_STEPS_REACHED / TOOL_ERROR_STORM / LLM_STREAM_ERROR）落 message.error_code（与 HTTP wire code 两个命名空间，见 [chat.md](../domains/chat.md)#6）。ToolProgress（ctx 注入的进度 writer）是工具流 progress 块的唯一通道。
