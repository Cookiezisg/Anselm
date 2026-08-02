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
- Shutdown 取消所有 running turn 并停止 queue；
- Cancel 同时取消 running turn、清空 queued turn，并把所有 assistant 行收成
  cancelled。

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
次 request tools 中出现。AgentState 使用有界 recency set；直接点名 lazy tool
时 AutoActivator 可补发现步骤。

### Grounded final text

面向用户的 assistant 文本还有服务端确定性边界：loop 会在流式文本的唯一出口保留跨 chunk 的尾部词元，并在看到未闭合的括号时短暂保留整个小括号片段，避免 provider 把 `(`、反引号、ID、`)` 分成不同 delta 后先泄露半个坏占位。实体名后紧接可能的 opaque ID 时，连同实体名和分隔符一起短暂保留，确保 chunk 恰好切在 `workflow ` 与 `wf_…` 之间时仍能整体清理；ID 被 Markdown `` `…` ``、`*…*` 或 `**…**` 包住时，同样先完成整体替换再向 SSE 发出，不能把 `workflow **` 这类半截格式先发给用户。它隐藏实体 ID、长整数、时间戳与长 hash 等不透明机器值。隐藏时按类型替换为上下文中性的 `the requested item` 等人话短语，而不是把 `<opaque value omitted>` 或旧版 `the referenced item` 这类坏模板标记露给用户；若模型把一个已经有名称的实体 ID 冗余写成括号（例如 `workflow nightly (wf_…)` 或 ``workflow nightly (`wf_…`)``），只删除整段冗余括号，不留下占位；若 ID 紧跟已有人话实体名（例如 `The workflow wf_… remains intact`），移除 ID 后也移除重复占位，结果为 `The workflow remains intact`，不制造重复名词；若模型用 `The ID <opaque>`、`The flowrun ID <opaque>`、`The flow run ID <opaque>` 或 `The flowrun with ID <opaque>` 引出一个待查对象，则整体改写为 `The requested item`、`The requested flowrun` 或 `The requested flow run`，不产生语法残片；`The flow ` 与 `run with ID ...` 也必须合并后再脱敏，不能因早期 chunk 边界重现同一残片；已明确实体名的 `flowrun report for <opaque>`（包括 Markdown 加粗或反引号装饰）则直接缩为 `flowrun report`，不能留下 “report for …” 坏短语；包含 opaque flowrun ID 的 Markdown 表格行改为 `Run / Current run` 语义行，不把 placeholder 留在表格里。对 `get_flowrun` 的错误总结还会把 `get_flowrun for <opaque>` 改写为 `get_flowrun for the requested run`，把“没有 workflow run with …”改成“没有匹配请求的 workflow run”，避免失败路径出现“the referenced item”或“the requested item”悬空占位。历史消息如果已经持久化旧版占位词，重建时也会先归一化到当前词汇。原始 tool call/tool_result 卡片与审计数据不改，仍保留精确值供追查。摘要只能表达语义结果（例如「已变更」），不能把机器值抄回 prose 或表格。该边界不依赖模型是否遵守 prompt。**但工具调用 JSON 参数是明确例外：若某个工具需要 opaque 值，模型必须从用户消息或上一个 tool result 逐字复制全部字符；不得缩写、规范化、脱敏或猜测。** 例外不适用于面向用户的 prose。带 flowrun 身份的 workflow agent 终答同时是下游节点的数据，必须保留完整 MediaRef receipt；它不是直接面向用户的 chat prose。

在同一确定性出口中，`Flowrun: <opaque>` 标题收敛为 `Flowrun`，`flowrunId = <opaque>` 收敛为 `the current run`；含 `wfv_`、`apf_`、`apfv_` 等内部版本引用的表格行分别显示 `Current version`、`Internal references`，不把机器值或任何旧版占位带到用户画面。

Flowrun 的自然语言摘要也遵守同一边界：`Run summary for <opaque>` 或其已脱敏的 placeholder 变体收敛为 `Run summary`；`Pinned reference: ... function pinned to version <fnv_...>` 收敛为 `Pinned reference: The function version is pinned.`。精确的 function/version ID 只保留在相邻 tool card 的 Copy 操作和审计/tool-result 面，不进入 assistant prose。`fnv_` 同时属于跨 delta 的整行缓冲集合，不能在中间 SSE 帧短暂露出。

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

用户面可见的 reasoning block 也走同一条 delta + durable-close 脱敏边界，不能因它显示在「thinking」区域而泄露 flowrun、实体、版本或时间戳；ISO 与 `YYYY-MM-DD HH:MM:SS UTC` 两种时间写法都必须收敛为 `the recorded time`；带 flowrun 上下文的 workflow-agent reasoning 是下游数据边界，按 workflow-agent text 的规则保留原值。

System prompt 明确禁止模型臆造或凭记忆抄写长 ID、时间戳、哈希、receipt 与密文。危险 HumanLoop
批准句不采用模型的自报 summary 作为动作真相：它由实际解析的工具名生成，避免 `delete_workflow`
被模型 prose 伪装成 `deactivate_workflow`；二者语义冲突时副作用在闸前终止并反馈模型改选。

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

User 附件与文档媒体追加为正在回答的最后一条 user message parts；tool media
在当前 loop 下一步以临时 user parts 回喂，不重复落 Message Block。模型不支持
相应模态时保留文本 receipt/文档正文，不能声称已看见媒体。

Attachment/Document 渲染的真实错误不静默吞掉；tool media 的扩展失败则记录
warning 并保留 durable textual result。

## 5. Finalize 与恢复

Loop 恰调用一次 `WriteFinalize`，在 detached workspace context 单事务写
assistant 状态、blocks、usage、model/provider 与 attrs，再发送 durable
message_stop。关闭页面或请求取消不能留下永久 streaming 行。

模型解析在 loop 前失败时，`failTurn` 走相同终态纪律。Boot 的
`SweepOrphans` 将进程硬崩溃留下的 pending/streaming Message 收成 cancelled。

完成回复原子更新 `last_message_at` 与 unread=true；用户 Send 更新 recency 且
unread=false。首轮自动标题与 durable compaction 都是 best-effort，不改变已经
落地的回答。

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
