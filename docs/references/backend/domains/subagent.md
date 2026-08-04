---
id: DOC-024
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Subagent

## 1. 定位

Subagent 是父 Chat 回合内的隔离递归运行机制，不是持久化 Agent 实体。Task
工具与 fork-mode Skill 调用同一个 `Spawn`，同步取得最终答案。

它没有独立表：assistant 回合作为带 `subagent_id` 的 sub-message 写入父
Conversation，blocks 通过 `parentBlockId` / stream ParentID 嵌在派生
tool_call 下。

## 2. Host 与隔离

Subagent Host：

- history 只有聚焦任务 prompt，不加载父 thread；
- tool set 在 Spawn 时静态确定；
- WriteFinalize 在 detached workspace context 写 sub-message 并发
  message_stop；
- 不提供 lazy auto-activation、Todo reminder 或 Workflow step recorder。

父模型只看到 Task tool_result 中的最终答案，不读取 Subagent 内部 trace。
前端 reload 通过 sub-message 重建嵌套；需要模型调查内部过程时使用
`get_subagent_trace`。

Subagent 从父 turn context 继承 workspace、conversation、tool-call、workdir、
deadline 与 HumanLoop 边界，但使用新的 AgentState，避免把父对话的 lazy tool
发现状态当作子运行授权。

## 3. 类型与递归边界

内建类型：

| Type | 工具面 | Step cap |
|---|---|---:|
| `Explore` | Read、LS、Glob、Grep | 30 |
| `Plan` | Explore + WebFetch/WebSearch | 25 |
| `general-purpose` | 父工具集减 Subagent/trace | 25 |

工具按稳定 Name 过滤。Subagent/trace 无论类型都剔除，并在 `Spawn` 再做递归
守卫，因此深度固定为 1。

模型使用 workspace dialogue scenario。Conversation 的显式 model override
不跨入 Subagent resolver。

## 4. 多模态

逐请求 capability tools 先并入候选工具集，再经过类型白名单：

- general-purpose 可继承当前可用的生成能力；
- Explore/Plan 的只读白名单自然排除生成能力。

工具结果里的 MediaRef 经与 Chat/Agent 相同的 AttachmentRenderer 按已解析模型
能力展开，下一步可以看到原生媒体。Renderer 缺席或模型不支持时只保留文本
receipt，不伪装为已消费。

## 5. 终态与契约

Spawn 受 Chat turn wall-clock 约束。模型解析、类型或 loop 失败作为 tool-level
错误返回，不新增 HTTP 错误。被取消的子运行仍以 detached context 落终态，避免
永久 streaming 行。

类型校验发生在 `Spawn` 之前。校验失败只落父工具调用的错误结果，不创建子运行、
不产生可回放轨迹；前端必须使用“校验失败 / 未启动”的语义，不能显示已派出或
`get_subagent_trace` 回放提示，也不能把该错误当成子代理回答。

无独立端点、表或错误码。依赖 Messages、Loop、dialogue model resolver、父工具
集、能力工具与 AttachmentRenderer；被 Chat Task 工具和 Skill fork mode 调用。
运行 ID：`subagt_`。
