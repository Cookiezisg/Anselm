---
id: WRK-026-FRONTIER
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-29
review-due: 2026-08-12
audience: [human, ai]
---

# Frontier · 高频动态覆盖与 reprobe 队列

> 这里记录下一批值得跑的真实路径，不是冻结的“覆盖率百分比”。完成后将结论移入 LOG 或 HISTORY；承重面变化后，历史绿格可以重新回到这里。

## 选择规则

优先级 = 高频度 × 用户损失 × 当前变化风险 × 证据缺口。每项至少注明：路由类别、执行面、媒体/资源流、后端真相和最小证据。173 家 provider 不是 173 条手工 lane；以协议/行为类抽样，验证目录解析与路由边界。

## 当前队列

| ID | 路径 | 路由 | 要证明的事实 | 最小证据 | 状态 |
|---|---|---|---|---|---|
| FRT-01 | 默认聊天 + 图片/视频附件 + 语音输入 | managed-read/default | Anselm 的实际输入路由、lease 与能力降级正确；语音输入另走 proof-bound ASR WebSocket | 请求形状 + 回合/附件真相；ASR `session.finished` | image / MP4 video / realtime ASR session 通过；chat audio 当前不宣传 |
| FRT-02 | BYOK 视觉/音视频输入 | byok-read | 多模态输入是正式 BYOK 能力，不被生成边界误关 | 目录能力、wire part 或明确文本降级 | OpenAI image / Qwen MP4 video / Qwen WAV audio 真实通过 |
| FRT-03 | BYOK 模型调用受管出图 | hybrid | 模型调度与受管生成正确接合，生成者不被重复喂像素导致重画 | tool/receipt、调用次数、产物与后续请求 | OpenAI→managed image 通过；真实 OpenAI continuation wire 已逐字节收到生成图片 |
| FRT-04 | workflow：生成者 → 下游观看者 | hybrid | 下游收到真实像素而非“图片已生成”文本 | 录制请求包含原始像素 | function-artifact workflow wire through；managed Anselm 生成→receipt→下游节点真实完成且附件可回读；managed provider wire 仍待 gateway 侧 recorder |
| FRT-05 | MCP/function/handler 产物 → 下游模型 | byok-read / hybrid | 各产地均能成为 MediaRef；不退化为占位字符串 | 产物字节、MediaRef、下游请求 | MCP/function/handler producers and chat/workflow vision wire through；subagent managed generation→receipt state through；reprobe on media/ref encoder changes |
| FRT-06 | 文档内图像 → 引用/问答 | managed-read/default / byok-read | 编辑器往返和 LLM 消费保真 | 文档、附件与请求三方一致 | managed image-reference 与 BYOK OpenAI exact-byte wire 均通过 |
| FRT-07 | 音色完整生命周期 | hybrid + managed-write | 预置语音→附件→危险审批→异步登记→克隆合成→库存→删除 | 生产 API Serve、inventory、网关句柄到上游 id 的映射、删除后状态 | 默认 Anselm API managed E2E 通过；网关句柄/default/WAV 修复已被真实链路覆盖 |
| FRT-08 | 朗读缓存与配额 | managed-write | 同文本同音色不二次调用；换输入才花费 | managed gateway quota delta + attachment cached；provider recorder 仅有 archived 直连证据 | managed cache/quota through; provider-wire count remains a gateway-side evidence gap |
| FRT-09 | 生成工具诚实显隐 | managed-write | 出图/改图/动画/音色各自独立，不能因一个能力存在而全露出 | 工具表 + 具体 route/capability | managed image/speech/edit/video/animation live through; animation uses the dedicated `/videos/animations` route and caps oversized output before continuation |
| FRT-10 | 无 tool-call 模型 | byok-read | 可聊天但不作为 agent 可用模型；不被目录裁剪误删 | 模型选择器/API + agent 限制 + chat-only wire | Qwen-MT 真实通过；chat 去工具、agent 明确拒绝 |
| FRT-11 | provider 行为类 | byok-read | compat、Anthropic、Azure、Google、Vertex 的凭证/URL/编码边界正确 | 每类最小 probe + 错误分类 | ready |
| FRT-12 | 工具参数流 | byok-read / hybrid | 累积式与增量式 `arguments` 都能执行一次正确工具调用 | 两类 fixture + 真线缆样本 | locked; reprobe with parser changes |
| FRT-13 | 取消、重试与恢复中的媒体 | all applicable | 取消回合不留孤儿、重放不错误复用或重复消费 | durable 状态、附件溯源、调用计数 | handler/workflow cancel/retry/crash no-orphan + image preparation ready/failed/cancel/retry + boot budget eviction/regeneration + crash requeue through; reprobe on worker/recovery changes |

## 历史高频 reprobe 组

这些不是“已覆盖所以跳过”。当任一承重面改变时，按组抽取代表路径重测：

| 组 | 代表路径 | 触发 reprobe 的承重变化 |
|---|---|---|
| R-A | 对话、模型选择、工具调用、错误恢复 | modelclient、catalog、provider 方言、loop、消息投影 |
| R-B | agent/subagent、动态工具、持久化 trace | toolset、agent runner、SSE、上下文压缩 |
| R-C | workflow、触发、暂停/审批、replay | durable engine、节点协议、并发、flowrun 存储 |
| R-D | 附件、文档、MCP/function/handler 产物 | MediaRef、attachment、renderer、part encoder |
| R-E | 配额、缓存、危险操作与资源清理 | gateway、managed key、quota、approval、resource store |

## 不做的伪覆盖

- 不逐家手工验证全部 provider；目录规模下这会制造过期清单而不是保证。
- 不以模型自然语言自述证明它“看见了”媒体；需要线缆或字节证据。
- 不用 mock 证明真实供应商的异步状态、URL 可达性、计费或流式分片约定。
- 不把已删除的 BYOK 直连生成路径作为正常能力回归。
- 不要求本地测试者持有或注入 API Serve 的 provider secret；那会把运维边界错误地拉回产品端。
