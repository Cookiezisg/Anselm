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

流式调 LLM → 派发工具 → 扩展历史 → 终态，循环至模型停手或触顶。**四消费者一引擎**（chat/agent/subagent/workflow-agent 经 `Host` 接口，物理上 3 个 Host 实现：`chatHost`/`agentHost`/`subagentHost`——agentHost 同时服务独立 agent 调用与 workflow-agent 节点），只依赖中立件（messages 内容模型 / tool 契约 / llm 端口 / stream）。**Host 三必选**：LoadHistory / Tools（**每步重算**——`search_tools` 激活的 lazy 工具扩张后续步集合）/ WriteFinalize（恰一次收尾，block 落盘是 host 的事——loop 只内存产 block + 实时推流）。**六可选能力（type-assert）**：`ReminderProvider`（每步把 live 状态注入为临时 `<system-reminder>`，历史副本上追加、持久历史不污染）/ `AutoActivator`（LLM 直接点名某未激活 lazy 工具时，标记 discovered 并重建工具集）/ `StepRecorder`（子步重放记账，at-least-once）/ `PromptCompactor`（优先用 host 的 utility 模型生成 continuation checkpoint）/ `ContextObserver`（只观测单次 sampling 的尺寸/route/压缩决策，不持有 prompt 内容）/ `MediaExpander`（WRK-082 批B' 消费咽喉·tool_result 半：每步工具跑完后从 tool_result 收集 MediaRef〔`pkg/mediaref` 文法、≤8 去重〕，host 按当前模型模态展开成原生 content part，loop 以一条追加 user 消息〔"Media artifacts referenced by the tool results above:" + parts〕**只**喂给后续请求——工具刚画的图模型当轮就看见；持久历史不写这条消息，无能力/无引用/展开为空皆零追加。**收集按 tool_call 分组**〔`toolResultMediaIDs` 返 `{toolCallID, ids}` 列表，键在 block 的 `ParentBlockID`〕，因为展开侧的归属收窄（H5.8）要知道**是哪次调用**铸的；**body 不是整串 JSON 时退化成字符串**交给 `Collect` 逐 `{` 试解嵌入对象——MCP 的媒体结果是 `[image: …]\n{…receipt…}` 这种「一段话后面跟一份 receipt」，只认整串 JSON 会让整个 MCP 产地的像素**一次也到不了模型**〔H7 A1 真钱验收查出，前五个产地的结果恰好都是纯 JSON 故一直没暴露〕。**收集无产地过滤**〔[ADR 0020](../../../decisions/0020-capability-decides-model-input.md) 取代 0017〕：生成族与其余产地一视同仁——旧否决让生成模型拿不到确认信号、重画到 MAX_STEPS〔成对真钱实验 4 vs 1〕；模型收不收得下由 `ToContentParts` 的能力+信封闸独家裁决〔听不了的音频、超信封的片子 → 文本 receipt〕）。

## 2. 关键行为

- **熔断**：连续 3 轮全部 tool_result 带 error → `TOOL_ERROR_STORM` 终止（burn-in 见过 LLM 连建 4 个废 handler——早停钻牛角尖）。
- **诚实终态**：maxSteps 耗尽但模型还想动 → `MAX_STEPS_REACHED` + StopReason=max_steps（非成功终态、不冒充 completed；UI 凭此给"继续"）。
- **单次 sampling 上下文治理**：每个 outbound request 都按其**实际 prompt view**选择 text / multimodal input budget；上一成功 sampling 的真实 `prompt_tokens` 是锚，后续仅以 request footprint delta（3 bytes/token 的保守近似）预测，估算只触发整理、**绝不本地拒绝**。预测达 80% 时先把旧且可重取的 tool_result 换成 prompt-only marker（保留最新 3 个完整 tool group 与所有 assistant reasoning/tool_call），仍高则把协议完整的旧前缀语义折成结构化 continuation checkpoint，目标 55%。chat 优先 utility model；agent/subagent/workflow-agent 走同一共享压缩器并以主模型兜底；语义压缩失败才用明确标为有损、要求 re-fetch 的确定性 checkpoint。完整 durable block trace 永不改写。
- **权威超限透明恢复**：只有 provider / 网关的结构化 `context_length` 才是硬上限事实。若一个 sampling 在**尚未产生任何 block、尚未执行工具**时被拒，loop 清理旧工具结果、压缩后重试**同一逻辑 step**，最多两次，成功时用户看不到失败。DeepSeek active tool chain 按完整 assistant(reasoning_content+tool_calls) / tool group 切割，绝不制造悬空 tool 协议。仅当自动恢复后当前不可再分的最新输入仍超限，才终态 `CONTEXT_INPUT_TOO_LARGE`，提示拆分最新附件/内容。
- **人闸（tools.go `dispatchWithGate`）：两件事会开这道闸。** broker 仅 chat 注入（含其 ctx 内嵌套调用的 agent/subagent-as-tool）——独立 agent invoke / 顶层 subagent / workflow 节点无 broker = 纯信任直接跑。
  1. **LLM 自报 `dangerous`**——先阻塞等人批。**三级判据含成本**(WRK-082 H5.6):花钱本身就是不可逆,故「只是写了个文件」的调用在那个文件要花真钱时**依然是** `dangerous`;锚点是**费率**而非工具名。在此之前判据只讲状态变更,一次生成视频完全可以被合理判成 `safe`,这道闸于是在最该响的那类调用上从没响过。**可豁免**，因为抬起它的正是模型自己的判断：`approve_always` 会话白名单 (对话, 工具) 这一对，active skill 的 `allowed-tools` 预授权它声明会用的工具。
  2. **越界写**（WRK-077 WD1）——挂了驻地的对话里，一次调用的目标落在驻地子树**外** → 强制设闸，**无视自报等级**。**不可豁免**：`approve_always` 是按 (对话, 工具) 记的，照顾它会把一次「行，那边那个文件」变成此后**任何**位置每次 `Write` 的长期许可——用户回答的是一个**路径**、不是一个工具；skill 的 `allowed-tools` 是在谁都还不知道它要写到**哪里**之前作出的同形承诺。两者都从未授权「离开驻地」。**为何它盖过自报**：其余一切地方 danger 等级都是模型对自己行为的诚实意见，而那正是设计（S18：无中央权限门控、纯信任 + 逐次确认）；而「我是不是正要写到用户指的那个文件夹外面去」**不是意见**——它是关于目标路径的可计算**事实**，一个把路径解析得稍有偏差、或因内容看起来无害就判某次覆写 `safe` 的模型，绝不能有跳过这个问题的能力。**读永不设闸**：驻地是 zoom、不是牢。
  **loop 保持通用**（它分不清 `file_path` 与 `content`）：判定经**可选能力接口** `toolapp.FileWriteTool`（`WriteTarget(argsJSON) string`，返回 args 里**未解析**的原始路径），断言方式与 `BuildTool` 完全一致；`Write`/`Edit` 实现它，`Tool` 的**五方法**不变（S18）。解析走**同一个** `fspath.ExpandIn`（工具自己将要用的那一个，故闸判的就是 Execute 将要打开的那个文件——两个解析器终会互相不同意，而那份不同意会静默地成为一个洞），归属判定走 fail-closed 的 `fspath.Inside`。路径定不下来（args 解不开 / 无路径）**落回**普通 danger 闸：一个说不清自己在问什么的确认框只会被闭眼点掉，而这种调用 Execute 自己会拒。
  **闸的载荷**：`{summary, args}` 一字不动，仅在**越界**时多一个 `outsideWorkDir: true` 键——故普通 danger 确认的载荷与每个既有客户端已在解析的形状**逐字节相同**，而用户不会为一次模型自称 `safe` 的写面对一个无从解释自己的批准框。
- **执行组并行**：同 `execution_group` 的调用 goroutine 并发，**每调用写预分配下标**（无共享槽、无锁），末尾按调用序拍平 block。
- **结果封顶**（tools.go `capToolResult`）：任何 tool_result 硬限 256 KiB（保头部 + 收窄提示）——结果整段落库、整段上 durable SSE；同回合下一步通常保留最新结果，接近预算时旧结果会在 prompt view 中清成可重取 marker。无界结果（不带 head_limit 的大 Grep、话痨 MCP 工具）仍会打爆持久化/流/近期 prompt，故入口硬限不可删。与 Bash 自身 cap 同值；Grep 两后端另有同值的内存累积界。
- **build 镜像**：tool_call 是 BuildTool 时，流式 arg delta 同步镜像到 entities 流（实体面板随 LLM 打字填充）。
- **标准字段协议**（tool 契约）：`summary`/`danger`/`execution_group` 由框架注入 schema（ToLLMDefs）+ 从 args 剥离（StripStandardFields）——工具只声明/接收业务参数（S18）。`danger` **缺失或非枚举值一律回落 `safe`**（fail-open，与 `fspath.Inside` 的 fail-closed 相反）：真模型会答 `"none"` 这类枚举外的值，而把每个这样的调用变成一次确认会让免费档不可用；本地单用户 + 无中央权限门控（[tool.go](../../../../backend/internal/app/tool/tool.go) `DangerLevel` 文档注释）是这条取舍的前提，WRK-082 H8 用户裁定维持。
- **`ObjectMap`**（`app/tool/objectmap.go`，WRK-082 H7）：object 型工具参数的**编码容忍**——同时接受对象形与「装着对象的 JSON 字符串」形。真模型例行把嵌套对象字符串化（实测一次 qwen 调用送来 `{"functionId":"fn_…","args":"{\"points\":6}"}`），裸 `map[string]any` 以「cannot unmarshal string into Go struct field」硬拒，该错以工具失败抵达模型、模型随即乱套。**只接受解出来是对象的字符串**（解出数组/数字或根本不是 JSON 仍报错）——接受的是**正确的值的另一种编码**，不是去猜一个错误的值。用在 `run_function`/`call_handler` 的 `args` 与 `invoke_agent` 的 `input`（两处）——一族四个由模型填的 object 参数，故住在框架层而非各修一遍。

## 3. 契约（引用）

无表无端点。回合级错误码（MAX_STEPS_REACHED / TOOL_ERROR_STORM / CONTEXT_INPUT_TOO_LARGE / LLM_STREAM_ERROR / **LLM_AUTH_FAILED / LLM_BAD_REQUEST / LLM_MODEL_NOT_FOUND / LLM_QUOTA_EXHAUSTED / LLM_RATE_LIMITED / LLM_PROVIDER_ERROR**；LoadHistory 失败走通用 INTERNAL_ERROR）落 message.error_code（与 HTTP wire code 两个命名空间，见 [chat.md](../domains/chat.md)#6）。`streamErrorCode` 保留 transport 已分类的 provider sentinel，不把可解释的鉴权、请求、模型、额度、限流或上游错误压成通用断流码；`LLM_MODEL_NOT_FOUND` 仍保留 transport 对 404 的稳定分类：目录仍列出但当前账号不可生成的模型只发一次、不进入重试，前端可提供重选模型入口。只有未分类的断流才使用 `LLM_STREAM_ERROR`。StopReason 词表仍兼容 end_turn / max_tokens / max_steps / context_budget / cancelled / error；新上下文引擎不再主动产 `context_budget` 软停。ToolProgress（ctx 注入的进度 writer）是工具流 progress 块的唯一通道。
