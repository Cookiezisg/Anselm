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
