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
→ persist/emit blocks
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

Reminder 与媒体追加只进入后续 request，不污染 durable Message history。

## 3. Blocks 与工具

模型流产生 text、reasoning 与 tool_call Blocks。框架给每个工具 schema 注入
`summary`、`danger`、`execution_group`，派发前剥离，工具只接收业务参数。

同 execution group 的 calls 并行，每个调用写预分配槽，结果仍按调用顺序拍平。
Tool 执行前 Open 空 tool_result，progress 作为子块实时/持久化，完成后 Close
完整 result。

单个 tool result 有统一硬上限，防止持久化、SSE 与当前 prompt 同时被无界输出
撑爆。Object 型参数接受真实 object 或“可解析为 object 的 JSON string”，不
接受数组/标量的猜测转换。

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

## 5. HumanLoop gate

Chat context 可携 ephemeral broker；独立 Agent、顶层 Subagent 与 Workflow node
没有 broker 时按其调用边界直接执行。

两类 gate：

- 模型自报 `dangerous`：允许 conversation/tool 的 approve-always 与 active
  Skill allowed-tools 预授权；
- Workdir 外写入：由 `FileWriteTool.WriteTarget`、`fspath.ExpandIn` 与
  `fspath.Inside` 计算，任何预授权都不能绕过。

Workdir 是 zoom，不限制读取。路径无法可靠解析时回到普通 danger 语义；工具
Execute 仍会校验自己的参数。越界确认 payload 在标准 summary/args 外增加
`outsideWorkDir=true`。

## 6. 多模态工具结果

Loop 按 tool-call 分组收集 result 中的 MediaRef，支持纯 JSON 或散文中的嵌入
JSON object。收集器去重并限制数量，不按 source 过滤。

Host 根据本次模型能力与 Attachment ownership 将媒体展开为原生 parts。不能
消费的媒体继续以文本 receipt 存在；扩展消息不重复写入 durable Blocks。

## 7. 终态

Provider 分类错误保留鉴权、请求、模型、额度、限流与上游错误码；无法分类的
流错误使用 `LLM_STREAM_ERROR`。Stop reason 兼容
`end_turn|max_tokens|max_steps|context_budget|cancelled|error`；
`context_budget` 只用于读取已有持久数据，当前引擎不主动产生该软停。

Loop 无表或 HTTP 端点。Message/Block 契约见
[`messages.md`](../domains/messages.md)，流见
[`events.md`](../events.md)，错误见
[`error-codes.md`](../error-codes.md)。
