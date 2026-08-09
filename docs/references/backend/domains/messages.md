---
id: DOC-022
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Messages

## 1. 定位

Messages 是 Chat、Agent loop 与 Subagent 共用的中立内容模型。Stream 描述节点
怎样传到客户端；Message/Block 描述一个回合由什么组成。

Message 是 `user|assistant` 回合，拥有一棵 Block。Loop 在内存中生成 Block；通常由
Host 的 `CreateMessage` / `FinalizeMessage` 边界持久化，Chat 在人在环停泊时可通过
可选 `BlockRecorder` 把已结束的 LLM sampling block 先追加到 streaming assistant，
以支持冷打开 REST 重建真实工具卡。

## 2. Block

封闭类型：

| Type | 语义 | 进入 LLM history |
|---|---|---|
| `text` | 用户或 assistant 文本 | 是 |
| `reasoning` | 模型推理内容 | 是 |
| `tool_call` | 工具名、参数与框架字段 | 是 |
| `tool_result` | 工具终态结果 | 是 |
| `progress` | 工具中间输出 | 否 |
| `compaction` | 压缩边界标记 | 否 |
| `marker` | 线程配置变化的行内标记 | 否 |

`tool_call` Close 只代表参数写完；工具执行在其下 Open `tool_result`，期间可挂
多个 progress，最终 `tool_result` Close 才是执行完成/失败真相。

Marker content 为空，客户端按 attrs 本地化渲染。目前 `kind=workdir` 保存 from/to。
增加新的 marker kind 不需要扩展 Block type。

Block 通过 `parent_block_id` 形成树，`seq` 在事务落盘时分配。Context role
`hot|warm|cold|archived` 只改变 LLM 投影，不改写 durable content。

## 3. Message 生命周期

状态为：

```text
pending → streaming → completed | error | cancelled
```

User 回合通常在 Create 时连 text block 一起落盘。Assistant 先落空 streaming
行以获得流锚点；Chat 若在 sampling 后停在人在环，会先追加该批已关闭的 blocks，
随后由 Finalize 以单事务写终态、token/provider/model 溯源、attrs 和尚未追加的 blocks。
Finalize 会跳过已追加的 block id，避免重复。Boot 的 `SweepNonTerminal` 将硬崩溃遗留行
收为 cancelled，已落下的工具调用证据仍可从 REST 读到。

`input_tokens` / `output_tokens` 是整次 ReAct 多轮 sampling 的累计计费量。
Assistant `attrs.contextUsage` 另存最后成功 prompt 的输入预算、route、组件字节
和压缩/恢复计数，二者不可混用。

## 4. 两类嵌套指针

### Subagent

`subagent_id` 非空表示父对话内的子运行。`attrs.parentBlockId` 指向派生它的
tool_call。REST history 保留这些行以重建树；父 LLM history 必须排除它们，
父模型只读取派生 tool_call 的最终 tool_result。

### Retry version

旧 Message 的 `superseded_by` 指向替代行，新行的 `attrs.retryOf` 反指旧行。
这是一组版本指针，不是删除：

- 所有行继续存在并可从 REST 读取；
- UI 将它们组成版本页；
- LLM history 只读取 `superseded_by=''` 的现行行；
- `MarkSuperseded` 是对终态 Message 唯一允许的单列更新。

## 5. 读取

- `ListMessages`：newest-first keyset；
- `ListMessagesNewer`：从已有窗口向新侧续翻；
- `ListMessagesAround`：以 Message ID 为中心返回双向窗口；
- `ListAnchorSource`：只读锚点需要的 lean blocks；
- `LoadThread`：完整 durable thread；
- `LoadThreadForLLM`：SQL 下推 top-level、current-version、watermark 三谓词；
- `SumTokens`：真实花费，不因 retry/compaction 过滤。

`get_subagent_trace` 在完整 thread 上按 subagent ID 投影内部 blocks。该工具不
提供给 Subagent 自身，避免读取父对话的其它子运行。

## 6. 契约

表见 [`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，流事件见
[`events.md`](../events.md)。ID：`msg_`、`blk_`。
