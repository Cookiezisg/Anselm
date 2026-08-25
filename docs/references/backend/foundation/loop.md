---
id: DOC-031
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# ReAct Loop

## 1. 定位

`app/loop` 是 Chat、Agent、Subagent 与 Workflow Agent node 共用的流式执行
引擎：

```text
LoadHistory
→ stream LLM
→ emit blocks（Host 可选地增量 persist sampling 边界）
→ gate and dispatch tools
→ append tool results/media
→ next sampling
→ one Finalize
```

Loop 只依赖 Messages、Tool、LLM 与 Stream 契约，不知道 Conversation 或实体
store。

## 2. Host

必选接口：

- `LoadHistory`：提供本次 prompt view；
- `Tools`：每步重算可用工具；
- `WriteFinalize`：恰一次收尾。

可选能力：

| Capability | 用途 |
|---|---|
| ReminderProvider | 每步临时注入 live reminder |
| AutoActivator | 直接点名 lazy tool 时补激活 |
| StepRecorder | Workflow Agent 子步持久化 |
| PromptCompactor | 生成 continuation checkpoint |
| ContextObserver | 记录 sampling 尺寸/route/恢复 |
| RuntimeBudgetResolver | 按真实 route 读取已学习预算 |
| MediaExpander | 将 tool-result MediaRef 展成 content parts |
| BlockRecorder | 在工具派发前增量落盘 sampling blocks；Chat 用于冷打开的人在环 tool_call |

Reminder 与媒体追加只进入后续 request，不污染 durable Message history。

## 3. Blocks 与工具

模型流产生 text、reasoning 与 tool_call Blocks。框架给每个工具 schema 注入
`summary`、`danger`、`execution_group`，派发前剥离，工具只接收业务参数。

同 execution group 的 calls 并行，每个调用写预分配槽，结果仍按调用顺序拍平。
Tool 执行前 Open 空 tool_result，progress 作为子块实时/持久化，完成后 Close
完整 result。

用户停止回合时，若 tool 已进入执行并因 `context.Canceled` 返回，loop 必须以
`tool_result status=cancelled` 收束，使用固定的中性结果并清空 wire `error`；底层 context
错误只进后端 journal。不得把用户主动停止显示成工具失败，也不得把 `context canceled`
等 executor 内部字样泄露到 transcript。工具调用已经在执行前被取消时，沿用既有的
「The run was cancelled before this tool ran.」结果。

若 provider 发出的工具名不在本回合解析出的 registry 中，loop 必须在副作用前终止该调用，落一张 error tool_result，并同时把「没有执行」「当前回合不可用」和下一步恢复建议交给模型与用户；不得只显示裸的 `tool "..." not found`。这既覆盖 stale catalog/wiring 也覆盖模型臆造工具名，不能把未知名当作 lazy 工具成功激活。

同一 `Run` 内，已经执行、参数校验失败或被人拒绝的 `dangerous`/静态危险下限/驻地越界写调用若在后续 ReAct
step 以相同工具名和规范化业务参数再次出现，Loop 在 dispatch 前产生已完成的
suppression tool_result，不再开第二次人闸或产生第二次副作用，并结束当前回合。
工具可选声明更窄的业务 `CallIdentity`；例如 `delete_workflow` 的身份只有目标 workflow，
所以模型第一次把无效的 `file_path` 混入参数并在下一步修正时，仍被识别为同一个破坏性意图，
不会因为无关字段变化而重新打开危险闸。该台账只存在于本次 `Run`；下一条用户消息是新意图，
仍可主动重试。只读或普通
可重试调用不因一次失败被这条跨步保护静默吞掉。

单个 tool result 有统一硬上限（默认 256 KiB，包含截断提示），防止持久化、SSE 与当前 prompt
同时被无界输出撑爆。成功结果保留头部并附带 filters / `head_limit` / pagination 的收窄提示；若工具
同时返回部分输出和错误，保留输出头部、错误尾部与同一提示，三者总长度仍不超过上限。Object 型参数
接受真实 object 或“可解析为 object 的 JSON string”，不接受数组/标量的猜测转换。

连续多个 step 全部工具失败触发 `TOOL_ERROR_STORM`。到达 step cap 且模型仍要
继续时，以 `MAX_STEPS_REACHED` / `max_steps` 非成功终态结束。

## 4. Context 治理

每个 outbound request 按实际 text/multimodal route 选择预算。已学习 runtime
profile 只触发主动整理，不作为本地硬拒绝。

整理顺序：

1. 清理较旧且可重取的 tool results，保留最近完整 tool groups；
2. 将协议完整的旧前缀压成 continuation checkpoint；
3. Semantic compactor 失败时使用明确标注有损的 deterministic checkpoint。

Durable Blocks 永不改写。只有 provider/gateway 的结构化 context-length 错误才是
硬证据；若本 step 尚未产生 block 或执行工具，Loop 可整理后透明重试同一逻辑
step。不可再分的最新输入仍超限时才终态
`CONTEXT_INPUT_TOO_LARGE`。

Assistant reasoning/tool-call/tool-result group 在裁剪时保持协议完整，不能制造
孤立 tool result。

面向用户的普通 Chat 文本会对 opaque machine values（ID、时间戳、hash、receipt）做确定性脱敏，
结构化 tool card 保留精确原值作为审计面。若模型把 MCP 调用的 `startedAt`/`endedAt`/`createdAt` 放进
详情 Markdown 表，脱敏器会保留字段行并把值改为「精确时间见旁边的 MCP 调用卡片。」（英文对应
`See the exact timing in the MCP call card.`），不得留下「相应时间」或其他看似真实的占位值；用户明确
点名某字段时，工具契约要求模型逐字复制返回字符串。

## 5. HumanLoop gate

Chat context 可携 ephemeral broker；独立 Agent、顶层 Subagent 与 Workflow node
没有 broker 时按其调用边界直接执行。

两类 gate：

- 模型自报 `dangerous`：允许 conversation/tool 的 approve-always 与 active
  Skill allowed-tools 预授权；工具若实现 `DangerFloorer`，其静态下限会覆盖较低的模型自报，且
  不受这两种预授权绕过；
- Workdir 外写入：由 `FileWriteTool.WriteTarget`、`fspath.ExpandIn` 与
  `fspath.Inside` 计算，任何预授权都不能绕过。

不可逆工具必须通过静态下限把有效等级固定为 `dangerous`；例如 `delete_workflow` 即使模型自报
`safe` 也必须先出现真实 HumanLoop approval，再允许副作用发生。tool-call 的 durable/SSE
快照同样展示提升后的有效等级，不能出现“看起来 safe、实际上要批准”的错觉。

同一规则适用于 `install_mcp_server`：安装会持久化 server 配置、可能启动常驻进程/外部连接并新增
能力与加密凭证，故其静态下限恒为 `dangerous`。即使模型自报 `safe` 或 `cautious`，也必须先出现
action-time HumanLoop approval，且不能由 skill `allowed-tools` 或 `approve_always` 绕过；批准句必须
说明这些持久化与外部后果。

`uninstall_mcp_server` 也属于不可绕过的 `dangerous` 工具：它停止常驻进程、永久删除持久化 server
配置并使动态工具不可用，必须先出现 action-time HumanLoop approval。工具描述要求模型使用安装回执的
短 server name；后端同时接受对应 marketplace registry name 作为确定性别名。名称失败不允许模型在
同一用户意图内自行换名重试，避免一张失败卡后再产生第二次不可逆副作用。

危险闸的批准句由执行器实际解析到的工具名生成，不能直接信任模型自报的 `summary`。所有不可逆
删除族（`delete_function` / `delete_handler` / `delete_agent` / `delete_control` / `delete_approval` /
`delete_skill` / `delete_trigger` / `delete_workflow`）都必须在门禁本体写清真实后果，而不是只说
“运行某个工具”：例如 `delete_trigger` 必须明确写成停止 listener、主行不可恢复、历史保留供审计且
关系边会被清理；`delete_workflow` 必须明确写成不可恢复删除，`deactivate_workflow` 必须明确写成
停止新触发但等待在途运行收尾，`kill_workflow` 必须明确写成取消在途运行；模型 summary 只能留在工具卡中。
这不是文案偏好，而是副作用前的动作身份校验。高后果生命周期工具若自报 summary 与实际工具
相互矛盾（例如 `delete_workflow` 自称 deactivate），在打开批准闸之前拒绝执行，并将应选工具
反馈给模型；绝不能让错误动作带着误导句进入批准流程。

Workdir 是 zoom，不限制读取。路径无法可靠解析时回到普通 danger 语义；工具
参数会在 gate 之前先做纯结构校验，非法 mutation 不得先显示 Allowed 再失败；
工具 Execute 仍会再次校验自己的参数。越界确认 payload 在标准 summary/args 外
增加 `outsideWorkDir=true`。

## 6. 多模态工具结果

Loop 按 tool-call 分组收集 result 中的 MediaRef，支持纯 JSON 或散文中的嵌入
JSON object。收集器去重并限制数量，不按 source 过滤。

Host 根据本次模型能力与 Attachment ownership 将媒体展开为原生 parts。不能
消费的媒体继续以文本 receipt 存在；扩展消息不重复写入 durable Blocks。

## 7. 终态

Provider 分类错误保留鉴权、请求、模型、额度、限流与上游错误码；chat 自己的总墙钟
到期使用 `CHAT_TURN_TIMEOUT`，不得伪装成用户主动取消；其它宿主仍保留其取消语义。无法分类的
流错误使用 `LLM_STREAM_ERROR`。Stop reason 兼容
`end_turn|max_tokens|max_steps|context_budget|cancelled|error`；
`context_budget` 只用于读取已有持久数据，当前引擎不主动产生该软停。

Loop 无表或 HTTP 端点。Message/Block 契约见
[`messages.md`](../domains/messages.md)，流见
[`events.md`](../events.md)，错误见
[`error-codes.md`](../error-codes.md)。
