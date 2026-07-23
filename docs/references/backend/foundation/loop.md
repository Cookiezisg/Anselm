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

流式调 LLM → 派发工具 → 扩展历史 → 终态，循环至模型停手或触顶。**四消费者一引擎**（chat/agent/subagent/workflow-agent 经 `Host` 接口，物理上 3 个 Host 实现：`chatHost`/`agentHost`/`subagentHost`——agentHost 同时服务独立 agent 调用与 workflow-agent 节点），只依赖中立件（messages 内容模型 / tool 契约 / llm 端口 / stream）。**Host 三必选**：LoadHistory / Tools（**每步重算**——`search_tools` 激活的 lazy 工具扩张后续步集合）/ WriteFinalize（恰一次收尾，block 落盘是 host 的事——loop 只内存产 block + 实时推流）。**五可选能力（type-assert）**：`ReminderProvider`（每步把 live 状态注入为临时 `<system-reminder>`，历史副本上追加、持久历史不污染）/ `AutoActivator`（LLM 直接点名某未激活 lazy 工具时，标记 discovered 并重建工具集）/ `StepRecorder`（子步重放记账，at-least-once）/ `PromptCompactor`（优先用 host 的 utility 模型生成 continuation checkpoint）/ `ContextObserver`（只观测单次 sampling 的尺寸/route/压缩决策，不持有 prompt 内容）。

## 2. 关键行为

- **熔断**：连续 3 轮全部 tool_result 带 error → `TOOL_ERROR_STORM` 终止（burn-in 见过 LLM 连建 4 个废 handler——早停钻牛角尖）。
- **诚实终态**：maxSteps 耗尽但模型还想动 → `MAX_STEPS_REACHED` + StopReason=max_steps（非成功终态、不冒充 completed；UI 凭此给"继续"）。
- **单次 sampling 上下文治理**：每个 outbound request 都按其**实际 prompt view**选择 text / multimodal input budget；上一成功 sampling 的真实 `prompt_tokens` 是锚，后续仅以 request footprint delta（3 bytes/token 的保守近似）预测，估算只触发整理、**绝不本地拒绝**。预测达 80% 时先把旧且可重取的 tool_result 换成 prompt-only marker（保留最新 3 个完整 tool group 与所有 assistant reasoning/tool_call），仍高则把协议完整的旧前缀语义折成结构化 continuation checkpoint，目标 55%。chat 优先 utility model；agent/subagent/workflow-agent 走同一共享压缩器并以主模型兜底；语义压缩失败才用明确标为有损、要求 re-fetch 的确定性 checkpoint。完整 durable block trace 永不改写。
- **权威超限透明恢复**：只有 provider / 网关的结构化 `context_length` 才是硬上限事实。若一个 sampling 在**尚未产生任何 block、尚未执行工具**时被拒，loop 清理旧工具结果、压缩后重试**同一逻辑 step**，最多两次，成功时用户看不到失败。DeepSeek active tool chain 按完整 assistant(reasoning_content+tool_calls) / tool group 切割，绝不制造悬空 tool 协议。仅当自动恢复后当前不可再分的最新输入仍超限，才终态 `CONTEXT_INPUT_TOO_LARGE`，提示拆分最新附件/内容。
- **danger gate**（tools.go）：ctx 有 humanloop broker 时自报 dangerous 的调用先阻塞等人批（active skill 的 allowed-tools / approve_always 会话白名单可预授权跳过）；broker 仅 chat 注入（含其 ctx 内嵌套调用的 agent/subagent-as-tool）——独立 agent invoke / 顶层 subagent / workflow 节点无 broker = 纯信任直接跑。
- **执行组并行**：同 `execution_group` 的调用 goroutine 并发，**每调用写预分配下标**（无共享槽、无锁），末尾按调用序拍平 block。
- **结果封顶**（tools.go `capToolResult`）：任何 tool_result 硬限 256 KiB（保头部 + 收窄提示）——结果整段落库、整段上 durable SSE；同回合下一步通常保留最新结果，接近预算时旧结果会在 prompt view 中清成可重取 marker。无界结果（不带 head_limit 的大 Grep、话痨 MCP 工具）仍会打爆持久化/流/近期 prompt，故入口硬限不可删。与 Bash 自身 cap 同值；Grep 两后端另有同值的内存累积界。
- **build 镜像**：tool_call 是 BuildTool 时，流式 arg delta 同步镜像到 entities 流（实体面板随 LLM 打字填充）。
- **标准字段协议**（tool 契约）：`summary`/`danger`/`execution_group` 由框架注入 schema（ToLLMDefs）+ 从 args 剥离（StripStandardFields）——工具只声明/接收业务参数（S18）。

## 3. 契约（引用）

无表无端点。回合级错误码（MAX_STEPS_REACHED / TOOL_ERROR_STORM / CONTEXT_INPUT_TOO_LARGE / LLM_STREAM_ERROR；LoadHistory 失败走通用 INTERNAL_ERROR）落 message.error_code（与 HTTP wire code 两个命名空间，见 [chat.md](../domains/chat.md)#6）。StopReason 词表仍兼容 end_turn / max_tokens / max_steps / context_budget / cancelled / error；新上下文引擎不再主动产 `context_budget` 软停。ToolProgress（ctx 注入的进度 writer）是工具流 progress 块的唯一通道。
