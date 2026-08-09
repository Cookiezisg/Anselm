---
id: DOC-021
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Chat

## 1. 定位

Chat 把用户输入变成 durable Message turn，在 workspace 工具面上运行共享
ReAct loop，实时推流并落终态。Conversation、Messages、Attachment、Document、
Memory、Model、Tool、Context manager 与 HumanLoop 都通过端口注入。

```text
Send
→ durable user + streaming assistant rows
→ per-conversation queue
→ resolved model + chatHost + loop
→ streamed blocks
→ durable assistant terminal
→ title / compaction tail work
```

## 2. 每 Conversation 串行

Send 先确认 Conversation 存在并自动解档，再同步落 user 与空 assistant 行，
随后入该 Conversation 的 queue。每个 Conversation 同时只运行一个 assistant
turn：

- generation 中再次 Send 返回 `STREAM_IN_PROGRESS`；
- 可见回复已 finalize、同步 tail work 尚未结束时允许一个 follow-up 槽；
- idle queue 自动释放；
- Shutdown 取消所有 running turn 并在传入的关停预算内停止 queue；可选的首轮自动标题不占用 queue
  等待组，收到 service 生命周期取消后不得再写库；
- Cancel 同时取消 running turn、清空 queued turn，并把所有 assistant 行收成
  cancelled。
- LLM 建连阶段允许受管网关最多 120 秒返回响应头，以覆盖冷路由/上游唤醒；这不是整回合预算。
  响应头之后仍由流式 idle 预算检测死连接，并由 `LLMStreamMaxSec` 限制持续输出却不收敛的模型；
  整个回合最终仍受 `ChatTurnSec` 约束。

Task 不复用请求 context。Worker 从 workspace detached context 重建 locale、
conversation/message、AgentState、两条 stream、HumanLoop、workdir 与 Chat turn
wall-clock。Workdir 在读取 Conversation 后种入，因此中途切换从下一回合生效。

## 3. Chat Host

### History

`LoadThreadForLLM` 在 SQL 下推三类排除：

- Subagent sub-message；
- `superseded_by` 非空的 retry 被替换版本；
- `seq <= summary watermark` 的已折叠 blocks。

Summary 作为前置上下文；user Message 按已解析模型能力渲染文本和附件；
assistant Blocks 按 context role 投影。Progress、marker、compaction 与本次空
assistant 不进入 prompt。

### Tools

每次 sampling 重新计算工具集：

- resident tools 与 `search_tools`；
- 当前 Conversation 已发现的 lazy tools；
- 已发现的 workspace MCP dynamic tools；
- 当前请求有真实路由的 capability tools。

Inactive inventory 只在 prompt 暴露紧凑名称/用途；完整 schema 在发现后的下一
次 request tools 中出现。目录行同时列出 required 与 optional property 名称（后者只
是键名提示，不改变默认值或校验规则），避免模型在用户已经给出可选边界时先按默认
值执行，再补一遍修正调用。AgentState 使用有界 recency set；直接点名 lazy tool
时 AutoActivator 可补发现步骤。

每个 Chat ReAct 回合还维护一份内存内调用台账：同一业务调用在成功后不会跨步重复执行，避免
模型在已经拿到完整只读结果后反复搜索、浪费用户等待；安全调用若工具层失败则不入账，保留真实
重试路径。危险或驻地越界调用即使被拒绝也入账，后续重复调用只返回可解释的 suppression result，
并结束本回合，防止绕过人闸。台账只属于当前回合，不跨用户消息持久化；同一参数的新用户意图
仍可正常执行。

工具调用的 assistant 消息不得同时携带面向用户的答案文本：不要在 tool result
返回前陈述结果。必要时只在 reasoning 中表达简短意图，等待 tool result 后再
一次性给出答案，避免把同一结果作为中间文本和最终文本重复展示。

同一回合内，已返回结果的只读枚举不得用完全相同的参数重复调用；模型应复用已有结果，或明确改变边界/过滤后再查。若安全层仍拦截重复调用，tool result 必须诚实标明未执行，不能伪装成成功。

工具若返回对精确业务调用已经终局的拒绝（当前 `move_document` 的循环拒绝），可通过可选的
`RepeatTerminaler` 契约声明该结果；这不扩张 S18 的五方法 `Tool` 接口。相同调用随后再出现时，
loop 只生成可审计的 suppression result 并收束本回合，不再次执行；前端不把这条终局重复拦截渲染成
第二条“未执行”卡，但 durable block、SSE 与后台台账仍保留原始证据。父节点暂时不存在等可由本回合
其它变更修复的错误不得误标为终局。

### Grounded final text

当模型把已脱敏值放进带语义前缀的标签行（例如 `**Attachment ID:**` 或 `**Version ID:**`）时，整行移除而不是把
`the requested item` 这类内部占位词渲染给用户；版本 ID 即使带有“new version created”等括号后缀也整行移除，
该规则同时作用于流式 delta 和 durable close，
精确引用仍只留在相邻工具卡与内部审计面。

同一规则覆盖 reasoning 中的 `versionId changed to <opaque>` 句式：保留“版本引用已更新”的事实，
但不让不可复制的版本值或占位词进入用户正文。

流式工具名的半截暂存只允许发生在词元边界；普通单词内部的词尾（例如 `lastMessageAt` 中的 `ge`）不能被误判为分片的 `get_flowrun`，否则会把正常表头拆坏。该边界规则与跨 chunk 的整词缓冲一起适用于 SSE delta 和 durable close。

带 `lastMessageAt` 列的 Markdown 表格在最后一行尚未收到换行时必须整体暂存，即使当前片段恰好看起来像完整的 `| Title |` 行；下一帧可能才会开始写目标时间列。不能先释放已完成的前置行，否则后续时间值会失去列语义并被通用规则误改为 `the recorded time`。

实体 ID 的前缀清单必须与当前领域命名保持同步；trigger 的真实 ID 前缀是 `trg_`，也必须经过同一条直接与流式脱敏路径，不能只兼容历史 `tr_` 缩写。

普通实体表格如果只有脱敏后的机器值，系统提示明确禁止把 `the requested item` 或 `the referenced item` 当作 ID、路径、标签或表格单元格；服务端流式阶段把这类单元格标为不可用，完整 durable close 再将所有值都不可用的 ID 列整体移除。精确 ID 仍只保留在相邻 tool card 与审计线缆中，助手正文优先展示人名与路径。若 workspace ID 经过脱敏后嵌入 `cwd`、`CLAUDE_SKILL_DIR`、`path` 等路径字段，不能把占位符留在看似可复制的路径里；改为 `See the exact path in the tool card.`，保留字段语义而不伪造路径。

Skill 激活的普通文本字段也遵守同一条规则：`Session:`/`Session ID:` 保留为
`See the exact session in the activation card.`，`Directory:`/`CLAUDE_SKILL_DIR:` 等路径字段保留为
`See the exact path in the tool card.`。这覆盖模型先把真实值自行替换为 `the requested item` 的情形；不能让该占位符进入可复制的路径，也不能为了满足“逐字引用”而放开 opaque 值的散文泄露。

该规则同样覆盖激活摘要的二列表格：表中 `Session`/`Session ID` 行若值不可用，统一指向相邻激活卡；`Directory`/`Path`/`CWD`/`CLAUDE_SKILL_DIR` 行统一指向精确路径 tool card，不保留 `the requested item` 或嵌入占位符的伪路径。若助手随后声称“所有值均原样/逐字引用、未做替换或臆造”，而表中已有字段被安全重定向，服务端会将整句改写为诚实的人话，避免最终正文与画面事实冲突。若技能已完成显式指令且用户没有后续任务，prompt 也要求助手停下，不得为了“继续”而无谓检查技能目录或发起额外工具调用。

二列表格把 `ID`/`Identifier` 作为字段行时遵守同一规则：当值不可用时，流式出口和 durable close 都必须物理移除整行，不能留下空行或 `ID | -`。空行会切断 Markdown 表格并可能让后续真实字段从渲染结果中消失；精确值仍只在相邻 tool card 与审计线缆中保留。

搜索积木的正文是同一条规则的可操作特例：若模型在“这些 ref 可以用于 workflow”之类的句子中重复 opaque ref，通用脱敏后不得留下 `the requested item` 或 `the requested item.method`，也不得留下 `hd_…` / `hd_….place`、`hd_<id>.<method>` 这类缩写或模板值。服务端只替换含坏占位的那一句为“精确值见相邻 `search_blocks` 结果卡，可直接复制到 workflow 节点”（英文同义句），保留后续提示语；即使模型没有写出 `ref` 一词，只要同句明确谈到 `workflow node(s)`/`workflow 节点` 并含上述坏值，也执行同一改写。若结果被模型整理成同时含 `ref`、`kind`、`name`、`snippet`/`description` 的 Markdown 表，按表头识别为 search_blocks 表，所有 ref 单元格统一改为“精确 ref 见相邻 search_blocks 结果卡”，不误套 flowrun 的 `See the run card`，也清理 `the requested item.method` 这类带方法后缀的坏值。表格行仍由结构化表格规则处理。精确 `ag_`、`hd_`、`mcp:` ref 只在相邻 tool card 和审计线缆中显示。

若模型把 search_blocks 结果进一步压成 `agent/function/handler ×N` 这类汇总 bullet，汇总仍不能把 `the requested item`、`the requested item.method` 或同类占位当成名称展示；服务端保留类别、数量、用户可读名称和方法名，把不可复制的 ref 改为“精确 ref 见相邻 search_blocks 结果卡”（英文同义句）。该 bullet 在流式出口暂存到换行后再处理，确保 SSE 中间帧、durable close、数据库正文和 UI 重建都不会短暂露出半截或完整坏占位；普通 Markdown 表格不走这条规则。

当模型把 opaque ID 放在位置/列表标签前、把人名放在括号内（例如 `Position 0: doc_… (Existing First)`）时，脱敏器必须保留括号中的人名，输出 `Position 0: Existing First`，不能留下 `the requested item`。

面向用户的 assistant 文本还有服务端确定性边界：loop 会在流式文本的唯一出口保留跨 chunk 的尾部词元，并在看到未闭合的括号时短暂保留整个小括号片段，避免 provider 把 `(`、反引号、ID、`)` 分成不同 delta 后先泄露半个坏占位。实体名后紧接可能的 opaque ID 时，连同实体名和分隔符一起短暂保留，确保 chunk 恰好切在 `workflow ` 与 `wf_…` 之间时仍能整体清理；ID 被 Markdown `` `…` ``、`*…*` 或 `**…**` 包住时，同样先完成整体替换再向 SSE 发出，不能把 `workflow **` 这类半截格式先发给用户。它隐藏实体 ID、长整数、时间戳与长 hash 等不透明机器值。隐藏时按类型替换为上下文中性的 `the requested item` 等人话短语，而不是把 `<opaque value omitted>` 或旧版 `the referenced item` 这类坏模板标记露给用户；若模型把一个已经有名称的实体 ID 冗余写成括号（例如 `workflow nightly (wf_…)` 或 ``workflow nightly (`wf_…`)``），只删除整段冗余括号，不留下占位；若 ID 紧跟已有人话实体名（例如 `The workflow wf_… remains intact`），移除 ID 后也移除重复占位，结果为 `The workflow remains intact`，不制造重复名词；若模型用 `The ID <opaque>`、`The flowrun ID <opaque>`、`The flow run ID <opaque>` 或 `The flowrun with ID <opaque>` 引出一个待查对象，则整体改写为 `The requested item`、`The requested flowrun` 或 `The requested flow run`，不产生语法残片；`The flow ` 与 `run with ID ...` 也必须合并后再脱敏，不能因早期 chunk 边界重现同一残片；已明确实体名的 `flowrun report for <opaque>`（包括 Markdown 加粗或反引号装饰）则直接缩为 `flowrun report`，不能留下 “report for …” 坏短语；包含 opaque flowrun ID 的 Markdown 表格行改为 `Run / Current run` 语义行，不把 placeholder 留在表格里。对 `get_flowrun` 的错误总结还会把 `get_flowrun for <opaque>` 改写为 `get_flowrun for the requested run`，把“没有 workflow run with …”改成“没有匹配请求的 workflow run”，避免失败路径出现“the referenced item”或“the requested item”悬空占位。历史消息如果已经持久化旧版占位词，重建时也会先归一化到当前词汇。原始 tool call/tool_result 卡片与审计数据不改，仍保留精确值供追查。摘要只能表达语义结果（例如「已变更」），不能把机器值抄回 prose 或表格。该边界不依赖模型是否遵守 prompt。**但工具调用 JSON 参数是明确例外：若某个工具需要 opaque 值，模型必须从用户消息或上一个 tool result 逐字复制全部字符；不得缩写、规范化、脱敏或猜测。** 例外不适用于面向用户的 prose。带 flowrun 身份的 workflow agent 终答同时是下游节点的数据，必须保留完整 MediaRef receipt；它不是直接面向用户的 chat prose。

在同一确定性出口中，`Flowrun: <opaque>` 标题收敛为 `Flowrun`，`flowrunId = <opaque>` 收敛为 `the current run`；含 `wfv_`、`apf_`、`apfv_` 等内部版本引用的表格行分别显示 `Current version`、`Internal references`，不把机器值或任何旧版占位带到用户画面。`search_flowruns` 生成的多行运行表若包含脱敏后的运行 ID，则每行显示 `See the run card`；中文列表进一步把同一行的两个脱敏值归一成「该运行 / 该工作流」，避免重复的 `the requested item` 让用户误以为多行指向同一个对象；精确 ID 仍只在相邻 tool card 的 Copy 面保留。

若模型生成的是可执行 webhook URL（例如 `/api/v1/webhooks/<trigger-id>/<mount-path>`），不能只把 `<trigger-id>` 替成 placeholder 后留下一个看似可复制但必定失效的地址；服务端会将整行收敛为 `See the exact webhook endpoint in the trigger card.`，并在流式换行前暂存整个 endpoint。精确 URL 仍由 trigger tool card 的原始结果提供。

Flowrun 的自然语言摘要也遵守同一边界：`Run summary for <opaque>` 或其已脱敏的 placeholder 变体收敛为 `Run summary`；`Pinned reference: ... function pinned to version <fnv_...>` 收敛为 `Pinned reference: The function version is pinned.`。精确的 function/version ID 只保留在相邻 tool card 的 Copy 操作和审计/tool-result 面，不进入 assistant prose。`fnv_` 同时属于跨 delta 的整行缓冲集合，不能在中间 SSE 帧短暂露出。

状态统计 reasoning 如果把计数后的明细写成脱敏 placeholder（例如 `running: 1 (the requested item - tool071_approval)`），服务端会移除 placeholder 和多余分隔符，保留可读的 `running: 1 (tool071_approval)`；若括号里只有 placeholder，则整段括号移除。该状态行在换行前会被完整暂存，所以早于 durable close 的 `seq=0` delta 也不能露出半截占位。不能让用户看到重复占位，也不能暗示多个结果是同一个对象。精确运行 ID 仍只从相邻 `search_flowruns` tool card 读取。

即使模型已经提前生成中性占位，同一出口也会对 Flowrun 标题、Run/Version/Ref/Node record 表行及 Pinned Refs 列表做二次语义归一化；Pinned Refs 既覆盖带 `approval form`/`version` 语义的行，也覆盖原始 opaque 值在通用替换后形成的双占位表格行、带实体注释的 ``<placeholder> (approval form) | <placeholder>`` 行、`placeholder → placeholder` 裸列表项和 `Approval form <placeholder> pinned to version <placeholder>` 自然语言项；结构化清理必须在通用 ID 替换之后再跑一次，最终用户画面不能出现任何占位短语。

对于带反引号或 opaque 值的 Markdown 表格行、Flowrun 报告 prose/标题、概览字段、失败报告与 Pinned Refs 摘要，delta 出口还会在最多 512 个 rune 内暂存当前未换行的整行，等行边界到达后再做语义归一化；因此 provider 把 ``| `<placeholder> (approval form) | `<placeholder>` |``、``## Flowrun Report: `<placeholder>```、``Here is the complete flowrun report for `<placeholder>`:``、``**Flowrun ID:** `<placeholder>``` 或 ``The requested item does not correspond...`` 拆成多帧时，中间 SSE 帧也不会出现坏占位或半截结构。失败总结中即使模型改用 `flowrunId: <placeholder>`、`The requested item doesn't correspond to any actual run`、`no workflow run exists with the requested item`、`The requested item is all zeroes after the run ID prefix`、`the actual fr_... ID` 或直接写出 `get_flowrun call`，也统一改写成 `for the supplied run`、`The supplied run ID does not correspond...`、`The supplied run ID has an all-zero suffix`、`the run ID` 和 `run lookup`，不把字段名、工具名或示例前缀带进助手正文。Flowrun 概览中的 `- ID`/`- Version` 会分别显示 `Current run`/`Current version`；失败报告显示 `Requested ID: Supplied run ID`，自然语言引用摘要和箭头列表显示内部引用语义。text block 的 durable close 会对该 block 的完整原始文本再跑一次同一 redactor；因此跨 provider delta 拆开的 Markdown 标题、表格行和列表，在最终 SSE close、数据库快照和 UI 重建三处保持同一语义结果，而不是只在单个 delta 上近似处理。

Flowrun 的另一种 `Not Found` 失败模板也遵守同一人话边界：`call to get_flowrun with ID <placeholder>` 归一为 `run lookup for the supplied run ID`，`there is no workflow run ... with <placeholder>` 归一为 `matching the supplied run`。这些规则和前述表格/失败行一样，既作用于完整 durable close，也作用于跨 delta 的未换行缓冲。

失败报告中残留在同一行的 `<placeholder>` 只要与 `workflow run`、`run ID` 或 `search_flowruns` 同行，也会归一为 `the supplied run ID`，并去掉包裹它的 Markdown 反引号；句首按自然语言规则恢复大写。这样“看起来像 placeholder”或“检查你从哪里拿到它”等建议句不会把脱敏占位直接显示给用户。

流式出口在上下文句尚未闭合时也会暂存 `workflow run` 与 `call to get_flowrun` 前缀；不能先发出前半句，再在后续 delta 才看到 placeholder。该缓冲是逐行的，仍受 512-rune 上限约束，收行后才发送规范化文本。

同一出口还把 `The requested flowrun ...` 归一为 `The supplied run ID ...`，把 `an actual fr_... ID` 一类示例归一为 `a real run ID`；助手正文不展示内部 ID 前缀，即使模型把示例放在“如何继续”说明中。

若失败说明写出 `The get_flowrun tool ...`，面向用户的正文显示为 `The run lookup tool ...`；精确工具名仍只保留在独立 tool card 和审计线缆中。

脱敏后的句法也要保持完整：`the value the supplied run ID looks like ...` 会收敛为 `the supplied run ID looks like ...`，不得留下两个主语拼接的残片。

失败列表中的 `the requested item appears to be a placeholder` 也按同一上下文改写为 `the supplied run ID appears to be a placeholder`；反引号包住的 `get_flowrun` 调用名同样只在 tool card/审计面保留。

Reasoning 也在同一边界内：若 provider 把 `get_flowrun` 拆成 `ge` 与 `t_flowrun` 两个 delta，出口先暂存部分工具名，直到完整词可归一为 `run lookup`；reasoning 的 durable close 不得重新带回工具名或 opaque placeholder。

该归一化只在失败报告上下文行内触发，不改变普通实体句中已有的 `The requested flowrun` 语义测试；这样通用实体脱敏与 Flowrun 错误文案各自保持稳定边界。

用户面可见的 reasoning block 也走同一条 delta + durable-close 脱敏边界，不能因它显示在「thinking」区域而泄露 flowrun、实体、版本或未被请求的时间戳；ISO 与 `YYYY-MM-DD HH:MM:SS UTC` 两种时间写法默认都必须收敛为 `the recorded time`。若用户明确要求工具返回的某个精确命名字段（例如 `lastMessageAt`），该字段是窄例外：在同名字段或表格列中逐字保留原值，不能规范化；附件、MCP 连接等无关时间戳仍按原规则脱敏。带 flowrun 上下文的 workflow-agent reasoning 是下游数据边界，按 workflow-agent text 的规则保留原值。

附件清单的上传时点是例外的可用性语义：精确 `createdAt` 保留在相邻附件工具卡中；若模型把它放进用户正文表格，正文改为 `See the exact upload time in the attachment card.`，不得把 `the recorded time` 留成看似真实的字段值。

System prompt 默认禁止模型臆造或凭记忆抄写长 ID、时间戳、哈希、receipt 与密文；用户明确要求某个工具返回的精确命名字段时，只允许在同名字段中逐字回显该字段，其他机器值仍不得进入 prose。危险 HumanLoop
批准句不采用模型的自报 summary 作为动作真相：它由实际解析的工具名生成，避免 `delete_workflow`
被模型 prose 伪装成 `deactivate_workflow`；所有不可逆 delete 族还必须在门禁本体展示实际后果，不能
退化成泛化的“运行某工具”。二者语义冲突时副作用在闸前终止并反馈模型改选。

对 `get_flowrun`，若模型把 `flowrunId` 截断、改名为 `file_path` 或丢失部分字符，loop 只在最新的 user/tool
message 中存在**唯一一个**明确 `fr_…` 证据值时按原字节恢复；多个候选、无候选或仅有相似值都不修复，仍让工具诚实失败。
用户只需要判断变化时，最终叙述应使用 `changed` / `unchanged` 等语义结果，原始
tool card 才是机器值的精确来源；确实需要精确值时应指向紧邻的 raw tool card，
默认不输出机器值的任何片段，包括前缀、后缀或 `...123` 这样的省略片段；不能自行重算、规范化或把猜测数字放入表格。这样避免工具结果正确而最终总结生成
一个看似可信但不存在的机器值。

模型目录明确 `tools=false` 时，Chat 不发送 tools array，并在 system prompt
明确本轮只能文本回答。Capability tool 是否出现由运行期路由决定；没有能力时
工具诚实缺席。

### Context

每次 sampling 前进行 route-aware context 治理：

- 已知 runtime profile 提供软预算；
- 旧 tool result 可被编辑；
- semantic checkpoint 优先委托 Context manager；
- provider 权威 overflow 可在压缩后透明重试；
- 成功/overflow 证据最佳努力写入 runtime profile。

Assistant `attrs.contextUsage` 保存最后一次 prompt 的预算、route、request
组件大小与恢复计数。回合后 Context manager 在 queue 槽内检查 durable
summary，避免下一回合与 summary/watermark 写竞态。

## 4. 多模态消费

同一个 Attachment renderer 覆盖三条入口：

1. User Message 的 attachment IDs；
2. attached Document 正文中的 MediaRef；
3. tool_result 中本次 tool-call 产生的 MediaRef。

User 附件的精确 opaque ID 会按媒体顺序写入只给模型看的
`<uploaded_attachments_for_tools>` 目录（`read_attachment` 使用 `id`，
`inspect_media` 使用 `attachmentId`），避免模型把 schema 示例 `att_...` 当成真实 ID
而先白付一次失败工具调用；提示中不重复展示任何示例 ID，该目录不写入持久 user bubble，也不渲染给用户。User 附件与文档媒体追加为正在回答的最后一条 user message parts；tool media
在当前 loop 下一步以临时 user parts 回喂，不重复落 Message Block。模型不支持
相应模态时保留文本 receipt/文档正文，不能声称已看见媒体。

Attachment/Document 渲染的真实错误不静默吞掉；tool media 的扩展失败则记录
warning 并保留 durable textual result。

## 5. Finalize 与恢复

Loop 恰调用一次 `WriteFinalize`，在 detached workspace context 单事务写
assistant 状态、余下 blocks、usage、model/provider 与 attrs，再发送 durable
`message_stop`。Chat host 另实现可选 `BlockRecorder`：每次 LLM sampling
结束后先把该批 blocks 追加到仍为 streaming 的 assistant 行。这样人在环停泊后，用户
稍晚冷打开线程时，REST history 仍有对应 `tool_call`，`GET interactions` 提供的
问题/按钮可以挂到真实节点上，而不是只显示一行无意义的 `thinking`。最终
`WriteFinalize` 按已落盘 block id 过滤，绝不重复插入。关闭页面或请求取消不能留下永久
streaming 行；未接增量 writer 的其它 loop host 仍保持只在 finalize 落盘。

模型解析在 loop 前失败时，`failTurn` 走相同终态纪律。Boot 的
`SweepOrphans` 将进程硬崩溃留下的 pending/streaming Message 收成 cancelled。

完成回复原子更新 `last_message_at` 与 unread=true；用户 Send 更新 recency 且
unread=false。首轮自动标题与 durable compaction 都是 best-effort，不改变已经
落地的回答。它们可以活过单个 turn 的取消，但必须观察 chat service 的 lifecycle
cancel，不能活过 DB close；自动标题即使遇到无视取消的 provider，也要在最终写入前
再检查生命周期。

## 6. Retry

`:retry` 有两种形态：

- 无 content：替换当前 assistant；若尾部只有 user，则补生成缺失回答；
- 有 content：复制原附件、写编辑后的新 user，并替换当前 user/assistant。

先写新行，再把旧行 `MarkSuperseded`，保证中途失败留下可见重复而不是丢失
对话。Mention snapshot 不从原 user 复制，因为编辑文本可能已删除提及。

替换目标只在 top-level、current-version Message 中选。逐回合 model override
只影响这次生成，不回写 Conversation。`retryOf` 必须在 assistant Host attrs
重新播种，因为 Finalize 整体写 attrs。

Open、Close 与 user echo 都携 `retryOf`；Close 是重连/replay 仅凭 durable
快照恢复版本组的入口。Context compaction 和 anchor source 同样排除被替换版本，
但 usage 保留它们的真实 token 花费。

## 7. Fork、Anchors 与读取

Chat 负责 Fork 的 Message/Block prefix 复制与 ID remap；Conversation 服务负责
新主行。详细不变量见 [`conversation.md`](conversation.md)。

消息读面支持 older/newer keyset 与 around deep jump。Scene anchors 使用 lean
source 构建并跳过 superseded turns。System-prompt preview 复用真实 prompt
builder；Usage 汇总所有真实模型花费。

## 8. 契约

精确 Send、Retry、Fork、Cancel、interaction、messages、anchors、usage 与
system-prompt-preview 端点见 [`api.md`](../api.md)。表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，流事件见
[`events.md`](../events.md)。

最大 steps 从 live limits 读取；触顶以 `max_steps` /
`MAX_STEPS_REACHED` 诚实终止。HumanLoop interaction 是回合内 ephemeral
broker；重启后不存在，Workflow durable approval 由 Scheduler 独立管理。

Fork Skill 返回后，父回合最多再做一次纯文本收尾采样；工具 schema 被移除。若模型仍吐出 tool
call，loop 跳过 AutoActivator、不执行该调用，补齐明确的 `toolsDisabled` tool-result 后以
`TURN_TOOLS_DISABLED` 终止，避免父模型绕回主聊天文件工具或再次派 fork。

当用户明确要求某个操作“必须被拒绝”时，模型必须先用最新工具结果验证拒绝前提；如果事实不满足该前提，不能为了迎合用户先执行再撤销，必须保持 durable state 不变并说明事实冲突。
`get_relations` 的关系卡每一行必须同时显示两个端点、方向和关系动词（`equip/link/create/edit`）；
只有箭头而没有动词时，用户无法判断这是挂载、文档链接还是创建/编辑溯源。精确机器 ref 仍只在
工具结果卡中显示，自然语言摘要遵守 opaque-id 脱敏边界。
关系表中的 `起点 (from)`、`终点 (to)`、`端点名称` 等列只展示 kind 与人类可读名称；
`fromId`、`toId`、`edgeId`、时间戳和 `rel_...` 不能附在端点名称后进入 assistant prose 或用户画面。
这一规则同时作用于 durable close 与每个 SSE delta：跨 chunk 的端点行、机器字段和裸占位符必须先暂存到
行边界再做一次完整脱敏。精确 ref 保留在相邻 tool card、tool result 和 LLM 审计线缆中，不能因为 prose
脱敏而篡改真实执行结果。
